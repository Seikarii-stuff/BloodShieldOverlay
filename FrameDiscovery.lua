-- Shared Blizzard-frame discovery helpers.
-- BlizzardFrames.lua (absorb overlays) and ClassResourceOverlay.lua (group
-- resource pips) both consume Blizzard's real compact-frame pools. Discovery
-- never creates replacement party/raid frames, and solo party discovery is
-- kept compatible with ShowPartyWhenSolo.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local type = type
local select = select
local _G = _G
local IsInRaid = _G.IsInRaid
local IsInGroup = _G.IsInGroup

-- ---------------------------------------------------------------------
-- Basic frame predicates
-- ---------------------------------------------------------------------

function addon.IsForbiddenFrame(frame)
    if not frame then return true end
    if frame.IsForbidden and frame:IsForbidden() then
        return true
    end
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

-- Resolves the unit displayed by a (possibly secure) Blizzard frame.
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
        if type(unit) == "string" and unit ~= "" then
            return unit
        end
    end

    return nil
end

-- Blizzard owns the raid compact-frame pool. ApplyToFrames("normal") gives us
-- the frames Blizzard currently considers active, so raid discovery does not
-- scan fixed global names or guess which frames exist.
local function ForEachBlizzardRaidFrame(callback)
    local container = _G.CompactRaidFrameContainer
    if not container or type(container.ApplyToFrames) ~= "function" then
        return false
    end

    container:ApplyToFrames("normal", callback)
    return true
end

addon.ForEachBlizzardRaidFrame = ForEachBlizzardRaidFrame

-- Blizzard's actual compact party member frames. We also expose the legacy
-- party frames because ShowPartyWhenSolo can configure PartyMemberFrame1.
local function ForEachBlizzardPartyFrame(callback)
    for index = 1, 4 do
        local frame = _G["CompactPartyFrameMemberFrame" .. index]
        if frame then callback(frame) end

        frame = _G["PartyMemberFrame" .. index]
        if frame then callback(frame) end
    end
    return true
end

addon.ForEachBlizzardPartyFrame = ForEachBlizzardPartyFrame

function addon.ForEachCompactFrame(callback)
    local raid = IsInRaid and IsInRaid() or false
    if raid then
        return ForEachBlizzardRaidFrame(callback)
    end

    local inParty = IsInGroup and IsInGroup() or false
    if inParty then
        return ForEachBlizzardPartyFrame(callback)
    end

    -- SOLO: ShowPartyWhenSolo owns visibility/unit assignment. Discovery only
    -- consumes those real Blizzard party frames; it never makes them visible
    -- or changes their unit here.
    if addon.RefreshPartyFrames then
        return ForEachBlizzardPartyFrame(callback)
    end

    return false
end

-- ---------------------------------------------------------------------
-- Player-frame lookup shared with ClassResourceOverlay.
-- ---------------------------------------------------------------------

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

    local nextDepth = (depth or 0) + 1
    return FindPlayerFrameChildren(nextDepth, frame:GetChildren())
end

addon.FindPlayerFrame = FindPlayerFrame
