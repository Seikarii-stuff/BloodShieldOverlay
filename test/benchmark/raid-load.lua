-- Raid-load benchmark: compare the addon cost at 25 vs 40 compact raid frames.
-- This is intentionally separate from the generic benchmark: it measures the
-- actual frame-discovery and per-unit absorb-update paths that matter in raids.
local wow = dofile("test/perf/harness.lua")
wow.load()
wow.fire("PLAYER_LOGIN")
local addon = BloodShieldOverlay

local function makeRaidFrames()
    for index = 1, 40 do
        local unit = "raid" .. index
        local frame = wow.new_frame("Frame", "CompactRaidFrame" .. index)
        frame.displayedUnit = unit
        frame.healthBar = wow.new_frame("StatusBar", "RaidHealthBar" .. index, frame)
        frame.healthBar:SetMinMaxValues(0, 1000)
        frame.healthBar:SetValue(1000)
    end

    -- Compact raid group slots are also walked by FrameDiscovery.lua. Reuse
    -- the same 40 logical members rather than creating a second 40-frame tree.
    for index = 1, 40 do
        local group = math.floor((index - 1) / 5) + 1
        local slot = ((index - 1) % 5) + 1
        local frame = wow.new_frame("Frame", "CompactRaidGroup" .. group .. "Slot" .. slot)
        frame.displayedUnit = "raid" .. index
    end
end

local function fmt(value)
    return string.format("%.6f", value)
end

local function runDiscovery(label, memberCount, iterations)
    wow.set_group(true, true, memberCount)
    wow.reset_get_children_calls()
    collectgarbage("collect")
    local before = collectgarbage("count")
    local start = os.clock()

    for _ = 1, iterations do
        addon.RequestRefresh()
        wow.flush_timers()
    end

    local elapsed = os.clock() - start
    local live = collectgarbage("count") - before
    collectgarbage("collect")
    local retained = collectgarbage("count") - before

    return {
        label = label,
        members = memberCount,
        iterations = iterations,
        seconds = elapsed,
        ops = iterations / math.max(elapsed, 0.000001),
        children = wow.get_children_calls(),
        live = live,
        retained = retained,
    }
end

local function runUnitUpdates(label, memberCount, rounds)
    wow.set_group(true, true, memberCount)
    local start = os.clock()
    local operations = 0

    for _ = 1, rounds do
        for index = 1, memberCount do
            wow.fire("UNIT_ABSORB_AMOUNT_CHANGED", "raid" .. index)
            wow.tick(0.034)
            operations = operations + 1
        end
    end

    local elapsed = os.clock() - start
    collectgarbage("collect")
    return {
        label = label,
        members = memberCount,
        rounds = rounds,
        operations = operations,
        seconds = elapsed,
        ops = operations / math.max(elapsed, 0.000001),
        heap = collectgarbage("count"),
    }
end

makeRaidFrames()
wow.set_group(true, true, 40)
wow.fire("GROUP_ROSTER_UPDATE")
wow.flush_timers()

local discoveryIterations = 2000
local updateRounds = 100

local d25 = runDiscovery("discovery_25", 25, discoveryIterations)
local u25 = runUnitUpdates("updates_25", 25, updateRounds)
local d40 = runDiscovery("discovery_40", 40, discoveryIterations)
local u40 = runUnitUpdates("updates_40", 40, updateRounds)

local result = string.format(
    "discovery_iterations=%d\nupdate_rounds=%d\n\n" ..
    "%s_members=%d\n%s_seconds=%s\n%s_ops_per_second=%.2f\n%s_getchildren=%d\n%s_heap_live_kb=%s\n%s_heap_retained_kb=%s\n\n" ..
    "%s_members=%d\n%s_seconds=%s\n%s_ops_per_second=%.2f\n%s_getchildren=%d\n%s_heap_live_kb=%s\n%s_heap_retained_kb=%s\n\n" ..
    "%s_members=%d\n%s_operations=%d\n%s_seconds=%s\n%s_ops_per_second=%.2f\n%s_heap_kb=%s\n\n" ..
    "%s_members=%d\n%s_operations=%d\n%s_seconds=%s\n%s_ops_per_second=%.2f\n%s_heap_kb=%s\n",
    discoveryIterations, updateRounds,
    d25.label, d25.members, d25.label, fmt(d25.seconds), d25.label, d25.ops,
    d25.label, d25.children, d25.label, fmt(d25.live), d25.label, fmt(d25.retained),
    d40.label, d40.members, d40.label, fmt(d40.seconds), d40.label, d40.ops,
    d40.label, d40.children, d40.label, fmt(d40.live), d40.label, fmt(d40.retained),
    u25.label, u25.members, u25.label, u25.operations, u25.label, fmt(u25.seconds),
    u25.label, u25.ops, u25.label, fmt(u25.heap),
    u40.label, u40.members, u40.label, u40.operations, u40.label, fmt(u40.seconds),
    u40.label, u40.ops, u40.label, fmt(u40.heap)
)

print(result)
local output = assert(io.open("test/result/raid-load-latest.txt", "w"))
output:write(result)
output:close()
