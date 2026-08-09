-- Profile storage and defaults for the standalone player bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local MIN_CAP_PERCENT = 20
local DEFAULTS = {
    configVersion = 2, point = "BOTTOM", relativePoint = "BOTTOM", xOffset = 100, yOffset = 450,
    width = 18, height = 150, locked = true, hideExternalBar = false, capMultiplier = 2.0,
    showHealth = true, showSpecialResources = true, showClassResourceOverlay = true,
    resourceDisplay = "left",
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

local function ApplyDefaults(db)
    db = db or {}
    local isLegacyProfile = db.configVersion == nil and db.showHealth == false
    for key, value in pairs(DEFAULTS) do if db[key] == nil then db[key] = value end end
    if isLegacyProfile then db.showHealth = true end
    if type(db.width) ~= "number" or db.width <= 0 then db.width = DEFAULTS.width end
    if type(db.height) ~= "number" or db.height <= 0 then db.height = DEFAULTS.height end
    if type(db.capMultiplier) ~= "number" or db.capMultiplier < MIN_CAP_PERCENT / 100 then db.capMultiplier = DEFAULTS.capMultiplier end
    if type(db.hideExternalBar) ~= "boolean" then db.hideExternalBar = DEFAULTS.hideExternalBar end
    if type(db.showHealth) ~= "boolean" then db.showHealth = DEFAULTS.showHealth end
    if type(db.showSpecialResources) ~= "boolean" then db.showSpecialResources = DEFAULTS.showSpecialResources end
    if type(db.showClassResourceOverlay) ~= "boolean" then db.showClassResourceOverlay = DEFAULTS.showClassResourceOverlay end
    if type(db.resourceDisplay) ~= "string" or not RESOURCE_DISPLAY_MODES[db.resourceDisplay] then db.resourceDisplay = DEFAULTS.resourceDisplay end
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