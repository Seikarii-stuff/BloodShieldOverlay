# BloodShieldOverlay

**BloodShieldOverlay** es un addon ligero y de alto rendimiento para **World of Warcraft** (Retail & PTR) que muestra escudos de absorción (*absorbs*) tanto en una barra personalizable como en los marcos de unidad nativos de Blizzard (**Jugador, Resource Display, Party y Raid**). Versión actual: **2.1**.

---

## 🌟 Características Principales

- **Barra de Absorción Standalone Personalizable**:
  - Muestra la absorción total del jugador como un porcentaje de su salud máxima (funciona del 20% al 200%+ para mecánicas como *Escudo de Sangre / Blood Shield* de Caballero de la Muerte).
  - Marcas visuales (*tick marks*) al **50%, 100% y 150%**.
  - Totalmente desplazable, redimensionable y configurable mediante interfaz gráfica (`/shield`).
  - Almacenamiento de perfiles independiente por personaje.
  - Barra de salud opcional superpuesta y barra de recurso personal configurable a la izquierda, derecha o desactivada.
  - Recursos especiales discretos dentro de la barra vertical de recursos: Poder Sagrado, Esencia, Fragmentos de Alma, Chi, Puntos de Combo y Runas de Caballero de la Muerte.
  - Los círculos se crean una sola vez y se actualizan mediante `UNIT_POWER_FREQUENT`, `UNIT_POWER_UPDATE`, `UNIT_MAXPOWER` y `RUNE_POWER_UPDATE`.

- **Barra Target of Target para Healers**:
  - Barra compacta configurable para mostrar a quién está targeteando actualmente el objetivo del jugador.
  - Muestra el **nombre** del target y utiliza el **color de clase de Blizzard** cuando la unidad proporciona información de clase; las unidades sin clase mantienen un color neutral.
  - Valores por defecto: **130 × 10**.
  - Se puede mover mediante el mismo sistema global de Unlock/Lock del addon.
  - Está integrada en el menú `/shield` junto a las dimensiones de la barra principal.
  - Respeta las restricciones de *secret values* de Midnight: los valores protegidos se entregan directamente a los widgets de Blizzard sin compararlos, convertirlos o inspeccionarlos.
  - Sus actualizaciones visuales utilizan el mismo **micro-throttle compartido de ~30 FPS** que el resto del addon.

- **Recursos Especiales Alrededor del Ratón**:
  - Opción independiente en `/shield`: **Show special resources around mouse**.
  - Reutiliza el mismo proveedor y `RenderResourcePips()` que los recursos especiales de la barra personal y los overlays de grupo; no duplica la lógica de Holy Power, Esencia, Fragmentos de Alma, Chi, Combo Points o Runas.
  - Los pips son **circulares** y siguen el mismo patrón de máscara circular soportado por Blizzard usado en Minimizer.
  - Se disponen en una **semiluna izquierda alrededor del cursor**, manteniendo el mismo centro geométrico del overlay y colocando el primer/recurso disponible en la parte superior del arco.
  - El relleno de los pips es un *eclipse* circular: el fondo y el relleno comparten la misma máscara circular, sin un barrido radial artificial.
  - El addon no recalcula el estado de los recursos cada frame: el estado se actualiza mediante el listener compartido y la posición del conjunto respecto al cursor se refresca con un micro-throttle de ~30 FPS.

- **Cooldowns alrededor del Ratón**:
  - Dos slots opcionales independientes, con checkbox y selector de habilidad.
  - Los dos slots comparten el mismo pool de habilidades disponible para la clase/spec actual.
  - Una habilidad seleccionada en un slot desaparece del selector del otro, evitando duplicados.
  - La lista se mantiene en `data/SpellData.lua`, separando **spellID** (API) y **name** (UI).
  - El módulo utiliza `CooldownFrameTemplate` y deja que Blizzard pinte el estado del cooldown; no calcula el tiempo restante en Lua.
  - Incluye de entrada Choque Sagrado / Holy Shock y Divine Toll para Paladín, además de Marrowrend y Heart Strike para Blood DK, con listas específicas para las tres specs de cada clase.
  - Las clases sin recurso especial también pueden usar los slots de cooldown: `Mouse.lua` no depende de que exista un `ResourceProvider` para funcionar.

