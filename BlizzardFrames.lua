-- Absorb overlays for Blizzard's player, personal-resource, party, and raid frames.
-- Blizzard owns all unit frames. This module only discovers their real health
-- bars and owns the absorb overlays attached to those health bars.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local C_Timer = C_Timer
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
local select = select
local type = type
local string_find = string.find
local table_wipe = table.wipe

local manager = CreateFrame("Frame")

local overlays = {}
local overlaysByHealthBar = setmetatable({}, { __mode = "k" })
local healthBarCache = setmetatable({}, { __mode = "k" })
local foundHealthBars = setmetatable({}, { __mode = "k" })
local discoveryPending = false
local pendingRefresh = false

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

local function GetHealthBar(frame, forceRefresh)
    if IsForbiddenFrame(frame) then return nil end

    if not forceRefresh then
        local cached = healthBarCache[frame]
        if cached ~= nil then return cached or nil end
    end

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
        if name == "" or string_find(name, "Health", 1, true) then
            healthBar = frame
        end
    end

    healthBarCache[frame] = healthBar or false
    return healthBar
end

local function IsSupportedUnit(unit)
    if type(unit) ~= "string" then return false end
    if IsInRaid and IsInRaid() then
        return RAID_UNITS[unit] == true
    end
    return PARTY_UNITS[unit] == true
end

local function HideOverlayForHealthBar(healthBar)
    local entry = overlaysByHealthBar[healthBar]
    if not entry then return end

    if entry.unit and overlays[entry.unit] then
        overlays[entry.unit][healthBar] = nil
        if not next(overlays[entry.unit]) then
            overlays[entry.unit] = nil
        end
    end

    entry.unit = nil
    entry.overlay:Hide()
    entry.overlay.lastAbsorb = nil
    entry.overlay.lastMaxHealth = nil
    overlaysByHealthBar[healthBar] = nil
end

local function AddOverlay(unit, healthBar)
    if not unit or not healthBar then return nil end

    local entry = overlaysByHealthBar[healthBar]
    if not entry then
        entry = {
            healthBar = healthBar,
            overlay = addon.CreateAbsorbOverlay(healthBar),
        }
        overlaysByHealthBar[healthBar] = entry
    end

    if entry.unit == unit then return entry end

    if entry.unit and overlays[entry.unit] then
        overlays[entry.unit][healthBar] = nil
        if not next(overlays[entry.unit]) then
            overlays[entry.unit] = nil
        end
    end

    entry.unit = unit
    overlays[unit] = overlays[unit] or {}
    overlays[unit][healthBar] = entry
    return entry
end

local function RemoveHealthBarFromUnit(unit, healthBar)
    local entries = overlays[unit]
    if not entries then return end

    local entry = entries[healthBar]
    if not entry then return end

    entries[healthBar] = nil
    if not next(entries) then overlays[unit] = nil end

    if overlaysByHealthBar[healthBar] == entry then
        entry.unit = nil
        entry.overlay:Hide()
        entry.overlay.lastAbsorb = nil
        entry.overlay.lastMaxHealth = nil
        overlaysByHealthBar[healthBar] = nil
    end
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
end

addon.RefreshPartyFrames = TryEnsurePartyFramesVisible

local function GetPlayerFrameHealthBar()
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local healthBarArea = main and main.HealthBarArea
    return healthBarArea and GetHealthBar(healthBarArea.HealthBar or healthBarArea, true)
end

local function GetPersonalResourceHealthBar()
    local container = PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.HealthBarsContainer
    local healthBar = container and (container.healthBar or container.HealthBar)
    if IsStatusBar(healthBar) then return healthBar end

    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local nameplate = C_NamePlate.GetNamePlateForUnit("player")
    if not nameplate then return nil end

    return GetHealthBar(nameplate.UnitFrame or nameplate.unitFrame, true)
end

