#!/bin/bash

# Política de Respaldos PostgreSQL - Sistema Alta Disponibilidad
# Proyecto: Sistema Pollo Sanjuanero S.A.
# 
# Política implementada:
# - Full backup semanal (domingos)
# - Backups incrementales diarios (WAL archiving)
# - Retención de 7 días

set -e

# Configuración
BACKUP_DIR="/backups"
WAL_ARCHIVE_DIR="/backups/wal_archive"
FULL_BACKUP_DIR="/backups/full"
INCREMENTAL_BACKUP_DIR="/backups/incremental"
RETENTION_DAYS=7
LOG_FILE="/backups/backup.log"

# Función para logging
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    # Guardar en archivo de log local
    echo "$msg" >> backups/backup.log 2>/dev/null || true
}

# Función para crear estructura de directorios
setup_backup_directories() {
    log "Configurando directorios de backup..."
    
    docker exec postgres-primary bash -c "
        mkdir -p $FULL_BACKUP_DIR
        mkdir -p $INCREMENTAL_BACKUP_DIR  
        mkdir -p $WAL_ARCHIVE_DIR
        chown -R postgres:postgres $BACKUP_DIR
    "
    
    log "✅ Directorios de backup configurados"
}

# Función para backup completo
full_backup() {
    local backup_name="full_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$FULL_BACKUP_DIR/$backup_name"
    
    log "Iniciando backup completo: $backup_name"
    
    docker exec postgres-primary bash -c "
        su postgres -c \"
            PGPASSWORD=postgres123 pg_basebackup -h localhost -U postgres -D $backup_path -Ft -z -P -v \
            --checkpoint=fast \
            --label='$backup_name' \
            --progress
        \"
    " 2>&1
    
    if [ $? -eq 0 ]; then
        log "✅ Backup completo exitoso: $backup_name"
        
        # Crear archivo de metadatos
        docker exec postgres-primary bash -c "
            cat > $backup_path/backup_info.txt << EOF
Backup Type: Full Backup
Backup Name: $backup_name
Date: $(date)
Database: pollo_sanjuanero
Server: postgres-primary
Size: \$(du -sh $backup_path | cut -f1)
EOF
        "
        
        return 0
    else
        log "❌ Error en backup completo: $backup_name"
        return 1
    fi
}

# Función para backup incremental (usando WAL)
incremental_backup() {
    local backup_name="incremental_backup_$(date +%Y%m%d_%H%M%S)"
    
    log "Iniciando backup incremental: $backup_name"
    
    # Forzar un checkpoint y rotación de WAL
    docker exec postgres-primary psql -U postgres -c "SELECT pg_switch_wal();" 2>&1 | tee -a "$LOG_FILE"
    
    # Comprimir archivos WAL del día actual
    docker exec postgres-primary bash -c "
        cd $WAL_ARCHIVE_DIR
        today=\$(date +%Y%m%d)
        
        if ls *\$today* 1> /dev/null 2>&1; then
            tar -czf $INCREMENTAL_BACKUP_DIR/\${backup_name}.tar.gz *\$today*
            echo \"Archivos WAL del día \$today comprimidos en $INCREMENTAL_BACKUP_DIR/\${backup_name}.tar.gz\"
            
            # Crear archivo de metadatos
            cat > $INCREMENTAL_BACKUP_DIR/\${backup_name}_info.txt << EOF
Backup Type: Incremental (WAL Archive)
Backup Name: \$backup_name
Date: \$(date)
WAL Files: \$(ls *\$today* 2>/dev/null | wc -l)
Size: \$(du -sh $INCREMENTAL_BACKUP_DIR/\${backup_name}.tar.gz | cut -f1)
EOF
        else
            echo \"No hay archivos WAL del día actual para backup incremental\"
        fi
    " 2>&1 | tee -a "$LOG_FILE"
    
    log "✅ Backup incremental completado: $backup_name"
}

# Función para limpieza con retención
cleanup_old_backups() {
    log "Iniciando limpieza de backups antiguos (retención: $RETENTION_DAYS días)"
    
    docker exec postgres-primary bash -c "
        # Limpiar backups completos antiguos
        find $FULL_BACKUP_DIR -type d -name 'full_backup_*' -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
        
        # Limpiar backups incrementales antiguos  
        find $INCREMENTAL_BACKUP_DIR -name '*.tar.gz' -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        find $INCREMENTAL_BACKUP_DIR -name '*_info.txt' -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        # Limpiar archivos WAL antiguos (mantener últimos 7 días)
        find $WAL_ARCHIVE_DIR -name '0*' -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        echo \"Limpieza de backups antiguos completada\"
    " 2>&1 | tee -a "$LOG_FILE"
    
    log "✅ Limpieza completada"
}

