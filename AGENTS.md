# 🚀 Agent & Developer Guide: BloodShieldOverlay Architecture

Welcome to **BloodShieldOverlay**, a high-performance, ultra-lightweight World of Warcraft addon designed for low overhead and stable operation across modern Retail UI layouts.

This repository documents a performance-oriented implementation of common high-efficiency Lua patterns for the World of Warcraft client environment. Offline benchmarks are synthetic and do not establish in-client correctness or performance guarantees.

**Current release:** 2.1. This release includes `ClassResourceOverlay.lua` for rendering the player's special resources horizontally on the bottom edge of the player's party/raid resource bar.

---

## 📊 Performance Benchmarks

- **Memory Footprint:** Synthetic measurements are recorded in `test/result/benchmark-latest.txt` when a benchmark result is generated; values vary by Lua runtime, client build and UI state.
- **CPU Footprint:** Synthetic throughput measurements are comparative signals, not production guarantees.
- **Garbage Generation:** Hot event dispatch reuses its queues; discovery and UI construction may allocate as frames change.
- **Taint / Lockdown Violations:** All state-changing discovery paths guard combat lockdown; verify protected-frame behavior in the target client build.

---

## 🛠️ Key Lua & Addon Optimization Techniques

This section details the architectural patterns and Lua techniques utilized throughout the codebase that achieve its minimal resource usage.

### 1. Zero-Allocation Event Throttling (`Core.lua`)
- **Micro-Throttled Flush Loop:** Rapidly firing Blizzard events (`UNIT_HEALTH`, `UNIT_ABSORB_AMOUNT_CHANGED`) do not trigger immediate UI re-renders. Instead, affected units are flagged in a pre-allocated key-value table (`pendingUnits`).
- **30 FPS Execution Bucket:** An on-demand `OnUpdate` accumulator batches pending updates into a discrete ~0.033-second window. Its script is installed only while work is pending and removed immediately after the queue drains; no recurring timer objects are created.
- **Table Recycling:** The engine moves keys between `pendingUnits` and `processingUnits` without re-creating or instantiating new tables during runtime.
- **Re-entrant Safety:** If a listener queues a unit while a flush is running, the driver remains active for one further bucket instead of dropping that update.

### 1.1 Hot-Path Lookup Elimination (`Core.lua`, `BlizzardFrames.lua`)
- Frequently called WoW API functions and Lua helpers are captured as local upvalues, avoiding repeated `_G` lookups in event, update, and discovery paths.
- `ScanCompactFrames` walks a one-time static cache of Blizzard frame names. The hot scan performs `_G[name]` resolution only; it does not concatenate frame-name strings.
- Supported units use fixed lookup tables for `player`, `party1`–`party4`, and `raid1`–`raid40`, avoiding pattern matching during scans and secure hooks.

### 2. Weak-Key Tables for Garbage Collector Friendly Caching (`BlizzardFrames.lua`)
- Frame resolution (`GetHealthBar`, `GetUnit`) uses weak-table caching (`setmetatable({}, { __mode = "k" })`).
- When Blizzard UI frames are recycled or destroyed by the client engine, references in `healthBarCache`, `overlaysByHealthBar`, and `foundHealthBars` are automatically collected by the Lua Garbage Collector without memory leaks or stale pointer retention.
- **False Sentinel Caching:** Unmatched frames store `false` (`healthBarCache[frame] = false`) to prevent repeated expensive hierarchy walks for negative hits.

### 3. Combat Lockdown Safety & Taint Prevention
- All frame discovery and party frame manipulations check `InCombatLockdown()` before executing state-changing operations.
- Operations during combat are queued via pending state and retried safely after `PLAYER_REGEN_ENABLED`.
- Explicit `IsForbiddenFrame` calls safeguard against protected or secure frame access errors.

