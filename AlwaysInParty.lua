-- AlwaysInParty: keep Blizzard's party frames visible while in a raid.
-- This deliberately follows the old working implementation: react to group
-- changes and explicitly show the native party frames. Blizzard owns raid UI.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown
local IsInRaid = IsInRaid

local function GetConfig()
    return addon.PlayerBarConfig and addon.PlayerBarConfig.Get and addon.PlayerBarConfig.Get()
end

local function IsEnabled()
    local config = GetConfig()
    return config and config.alwaysInParty == true
end

addon.IsAlwaysInPartyEnabled = IsEnabled

function addon.ShouldShowPartyFrames()
    if IsInRaid and IsInRaid() then
        return IsEnabled()
    end
    return true
end

local pending = false
local queued = false

local function ShowPartyFrames()
    queued = false

    if InCombatLockdown and InCombatLockdown() then
        pending = true
        return
    end

    if not addon.ShouldShowPartyFrames() then
        pending = false
        return
    end

    if _G.PartyFrame then
        _G.PartyFrame:Show()
        if _G.PartyFrame.Update then
            _G.PartyFrame:Update()
        end
    end

    if _G.CompactPartyFrame then
        _G.CompactPartyFrame:Show()
        if _G.CompactPartyFrame_Update then
            _G.CompactPartyFrame_Update()
        end
    end

    if _G.PartyMemberFrame1 then
        _G.PartyMemberFrame1:Show()
        _G.PartyMemberFrame1.unit = "player"
        if _G.PartyMemberFrame_Update then
            _G.PartyMemberFrame_Update(_G.PartyMemberFrame1, "player")
        end
    end

    if _G.CompactPartyFrameMemberFrame1 then
        _G.CompactPartyFrameMemberFrame1:Show()
        if _G.CompactPartyFrameMemberFrame1.SetUnit then
            _G.CompactPartyFrameMemberFrame1:SetUnit("player")
        end
    end

    pending = false
end

local function QueueShow(delay)
    pending = true
    if queued then return end
    queued = true
    C_Timer.After(delay or 0.2, ShowPartyFrames)
end

function addon.RefreshPartyFrames()
    QueueShow(0)
end

function addon.SetAlwaysInPartyEnabled(enabled)
    local config = GetConfig()
    if not config then return false end

    config.alwaysInParty = enabled == true

    if enabled then
        QueueShow(0.2)
    end

    if addon.RequestRefresh then
        addon.RequestRefresh(true)
    end

    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PARTY_INVITE_REQUEST")
eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then
            QueueShow(0)
        end
        return
    end

    QueueShow(0.2)
end)

addon.RegisterInitializer(function()
    QueueShow(0.2)
end)
