-- AlwaysInParty: in a raid, use the normal party UI instead of the raid UI.

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
    return not (IsInRaid and IsInRaid()) or IsEnabled()
end

local pending = false
local queued = false

local function SetShown(frame, shown)
    if not frame then return end
    if shown then frame:Show() else frame:Hide() end
end

local function Apply()
    queued = false
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        return
    end

    local enabled = IsEnabled()
    local inRaid = IsInRaid and IsInRaid() or false

    -- AlwaysInParty means party UI replaces raid UI. This is the missing half
    -- of the old behaviour: showing party is not enough if Blizzard's raid
    -- container is still visible.
    if inRaid and enabled then
        SetShown(_G.CompactRaidFrameManager, false)
        if _G.CompactRaidFrameManagerContainer then
            SetShown(_G.CompactRaidFrameManagerContainer, false)
        end
    end

    local showParty = not inRaid or enabled
    SetShown(_G.PartyFrame, showParty)
    SetShown(_G.CompactPartyFrame, showParty)
    SetShown(_G.PartyMemberFrame1, showParty)

    if showParty then
        if _G.PartyFrame and _G.PartyFrame.Update then _G.PartyFrame:Update() end
        if _G.CompactPartyFrame_Update then _G.CompactPartyFrame_Update() end
        if _G.PartyMemberFrame1 then
            _G.PartyMemberFrame1.unit = "player"
            if _G.PartyMemberFrame_Update then
                _G.PartyMemberFrame_Update(_G.PartyMemberFrame1, "player")
            end
        end
    end

    pending = false
end

local function Queue(delay)
    pending = true
    if queued then return end
    queued = true
    C_Timer.After(delay or 0.2, Apply)
end

function addon.RefreshPartyFrames()
    Queue(0)
end

function addon.SetAlwaysInPartyEnabled(enabled)
    local config = GetConfig()
    if not config then return false end
    config.alwaysInParty = enabled == true
    Queue(0)
    if addon.RequestRefresh then addon.RequestRefresh(true) end
    return true
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
    "PARTY_INVITE_REQUEST", "PARTY_LEADER_CHANGED", "PLAYER_REGEN_ENABLED"
}) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then Queue(0) end
    else
        Queue(0.2)
    end
end)

addon.RegisterInitializer(function()
    Queue(0.2)
end)
