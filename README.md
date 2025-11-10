# Sistema de Alta Disponibilidad PostgreSQL
## Proyecto Final - Base de Datos 2

### Universidad Rafael Landívar
**Materia:** Base de Datos 2  
**Segundo Semestre 2025**  
**Fecha:** 16 de octubre de 2024  
**Empresa:** Pollo Sanjuanero S.A.

---

## 📋 Descripción del Proyecto

Este proyecto implementa un **sistema de alta disponibilidad** para bases de datos PostgreSQL, diseñado para la empresa Pollo Sanjuanero S.A. El sistema incluye replicación streaming, failover manual, y una política de respaldos con retención de 7 días.

### 🎯 Objetivos Cumplidos

✅ **Arquitectura de 3 nodos:**
- **Nodo Primario:** Acepta lecturas y escrituras
- **Nodo Standby:** Réplica en espera para failover
- **Nodo de Solo Lectura:** Optimizado para consultas

✅ **Replicación Streaming:** Configurada entre los 3 nodos  
✅ **Failover Manual:** Implementado con scripts automatizados  
✅ **Política de Respaldos:** Full backup semanal + incrementales diarios  
✅ **Retención de Datos:** Configurada para 7 días automáticamente  
✅ **Análisis de Costos:** Comparativa completa de alternativas tecnológicas

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nodo Primario │    │  Nodo Standby   │    │ Nodo Solo Lectura│
│  (Puerto 15432) │    │  (Puerto 15433) │    │  (Puerto 15434) │
│                 │    │                 │    │                 │
│ ✅ Lecturas     │────▶│ 📥 Streaming    │    │ 📥 Streaming    │
│ ✅ Escrituras   │    │ 🔄 Failover     │    │ 📖 Solo Lectura │
│ 💾 Backups      │    │ 📊 Monitoreo    │    │ 📊 Reportes     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Sistema de Backups                          │
│  📦 Full Backup (Semanal) + 📊 Incremental (Diario)          │
│  🗑️ Retención automática de 7 días                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Instalación y Configuración

### Pre-requisitos

- **Docker** y **Docker Compose** instalados
- **PostgreSQL Client** (psql) para pruebas
- **Bash** para ejecutar scripts
- Al menos **8GB RAM** disponible
- **Red estable** entre nodos

### 1. Clonar el Repositorio

```bash
git clone <repository-url>
cd proyecto_Bases_2
```

### 2. Configuración Inicial

El proyecto incluye todas las configuraciones necesarias:

```
proyecto_Bases_2/
├── config/
│   ├── primary/          # Configuración nodo primario
│   ├── standby/          # Configuración nodo standby
│   └── readonly/         # Configuración nodo solo lectura
├── scripts/              # Scripts de automatización
├── backups/              # Directorio de respaldos
└── documentacion/        # Documentación completa
```

### 3. Iniciar el Sistema

#### Opción A: Inicio Completo Automático
```bash
# Crear red Docker
docker network create postgres-ha

# Iniciar nodo primario
docker run -d --name postgres-primary --network postgres-ha -p 15432:5432 \
  -e POSTGRES_DB=pollo_sanjuanero \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -v $(pwd)/backups:/backups \
  -v $(pwd)/scripts:/scripts \
  postgres:15

# Esperar y configurar
sleep 15
```

#### Opción B: Usando Docker Compose (Simplificado)
```bash
docker-compose -f docker-compose-final.yml up -d
```

### 4. Configurar Replicación

```bash
# Ejecutar configuración de replicación
./scripts/setup-replication.sh
```

---

## 📊 Uso del Sistema

### Conexiones a los Nodos

#### Nodo Primario (Lectura/Escritura)
```bash
psql -h localhost -p 15432 -U postgres -d pollo_sanjuanero
```

#### Nodo Standby (Failover)
```bash
psql -h localhost -p 15433 -U postgres -d pollo_sanjuanero
```

#### Nodo Solo Lectura (Consultas)
```bash
psql -h localhost -p 15434 -U postgres -d pollo_sanjuanero
```

**Credenciales:**
- **Usuario:** `postgres`
- **Contraseña:** `postgres123`
- **Base de Datos:** `pollo_sanjuanero`

### Probar Replicación

```bash
# Ejecutar pruebas de replicación
docker exec postgres-primary psql -U postgres -f /scripts/test-replication.sql
```

### Ejecutar Failover Manual

```bash
# Simular falla y failover
./scripts/demo-failover.sh
```

### Gestión de Respaldos

```bash
# Configurar directorios de backup
./scripts/backup-policy.sh setup

# Ejecutar backup completo
./scripts/backup-policy.sh full

# Ejecutar backup incremental
./scripts/backup-policy.sh incremental

# Ver estado de backups
./scripts/backup-policy.sh status
```

---

## 📈 Monitoreo y Administración

### Estado de Replicación

```sql
-- En el nodo primario
SELECT client_addr, application_name, state, sync_state 
FROM pg_stat_replication;

-- Verificar slots de replicación
SELECT slot_name, slot_type, active, restart_lsn 
FROM pg_replication_slots;
```

### Estado de los Nodos

```sql
-- Verificar si está en modo recovery (standby)
SELECT pg_is_in_recovery();

-- Ver último WAL recibido
SELECT pg_last_wal_receive_lsn();

-- Ver último WAL aplicado  
SELECT pg_last_wal_replay_lsn();
```

### Logs del Sistema

```bash
# Ver logs de cada nodo
docker logs postgres-primary
docker logs postgres-standby  
docker logs postgres-readonly

# Logs de backup
tail -f backups/backup.log
```

---

## 🔧 Scripts Disponibles

