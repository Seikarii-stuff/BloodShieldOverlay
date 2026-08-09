-- Shared Blizzard-frame discovery helpers.
-- BlizzardFrames.lua (absorb overlays) and ClassResourceOverlay.lua (group
-- resource pips) both need to identify unit frames, status bars and compact
-- group frames. Centralizing that logic here avoids running two near-
-- identical tree walks per roster/layout event and keeps the two discovery
-- consumers from drifting apart.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local type = type
local select = select
local _G = _G

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
    if IsForbiddenFrame(frame) or not frame.GetName then
        return ""
    end
    local name = frame:GetName()
    if type(name) == "string" then
        return name
    end
    return ""
end

-- Resolves the unit displayed by a (possibly secure) frame. Shared by the
-- absorb-overlay discovery pass and the class-resource pip discovery pass.
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

-- ---------------------------------------------------------------------
-- Compact/raid frame name caches, split by category so callers can bound
-- their scan to the frames that can plausibly exist for the current group
-- state instead of always walking all ~200 fixed names.
-- ---------------------------------------------------------------------

local RAID_FRAME_COUNT = 40
local PARTY_FRAME_COUNT = 4
local RAID_GROUP_COUNT = 8
local RAID_GROUP_SLOTS = 5
local RAID_GROUP_SLOT_COUNT = RAID_GROUP_COUNT * RAID_GROUP_SLOTS

local RAID_FRAME_NAMES = {}
local PARTY_MEMBER_FRAME_NAMES = {}
local LEGACY_PARTY_FRAME_NAMES = {}
local COMPACT_PARTY_FRAME_NAMES = {}
local RAID_GROUP_SLOT_NAMES = {}

for index = 1, RAID_FRAME_COUNT do
    RAID_FRAME_NAMES[index] = "CompactRaidFrame" .. index
end
for index = 1, PARTY_FRAME_COUNT do
    PARTY_MEMBER_FRAME_NAMES[index] = "CompactPartyFrameMemberFrame" .. index
    LEGACY_PARTY_FRAME_NAMES[index] = "PartyMemberFrame" .. index
    COMPACT_PARTY_FRAME_NAMES[index] = "CompactPartyFrame" .. index
end
do
    local slotIndex = 0
    for group = 1, RAID_GROUP_COUNT do
        for slot = 1, RAID_GROUP_SLOTS do
            slotIndex = slotIndex + 1
            RAID_GROUP_SLOT_NAMES[slotIndex] = "CompactRaidGroup" .. group .. "Slot" .. slot
        end
    end
end

addon.RAID_FRAME_NAMES = RAID_FRAME_NAMES
addon.PARTY_MEMBER_FRAME_NAMES = PARTY_MEMBER_FRAME_NAMES
addon.LEGACY_PARTY_FRAME_NAMES = LEGACY_PARTY_FRAME_NAMES
addon.COMPACT_PARTY_FRAME_NAMES = COMPACT_PARTY_FRAME_NAMES
addon.RAID_GROUP_SLOT_NAMES = RAID_GROUP_SLOT_NAMES

local IsInRaid = _G.IsInRaid
local IsInGroup = _G.IsInGroup
local GetNumGroupMembers = _G.GetNumGroupMembers

-- Invokes callback(frame) for every compact/raid frame that can plausibly
-- exist given the current group state, instead of unconditionally resolving
-- all ~200 fixed global names on every discovery pass. Solo play does zero
-- lookups; a 5-player party does ~12; a raid is bounded by its actual roster
-- size rather than the hard-coded maximum of 40.
function addon.ForEachCompactFrame(callback)
    local inRaid = IsInRaid and IsInRaid()
    local inGroup = inRaid or (IsInGroup and IsInGroup())

    if not inGroup then return end

    if inRaid then
        local memberCount = (GetNumGroupMembers and GetNumGroupMembers()) or RAID_FRAME_COUNT
        if type(memberCount) ~= "number" or memberCount <= 0 or memberCount > RAID_FRAME_COUNT then
            memberCount = RAID_FRAME_COUNT
        end

        for index = 1, memberCount do
            local frame = _G[RAID_FRAME_NAMES[index]]
            if frame then callback(frame) end
        end

        local slotCount = memberCount
        if slotCount > RAID_GROUP_SLOT_COUNT then slotCount = RAID_GROUP_SLOT_COUNT end
        for index = 1, slotCount do
            local frame = _G[RAID_GROUP_SLOT_NAMES[index]]
            if frame then callback(frame) end
        end
        return
    end

    for index = 1, PARTY_FRAME_COUNT do
        local frame = _G[PARTY_MEMBER_FRAME_NAMES[index]]
        if frame then callback(frame) end

        frame = _G[LEGACY_PARTY_FRAME_NAMES[index]]
        if frame then callback(frame) end

        frame = _G[COMPACT_PARTY_FRAME_NAMES[index]]
        if frame then callback(frame) end
    end
end

-- Depth-limited recursive search for the frame that displays "player" inside
-- a container (CompactPartyFrame, CompactRaidFrameContainer, PartyFrame...).
-- Shared by ClassResourceOverlay's resource-bar lookup.
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
