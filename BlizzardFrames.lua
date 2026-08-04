-- Absorb overlays for Blizzard's player, personal-resource, party, and raid frames.
-- Frames are discovered out of combat; combat updates only change overlay values.
-- # Module: Frame discovery and overlay attachment.
-- # This file owns the logic that finds Blizzard unit frames and attaches absorb overlays.

local addon = _G.BloodShieldOverlay
local manager = CreateFrame("Frame")
-- A unit can have more than one visible health bar.  In particular, the player
-- can have both PlayerFrame and the Personal Resource Display enabled.
local overlays = {}
local overlaysByHealthBar = setmetatable({}, { __mode = "k" })
local discoveryPending = false
local lastDiscoveryTime = 0
local pendingRefresh = false

local HEALTH_BAR_KEYS = { "healthBar", "HealthBar", "health", "Health" }
local FRAME_SCAN_LIMIT = 200
local DISCOVERY_COOLDOWN = 0.25

local function IsStatusBar(frame)
    return frame and frame.GetObjectType and frame:GetObjectType() == "StatusBar"
end

local function GetFrameName(frame)
    local ok, name = pcall(frame.GetName, frame)
    if ok and type(name) == "string" then
        return name
    end
    return ""
end

-- Traverses a frame and its descendants to find the first health status bar.
-- # DEV: This is intentionally recursive to support nested Blizzard frame layouts.
local function GetHealthBar(frame)
    if not frame then
        return
    end

    for _, key in ipairs(HEALTH_BAR_KEYS) do
        local healthBar = frame[key]
        if IsStatusBar(healthBar) then
            return healthBar
        end
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            local healthBar = GetHealthBar(child)
            if healthBar then
                return healthBar
            end
        end
    end

    if IsStatusBar(frame) then
        local name = GetFrameName(frame)
        if name == "" then
            return frame
        end
        if name:find("Health") then
            return frame
        end
    end
end

-- Attempts to resolve a frame's unit token.
-- # DEV: This uses both explicit unit fields and name-based Blizzard heuristics.
local function GetUnit(frame)
    if type(frame.unit) == "string" then
        return frame.unit
    end

    local name = GetFrameName(frame)
    if name == "" then
        return
    end

    if not (name:find("PlayerFrame") or name:find("Party") or name:find("Raid") or name:find("Unit") or name:find("NamePlate")) then
        return
    end

    if not frame.GetAttribute then
        return
    end

    local ok, unit = pcall(frame.GetAttribute, frame, "unit")
    if ok and type(unit) == "string" then
        return unit
    end
end

local function IsSupportedUnit(unit)
    local inRaid = IsInRaid and IsInRaid()
    
    if inRaid then
        -- En Raid ignoramos los marcos de party para evitar duplicados
        return unit == "player" or unit:match("^raid%d+$")
    else
        -- Estando solo o en party, aceptamos player y party
        return unit == "player" or unit:match("^party%d+$")
    end
end

local function AddOverlay(unit, healthBar)
    local entry = overlaysByHealthBar[healthBar]
    if not entry then
        entry = {
            healthBar = healthBar,
            overlay = addon.CreateAbsorbOverlay(healthBar),
        }
        overlaysByHealthBar[healthBar] = entry
    end

    if entry.unit == unit then
        return
    end

    if entry.unit and overlays[entry.unit] then
        overlays[entry.unit][healthBar] = nil
    end

    entry.unit = unit
    overlays[unit] = overlays[unit] or {}
    overlays[unit][healthBar] = entry
end

-- Ensures party-related native Blizzard frames are visible and updated.
-- # DEV: This is separate from overlay creation so refresh logic can stay isolated.
local function TryEnsurePartyFramesVisible()
    local inRaid = IsInRaid and IsInRaid()
    local inGroup = IsInGroup and IsInGroup()

    -- 1. Si estamos en RAID: Ocultamos marcos de party para que solo salga la Raid
    if inRaid then
        if PartyFrame and PartyFrame.Hide then PartyFrame:Hide() end
        if CompactPartyFrame and CompactPartyFrame.Hide then CompactPartyFrame:Hide() end
        return
    end

    local function EnsureFrameShown(frame)
        if not frame then return end
        if frame.Show then frame:Show() end
    end

    -- 2. Si estamos en PARTY o SOLOS: Mostramos el marco de party
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
        -- Si no estamos en grupo (estamos solos), forzamos "player" en party1
        -- Si ESTAMOS en grupo, respetamos la unidad asignada por el juego
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

-- Expose the party refresh helper so the main addon can invoke it without owning
-- the party-frame discovery logic itself.
addon.RefreshPartyFrames = TryEnsurePartyFramesVisible

-- # DEV: The main addon should not need to know the details of unit frame discovery.
local function GetPlayerFrameHealthBar()
    -- The modern PlayerFrame does not expose its health bar directly.  It is
    -- nested inside the new content frame, so the generic frame scan cannot
    -- reliably discover it.
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local healthBarArea = main and main.HealthBarArea
    return healthBarArea and GetHealthBar(healthBarArea.HealthBar or healthBarArea)