# Función para mostrar estado de backups
show_backup_status() {
    log "=== ESTADO ACTUAL DE BACKUPS ==="
    
    docker exec postgres-primary bash -c "
        echo \"Backups Completos:\"
        ls -la $FULL_BACKUP_DIR/ 2>/dev/null | head -10 || echo \"  No hay backups completos\"
        echo \"\"
        
        echo \"Backups Incrementales:\"  
        ls -la $INCREMENTAL_BACKUP_DIR/*.tar.gz 2>/dev/null | tail -5 || echo \"  No hay backups incrementales\"
        echo \"\"
        
        echo \"Archivos WAL:\"
        ls -la $WAL_ARCHIVE_DIR/ 2>/dev/null | tail -5 || echo \"  No hay archivos WAL\"
        echo \"\"
        
        echo \"Espacio utilizado:\"
        du -sh $BACKUP_DIR/* 2>/dev/null | sort -hr || echo \"  No hay datos de espacio\"
    "
}

# Función para restaurar desde backup
restore_from_backup() {
    local backup_name=$1
    local target_time=$2
    
    if [ -z "$backup_name" ]; then
        log "❌ Error: Debe especificar nombre del backup para restaurar"
        return 1
    fi
    
    log "Iniciando proceso de restauración desde: $backup_name"
    log "Point-in-time: ${target_time:-'último disponible'}"
    
    # Aquí iría la lógica de restauración PITR
    docker exec postgres-primary bash -c "
        echo \"PROCESO DE RESTAURACIÓN\"
        echo \"Backup: $backup_name\"
        echo \"Target time: ${target_time:-'latest'}\"
        echo \"\"
        echo \"Pasos para restauración manual:\"
        echo \"1. Detener PostgreSQL\"
        echo \"2. Respaldar datos actuales\"  
        echo \"3. Restaurar backup base: tar -xf $FULL_BACKUP_DIR/$backup_name/base.tar.gz\"
        echo \"4. Configurar recovery.conf con target time\"
        echo \"5. Restaurar archivos WAL necesarios\"
        echo \"6. Iniciar PostgreSQL en modo recovery\"
        echo \"7. Verificar restauración\"
    "
    
    log "✅ Información de restauración mostrada"
}

# Función principal
main() {
    log "=== INICIANDO POLÍTICA DE RESPALDOS ==="
    log "Proyecto: Sistema Pollo Sanjuanero S.A."
    
    # Configurar directorios
    setup_backup_directories
    
    case "${1:-daily}" in
        "setup")
            log "Configuración inicial completada"
            show_backup_status
            ;;
        "full")
            full_backup
            cleanup_old_backups
            show_backup_status
            ;;
        "incremental"|"daily")
            incremental_backup
            cleanup_old_backups
            show_backup_status
            ;;
        "weekly")
            full_backup
            incremental_backup  
            cleanup_old_backups
            show_backup_status
            ;;
        "status")
            show_backup_status
            ;;
        "restore")
            restore_from_backup "$2" "$3"
            ;;
        "cleanup")
            cleanup_old_backups
            show_backup_status
            ;;
        *)
            echo "Uso: $0 {setup|full|incremental|weekly|status|restore|cleanup}"
            echo ""
            echo "Comandos:"
            echo "  setup       - Configurar directorios de backup"
            echo "  full        - Ejecutar backup completo"
            echo "  incremental - Ejecutar backup incremental (diario)"  
            echo "  weekly      - Ejecutar backup semanal (completo + incremental)"
            echo "  status      - Mostrar estado de backups"
            echo "  restore     - Mostrar información de restauración"
            echo "  cleanup     - Limpiar backups antiguos"
            echo ""
            echo "Ejemplos:"
            echo "  $0 setup"
            echo "  $0 full"
            echo "  $0 incremental"
            echo "  $0 status"
            exit 1
            ;;
    esac
    
    log "=== POLÍTICA DE RESPALDOS COMPLETADA ==="
}

# Ejecutar función principal
main "$@"