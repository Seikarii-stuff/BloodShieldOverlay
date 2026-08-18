-- Always In Party support.
-- This module is the only owner of Blizzard party-frame visibility.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
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

function addon.ShouldShowPartyFrames()
    return not (IsInRaid and IsInRaid()) or IsEnabled()
end

local function SetShown(frame, shown)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    if frame:IsShown() ~= shown then
        if shown then frame:Show() else frame:Hide() end
    end
end

local function ApplyVisibility()
    syncQueued = false
    if InCombatLockdown() then
        pendingSync = true
        return
    end

    local showParty = addon.ShouldShowPartyFrames()
    local inGroup = IsInGroup and IsInGroup() or false

    if _G.PartyFrame then
        SetShown(_G.PartyFrame, showParty)
        if showParty and _G.PartyFrame.Update then _G.PartyFrame:Update() end
    end
    if _G.CompactPartyFrame then
        SetShown(_G.CompactPartyFrame, showParty)
        if showParty and _G.CompactPartyFrame_Update then _G.CompactPartyFrame_Update() end
    end

    local partyMemberFrame = _G.PartyMemberFrame1
    if partyMemberFrame then
        SetShown(partyMemberFrame, showParty)
        if showParty and not inGroup then
            partyMemberFrame.unit = "player"
            if _G.PartyMemberFrame_Update then
                _G.PartyMemberFrame_Update(partyMemberFrame, "player")
            end
        end
    end

    pendingSync = false
end

local function QueueVisibilitySync()
    pendingSync = true
    if syncQueued then return end
    syncQueued = true
    C_Timer.After(0, ApplyVisibility)
end

function addon.RefreshPartyFrames()
    QueueVisibilitySync()
end

function addon.SetAlwaysInPartyEnabled(enabled)
    local config = GetConfig()
    if not config then return false end
    config.alwaysInParty = enabled == true
    QueueVisibilitySync()
    if addon.RequestRefresh then addon.RequestRefresh(true) end
    return true
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingSync then QueueVisibilitySync() end
    else
        QueueVisibilitySync()
    end
end)

local function ReassertHidden()
    if IsInRaid and IsInRaid() and not IsEnabled() then
        QueueVisibilitySync()
    end
end

if hooksecurefunc then
    if _G.CompactPartyFrame_Update then hooksecurefunc("CompactPartyFrame_Update", ReassertHidden) end
    if _G.PartyFrame_Update then hooksecurefunc("PartyFrame_Update", ReassertHidden) end
    if _G.PartyMemberFrame_Update then hooksecurefunc("PartyMemberFrame_Update", ReassertHidden) end
end

addon.RegisterInitializer(function()
    if initialized then return end
    initialized = true
    QueueVisibilitySync()
end)
