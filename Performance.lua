-- Shared graphics throttle for non-realtime addon visuals.
-- Mouse cursor positioning/glow animation intentionally do NOT use this setting.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local DEFAULT_RATE = 30
local ALLOWED_RATES = { [30] = true, [60] = true }
local rate = DEFAULT_RATE

local function NormalizeRate(value)
    value = tonumber(value)
    if ALLOWED_RATES[value] then return value end
    return DEFAULT_RATE
end

function addon.GetGraphicsUpdateRate()
    return rate
end

function addon.GetGraphicsUpdateInterval()
    return 1 / rate
end

function addon.SetGraphicsUpdateRate(value)
    rate = NormalizeRate(value)
    return rate
end

function addon.InitializeGraphicsSettings(config)
    rate = NormalizeRate(config and config.graphicsUpdateRate)
    if config then config.graphicsUpdateRate = rate end
    return rate
end
