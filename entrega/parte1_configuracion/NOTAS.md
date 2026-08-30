# Parte 1 - Notas

## Enfoque

`EffectiveConfigResolver` obtiene en una sola consulta parametrizada las directivas del renglón, el header y las unidades solicitadas. Una ventana ordena primero el `user` para las claves de intención y después por `version`, `created_at` e `id`. Ruby combina el ganador de unidad con el ganador de header únicamente cuando falta la unidad.

## Supuestos

- Una fila de directiva representa una decisión, incluso si `value` es `NULL`; por eso evita herencia y devuelve la clave con valor `nil`.
- `id` desempata filas con el mismo `created_at`.
- Una lista `keys: []` devuelve mapas vacíos sin consultar la base de datos.
- Una clave sin directiva efectiva no aparece en el mapa.

## Fuera de alcance

No se modela `line_items`, porque el contrato solo necesita `line_item_id`. Tampoco se agrega una foreign key hacia una tabla que no está incluida en el esquema de la prueba.

## Con más tiempo

Mediría `EXPLAIN (ANALYZE, BUFFERS)` con volúmenes representativos, añadiría pruebas de contrato para límites de longitud y evaluaría particionamiento si el historial creciera de forma significativa.
