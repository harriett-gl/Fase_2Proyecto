# Proceso Completo de Implementación - Sistema de Alta Disponibilidad PostgreSQL
## Con Indicaciones para Capturas de Pantalla

### Universidad Rafael Landívar
**Materia:** Base de Datos 2  
**Proyecto:** Sistema de Alta Disponibilidad - Pollo Sanjuanero S.A.  
**Fecha:** 16 de octubre de 2024

---

## 📸 **IMPORTANTE: Indicaciones para Capturas de Pantalla**

Cada sección marcada con 📸 requiere una captura de pantalla. Las capturas deben mostrar:
- **Terminal completo** con comandos y resultados
- **Archivos de configuración** abiertos en editor
- **Salidas de comandos** PostgreSQL con datos
- **Estados de contenedores** Docker

---

## 1. CONFIGURACIÓN INICIAL DEL PROYECTO

### 1.1 Estructura de Directorios

```bash
# Crear estructura del proyecto
mkdir -p config/{primary,standby,readonly} backups scripts documentacion
mkdir -p backups/wal_archive backups/full backups/incremental
```

**📸 CAPTURA 1:** Terminal mostrando la creación de directorios y resultado de `tree` o `ls -la`

### 1.2 Verificar Docker

```bash
# Verificar Docker disponible
docker --version
docker-compose --version
```

**📸 CAPTURA 2:** Versiones de Docker instaladas

---

## 2. CONFIGURACIÓN DEL NODO PRIMARIO

### 2.1 Crear Red Docker

```bash
# Crear red dedicada para PostgreSQL HA
docker network create postgres-ha
docker network ls | grep postgres-ha
```

**📸 CAPTURA 3:** Creación de red Docker y verificación

### 2.2 Iniciar Contenedor Primario

```bash
# Iniciar nodo primario
docker run -d --name postgres-primary --network postgres-ha -p 15432:5432 \
  -e POSTGRES_DB=pollo_sanjuanero \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -v $(pwd)/backups:/backups \
  -v $(pwd)/scripts:/scripts \
  postgres:15

# Verificar estado
docker ps | grep postgres-primary
```

**📸 CAPTURA 4:** Comando de creación del contenedor primario y verificación con `docker ps`

### 2.3 Esperar Inicialización

```bash
# Esperar que PostgreSQL esté listo
sleep 15
docker exec postgres-primary pg_isready -U postgres
```

**📸 CAPTURA 5:** Verificación de que PostgreSQL está listo para conexiones

---

## 3. INICIALIZACIÓN DE LA BASE DE DATOS

### 3.1 Ejecutar Script de Inicialización

```bash
# Ejecutar script de inicialización
docker exec postgres-primary psql -U postgres -f /scripts/init-primary.sql
```

**📸 CAPTURA 6:** Ejecución del script de inicialización mostrando:
- Creación de usuario replicator
- Creación de slots de replicación
- Creación de esquemas y tablas
- Inserción de datos iniciales

### 3.2 Verificar Datos Iniciales

```bash
# Conectar y verificar datos
docker exec postgres-primary psql -U postgres -d pollo_sanjuanero -c "
SELECT 'CLIENTES' as tabla, COUNT(*) as total FROM ventas.clientes
UNION ALL
SELECT 'PRODUCTOS', COUNT(*) FROM inventario.productos
UNION ALL
SELECT 'PEDIDOS', COUNT(*) FROM ventas.pedidos;
"
```

**📸 CAPTURA 7:** Consulta mostrando datos iniciales insertados en las tablas

---

## 4. CONFIGURACIÓN DE PARÁMETROS DE REPLICACIÓN

### 4.1 Configurar Parámetros WAL

```bash
# Configurar parámetros críticos de replicación
docker exec postgres-primary bash -c 'echo "wal_level = replica" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-primary bash -c 'echo "max_wal_senders = 3" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-primary bash -c 'echo "wal_keep_size = 1GB" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-primary bash -c 'echo "hot_standby = on" >> /var/lib/postgresql/data/postgresql.conf'
```

### 4.2 Configurar Permisos de Replicación

```bash
# Agregar permisos de replicación
docker exec postgres-primary bash -c 'echo "host replication replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf'
docker exec postgres-primary bash -c 'echo "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf'
```

### 4.3 Crear Directorio WAL Archive

