-- Synthetic benchmark: event dispatch, overlay update, discovery, Mouse idle/on paths.
-- Optional second argument "heap" adds a verbose heap/object report; normal benchmark output is unchanged.
local wow = dofile("test/perf/harness.lua")
wow.load()
wow.fire("PLAYER_LOGIN")
local addon = BloodShieldOverlay
local bar = wow.new_frame("StatusBar", "BenchmarkHealthBar")
local overlay = addon.CreateAbsorbOverlay(bar)
local iterations = tonumber(arg[1]) or 100000
local heapDiagnostics = arg[2] == "heap"
local updates = 0
addon.RegisterUnitUpdateListener(function() updates = updates + 1 end)

local startMemory = collectgarbage("count")
local startObjects = wow.object_counts()
local checkpoints = {}

local function objectDelta(before, after)
    local names = {}
    for objectType in pairs(before) do if objectType ~= "total" then names[objectType] = true end end
    for objectType in pairs(after) do if objectType ~= "total" then names[objectType] = true end end
    local parts = {}
    for objectType in pairs(names) do
        local delta = (after[objectType] or 0) - (before[objectType] or 0)
        if delta ~= 0 then parts[#parts + 1] = objectType .. ":" .. delta end
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ",") or "none"
end

local function checkpoint(label, beforeObjects)
    local objectsBeforeGC = wow.object_counts()
    local heapBeforeGC = collectgarbage("count") - startMemory
    collectgarbage("collect")
    local heapAfterGC = collectgarbage("count") - startMemory
    local objectsAfterGC = wow.object_counts()
    checkpoints[#checkpoints + 1] = {
        label = label,
        heap = heapBeforeGC,
        retained = heapAfterGC,
        transient = heapBeforeGC - heapAfterGC,
        objects = objectDelta(beforeObjects or startObjects, objectsBeforeGC),
        totalObjects = objectsBeforeGC.total,
        objectsAfterGC = objectsAfterGC.total,
    }
    return objectsAfterGC
end

local start = os.clock()
for i = 1, iterations do
    wow.fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    wow.tick(0.034)
end
local elapsed = os.clock() - start
local objectsAfterDispatch = checkpoint("dispatch")

local updateStart = os.clock()
for i = 1, iterations do addon.UpdateAbsorbOverlay(overlay, i % 1000, 1000) end
local updateElapsed = os.clock() - updateStart
local objectsAfterOverlay = checkpoint("overlay", objectsAfterDispatch)

local discoveryIterations = math.max(1000, math.floor(iterations / 100))
local discoveryContainer = wow.new_frame("Frame", "BenchmarkPartyContainer")
local discoveryMember = wow.new_frame("Frame", "BenchmarkPartyMember", discoveryContainer)
discoveryMember.displayedUnit = "party1"
discoveryMember.healthBar = wow.new_frame("StatusBar", "BenchmarkPartyHealthBar", discoveryMember)
PartyFrame = discoveryContainer
wow.set_group(true, false)
local discoveryStart = os.clock()
for _ = 1, discoveryIterations do
    addon.RequestRefresh()
    wow.flush_timers()
end
local discoveryElapsed = os.clock() - discoveryStart
local objectsAfterDiscovery = checkpoint("discovery", objectsAfterOverlay)

-- Repeated-value overlay updates: measures the early-return dedupe path.
local staticOverlay = addon.CreateAbsorbOverlay(wow.new_frame("StatusBar", "BenchmarkStaticHealthBar"))
local staticIterations = iterations
local staticStart = os.clock()
for _ = 1, staticIterations do
    addon.UpdateAbsorbOverlay(staticOverlay, 250, 1000)
end
local staticElapsed = os.clock() - staticStart
local objectsAfterStatic = checkpoint("static_overlay", objectsAfterDiscovery)

local playerBarIterations = math.max(1000, math.floor(iterations / 10))
local playerBarStart = os.clock()
if addon.UpdateSpecialResources then
    for _ = 1, playerBarIterations do addon.UpdateSpecialResources() end
end
local playerBarElapsed = os.clock() - playerBarStart
local objectsAfterPlayerBar = checkpoint("playerbar", objectsAfterStatic)

local classOverlayContainer = wow.new_frame("Frame", "BenchmarkClassOverlayContainer")
local classOverlayMember = wow.new_frame("Frame", "BenchmarkClassOverlayMember", classOverlayContainer)
classOverlayMember.displayedUnit = "player"
local classOverlayPowerBar = wow.new_frame("StatusBar", "BenchmarkClassOverlayPowerBar", classOverlayMember)
PartyFrame = classOverlayContainer
wow.set_group(true, false)
local classEnableStart = os.clock()
if addon.SetClassResourceOverlayEnabled then addon.SetClassResourceOverlayEnabled(true) end
wow.flush_timers()
local classEnableElapsed = os.clock() - classEnableStart
local objectsAfterClassEnable = checkpoint("classoverlay_enable", objectsAfterPlayerBar)
local classOverlayIterations = math.max(1000, math.floor(iterations / 10))
local classOverlayStart = os.clock()
if addon.SetClassResourceOverlayPipSize then
    for _ = 1, classOverlayIterations do addon.SetClassResourceOverlayPipSize(12, 6) end
