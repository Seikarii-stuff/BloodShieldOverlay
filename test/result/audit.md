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

Hallazgos iniciales confirmados:

1. `BlizzardFrames.lua`: `ScanContainerChildren` llama `container:GetChildren()` dos veces por índice y por nivel. Es trabajo redundante en un camino de descubrimiento y contradice la afirmación de cero coste; **1 bloque junior**.
2. `BlizzardFrames.lua`: `pcall` alrededor de callbacks de `EventRegistry`/`HookScript` oculta errores reales y dificulta diagnóstico; **2 bloques junior**.
3. `BloodShieldOverlay.lua`: los handlers de arrastre del menú pasan métodos sin wrapper (`menuFrame.StartMoving`/`StopMovingOrSizing`), acoplando implícitamente la firma del callback a la API; **2 bloques junior**.
4. `BloodShieldOverlay.lua`: `SaveBarPosition` persiste offsets sin validar que `GetPoint()` haya devuelto una posición completa; **1 bloque junior**.
5. `README.md`/`AGENTS.md`: afirmaciones absolutas de “0 bugs”, “0 B/s” y “cero asignaciones” no están respaldadas por tests ni medición reproducible; **1 bloque documental junior**.

**Total provisional: 7 bloques de código/documentación junior.** Se mantiene separado de bugs funcionales y no se modifica producción sin una petición explícita de refactor.
