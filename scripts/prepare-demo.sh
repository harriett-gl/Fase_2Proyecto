#!/bin/bash

# Script de Preparación para la Demostración
# Sistema de Alta Disponibilidad PostgreSQL - Pollo Sanjuanero S.A.

set -e

echo "🔧 PREPARANDO INFRAESTRUCTURA PARA LA DEMOSTRACIÓN..."
echo ""

# Limpiar contenedores anteriores
echo "1. Limpiando contenedores anteriores..."
docker rm -f postgres-primary postgres-standby postgres-readonly some-postgres 2>/dev/null || true

# Crear red si no existe
echo "2. Configurando red Docker..."
docker network rm postgres-ha 2>/dev/null || true
docker network create postgres-ha

# Crear contenedor primario
echo "3. Creando nodo PRIMARIO..."
docker run -d --name postgres-primary --network postgres-ha -p 15432:5432 \
    -e POSTGRES_PASSWORD=admin123 \
    -e POSTGRES_DB=pollo_sanjuanero \
    postgres:15

# Esperar a que el primario esté listo
echo "4. Esperando a que el primario esté listo..."
sleep 15
while ! docker exec postgres-primary pg_isready -U postgres > /dev/null 2>&1; do
    echo "   Esperando PostgreSQL primario..."
    sleep 5
done

# Configurar replicación en el primario
echo "5. Configurando replicación en el primario..."
docker exec postgres-primary psql -U postgres -c "
CREATE USER replicator WITH REPLICATION PASSWORD 'replicator123';
"

docker exec postgres-primary bash -c 'echo "wal_level = replica" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-primary bash -c 'echo "max_wal_senders = 10" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-primary bash -c 'echo "max_replication_slots = 10" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-primary bash -c 'echo "hot_standby = on" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-primary bash -c 'echo "host replication replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf'

# Reiniciar primario para aplicar configuración
echo "6. Reiniciando primario para aplicar configuración..."
docker restart postgres-primary
sleep 10

# Crear datos de ejemplo
echo "7. Creando base de datos empresarial..."
docker exec postgres-primary psql -U postgres -d pollo_sanjuanero -c "
-- Crear esquemas
CREATE SCHEMA IF NOT EXISTS ventas;
CREATE SCHEMA IF NOT EXISTS inventario;

-- Tabla de clientes
CREATE TABLE IF NOT EXISTS ventas.clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(15),
    direccion TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de productos
CREATE TABLE IF NOT EXISTS inventario.productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(50),
    precio DECIMAL(10,2),
    stock INTEGER DEFAULT 0
);

-- Tabla de pedidos
CREATE TABLE IF NOT EXISTS ventas.pedidos (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER REFERENCES ventas.clientes(id),
    producto_id INTEGER REFERENCES inventario.productos(id),
    cantidad INTEGER,
    total DECIMAL(10,2),
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar datos de ejemplo
INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
('Restaurante La Esquina', '2345-6789', 'Zona 1, Guatemala'),
('Comedor Mary', '2456-7890', 'Zona 10, Guatemala'),
('Cafetería Central', '2567-8901', 'Zona 4, Guatemala'),
('Hotel Plaza', '2678-9012', 'Zona 9, Guatemala'),
('Pollo Rey', '2789-0123', 'Zona 12, Guatemala');

INSERT INTO inventario.productos (nombre, categoria, precio, stock) VALUES
('Pollo Entero Fresco', 'Pollo Entero', 45.00, 100),
('Pechuga de Pollo', 'Cortes', 65.00, 80),
('Muslos de Pollo', 'Cortes', 35.00, 120),
('Alitas de Pollo', 'Cortes', 25.00, 150),
('Pollo Marinado', 'Especialidades', 55.00, 60);

INSERT INTO ventas.pedidos (cliente_id, producto_id, cantidad, total) VALUES
(1, 1, 5, 225.00),
(2, 2, 3, 195.00),
(3, 3, 8, 280.00),
(4, 4, 10, 250.00),
(5, 5, 4, 220.00);
"

# Crear slot de replicación
echo "8. Creando slot de replicación..."
docker exec postgres-primary psql -U postgres -c "SELECT pg_create_physical_replication_slot('standby_slot');" 2>/dev/null || true

# Crear contenedor standby
echo "9. Creando nodo STANDBY..."
docker run -d --name postgres-standby --network postgres-ha -p 15433:5432 \
    -e PGPASSWORD=replicator123 postgres:15 sleep infinity

# Configurar standby
echo "10. Configurando nodo standby..."
docker exec postgres-standby pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replicator -v -P -W

docker exec postgres-standby bash -c 'echo "primary_conninfo = '\''host=postgres-primary port=5432 user=replicator password=replicator123 application_name=standby'\'' " >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-standby bash -c 'echo "primary_slot_name = '\''standby_slot'\''" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-standby bash -c 'echo "hot_standby = on" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-standby bash -c 'touch /var/lib/postgresql/data/standby.signal'
docker exec postgres-standby chown -R postgres:postgres /var/lib/postgresql/data

# Iniciar standby
echo "11. Iniciando PostgreSQL en standby..."
docker exec -d postgres-standby su postgres -c postgres
sleep 10

# Verificar estado
echo "12. Verificando estado de la infraestructura..."
echo ""
echo "🔵 PRIMARIO (puerto 15432):"
if docker exec postgres-primary pg_isready -U postgres > /dev/null 2>&1; then
    echo "   ✅ ACTIVO"
else
    echo "   ❌ INACTIVO"
fi

echo ""
echo "🟡 STANDBY (puerto 15433):"
sleep 5
if docker exec postgres-standby pg_isready -U postgres > /dev/null 2>&1; then
    echo "   ✅ ACTIVO"
else
    echo "   🔄 INICIANDO..."
fi

echo ""
echo "✅ INFRAESTRUCTURA LISTA PARA LA DEMOSTRACIÓN"
echo ""
echo "Para ejecutar la demostración completa:"
echo "./scripts/demo-presentacion.sh"