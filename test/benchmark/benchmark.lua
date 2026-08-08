-- Synthetic benchmark: event dispatch, overlay update, and refresh scheduling.
local wow = dofile("test/perf/harness.lua")
wow.load()
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
    wow.tick(0.033)
end
local elapsed = os.clock() - start
local endMemory = collectgarbage("count")
local updateStart = os.clock()
for i = 1, iterations do addon.UpdateAbsorbOverlay(overlay, i % 1000, 1000) end
local updateElapsed = os.clock() - updateStart

local result = string.format(
    "iterations=%d\ndispatch_seconds=%.6f\ndispatch_ops_per_second=%.2f\noverlay_seconds=%.6f\noverlay_ops_per_second=%.2f\nlistener_updates=%d\nheap_delta_kb=%.2f\n",
    iterations, elapsed, iterations / math.max(elapsed, 0.000001), updateElapsed,
    iterations / math.max(updateElapsed, 0.000001), updates, endMemory - startMemory)
print(result)
local output = assert(io.open("test/result/benchmark-latest.txt", "w"))
output:write(result)
output:close()
