-- Shared event dispatcher for player, unit absorb, target-of-target and layout updates.
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
local layoutListeners = {}
local pendingUnits = {}
local processingUnits = {}
local targetTargetPending = false
local isThrottleScheduled = false
local eventFrame = CreateFrame("Frame")
local throttleElapsed = 0

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

function addon.RegisterLayoutListener(listener)
    if type(listener) == "function" then table_insert(layoutListeners, listener) end
end

function addon.RequestRefresh()
    for i = 1, #layoutListeners do layoutListeners[i]("MANUAL_REFRESH") end
end

local function GetThrottleInterval()
    if type(addon.GetGraphicsUpdateInterval) == "function" then
        return addon.GetGraphicsUpdateInterval()
    end
    return 1 / 30
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
    if throttleElapsed >= GetThrottleInterval() then FlushUpdates() end
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
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        for i = 1, #regenListeners do regenListeners[i](event) end
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD"
        or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED"
        or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        for i = 1, #layoutListeners do layoutListeners[i](event) end
    end

    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        return
    end
    ScheduleUnitUpdate(unit)
end)
