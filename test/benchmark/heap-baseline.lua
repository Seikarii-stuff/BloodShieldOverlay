-- Calibrate the offline WoW harness allocation cost before interpreting addon heap deltas.
-- This intentionally creates the same number of generic mock UI objects used by the
-- Mouse overlay, without loading the addon. Run with: lua test/benchmark/heap-baseline.lua
local wow = dofile("test/perf/harness.lua")

local function heap()
    collectgarbage("collect")
    return collectgarbage("count")
end

local before = heap()
local beforeObjects = wow.object_counts()

-- Same object shape/count as the Mouse overlay creation path reported by the
-- benchmark: 2 Button, 2 Cooldown, 2 FontString, 1 Frame, 16 MaskTexture,
-- 7 StatusBar and 20 Texture objects. Parenting is intentionally omitted so
-- this measures object/method overhead rather than addon behavior.
local objects = {
    {"Button", 2}, {"Cooldown", 2}, {"FontString", 2}, {"Frame", 1},
    {"MaskTexture", 16}, {"StatusBar", 7}, {"Texture", 20},
}
for _, entry in ipairs(objects) do
    for _ = 1, entry[2] do wow.new_frame(entry[1]) end
end

local live = heap() - before
local afterObjects = wow.object_counts()
local objectParts = {}
for _, entry in ipairs(objects) do
    objectParts[#objectParts + 1] = entry[1] .. ":" .. entry[2]
end

print(string.format(
    "harness_heap_baseline_kb=%.2f\nobjects=%s\ntotal_objects=%d",
    live, table.concat(objectParts, ","), afterObjects.total - beforeObjects.total))
