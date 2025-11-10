# 🎯 INSTRUCCIONES PARA LA DEMOSTRACIÓN

## Scripts Disponibles

### 1. `prepare-demo.sh` - Preparar Infraestructura
```bash
./scripts/prepare-demo.sh
```
**Función**: Configura toda la infraestructura necesaria (nodos primario y standby, red, datos)
**Tiempo**: ~3-4 minutos
**Usar**: Antes de la demostración para preparar todo

### 2. `demo-presentacion.sh` - Demostración Completa  
```bash
./scripts/demo-presentacion.sh
```
**Función**: Ejecuta la demostración paso a paso con pausas para capturas
**Tiempo**: ~15-20 minutos (según pausas)
**Usar**: Durante la presentación

### 3. `test-demo.sh` - Verificar Estado
```bash
./scripts/test-demo.sh
```
**Función**: Verifica que todo esté funcionando correctamente
**Tiempo**: ~1 minuto
**Usar**: Para verificar que todo está listo

## 🚀 Flujo Recomendado

### Antes de la Presentación:
1. **Preparar**: `./scripts/prepare-demo.sh`
2. **Verificar**: `./scripts/test-demo.sh`
3. **Practicar**: `./scripts/demo-presentacion.sh` (opcional)

### Durante la Presentación:
1. **Ejecutar**: `./scripts/demo-presentacion.sh`
2. **Pausar en cada paso** para tomar capturas de pantalla
3. **Explicar cada funcionalidad** mostrada

## 📸 Momentos Clave para Capturas

### Captura 1: Banner y Arquitectura
- Al inicio, después del banner del proyecto
- Muestra los 3 nodos funcionando

### Captura 2: Base de Datos Empresarial  
- Datos de Pollo Sanjuanero S.A.
- Tablas con productos avícolas

### Captura 3: Replicación en Tiempo Real
- Inserción en primario
- Verificación en réplicas

### Captura 4: Failover Manual
- Estado antes de falla
- Promoción exitosa de standby
- Continuidad de datos

### Captura 5: Análisis de Costos
- Comparativa económica
- Ahorro de $312,096 USD

### Captura 6: Verificación Final
- Métricas de éxito
- Resumen de objetivos cumplidos

## ⚠️ Solución de Problemas

### Si el standby no inicia:
```bash
docker restart postgres-standby
sleep 20
```

### Si falla la red:
```bash
docker network rm postgres-ha
docker network create postgres-ha
```

### Si hay errores de permisos:
```bash
chmod +x scripts/*.sh
```

### Para limpiar completamente:
```bash
docker rm -f postgres-primary postgres-standby postgres-readonly
docker network rm postgres-ha
```

## 🎓 Estructura de la Demostración

1. **Verificación de Arquitectura** (2 min)
2. **Creación Nodo Solo Lectura** (3 min)
3. **Arquitectura Completa** (2 min)
4. **Base de Datos Empresarial** (3 min)  
5. **Replicación Streaming** (4 min)
6. **Failover Manual** (5 min)
7. **Sistema de Respaldos** (2 min)
8. **Análisis de Costos** (2 min)
9. **Verificación Final** (2 min)

**Total: ~25 minutos con explicaciones**

## 💡 Tips para la Presentación

- **Ensaya antes**: Corre el script completo al menos una vez
- **Prepara explicaciones**: Ten claro qué explicar en cada paso  
- **Ten backup**: Guarda capturas previas por si algo falla
- **Tiempo**: Cada paso tiene pausas naturales para explicar
- **Interacción**: El script es visual y fácil de seguir

## 🏆 Objetivos que Demuestra

✅ **Alta Disponibilidad**: 3 nodos funcionando
✅ **Replicación Streaming**: Tiempo real demostrado  
✅ **Failover Manual**: Continuidad sin pérdida de datos
✅ **Base de Datos Empresarial**: Caso real implementado
✅ **Análisis Económico**: Ahorro significativo demostrado
✅ **Competencias Técnicas**: PostgreSQL avanzado evidenciado