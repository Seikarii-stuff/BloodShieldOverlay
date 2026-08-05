# BloodShieldOverlay

**BloodShieldOverlay** es un addon ligero y de alto rendimiento para **World of Warcraft** (Retail & PTR) que muestra escudos de absorción (*absorbs*) tanto en una barra personalizable como en los marcos de unidad nativos de Blizzard (**Jugador, Resource Display, Party y Raid**).

---

## 🌟 Características Principales

- **Barra de Absorción Standalone Personalizable**:
  - Muestra la absorción total del jugador como un porcentaje de su salud máxima (funciona del 20% al 200%+ para mecánicas como *Escudo de Sangre / Blood Shield* de Caballero de la Muerte).
  - Marcas visuales (*tick marks*) al **50%, 100% y 150%**.
  - Totalmente desplazable, redimensionable y configurable mediante interfaz gráfica (`/shield`).
  - Almacenamiento de perfiles independiente por personaje.

- **Overlays en Marcos Nativos de Blizzard**:
  - Integración limpia sobre `PlayerFrame`, `PersonalResourceDisplayFrame`, `PartyFrame`, `CompactPartyFrame` y `CompactRaidFrame`.
  - Compatible con el modo marco de party forzado estando solo (*Always-In-Party*).

- **Arquitectura de Alto Rendimiento (Zero-Allocation)**:
  - **Zero asignaciones de memoria en combate**: Eliminada la creación de tablas o funciones anónimas durante el procesamiento de eventos rápidos (`UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_HEALTH`).
  - **Micro-Throttle (30 FPS / ~0.033s)**: Agrupa las ráfagas intensas de curación/absorción en combate a ~30 FPS para evitar sobrecargar el renderizador visual de WoW.
  - **Escaneo Inteligente sin `EnumerateFrames()`**: Acceso directo O(1) con caché de clave débil (*weak-table*) para descubrir marcos sin bucles globales pesados.

---

## 🛠️ Comandos de Chat (`/shield`)

| Comando | Descripción |
| :--- | :--- |
| `/shield` \| `/shields` \| `/shieldbar` | Abre el menú de configuración gráfica. |
| `/shield unlock` \| `/shield move` | Desbloquea la barra del jugador para arrastrarla libremente. |
| `/shield lock` | Bloquea la barra en su posición actual. |
| `/shield hide` | Oculta la barra independiente para el personaje actual. |
| `/shield show` | Muestra la barra independiente para el personaje actual. |
| `/shield reset` | Restaura la posición y tamaño por defecto. |
| `/shield party` | Fuerza un refresco manual del descubrimiento de marcos de party/raid. |

---

## 📁 Estructura del Proyecto

1. **[`Core.lua`]
   - Centralizador de eventos de salud y absorciones.
   - Sistema de micro-throttle (~30 FPS) y patrón observador con asignaciones nulas de memoria.

2. **[`BloodShieldOverlay.lua`
   - Control de la barra de absorción independiente del jugador.
   - Gestión de perfiles almacenados (`BloodShieldOverlayProfiles`) y menú de ajustes.

3. **[`AbsorbIndicator.lua`]
   - Helper ligero para la creación de StatusBar transparentes al ratón sobre los marcos de salud.

4. **[`BlizzardFrames.lua`]
   - Descubrimiento dirigido de marcos de Blizzard y vinculación de overlays mediante `hooksecurefunc` y caché débil (`healthBarCache`).

---

## 📝 Notas de Release y Futuras Mejoras Documentadas

- **Comportamiento al Salir de Grupo en Combate (`InCombatLockdown`)**:
  - *Nota*: Si el jugador abandona un grupo estando en combate, el sistema de protección de marcos de WoW (*Secure Frames*) impide modificar la visibilidad o estructura de los marcos de party dinámicamente. El refresco del marco de party en solitario (*Always-In-Party*) se procesará automáticamente de forma transparente en cuanto finalice el combate (`PLAYER_REGEN_ENABLED`). Este comportamiento es esperado y correcto por seguridad del motor de WoW.
- **Compatibilidad de Marcos de Unidad**:
  - *Nota*: Diseñado exclusivamente para la interfaz nativa de Blizzard. 
- **Futura Idea de Mejora**:
  - Añadir en el menú gráfico una opción para activar/desactivar individualmente los overlays de Party/Raid de forma independiente a la barra principal.

  - *Nota adicional*: Al abrir el edit mode el (*Always-In-Party*) desaparece y hay que hacer /reload o /shield party ,tras intentar arreglarlo de varias maneras solo conseguias maneras burdas (como checkear cada 20 secs si se esta mostrando el addon) y los comandos con el modo edit de blizzard no funcionaban correctamente asique se queda como bug conocido, ya lo arreglare cuando lo vea molesto, de momento es algo pasable.

---
**Versión**: 1.3 Release  
**Autor**: Seikarii  
