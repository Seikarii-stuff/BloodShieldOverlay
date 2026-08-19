-- Absorb overlays for Blizzard's player, party, and raid compact frames.
-- Discovery/cache owns overlays only. ShowPartyWhenSolo owns solo party-frame visibility.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
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
local unitFrames = setmetatable({}, { __mode = "k" })
local framesByUnit = {}
local frameGeneration = setmetatable({}, { __mode = "k" })
local generation = 0
local discoveryPending = false
local pendingRefresh = false
local fullRefreshPending = true
local dirtyFrames = setmetatable({}, { __mode = "k" })
local rosterDirty = false
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

-- Keep group-state decisions local to this module. ShowPartyWhenSolo is a
-- separate visibility controller and must never turn solo into party mode.
local function GetCurrentMode()
    if IsInRaid and IsInRaid() then return "raid" end
    if IsInGroup and IsInGroup() then return "party" end
    return "solo"
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
                if IsStatusBar(subBar) then healthBar = subBar break end
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
    if mode == "party" or mode == "solo" then return PARTY_UNITS[unit] == true end
    return false
end

local function RemoveFrameFromUnit(unit, frame)
    local bucket = framesByUnit[unit]
    if not bucket then return end
    bucket[frame] = nil
    if not next(bucket) then framesByUnit[unit] = nil end
end

local function DetachFrame(frame, unit)
    unit = unit or unitFrames[frame]
    if not unit then
        unitFrames[frame] = nil
        frameGeneration[frame] = nil
        return
    end
    RemoveFrameFromUnit(unit, frame)
    local healthBar = GetHealthBar(frame)
    local entry = healthBar and overlaysByHealthBar[healthBar]
    if entry and entry.unit == unit then
        entry.overlay:Hide()
        entry.unit = nil
        overlaysByHealthBar[healthBar] = nil
        if overlays[unit] then overlays[unit][healthBar] = nil end
    end
    if overlays[unit] and not next(overlays[unit]) then overlays[unit] = nil end
    unitFrames[frame] = nil
    frameGeneration[frame] = nil
end

local function AddOverlay(unit, healthBar)
    local entry = overlaysByHealthBar[healthBar]
    if not entry then
        entry = { healthBar = healthBar, overlay = addon.CreateAbsorbOverlay(healthBar) }
        overlaysByHealthBar[healthBar] = entry
    end
    if entry.unit and entry.unit ~= unit and overlays[entry.unit] then
        overlays[entry.unit][healthBar] = nil
    end
    entry.unit = unit
    overlays[unit] = overlays[unit] or {}
    overlays[unit][healthBar] = entry
    return entry
end

local function AttachFrame(frame, unit)
    unitFrames[frame] = unit
    framesByUnit[unit] = framesByUnit[unit] or setmetatable({}, { __mode = "k" })
    framesByUnit[unit][frame] = true
    frameGeneration[frame] = generation
    local healthBar = GetHealthBar(frame)
    if healthBar then AddOverlay(unit, healthBar) end
end

local function ReconcileFrame(frame, mode)
    if IsForbiddenFrame(frame) then return end
    mode = mode or compactMode or GetCurrentMode()
    local previousUnit = unitFrames[frame]
    local unit = GetUnit(frame)
    if previousUnit and previousUnit ~= unit then DetachFrame(frame, previousUnit) end
    if not unit or not IsSupportedUnit(unit, mode) then
        if previousUnit then DetachFrame(frame, previousUnit) end
        return
    end
    if previousUnit ~= unit then
        AttachFrame(frame, unit)
    else
        frameGeneration[frame] = generation
        local healthBar = GetHealthBar(frame)
        if healthBar then AddOverlay(unit, healthBar) end
    end
end

local function ReconcileAllCurrentFrames()
    generation = generation + 1
    local mode = GetCurrentMode()
    compactMode = mode
    ForEachCompactFrame(function(frame) ReconcileFrame(frame, mode) end)
    for frame in pairs(unitFrames) do
        if frameGeneration[frame] ~= generation then DetachFrame(frame) end
    end
end

local function UpdateUnit(unit, absorb, maxHealth)
    local entries = overlays[unit]
    if not entries then return end
    absorb = absorb or UnitGetTotalAbsorbs(unit) or 0
    maxHealth = maxHealth or UnitHealthMax(unit) or 1
    for _, entry in next, entries do addon.UpdateAbsorbOverlay(entry.overlay, absorb, maxHealth) end
end

local function GetPlayerFrameHealthBar()
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local area = main and main.HealthBarArea
    return area and GetHealthBar(area.HealthBar or area)
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

local function DiscoverFrames(full)
    if InCombatLockdown() then pendingRefresh = true return end
    local mode = GetCurrentMode()
    local modeChanged = compactMode ~= mode
    if full or fullRefreshPending or modeChanged then
        fullRefreshPending = false
        rosterDirty = false
        dirtyFrames = setmetatable({}, { __mode = "k" })
        ReconcileAllCurrentFrames()
    elseif rosterDirty then
        rosterDirty = false
        for frame in pairs(dirtyFrames) do
            dirtyFrames[frame] = nil
            ReconcileFrame(frame, mode)
        end
    end
    local playerHealthBar = GetPlayerFrameHealthBar()
    if playerHealthBar then AddOverlay("player", playerHealthBar) end
    local personalResourceHealthBar = GetPersonalResourceHealthBar()
    if personalResourceHealthBar then AddOverlay("player", personalResourceHealthBar) end
end

local QueueDiscoverAndUpdate
local function OnDiscoveryTimer()
    discoveryPending = false
    DiscoverFrames(fullRefreshPending)
    if pendingRefresh then pendingRefresh = false QueueDiscoverAndUpdate(false) end
end

QueueDiscoverAndUpdate = function(full)
    if full then fullRefreshPending = true end
    if InCombatLockdown() then pendingRefresh = true return end
    if discoveryPending then pendingRefresh = true return end
    discoveryPending = true
    C_Timer.After(0.05, OnDiscoveryTimer)
end

addon.RequestRefresh = QueueDiscoverAndUpdate
addon.RegisterLayoutListener(function(event)
    if event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED"
        or event == "DISPLAY_SIZE_CHANGED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        fullRefreshPending = true
    else
        rosterDirty = true
    end
    QueueDiscoverAndUpdate(fullRefreshPending)
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
            QueueDiscoverAndUpdate(true)
        end
    end)
end)

if hooksecurefunc then
    local ScheduleUnitUpdate = addon.ScheduleUnitUpdate
    local function OnCompactUnitFrameUpdated(frame)
        if InCombatLockdown() or IsForbiddenFrame(frame) then return end
        local unit = GetUnit(frame)
        if unit and IsSupportedUnit(unit) then
            dirtyFrames[frame] = true
            rosterDirty = true
            ReconcileFrame(frame)
            if ScheduleUnitUpdate then ScheduleUnitUpdate(unit) else UpdateUnit(unit) end
        elseif unitFrames[frame] then
            dirtyFrames[frame] = true
            rosterDirty = true
            ReconcileFrame(frame)
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
        QueueDiscoverAndUpdate(true)
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
        if unit and UnitIsUnit(unit, "player") then QueueDiscoverAndUpdate(false) end
        return
    end
    if event == "NAME_PLATE_UNIT_ADDED" and (not unit or not UnitIsUnit(unit, "player")) then return end
    QueueDiscoverAndUpdate(false)
end)
