-- Synthetic benchmark: event dispatch, overlay update, discovery, Mouse idle/on paths.
local wow = dofile("test/perf/harness.lua")
wow.load()
wow.fire("PLAYER_LOGIN")
local addon = BloodShieldOverlay
local bar = wow.new_frame("StatusBar", "BenchmarkHealthBar")
local overlay = addon.CreateAbsorbOverlay(bar)
local iterations = tonumber(arg[1]) or 100000
local updates = 0
addon.RegisterUnitUpdateListener(function() updates = updates + 1 end)

local startMemory = collectgarbage("count")
local start = os.clock()
for i = 1, iterations do
    wow.fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    wow.tick(0.034)
end
local elapsed = os.clock() - start
local endMemory = collectgarbage("count")

local updateStart = os.clock()
for i = 1, iterations do addon.UpdateAbsorbOverlay(overlay, i % 1000, 1000) end
local updateElapsed = os.clock() - updateStart

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

-- Repeated-value overlay updates: measures the early-return dedupe path.
local staticOverlay = addon.CreateAbsorbOverlay(wow.new_frame("StatusBar", "BenchmarkStaticHealthBar"))
local staticIterations = iterations
local staticStart = os.clock()
for _ = 1, staticIterations do
    addon.UpdateAbsorbOverlay(staticOverlay, 250, 1000)
end
local staticElapsed = os.clock() - staticStart

local playerBarIterations = math.max(1000, math.floor(iterations / 10))
local playerBarStart = os.clock()
if addon.UpdateSpecialResources then
    for _ = 1, playerBarIterations do addon.UpdateSpecialResources() end
end
local playerBarElapsed = os.clock() - playerBarStart

local classOverlayContainer = wow.new_frame("Frame", "BenchmarkClassOverlayContainer")
local classOverlayMember = wow.new_frame("Frame", "BenchmarkClassOverlayMember", classOverlayContainer)
classOverlayMember.displayedUnit = "player"
local classOverlayPowerBar = wow.new_frame("StatusBar", "BenchmarkClassOverlayPowerBar", classOverlayMember)
PartyFrame = classOverlayContainer
wow.set_group(true, false)
if addon.SetClassResourceOverlayEnabled then addon.SetClassResourceOverlayEnabled(true) end
wow.flush_timers()
local classOverlayIterations = math.max(1000, math.floor(iterations / 10))
local classOverlayStart = os.clock()
if addon.SetClassResourceOverlayPipSize then
    for _ = 1, classOverlayIterations do addon.SetClassResourceOverlayPipSize(12, 6) end
end
local classOverlayElapsed = os.clock() - classOverlayStart

-- Mouse OFF: all mouse features remain disabled, so no overlay or OnUpdate may exist.
local mouseOverlayOffCreated = _G["BloodShieldOverlayMouseResources"] ~= nil
local mouseOverlayOffOnUpdate = mouseOverlayOffCreated and _G["BloodShieldOverlayMouseResources"]:GetScript("OnUpdate") ~= nil
local mouseOffStart = os.clock()
for _ = 1, iterations do wow.tick(0.016) end
local mouseOffElapsed = os.clock() - mouseOffStart

-- Mouse ON: measure the same tick loop after explicitly enabling it.
addon.SetMouseResourceOverlayEnabled(true)
local mouseOverlay = _G["BloodShieldOverlayMouseResources"]
local mouseOnOnUpdate = mouseOverlay and mouseOverlay:GetScript("OnUpdate") ~= nil
local mouseOnStart = os.clock()
for _ = 1, iterations do wow.tick(0.016) end
local mouseOnElapsed = os.clock() - mouseOnStart
addon.SetMouseResourceOverlayEnabled(false)
local mouseOffAfterDisableOnUpdate = mouseOverlay and mouseOverlay:GetScript("OnUpdate") ~= nil

local result = string.format(
    "iterations=%d\ndispatch_seconds=%.6f\ndispatch_ops_per_second=%.2f\noverlay_seconds=%.6f\noverlay_ops_per_second=%.2f\ndiscovery_iterations=%d\ndiscovery_seconds=%.6f\ndiscovery_ops_per_second=%.2f\nstatic_overlay_iterations=%d\nstatic_overlay_seconds=%.6f\nstatic_overlay_ops_per_second=%.2f\nplayerbar_iterations=%d\nplayerbar_seconds=%.6f\nplayerbar_ops_per_second=%.2f\nclassoverlay_iterations=%d\nclassoverlay_seconds=%.6f\nclassoverlay_ops_per_second=%.2f\nmouse_off_overlay_created=%s\nmouse_off_onupdate_installed=%s\nmouse_off_tick_seconds=%.6f\nmouse_off_tick_ops_per_second=%.2f\nmouse_on_onupdate_installed=%s\nmouse_on_tick_seconds=%.6f\nmouse_on_tick_ops_per_second=%.2f\nmouse_off_after_disable_onupdate=%s\nlistener_updates=%d\nheap_delta_kb=%.2f\n",
    iterations, elapsed, iterations / math.max(elapsed, 0.000001), updateElapsed,
    iterations / math.max(updateElapsed, 0.000001), discoveryIterations, discoveryElapsed,
    discoveryIterations / math.max(discoveryElapsed, 0.000001), staticIterations, staticElapsed,
    staticIterations / math.max(staticElapsed, 0.000001), playerBarIterations, playerBarElapsed,
    playerBarIterations / math.max(playerBarElapsed, 0.000001), classOverlayIterations,
    classOverlayElapsed, classOverlayIterations / math.max(classOverlayElapsed, 0.000001),
    tostring(mouseOverlayOffCreated), tostring(mouseOverlayOffOnUpdate), mouseOffElapsed,
    iterations / math.max(mouseOffElapsed, 0.000001), tostring(mouseOnOnUpdate), mouseOnElapsed,
    iterations / math.max(mouseOnElapsed, 0.000001), tostring(mouseOffAfterDisableOnUpdate),
    updates, endMemory - startMemory)
print(result)
local output = assert(io.open("test/result/benchmark-latest.txt", "w"))
output:write(result)
output:close()
