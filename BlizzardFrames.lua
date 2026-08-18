-- Absorb overlays for Blizzard's player, personal-resource, party, and raid frames.
-- Blizzard's CompactUnitFrames are the only supported group-frame source.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealthMax = UnitHealthMax
local UnitIsUnit = UnitIsUnit
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local next = next
local pairs = pairs
local type = type
local string_find = string.find
local manager = CreateFrame("Frame")

local overlays = {}
local overlaysByHealthBar = setmetatable({}, { __mode = "k" })
local healthBarCache = setmetatable({}, { __mode = "k" })
local discoveryPending = false
local pendingRefresh = false
local fullRefreshPending = false
local dirtyUnits = {}
local unitFrames = {}
local compactMode = nil

local HEALTH_BAR_KEYS = { "healthBar", "HealthBar", "healthbar", "health", "Health", "HealthBarArea" }
local PARTY_UNITS = { player = true }
local RAID_UNITS = { player = true }

for index = 1, 4 do PARTY_UNITS["party" .. index] = true end
for index = 1, 40 do RAID_UNITS["raid" .. index] = true end

local IsForbiddenFrame = addon.IsForbiddenFrame
local IsStatusBar = addon.IsStatusBar
local GetFrameName = addon.GetFrameName
local GetUnit = addon.GetUnit
local ForEachCompactFrame = addon.ForEachCompactFrame

local function InRaidMode()
    return IsInRaid and IsInRaid() or false
end

local function GetCurrentMode()
    return InRaidMode() and "raid" or "party"
end

local function GetHealthBar(frame)
    if IsForbiddenFrame(frame) then return nil end
    local cached = healthBarCache[frame]
    if cached ~= nil then return cached or nil end

    local healthBar
    for _, key in ipairs(HEALTH_BAR_KEYS) do
        local bar = frame[key]
        if IsStatusBar(bar) then
            healthBar = bar
            break
        elseif bar and not IsForbiddenFrame(bar) then
            for _, subKey in ipairs(HEALTH_BAR_KEYS) do
                local subBar = bar[subKey]
                if IsStatusBar(subBar) then
                    healthBar = subBar
                    break
                end
            end
            if healthBar then break end
        end
    end

    if not healthBar and IsStatusBar(frame) then
        local name = GetFrameName(frame)
        if name == "" or string_find(name, "Health", 1, true) then healthBar = frame end
    end

    healthBarCache[frame] = healthBar or false
    return healthBar
end

local function IsSupportedUnit(unit, mode)
    if type(unit) ~= "string" then return false end
    mode = mode or compactMode or GetCurrentMode()
    if mode == "raid" then return RAID_UNITS[unit] == true end
    return PARTY_UNITS[unit] == true
end

local function RemoveFrame(frame, unit)
    if not frame then return end
    unit = unit or unitFrames[frame]
    if unit then
        local entries = overlays[unit]
        if entries then
            local healthBar = GetHealthBar(frame)
            local entry = healthBar and overlaysByHealthBar[healthBar]
            if entry and entry.unit == unit then
                entry.overlay:Hide()
                entry.unit = nil
                overlaysByHealthBar[healthBar] = nil
            end
            if healthBar then entries[healthBar] = nil end
            if not next(entries) then overlays[unit] = nil end
        end
    end
    unitFrames[frame] = nil
end

local function AddOverlay(unit, healthBar)
    local entry = overlaysByHealthBar[healthBar]
    if not entry then
        entry = { healthBar = healthBar, overlay = addon.CreateAbsorbOverlay(healthBar) }
        overlaysByHealthBar[healthBar] = entry
    end

    if entry.unit == unit then return entry end
    if entry.unit and overlays[entry.unit] then overlays[entry.unit][healthBar] = nil end

    entry.unit = unit
    overlays[unit] = overlays[unit] or {}
    overlays[unit][healthBar] = entry
    return entry
end

