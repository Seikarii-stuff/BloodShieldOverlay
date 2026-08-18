-- AlwaysInParty means exactly this:
--   SOLO  -> create/show the native party frame for the player.
--   PARTY -> Blizzard's normal party frame is used.
--   RAID  -> Blizzard's raid frames are used; NEVER show party as a second group.

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

-- This answers the only question the discovery code needs:
-- party UI is valid unless the player is in a real raid.
function addon.ShouldShowPartyFrames()
    return not (IsInRaid and IsInRaid())
end

local pending = false
local queued = false

local function SetShown(frame, shown)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    if shown then frame:Show() else frame:Hide() end
end

local function Apply()
    queued = false
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        return
    end

    local inRaid = IsInRaid and IsInRaid() or false
    local enabled = IsEnabled()

    if inRaid then
        -- A raid is NEVER an AlwaysInParty state. Leave the raid UI alone and
        -- explicitly remove our solo party presentation if it was visible.
        SetShown(_G.PartyFrame, false)
        SetShown(_G.CompactPartyFrame, false)
        SetShown(_G.PartyMemberFrame1, false)
        SetShown(_G.CompactPartyFrameMemberFrame1, false)
        pending = false
        return
    end

    if not enabled then
        pending = false
        return
    end

    -- Solo: manufacture the normal player-only party presentation.
    SetShown(_G.PartyFrame, true)
    SetShown(_G.CompactPartyFrame, true)
    SetShown(_G.PartyMemberFrame1, true)
    SetShown(_G.CompactPartyFrameMemberFrame1, true)

    if _G.PartyFrame and _G.PartyFrame.Update then
        _G.PartyFrame:Update()
    end
    if _G.CompactPartyFrame_Update then
        _G.CompactPartyFrame_Update()
    end
    if _G.PartyMemberFrame1 then
        _G.PartyMemberFrame1.unit = "player"
        if _G.PartyMemberFrame_Update then
            _G.PartyMemberFrame_Update(_G.PartyMemberFrame1, "player")
        end
    end
    if _G.CompactPartyFrameMemberFrame1 and _G.CompactPartyFrameMemberFrame1.SetUnit then
        _G.CompactPartyFrameMemberFrame1:SetUnit("player")
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