end

local function GetPersonalResourceHealthBar()
    -- Retail's Personal Resource Display has its own top-level frame.  This
    -- explicit path works even when the player nameplate is not enumerable.
    local container = PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.HealthBarsContainer
    local healthBar = container and (container.healthBar or container.HealthBar)
    if IsStatusBar(healthBar) then
        return healthBar
    end

    -- Older UI layouts expose the same display as the player's nameplate.
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit("player")
    if not nameplate then
        return
    end

    -- Blizzard uses UnitFrame on current Retail builds.  unitFrame is kept as
    -- a fallback for older frame implementations and third-party nameplates.
    return GetHealthBar(nameplate.UnitFrame or nameplate.unitFrame)
end

local function TryAddFrameOverlay(frame, foundHealthBars)
    if not frame then
        return
    end

    local unit = GetUnit(frame)
    if unit and IsSupportedUnit(unit) then
        local healthBar = GetHealthBar(frame)
        if healthBar then
            AddOverlay(unit, healthBar)
            foundHealthBars[healthBar] = true
        end
    end
end

local function ScanCompactFrames(foundHealthBars)
    for _, prefix in ipairs({ "CompactPartyFrame", "CompactRaidFrame" }) do
        for index = 1, 40 do
            local frame = _G[prefix .. index]
            if not frame then
                break
            end

            TryAddFrameOverlay(frame, foundHealthBars)

            local children = { frame:GetChildren() }
            for _, child in ipairs(children) do
                TryAddFrameOverlay(child, foundHealthBars)
            end
        end
    end
end

local function DiscoverFrames()
    if InCombatLockdown() then
        return
    end

    TryEnsurePartyFramesVisible()

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

    ScanCompactFrames(foundHealthBars)

    local frame
    local scannedFrames = 0
    while true do
        frame = EnumerateFrames(frame)
        if not frame then
            break
        end

        scannedFrames = scannedFrames + 1
        if scannedFrames > FRAME_SCAN_LIMIT then
            break
        end

        TryAddFrameOverlay(frame, foundHealthBars)
    end

    for unit, entries in pairs(overlays) do
        for healthBar, entry in pairs(entries) do
            if not foundHealthBars[healthBar] then
                entry.overlay:Hide()
                entry.unit = nil
                entries[healthBar] = nil
            end
        end
        if not next(entries) then
            overlays[unit] = nil
        end
    end
end

local function UpdateUnit(unit, absorb, maxHealth)
    local entries = overlays[unit]
    if not entries then
        return
    end

    absorb = absorb or UnitGetTotalAbsorbs(unit)
    maxHealth = maxHealth or UnitHealthMax(unit)
    for _, entry in pairs(entries) do
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

-- Several UI events can arrive together (for example while entering the
-- world).  Coalescing them avoids repeatedly enumerating every UI frame.
local function QueueDiscoverAndUpdate()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    if discoveryPending then
        return
    end

    local now = GetTime()
    if not pendingRefresh and now - lastDiscoveryTime < DISCOVERY_COOLDOWN then
        return
    end

    pendingRefresh = false
    lastDiscoveryTime = now
    discoveryPending = true
    C_Timer.After(0.35, function()
        discoveryPending = false
        pendingRefresh = false
        DiscoverAndUpdate()
    end)
end

-- Requests a full refresh of party/raid frame discovery and overlay updates.
-- This is used both by the main addon events and by the /shield party command.
addon.RequestRefresh = function()
    TryEnsurePartyFramesVisible()
    if QueueDiscoverAndUpdate then
        QueueDiscoverAndUpdate()
    end
end

addon.RegisterPlayerUpdateListener(function(absorb, maxHealth)
    UpdateUnit("player", absorb, maxHealth)
end)

manager:RegisterEvent("PLAYER_LOGIN")
manager:RegisterEvent("PLAYER_ENTERING_WORLD")
manager:RegisterEvent("GROUP_ROSTER_UPDATE")
manager:RegisterEvent("PLAYER_REGEN_ENABLED")
manager:RegisterEvent("PLAYER_REGEN_DISABLED")
manager:RegisterEvent("NAME_PLATE_UNIT_ADDED")
manager:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
manager:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
manager:RegisterEvent("UNIT_HEALTH")
manager:RegisterEvent("UNIT_MAXHEALTH")
manager:RegisterEvent("UI_SCALE_CHANGED")
manager:RegisterEvent("DISPLAY_SIZE_CHANGED")
manager:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if unit and unit ~= "player" and overlays[unit] then
            UpdateUnit(unit)
        end
        return
    end

    -- Only the player's nameplate can affect the Personal Resource Display.
    -- Ignoring other units prevents a full frame scan when enemies appear.
    if (event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED")
        and (not unit or not UnitIsUnit(unit, "player")) then
        return
    end

    TryEnsurePartyFramesVisible()
    QueueDiscoverAndUpdate()
end)