local function ReconcileFrame(frame, mode)
    if IsForbiddenFrame(frame) then return end
    mode = mode or compactMode or GetCurrentMode()
    local previousUnit = unitFrames[frame]
    local unit = GetUnit(frame)

    if previousUnit and previousUnit ~= unit then
        RemoveFrame(frame, previousUnit)
    end

    if not unit or not IsSupportedUnit(unit, mode) then
        unitFrames[frame] = nil
        return
    end

    local healthBar = GetHealthBar(frame)
    if not healthBar then
        unitFrames[frame] = unit
        return
    end

    AddOverlay(unit, healthBar)
    unitFrames[frame] = unit
end

local function ReconcileUnit(unit, mode)
    if not unit then return end
    mode = mode or compactMode or GetCurrentMode()
    local frame = unitFrames[unit]
    if frame then
        ReconcileFrame(frame, mode)
        return
    end

    -- A unit may have just been assigned a new Blizzard frame. Ask Blizzard's
    -- authoritative frame pool for the current frame, but only once for this
    -- dirty unit; never perform a full tree scan.
    ForEachCompactFrame(function(candidate)
        if GetUnit(candidate) == unit then
            ReconcileFrame(candidate, mode)
        end
    end)
end

local function MarkUnitDirty(unit)
    if unit and IsSupportedUnit(unit) then dirtyUnits[unit] = true end
end

local function DiscoverAllCompactFrames()
    local mode = GetCurrentMode()
    compactMode = mode
    local seenFrames = {}
    ForEachCompactFrame(function(frame)
        seenFrames[frame] = true
        ReconcileFrame(frame, mode)
    end)

    for frame, unit in pairs(unitFrames) do
        if not seenFrames[frame] then
            RemoveFrame(frame, unit)
        end
    end
end

local function TryEnsurePartyFramesVisible()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    local inRaid = InRaidMode()
    local inGroup = IsInGroup and IsInGroup()

    local function SetShown(frame, shown)
        if IsForbiddenFrame(frame) then return end
        if shown then frame:Show() else frame:Hide() end
    end

    if PartyFrame then
        SetShown(PartyFrame, not inRaid)
        if not inRaid and PartyFrame.Update then PartyFrame:Update() end
    end

    if CompactPartyFrame then
        SetShown(CompactPartyFrame, not inRaid)
        if not inRaid and _G.CompactPartyFrame_Update then _G.CompactPartyFrame_Update() end
    end

    local partyMemberFrame = _G.PartyMemberFrame1
    if partyMemberFrame then
        SetShown(partyMemberFrame, not inRaid)
        if not inRaid and not inGroup then
            partyMemberFrame.unit = "player"
            if _G.PartyMemberFrame_Update then _G.PartyMemberFrame_Update(partyMemberFrame, partyMemberFrame.unit) end
        end
    end
end

addon.RefreshPartyFrames = TryEnsurePartyFramesVisible

local function GetPlayerFrameHealthBar()
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local healthBarArea = main and main.HealthBarArea
    return healthBarArea and GetHealthBar(healthBarArea.HealthBar or healthBarArea)
end

local function GetPersonalResourceHealthBar()
    local container = PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.HealthBarsContainer
    local healthBar = container and (container.healthBar or container.HealthBar)
    if IsStatusBar(healthBar) then return healthBar end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local nameplate = C_NamePlate.GetNamePlateForUnit("player")
    if not nameplate then return nil end
    return GetHealthBar(nameplate.UnitFrame or nameplate.unitFrame)
end

local function AddDirtyUnitsToUpdate()
    local mode = GetCurrentMode()
    for unit in pairs(dirtyUnits) do
        if IsSupportedUnit(unit, mode) then
            ReconcileUnit(unit, mode)
        end
        dirtyUnits[unit] = nil
    end
end

local function UpdateUnit(unit, absorb, maxHealth)
    local entries = overlays[unit]
    if not entries then return end
    absorb = absorb or UnitGetTotalAbsorbs(unit) or 0
    maxHealth = maxHealth or UnitHealthMax(unit) or 1
    for _, entry in next, entries do addon.UpdateAbsorbOverlay(entry.overlay, absorb, maxHealth) end
