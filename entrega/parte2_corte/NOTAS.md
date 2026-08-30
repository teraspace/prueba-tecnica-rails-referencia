# Parte 2 - Notas

## Heurística elegida

Uso Best Fit Decreasing: ordeno las piezas por longitud descendente, con desempate por posición original, y coloco cada pieza en la barra abierta que deja el menor remanente no negativo. Si ninguna barra abierta sirve, abro la barra disponible más corta que pueda contenerla. Los empates se resuelven por orden de stock e instancia.

La solución es determinista y no exponencial. Su costo típico es `O(P * B)` después del ordenamiento, donde `P` es el número de piezas unitarias y `B` el número de barras abiertas. La implementación conserva el índice original para poder agrupar las piezas no ubicadas.

## Convención física

La capacidad útil es `length - head_trim - tail_trim`. Cada pieza consume `length + kerf`, incluido el último corte. El desperdicio expuesto en cada barra es la longitud física menos la suma de longitudes de piezas; el ratio global es desperdicio físico dividido por longitud física de las barras utilizadas.

## Alternativa descartada

Descarté backtracking y búsqueda exacta porque el problema es NP-difícil y la prueba permite una heurística. También descarté ordenar aleatoriamente: aunque a veces mejora un caso aislado, rompe reproducibilidad.

## Cómo mediría la calidad

Mediría barras usadas, material físico consumido, desperdicio absoluto, ratio de desperdicio, piezas satisfechas y tiempo de ejecución. Compararía la heurística contra fixtures históricos y, para casos pequeños, contra una solución exacta solo como benchmark.

## Retales cortos

Introduciría una política de selección de barra separada del recorrido principal. La nueva política podría preferir remanentes cortos antes de abrir stock nuevo, manteniendo la misma interfaz y pruebas de determinismo.
