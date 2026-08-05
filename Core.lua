-- Shared event dispatcher for player and unit absorb updates.
-- Decouples absorption updates from UI and frame discovery.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local playerListeners = {}
local unitListeners = {}
local regenListeners = {}
local pendingUnits = {}
local processingUnits = {}
local isThrottleScheduled = false
local eventFrame = CreateFrame("Frame")

local THROTTLE_INTERVAL = 0.033 -- ~30 FPS micro-throttle for visual updates

-- Export functions guaranteed on initial execution
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

function addon.RegisterRegenListener(listener)
    if type(listener) == "function" then
        table.insert(regenListeners, listener)
    end
end

local function FlushUpdates()
    -- Move pending updates to processing table without allocating new tables
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

    -- FIX: Reset flag at the end to avoid chained executions during loop processing
    isThrottleScheduled = false
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
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        for i = 1, #regenListeners do
            regenListeners[i](event)
        end
        return
    end

    ScheduleUnitUpdate(unit)
end)