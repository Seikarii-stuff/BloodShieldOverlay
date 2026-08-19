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

local pendingRefresh = false
local refreshScheduled = false

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

-- The shared Core event bus owns GROUP_ROSTER_UPDATE/PLAYER_ENTERING_WORLD and
-- layout events. Solo visibility subscribes directly instead of depending on
-- BlizzardFrames.lua's old private event frame.
addon.RegisterLayoutListener(function()
    TryEnsurePartyFramesVisible()
end)

-- Blizzard's party frames may not exist yet at the exact instant the addon
-- initializer runs. The old BlizzardFrames event path effectively gave them a
-- short post-login/layout delay; preserve that behavior without restoring a
-- second event frame.
local function ScheduleInitialRefresh()
    if refreshScheduled then return end
    refreshScheduled = true
    C_Timer.After(0.05, function()
        refreshScheduled = false
        TryEnsurePartyFramesVisible()
    end)
end

addon.RegisterInitializer(function()
    ScheduleInitialRefresh()
end)

addon.RegisterInitializer(function()
    addon.RegisterRegenListener(function(event)
        if event == "PLAYER_REGEN_ENABLED" and pendingRefresh then
            ScheduleInitialRefresh()
        end
    end)
end)
