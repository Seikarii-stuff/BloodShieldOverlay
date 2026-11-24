-- Temporary visual role markers on Blizzard compact party/raid frames.
-- Resolve the current target with UnitIsUnit; never read GUIDs or player names.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local hooksecurefunc = hooksecurefunc
local type = type
local pairs = pairs

local markedUnits = {}
local markersByFrame = setmetatable({}, { __mode = "k" })
local function GetGroupState()
    if not IsInGroup or not IsInGroup() then return "none" end
    return IsInRaid and IsInRaid() and "raid" or "party"
end
local lastGroupKind = GetGroupState()
local ROLE_STYLE = {
    heal = { atlas = "roleicon-tiny-healer" },
    tank = { atlas = "roleicon-tiny-tank" },
    dps = { atlas = "roleicon-tiny-dps" },
    -- Carry is not a Blizzard group role, so use the familiar raid star.
    carry = { texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
}

local function FindTargetGroupUnit()
    if not UnitExists("target") then return nil end
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        if count > 40 then count = 40 end
        for index = 1, count do
            local unit = "raid" .. index
            if UnitIsUnit("target", unit) then return unit end
        end
    elseif IsInGroup and IsInGroup() then
        count = math.min(4, math.max(0, count - 1))
        for index = 1, count do
            local unit = "party" .. index
            if UnitIsUnit("target", unit) then return unit end
        end
    end
    return nil
end

local function CreateMarker(frame)
    if not frame or addon.IsForbiddenFrame(frame) or InCombatLockdown() then return nil end
    local marker = CreateFrame("Frame", nil, frame)
    marker:SetSize(18, 18)
    marker:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    marker:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 20)
    marker:EnableMouse(false)
    local background = marker:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(marker)
    background:SetColorTexture(0.05, 0.05, 0.05, 0.82)
    local icon = marker:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER", marker, "CENTER", 0, 0)
    marker.icon = icon
    marker:Hide()
    markersByFrame[frame] = marker
    return marker
end

local function UpdateFrame(frame)
    if not frame or addon.IsForbiddenFrame(frame) or InCombatLockdown() then return end
    local unit = addon.GetUnit(frame)
    local marker = markersByFrame[frame]
    if not marker and unit and markedUnits[unit] then marker = CreateMarker(frame) end
    if not marker then return end
    local role = unit and markedUnits[unit]
    if role and ROLE_STYLE[role] then
        local style = ROLE_STYLE[role]
        if style.atlas then
            marker.icon:SetAtlas(style.atlas)
        else
            marker.icon:SetTexture(style.texture)
        end
        marker:Show()
    else
        marker:Hide()
    end
end

local function RefreshFrames()
    if InCombatLockdown() then return end
    for frame in pairs(markersByFrame) do UpdateFrame(frame) end
    addon.ForEachCompactFrame(UpdateFrame)
end

local function ClearMarks()
    for unit in pairs(markedUnits) do markedUnits[unit] = nil end
end

function addon.HandleRoleSlashCommand(role, message)
    if not ROLE_STYLE[role] then return end
    local argument = type(message) == "string" and message:match("^%s*(.-)%s*$") or ""
    if argument ~= "" then
        print("BloodShieldOverlay: /" .. role .. " takes no arguments. Target a group member, then use /" .. role .. ".")
        return
    end

    local unit = FindTargetGroupUnit()
    if not unit then
        print("BloodShieldOverlay: your target is not in your current party or raid.")
        return
    end

    local previousRole = markedUnits[unit]
    if previousRole == role then
        markedUnits[unit] = nil
    else
        markedUnits[unit] = role
    end
    RefreshFrames()
    if markedUnits[unit] then
        print("BloodShieldOverlay: target marked as " .. role .. ".")
    elseif previousRole then
        print("BloodShieldOverlay: " .. previousRole .. " marker removed.")
    end
end

function addon.HandleHealSlashCommand(message)
    addon.HandleRoleSlashCommand("heal", message)
end

addon.RegisterLayoutListener(function(event)
    if event == "GROUP_ROSTER_UPDATE" then
        local groupKind = GetGroupState()
        -- Keep marks while this group changes. Clear only after leaving it so
        -- marks do not carry into the next party/raid.
        if groupKind == "none" and lastGroupKind ~= "none" then ClearMarks() end
        lastGroupKind = groupKind
    end
    RefreshFrames()
end)

addon.RegisterRegenListener(function(event)
    if event == "PLAYER_REGEN_ENABLED" then RefreshFrames() end
end)

if hooksecurefunc then
    local function OnCompactFrameUpdated(frame) UpdateFrame(frame) end
    if _G.CompactUnitFrame_UpdateAll then hooksecurefunc("CompactUnitFrame_UpdateAll", OnCompactFrameUpdated) end
    if _G.CompactUnitFrame_UpdateHealth then hooksecurefunc("CompactUnitFrame_UpdateHealth", OnCompactFrameUpdated) end
    if _G.CompactUnitFrame_UpdateHealPrediction then hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", OnCompactFrameUpdated) end
    if _G.CompactUnitFrame_SetUpFrame then hooksecurefunc("CompactUnitFrame_SetUpFrame", OnCompactFrameUpdated) end
end