```bash
# Crear directorio para archivos WAL
docker exec postgres-primary mkdir -p /backups/wal_archive
docker exec postgres-primary chown postgres:postgres /backups/wal_archive
```

### 4.4 Reiniciar Primario

```bash
# Reiniciar para aplicar configuración
docker restart postgres-primary
sleep 10
docker exec postgres-primary pg_isready -U postgres
```

**📸 CAPTURA 8:** Reinicio del contenedor primario y verificación de conectividad

---

## 5. VERIFICACIÓN DE CONFIGURACIÓN DE REPLICACIÓN

### 5.1 Verificar Parámetros Aplicados

```bash
# Verificar parámetros de replicación
docker exec postgres-primary psql -U postgres -c "
SELECT name, setting, context 
FROM pg_settings 
WHERE name IN ('wal_level', 'max_wal_senders', 'wal_keep_size', 'hot_standby');
"
```

**📸 CAPTURA 9:** Verificación de parámetros de replicación configurados correctamente

### 5.2 Verificar Slots de Replicación

```bash
# Verificar slots de replicación
docker exec postgres-primary psql -U postgres -c "
SELECT slot_name, slot_type, active, restart_lsn 
FROM pg_replication_slots;
"
```

**📸 CAPTURA 10:** Slots de replicación creados (standby_slot y readonly_slot)

---

## 6. PRUEBA DE REPLICACIÓN Y DATOS

### 6.1 Ejecutar Pruebas de Replicación

```bash
# Ejecutar script de pruebas
docker exec postgres-primary psql -U postgres -f /scripts/test-replication.sql
```

**📸 CAPTURA 11:** Ejecución de pruebas de replicación mostrando:
- Inserción de nuevos datos
- Actualización de inventario
- Conteos de registros por tabla
- Estado de slots de replicación

### 6.2 Verificar Datos de Pollo Sanjuanero

```bash
# Mostrar datos específicos de la empresa
docker exec postgres-primary psql -U postgres -d pollo_sanjuanero -c "
SELECT 'Últimos clientes registrados:' as titulo;
SELECT id, nombre, telefono, fecha_registro 
FROM ventas.clientes 
ORDER BY fecha_registro DESC 
LIMIT 5;
"
```

**📸 CAPTURA 12:** Datos de clientes de Pollo Sanjuanero insertados

### 6.3 Verificar Productos y Pedidos

```bash
# Mostrar inventario y pedidos
docker exec postgres-primary psql -U postgres -d pollo_sanjuanero -c "
SELECT 'Inventario actual:' as titulo;
SELECT nombre, categoria, precio, stock 
FROM inventario.productos 
ORDER BY nombre;

SELECT 'Pedidos recientes:' as titulo;
SELECT p.id, c.nombre as cliente, p.total, p.estado
FROM ventas.pedidos p
JOIN ventas.clientes c ON p.cliente_id = c.id
ORDER BY p.fecha_pedido DESC;
"
```

**📸 CAPTURA 13:** Inventario de productos y pedidos del sistema

---

## 7. CONFIGURACIÓN DE POLÍTICA DE RESPALDOS

### 7.1 Configurar Directorios de Backup

```bash
# Configurar sistema de respaldos
./scripts/backup-policy.sh setup
```

**📸 CAPTURA 14:** Configuración inicial del sistema de respaldos

### 7.2 Ejecutar Backup Completo

```bash
# Ejecutar backup completo
./scripts/backup-policy.sh full
```

**📸 CAPTURA 15:** Ejecución de backup completo mostrando:
- Proceso de pg_basebackup
- Tiempo de ejecución
- Tamaño del backup generado
- Confirmación de éxito

### 7.3 Ejecutar Backup Incremental

```bash
# Ejecutar backup incremental
./scripts/backup-policy.sh incremental
```

**📸 CAPTURA 16:** Ejecución de backup incremental con archivos WAL

### 7.4 Verificar Estado de Backups

```bash
# Verificar estado de backups
./scripts/backup-policy.sh status
```

**📸 CAPTURA 17:** Estado completo del sistema de backups mostrando:
- Backups completos disponibles
- Backups incrementales
- Archivos WAL archivados
- Espacio utilizado

---

## 8. CREACIÓN Y CONFIGURACIÓN DEL NODO STANDBY

### 8.1 Crear Contenedor Standby

```bash
# Crear contenedor standby
docker run -d --name postgres-standby --network postgres-ha -p 15433:5432 \
  -e PGPASSWORD=replicator123 postgres:15 sleep infinity
```