local function TryAddFrameOverlay(frame, forceRefresh)
    if IsForbiddenFrame(frame) then return end

    local unit = GetUnit(frame)
    local healthBar = GetHealthBar(frame, forceRefresh)

    -- A Blizzard frame can be reused for a pet, vehicle, empty slot, etc.
    -- Pets are deliberately excluded: if this health bar previously belonged
    -- to a supported party/raid unit, remove only our overlay and leave the
    -- Blizzard frame completely untouched.
    if not unit or not IsSupportedUnit(unit) then
        if healthBar then
            HideOverlayForHealthBar(healthBar)
        end
        return
    end

    if healthBar then
        AddOverlay(unit, healthBar)
        foundHealthBars[healthBar] = true
    end
end

local function HandleCompactFrame(frame)
    TryAddFrameOverlay(frame, false)
end

local function ScanCompactFrames(forceRefresh)
    -- FrameDiscovery returns Blizzard's currently active compact frames. It
    -- does not create frames or modify their units.
    ForEachCompactFrame(function(frame)
        TryAddFrameOverlay(frame, forceRefresh)
    end)
end

local function DiscoverFrames()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    TryEnsurePartyFramesVisible()

    table_wipe(foundHealthBars)
    -- A full discovery is the authoritative snapshot. Blizzard may have
    -- replaced a frame's internal health bar while changing layouts, so throw
    -- away the per-frame cache before taking that snapshot.
    healthBarCache = setmetatable({}, { __mode = "k" })

    local playerHealthBar = GetPlayerFrameHealthBar()
    if playerHealthBar then
        AddOverlay("player", playerHealthBar)
        foundHealthBars[playerHealthBar] = true
    end

    local personalResourceHealthBar = GetPersonalResourceHealthBar()
    if personalResourceHealthBar then
        AddOverlay("player", personalResourceHealthBar)
        foundHealthBars[personalResourceHealthBar] = true
    end

    ScanCompactFrames(true)

    -- Snapshot cleanup is the important lifecycle guarantee from the old
    -- implementation: anything Blizzard no longer exposes is dead to us.
    for unit, entries in pairs(overlays) do
        for healthBar, entry in pairs(entries) do
            if not foundHealthBars[healthBar] then
                entry.overlay:Hide()
                entry.unit = nil
                entries[healthBar] = nil
                overlaysByHealthBar[healthBar] = nil
            end
        end
        if not next(entries) then
            overlays[unit] = nil
        end
    end
end

local function UpdateUnit(unit, absorb, maxHealth)
    local entries = overlays[unit]
    if not entries then return end

    absorb = absorb or UnitGetTotalAbsorbs(unit) or 0
    maxHealth = maxHealth or UnitHealthMax(unit) or 1
    for _, entry in next, entries do
        addon.UpdateAbsorbOverlay(entry.overlay, absorb, maxHealth)
    end
end

local function UpdateAll()
    for unit in pairs(overlays) do
        UpdateUnit(unit)
    end
end

local function DiscoverAndUpdate()
    DiscoverFrames()
    UpdateAll()
end

local QueueDiscoverAndUpdate

local function OnDiscoveryTimer()
    discoveryPending = false
    DiscoverAndUpdate()

    if pendingRefresh and not InCombatLockdown() then
        pendingRefresh = false
        QueueDiscoverAndUpdate()
    end
end

QueueDiscoverAndUpdate = function()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    if discoveryPending then
        pendingRefresh = true
        return
    end

    discoveryPending = true
    C_Timer.After(0.05, OnDiscoveryTimer)
end

addon.RequestRefresh = QueueDiscoverAndUpdate

addon.RegisterInitializer(function()
    addon.RegisterUnitUpdateListener(function(unit, absorb, maxHealth)
        if overlays[unit] then
            UpdateUnit(unit, absorb, maxHealth)
        end
    end)
end)

addon.RegisterInitializer(function()
    addon.RegisterRegenListener(function(event)
        if event == "PLAYER_REGEN_ENABLED" then
            pendingRefresh = false
            QueueDiscoverAndUpdate()
        end
    end)
end)

