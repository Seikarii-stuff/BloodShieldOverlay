-- Always In Party support.
-- This module exclusively owns Blizzard party-frame visibility while in raids.
-- Discovery never changes party visibility; it consumes ShouldShowPartyFrames().

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown
local hooksecurefunc = hooksecurefunc

local initialized = false
local pendingSync = false
local syncQueued = false

local function GetConfig()
    local config = addon.PlayerBarConfig and addon.PlayerBarConfig.Get and addon.PlayerBarConfig.Get()
    if config and (config.configVersion or 0) < 9 then
        config.alwaysInParty = true
        config.configVersion = 9
    end
    return config
end

local function IsEnabled()
    local config = GetConfig()
    return config and config.alwaysInParty == true
end

addon.IsAlwaysInPartyEnabled = IsEnabled

local function SetShown(frame, shown)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    if shown then frame:Show() else frame:Hide() end
end

local function ApplyVisibility()
    syncQueued = false
    if InCombatLockdown() then
        pendingSync = true
        return
    end

    local showParty = addon.ShouldShowPartyFrames and addon.ShouldShowPartyFrames() or true
    pendingSync = false

    if PartyFrame then
        SetShown(PartyFrame, showParty)
        if showParty and PartyFrame.Update then PartyFrame:Update() end
    end
    if CompactPartyFrame then
        SetShown(CompactPartyFrame, showParty)
        if showParty and _G.CompactPartyFrame_Update then _G.CompactPartyFrame_Update() end
    end
    local partyMemberFrame = _G.PartyMemberFrame1
    if partyMemberFrame then
        SetShown(partyMemberFrame, showParty)
        if showParty and not IsInGroup() then
            partyMemberFrame.unit = "player"
            if _G.PartyMemberFrame_Update then
                _G.PartyMemberFrame_Update(partyMemberFrame, partyMemberFrame.unit)
            end
        end
    end

    if addon.RequestRefresh then addon.RequestRefresh(true) end
end

local function QueueVisibilitySync(delay)
    pendingSync = true
    if syncQueued then return end
    syncQueued = true
    C_Timer.After(delay or 0, ApplyVisibility)
end

addon.RefreshPartyFrames = function()
    QueueVisibilitySync(0)
end

function addon.SetAlwaysInPartyEnabled(enabled)
    local config = GetConfig()
    if not config then return false end
    config.alwaysInParty = enabled == true
    QueueVisibilitySync(0)
    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingSync then QueueVisibilitySync(0) end
        return
    end
    QueueVisibilitySync(0)
end)

local function OnBlizzardPartyFrameUpdate()
    if addon.IsInRaidMode and addon.IsInRaidMode() and not IsEnabled() then
        QueueVisibilitySync(0)
    end
end

if hooksecurefunc then
    if _G.CompactPartyFrame_Update then hooksecurefunc("CompactPartyFrame_Update", OnBlizzardPartyFrameUpdate) end
    if _G.PartyFrame_Update then hooksecurefunc("PartyFrame_Update", OnBlizzardPartyFrameUpdate) end
    if _G.PartyMemberFrame_Update then hooksecurefunc("PartyMemberFrame_Update", OnBlizzardPartyFrameUpdate) end
end

addon.RegisterInitializer(function()
    if initialized then return end
    initialized = true
    QueueVisibilitySync(0)
end)