| Script | Descripción | Uso |
|--------|-------------|-----|
| `setup-replication.sh` | Configuración inicial completa | `./scripts/setup-replication.sh` |
| `demo-failover.sh` | Demostración de failover | `./scripts/demo-failover.sh` |
| `backup-policy.sh` | Gestión de respaldos | `./scripts/backup-policy.sh [comando]` |
| `init-primary.sql` | Inicialización del primario | Ejecutado automáticamente |
| `test-replication.sql` | Pruebas de replicación | Ejecutado vía psql |

### Comandos de Backup

```bash
./scripts/backup-policy.sh setup        # Configurar
./scripts/backup-policy.sh full         # Backup completo
./scripts/backup-policy.sh incremental  # Backup incremental
./scripts/backup-policy.sh status       # Estado actual
./scripts/backup-policy.sh cleanup      # Limpiar antiguos
```

---

## 🛠️ Configuraciones Técnicas

### Parámetros Clave PostgreSQL

#### Nodo Primario
- `wal_level = replica`
- `max_wal_senders = 3`  
- `wal_keep_size = 1GB`
- `archive_mode = on`
- `hot_standby = on`

#### Nodos Secundarios  
- `primary_conninfo = 'host=postgres-primary...'`
- `standby.signal` (archivo de control)
- `hot_standby = on`
- `max_standby_streaming_delay = 300s`

### Puertos y Red

- **Primario:** localhost:15432
- **Standby:** localhost:15433  
- **Solo Lectura:** localhost:15434
- **Red Docker:** `postgres-ha`

---

## 📚 Documentación Adicional

### Archivos de Documentación

- [`documentacion/investigacion-costos-alternativas.md`](documentacion/investigacion-costos-alternativas.md) - Análisis completo de alternativas y costos
- Configuraciones en `config/` - Archivos postgresql.conf y pg_hba.conf
- Scripts comentados en `scripts/` - Lógica de implementación

### Estructura de la Base de Datos

**Esquemas creados:**
- `ventas` - Gestión de clientes, pedidos y ventas
- `inventario` - Control de productos y stock  
- `administracion` - Auditoría y logs del sistema

**Tablas principales:**
- `ventas.clientes` - Información de clientes
- `inventario.productos` - Catálogo de productos
- `ventas.pedidos` - Órdenes de compra
- `administracion.audit_trail` - Auditoría automática

---

## 🔍 Troubleshooting

### Problemas Comunes

#### 1. Error de Conexión
```bash
# Verificar que el contenedor está corriendo
docker ps

# Reiniciar si es necesario
docker restart postgres-primary
```

#### 2. Replicación No Funciona
```bash
# Verificar logs
docker logs postgres-standby

# Verificar configuración de red
docker network ls
docker network inspect postgres-ha
```

#### 3. Espacio de Backup
```bash
# Verificar espacio disponible
du -sh backups/*

# Limpiar backups antiguos
./scripts/backup-policy.sh cleanup
```

#### 4. Failover No Responde
```bash
# Verificar estado del standby
docker exec postgres-standby pg_isready -U postgres

# Verificar archivos de recovery
docker exec postgres-standby ls -la /var/lib/postgresql/data/ | grep signal
```

### Comandos de Diagnóstico

```bash
# Estado general del sistema
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Uso de recursos
docker stats --no-stream

# Verificar configuración
docker exec postgres-primary cat /var/lib/postgresql/data/postgresql.conf | grep -E "(wal_level|max_wal_senders|hot_standby)"
```

---

## 📊 Métricas y KPIs

### Indicadores de Rendimiento

- **RTO (Recovery Time Objective):** < 5 minutos
- **RPO (Recovery Point Objective):** < 1 minuto  
- **Disponibilidad:** 99.9% objetivo
- **Replicación Lag:** < 100ms en red local

### Métricas de Backup

- **Full Backup:** Semanal, ~30MB comprimido
- **Incremental:** Diario, ~5-10MB por día  
- **Retención:** 7 días automática
- **Tiempo de Backup:** < 2 minutos para full

---

## 👥 Equipo de Desarrollo

**Universidad Rafael Landívar**  
**Curso:** Base de Datos 2 - Segundo Semestre 2025

**Tecnologías Utilizadas:**
- PostgreSQL 15
- Docker & Docker Compose  
- Bash Scripting
- Streaming Replication
- WAL Archiving

---

## 📄 Licencia

Este proyecto es desarrollado con fines académicos para la Universidad Rafael Landívar.

**Tecnologías Open Source utilizadas:**
- PostgreSQL (PostgreSQL License)
- Docker (Apache 2.0)

---

## ✅ Estado del Proyecto

**Fase 1 - COMPLETADA ✅**

- [x] Arquitectura de 3 nodos implementada
- [x] Replicación streaming funcionando  
- [x] Failover manual probado
- [x] Política de respaldos configurada
- [x] Análisis de costos completado
- [x] Documentación técnica generada
- [x] Scripts de automatización creados

**Entregables:**
- ✅ Sistema funcionando
- ✅ Documentación completa  
- ✅ Scripts automatizados
- ✅ Análisis de alternativas
- ✅ Evidencias de funcionamiento

---

## 📞 Soporte

Para preguntas sobre la implementación:

1. Revisar la documentación en `documentacion/`
2. Verificar logs en `backups/backup.log`
3. Consultar scripts comentados en `scripts/`
4. Revisar troubleshooting en este README

**Comandos rápidos de verificación:**
```bash
# Estado completo del sistema
docker ps && docker network ls

# Conectividad básica
psql -h localhost -p 15432 -U postgres -d pollo_sanjuanero -c "SELECT version();"

# Logs recientes
docker logs postgres-primary --tail 50
```

---

*Proyecto desarrollado para demostrar competencias en administración de bases de datos de alta disponibilidad y análisis de alternativas tecnológicas.*