### 8.2 Crear Réplica Base

```bash
# Crear réplica desde primario
docker exec postgres-standby pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replicator -v -P
```

**📸 CAPTURA 18:** Proceso de pg_basebackup creando la réplica standby

### 8.3 Configurar Standby

```bash
# Configurar como standby
docker exec postgres-standby bash -c 'echo "primary_conninfo = '\''host=postgres-primary port=5432 user=replicator password=replicator123'\''" >> /var/lib/postgresql/data/postgresql.conf'
docker exec postgres-standby bash -c 'touch /var/lib/postgresql/data/standby.signal'
docker exec postgres-standby chown -R postgres:postgres /var/lib/postgresql/data
```

### 8.4 Iniciar PostgreSQL en Standby

```bash
# Iniciar PostgreSQL en modo standby
docker exec -d postgres-standby su postgres -c postgres
sleep 10
docker exec postgres-standby pg_isready -U postgres
```

**📸 CAPTURA 19:** Verificación de que el nodo standby está funcionando

---

## 9. DEMOSTRACIÓN DE FAILOVER MANUAL

### 9.1 Verificar Estado Inicial

```bash
# Verificar estado antes del failover
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**📸 CAPTURA 20:** Estado de contenedores antes del failover

### 9.2 Insertar Datos de Prueba

```bash
# Insertar datos para verificar continuidad
docker exec postgres-primary psql -U postgres -d pollo_sanjuanero -c "
INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
('Cliente Pre-Failover $(date +%H:%M:%S)', '9999-TEST', 'Zona Failover, Guatemala');
"
```

### 9.3 Ejecutar Demo de Failover

```bash
# Ejecutar demo de failover
./scripts/demo-failover.sh
```

**📸 CAPTURA 21:** Ejecución completa del script de failover mostrando:
- Creación del nodo standby
- Inserción de datos de prueba
- Simulación de caída del primario
- Promoción del standby a primario
- Verificación de funcionamiento

---

## 10. VERIFICACIÓN POST-FAILOVER

### 10.1 Verificar Nuevo Primario

```bash
# Verificar que el antiguo standby ahora es primario
docker exec postgres-standby psql -U postgres -c "SELECT pg_is_in_recovery();"
```

**📸 CAPTURA 22:** Verificación de que el nodo ya no está en modo recovery

### 10.2 Probar Escrituras en Nuevo Primario

```bash
# Probar escritura en el nuevo primario
docker exec postgres-standby psql -U postgres -d pollo_sanjuanero -c "
INSERT INTO ventas.clientes (nombre, telefono, direccion) VALUES
('Cliente Post-Failover $(date +%H:%M:%S)', '8888-TEST', 'Zona Post-Failover, Guatemala');

