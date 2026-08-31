# Parte 5 - Respuestas de referencia

## 1. Media más rápida y usuarios más lentos

Primero, la media puede ocultar una cola: el promedio bajó, pero p95/p99 subió. Mediría percentiles por endpoint, versión, cliente y consulta.

Segundo, pudo cambiar la mezcla de tráfico: se optimizó una ruta frecuente, pero los usuarios ahora usan una ruta más pesada o hay más cache misses. Mediría volumen, rutas, cohortes y hit ratio.

Tercero, quizá bajó el tiempo de servidor, pero aumentaron red, colas, frontend o reintentos. Compararía trazas end-to-end, RUM, retries, tiempo de cola y time-to-interactive.

## 2. Botón para recalcular precios

1. Preguntaría qué cotizaciones y líneas entran, cuál es la fuente de verdad y cómo se aplican moneda, impuestos, descuentos y redondeos; eso define el dominio.
2. Preguntaría volumen, SLA y si el usuario necesita esperar; eso decide sincronía, job, estados y UX.
3. Preguntaría qué pasa con concurrencia, cambios de catálogo, fallas y reintentos; eso define idempotencia, versionado y recuperación.
4. Preguntaría auditoría, permisos y posibilidad de deshacer; eso define modelo, autorización y trazabilidad.

## 3. Proceso de seis horas que debe tardar dos

Perfilaría primero para separar CPU, IO, base de datos, locks, serialización y memoria. Luego probaría índices/planes, eliminaría N+1, reduciría round trips y procesaría en lotes. Paralelizaría particiones independientes con límite de workers, cachearía resultados repetidos y procesaría solo cambios. También revisaría logs, flushes, GC, conexiones, commits y checkpoint/reanudación. Mediría tiempo total, throughput, percentiles, recursos, errores y equivalencia funcional después de cada cambio.

Hay otros factores; como por ejemplo si entre la capa de aplicación y el servidor de Base de datos hay una alta latencia y por mal diseño lanza peticiones de negocio pequeñas en vez de intentar que sean por lotes u otra forma.
