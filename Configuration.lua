-- Profile storage and defaults for the standalone player bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local DEFAULTS = {
    configVersion = 8,
    point = "BOTTOM",
    relativePoint = "BOTTOM",
    xOffset = 100,
    yOffset = 450,
    width = 18,
    height = 150,
    locked = true,
    hideExternalBar = false,
    showClassResourceOverlay = true,
    classResourcePipWidth = 12,
    classResourcePipHeight = 6,
    specialResourcePipWidth = 2,
    specialResourcePipHeight = 10,
    showTargetTarget = false,
    targetTargetWidth = 130,
    targetTargetHeight = 10,
    targetTargetLocked = true,
    targetTargetPoint = "CENTER",
    targetTargetRelativePoint = "CENTER",
    targetTargetXOffset = 0,
    targetTargetYOffset = -140,
    graphicsUpdateRate = 30,
}

local profileKey
local config = {}
local subscribers = {}
local subscriptionCounter = 0

local function CopySettings(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            copy[key] = value
        end
    end
    return copy
end

local function BuildProfileKey()
    local playerName = UnitName("player") or "Player"
    local realmName = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName and GetRealmName() or "Unknown"
    return string.format("%s-%s", playerName, realmName)
end

local function GetProfileKey()
    if not profileKey then
        profileKey = BuildProfileKey()
    end
    return profileKey
end

local function EnsureProfileStore()
    if type(BloodShieldOverlayProfiles) ~= "table" then
        BloodShieldOverlayProfiles = {}
    end
    return BloodShieldOverlayProfiles
end

local function IsPositiveNumber(value)
    return type(value) == "number" and value > 0
end

local function IsBoolean(value)
    return type(value) == "boolean"
end

local function IsPoint(value)
    return type(value) == "string" and value ~= ""
end

local FIELD_VALIDATORS = {
    configVersion = function(value) return value == DEFAULTS.configVersion end,
    point = IsPoint,
    relativePoint = IsPoint,
    xOffset = function(value) return type(value) == "number" end,
    yOffset = function(value) return type(value) == "number" end,
    width = IsPositiveNumber,
    height = IsPositiveNumber,
    locked = IsBoolean,
    hideExternalBar = IsBoolean,
    showClassResourceOverlay = IsBoolean,
    classResourcePipWidth = function(value) return type(value) == "number" and value >= 4 and value <= 32 end,
    classResourcePipHeight = function(value) return type(value) == "number" and value >= 2 and value <= 20 end,
    specialResourcePipWidth = function(value) return type(value) == "number" and value >= 2 and value <= 20 end,
    specialResourcePipHeight = function(value) return type(value) == "number" and value >= 2 and value <= 32 end,
    showTargetTarget = IsBoolean,
    targetTargetWidth = IsPositiveNumber,
    targetTargetHeight = IsPositiveNumber,
    targetTargetLocked = IsBoolean,
    targetTargetPoint = IsPoint,
    targetTargetRelativePoint = IsPoint,
    targetTargetXOffset = function(value) return type(value) == "number" end,
    targetTargetYOffset = function(value) return type(value) == "number" end,
    graphicsUpdateRate = function(value) return value == 30 or value == 60 end,
}

local function ApplyDefaults(db)
    db = db or {}
    local clean = {}
    for key, defaultValue in pairs(DEFAULTS) do
        local value = db[key]
        if key == "configVersion" then
            value = DEFAULTS.configVersion
        elseif value == nil or (FIELD_VALIDATORS[key] and not FIELD_VALIDATORS[key](value)) then
            value = defaultValue
        end
        clean[key] = value
    end
    return clean
end

local function Persist()
    local profiles = EnsureProfileStore()
    profiles[GetProfileKey()] = config
    BloodShieldOverlayProfiles = profiles
    return profiles[GetProfileKey()]
end

local function EmitChange(key, oldValue, newValue)
    if not key then return end
    for index = #subscribers, 1, -1 do
        local subscriber = subscribers[index]
        if not subscriber then
            table.remove(subscribers, index)
        else
            local ok, errorMessage = pcall(subscriber.callback, {
                key = key,
                oldValue = oldValue,
                newValue = newValue,
                config = config,
            })
            if not ok then
                print("BloodShieldOverlay: config subscriber error: " .. tostring(errorMessage))
            end
        end
    end
end

local function Initialize()
    local profiles = EnsureProfileStore()
    local key = GetProfileKey()

    if not profiles[key] then
        profiles[key] = ApplyDefaults({})
    end

    config = ApplyDefaults(profiles[key])
    profiles[key] = config
    BloodShieldOverlayProfiles = profiles

    if addon.InitializeGraphicsSettings then
        addon.InitializeGraphicsSettings(config)
    end
    return config
end

local function Reset()
    local previous = CopySettings(config)
    config = CopySettings(DEFAULTS)
    Persist()

    for key, defaultValue in pairs(DEFAULTS) do
        if previous[key] ~= defaultValue then
            EmitChange(key, previous[key], defaultValue)
        end
    end

    if addon.InitializeGraphicsSettings then
        addon.InitializeGraphicsSettings(config)
    end
    return config
end

local PlayerBarConfig = {}

PlayerBarConfig.GetDefaults = function()
    return CopySettings(DEFAULTS)
end

PlayerBarConfig.Get = function()
    return config
end

PlayerBarConfig.Set = function(key, value)
    if type(key) ~= "string" then return false end
    if not FIELD_VALIDATORS[key] then return false end
    if not FIELD_VALIDATORS[key](value) then return false end

    if config[key] == value then
        return true
    end

    local previous = config[key]
    config[key] = value
    Persist()
    EmitChange(key, previous, value)

    if key == "graphicsUpdateRate" and type(addon.SetGraphicsUpdateRate) == "function" then
        addon.SetGraphicsUpdateRate(value)
    end
    return true
end

PlayerBarConfig.SetMany = function(values)
    if type(values) ~= "table" then return false end

    local nextState = CopySettings(config)
    local pending = {}
    for key, value in pairs(values) do
        if not FIELD_VALIDATORS[key] then
            return false
        end
        if not FIELD_VALIDATORS[key](value) then
            return false
        end
        if nextState[key] ~= value then
            nextState[key] = value
            pending[#pending + 1] = { key = key, oldValue = config[key], newValue = value }
        end
    end

    if #pending == 0 then
        return true
    end

    config = nextState
    Persist()
    for _, change in ipairs(pending) do
        EmitChange(change.key, change.oldValue, change.newValue)
    end

    if values.graphicsUpdateRate and type(addon.SetGraphicsUpdateRate) == "function" then
        addon.SetGraphicsUpdateRate(values.graphicsUpdateRate)
    end
    return true
end

PlayerBarConfig.Reset = Reset
PlayerBarConfig.Initialize = Initialize

PlayerBarConfig.Subscribe = function(callback)
    if type(callback) ~= "function" then return nil end
    for _, subscriber in ipairs(subscribers) do
        if subscriber and subscriber.callback == callback then
            return subscriber.token
        end
    end

    subscriptionCounter = subscriptionCounter + 1
    local token = string.format("sub-%d", subscriptionCounter)
    subscribers[#subscribers + 1] = { token = token, callback = callback }
    return token
end

PlayerBarConfig.Unsubscribe = function(token)
    if type(token) ~= "string" then return false end
    local removed = false
    for index = #subscribers, 1, -1 do
        local subscriber = subscribers[index]
        if subscriber and subscriber.token == token then
            table.remove(subscribers, index)
            removed = true
        end
    end
    return removed
end

addon.PlayerBarConfig = PlayerBarConfig

addon.RegisterInitializer(function()
    PlayerBarConfig.Initialize()
end)