SELECT nombre, telefono FROM ventas.clientes 
WHERE telefono LIKE '%TEST%' 
ORDER BY fecha_registro DESC;
"
```

**📸 CAPTURA 23:** Datos antes y después del failover, demostrando continuidad

---

## 11. ANÁLISIS DE ALTERNATIVAS Y COSTOS

### 11.1 Mostrar Análisis Comparativo

```bash
# Mostrar contenido del análisis de costos
head -50 documentacion/investigacion-costos-alternativas.md
```

**📸 CAPTURA 24:** Inicio del documento de investigación de alternativas

### 11.2 Tabla Comparativa de Costos

```bash
# Mostrar tabla de costos (líneas específicas del documento)
sed -n '143,151p' documentacion/investigacion-costos-alternativas.md
```

**📸 CAPTURA 25:** Tabla comparativa de costos de software por 3 años

### 11.3 Matriz de Decisión

```bash
# Mostrar matriz de evaluación
sed -n '232,248p' documentacion/investigacion-costos-alternativas.md
```

**📸 CAPTURA 26:** Matriz de decisión con puntajes de cada alternativa

---

## 12. VERIFICACIÓN FINAL COMPLETA

### 12.1 Ejecutar Verificación Integral

```bash
# Ejecutar script de verificación final
./scripts/verificar-proyecto.sh
```

**📸 CAPTURA 27:** Ejecución completa del script de verificación mostrando:
- Estado de estructura del proyecto
- Configuraciones PostgreSQL
- Scripts de automatización
- Documentación técnica
- Estado de contenedores
- Conectividad de base de datos
- Sistema de respaldos
- Parámetros críticos
- Métricas de documentación
- Resumen final del proyecto

---

## 13. EVIDENCIAS DE DOCUMENTACIÓN

### 13.1 Estructura de Archivos

```bash
# Mostrar estructura completa del proyecto
find . -type f -name "*.md" -o -name "*.sql" -o -name "*.sh" -o -name "*.yml" -o -name "*.conf" | sort
```

**📸 CAPTURA 28:** Lista completa de archivos del proyecto

### 13.2 Métricas de Documentación

```bash
# Contar líneas de documentación
echo "=== MÉTRICAS DE DOCUMENTACIÓN ==="
echo "README.md: $(wc -l < README.md) líneas"
echo "Investigación costos: $(wc -l < documentacion/investigacion-costos-alternativas.md) líneas"
echo "Resumen ejecutivo: $(wc -l < documentacion/resumen-ejecutivo.md) líneas"
echo "Scripts SQL: $(find scripts -name "*.sql" -exec wc -l {} + | tail -1)"
echo "Scripts Bash: $(find scripts -name "*.sh" -exec wc -l {} + | tail -1)"
```

**📸 CAPTURA 29:** Métricas de documentación generada

---

## 14. COMPROBACIONES TÉCNICAS FINALES

### 14.1 Estado de Slots de Replicación

```bash
# Verificar slots de replicación (en primario original si está activo, sino en nuevo primario)
docker exec postgres-primary psql -U postgres -c "
SELECT 
    slot_name,
    slot_type,
    database,
    active,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots;" 2>/dev/null || \
docker exec postgres-standby psql -U postgres -c "
SELECT 
    slot_name,
    slot_type,
    database,
    active,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots;"
```

**📸 CAPTURA 30:** Estado final de slots de replicación

### 14.2 Resumen de Datos Finales

```bash
# Resumen final de datos en el sistema
docker exec postgres-standby psql -U postgres -d pollo_sanjuanero -c "
SELECT 'RESUMEN FINAL DE DATOS' as titulo;
SELECT 'Clientes totales:' as metric, COUNT(*)::text as valor FROM ventas.clientes
UNION ALL
SELECT 'Productos disponibles:', COUNT(*)::text FROM inventario.productos  
UNION ALL
SELECT 'Pedidos procesados:', COUNT(*)::text FROM ventas.pedidos
UNION ALL
SELECT 'Registros de auditoría:', COUNT(*)::text FROM administracion.audit_trail;
"
```

**📸 CAPTURA 31:** Resumen final de todos los datos en el sistema

---

## 15. CONCLUSIONES Y ESTADO FINAL

### 15.1 Estado de Contenedores Docker

```bash
# Estado final de todos los contenedores
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
```

**📸 CAPTURA 32:** Estado final de todos los contenedores Docker

### 15.2 Uso de Recursos

```bash
# Mostrar uso de recursos
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
```

**📸 CAPTURA 33:** Uso de recursos de los contenedores

---

## 📋 RESUMEN DE CAPTURAS REQUERIDAS

**Total de capturas necesarias: 33**

### Capturas por Categoría:
1. **Configuración inicial** (Capturas 1-5): Estructura, Docker, red, contenedor primario
2. **Inicialización BD** (Capturas 6-7): Scripts de inicialización y datos
3. **Configuración replicación** (Capturas 8-10): Parámetros WAL, reinicio, verificación
4. **Pruebas de datos** (Capturas 11-13): Pruebas de replicación, datos empresa
5. **Sistema de respaldos** (Capturas 14-17): Setup, backups full/incremental, estado
6. **Nodo standby** (Capturas 18-19): Creación de réplica y configuración
7. **Failover manual** (Capturas 20-23): Demo completa de failover
8. **Análisis de costos** (Capturas 24-26): Documentación de alternativas
9. **Verificación final** (Capturas 27-33): Scripts de verificación, métricas, estado final

### Notas Importantes para las Capturas:
- **Usar terminal con fondo oscuro** para mejor contraste
- **Capturar pantalla completa** incluyendo prompt
- **Asegurar que el texto sea legible** en el tamaño final
- **Incluir timestamps** cuando sea relevante
- **Mostrar comandos completos** y sus resultados

---

*Este documento sirve como guía completa para la ejecución y documentación del proyecto con todas las evidencias visuales necesarias para el reporte final.*