-- Shared Blizzard-frame discovery helpers.
-- Prefer Blizzard's authoritative CompactRaidFrameContainer frame pool in raid.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local type = type
local select = select
local _G = _G

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
local slotIndex = 0
for group = 1, RAID_GROUP_COUNT do
    for slot = 1, RAID_GROUP_SLOTS do
        slotIndex = slotIndex + 1
        RAID_GROUP_SLOT_NAMES[slotIndex] = "CompactRaidGroup" .. group .. "Slot" .. slot
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

local function ForEachBlizzardRaidFrame(callback)
    local container = _G.CompactRaidFrameContainer
    if not container or type(container.ApplyToFrames) ~= "function" then
        return false
    end
    container:ApplyToFrames("normal", callback)
    return true
end

addon.ForEachBlizzardRaidFrame = ForEachBlizzardRaidFrame

function addon.ForEachCompactFrame(callback)
    local inRaid = IsInRaid and IsInRaid()
    local inGroup = inRaid or (IsInGroup and IsInGroup())
    if not inGroup then return end

    if inRaid then
        if ForEachBlizzardRaidFrame(callback) then return end

        local memberCount = (GetNumGroupMembers and GetNumGroupMembers()) or RAID_FRAME_COUNT
        if type(memberCount) ~= "number" or memberCount <= 0 or memberCount > RAID_FRAME_COUNT then
            memberCount = RAID_FRAME_COUNT
        end
        for index = 1, memberCount do
            local frame = _G[RAID_FRAME_NAMES[index]]
            if frame then callback(frame) end
        end
        local slotCount = math.min(memberCount, RAID_GROUP_SLOT_COUNT)
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
