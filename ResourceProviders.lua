-- Providers for class-specific special resources shown beside the player bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CHARGING_COLOR = { 1, 1, 1 }
local READY_COLOR = { 1, 0.82, 0 }

local function CreatePowerResourceProvider(powerType, powerToken, circles, progress, maxCircles)
    return {
        token = powerToken,
        GetMax = function() return UnitPowerMax("player", powerType) or 0 end,
        Update = function()
            local currentPower = UnitPower("player", powerType) or 0
            local maxPower = math.min(UnitPowerMax("player", powerType) or 0, maxCircles)
            for index = 1, maxPower do
                local circle = circles[index]
                circle:SetMinMaxValues(0, 1)
                if index <= currentPower then
                    progress[index] = 1
                    circle:SetValue(1)
                    circle:SetStatusBarColor(READY_COLOR[1], READY_COLOR[2], READY_COLOR[3], 1)
                else
                    circle:SetValue(0)
                    circle:SetStatusBarColor(CHARGING_COLOR[1], CHARGING_COLOR[2], CHARGING_COLOR[3], 1)
                end
            end
            return maxPower
        end,
    }
end

function addon.CreateResourceProviders(playerClass, powerTypes, circles, progress, maxCircles)
    local providers = {
        DEATHKNIGHT = {
            GetMax = function() return 6 end,
            Update = function()
                local now = GetTime()
                for index = 1, 6 do
                    local start, duration, ready = GetRuneCooldown(index)
                    local circle = circles[index]
                    circle:SetMinMaxValues(0, 1)
                    if ready then
                        progress[index] = 1
                        circle:SetValue(1)
                        circle:SetStatusBarColor(READY_COLOR[1], READY_COLOR[2], READY_COLOR[3], 1)
                    elseif start and duration and duration > 0 then
                        local value = (now - start) / duration
                        if value < 0 then value = 0 end
                        if value > 1 then value = 1 end
                        progress[index] = value
                        circle:SetMinMaxValues(0, duration)
                        circle:SetValue(now - start)
                        circle:SetStatusBarColor(CHARGING_COLOR[1], CHARGING_COLOR[2], CHARGING_COLOR[3], 1)
                    else
                        circle:SetValue(0)
                        circle:SetStatusBarColor(CHARGING_COLOR[1], CHARGING_COLOR[2], CHARGING_COLOR[3], 1)
                    end
                end
                return 6
            end,
        },
    }
    if powerTypes then
        providers.PALADIN = CreatePowerResourceProvider(powerTypes.HolyPower, "HOLY_POWER", circles, progress, maxCircles)
        providers.EVOKER = CreatePowerResourceProvider(powerTypes.Essence, "ESSENCE", circles, progress, maxCircles)
        providers.WARLOCK = CreatePowerResourceProvider(powerTypes.SoulShards, "SOUL_SHARDS", circles, progress, maxCircles)
        providers.MONK = CreatePowerResourceProvider(powerTypes.Chi, "CHI", circles, progress, maxCircles)
        providers.ROGUE = CreatePowerResourceProvider(powerTypes.ComboPoints, "COMBO_POINTS", circles, progress, maxCircles)
        providers.DRUID = CreatePowerResourceProvider(powerTypes.ComboPoints, "COMBO_POINTS", circles, progress, maxCircles)
    end
    return providers[playerClass]
end