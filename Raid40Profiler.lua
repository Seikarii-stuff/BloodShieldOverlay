-- Opt-in profiler for raid roster/layout churn.
-- Disabled by default; when enabled it measures only the discovery/layout
-- paths that can spike during 20-40 player roster changes.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local profiler = {
    enabled = false,
    calls = {},
    elapsed = {},
    events = {},
    max = {},
    stack = {},
    sequence = 0,
    rosterChanges = 0,
}

local function now()
    if debugprofilestop then
        return debugprofilestop()
    end
    return os.clock() * 1000
end

local function ensure(name)
    profiler.calls[name] = profiler.calls[name] or 0
    profiler.elapsed[name] = profiler.elapsed[name] or 0
    profiler.max[name] = profiler.max[name] or 0
end

function profiler:Reset()
    self.calls = {}
    self.elapsed = {}
    self.events = {}
    self.max = {}
    self.stack = {}
    self.sequence = 0
    self.rosterChanges = 0
end

function profiler:SetEnabled(value)
    self.enabled = value and true or false
    self.stack = {}
end

function profiler:IsEnabled()
    return self.enabled
end

function profiler:Event(name)
    if not self.enabled then return end
    self.events[name] = (self.events[name] or 0) + 1
    if name == "GROUP_ROSTER_UPDATE" then
        self.rosterChanges = self.rosterChanges + 1
        self.sequence = self.sequence + 1
    end
end

function profiler:Begin(name)
    if not self.enabled then return nil end
    ensure(name)
    self.calls[name] = self.calls[name] + 1
    local token = { name = name, start = now() }
    self.stack[#self.stack + 1] = token
    return token
end

function profiler:End(token)
    if not self.enabled or not token then return end
    local elapsed = now() - token.start
    self.elapsed[token.name] = self.elapsed[token.name] + elapsed
    if elapsed > self.max[token.name] then
        self.max[token.name] = elapsed
    end
    for index = #self.stack, 1, -1 do
        if self.stack[index] == token then
            table.remove(self.stack, index)
            break
        end
    end
end

function profiler:Measure(name, fn, ...)
    if not self.enabled then
        return fn(...)
    end
    local token = self:Begin(name)
    local results = { fn(...) }
    self:End(token)
    return unpack(results)
end

local function sortedNames(map)
    local names = {}
    for name in pairs(map) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function profiler:Report()
    print("BloodShieldOverlay raid40 profiler")
    print("enabled=" .. tostring(self.enabled) .. " roster_changes=" .. tostring(self.rosterChanges))

    local eventNames = sortedNames(self.events)
    for _, name in ipairs(eventNames) do
        print(string.format("event %-34s %d", name, self.events[name]))
    end

    local names = sortedNames(self.calls)
    for _, name in ipairs(names) do
        local calls = self.calls[name]
        local total = self.elapsed[name] or 0
        local maximum = self.max[name] or 0
        print(string.format("section %-30s calls=%-5d total=%8.3fms avg=%7.3fms max=%7.3fms", name, calls, total, total / math.max(calls, 1), maximum))
    end

    if #names == 0 then
        print("No profiled sections recorded yet.")
    end
end

function profiler:Snapshot()
    local snapshot = {
        enabled = self.enabled,
        rosterChanges = self.rosterChanges,
        calls = {},
        elapsed = {},
        max = {},
        events = {},
    }
    for name, value in pairs(self.calls) do snapshot.calls[name] = value end
    for name, value in pairs(self.elapsed) do snapshot.elapsed[name] = value end
    for name, value in pairs(self.max) do snapshot.max[name] = value end
    for name, value in pairs(self.events) do snapshot.events[name] = value end
    return snapshot
end

addon.Raid40Profiler = profiler

function addon.Raid40ProfilerStart()
    profiler:Reset()
    profiler:SetEnabled(true)
    print("BloodShieldOverlay: raid40 profiler STARTED. Reproduce the 20-40 player join/leave hitch, then /shield raidprof report")
end

function addon.Raid40ProfilerStop()
    profiler:SetEnabled(false)
    print("BloodShieldOverlay: raid40 profiler STOPPED.")
end
