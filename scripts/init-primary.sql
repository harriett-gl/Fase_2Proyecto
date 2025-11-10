-- Script de Inicialización del Nodo Primario
-- Proyecto: Sistema Alta Disponibilidad - Pollo Sanjuanero S.A.

-- Crear usuario de replicación
CREATE USER replicator WITH REPLICATION PASSWORD 'replicator123';

-- Crear slots de replicación para los nodos
SELECT pg_create_physical_replication_slot('standby_slot');
SELECT pg_create_physical_replication_slot('readonly_slot');

-- Crear base de datos para Pollo Sanjuanero
CREATE DATABASE pollo_sanjuanero;

-- Conectar a la base de datos
\c pollo_sanjuanero;

-- Crear esquema de ejemplo para pruebas
CREATE SCHEMA IF NOT EXISTS ventas;
CREATE SCHEMA IF NOT EXISTS inventario;
CREATE SCHEMA IF NOT EXISTS administracion;

-- Crear tablas de ejemplo
CREATE TABLE ventas.clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20),
    direccion TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inventario.productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(50),
    precio DECIMAL(10,2),
    stock INTEGER DEFAULT 0,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ventas.pedidos (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER REFERENCES ventas.clientes(id),
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10,2),
    estado VARCHAR(20) DEFAULT 'PENDIENTE'
);

CREATE TABLE ventas.detalle_pedidos (
    id SERIAL PRIMARY KEY,
    pedido_id INTEGER REFERENCES ventas.pedidos(id),
    producto_id INTEGER REFERENCES inventario.productos(id),
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2)
);

-- Insertar datos de ejemplo
INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
('Restaurante El Buen Sabor', '2234-5678', 'Zona 10, Guatemala'),
('Comedor Universitario', '2456-7890', 'Zona 12, Guatemala'),
('Cafetería Central', '2678-9012', 'Zona 1, Guatemala'),
('Hotel Intercontinental', '2890-1234', 'Zona 9, Guatemala'),
('Supermercado La Barata', '2012-3456', 'Zona 7, Guatemala');

INSERT INTO inventario.productos (nombre, categoria, precio, stock) VALUES
('Pollo Entero', 'POLLO', 45.00, 100),
('Pechuga de Pollo', 'POLLO', 65.00, 50),
('Muslos de Pollo', 'POLLO', 35.00, 75),
('Alitas de Pollo', 'POLLO', 40.00, 60),
('Pollo Deshuesado', 'POLLO', 80.00, 30);

INSERT INTO ventas.pedidos (cliente_id, total, estado) VALUES
(1, 450.00, 'COMPLETADO'),
(2, 320.00, 'PENDIENTE'),
(3, 160.00, 'COMPLETADO'),
(4, 520.00, 'EN_PROCESO'),
(5, 280.00, 'PENDIENTE');

INSERT INTO ventas.detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario) VALUES
(1, 1, 10, 45.00),
(2, 2, 5, 65.00),
(3, 3, 4, 35.00),
(4, 1, 8, 45.00),
(4, 4, 6, 40.00),
(5, 5, 4, 80.00);

-- Crear índices para mejor rendimiento
CREATE INDEX idx_clientes_nombre ON ventas.clientes(nombre);
CREATE INDEX idx_productos_categoria ON inventario.productos(categoria);
CREATE INDEX idx_pedidos_fecha ON ventas.pedidos(fecha_pedido);
CREATE INDEX idx_pedidos_cliente ON ventas.pedidos(cliente_id);

-- Crear vistas para reportes
CREATE VIEW ventas.reporte_ventas_diarias AS
SELECT 
    DATE(fecha_pedido) as fecha,
    COUNT(*) as total_pedidos,
    SUM(total) as monto_total,
    AVG(total) as promedio_pedido
FROM ventas.pedidos 
WHERE estado = 'COMPLETADO'
GROUP BY DATE(fecha_pedido)
ORDER BY fecha DESC;

-- Crear función para auditoría
CREATE OR REPLACE FUNCTION administracion.audit_log()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO administracion.audit_trail (
        tabla, operacion, usuario, fecha, datos_anteriores, datos_nuevos
    ) VALUES (
        TG_TABLE_NAME, TG_OP, current_user, now(), 
        CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) ELSE NULL END
    );
    
    RETURN CASE 
        WHEN TG_OP = 'DELETE' THEN OLD 
        ELSE NEW 
    END;
END;
$$ LANGUAGE plpgsql;

-- Crear tabla de auditoría
CREATE TABLE administracion.audit_trail (
    id SERIAL PRIMARY KEY,
    tabla VARCHAR(50),
    operacion VARCHAR(10),
    usuario VARCHAR(50),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    datos_anteriores JSONB,
    datos_nuevos JSONB
);

-- Aplicar triggers de auditoría
CREATE TRIGGER audit_clientes 
    AFTER INSERT OR UPDATE OR DELETE ON ventas.clientes
    FOR EACH ROW EXECUTE FUNCTION administracion.audit_log();

CREATE TRIGGER audit_productos 
    AFTER INSERT OR UPDATE OR DELETE ON inventario.productos
    FOR EACH ROW EXECUTE FUNCTION administracion.audit_log();

-- Mostrar estado de replicación
SELECT slot_name, slot_type, active, restart_lsn 
FROM pg_replication_slots;