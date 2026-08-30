# Parte 3 - Notas

## Estrategia de bloqueo

Primero bloqueo la solicitud con `SELECT ... FOR UPDATE` para serializar reintentos del mismo request. Después bloqueo todos los lotes del material y almacén en `received_at ASC, id ASC`, que es el orden FIFO y el mismo orden para todos los callers. La función espera el lock en lugar de usar `SKIP LOCKED`, porque saltar un lote podría romper FIFO.

Los movimientos y descuentos ocurren dentro de la misma transacción de la aplicación. El `UPDATE` tiene una condición `quantity >= v_moved` como segunda barrera contra cantidades negativas. El bloque de excepción no captura ni oculta errores; una excepción aborta la operación y revierte sus escrituras.

## Idempotencia y concurrencia

Una solicitud `fulfilled` o `partial` se devuelve sin nuevos movimientos. Dos llamadas simultáneas al mismo request compiten por el lock de la solicitud: la segunda espera, observa el estado confirmado por la primera y retorna el resultado anterior. Dos requests diferentes también se serializan al bloquear los lotes compartidos en el mismo orden; el segundo reevalúa las cantidades después de que el primero termina.

## Base de datos frente a Ruby

La reserva vive en PostgreSQL porque el inventario, los locks, los movimientos y la actualización de la solicitud deben ser una sola unidad atómica para todos los consumidores. Moverlo a Ruby aumenta el riesgo de carreras entre procesos y de doble consumo. Se pierde parte de la comodidad y testeabilidad de objetos Ruby, y la lógica queda acoplada al dialecto SQL; a cambio se protege la integridad en el punto donde viven los datos.

## Índices y plan

`idx_stock_lots_fifo(material_id, warehouse_id, received_at, id)` permite acotar por material/almacén y recorrer en orden FIFO. `idx_stock_movements_request(request_id)` permite comprobar la suma y contar lotes usados de una solicitud. Esperaría un Index Scan o Bitmap/Sort pequeño sobre los lotes del material y almacén, no una lectura completa del inventario. Lo validaría con `EXPLAIN (ANALYZE, BUFFERS)` en datos representativos.

## Limitación del esquema

No existe tabla `warehouses` ni foreign key sobre `warehouse_id`. La función rechaza IDs nulos o no positivos, pero no puede distinguir un almacén válido sin lotes de uno inexistente. Si esa validación es contractual, el esquema debe agregar `warehouses` y una foreign key.

## Concurrencia manual

Para reproducir el bloqueo, ejecutar `test.sql` en una base limpia y abrir dos sesiones `psql`. En ambas, insertar requests distintos sobre el mismo material y almacén; en la primera iniciar `BEGIN` y llamar la función sin `COMMIT`; en la segunda llamar la función y observar que espera. Confirmar la primera, dejar continuar la segunda y comprobar que la suma de movimientos no supera el inventario inicial.
