# Entrega

Esta carpeta contiene los entregables finales de las cinco partes de la prueba. El código de trabajo puede vivir en `app/`, `lib/` y `test/`, con referencias desde cada `NOTAS.md`.

## Mapa de archivos

- `parte1_configuracion/NOTAS.md`: decisiones y supuestos del resolver.
- `parte2_corte/NOTAS.md`: heurística, métrica y evolución del planificador.
- `parte3_postgres/reserve_material.sql`: función PL/pgSQL.
- `parte3_postgres/seeds.sql`: datos mínimos de prueba.
- `parte3_postgres/test.sql`: escenarios funcionales y aserciones SQL.
- `parte3_postgres/NOTAS.md`: locks, idempotencia, índices y concurrencia.
- `parte4_video/guion.md`: guion de referencia; no sustituye un video real de candidato.
- `parte5_preguntas.md`: respuestas de referencia.

## Verificación

Desde la raíz del proyecto:

```bash
bin/rails test
psql -d prueba_tecnica_rails_referencia_development -v ON_ERROR_STOP=1 -f entrega/parte3_postgres/reserve_material.sql
psql -d prueba_tecnica_rails_referencia_development -v ON_ERROR_STOP=1 -f entrega/parte3_postgres/seeds.sql
psql -d prueba_tecnica_rails_referencia_development -v ON_ERROR_STOP=1 -f entrega/parte3_postgres/test.sql
```
