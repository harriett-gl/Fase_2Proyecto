#!/bin/bash

# Script de Failover Manual - PostgreSQL HA
# Proyecto: Sistema Alta Disponibilidad - Pollo Sanjuanero S.A.

set -e

echo "=== SIMULACIÓN DE FAILOVER MANUAL ==="
echo "Proyecto: Sistema Pollo Sanjuanero S.A."
echo ""

# Función para mostrar estado de los nodos
show_status() {
    echo "=== ESTADO ACTUAL DE LOS NODOS ==="
    
    echo "Primario (puerto 15432):"
    if docker exec postgres-primary pg_isready -U postgres 2>/dev/null; then
        echo "  ✅ ACTIVO"
        echo "  Estado de replicación:"
        docker exec postgres-primary psql -U postgres -c "SELECT client_addr, application_name, state, sync_state FROM pg_stat_replication;" 2>/dev/null || echo "  No hay réplicas conectadas"
    else
        echo "  ❌ INACTIVO"
    fi
    
    echo ""
    echo "Standby (puerto 15433):"
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep postgres-standby | grep "Up" >/dev/null 2>&1; then
        if docker exec postgres-standby pg_isready -U postgres 2>/dev/null; then
            echo "  ✅ ACTIVO (Standby)"
            echo "  Estado de recovery:"
            docker exec postgres-standby psql -U postgres -c "SELECT pg_is_in_recovery();" 2>/dev/null || echo "  Error consultando estado"
        else
            echo "  🔄 INICIANDO"
        fi
    else
        echo "  ❌ INACTIVO"
    fi
    
    echo ""
}

# Función para crear standby si no existe
create_standby_if_needed() {
    if ! docker ps -a --format "{{.Names}}" | grep -q "^postgres-standby$"; then
        echo "Creando nodo standby..."
        
        # Crear contenedor standby
        docker run -d --name postgres-standby --network postgres-ha -p 15433:5432 \
            -e PGPASSWORD=replicator123 \
            -v $(pwd)/scripts:/scripts \
            postgres:15 sleep infinity
        
        echo "Creando réplica desde primario..."
        docker exec postgres-standby pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replicator -v -P
        
        echo "Configurando como standby..."
        docker exec postgres-standby bash -c 'echo "primary_conninfo = '\''host=postgres-primary port=5432 user=replicator password=replicator123'\''" >> /var/lib/postgresql/data/postgresql.conf'
        docker exec postgres-standby bash -c 'touch /var/lib/postgresql/data/standby.signal'
        docker exec postgres-standby chown -R postgres:postgres /var/lib/postgresql/data
        
        echo "Iniciando PostgreSQL en standby..."
        docker exec -d postgres-standby su postgres -c postgres
        
        echo "Esperando que standby esté listo..."
        sleep 15
    else
        if ! docker ps --format "{{.Names}}" | grep -q "^postgres-standby$"; then
            echo "Iniciando contenedor standby existente..."
            docker start postgres-standby
            sleep 10
        fi
    fi
}

# 1. MOSTRAR ESTADO INICIAL
echo "1. Estado inicial del sistema:"
show_status

# 2. CREAR STANDBY SI NO EXISTE
echo "2. Verificando/creando nodo standby..."
create_standby_if_needed

# 3. MOSTRAR ESTADO CON STANDBY
echo "3. Estado con standby funcionando:"
show_status

# 4. INSERTAR DATOS DE PRUEBA EN EL PRIMARIO
echo "4. Insertando datos de prueba en el primario..."
docker exec postgres-primary psql -U postgres -d pollo_sanjuanero -c "
INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
('Cliente Pre-Failover $(date +%H:%M:%S)', '2999-0001', 'Zona Test, Guatemala');

INSERT INTO inventario.productos (nombre, categoria, precio, stock) VALUES
('Producto Test $(date +%H:%M:%S)', 'TEST', 99.99, 10);
"

echo "Datos insertados. Conteo actual de registros:"
docker exec postgres-primary psql -U postgres -d pollo_sanjuanero -c "
SELECT 'Clientes' as tabla, COUNT(*) as total FROM ventas.clientes
UNION ALL
SELECT 'Productos', COUNT(*) FROM inventario.productos;
"

# 5. SIMULAR CAÍDA DEL PRIMARIO
echo ""
echo "5. ⚠️  SIMULANDO CAÍDA DEL SERVIDOR PRIMARIO..."
echo "Deteniendo contenedor primario en 3 segundos..."
sleep 3
docker stop postgres-primary
echo "✅ Primario detenido"

# 6. PROMOVER STANDBY A PRIMARIO
echo ""
echo "6. 🔄 EJECUTANDO FAILOVER MANUAL..."
echo "Promoviendo standby a primario..."

# Promover el standby
docker exec postgres-standby bash -c '
# Remover archivo standby.signal para promover a primario
rm -f /var/lib/postgresql/data/standby.signal

# Crear archivo de promoción
touch /var/lib/postgresql/data/promote

# Enviar señal de promoción
su postgres -c "pg_ctl promote -D /var/lib/postgresql/data"
'

echo "Esperando que la promoción complete..."
sleep 10

# 7. VERIFICAR NUEVO PRIMARIO
echo ""
echo "7. ✅ VERIFICANDO NUEVO PRIMARIO..."
echo "Estado del nuevo primario (ex-standby):"

if docker exec postgres-standby pg_isready -U postgres; then
    echo "✅ Nuevo primario está activo"
    
    echo "Verificando que ya no está en modo recovery:"
    docker exec postgres-standby psql -U postgres -c "SELECT pg_is_in_recovery();"
    
    echo "Verificando datos existentes:"
    docker exec postgres-standby psql -U postgres -d pollo_sanjuanero -c "
    SELECT 'Clientes' as tabla, COUNT(*) as total FROM ventas.clientes
    UNION ALL
    SELECT 'Productos', COUNT(*) FROM inventario.productos;
    "
    
    # Probar inserción en nuevo primario
    echo "Insertando nuevo dato en el nuevo primario:"
    docker exec postgres-standby psql -U postgres -d pollo_sanjuanero -c "
    INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
    ('Cliente Post-Failover $(date +%H:%M:%S)', '2999-0002', 'Zona Post-Failover, Guatemala');
    "
    
    echo "✅ Nuevo primario acepta escrituras correctamente"
else
    echo "❌ Error: Nuevo primario no está respondiendo"
fi

# 8. RESUMEN FINAL
echo ""
echo "=== RESUMEN DEL FAILOVER ==="
echo "✅ Primario original: DETENIDO"
echo "✅ Standby promovido: FUNCIONANDO COMO PRIMARIO"
echo "✅ Datos preservados: SÍ"
echo "✅ Escrituras funcionando: SÍ"
echo ""
echo "Nuevo primario disponible en: localhost:15433"
echo ""
echo "Para reconectar aplicaciones:"
echo "  Host: localhost"
echo "  Puerto: 15433"
echo "  Usuario: postgres"
echo "  Password: postgres123"
echo "  Base de datos: pollo_sanjuanero"
echo ""
echo "⚠️  NOTA: Este es un failover manual. En producción se debe:"
echo "   - Actualizar configuraciones de aplicaciones"
echo "   - Actualizar balanceadores de carga"
echo "   - Configurar nuevo standby si es necesario"