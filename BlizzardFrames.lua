-- Absorb overlays for Blizzard's player, personal-resource, party, and raid frames.
-- Frames are discovered out of combat; combat updates only change overlay values.

local addon = _G.BloodShieldOverlay
local manager = CreateFrame("Frame")
-- A unit can have more than one visible health bar.  In particular, the player
-- can have both PlayerFrame and the Personal Resource Display enabled.
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
    if not frame then
        return
    end

    if IsStatusBar(frame) then
        return frame
    end

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

local function DiscoverFrames()
    if InCombatLockdown() then
        return
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
                foundHealthBars[healthBar] = true
            end
        end
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

addon.RegisterPlayerUpdateListener(function(absorb, maxHealth)
    UpdateUnit("player", absorb, maxHealth)
end)

manager:RegisterEvent("PLAYER_LOGIN")
manager:RegisterEvent("PLAYER_ENTERING_WORLD")
manager:RegisterEvent("GROUP_ROSTER_UPDATE")
manager:RegisterEvent("PLAYER_REGEN_ENABLED")
manager:RegisterEvent("NAME_PLATE_UNIT_ADDED")
manager:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
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
