-- Class-specific special-resource providers.
-- PlayerBar only renders provider output; it does not own class rules.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local GetRuneCooldown = GetRuneCooldown
local UnitPowerBarTimerInfo = UnitPowerBarTimerInfo
local GetTime = GetTime
local math_min = math.min
local math_max = math.max

local MAX_SPECIAL_CIRCLES = 7
local RUNE_COUNT = 6
local CHARGING_COLOR = { 1, 1, 1 }
local READY_COLOR = { 1, 0.82, 0 }

local function SetCircle(circle, progress, maximum, value, ready)
    circle:SetMinMaxValues(0, maximum)
    circle:SetValue(value)
    if ready then
        circle:SetStatusBarColor(READY_COLOR[1], READY_COLOR[2], READY_COLOR[3], 1)
    else
        circle:SetStatusBarColor(CHARGING_COLOR[1], CHARGING_COLOR[2], CHARGING_COLOR[3], 1)
    end
    return progress
end

local function CreatePowerProvider(powerType)
    return {
        GetMax = function()
            return math_min(UnitPowerMax("player", powerType) or 0, MAX_SPECIAL_CIRCLES)
        end,
        Update = function(_, progress, circles)
            local current = UnitPower("player", powerType) or 0
            local maximum = math_min(UnitPowerMax("player", powerType) or 0, MAX_SPECIAL_CIRCLES)
            for index = 1, maximum do
                local ready = index <= current
                progress[index] = ready and 1 or 0
                SetCircle(circles[index], progress[index], 1, progress[index], ready)
            end
            return maximum
        end,
    }
end

local function CreateEssenceProvider(powerType)
    return {
        GetMax = function()
            return math_min(UnitPowerMax("player", powerType) or 0, MAX_SPECIAL_CIRCLES)
        end,
        Update = function(_, progress, circles, now)
            local current = UnitPower("player", powerType) or 0
            local maximum = math_min(UnitPowerMax("player", powerType) or 0, MAX_SPECIAL_CIRCLES)
            local readyCount = math_min(current, maximum)
            local start, duration, modRate

            if UnitPowerBarTimerInfo then
                start, duration, modRate = UnitPowerBarTimerInfo("player", powerType)
            end

            for index = 1, maximum do
                if index <= readyCount then
                    progress[index] = 1
                    SetCircle(circles[index], 1, 1, 1, true)
                elseif index == readyCount + 1 and start and duration and duration > 0 then
                    local elapsed = (now - start) * (modRate or 1)
                    local value = math_max(0, math_min(1, elapsed / duration))
                    progress[index] = value
                    SetCircle(circles[index], value, 1, value, false)
                else
                    progress[index] = 0
                    SetCircle(circles[index], 0, 1, 0, false)
                end
            end
            return maximum
        end,
    }
end

local function CreateRuneProvider()
    return {
        GetMax = function() return RUNE_COUNT end,
        Update = function(_, progress, circles, now)
            now = now or GetTime()
            for index = 1, RUNE_COUNT do
                local start, duration, ready = GetRuneCooldown(index)
                local circle = circles[index]
                if ready then
                    progress[index] = 1
                    SetCircle(circle, 1, 1, 1, true)
                elseif start and duration and duration > 0 then
                    local value = math_max(0, math_min(1, (now - start) / duration))
                    progress[index] = value
                    SetCircle(circle, value, duration, now - start, false)
                else
                    progress[index] = 0
                    SetCircle(circle, 0, 1, 0, false)
                end
            end
            return RUNE_COUNT
        end,
    }
end

function addon.CreateSpecialResourceProvider(playerClass, powerTypes)
    if playerClass == "DEATHKNIGHT" then
        return CreateRuneProvider(), nil
    end
    if not powerTypes then return nil, nil end

    local definitions = {
        PALADIN = { powerTypes.HolyPower, "HOLY_POWER" },
        EVOKER = { powerTypes.Essence, "ESSENCE", true },
        WARLOCK = { powerTypes.SoulShards, "SOUL_SHARDS" },
        MONK = { powerTypes.Chi, "CHI" },
        ROGUE = { powerTypes.ComboPoints, "COMBO_POINTS" },
        DRUID = { powerTypes.ComboPoints, "COMBO_POINTS" },
    }
    local definition = definitions[playerClass]
    if not definition or not definition[1] then return nil, nil end
    if definition[3] then
        return CreateEssenceProvider(definition[1]), definition[2]
    end
    return CreatePowerProvider(definition[1]), definition[2]
end