- **Recursos Especiales en Marcos de Grupo y Raid**:
  - Muestra los recursos especiales del jugador de forma horizontal en la parte inferior de su barra de maná/recurso de clase.
  - Funciona con `CompactPartyFrame`, `CompactRaidFrame`, `PartyFrame` y el modo *Always-In-Party*.
  - Reutiliza los proveedores de `ResourceProviders.lua`, sin duplicar reglas específicas de cada clase.
  - El descubrimiento se difiere durante combate y se reintenta después del layout de Blizzard para evitar taint y referencias a marcos protegidos.

- **Overlays en Marcos Nativos de Blizzard**:
  - Integración limpia sobre `PlayerFrame`, `PersonalResourceDisplayFrame`, `PartyFrame`, `CompactPartyFrame` y `CompactRaidFrame`.
  - Compatible con el modo marco de party forzado estando solo (*Always-In-Party*).

- **Arquitectura de Alto Rendimiento**:
  - El procesamiento de eventos rápidos (`UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_HEALTH`) usa un throttle bajo demanda y reutiliza sus colas internas; la creación de overlays queda limitada a los ciclos de descubrimiento.
  - **Micro-Throttle (30 FPS / ~0.033s)**: Agrupa las ráfagas intensas de curación/absorción y las actualizaciones del Target of Target en combate a ~30 FPS para evitar sobrecargar el renderizador visual de WoW.
  - El overlay del ratón no tiene un loop de actualización de recursos propio: solo actualiza su posición con el cursor a ~30 FPS mientras está activo.
  - **Escaneo Inteligente sin `EnumerateFrames()`**: Acceso dirigido con caché de clave débil (*weak-table*) para descubrir marcos sin recorrer todos los frames globales.
  - La barra personal solo usa el `OnUpdate` compartido y throttled del dispatcher; no crea un bucle de renderizado propio.

---

## 🛠️ Comandos de Chat (`/shield`)

| Comando | Descripción |
| :--- | :--- |
| `/shield` \| `/shields` \| `/shieldbar` | Abre el menú de configuración gráfica. |
| `/shield unlock` \| `/shield move` | Desbloquea las barras del addon para arrastrarlas libremente. |
| `/shield lock` | Bloquea las barras en sus posiciones actuales. |
| `/shield hide` | Oculta la barra independiente para el personaje actual. |
| `/shield show` | Muestra la barra independiente para el personaje actual. |
| `/shield reset` | Restaura la posición, tamaño y opciones por defecto. |
| `/shield party` | Fuerza un refresco manual del descubrimiento de marcos de party/raid. |

---

## 📁 Estructura del Proyecto

1. **[Core.lua](Core.lua)**
   - Centralizador de eventos de salud y absorciones.
   - Sistema de micro-throttle (~30 FPS) y patrón observador con asignaciones nulas de memoria.
   - También coalescea las actualizaciones visuales del Target of Target dentro del mismo dispatcher.

2. **[BloodShieldOverlay.lua](BloodShieldOverlay.lua)**
  - Bootstrap del namespace del addon y punto de entrada mínimo.

3. **[PlayerBar.lua](PlayerBar.lua)**
  - Control de las barras standalone de absorción, salud y recurso.

4. **[TargetTargetBar.lua](TargetTargetBar.lua)**
  - Barra compacta de Target of Target, nombre, color de clase y posicionamiento.
  - Mantiene separada la presentación de los datos y utiliza el dispatcher compartido para sus actualizaciones.

5. **[Mouse.lua](Mouse.lua)**
  - Presentación de recursos y cooldowns alrededor del cursor.
  - Recursos en semiluna izquierda; dos slots de cooldown en el lateral derecho.
  - Usa `CooldownFrameTemplate` para los temporizadores y mantiene separada la presentación de la lógica de recursos.

6. **[Menu.lua](Menu.lua)**
  - Interfaz central de configuración `/shield`, incluida la configuración de la barra Target of Target, el overlay del ratón y el Unlock/Lock global.

7. **[Configuration.lua](Configuration.lua)**
  - Defaults, migración y perfiles almacenados (`BloodShieldOverlayProfiles`).

