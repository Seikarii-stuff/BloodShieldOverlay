-- Profile storage and defaults for the standalone player bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local MIN_CAP_PERCENT = 20
local DEFAULTS = {
    configVersion = 5, point = "BOTTOM", relativePoint = "BOTTOM", xOffset = 100, yOffset = 450,
    width = 18, height = 150, locked = true, hideExternalBar = false, capMultiplier = 2.0,
    showHealth = true, showSpecialResources = true, showClassResourceOverlay = true,
    classResourcePipWidth = 12, classResourcePipHeight = 6,
    specialResourcePipWidth = 2, specialResourcePipHeight = 10,
    resourceDisplay = "left",
    showTargetTarget = false,
    targetTargetWidth = 130, targetTargetHeight = 10, targetTargetLocked = true,
    targetTargetPoint = "CENTER", targetTargetRelativePoint = "CENTER",
    targetTargetXOffset = 0, targetTargetYOffset = -140,
    showMouseSpecialResources = false,
    showMouseCooldown1 = false,
    showMouseCooldown2 = false,
    mouseCooldown1Spell = nil,
    mouseCooldown2Spell = nil,
}
local RESOURCE_DISPLAY_MODES = { left = true, right = true, none = true }
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
local function IsOptionalSpellID(value) return value == nil or (type(value) == "number" and value > 0) end

local FIELD_VALIDATORS = {
    width = IsPositiveNumber,
    height = IsPositiveNumber,
    capMultiplier = function(value) return type(value) == "number" and value >= MIN_CAP_PERCENT / 100 end,
    hideExternalBar = IsBoolean,
    showHealth = IsBoolean,
    showSpecialResources = IsBoolean,
    showClassResourceOverlay = IsBoolean,
    classResourcePipWidth = function(value) return type(value) == "number" and value >= 4 and value <= 32 end,
    classResourcePipHeight = function(value) return type(value) == "number" and value >= 2 and value <= 20 end,
    specialResourcePipWidth = function(value) return type(value) == "number" and value >= 2 and value <= 20 end,
    specialResourcePipHeight = function(value) return type(value) == "number" and value >= 2 and value <= 32 end,
    resourceDisplay = function(value) return type(value) == "string" and RESOURCE_DISPLAY_MODES[value] == true end,
    showTargetTarget = IsBoolean,
    targetTargetWidth = IsPositiveNumber,
    targetTargetHeight = IsPositiveNumber,
    targetTargetLocked = IsBoolean,
    targetTargetPoint = IsPoint,
    targetTargetRelativePoint = IsPoint,
    targetTargetXOffset = function(value) return type(value) == "number" end,
    targetTargetYOffset = function(value) return type(value) == "number" end,
    showMouseSpecialResources = IsBoolean,
    showMouseCooldown1 = IsBoolean,
    showMouseCooldown2 = IsBoolean,
    mouseCooldown1Spell = IsOptionalSpellID,
    mouseCooldown2Spell = IsOptionalSpellID,
}

local function ApplyDefaults(db)
    db = db or {}
    local isLegacyProfile = db.configVersion == nil and db.showHealth == false
    for key, value in pairs(DEFAULTS) do if db[key] == nil then db[key] = value end end
    if isLegacyProfile then db.showHealth = true end

    for key, validator in pairs(FIELD_VALIDATORS) do
        if not validator(db[key]) then db[key] = DEFAULTS[key] end
    end

    return db
end

local function CopySettings(source)
    local copy = {}
    if type(source) == "table" then for key, value in pairs(source) do copy[key] = value end end
    return copy
end

local function Initialize()
    local profiles = EnsureProfileStore()
    local key = GetProfileKey()
    if not profiles[key] then
        if type(BloodShieldOverlayDB) == "table" and next(BloodShieldOverlayDB) ~= nil then
            profiles[key] = CopySettings(BloodShieldOverlayDB)
        else
            profiles[key] = {}
        end
    end
    config = ApplyDefaults(profiles[key])
    profiles[key] = config
    BloodShieldOverlayProfiles = profiles
    return config
end

local function Reset()
    local profiles = EnsureProfileStore()
    local reset = {}
    for key, value in pairs(DEFAULTS) do reset[key] = value end
    config = reset
    profiles[GetProfileKey()] = config
    BloodShieldOverlayProfiles = profiles
    return config
end

addon.PlayerBarConfig = {
    Initialize = Initialize,
    Reset = Reset,
    GetDefaults = function() return DEFAULTS end,
    GetMinCapPercent = function() return MIN_CAP_PERCENT end,
}