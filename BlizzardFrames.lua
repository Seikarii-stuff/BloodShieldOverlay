-- Absorb overlays for Blizzard player and compact party/raid frames.
--
-- CompactUnitFrame already owns the complete lifecycle for Blizzard's group
-- frames. Piggyback on that lifecycle instead of maintaining a second
-- frame/healthbar discovery system. A new/recycled raid frame calls
-- CompactUnitFrame_UpdateAll/Health/HealPrediction; those hooks are therefore
-- the authoritative and cheap place to read its current unit and absorb.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealthMax = UnitHealthMax
local hooksecurefunc = hooksecurefunc
local type = type

local manager = CreateFrame("Frame")
local IsForbiddenFrame = addon.IsForbiddenFrame
local IsStatusBar = addon.IsStatusBar
local GetUnit = addon.GetUnit
local ForEachCompactFrame = addon.ForEachCompactFrame

local PARTY_UNITS = { player = true }
local RAID_UNITS = { player = true }
for i = 1, 4 do PARTY_UNITS["party" .. i] = true end
for i = 1, 40 do RAID_UNITS["raid" .. i] = true end

local compactState = setmetatable({}, { __mode = "k" })
local playerOverlay
local personalOverlay

local function InRaid()
    return IsInRaid and IsInRaid() or false
end

local function IsSupportedUnit(unit)
    if type(unit) ~= "string" then return false end
    if InRaid() then return RAID_UNITS[unit] == true end
    return PARTY_UNITS[unit] == true
end

local function GetCompactHealthBar(frame)
    if not frame or IsForbiddenFrame(frame) then return nil end
    local healthBar = frame.healthBar
    if IsStatusBar(healthBar) then return healthBar end
    return nil
end

local function HideOverlay(overlay)
    if not overlay then return end
    overlay:Hide()
    overlay.lastAbsorb = nil
    overlay.lastMaxHealth = nil
end

local function UpdateCompactFrame(frame)
    if not frame or IsForbiddenFrame(frame) then return end

    local state = compactState[frame]
    if not state then
        state = {}
        compactState[frame] = state
    end

    local healthBar = GetCompactHealthBar(frame)
    local unit = GetUnit(frame)

    if not healthBar or not unit or not IsSupportedUnit(unit) then
        if state.overlay then HideOverlay(state.overlay) end
        state.unit = nil
        state.healthBar = nil
        return
    end

    if state.healthBar ~= healthBar then
        if state.overlay then HideOverlay(state.overlay) end
        state.overlay = addon.CreateAbsorbOverlay(healthBar)
        state.healthBar = healthBar
    end

    state.unit = unit
    addon.UpdateAbsorbOverlay(state.overlay, UnitGetTotalAbsorbs(unit) or 0, UnitHealthMax(unit) or 1)
end

local function ScanExistingCompactFrames()
    -- Fixed, bounded lookup only for initialization/layout changes. The hot
    -- path for a newly materialized/recycled frame is Blizzard's own hooks.
    ForEachCompactFrame(UpdateCompactFrame)
end

local function GetPlayerFrameHealthBar()
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local area = main and main.HealthBarArea
    local bar = area and (area.HealthBar or area)
    return IsStatusBar(bar) and bar or nil
end

local function UpdatePlayerOverlay()
    local healthBar = GetPlayerFrameHealthBar()
    if not healthBar then
        HideOverlay(playerOverlay)
        playerOverlay = nil
        return
    end
    if not playerOverlay then
        playerOverlay = addon.CreateAbsorbOverlay(healthBar)
    end
    addon.UpdateAbsorbOverlay(playerOverlay, UnitGetTotalAbsorbs("player") or 0, UnitHealthMax("player") or 1)
end

local function GetPersonalResourceHealthBar()
    local container = PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.HealthBarsContainer
    local bar = container and (container.healthBar or container.HealthBar)
    return IsStatusBar(bar) and bar or nil
end

local function UpdatePersonalOverlay()
    local healthBar = GetPersonalResourceHealthBar()
    if not healthBar then
        HideOverlay(personalOverlay)
        personalOverlay = nil
        return
    end
    if not personalOverlay then
        personalOverlay = addon.CreateAbsorbOverlay(healthBar)
    end
    addon.UpdateAbsorbOverlay(personalOverlay, UnitGetTotalAbsorbs("player") or 0, UnitHealthMax("player") or 1)