### 4. Bounded Container Scanning
- Container scanning (`ScanContainerChildren`, `ScanCompactFrames`) uses bounded child lists and direct loops.
- Discovery is not a combat-frame loop; allocations are measured by the benchmark rather than claimed as zero.
- `ClassResourceOverlay.lua` uses fixed compact-frame name caches and bounded hierarchy discovery; it does not enumerate all global frames.

### 5. Event Bus Decoupling
- `Core.lua` owns shared layout/roster/scale event dispatch through `RegisterLayoutListener`, alongside the existing player/unit/regen listeners.
- Consumers subscribe instead of creating independent layout event frames, reducing duplicated discovery scheduling.

### 6. Minimalist Render Engine (`AbsorbIndicator.lua`, `PlayerBar.lua`, `BloodShieldOverlay.lua`)
- Render textures rely on native status bar primitives (`Interface\\Buttons\\WHITE8x8`).
- `Core.lua` uses a demand-driven `OnUpdate` throttle for absorb updates, and `PlayerBar.lua` uses a separate 10 Hz `OnUpdate` only while a special resource pip is charging. Both scripts are removed when their work is complete; the addon otherwise remains event-driven.
- Overlay elements are set to `EnableMouse(false)`, removing them from the client's hit-testing pass.

### 6.1 Horizontal Class-Resource Overlay (`ClassResourceOverlay.lua`)
- Reuses `addon.CreateSpecialResourceProvider()` from `ResourceProviders.lua`; class-specific rules are not duplicated in the UI module.
- Pre-creates a maximum of seven horizontal `StatusBar` pips and reuses their progress/state tables during updates.
- Anchors the overlay to the player's Blizzard power/mana bar in compact party, compact raid, legacy party, or fallback player-frame layouts.
- Discovery and reparenting are guarded by `InCombatLockdown()` and retried after `PLAYER_REGEN_ENABLED` or the next shared layout pass.
- Resource changes are event-driven through `UNIT_POWER_UPDATE`, `UNIT_POWER_FREQUENT`, `UNIT_MAXPOWER`, and `RUNE_POWER_UPDATE`; there is no permanent polling loop.

### 7. Test and Benchmark Workflow
- Offline smoke test: `lua test/perf/smoke.lua` — validates loading, public API wiring, event coalescing, menu initialization, combat-deferred refresh, bounded frame discovery and module integration. Output is grouped by functional area and ends with assertion/pass/fail/error totals; failures produce a non-zero exit code.
- Offline unit tests: `lua test/unit/unit.lua` — exercises deterministic configuration defaults/validation/migration/reset, event dispatch, frame discovery, target-of-target combat deferral and the small legacy Mouse-overlay removal regression check. Every unit case calls `wow.reset_and_load()` from `test/perf/harness.lua`, restoring the mock baseline and loading a fresh addon instance so globals, frames, timers, listeners and profiles do not leak between cases.
- Aggregate functional runner: `lua test/test_all.lua` — runs smoke and unit suites as independent Lua processes and reports their exit codes. It deliberately excludes the benchmark because performance measurement is not a functional test gate.
- Synthetic benchmark: `lua test/benchmark/benchmark.lua 100000` — measures dispatch, overlay updates, discovery throughput, player/group resource paths, listener count and Lua heap delta. Benchmark assertions are intentionally kept separate from functional tests.
- Generated result: `test/result/benchmark-latest.txt` when generated by the benchmark command.
- The harness is intentionally offline and does not replace in-client PTR/Retail validation with protected frames, Edit Mode and 40-player raid layouts.

---

## 💡 Why Use This Repository as a Template?

1. **Production-Oriented:** The offline suite covers loading and representative event/UI paths; in-client validation is still required for each Retail/PTR build.
2. **Clean Modularity:** Core updates, frame discovery, rendering, and UI config are decoupled into discrete, easily readable files.
3. **Copy-Paste Architecture:** The frame discovery engine in `BlizzardFrames.lua` provides a blueprint for targeting Blizzard frames across modern retail interface updates.

Feel free to fork, adapt, or adopt these architectural patterns for your own WoW addons!
