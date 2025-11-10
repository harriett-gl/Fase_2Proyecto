-- Script de Prueba de Replicación
-- Proyecto: Sistema Alta Disponibilidad - Pollo Sanjuanero S.A.

-- Conectar a la base de datos
\c pollo_sanjuanero;

-- 1. INSERTAR DATOS DE PRUEBA (ejecutar en primario)
INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
('Restaurante Los Cebollines', '2334-5678', 'Zona 4, Guatemala'),
('Hotel Real InterContinental', '2445-6789', 'Zona 10, Guatemala'),
('Panadería San Martín', '2556-7890', 'Zona 3, Guatemala');

-- 2. ACTUALIZAR DATOS EXISTENTES
UPDATE inventario.productos 
SET stock = stock + 25, fecha_actualizacion = CURRENT_TIMESTAMP 
WHERE categoria = 'POLLO';

-- 3. INSERTAR NUEVO PEDIDO
INSERT INTO ventas.pedidos (cliente_id, total, estado) VALUES
((SELECT id FROM ventas.clientes WHERE nombre = 'Restaurante Los Cebollines'), 380.00, 'PENDIENTE');

-- 4. INSERTAR DETALLES DEL PEDIDO
INSERT INTO ventas.detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario) VALUES
((SELECT MAX(id) FROM ventas.pedidos), 1, 5, 45.00),
((SELECT MAX(id) FROM ventas.pedidos), 3, 3, 35.00),
((SELECT MAX(id) FROM ventas.pedidos), 4, 4, 40.00);

-- 5. MOSTRAR DATOS PARA VERIFICACIÓN
SELECT 'CLIENTES' as tabla, COUNT(*) as total_registros FROM ventas.clientes
UNION ALL
SELECT 'PRODUCTOS', COUNT(*) FROM inventario.productos
UNION ALL
SELECT 'PEDIDOS', COUNT(*) FROM ventas.pedidos
UNION ALL
SELECT 'DETALLES', COUNT(*) FROM ventas.detalle_pedidos;

-- 6. MOSTRAR ÚLTIMOS CLIENTES AGREGADOS
SELECT 'Últimos clientes agregados:' as titulo;
SELECT id, nombre, fecha_registro 
FROM ventas.clientes 
ORDER BY fecha_registro DESC 
LIMIT 5;

-- 7. MOSTRAR ESTADO ACTUAL DEL INVENTARIO
SELECT 'Estado actual del inventario:' as titulo;
SELECT nombre, categoria, precio, stock, fecha_actualizacion 
FROM inventario.productos 
ORDER BY fecha_actualizacion DESC;

-- 8. MOSTRAR PEDIDOS RECIENTES
SELECT 'Pedidos recientes:' as titulo;
SELECT p.id, c.nombre as cliente, p.fecha_pedido, p.total, p.estado
FROM ventas.pedidos p
JOIN ventas.clientes c ON p.cliente_id = c.id
ORDER BY p.fecha_pedido DESC
LIMIT 5;

-- 9. TRANSACCIÓN COMPLEJA PARA PROBAR REPLICACIÓN
BEGIN;
    -- Crear nuevo cliente
    INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
    ('Comedor Industrial XYZ', '2667-8901', 'Zona 18, Guatemala');
    
    -- Crear pedido para el nuevo cliente
    INSERT INTO ventas.pedidos (cliente_id, total, estado) VALUES
    (LASTVAL(), 0, 'EN_PROCESO');
    
    -- Agregar productos al pedido
    INSERT INTO ventas.detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario)
    SELECT 
        LASTVAL(),
        p.id,
        CASE WHEN p.nombre = 'Pollo Entero' THEN 10
             WHEN p.nombre = 'Pechuga de Pollo' THEN 5
             ELSE 3 END,
        p.precio
    FROM inventario.productos p
    WHERE p.categoria = 'POLLO'
    LIMIT 3;
    
    -- Actualizar el total del pedido
    UPDATE ventas.pedidos 
    SET total = (
        SELECT SUM(cantidad * precio_unitario)
        FROM ventas.detalle_pedidos
        WHERE pedido_id = CURRVAL('ventas.pedidos_id_seq')
    )
    WHERE id = CURRVAL('ventas.pedidos_id_seq');
    
    -- Reducir stock de productos
    UPDATE inventario.productos 
    SET stock = stock - 5,
        fecha_actualizacion = CURRENT_TIMESTAMP
    WHERE categoria = 'POLLO';
    
COMMIT;

-- 10. CREAR DATOS DE PRUEBA PARA VERIFICAR EN TIEMPO REAL
CREATE TEMP TABLE replication_test AS
SELECT 
    'TEST_' || generate_series(1,10) as test_id,
    'Cliente de Prueba ' || generate_series(1,10) as nombre,
    '2000-' || LPAD(generate_series(1,10)::text, 4, '0') as telefono,
    CURRENT_TIMESTAMP as fecha_creacion;

INSERT INTO ventas.clientes (nombre, telefono, direccion)
SELECT nombre, telefono, 'Dirección de Prueba - Zona ' || (random()*20)::int
FROM replication_test;

-- 11. MOSTRAR RESUMEN FINAL
SELECT 
    'RESUMEN FINAL DE DATOS:' as titulo,
    '' as detalle
UNION ALL
SELECT 
    'Total Clientes:', COUNT(*)::text
FROM ventas.clientes
UNION ALL
SELECT 
    'Total Productos:', COUNT(*)::text
FROM inventario.productos
UNION ALL
SELECT 
    'Total Pedidos:', COUNT(*)::text
FROM ventas.pedidos
UNION ALL
SELECT 
    'Total Registros Auditoría:', COUNT(*)::text
FROM administracion.audit_trail;

-- 12. CONSULTA DE MONITOREO DE REPLICACIÓN (solo en primario)
SELECT 
    client_addr as replica_ip,
    application_name as replica_name,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state
FROM pg_stat_replication;

-- 13. MOSTRAR SLOTS DE REPLICACIÓN
SELECT 
    slot_name,
    slot_type,
    database,
    active,
    restart_lsn
FROM pg_replication_slots;