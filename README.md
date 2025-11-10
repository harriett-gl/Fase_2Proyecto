# 🚀 Proyecto Final – Sistema de Alta Disponibilidad y Arquitectura Híbrida SQL/NoSQL  

**📚 Curso:** Base de Datos 2  
**🏛️ Universidad:** Universidad Rafael Landívar  
**📆 Semestre:** Segundo Semestre 2025  
**🏢 Empresa:** Pollo Sanjuanero S.A.  

**👩‍💻 Autora:** Harriett Guzmán y Eduardo Hernández 

---

## 🧩 Descripción General

Este proyecto forma parte del curso **Base de Datos 2** y tiene como objetivo la creación de una **arquitectura de datos híbrida** compuesta por:

- 🐘 **PostgreSQL** → Sistema relacional de alta disponibilidad (Fase 1)  
- 🍃 **MongoDB** → Sistema NoSQL con replicación y autenticación (Fase 2)  

Ambas fases trabajan en conjunto para ofrecer un sistema **resiliente, escalable y seguro**, garantizando el almacenamiento tanto de datos estructurados como no estructurados.

---

## ⚙️ Fase 1 – Alta Disponibilidad con PostgreSQL (Resumen)

La **Fase 1** implementó una infraestructura de **tres nodos** en PostgreSQL utilizando **replicación streaming**, **failover manual** y **respaldos automáticos** con retención de 7 días.

### 🧠 Arquitectura PostgreSQL

```

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ 🟢 Nodo Primario │    │ 🟡 Nodo Standby │    │ 🔵 Nodo Lectura │
│ (Puerto 15432)  │    │ (Puerto 15433)  │    │ (Puerto 15434)  │
│ ✅ Escritura     │    │ 🔄 Failover     │    │ 📖 Consultas     │
└─────────────────┘    └─────────────────┘    └─────────────────┘

```

📊 **Características clave:**
- Replicación streaming entre tres nodos.  
- Failover manual con scripts automatizados.  
- Política de respaldos incremental.  
- Disponibilidad del 99.9 %.  
- **RTO < 5 minutos | RPO < 1 minuto.**

🔗 **Ver más detalles:** [`README_Fase1_PostgreSQL.md`](README_Fase1_PostgreSQL.md)

---

## 🍃 Fase 2 – Arquitectura NoSQL con MongoDB Replica Set

En la segunda fase se implementó una **arquitectura NoSQL** utilizando **MongoDB Replica Set** (1 primario y 2 secundarios), desplegado con **Docker Compose**.  
Además, se realizó la **integración manual SQL → NoSQL**, exportando datos de PostgreSQL e importándolos en MongoDB.

### 🎯 Objetivos Específicos
✅ Configurar un Replica Set con tres nodos usando Docker.  
✅ Modelar colecciones (`rutas_entrega`, `comentarios_clientes`, `historial_fallas`).  
✅ Insertar datos de prueba y ejecutar consultas.  
✅ Simular failover manual y automático.  
✅ Crear usuario administrador con autenticación SCRAM-SHA-1.  
✅ Integrar datos desde PostgreSQL en formato JSON/CSV.  

---

## 🏗️ Arquitectura del Replica Set

```

            +---------------------------+
            | ⭐ Nodo Primario          |
            | mongo-primary:27017       |
            | (Lectura/Escritura)       |
            +-----------+---------------+
                  |                   |
                  |                   |
                  |                   |
                  v                   v
        +------------------+    +--------------------+
        | 🟢 Nodo Secundario |  | 🔵 Nodo Secundario |
        | mongo-secondary1   |  | mongo-secondary2   |
        | (Solo Lectura)     |  | (Solo Lectura)     |
        +------------------+    +--------------------+

````

📡 Identificador del Replica Set: `rsPolloSanjuanero`  
🌐 Red interna Docker: `mongo-cluster`

---

## 🐳 Configuración con Docker Compose

Archivo `docker-compose.yml`:

```yaml
version: '3.8'
services:
  mongo-primary:
    image: mongo:7
    container_name: mongo-primary
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=admin123
    volumes:
      - ./data/primary:/data/db
    networks:
      - mongo-cluster

  mongo-secondary1:
    image: mongo:7
    container_name: mongo-secondary1
    ports:
      - "27018:27017"
    networks:
      - mongo-cluster

  mongo-secondary2:
    image: mongo:7
    container_name: mongo-secondary2
    ports:
      - "27019:27017"
    networks:
      - mongo-cluster

networks:
  mongo-cluster:
    driver: bridge
````

### ▶️ Inicialización del Replica Set

```bash
docker exec -it mongo-primary mongosh -u admin -p admin123
```

```javascript
rs.initiate({
  _id: "rsPolloSanjuanero",
  members: [
    { _id: 0, host: "mongo-primary:27017" },
    { _id: 1, host: "mongo-secondary1:27017" },
    { _id: 2, host: "mongo-secondary2:27017" }
  ]
});
```