end
local classOverlayElapsed = os.clock() - classOverlayStart
local objectsAfterClassOverlay = checkpoint("classoverlay_update", objectsAfterClassEnable)

-- Mouse OFF: all mouse features remain disabled, so no overlay or OnUpdate may exist.
local mouseOverlayOffCreated = _G["BloodShieldOverlayMouseResources"] ~= nil
local mouseOverlayOffOnUpdate = mouseOverlayOffCreated and _G["BloodShieldOverlayMouseResources"]:GetScript("OnUpdate") ~= nil
local mouseOffStart = os.clock()
for _ = 1, iterations do wow.tick(0.016) end
local mouseOffElapsed = os.clock() - mouseOffStart
local objectsAfterMouseOff = checkpoint("mouse_off", objectsAfterClassOverlay)

-- Mouse ON: separate creation from the repeated tick/update path.
local mouseEnableStart = os.clock()
addon.SetMouseResourceOverlayEnabled(true)
local mouseOverlay = _G["BloodShieldOverlayMouseResources"]
local mouseOnOnUpdate = mouseOverlay and mouseOverlay:GetScript("OnUpdate") ~= nil
local mouseEnableElapsed = os.clock() - mouseEnableStart
local objectsAfterMouseEnable = checkpoint("mouse_enable", objectsAfterMouseOff)

local mouseOnStart = os.clock()
for _ = 1, iterations do wow.tick(0.016) end
local mouseOnElapsed = os.clock() - mouseOnStart
local objectsAfterMouseOn = checkpoint("mouse_update", objectsAfterMouseEnable)

addon.SetMouseResourceOverlayEnabled(false)
local mouseOffAfterDisableOnUpdate = mouseOverlay and mouseOverlay:GetScript("OnUpdate") ~= nil
local objectsAfterMouseDisable = checkpoint("mouse_disable", objectsAfterMouseOn)

local endMemory = collectgarbage("count")
local retainedBeforeGC = endMemory - startMemory
collectgarbage("collect")
local retainedAfterGC = collectgarbage("count") - startMemory

local heapReport = {}
for _, item in ipairs(checkpoints) do
    heapReport[#heapReport + 1] = string.format(
        "%s: live=%+0.2f KB, retained=%+0.2f KB, transient=%+0.2f KB, objects=%s, total_objects=%d, after_gc_objects=%d",
        item.label, item.heap, item.retained, item.transient, item.objects, item.totalObjects, item.objectsAfterGC)
end

local result = string.format(
    "iterations=%d\ndispatch_seconds=%.6f\ndispatch_ops_per_second=%.2f\noverlay_seconds=%.6f\noverlay_ops_per_second=%.2f\ndiscovery_iterations=%d\ndiscovery_seconds=%.6f\ndiscovery_ops_per_second=%.2f\nstatic_overlay_iterations=%d\nstatic_overlay_seconds=%.6f\nstatic_overlay_ops_per_second=%.2f\nplayerbar_iterations=%d\nplayerbar_seconds=%.6f\nplayerbar_ops_per_second=%.2f\nclassoverlay_enable_seconds=%.6f\nclassoverlay_iterations=%d\nclassoverlay_seconds=%.6f\nclassoverlay_ops_per_second=%.2f\nmouse_off_overlay_created=%s\nmouse_off_onupdate_installed=%s\nmouse_off_tick_seconds=%.6f\nmouse_off_tick_ops_per_second=%.2f\nmouse_enable_seconds=%.6f\nmouse_on_onupdate_installed=%s\nmouse_on_tick_seconds=%.6f\nmouse_on_tick_ops_per_second=%.2f\nmouse_off_after_disable_onupdate=%s\nlistener_updates=%d\nheap_delta_kb=%.2f\nheap_retained_after_gc_kb=%.2f\nheap_diagnostics=%s\n",
    iterations, elapsed, iterations / math.max(elapsed, 0.000001), updateElapsed,
    iterations / math.max(updateElapsed, 0.000001), discoveryIterations, discoveryElapsed,
    discoveryIterations / math.max(discoveryElapsed, 0.000001), staticIterations, staticElapsed,
    staticIterations / math.max(staticElapsed, 0.000001), playerBarIterations, playerBarElapsed,
    playerBarIterations / math.max(playerBarElapsed, 0.000001), classEnableElapsed, classOverlayIterations,
    classOverlayElapsed, classOverlayIterations / math.max(classOverlayElapsed, 0.000001),
    tostring(mouseOverlayOffCreated), tostring(mouseOverlayOffOnUpdate), mouseOffElapsed,
    iterations / math.max(mouseOffElapsed, 0.000001), mouseEnableElapsed, tostring(mouseOnOnUpdate), mouseOnElapsed,
    iterations / math.max(mouseOnElapsed, 0.000001), tostring(mouseOffAfterDisableOnUpdate),
    updates, retainedBeforeGC, retainedAfterGC, heapDiagnostics and table.concat(heapReport, "\n") or "run with: lua test/benchmark/benchmark.lua 100000 heap")
print(result)
local output = assert(io.open("test/result/benchmark-latest.txt", "w"))
output:write(result)
output:close()