end

local function UpdateAll()
    for unit in pairs(overlays) do UpdateUnit(unit) end
end

local function DiscoverFrames()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    TryEnsurePartyFramesVisible()

    local mode = GetCurrentMode()
    if fullRefreshPending or compactMode ~= mode then
        fullRefreshPending = false
        dirtyUnits = {}
        DiscoverAllCompactFrames()
    else
        AddDirtyUnitsToUpdate()
    end

    local playerHealthBar = GetPlayerFrameHealthBar()
    if playerHealthBar then AddOverlay("player", playerHealthBar) end

    local personalResourceHealthBar = GetPersonalResourceHealthBar()
    if personalResourceHealthBar then AddOverlay("player", personalResourceHealthBar) end
end

local function DiscoverAndUpdate()
    DiscoverFrames()
    UpdateAll()
end

local QueueDiscoverAndUpdate
local function OnDiscoveryTimer()
    discoveryPending = false
    DiscoverAndUpdate()
    if pendingRefresh then
        pendingRefresh = false
        QueueDiscoverAndUpdate()
    end
end

QueueDiscoverAndUpdate = function()
    if InCombatLockdown() then pendingRefresh = true; return end
    if discoveryPending then pendingRefresh = true; return end
    discoveryPending = true
    C_Timer.After(0.05, OnDiscoveryTimer)
end

addon.RequestRefresh = QueueDiscoverAndUpdate
addon.RegisterLayoutListener(function()
    fullRefreshPending = true
    QueueDiscoverAndUpdate()
end)

addon.RegisterInitializer(function()
    addon.RegisterUnitUpdateListener(function(unit, absorb, maxHealth)
        if overlays[unit] then UpdateUnit(unit, absorb, maxHealth) end
    end)
end)

addon.RegisterInitializer(function()
    addon.RegisterRegenListener(function(event)
        if event == "PLAYER_REGEN_ENABLED" then
            pendingRefresh = false
            fullRefreshPending = true
            QueueDiscoverAndUpdate()
        end
    end)
end)

if hooksecurefunc then
    local ScheduleUnitUpdate = addon.ScheduleUnitUpdate
    local function OnCompactUnitFrameUpdated(frame)
        if InCombatLockdown() or IsForbiddenFrame(frame) then return end
        local unit = GetUnit(frame)
        if unit and IsSupportedUnit(unit) then
            ReconcileFrame(frame)
            if ScheduleUnitUpdate then ScheduleUnitUpdate(unit) else UpdateUnit(unit) end
        end
    end
    if _G.CompactUnitFrame_UpdateAll then hooksecurefunc("CompactUnitFrame_UpdateAll", OnCompactUnitFrameUpdated) end
    if _G.CompactUnitFrame_SetUpFrame then hooksecurefunc("CompactUnitFrame_SetUpFrame", OnCompactUnitFrameUpdated) end
    if _G.CompactUnitFrame_UpdateUnit then hooksecurefunc("CompactUnitFrame_UpdateUnit", OnCompactUnitFrameUpdated) end
end

local editModeExitPending = false
local function OnEditModeExit()
    if editModeExitPending then return end
    editModeExitPending = true
    C_Timer.After(0.2, function()
        editModeExitPending = false
        fullRefreshPending = true
        QueueDiscoverAndUpdate()
    end)
end

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit, addon)
end
if EditModeManagerFrame and EditModeManagerFrame.HookScript then
    EditModeManagerFrame:HookScript("OnHide", OnEditModeExit)
end

manager:RegisterEvent("NAME_PLATE_UNIT_ADDED")
manager:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
manager:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        if unit and UnitIsUnit(unit, "player") then
            QueueDiscoverAndUpdate()
        end
        return
    end
    if event == "NAME_PLATE_UNIT_ADDED" and (not unit or not UnitIsUnit(unit, "player")) then return end
    QueueDiscoverAndUpdate()
end)
