-- Shared event dispatcher for player and unit absorb updates.
-- Decouples absorption updates from UI and frame discovery.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

-- Shared discovery cache reused by Blizzard-frame integrations.
local compactFrameNames = addon.COMPACT_FRAME_NAMES or {}
addon.COMPACT_FRAME_NAMES = compactFrameNames

if not addon.COMPACT_FRAME_NAMES_INITIALIZED then
    local nameCount = 0
    for index = 1, 40 do
        nameCount = nameCount + 1
        compactFrameNames[nameCount] = "CompactRaidFrame" .. index
        nameCount = nameCount + 1
        compactFrameNames[nameCount] = "CompactPartyFrameMemberFrame" .. index
        nameCount = nameCount + 1
        compactFrameNames[nameCount] = "PartyMemberFrame" .. index
        nameCount = nameCount + 1
        compactFrameNames[nameCount] = "CompactPartyFrame" .. index
    end
    for group = 1, 8 do
        for slot = 1, 5 do
            nameCount = nameCount + 1
            compactFrameNames[nameCount] = "CompactRaidGroup" .. group .. "Slot" .. slot
        end
    end
    addon.COMPACT_FRAME_NAME_COUNT = nameCount
    addon.COMPACT_FRAME_NAMES_INITIALIZED = true
end

-- Keep hot-path API and standard-library lookups out of _G.
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
local pendingUnits = {}
local processingUnits = {}
local isThrottleScheduled = false
local eventFrame = CreateFrame("Frame")
local throttleElapsed = 0

local THROTTLE_INTERVAL = 0.033 -- ~30 FPS micro-throttle for visual updates

local relevantUnits = { player = true }
for index = 1, 4 do
    relevantUnits["party" .. index] = true
end
for index = 1, 40 do
    relevantUnits["raid" .. index] = true
end

-- Export functions guaranteed on initial execution
function addon.RegisterPlayerUpdateListener(listener)
    if type(listener) == "function" then
        table_insert(playerListeners, listener)
    end
end

function addon.RegisterUnitUpdateListener(listener)
    if type(listener) == "function" then
        table_insert(unitListeners, listener)
    end
end

function addon.RegisterRegenListener(listener)
    if type(listener) == "function" then
        table_insert(regenListeners, listener)
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

    -- A listener can indirectly queue another update while this flush runs.
    -- Keep the driver active in that case so no update is silently lost.
    if next(pendingUnits) then
        throttleElapsed = 0
    else
        isThrottleScheduled = false
        eventFrame:SetScript("OnUpdate", nil)
    end
end

local function OnThrottleUpdate(_, elapsed)
    throttleElapsed = throttleElapsed + elapsed
    if throttleElapsed >= THROTTLE_INTERVAL then
        FlushUpdates()
    end
end

local function ScheduleUnitUpdate(unit)
    if not unit or not relevantUnits[unit] then return end
    pendingUnits[unit] = true
    if not isThrottleScheduled then
        isThrottleScheduled = true
        throttleElapsed = 0
        eventFrame:SetScript("OnUpdate", OnThrottleUpdate)
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
