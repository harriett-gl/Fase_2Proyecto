# 🎯 INSTRUCCIONES PARA LA DEMOSTRACIÓN – FASE 2  
## 🍃 MongoDB Replica Set – Pollo Sanjuanero S.A.

---

## 🧰 Scripts / Comandos Principales

### 1️⃣ Ver Contenedores Activos
```bash
docker ps
````

🗣️ **Explicación sugerida:**

> “Aquí pueden ver todos mis contenedores corriendo: los de **PostgreSQL** (Fase 1) y los **tres nodos de MongoDB** de la Fase 2: `mongo1`, `mongo2` y `mongo3`.”

---

### 2️⃣ Conectarse al Nodo Primario

```bash
docker exec -it mongo1 mongosh -u adminPollo -p 'SanjuaneroPassword2025!' --authenticationDatabase admin
```

🗣️ **Explicación sugerida:**

> “Voy a conectarme al nodo **mongo1** con el usuario administrador **adminPollo**. Como ven, el prompt muestra `rs0:PRIMARY>`, indicando que este nodo es el **Primario**.”

---

### 3️⃣ Ver Estado del Replica Set

```javascript
rs.status()
```

🗣️ **Explicación sugerida:**

> “Aquí se observa que **mongo1** es el nodo Primario y los otros dos (`mongo2`, `mongo3`) son **Secundarios**. Esto confirma que la replicación está activa.”

---

## 📦 Visualización de Colecciones

### 4️⃣ Cambiar a la Base de Datos

use db_sanjuanero


### 5️⃣ Mostrar Colecciones Operativas

```javascript
db.rutas_entrega.find()
db.comentarios_clientes.find()
db.historial_fallas.find()
```

### 6️⃣ Mostrar Colección Migrada

db.clientes_migrados.find()


🗣️ **Explicación sugerida:**

> “En la base de datos `db_sanjuanero` tenemos las tres colecciones operativas: **rutas**, **comentarios** y **fallas**.
> Además, esta colección **clientes_migrados** contiene los datos importados desde PostgreSQL (por ejemplo, los registros de *Ana* y *Luis*).”

---

## 🔄 Replicación en los Nodos Secundarios

### 7️⃣ Conectarse a un Nodo Secundario

```bash
docker exec -it mongo2 mongosh -u adminPollo -p 'SanjuaneroPassword2025!' --authenticationDatabase admin
```

🗣️ **Explicación sugerida:**

> “Ahora me conecto al nodo **mongo2**, que en este momento es un **Secundario**. El prompt lo confirma con `rs0:SECONDARY>`.”

---

### 8️⃣ Habilitar Lecturas en el Secundario

```javascript
rs.secondaryOk()
```

### 9️⃣ Consultar Datos Replicados

use db_sanjuanero
db.clientes_migrados.find()


🗣️ **Explicación sugerida:**

> “Por defecto, los nodos secundarios no permiten lecturas.
> Habilito la opción `rs.secondaryOk()` y verifico que los datos migrados también están disponibles aquí.
> ✅ Esto demuestra que **la replicación entre nodos funciona correctamente**.”

---

## 💥 Simulación de Failover Automático

### 🔻 Apagar el Nodo Primario

```bash
docker stop mongo1
```

🗣️ **Explicación sugerida:**

> “Ahora voy a **simular una falla del nodo Primario** apagando `mongo1`.
> MongoDB detectará la caída y promoverá automáticamente un nuevo nodo como Primario.”

---

### 🆙 Conectarse al Nuevo Primario

```bash
docker exec -it mongo2 mongosh -u adminPollo -p 'SanjuaneroPassword2025!' --authenticationDatabase admin
```

🗣️ **Explicación sugerida:**

> “Como pueden ver, el prompt ahora muestra `rs0:PRIMARY>`.
> Esto significa que **mongo2 fue promovido automáticamente** como el nuevo Primario.
> 🔄 **El sistema sigue en línea, sin pérdida de datos.**”

---

### 🔁 Restaurar el Nodo Original

```bash
docker start mongo1
docker exec -it mongo1 mongosh -u adminPollo -p 'SanjuaneroPassword2025!' --authenticationDatabase admin
```

🗣️ **Explicación sugerida:**

> “Reinicio el nodo que falló (`mongo1`).
> Al reconectarlo, ya no es Primario, sino **Secundario (rs0:SECONDARY)**.
> Se ha reintegrado automáticamente al cluster.
> ✅ **La arquitectura se reparó sola.**”

---

## 📸 Momentos Clave para Capturas

| 🖼️ Captura                         | 📋 Descripción                                                   |
| ----------------------------------- | ---------------------------------------------------------------- |
| **1. Replica Set Activo**           | Mostrar los 3 nodos (`mongo1`, `mongo2`, `mongo3`) corriendo.    |
| **2. Nodo Primario Activo**         | Conexión a `mongo1` con `rs0:PRIMARY>`.                          |
| **3. Colecciones y Datos Migrados** | Mostrar `rutas`, `comentarios`, `fallas`, y `clientes_migrados`. |
| **4. Lectura en Secundario**        | Mostrar `rs0:SECONDARY>` con lectura habilitada.                 |
| **5. Failover Automático**          | Mostrar que `mongo2` se convierte en el nuevo Primario.          |
| **6. Reintegración**                | `mongo1` vuelve como Secundario tras reiniciarse.                |

---

## ⚠️ Solución de Problemas

| 🔧 Problema                   | 💡 Solución                                                              |
| ----------------------------- | ------------------------------------------------------------------------ |
| El nodo secundario no arranca | `docker restart mongo2 && sleep 20`                                      |
| Fallo de red entre nodos      | `docker network rm mongo-cluster && docker network create mongo-cluster` |
| Error de permisos en scripts  | `chmod +x scripts/*.sh`                                                  |
| Resetear toda la demo         | `docker rm -f mongo1 mongo2 mongo3 && docker network rm mongo-cluster`   |

---

## 🎓 Estructura de la Demostración

| ⏱️ Paso             | 🧩 Descripción                                        | ⌛ Tiempo           |
| ------------------- | ----------------------------------------------------- | ------------------ |
| 1                   | Verificación de contenedores y estado del Replica Set | 2 min              |
| 2                   | Visualización de colecciones y migración              | 4 min              |
| 3                   | Prueba de replicación entre nodos                     | 3 min              |
| 4                   | Failover automático                                   | 4 min              |
| 5                   | Restauración del nodo original                        | 2 min              |
| 6                   | Capturas y cierre                                     | 2 min              |
| **Total estimado:** | —                                                     | **~15–20 minutos** |

---

## 💡 Tips para la Presentación

* 🧠 **Ensaya antes:** Corre todos los comandos al menos una vez.
* 🗣️ **Explica cada paso:** Menciona qué demuestra cada comando.
* 💻 **Ten capturas previas:** Por si algún contenedor falla.
* 🕐 **Controla el ritmo:** Cada fase tiene pausas naturales para comentar.
* 📈 **Muestra resultados claros:** Que se vea el failover y la replicación en tiempo real.

---

## 🏆 Objetivos Demostrados

✅ Alta Disponibilidad con 3 nodos (Primario y Secundarios).
✅ Replica Set funcional con failover automático.
✅ Replicación verificada en tiempo real.
✅ Integración SQL → NoSQL demostrada.
✅ Arquitectura reparable y tolerante a fallos.
✅ Competencias avanzadas en **MongoDB y Docker**.

---