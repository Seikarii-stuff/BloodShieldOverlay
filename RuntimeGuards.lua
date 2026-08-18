-- Runtime guards for user-facing configuration writes that can cross protected UI boundaries.
-- Keeps validation at the public API boundary and defers secure TargetTarget changes out of combat.

local addon = _G.BloodShieldOverlay
if not addon then return end

local MIN_MOUSE_COOLDOWN_SIZE = 4
local MAX_MOUSE_COOLDOWN_SIZE = 24

local function ClampMouseCooldownPipSize(value)
    value = tonumber(value)
    if not value then return nil end
    if value < MIN_MOUSE_COOLDOWN_SIZE then return MIN_MOUSE_COOLDOWN_SIZE end
    if value > MAX_MOUSE_COOLDOWN_SIZE then return MAX_MOUSE_COOLDOWN_SIZE end
    return value
end

local function GetConfig()
    return addon.PlayerBarConfig and addon.PlayerBarConfig.Initialize and addon.PlayerBarConfig.Initialize()
end

function addon.SetMouseCooldownPipSize(value)
    local size = ClampMouseCooldownPipSize(value)
    if not size then return false end

    local config = GetConfig()
    if not config then return false end
    config.mouseCooldownPipSize = size
    return true
end

local originalRefreshMouseCooldowns = addon.RefreshMouseCooldowns
if type(originalRefreshMouseCooldowns) == "function" then
    addon.RefreshMouseCooldowns = function(...)
        local config = GetConfig()
        if config then
            local size = ClampMouseCooldownPipSize(config.mouseCooldownPipSize)
            if size then config.mouseCooldownPipSize = size end
        end
        return originalRefreshMouseCooldowns(...)
    end
end

local function IsPositiveNumber(value)
    return type(value) == "number" and value > 0
end

local function CombatMessage()
    print("BloodShieldOverlay: no se puede modificar el target of target en combate; se aplicará al salir de combate.")
end

local function WrapTargetTargetAPI()
    local api = addon.TargetTargetBarAPI
    if not api or api.__runtimeGuardsWrapped then return true end

    local originalEnable = api.Enable
    local originalApplySize = api.ApplySize
    local originalSetLocked = api.SetLocked
    if type(originalEnable) ~= "function" or type(originalApplySize) ~= "function" or type(originalSetLocked) ~= "function" then
        return false
    end

    api.Enable = function(show)
        local result = originalEnable(show)
        if result == false and InCombatLockdown() then CombatMessage() end
        return result
    end

    local pendingWidth
    local pendingHeight
    api.ApplySize = function(width, height)
        if not IsPositiveNumber(width) or not IsPositiveNumber(height) then return false end
        if InCombatLockdown() then
            pendingWidth, pendingHeight = width, height
            CombatMessage()
            return false
        end

        pendingWidth, pendingHeight = nil, nil
        return originalApplySize(width, height)
    end

    api.SetLocked = function(locked)
        local result = originalSetLocked(locked)
        if result == false and InCombatLockdown() then CombatMessage() end
        return result
    end

    api.__runtimeGuardsWrapped = true

    if type(addon.RegisterRegenListener) == "function" then
        addon.RegisterRegenListener(function()
            if pendingWidth and pendingHeight then
                local width, height = pendingWidth, pendingHeight
                pendingWidth, pendingHeight = nil, nil
                originalApplySize(width, height)
            end
        end)
    end

    return true
end

addon.RegisterInitializer(function()
    WrapTargetTargetAPI()
end)

WrapTargetTargetAPI()
