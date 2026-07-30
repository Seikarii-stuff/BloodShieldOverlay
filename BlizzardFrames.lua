-- Experimental absorb overlays for Blizzard's player, party, and raid frames.
-- Frames are discovered out of combat; combat updates only change overlay values.

local addon = _G.BloodShieldOverlay
local manager = CreateFrame("Frame")
local overlays = {}
local overlaysByHealthBar = setmetatable({}, { __mode = "k" })

local HEALTH_BAR_KEYS = { "healthBar", "HealthBar", "health", "Health" }

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

local function GetHealthBar(frame)
    for _, key in ipairs(HEALTH_BAR_KEYS) do
        local healthBar = frame[key]
        if IsStatusBar(healthBar) then
            return healthBar
        end
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        if IsStatusBar(child) then
            local name = GetFrameName(child)
            if name:find("Health") then
                return child
            end
        end
    end
end

local function GetUnit(frame)
    if type(frame.unit) == "string" then
        return frame.unit
    end

    local ok, unit = pcall(frame.GetAttribute, frame, "unit")
    if ok and type(unit) == "string" then
        return unit
    end
end

local function IsSupportedUnit(unit)
    return unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$")
end

local function AddOverlay(unit, healthBar)
    local currentEntry = overlays[unit]
    if currentEntry and currentEntry.healthBar == healthBar then
        return
    end

    if currentEntry then
        currentEntry.overlay:Hide()
        currentEntry.unit = nil
        overlays[unit] = nil
    end

    local entry = overlaysByHealthBar[healthBar]
    if not entry then
        entry = {
            healthBar = healthBar,
            overlay = addon.CreateAbsorbOverlay(healthBar),
        }
        overlaysByHealthBar[healthBar] = entry
    elseif entry.unit then
        entry.overlay:Hide()
        overlays[entry.unit] = nil
    end

    entry.unit = unit
    overlays[unit] = entry
end

local function DiscoverFrames()
    if InCombatLockdown() then
        return
    end

    local foundUnits = {}
    local playerHealthBar = PlayerFrame and GetHealthBar(PlayerFrame)
    if playerHealthBar then
        AddOverlay("player", playerHealthBar)
        foundUnits.player = true
    end

    local frame
    while true do
        frame = EnumerateFrames(frame)
        if not frame then
            break
        end

        local unit = GetUnit(frame)
        if unit and IsSupportedUnit(unit) then
            local healthBar = GetHealthBar(frame)
            if healthBar then
                AddOverlay(unit, healthBar)
                foundUnits[unit] = true
            end
        end
    end

    for unit, entry in pairs(overlays) do
        if not foundUnits[unit] then
            entry.overlay:Hide()
            entry.unit = nil
            overlays[unit] = nil
        end
    end
end

local function UpdateUnit(unit, absorb, maxHealth)
    local entry = overlays[unit]
    if not entry then
        return
    end

    addon.UpdateAbsorbOverlay(entry.overlay, absorb or UnitGetTotalAbsorbs(unit), maxHealth or UnitHealthMax(unit))
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

addon.RegisterPlayerUpdateListener(function(absorb, maxHealth)
    UpdateUnit("player", absorb, maxHealth)
end)

manager:RegisterEvent("PLAYER_LOGIN")
manager:RegisterEvent("PLAYER_ENTERING_WORLD")
manager:RegisterEvent("GROUP_ROSTER_UPDATE")
manager:RegisterEvent("PLAYER_REGEN_ENABLED")
manager:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
manager:RegisterEvent("UNIT_HEALTH")
manager:RegisterEvent("UNIT_MAXHEALTH")
manager:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if unit and unit ~= "player" and overlays[unit] then
            UpdateUnit(unit)
        end
        return
    end

    C_Timer.After(0.2, DiscoverAndUpdate)
end)
