# Auditoría y resultados

## Smoke tests

Ejecutar desde la raíz del addon:

`lua test/perf/smoke.lua`

Cubre APIs públicas, creación/actualización del overlay, coalescencia del throttle, listeners de unidad/jugador/regen, comandos `/shield`, perfiles, descubrimiento del marco del jugador y refresco diferido durante combate.

## Benchmark sintético

`lua test/benchmark/benchmark.lua 100000`

El benchmark mide dispatch de eventos, actualizaciones del overlay, operaciones por segundo, listeners ejecutados y delta de heap Lua. El último resultado se escribe en `test/result/benchmark-latest.txt`.

## Criterio de código junior

Se contabiliza como “código junior” una construcción que introduce riesgo funcional o mantenimiento innecesario (duplicación, API insegura, manejo incompleto de errores o comentarios que afirman garantías no verificadas), no el estilo deliberadamente simple.

Hallazgos iniciales confirmados y estado:

1. `BlizzardFrames.lua`: llamadas redundantes a `GetChildren`; **resuelto** usando una lista capturada por nivel.
2. `BlizzardFrames.lua`: `pcall` silenciosos alrededor de callbacks; **resuelto** dejando que los errores sean visibles durante desarrollo/carga.
3. `BloodShieldOverlay.lua`: handlers de arrastre sin wrapper explícito; **resuelto** con callbacks que reciben `self` de forma segura.
4. `BloodShieldOverlay.lua`: `SaveBarPosition` sin validación; **resuelto** rechazando puntos incompletos o offsets no numéricos.
5. `README.md`/`AGENTS.md`: afirmaciones absolutas de rendimiento; **resuelto** sustituyéndolas por medición y límites explícitos.

**Total original: 7 bloques de código/documentación junior. Estado: 7/7 corregidos.** El smoke test pasó 19 assertions y el benchmark ahora incluye dispatch, overlay y descubrimiento de frames.
