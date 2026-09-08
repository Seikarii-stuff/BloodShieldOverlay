-- Profile storage and defaults for the standalone player bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local DEFAULTS = {
    configVersion = 8, point = "BOTTOM", relativePoint = "BOTTOM", xOffset = 100, yOffset = 450,
    width = 18, height = 150, locked = true, hideExternalBar = false,
    showClassResourceOverlay = true,
    classResourcePipWidth = 12, classResourcePipHeight = 6,
    specialResourcePipWidth = 2, specialResourcePipHeight = 10,
    showTargetTarget = false,
    targetTargetWidth = 130, targetTargetHeight = 10, targetTargetLocked = true,
    targetTargetPoint = "CENTER", targetTargetRelativePoint = "CENTER",
    targetTargetXOffset = 0, targetTargetYOffset = -140,
    graphicsUpdateRate = 30,
}
local profileKey
local config = {}

local function BuildProfileKey()
    local playerName = UnitName("player") or "Player"
    local realmName = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName and GetRealmName() or "Unknown"
    return string.format("%s-%s", playerName, realmName)
end

local function GetProfileKey()
    if not profileKey then profileKey = BuildProfileKey() end
    return profileKey
end

local function EnsureProfileStore()
    if type(BloodShieldOverlayProfiles) ~= "table" then BloodShieldOverlayProfiles = {} end
    return BloodShieldOverlayProfiles
end

local function IsPositiveNumber(value) return type(value) == "number" and value > 0 end
local function IsBoolean(value) return type(value) == "boolean" end
local function IsPoint(value) return type(value) == "string" and value ~= "" end

local FIELD_VALIDATORS = {
    width = IsPositiveNumber,
    height = IsPositiveNumber,
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

-- Rebuild the persisted profile from the current schema. This is deliberately
-- a whitelist rather than a patch-in-place migration: fields removed from the
-- configuration model (including old hardcoded options) must disappear from
-- SavedVariables instead of being loaded and overwritten at runtime.
local function ApplyDefaults(db)
    db = db or {}
    local clean = {}
    for key, defaultValue in pairs(DEFAULTS) do
        local value = db[key]
        local validator = FIELD_VALIDATORS[key]
        if key == "configVersion" then
            value = DEFAULTS.configVersion
        elseif value == nil or (validator and not validator(value)) then
            value = defaultValue
        end
        clean[key] = value
    end
    return clean
end

local function CopySettings(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do copy[key] = value end
    end
    return copy
end

local function Initialize()
    local profiles = EnsureProfileStore()
    local key = GetProfileKey()
    if not profiles[key] then
        if type(BloodShieldOverlayDB) == "table" and next(BloodShieldOverlayDB) ~= nil then
            profiles[key] = CopySettings(BloodShieldOverlayDB)
            -- BloodShieldOverlayDB is the pre-profile-format SavedVariable.
            -- Once copied into the per-character profile store, remove the
            -- legacy table so dead settings are not serialized forever.
            BloodShieldOverlayDB = nil
        else
            profiles[key] = {}
        end
    end
    config = ApplyDefaults(profiles[key])
    profiles[key] = config
    BloodShieldOverlayProfiles = profiles
    if addon.InitializeGraphicsSettings then addon.InitializeGraphicsSettings(config) end
    return config
end

local function Reset()
    local profiles = EnsureProfileStore()
    local reset = {}
    for key, value in pairs(DEFAULTS) do reset[key] = value end
    config = reset
    profiles[GetProfileKey()] = config
    BloodShieldOverlayProfiles = profiles
    if addon.InitializeGraphicsSettings then addon.InitializeGraphicsSettings(config) end
    return config
end

addon.PlayerBarConfig = {
    Initialize = Initialize,
    Get = function() return config end,
    Reset = Reset,
    GetDefaults = function() return DEFAULTS end,
}