end

-- Keep solo visibility completely owned by ShowPartyWhenSolo.lua. The
-- fallback exists only for load-order safety and is isolated from absorb
-- handling.
local function FallbackRefreshPartyFrames()
    if InCombatLockdown() then return end
    if IsInRaid and IsInRaid() then
        if PartyFrame and PartyFrame.Hide then PartyFrame:Hide() end
        if CompactPartyFrame and CompactPartyFrame.Hide then CompactPartyFrame:Hide() end
        return
    end

    if PartyFrame and PartyFrame.Show then
        PartyFrame:Show()
        if PartyFrame.Update then PartyFrame:Update() end
    end
    if CompactPartyFrame and CompactPartyFrame.Show then
        CompactPartyFrame:Show()
        if _G.CompactPartyFrame_Update then _G.CompactPartyFrame_Update() end
    end

    local legacy = _G.PartyMemberFrame1
    if legacy and legacy.Show then
        legacy:Show()
        if not IsInGroup() then legacy.unit = "player" end
        if _G.PartyMemberFrame_Update and legacy.unit then
            _G.PartyMemberFrame_Update(legacy, legacy.unit)
        end
    end

    local compact = _G.CompactPartyFrameMemberFrame1
    if compact and compact.Show then
        compact:Show()
        if not IsInGroup() and compact.SetUnit then compact:SetUnit("player") end
    end
end

addon.RefreshPartyFrames = addon.RefreshPartyFrames or FallbackRefreshPartyFrames

local function RefreshAll()
    if InCombatLockdown() then return end
    addon.RefreshPartyFrames()
    ScanExistingCompactFrames()
    UpdatePlayerOverlay()
    UpdatePersonalOverlay()
end

if hooksecurefunc then
    -- Same basic strategy used by established raid-frame addons: hook the
    -- Blizzard compact-frame update functions and read frame.healthBar and
    -- frame.unit directly. A new 21st/39th frame is handled by Blizzard itself;
    -- no roster-wide hierarchy scan is needed.
    local function OnCompactUnitFrameUpdated(frame)
        -- Do NOT gate this on InCombatLockdown(). Blizzard's own compact-frame
        -- updates happen during combat too, and this hook only reads frame.unit
        -- / frame.healthBar and updates an unprotected child overlay. Skipping
        -- this hook in combat is exactly how a newly recycled raid frame can
        -- miss its first bind.
        UpdateCompactFrame(frame)
    end

    if _G.CompactUnitFrame_UpdateAll then
        hooksecurefunc("CompactUnitFrame_UpdateAll", OnCompactUnitFrameUpdated)
    end
    if _G.CompactUnitFrame_UpdateHealth then
        hooksecurefunc("CompactUnitFrame_UpdateHealth", OnCompactUnitFrameUpdated)
    end
    if _G.CompactUnitFrame_UpdateHealPrediction then
        hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", OnCompactUnitFrameUpdated)
    end
    if _G.CompactUnitFrame_SetUpFrame then
        hooksecurefunc("CompactUnitFrame_SetUpFrame", OnCompactUnitFrameUpdated)
    end
end

addon.RegisterInitializer(function()
    addon.RegisterUnitUpdateListener(function(unit)
        if unit == "player" then
            UpdatePlayerOverlay()
            UpdatePersonalOverlay()
        end
    end)
end)

local refreshPending = false
local function QueueRefresh()
    if refreshPending or InCombatLockdown() then return end
    refreshPending = true
    C_Timer.After(0.05, function()
        refreshPending = false
        RefreshAll()
    end)
end

-- Core.lua is the single owner of layout/roster event dispatch. Raid roster
-- changes intentionally do not schedule a discovery pass here: Blizzard's
-- CompactUnitFrame lifecycle handles new/recycled raid frames directly.
addon.RegisterLayoutListener(function(event)
    if event == "GROUP_ROSTER_UPDATE" and InRaid() then
        return
    end
    QueueRefresh()
end)

addon.RegisterRegenListener(function(event)
    if event == "PLAYER_REGEN_ENABLED" then
        QueueRefresh()
    end
end)
