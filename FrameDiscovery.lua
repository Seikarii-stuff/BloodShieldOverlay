-- Shared Blizzard-frame discovery helpers.
-- Blizzard owns the compact-frame lifecycle; this module only consumes the
-- frames Blizzard exposes and never searches third-party raid-frame trees.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local type = type
local select = select
local _G = _G
local IsInRaid = _G.IsInRaid
local IsInGroup = _G.IsInGroup

function addon.IsForbiddenFrame(frame)
    if not frame then return true end
    if frame.IsForbidden and frame:IsForbidden() then return true end
    return false
end

local IsForbiddenFrame = addon.IsForbiddenFrame

function addon.IsStatusBar(frame)
    if IsForbiddenFrame(frame) then return false end
    return frame.GetObjectType and frame:GetObjectType() == "StatusBar"
end

function addon.GetFrameName(frame)
    if IsForbiddenFrame(frame) or not frame.GetName then return "" end
    local name = frame:GetName()
    return type(name) == "string" and name or ""
end

function addon.GetUnit(frame)
    if IsForbiddenFrame(frame) then return nil end
    if type(frame.displayedUnit) == "string" and frame.displayedUnit ~= "" then
        return frame.displayedUnit
    end
    if type(frame.unit) == "string" and frame.unit ~= "" then
        return frame.unit
    end
    if frame.GetAttribute then
        local unit = frame:GetAttribute("unit")
        if type(unit) == "string" and unit ~= "" then return unit end
    end
    return nil
end

-- Blizzard's raid container is the authoritative source for active raid
-- compact frames. Do not fall back to named-frame probing or child walks:
-- BloodShieldOverlay intentionally supports Blizzard's default compact frames,
-- not third-party raid-frame replacements.
local function ForEachBlizzardRaidFrame(callback)
    local container = _G.CompactRaidFrameContainer
    if not container or type(container.ApplyToFrames) ~= "function" then
        return false
    end
    container:ApplyToFrames("normal", callback)
    return true
end

addon.ForEachBlizzardRaidFrame = ForEachBlizzardRaidFrame

-- CompactPartyFrameMember1..5 are Blizzard's five party slots. Their `unit`
-- field is authoritative and is deliberately used instead of assuming that
-- Member1 means player: in raid/AlwaysInParty Blizzard can reuse these frames
-- for raid units (e.g. raid3, raid2, raid4...).
local function ForEachBlizzardPartyFrame(callback)
    local container = _G.CompactPartyFrame
    if not container or not container.GetChildren then
        return false
    end

    local frames = {
        _G.CompactPartyFrameMember1,
        _G.CompactPartyFrameMember2,
        _G.CompactPartyFrameMember3,
        _G.CompactPartyFrameMember4,
        _G.CompactPartyFrameMember5,
    }

    for index = 1, 5 do
        local frame = frames[index]
        if frame then callback(frame) end
    end
    return true
end

addon.ForEachBlizzardPartyFrame = ForEachBlizzardPartyFrame

function addon.ForEachCompactFrame(callback)
    local inRaid = IsInRaid and IsInRaid()
    local inGroup = inRaid or (IsInGroup and IsInGroup())

    if inRaid then
        -- Raid discovery is exclusively Blizzard's authoritative frame pool.
        return ForEachBlizzardRaidFrame(callback)
    end

    if inGroup or container then
        return ForEachBlizzardPartyFrame(callback)
    end

    -- AlwaysInParty / solo: CompactPartyFrame can still expose the player
    -- even when IsInGroup() is false. Never search arbitrary frame trees; if
    -- Blizzard's compact party frames exist, consume those five slots.
    return ForEachBlizzardPartyFrame(callback)
end

local UnitIsUnit = _G.UnitIsUnit
local function IsPlayerUnit(frame)
    local unit = addon.GetUnit(frame)
    if not unit then return false end
    if unit == "player" then return true end
    return UnitIsUnit and UnitIsUnit(unit, "player") or false
end
addon.IsPlayerUnit = IsPlayerUnit

local FindPlayerFrame
local function FindPlayerFrameChildren(depth, ...)
    local childCount = select("#", ...)
    for index = 1, childCount do
        local found = FindPlayerFrame(select(index, ...), depth)
        if found then return found end
    end
    return nil
end

FindPlayerFrame = function(frame, depth)
    if IsForbiddenFrame(frame) then return nil end
    if IsPlayerUnit(frame) then return frame end
    if not frame.GetChildren or (depth or 0) >= 2 then return nil end
    return FindPlayerFrameChildren((depth or 0) + 1, frame:GetChildren())
end

addon.FindPlayerFrame = FindPlayerFrame
