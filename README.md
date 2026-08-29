# Prueba técnica Ruby on Rails - implementación de referencia

Implementación aislada para desarrollar y evaluar la prueba técnica de Energía Solar S.A.

## Estado

- Rails 7.2.2.2
- Ruby 3.3.4
- PostgreSQL mediante `pg`
- Minitest, incluido por Rails
- Sin gemas adicionales de dominio

La implementación se desarrolla por partes y commits progresivos. No se mezclan cambios con la aplicación Rails de `/Users/charly/tetraspace.llc`.

## Estructura de entrega

```text
entrega/
  parte1_configuracion/
  parte2_corte/
  parte3_postgres/
  parte4_video/
  parte5_preguntas.md
```

## Desarrollo por commits

1. `chore: establish technical-test baseline`
2. `part1: add directives schema and indexes`
3. `part1: implement effective configuration resolution`
4. `part1: verify precedence inheritance and query budget`
5. `part2: add cut planner domain objects`
6. `part2: implement deterministic packing heuristic`
7. `part2: cover planner edges and invariants`
8. `part3: add postgres indexes and test fixtures`
9. `part3: implement fifo material reservation`
10. `part3: verify idempotency and concurrency`
11. `docs: add video outline and short answers`
12. `qa: finalize delivery documentation`

Cada commit debe dejar las pruebas del alcance en verde. Las decisiones ambiguas se documentan en el `NOTAS.md` de su parte.

## Preparación local

```bash
bundle install
bin/rails db:prepare
bin/rails test
```

La configuración de PostgreSQL está en `config/database.yml`. Para usar otra conexión, configurar `DATABASE_URL` o las variables propias de Rails sin guardar secretos en el repositorio.

## Convenciones de calidad

- SQL parametrizado y sin interpolación de datos.
- Sin N+1 ni consultas por unidad, clave o pieza.
- Pruebas de casos felices, bordes, invariantes y concurrencia donde aplique.
- Determinismo explícito en la Parte 2.
- Ningún commit incluye `config/master.key`, logs, bases locales o artefactos generados.