8. **[ResourceProviders.lua](ResourceProviders.lua)**
  - Proveedores extensibles para recursos especiales de clase y runas de Caballero de la Muerte.
  - La Esencia de Evoker muestra la recarga secuencial del siguiente pip, mientras que las runas mantienen sus seis recargas independientes.

9. **[data/SpellData.lua](data/SpellData.lua)**
  - Catálogo de habilidades disponibles para los slots de cooldown del ratón.
  - Mantiene separados los IDs usados por la API y los nombres humanos mostrados en los desplegables.
  - Las tablas específicas de spec sobrescriben las listas de fallback por clase.

10. **[Commands.lua](Commands.lua)**
  - Adaptador de comandos `/shield`; delega las operaciones de UI en la API pública del addon.

11. **[AbsorbIndicator.lua](AbsorbIndicator.lua)**
   - Helper ligero para la creación de StatusBar transparentes al ratón sobre los marcos de salud.

12. **[BlizzardFrames.lua](BlizzardFrames.lua)**
   - Descubrimiento dirigido de marcos de Blizzard y vinculación de overlays mediante `hooksecurefunc` y caché débil (`healthBarCache`).

13. **[ClassResourceOverlay.lua](ClassResourceOverlay.lua)**
  - Renderiza horizontalmente los recursos especiales del jugador sobre la barra de recurso de su marco de party/raid.
  - Mantiene separado el descubrimiento de marcos, el renderizado y la lógica de recursos de clase.

## 🧪 Tests offline

El addon incluye un simulador mínimo de la API de WoW para validar los caminos que no requieren el cliente:

- Smoke test: `lua test/perf/smoke.lua`
  - Comprueba carga, APIs públicas, coalescing de eventos, perfiles, comandos slash, menú, toggles de salud/recurso, descubrimiento y refresco diferido durante combate.
  - Incluye una regresión del botón **Unlock**, que anteriormente llamaba al método inexistente `Button:Text()`.
- Integración de recursos especiales: crea un `CompactPartyFrame` simulado, asigna el jugador y verifica el anclaje del overlay a la barra de recurso.
- Benchmark: `lua test/benchmark/benchmark.lua 100000`
  - Mide dispatch, actualización de overlays, descubrimiento y delta del heap.

Estos tests no sustituyen la validación dentro del cliente PTR/Retail con marcos protegidos, Edit Mode y grupos de 40 jugadores.

---

## 📝 Notas de Release y Futuras Mejoras Documentadas

- **Comportamiento al Salir de Grupo en Combate (`InCombatLockdown`)**:
  - *Nota*: Si el jugador abandona un grupo estando en combate, el sistema de protección de marcos de WoW (*Secure Frames*) impide modificar la visibilidad o estructura de los marcos de party dinámicamente. El refresco del marco de party en solitario (*Always-In-Party*) se procesará automáticamente de forma transparente en cuanto finalice el combate (`PLAYER_REGEN_ENABLED`). Este comportamiento es esperado y correcto por seguridad del motor de WoW.
- **Compatibilidad de Marcos de Unidad**:
  - *Nota*: Diseñado exclusivamente para la interfaz nativa de Blizzard.
- **Target of Target — posible mejora futura**:
  - El frame ya utiliza `SecureUnitButtonTemplate`, por lo que una futura interacción mediante **mouseover/click** para targetear o lanzar hechizos sobre el target mostrado es técnicamente posible.
  - Se mantiene deliberadamente fuera de la implementación actual. Solo se añadirá si el uso real del frame demuestra que aporta suficiente valor como para justificar la complejidad adicional de los secure attributes y las restricciones de combate.
- **Cooldowns del overlay del ratón**:
  - Los dos slots actuales son una primera implementación deliberadamente pequeña. Si se demuestra útil, la semiluna superior puede ampliarse con más indicadores sin cambiar el catálogo ni la API de `Mouse.lua`.
- **Futura Idea de Mejora**:
  - Añadir en el menú gráfico una opción para activar/desactivar individualmente los overlays de Party/Raid de forma independiente a la barra principal.

---
**Versión**: 2.1 Release
**Autor**: Seikarii  
