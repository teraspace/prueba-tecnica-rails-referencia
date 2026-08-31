# Pitch de video — máximo 3 minutos

## Versión recomendada

### 0:00–0:20 — Presentación y alcance

“Voy a explicar la solución desde el problema de negocio y no solamente desde el código. Interpreté el ejercicio como el backend de una operación de corte: recibe piezas y material disponible, calcula un plan y reserva inventario. El enunciado no define una integración directa con una CNC, así que dejé esa frontera fuera y me concentré en la consistencia del dominio.”

### 0:20–0:55 — Configuración efectiva

“La primera parte resuelve la configuración efectiva de cada unidad. Una directiva puede venir del header o de la unidad específica, y la unidad debe sobrescribir al header cuando existe. Para las claves de intención del usuario, como color o acabado, priorizo explícitamente el valor de usuario aunque exista una resolución posterior. La consulta está parametrizada, filtra por versión y devuelve los ganadores con una función de ventana. Así evito traer datos innecesarios y mantengo el límite de una consulta.”

### 0:55–1:30 — Planificación de cortes

“Para el corte normalizo primero longitudes, cantidades, stock y tolerancias. El algoritmo utilizado es Best Fit Decreasing: ordena las piezas de mayor a menor y coloca cada una en la barra que deja el menor sobrante posible. Antes de colocarla considero el kerf, el head trim y el tail trim. Si no existe una barra útil, la pieza queda reportada como no colocada en lugar de ocultar la falta de inventario. El resultado también incluye las barras usadas, sobrantes y porcentaje de desperdicio.”

### 1:30–2:15 — Reserva FIFO y concurrencia

“La parte más delicada es la reserva. No alcanza con leer stock y después actualizarlo, porque dos órdenes podrían leer el mismo saldo. La función corre dentro de una transacción, bloquea la solicitud para serializar reintentos y bloquea los lotes candidatos en orden FIFO: primero `received_at` y luego `id` como desempate determinista. Cada descuento y cada movimiento de auditoría se confirma en la misma transacción.

Para una solicitud no parcial, si el inventario total no alcanza, no descuento nada y la solicitud queda en backorder. Para una solicitud parcial, consumo lo disponible y dejo registrada la cantidad pendiente. También uso una clave de idempotencia para que reintentar la misma operación no duplique movimientos.”

### 2:15–2:45 — Decisiones y límites

“Elegí `FOR UPDATE` en vez de `SKIP LOCKED` porque aquí la prioridad es respetar FIFO y tomar una decisión explicable. `SKIP LOCKED` sería más apropiado para repartir trabajo entre workers, pero podría saltarse un lote que debe atender a la orden.

Hay decisiones que el enunciado no especifica. Por ejemplo, no define una tabla de almacenes ni la unidad física de las dimensiones. Para producción agregaría esa relación y normalizaría las medidas a milímetros enteros o `NUMERIC`, en lugar de depender de `Float`.”

### 2:45–3:00 — Cierre

“La solución está cubierta con pruebas de precedencia, límites del planificador, FIFO, parciales, idempotencia y concurrencia. Mi prioridad fue que el inventario, la trazabilidad y los reintentos siguieran siendo correctos bajo carga, no solamente que el caso feliz devolviera un número.”

## Cómo presentarlo

- Hablar sobre decisiones y trade-offs, no leer cada archivo.
- Mostrar primero el flujo general y después un fragmento corto de `FOR UPDATE`.
- Aclarar los supuestos antes de defenderlos como requisitos.
- Si preguntan por la CNC, responder que Rails administra órdenes y planificación; la generación de G-code y el control en tiempo real pertenecen a una integración CAM/PLC separada.
