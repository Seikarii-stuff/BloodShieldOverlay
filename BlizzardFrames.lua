-- Absorb overlays for Blizzard's player, personal-resource, party, and raid frames.
--
-- Discovery is deliberately Blizzard-authoritative but bounded.  We do not
-- recursively walk the compact-frame hierarchy: that was the source of the
-- roster-size hitch this module originally had.  Instead we reconcile the
-- real compact frames exposed by FrameDiscovery and repair Blizzard's frame
-- reuse lifecycle when SetUpFrame/UpdateUnit changes a frame underneath us.

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
local type = type
local string_find = string.find
local manager = CreateFrame("Frame")

local overlays = {}
local overlaysByHealthBar = setmetatable({}, { __mode = "k" })

-- Blizzard can reuse a CompactUnitFrame and replace its internal health bar.
-- This cache is intentionally weak, but it must also be explicitly invalidated
-- at lifecycle boundaries; weak keys do not help while Blizzard keeps the frame.
local healthBarCache = setmetatable({}, { __mode = "k" })
local frameHealthBar = setmetatable({}, { __mode = "k" })
local frameUnit = setmetatable({}, { __mode = "k" })

local discoveryPending = false
local pendingRefresh = false
local rosterRefreshPending = false
local editModeExitPending = false

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

local function InRaid()
    return IsInRaid and IsInRaid() or false
end

local function IsSupportedUnit(unit)
    if type(unit) ~= "string" then return false end
    if InRaid() then return RAID_UNITS[unit] == true end
    return PARTY_UNITS[unit] == true
end

local function InvalidateHealthBar(frame)
    if frame then healthBarCache[frame] = nil end
end

local function GetHealthBar(frame)
    if not frame or IsForbiddenFrame(frame) then return nil end

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
        if name == "" or string_find(name, "Health", 1, true) then
            healthBar = frame
        end
    end

    healthBarCache[frame] = healthBar or false
    return healthBar
end

local function RemoveOverlay(unit, healthBar)
    if not healthBar then return end

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

local function DetachFrame(frame)
    local oldBar = frameHealthBar[frame]
    if oldBar then RemoveOverlay(frameUnit[frame], oldBar) end
    frameHealthBar[frame] = nil
    frameUnit[frame] = nil
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

local function BindFrame(frame, unit, healthBar)
    local oldUnit = frameUnit[frame]
    local oldBar = frameHealthBar[frame]

    if oldUnit == unit and oldBar == healthBar then
        return AddOverlay(unit, healthBar)
    end

    if oldBar and oldBar ~= healthBar then
        RemoveOverlay(oldUnit, oldBar)
    elseif oldBar and oldUnit ~= unit then
        RemoveOverlay(oldUnit, oldBar)
    end

    frameUnit[frame] = unit
    frameHealthBar[frame] = healthBar
    return AddOverlay(unit, healthBar)
end

local function TryAddFrameOverlay(frame, forceHealthBarRefresh)
    if not frame or IsForbiddenFrame(frame) then return end

    if forceHealthBarRefresh then
        InvalidateHealthBar(frame)
    end

    local unit = GetUnit(frame)
    local healthBar = GetHealthBar(frame)

    if not unit or not IsSupportedUnit(unit) or not healthBar then
        if frameHealthBar[frame] then
            DetachFrame(frame)
        end
        return
    end

    BindFrame(frame, unit, healthBar)
end

local function ScanCompactFrames(forceHealthBarRefresh)
    -- This is intentionally bounded by FrameDiscovery's active-frame list.
    -- For a 40-man raid this is at most the real raid frames, not a recursive
    -- walk through every child of Blizzard's containers.
    ForEachCompactFrame(function(frame)
        TryAddFrameOverlay(frame, forceHealthBarRefresh)
    end)
end

local function GetPlayerFrameHealthBar()
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local healthBarArea = main and main.HealthBarArea
    local frame = healthBarArea and (healthBarArea.HealthBar or healthBarArea)
    return frame and GetHealthBar(frame)
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

local function TryEnsurePartyFramesVisible()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    local inRaid = InRaid()
    local inGroup = IsInGroup and IsInGroup() or false

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

-- ShowPartyWhenSolo also owns this entry point.  Keeping the small compatibility
-- hook here means BlizzardFrames remains usable by itself and does not depend on
-- initialization order, while the actual solo policy stays in its own module.
addon.RefreshPartyFrames = addon.RefreshPartyFrames or TryEnsurePartyFramesVisible

local function FullReconcile(forceHealthBarRefresh)
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    TryEnsurePartyFramesVisible()

    -- A full roster/layout reconciliation is the one place where we deliberately
    -- throw away the frame->healthbar cache.  This catches Blizzard replacing a
    -- healthbar without making UNIT_* events expensive.
    if forceHealthBarRefresh then
        healthBarCache = setmetatable({}, { __mode = "k" })
    end

    local foundHealthBars = setmetatable({}, { __mode = "k" })

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

    ScanCompactFrames(forceHealthBarRefresh)

    -- Snapshot cleanup is bounded by overlays we actually own.  It prevents a
    -- reused frame from leaving the old unit's absorb overlay behind.
    for unit, entries in pairs(overlays) do
        for healthBar, entry in pairs(entries) do
            if not foundHealthBars[healthBar] then
                entry.overlay:Hide()
                entry.overlay.lastAbsorb = nil
                entry.overlay.lastMaxHealth = nil
                entry.unit = nil
                entries[healthBar] = nil
                overlaysByHealthBar[healthBar] = nil
            end
        end
        if not next(entries) then overlays[unit] = nil end
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

local function DiscoverAndUpdate(forceHealthBarRefresh)
    FullReconcile(forceHealthBarRefresh)
    UpdateAll()
end

local function OnDiscoveryTimer()
    discoveryPending = false

    local forceHealthBarRefresh = rosterRefreshPending
    rosterRefreshPending = false
    DiscoverAndUpdate(forceHealthBarRefresh)

    if pendingRefresh then
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
        if not frame or InCombatLockdown() or IsForbiddenFrame(frame) then return end

        -- SetUpFrame/UpdateUnit are precisely the lifecycle points where
        -- Blizzard can retarget a recycled frame or install a new healthbar.
        -- Resolve it fresh here; never trust a stale negative cache entry.
        InvalidateHealthBar(frame)
        TryAddFrameOverlay(frame, false)

        local unit = frameUnit[frame]
        if unit then
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

local function OnEditModeExit()
    if editModeExitPending then return end
    editModeExitPending = true

    C_Timer.After(0.2, function()
        editModeExitPending = false
        TryEnsurePartyFramesVisible()
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

    if event == "GROUP_ROSTER_UPDATE" then
        -- The only roster-specific cost is one bounded pass over the real
        -- compact frames.  We force cache invalidation here because a newly
        -- joined 21st/39th player is exactly where Blizzard tends to recycle
        -- compact frames.  No recursive container scan is performed.
        rosterRefreshPending = true
        QueueDiscoverAndUpdate()
        return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        if unit then
            local nameplate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
            if nameplate then
                local frame = nameplate.UnitFrame or nameplate.unitFrame or nameplate
                InvalidateHealthBar(frame)
                local bar = GetHealthBar(frame)
                if bar then RemoveOverlay(unit, bar) end
            end
        end
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" and (not unit or not UnitIsUnit(unit, "player")) then
        return
    end

    QueueDiscoverAndUpdate()
end)