🧾 Verificar estado:

```javascript
rs.status();
```

---

## 🗃️ Modelado de Datos

### 🚚 Colección: `rutas_entrega`

```json
{
  "_id": "RUTA001",
  "fecha": "2025-10-30",
  "conductor": "Juan Pérez",
  "vehiculo": "Placas P123ABC",
  "coordenadas": [
    {"lat": 14.6349, "lon": -90.5069, "hora": "08:00"},
    {"lat": 14.6350, "lon": -90.5075, "hora": "08:30"}
  ],
  "estado": "completada"
}
```

### 💬 Colección: `comentarios_clientes`

```json
{
  "_id": "COM123",
  "cliente_id": "CLI45",
  "fecha": "2025-10-29",
  "comentario": "Excelente servicio",
  "calificacion": 5
}
```

### ⚙️ Colección: `historial_fallas`

```json
{
  "_id": "FALLA001",
  "fecha_reporte": "2025-10-28",
  "area": "Transporte",
  "descripcion": "Falla en sistema de refrigeración",
  "resuelto": false
}
```

---

## 🔁 Integración SQL → NoSQL

### 📤 Exportar desde PostgreSQL

```sql
COPY (SELECT id_cliente, nombre, telefono, correo FROM clientes)
TO '/tmp/clientes.csv' DELIMITER ',' CSV HEADER;
```

### 📥 Importar a MongoDB

```bash
mongoimport --db pollo_sanjuanero --collection clientes \
  --type csv --headerline --file /tmp/clientes.csv \
  --host localhost --port 27017 -u admin -p admin123 --authenticationDatabase admin
```

🔎 Verificación:

```javascript
db.clientes.find().pretty();
```

---

## 🔍 Consultas de Ejemplo

```javascript
// 🛣️ Rutas completadas
db.rutas_entrega.find({ estado: "completada" });

// 🌟 Comentarios con calificación máxima
db.comentarios_clientes.find({ calificacion: 5 });

// ⚠️ Fallas no resueltas
db.historial_fallas.find({ resuelto: false });

// 👤 Buscar cliente por nombre
db.clientes.find({ nombre: /María/ });
```

---

## 🔐 Seguridad y Autenticación

```javascript
use admin
db.createUser({
  user: "dbAdmin",
  pwd: "securePass123",
  roles: [{ role: "root", db: "admin" }]
});
```

🔒 Autenticación activada con `SCRAM-SHA-1`.

---

## ⚡ Pruebas de Failover

1. Ver nodo primario:

   ```javascript
   rs.status()
   ```
2. Detener nodo primario:

   ```bash
   docker stop mongo-primary
   ```
3. Observar elección de nuevo primario:

   ```javascript
   rs.status()
   ```
4. Reiniciar nodo detenido y confirmar reintegración.

---

## 📊 Comparativa SQL vs NoSQL

| 🧠 Aspecto          | 🐘 PostgreSQL (SQL)   | 🍃 MongoDB (NoSQL)            |
| ------------------- | --------------------- | ----------------------------- |
| Modelo de datos     | Tablas relacionales   | Documentos JSON               |
| Escalabilidad       | Vertical              | Horizontal (Replica/Sharding) |
| Integridad          | Llaves foráneas, ACID | Documentos embebidos          |
| Consultas           | SQL                   | BSON/JSON dinámico            |
| Alta disponibilidad | Streaming replication | Replica Set nativo            |
| Ideal para          | Datos estructurados   | Datos no estructurados        |

---

## 🧾 Conclusiones Generales

* ✅ **MongoDB** amplió la arquitectura hacia un entorno más flexible y dinámico.
* 🔄 La **replicación** demostró alta disponibilidad y recuperación automática.
* 🧠 La integración **SQL → NoSQL** permitió combinar datos transaccionales con operativos.
* 🧱 PostgreSQL sigue siendo ideal para operaciones estructuradas, mientras que MongoDB lo complementa para datos flexibles.
* 🌍 Se logró una arquitectura **híbrida, segura y escalable** para la empresa *Pollo Sanjuanero S.A.*.

---

## 📂 Estructura del Repositorio

```
Fase_2Proyecto/
├── README.md                     # Fase 2 (MongoDB)
├── README_Fase1_PostgreSQL.md    # Fase 1 (PostgreSQL)
├── docker-compose.yml
├── documentacion/
│   ├── evidencias_postgresql/
│   └── evidencias_mongodb/
└── scripts/
```

---

## 👩‍💻 Autora

**Harriett Guzmán**
*Universidad Rafael Landívar – Base de Datos 2 – 2025*

✨ *Proyecto académico diseñado para demostrar competencias en administración, replicación y análisis comparativo entre bases de datos SQL y NoSQL.*

```

---

💡 **Consejo:**  
Copia todo este texto en un archivo llamado `README.md` dentro de tu repositorio `Fase_2Proyecto`.  
GitHub mostrará automáticamente los emojis y la estructura visual cuando lo subas ✅
```