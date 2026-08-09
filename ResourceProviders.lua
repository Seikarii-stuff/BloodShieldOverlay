-- Shared class-specific resource state and event driver.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local GetRuneCooldown = GetRuneCooldown
local GetTime = GetTime
local CreateFrame = CreateFrame
local math_min = math.min
local math_max = math.max

local MAX_RESOURCES = 7
local RUNE_COUNT = 6
local ESSENCE_CHARGE_DURATION = 4

-- Shared rendering step for both the standalone bar's vertical circles
-- (PlayerBar.lua) and the group-frame horizontal pips (ClassResourceOverlay.lua).
-- Fills progressBuf from the provider state, applies value/color to each pip
-- in `pips`, sorts orderBuf by progress, and returns the clamped pip count.
-- Positioning/sizing stays with the caller since the two layouts differ.
function addon.RenderResourcePips(state, pips, progressBuf, orderBuf, maxCount)
    local count = math_min(state.maximum or 0, maxCount)

    for index = 1, maxCount do
        local value = state.progress[index] or 0
        progressBuf[index] = value

        local pip = pips[index]
        pip:SetMinMaxValues(0, 1)
        pip:SetValue(value)
        if value >= 1 then
            pip:SetStatusBarColor(1, 0.82, 0, 1)
        else
            pip:SetStatusBarColor(1, 1, 1, 1)
        end
    end

    addon.SortSpecialResources(progressBuf, orderBuf, count)
    return count
end

function addon.SortSpecialResources(progress, order, count)
    for position = 2, count do
        local candidate = order[position]
        local candidateProgress = progress[candidate]
        local insertAt = position - 1
        while insertAt >= 1 and progress[order[insertAt]] < candidateProgress do
            order[insertAt + 1] = order[insertAt]
            insertAt = insertAt - 1
        end
        order[insertAt + 1] = candidate
    end
end

local function CreatePowerProvider(powerType)
    local state = { progress = {}, maximum = 0, charging = false }
    return {
        GetMax = function()
            return math_min(UnitPowerMax("player", powerType) or 0, MAX_RESOURCES)
        end,
        Refresh = function()
            local current = UnitPower("player", powerType) or 0
            local maximum = math_min(UnitPowerMax("player", powerType) or 0, MAX_RESOURCES)
            for index = 1, maximum do state.progress[index] = index <= current and 1 or 0 end
            for index = maximum + 1, MAX_RESOURCES do state.progress[index] = 0 end
            state.maximum, state.charging = maximum, false
        end,
        GetState = function() return state end,
    }
end

local function CreateEssenceProvider(powerType)
    local chargeStart
    local previousReadyCount
    local state = { progress = {}, maximum = 0, charging = false }
    return {
        GetMax = function()
            return math_min(UnitPowerMax("player", powerType) or 0, MAX_RESOURCES)
        end,
        Refresh = function(_, now)
            local current = UnitPower("player", powerType) or 0
            local maximum = math_min(UnitPowerMax("player", powerType) or 0, MAX_RESOURCES)
            local readyCount = math_min(current, maximum)
            if maximum <= 0 or readyCount >= maximum then
                chargeStart = nil
            elseif previousReadyCount == nil or readyCount > previousReadyCount or not chargeStart then
                chargeStart = now
            end
            previousReadyCount = readyCount
            for index = 1, maximum do
                if index <= readyCount then
                    state.progress[index] = 1
                elseif index == readyCount + 1 and chargeStart then
                    state.progress[index] = math_min(1, math_max(0, now - chargeStart) / ESSENCE_CHARGE_DURATION)
                else
                    state.progress[index] = 0
                end
            end
            for index = maximum + 1, MAX_RESOURCES do state.progress[index] = 0 end
            state.maximum = maximum
            state.charging = readyCount < maximum and chargeStart ~= nil
        end,
        GetState = function() return state end,
    }
end

local function CreateRuneProvider()
    local state = { progress = {}, maximum = RUNE_COUNT, charging = false }
    return {
        GetMax = function() return RUNE_COUNT end,
        Refresh = function(_, now)
            local charging = false
            for index = 1, RUNE_COUNT do
                local start, duration, ready = GetRuneCooldown(index)
                if ready then
                    state.progress[index] = 1
                elseif start and duration and duration > 0 then
                    state.progress[index] = math_max(0, math_min(1, (now - start) / duration))
                    charging = true
                else
                    state.progress[index] = 0
                end
            end
            state.charging = charging
        end,
        GetState = function() return state end,
    }
end

local provider
local resourceToken
local listeners = {}
local listenerCount = 0
local driver = CreateFrame("Frame")
local tickerElapsed = 0
local ticking = false
local RefreshProvider

function addon.GetSpecialResourceProvider(playerClass, powerTypes)
    if provider then return provider, resourceToken end
    if playerClass == "DEATHKNIGHT" then
        provider = CreateRuneProvider()
    elseif powerTypes then
        local definitions = {
            PALADIN = { powerTypes.HolyPower, "HOLY_POWER" },
            EVOKER = { powerTypes.Essence, "ESSENCE", true },
            WARLOCK = { powerTypes.SoulShards, "SOUL_SHARDS" },
            MONK = { powerTypes.Chi, "CHI" },
            ROGUE = { powerTypes.ComboPoints, "COMBO_POINTS" },
            DRUID = { powerTypes.ComboPoints, "COMBO_POINTS" },
        }
        local definition = definitions[playerClass]
        if definition and definition[1] then
            provider = definition[3] and CreateEssenceProvider(definition[1]) or CreatePowerProvider(definition[1])
            resourceToken = definition[2]
        end
    end
    if provider then provider:Refresh(GetTime()) end
    return provider, resourceToken
end

local function NotifyListeners()
    for index = 1, listenerCount do listeners[index]() end
end

local function OnDriverTick(_, elapsed)
    tickerElapsed = tickerElapsed + elapsed
    if tickerElapsed >= 0.1 then
        tickerElapsed = 0
        RefreshProvider()
    end
end

RefreshProvider = function()
    if not provider then return end
    provider:Refresh(GetTime())
    local state = provider:GetState()
    if state.charging and not ticking then
        ticking = true
        driver:SetScript("OnUpdate", OnDriverTick)
    elseif not state.charging and ticking then
        ticking = false
        tickerElapsed = 0
        driver:SetScript("OnUpdate", nil)
    end
    NotifyListeners()
end

function addon.RegisterSpecialResourceListener(listener)
    if type(listener) ~= "function" then return end
    listenerCount = listenerCount + 1
    listeners[listenerCount] = listener
    listener()
end

driver:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
driver:RegisterUnitEvent("UNIT_MAXPOWER", "player")
driver:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
driver:RegisterEvent("RUNE_POWER_UPDATE")
driver:SetScript("OnEvent", RefreshProvider)
