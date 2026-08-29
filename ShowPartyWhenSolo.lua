-- ShowPartyWhenSolo: keep Blizzard's party-style frames visible while solo.
-- PARTY uses Blizzard's normal party frames; RAID uses raid frames.
-- This module owns solo visibility directly; it does not depend on
-- BlizzardFrames.lua to forward roster/layout events.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local C_Timer = C_Timer
local hooksecurefunc = hooksecurefunc

local pendingRefresh = false
local refreshScheduled = false
local editModeHooked = false

local function IsForbiddenFrame(frame)
    return frame and addon.IsForbiddenFrame and addon.IsForbiddenFrame(frame)
end

local function TryEnsurePartyFramesVisible()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    local inRaid = IsInRaid and IsInRaid()
    local inGroup = IsInGroup and IsInGroup()

    if inRaid then
        if PartyFrame and PartyFrame.Hide then PartyFrame:Hide() end
        if CompactPartyFrame and CompactPartyFrame.Hide then CompactPartyFrame:Hide() end
        pendingRefresh = false
        return
    end

    local function EnsureFrameShown(frame)
        if IsForbiddenFrame(frame) then return end
        if frame.Show then frame:Show() end
    end

    if PartyFrame then
        EnsureFrameShown(PartyFrame)
        if PartyFrame.Update then PartyFrame:Update() end
    end

    if CompactPartyFrame then
        EnsureFrameShown(CompactPartyFrame)
        if _G.CompactPartyFrame_Update then _G.CompactPartyFrame_Update() end
    end

    local partyMemberFrame = _G.PartyMemberFrame1
    if partyMemberFrame then
        EnsureFrameShown(partyMemberFrame)
        if not inGroup then
            partyMemberFrame.unit = "player"
        end
        if _G.PartyMemberFrame_Update and partyMemberFrame.unit then
            _G.PartyMemberFrame_Update(partyMemberFrame, partyMemberFrame.unit)
        end
    end

    local compactPartyMemberFrame = _G.CompactPartyFrameMemberFrame1
    if compactPartyMemberFrame then
        EnsureFrameShown(compactPartyMemberFrame)
        if not inGroup and compactPartyMemberFrame.SetUnit then
            compactPartyMemberFrame:SetUnit("player")
        end
    end

    pendingRefresh = false
end

addon.RefreshPartyFrames = TryEnsurePartyFramesVisible

-- Public refresh entry point used by /shield reload.
addon.RequestRefresh = function()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    TryEnsurePartyFramesVisible()

    if not refreshScheduled then
        refreshScheduled = true
        C_Timer.After(0.2, function()
            refreshScheduled = false
            TryEnsurePartyFramesVisible()
        end)
    end
end

-- EDIT_MODE_LAYOUTS_UPDATED is emitted while Edit Mode is applying layout
-- changes. The actual exit lifecycle happens in EditModeManagerFrame:ExitEditMode,
-- so hook that method as well and refresh after Blizzard has completed it.
local function ScheduleEditModeExitRefresh()
    if refreshScheduled then return end
    refreshScheduled = true

    C_Timer.After(0.05, function()
        TryEnsurePartyFramesVisible()
    end)

    C_Timer.After(0.20, function()
        TryEnsurePartyFramesVisible()
    end)

    C_Timer.After(0.50, function()
        refreshScheduled = false
        TryEnsurePartyFramesVisible()
    end)
end

local function HookEditModeExit()
    if editModeHooked or not hooksecurefunc then return end
    if not EditModeManagerFrame or not EditModeManagerFrame.ExitEditMode then return end

    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
        ScheduleEditModeExitRefresh()
    end)
    editModeHooked = true
end

-- The shared Core event bus owns GROUP_ROSTER_UPDATE/PLAYER_ENTERING_WORLD and
-- layout events. Solo visibility subscribes directly instead of depending on
-- BlizzardFrames.lua's old private event frame.
addon.RegisterLayoutListener(function(event)
    TryEnsurePartyFramesVisible()

    if event == "EDIT_MODE_LAYOUTS_UPDATED" then
        ScheduleEditModeExitRefresh()
    end
end)

local function ScheduleInitialRefresh()
    if refreshScheduled then return end
    refreshScheduled = true
    C_Timer.After(0.05, function()
        refreshScheduled = false
        TryEnsurePartyFramesVisible()
    end)
end

addon.RegisterInitializer(function()
    HookEditModeExit()
    ScheduleInitialRefresh()
end)

addon.RegisterInitializer(function()
    addon.RegisterRegenListener(function(event)
        if event == "PLAYER_REGEN_ENABLED" and pendingRefresh then
            ScheduleInitialRefresh()
        end
    end)
end)