if hooksecurefunc then
    local ScheduleUnitUpdate = addon.ScheduleUnitUpdate

    local function OnCompactUnitFrameUpdated(frame)
        if IsForbiddenFrame(frame) then return end

        local unit = GetUnit(frame)
        local healthBar = GetHealthBar(frame, false)

        if not unit or not IsSupportedUnit(unit) then
            -- Do not manipulate Blizzard's frame. Only remove an overlay that
            -- belongs to the actual health bar currently exposed by that frame.
            if healthBar and overlaysByHealthBar[healthBar] then
                HideOverlayForHealthBar(healthBar)
            end
            return
        end

        if not healthBar then
            if InCombatLockdown() then
                pendingRefresh = true
            end
            return
        end

        local entry = overlaysByHealthBar[healthBar]
        if entry and entry.unit == unit then
            -- Existing overlay: safe to update in combat. We do not create,
            -- reparent, show, or otherwise manipulate Blizzard's frame here.
            if ScheduleUnitUpdate then
                ScheduleUnitUpdate(unit)
            else
                UpdateUnit(unit)
            end
            return
        end

        -- A genuinely new frame/health bar appeared. Creation/attachment is
        -- deferred in combat and handled by the authoritative post-combat
        -- discovery instead of being discarded.
        if InCombatLockdown() then
            pendingRefresh = true
            return
        end

        entry = AddOverlay(unit, healthBar)
        if entry then
            if ScheduleUnitUpdate then
                ScheduleUnitUpdate(unit)
            else
                UpdateUnit(unit)
            end
        end
    end

    if _G.CompactUnitFrame_UpdateAll then
        hooksecurefunc("CompactUnitFrame_UpdateAll", OnCompactUnitFrameUpdated)
    end
    if _G.CompactUnitFrame_SetUpFrame then
        hooksecurefunc("CompactUnitFrame_SetUpFrame", OnCompactUnitFrameUpdated)
    end
    if _G.CompactUnitFrame_UpdateUnit then
        hooksecurefunc("CompactUnitFrame_UpdateUnit", OnCompactUnitFrameUpdated)
    end
end

local editModeExitPending = false
local function OnEditModeExit()
    if editModeExitPending then return end
    editModeExitPending = true
    C_Timer.After(0.2, function()
        editModeExitPending = false
        QueueDiscoverAndUpdate()
    end)
end

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit, addon)
end

if EditModeManagerFrame and EditModeManagerFrame.HookScript then
    EditModeManagerFrame:HookScript("OnHide", OnEditModeExit)
end

manager:RegisterEvent("PLAYER_LOGIN")
manager:RegisterEvent("PLAYER_ENTERING_WORLD")
manager:RegisterEvent("GROUP_ROSTER_UPDATE")
manager:RegisterEvent("PLAYER_REGEN_ENABLED")
manager:RegisterEvent("NAME_PLATE_UNIT_ADDED")
manager:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
manager:RegisterEvent("UI_SCALE_CHANGED")
manager:RegisterEvent("DISPLAY_SIZE_CHANGED")
manager:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

manager:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        QueueDiscoverAndUpdate()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- A dungeon/instance transition can rebuild Blizzard's compact frames
        -- without a roster change. Reset only our overlay ownership; Blizzard
        -- continues to own and create all unit frames.
        for _, entries in pairs(overlays) do
            for _, entry in pairs(entries) do
                entry.overlay:Hide()
                entry.overlay.lastAbsorb = nil
                entry.overlay.lastMaxHealth = nil
                entry.unit = nil
            end
        end
        overlays = {}
        overlaysByHealthBar = setmetatable({}, { __mode = "k" })
        healthBarCache = setmetatable({}, { __mode = "k" })
        table_wipe(foundHealthBars)
        pendingRefresh = false
        discoveryPending = false
        QueueDiscoverAndUpdate()
        return
    end

    -- Unit frames themselves are Blizzard-owned. Nameplate events are relevant
    -- only to the player's personal-resource path, so they don't trigger a
    -- party/raid discovery storm for every nameplate in the world.
    if event == "NAME_PLATE_UNIT_REMOVED" then
        if unit and UnitIsUnit(unit, "player") then
            QueueDiscoverAndUpdate()
        end
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        if unit and UnitIsUnit(unit, "player") then
            QueueDiscoverAndUpdate()
        end
        return
    end

    QueueDiscoverAndUpdate()
end)
