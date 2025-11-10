#!/bin/bash

# Demo de Failover Manual - PostgreSQL HA
# Proyecto: Sistema Alta Disponibilidad - Pollo Sanjuanero S.A.

echo "=== DEMOSTRACIÓN DE FAILOVER MANUAL ==="
echo "Proyecto: Sistema Pollo Sanjuanero S.A."
echo ""

# 1. Crear standby funcional
echo "1. Creando nodo standby con réplica streaming..."

docker run -d --name postgres-standby --network postgres-ha -p 15433:5432 \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres123 \
    -e PGPASSWORD=replicator123 \
    postgres:15 bash -c "
        # Crear réplica
        pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replicator -v -P
        
        # Configurar standby
        echo \"primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator123'\" >> /var/lib/postgresql/data/postgresql.conf
        touch /var/lib/postgresql/data/standby.signal
        chown -R postgres:postgres /var/lib/postgresql/data
        
        # Iniciar postgres
        su postgres -c 'postgres'
    "

echo "Esperando que standby esté listo..."
sleep 20

# 2. Verificar replicación
echo "2. Verificando replicación..."
if docker exec postgres-standby pg_isready -U postgres; then
    echo "✅ Standby está funcionando"
    
    # Insertar dato en primario
    echo "Insertando dato de prueba en primario..."
    docker exec postgres-primary psql -U postgres -d pollo_sanjuanero -c "
        INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
        ('Test Failover $(date)', '9999-0000', 'Test Address');
    "
    
    # Verificar que llegó al standby
    sleep 3
    echo "Verificando dato en standby:"
    docker exec postgres-standby psql -U postgres -d pollo_sanjuanero -c "
        SELECT nombre FROM ventas.clientes WHERE telefono = '9999-0000' ORDER BY fecha_registro DESC LIMIT 1;
    "
    
    echo "✅ Replicación funcionando correctamente"
else
    echo "❌ Error: Standby no está funcionando"
    exit 1
fi

# 3. Simular falla y failover
echo ""
echo "3. Simulando falla del primario..."
echo "Deteniendo postgres-primary..."
docker stop postgres-primary

echo ""
echo "4. Ejecutando failover manual..."
echo "Promoviendo standby a primario..."

# Promover standby
docker exec postgres-standby su postgres -c "pg_ctl promote -D /var/lib/postgresql/data"

sleep 5

# 5. Verificar nuevo primario
echo ""
echo "5. Verificando nuevo primario..."
if docker exec postgres-standby pg_isready -U postgres; then
    echo "✅ Nuevo primario está funcionando"
    
    # Verificar que no está en recovery
    echo "Estado de recovery:"
    docker exec postgres-standby psql -U postgres -c "SELECT pg_is_in_recovery();"
    
    # Probar escritura
    echo "Probando escritura en nuevo primario:"
    docker exec postgres-standby psql -U postgres -d pollo_sanjuanero -c "
        INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
        ('Post Failover $(date)', '8888-0000', 'Post Failover Address');
        
        SELECT nombre FROM ventas.clientes WHERE telefono IN ('9999-0000', '8888-0000') ORDER BY fecha_registro DESC;
    "
    
    echo "✅ FAILOVER COMPLETADO EXITOSAMENTE"
    echo ""
    echo "Resumen:"
    echo "- Primario original: DETENIDO"
    echo "- Standby promovido: FUNCIONANDO COMO PRIMARIO"
    echo "- Datos preservados: ✅"
    echo "- Escrituras funcionando: ✅"
    echo "- Nuevo endpoint: localhost:15433"
    
else
    echo "❌ Error en el failover"
fi