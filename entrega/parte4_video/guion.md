# Guion de video - máximo 3 minutos

## Parte elegida: reserva FIFO de inventario

### 0:00-0:30 - Problema real

“El problema no es solo restar una cantidad. Varias órdenes pueden pedir el mismo material al mismo tiempo, y necesitamos decidir qué lotes consumir, dejar trazabilidad y poder reintentar sin duplicar una reserva. La solución tiene que seguir siendo correcta aunque dos procesos lleguen juntos.”

### 0:30-1:20 - Estructura

“La función recibe la solicitud, el almacén y la política de parciales. Primero bloquea la solicitud para serializar reintentos del mismo pedido. Luego bloquea los lotes del material y almacén en orden `received_at, id`, calcula disponibilidad y decide si cumple completa, parcialmente o deja la solicitud en backorder. Cada consumo inserta un movimiento y descuenta el lote dentro de la misma transacción.”

### 1:20-2:10 - Decisión y alternativa

“Elegí `FOR UPDATE` y esperar el bloqueo en vez de `SKIP LOCKED`. `SKIP LOCKED` puede ser bueno para una cola de trabajos, pero aquí saltarse un lote podría romper FIFO o producir una decisión difícil de explicar. También bloqueo todos los lotes candidatos antes de decidir un backorder, porque `allow_partial = false` debe consumir cero si no alcanza.”

### 2:10-2:50 - Debilidad y siguiente inversión

“La principal limitación es que el esquema no tiene tabla de almacenes, por lo que no puedo distinguir un almacén desconocido de uno válido sin lotes. Con dos días más agregaría esa relación y una foreign key, mediría el plan con `EXPLAIN`, y automatizaría una prueba de concurrencia dentro de CI. También revisaría si bloquear todos los lotes es demasiado costoso para inventarios muy grandes.”

### 2:50-3:00 - Cierre

“La propiedad que prioricé es que el inventario y su trazabilidad se mantengan correctos bajo reintentos y concurrencia, no solo que el caso feliz devuelva una cantidad.”
