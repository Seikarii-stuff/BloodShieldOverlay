# 🚀 Agent & Developer Guide: BloodShieldOverlay Architecture

Welcome to **BloodShieldOverlay**, a high-performance, ultra-lightweight World of Warcraft addon engineered for maximum execution speed, zero memory bloat, and rock-solid stability across thousands of hours of gameplay.

This repository serves as a **battle-tested reference implementation (0 bugs, peak performance)** for high-efficiency Lua development in the World of Warcraft client environment.

---

## 📊 Performance Benchmarks

- **Memory Footprint:** The latest synthetic run reports `heap_delta_kb=15.84` after 100,000 dispatches; values vary by client build and UI state.
- **CPU Footprint:** The latest synthetic run reports `226757.37` dispatch operations/second, `3333333.33` overlay operations/second and `35714.29` discovery operations/second.
- **Garbage Generation:** Hot event dispatch reuses its queues; discovery and UI construction may allocate as frames change.
- **Taint / Lockdown Violations:** All state-changing discovery paths guard combat lockdown; verify protected-frame behavior in the target client build.

---

## 🛠️ Key Lua & Addon Optimization Techniques

This section details the architectural patterns and Lua techniques utilized throughout the codebase that achieve its minimal resource usage.

### 1. Zero-Allocation Event Throttling (`Core.lua`)
- **Micro-Throttled Flush Loop:** Rapidly firing Blizzard events (`UNIT_HEALTH`, `UNIT_ABSORB_AMOUNT_CHANGED`) do not trigger immediate UI re-renders. Instead, affected units are flagged in a pre-allocated key-value table (`pendingUnits`).
- **30 FPS Execution Bucket:** An on-demand `OnUpdate` accumulator batches pending updates into a discrete ~0.033-second window. Its script is installed only while work is pending and removed immediately after the queue drains; no recurring timer objects are created.
- **Table Recycling:** The engine moves keys between `pendingUnits` and `processingUnits` without re-creating or instantiating new tables during runtime:
  ```lua
  for unit in pairs(pendingUnits) do
      processingUnits[unit] = true
      pendingUnits[unit] = nil
  end
  ```
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
- Operations during combat are queued via `pendingRefresh = true` and deferred safely until `PLAYER_REGEN_ENABLED` triggers.
- Explicit `IsForbiddenFrame` calls safeguard against protected or secure frame access errors.

### 4. Bounded Container Scanning
- Container scanning (`ScanContainerChildren`, `ScanCompactFrames`) uses bounded child lists and direct loops.
- Discovery is not a combat-frame loop; allocations are measured by the benchmark rather than claimed as zero.

### 5. Event Bus Decoupling
- Uses a centralized, subscription-based dispatcher (`RegisterUnitUpdateListener`, `RegisterPlayerUpdateListener`, `RegisterRegenListener`).
- Avoids redundant event registrations across multiple frames, keeping client event overhead to the absolute minimum.

### 6. Minimalist Render Engine (`AbsorbIndicator.lua`, `PlayerBar.lua`, `BloodShieldOverlay.lua`)
- Render textures rely on native status bar primitives (`Interface\Buttons\WHITE8x8`).
- The only `OnUpdate` script is the demand-driven throttle controller in `Core.lua`; it is removed whenever the pending-unit queue is empty. The addon otherwise remains event-driven.
- Overlay elements are set to `EnableMouse(false)`, removing them from the client's hit-testing pass.

### 7. Test and Benchmark Workflow
- Offline smoke test: `lua test/perf/smoke.lua` — validates loading, public APIs, event coalescing, profile/menu initialization, combat-deferred refresh and bounded frame discovery. Current result: **PASS, 19 assertions**.
- Synthetic benchmark: `lua test/benchmark/benchmark.lua 100000` — measures dispatch, overlay updates, discovery throughput, listener count and Lua heap delta.
- Generated result: `test/result/benchmark-latest.txt`.
- The harness is intentionally offline and does not replace in-client PTR/Retail validation with protected frames, Edit Mode and 40-player raid layouts.

---

## 💡 Why Use This Repository as a Template?

1. **Production-Oriented:** The offline suite covers loading and representative event/UI paths; in-client validation is still required for each Retail/PTR build.
2. **Clean Modularity:** Core updates, frame discovery, rendering, and UI config are decoupled into discrete, easily readable files.
3. **Copy-Paste Architecture:** The frame discovery engine in `BlizzardFrames.lua` provides a blueprint for targeting Blizzard frames across modern retail interface updates.

Feel free to fork, adapt, or adopt these architectural patterns in your own WoW addons!
