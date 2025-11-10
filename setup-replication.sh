#!/bin/bash

# Script de Configuración Manual de Replicación PostgreSQL
# Proyecto: Sistema Alta Disponibilidad - Pollo Sanjuanero S.A.

set -e

echo "=== CONFIGURACIÓN DE ALTA DISPONIBILIDAD POSTGRESQL ==="
echo "Proyecto: Sistema Pollo Sanjuanero S.A."
echo ""

# Función para esperar que un contenedor esté listo
wait_for_postgres() {
    local container=$1
    local port=$2
    
    echo "Esperando que $container esté listo en puerto $port..."
    while ! docker exec $container pg_isready -U postgres > /dev/null 2>&1; do
        sleep 2
        echo "."
    done
    echo "$container está listo!"
}

# 1. INICIAR NODO PRIMARIO
echo "1. Iniciando nodo primario..."
docker run -d --name postgres-primary \
    --network postgres-ha \
    -p 15432:5432 \
    -e POSTGRES_DB=pollo_sanjuanero \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres123 \
    -v primary_data:/var/lib/postgresql/data \
    -v $(pwd)/backups:/backups \
    -v $(pwd)/scripts:/scripts \
    postgres:15

# Crear red si no existe
docker network create postgres-ha 2>/dev/null || true

# Reiniciar con la red
docker stop postgres-primary 2>/dev/null || true
docker rm postgres-primary 2>/dev/null || true

docker run -d --name postgres-primary \
    --network postgres-ha \
    -p 15432:5432 \
    -e POSTGRES_DB=pollo_sanjuanero \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres123 \
    -v primary_data:/var/lib/postgresql/data \
    -v $(pwd)/backups:/backups \
    -v $(pwd)/scripts:/scripts \
    postgres:15

wait_for_postgres postgres-primary 15432

# 2. CONFIGURAR REPLICACIÓN EN EL PRIMARIO
echo "2. Configurando parámetros de replicación en el primario..."

# Modificar postgresql.conf
docker exec postgres-primary bash -c "
echo \"
# Configuración de replicación
wal_level = replica
archive_mode = on
archive_command = 'cp %p /backups/wal_archive/%f'
max_wal_senders = 3
wal_keep_size = 1GB
hot_standby = on
listen_addresses = '*'
\" >> /var/lib/postgresql/data/postgresql.conf"

# Modificar pg_hba.conf para permitir replicación
docker exec postgres-primary bash -c "
echo '# Configuración de replicación' >> /var/lib/postgresql/data/pg_hba.conf
echo 'host replication replicator 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf
echo 'host all all 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf
"

# Reiniciar primario
echo "Reiniciando nodo primario con nueva configuración..."
docker restart postgres-primary
wait_for_postgres postgres-primary 15432

# 3. CREAR USUARIO DE REPLICACIÓN Y SLOTS
echo "3. Creando usuario de replicación y slots..."
docker exec postgres-primary psql -U postgres -c "
CREATE USER replicator WITH REPLICATION PASSWORD 'replicator123';
SELECT pg_create_physical_replication_slot('standby_slot');
SELECT pg_create_physical_replication_slot('readonly_slot');
"

# 4. INICIALIZAR BASE DE DATOS
echo "4. Inicializando base de datos con datos de ejemplo..."
docker exec postgres-primary psql -U postgres -f /scripts/init-primary.sql

# Crear directorio para WAL archive
docker exec postgres-primary mkdir -p /backups/wal_archive

# 5. CREAR NODO STANDBY
echo "5. Creando nodo standby..."

# Crear réplica base
docker run -d --name postgres-standby \
    --network postgres-ha \
    -p 15433:5432 \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres123 \
    -e PGPASSWORD=replicator123 \
    -v standby_data:/var/lib/postgresql/data \
    -v $(pwd)/backups:/backups \
    -v $(pwd)/scripts:/scripts \
    --entrypoint bash \
    postgres:15 \
    -c "
        # Crear réplica desde primario
        pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replicator -v -P
        
        # Configurar como standby
        echo \"standby_mode = 'on'\" >> /var/lib/postgresql/data/postgresql.conf
        echo \"primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator123'\" >> /var/lib/postgresql/data/postgresql.conf
        echo \"primary_slot_name = 'standby_slot'\" >> /var/lib/postgresql/data/postgresql.conf
        echo \"hot_standby = on\" >> /var/lib/postgresql/data/postgresql.conf
        
        # Crear recovery.conf (PostgreSQL 12+)
        echo \"standby_mode = 'on'\" > /var/lib/postgresql/data/recovery.conf
        echo \"primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator123'\" >> /var/lib/postgresql/data/recovery.conf
        echo \"primary_slot_name = 'standby_slot'\" >> /var/lib/postgresql/data/recovery.conf
        
        # Cambiar propietario
        chown -R postgres:postgres /var/lib/postgresql/data
        
        # Iniciar PostgreSQL
        su postgres -c 'postgres'
    "

wait_for_postgres postgres-standby 15433

# 6. CREAR NODO SOLO LECTURA
echo "6. Creando nodo de solo lectura..."

docker run -d --name postgres-readonly \
    --network postgres-ha \
    -p 15434:5432 \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres123 \
    -e PGPASSWORD=replicator123 \
    -v readonly_data:/var/lib/postgresql/data \
    -v $(pwd)/scripts:/scripts \
    --entrypoint bash \
    postgres:15 \
    -c "
        # Crear réplica desde primario
        pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replicator -v -P
        
        # Configurar como standby de solo lectura
        echo \"standby_mode = 'on'\" >> /var/lib/postgresql/data/postgresql.conf
        echo \"primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator123'\" >> /var/lib/postgresql/data/postgresql.conf
        echo \"primary_slot_name = 'readonly_slot'\" >> /var/lib/postgresql/data/postgresql.conf
        echo \"hot_standby = on\" >> /var/lib/postgresql/data/postgresql.conf
        echo \"max_standby_streaming_delay = 300s\" >> /var/lib/postgresql/data/postgresql.conf
        
        # Crear recovery.conf
        echo \"standby_mode = 'on'\" > /var/lib/postgresql/data/recovery.conf
        echo \"primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator123'\" >> /var/lib/postgresql/data/recovery.conf
        echo \"primary_slot_name = 'readonly_slot'\" >> /var/lib/postgresql/data/recovery.conf
        
        # Cambiar propietario
        chown -R postgres:postgres /var/lib/postgresql/data
        
        # Iniciar PostgreSQL
        su postgres -c 'postgres'
    "

wait_for_postgres postgres-readonly 15434

echo ""
echo "=== CONFIGURACIÓN COMPLETADA ==="
echo ""
echo "Nodos disponibles:"
echo "- Primario (lectura/escritura): localhost:15432"
echo "- Standby (failover): localhost:15433"  
echo "- Solo Lectura: localhost:15434"
echo ""
echo "Credenciales:"
echo "- Usuario: postgres"
echo "- Password: postgres123"
echo "- Base de datos: pollo_sanjuanero"
echo ""
echo "Ejecute el siguiente comando para probar la replicación:"
echo "docker exec postgres-primary psql -U postgres -f /scripts/test-replication.sql"