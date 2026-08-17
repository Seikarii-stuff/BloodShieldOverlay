-- Shared event dispatcher for player, unit absorb and target-of-target updates.
-- Decouples absorption updates from UI and frame discovery.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealthMax = UnitHealthMax
local next = next
local pairs = pairs
local type = type
local table_insert = table.insert

local playerListeners = {}
local unitListeners = {}
local regenListeners = {}
local targetTargetListeners = {}
local pendingUnits = {}
local processingUnits = {}
local targetTargetPending = false
local isThrottleScheduled = false
local eventFrame = CreateFrame("Frame")
local throttleElapsed = 0

local THROTTLE_INTERVAL = 0.033 -- ~30 FPS micro-throttle for visual updates

local relevantUnits = { player = true, targettarget = true }
for index = 1, 4 do
    relevantUnits["party" .. index] = true
end
for index = 1, 40 do
    relevantUnits["raid" .. index] = true
end

function addon.RegisterPlayerUpdateListener(listener)
    if type(listener) == "function" then table_insert(playerListeners, listener) end
end

function addon.RegisterUnitUpdateListener(listener)
    if type(listener) == "function" then table_insert(unitListeners, listener) end
end

function addon.RegisterRegenListener(listener)
    if type(listener) == "function" then table_insert(regenListeners, listener) end
end

function addon.RegisterTargetTargetUpdateListener(listener)
    if type(listener) == "function" then table_insert(targetTargetListeners, listener) end
end

local function FlushUpdates()
    for unit in pairs(pendingUnits) do
        processingUnits[unit] = true
        pendingUnits[unit] = nil
    end

    for unit in pairs(processingUnits) do
        processingUnits[unit] = nil
        local absorb = UnitGetTotalAbsorbs(unit) or 0
        local maxHealth = UnitHealthMax(unit) or 0

        for i = 1, #unitListeners do unitListeners[i](unit, absorb, maxHealth) end

        if unit == "player" then
            for i = 1, #playerListeners do playerListeners[i](absorb, maxHealth) end
        end
    end

    if targetTargetPending then
        targetTargetPending = false
        for i = 1, #targetTargetListeners do targetTargetListeners[i]() end
    end

    if next(pendingUnits) or targetTargetPending then
        throttleElapsed = 0
    else
        isThrottleScheduled = false
        eventFrame:SetScript("OnUpdate", nil)
    end
end

local function OnThrottleUpdate(_, elapsed)
    throttleElapsed = throttleElapsed + elapsed
    if throttleElapsed >= THROTTLE_INTERVAL then FlushUpdates() end
end

local function EnsureThrottleScheduled()
    if not isThrottleScheduled then
        isThrottleScheduled = true
        throttleElapsed = 0
        eventFrame:SetScript("OnUpdate", OnThrottleUpdate)
    end
end

local function ScheduleUnitUpdate(unit)
    if not unit or not relevantUnits[unit] then return end
    pendingUnits[unit] = true
    EnsureThrottleScheduled()
end

function addon.ScheduleTargetTargetUpdate()
    targetTargetPending = true
    EnsureThrottleScheduled()
end

addon.ScheduleUnitUpdate = ScheduleUnitUpdate

eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        for i = 1, #regenListeners do regenListeners[i](event) end
        return
    end
    ScheduleUnitUpdate(unit)
end)
