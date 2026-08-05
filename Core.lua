-- Shared event dispatcher for player and unit absorb updates.
-- # DEV: This core module decouples absorption updates from UI and frame discovery.
-- # DEV: Other modules can register listeners without depending directly on the WoW event system.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local playerListeners = {}
local unitListeners = {}
local pendingUnits = {}
local processingUnits = {}
local isThrottleScheduled = false
local eventFrame = CreateFrame("Frame")

local THROTTLE_INTERVAL = 0.033 -- ~30 FPS micro-throttle for visual updates

function addon.RegisterPlayerUpdateListener(listener)
    if type(listener) == "function" then
        table.insert(playerListeners, listener)
    end
end

function addon.RegisterUnitUpdateListener(listener)
    if type(listener) == "function" then
        table.insert(unitListeners, listener)
    end
end

local function FlushUpdates()
    isThrottleScheduled = false

    -- Move pending updates to processing table without allocating a new table
    for unit in pairs(pendingUnits) do
        processingUnits[unit] = true
        pendingUnits[unit] = nil
    end

    for unit in pairs(processingUnits) do
        processingUnits[unit] = nil
        local absorb = UnitGetTotalAbsorbs(unit) or 0
        local maxHealth = UnitHealthMax(unit) or 0

        for i = 1, #unitListeners do
            unitListeners[i](unit, absorb, maxHealth)
        end

        if unit == "player" then
            for i = 1, #playerListeners do
                playerListeners[i](absorb, maxHealth)
            end
        end
    end
end

local function ScheduleUnitUpdate(unit)
    if not unit then return end
    pendingUnits[unit] = true
    if not isThrottleScheduled then
        isThrottleScheduled = true
        C_Timer.After(THROTTLE_INTERVAL, FlushUpdates)
    end
end

eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
eventFrame:SetScript("OnEvent", function(_, _, unit)
    ScheduleUnitUpdate(unit)
end)
