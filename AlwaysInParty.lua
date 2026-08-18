-- Always In Party support.
-- This module exclusively owns Blizzard party-frame visibility while in raids.
-- BloodShieldOverlay's raid/party discovery remains independent of this option.

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
        -- Version 8 was our erroneous migration. AlwaysInParty has always been
        -- the required default; only the explicit checkbox may turn it off.
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

    local inRaid = IsInRaid and IsInRaid() or false
    local showParty = not inRaid or IsEnabled()
    local inGroup = IsInGroup and IsInGroup() or false

    -- Blizzard's protected party frames cannot always be changed in combat.
    -- Never attempt the protected mutation there; remember the desired state
    -- and enforce it as soon as combat ends.
    if InCombatLockdown() then
        pendingSync = true
        return
    end

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
        if showParty and not inGroup then
            partyMemberFrame.unit = "player"
            if _G.PartyMemberFrame_Update then
                _G.PartyMemberFrame_Update(partyMemberFrame, partyMemberFrame.unit)
            end
        end
    end
end

local function QueueVisibilitySync(delay)
    pendingSync = true
    if syncQueued then return end

    syncQueued = true
    C_Timer.After(delay or 0, function()
        ApplyVisibility()
    end)
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
        if pendingSync or (IsInRaid and IsInRaid()) then
            QueueVisibilitySync(0)
        end
        return
    end
    QueueVisibilitySync(0)
end)

local function OnBlizzardPartyFrameUpdate()
    -- Blizzard can rebuild/re-show its party frames during roster/combat
    -- transitions. In a raid with AlwaysInParty disabled, reassert the rule.
    if IsInRaid and IsInRaid() and not IsEnabled() then
        QueueVisibilitySync(0)
    end
end

if hooksecurefunc then
    if _G.CompactPartyFrame_Update then
        hooksecurefunc("CompactPartyFrame_Update", OnBlizzardPartyFrameUpdate)
    end
    if _G.PartyFrame_Update then
        hooksecurefunc("PartyFrame_Update", OnBlizzardPartyFrameUpdate)
    end
    if _G.PartyMemberFrame_Update then
        hooksecurefunc("PartyMemberFrame_Update", OnBlizzardPartyFrameUpdate)
    end
end

addon.RegisterInitializer(function()
    if initialized then return end
    initialized = true
    QueueVisibilitySync(0)
end)
