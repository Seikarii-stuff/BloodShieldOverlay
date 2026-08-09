-- Standalone player absorption, health, resource bars, and configuration UI.
-- Public slash commands and SavedVariables remain owned by BloodShieldOverlay.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local bar
local healthBar
local resourceBar
local menuFrame
local tickLines = {}

local TICK_FRACTIONS = { 0.5, 1.0, 1.5 }
local MIN_CAP_PERCENT = 20
local RESOURCE_BAR_WIDTH = 8
local MAX_SPECIAL_CIRCLES = 7
local SPECIAL_CIRCLE_SIZE = 12

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local profileKey

local DEFAULTS = {
    configVersion = 2,
    point = "BOTTOM",
    relativePoint = "BOTTOM",
    xOffset = 100,
    yOffset = 450,
    width = 18,
    height = 150,
    locked = true,
    hideExternalBar = false,
    capMultiplier = 2.0,
    showHealth = true,
    showSpecialResources = true,
    resourceDisplay = "left", -- "left", "right", "none"
}

local RESOURCE_DISPLAY_MODES = { left = true, right = true, none = true }

local config = {}

local function BuildProfileKey()
    local playerName = UnitName("player") or "Player"
    local realmName = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName and GetRealmName() or "Unknown"
    return string.format("%s-%s", playerName, realmName)
end

local function GetProfileKey()
    if not profileKey then
        profileKey = BuildProfileKey()
    end
    return profileKey
end

local function EnsureProfileStore()
    if type(BloodShieldOverlayProfiles) ~= "table" then
        BloodShieldOverlayProfiles = {}
    end
    return BloodShieldOverlayProfiles
end

local function ApplyDefaults(db)
    db = db or {}
    local isLegacyProfile = db.configVersion == nil and db.showHealth == false
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end

    -- The previous release defaulted this option to false. Migrate that
    -- implicit legacy value once, while preserving an explicit choice made
    -- after this version.
    if isLegacyProfile then
        db.showHealth = true
    end

    if type(db.width) ~= "number" or db.width <= 0 then
        db.width = DEFAULTS.width
    end
    if type(db.height) ~= "number" or db.height <= 0 then
        db.height = DEFAULTS.height
    end
    if type(db.capMultiplier) ~= "number" or db.capMultiplier < MIN_CAP_PERCENT / 100 then
        db.capMultiplier = DEFAULTS.capMultiplier
    end
    if type(db.hideExternalBar) ~= "boolean" then
        db.hideExternalBar = DEFAULTS.hideExternalBar
    end
    if type(db.showHealth) ~= "boolean" then
        db.showHealth = DEFAULTS.showHealth
    end
    if type(db.showSpecialResources) ~= "boolean" then
        db.showSpecialResources = DEFAULTS.showSpecialResources
    end
    if type(db.resourceDisplay) ~= "string" or not RESOURCE_DISPLAY_MODES[db.resourceDisplay] then
        db.resourceDisplay = DEFAULTS.resourceDisplay
    end

    return db
end

local function CopySettings(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            copy[key] = value
        end
    end
    return copy
end

local function EnsureConfig()
    local profiles = EnsureProfileStore()
    local profileKey = GetProfileKey()

    if not profiles[profileKey] then
        if type(BloodShieldOverlayDB) == "table" and next(BloodShieldOverlayDB) ~= nil then
            profiles[profileKey] = CopySettings(BloodShieldOverlayDB)
        else
            profiles[profileKey] = {}
        end
    end

    config = ApplyDefaults(profiles[profileKey])
    profiles[profileKey] = config
    BloodShieldOverlayProfiles = profiles
end

local function ResetConfig()
    local profiles = EnsureProfileStore()
    local profileKey = GetProfileKey()

    config = {}
    for key, value in pairs(DEFAULTS) do
        config[key] = value
    end

    profiles[profileKey] = config
    BloodShieldOverlayProfiles = profiles
end

local function GetAbsorbAmount(unit)
    if UnitGetTotalAbsorbs then
        return UnitGetTotalAbsorbs(unit) or 0
    end
    return 0
end

local function SaveBarPosition()
    if not bar then return end
    local point, _, relativePoint, xOffset, yOffset = bar:GetPoint()
    if type(point) ~= "string" or type(relativePoint) ~= "string"
        or type(xOffset) ~= "number" or type(yOffset) ~= "number" then
        return
    end
    config.point = point
    config.relativePoint = relativePoint
    config.xOffset = xOffset
    config.yOffset = yOffset
end

local function UpdateBarLock()
    if not bar then return end
    bar:EnableMouse(not config.locked)
    bar:SetMovable(not config.locked)
    if config.locked then
        bar:SetScript("OnDragStart", nil)
        bar:SetScript("OnDragStop", nil)
    else
        bar:RegisterForDrag("LeftButton")
        bar:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        bar:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            SaveBarPosition()
        end)
    end
end

local function UpdateTickMarks()
    if not bar then return end

    local capMultiplier = config.capMultiplier or DEFAULTS.capMultiplier
    local totalHeight = bar:GetHeight()

    for _, fraction in ipairs(TICK_FRACTIONS) do
        local tick = tickLines[fraction]

        if fraction <= capMultiplier then
            local yOffset = totalHeight * (fraction / capMultiplier)

            tick:ClearAllPoints()
            tick:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, yOffset - 1)
            tick:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, yOffset - 1)
            tick:Show()
        else
            tick:Hide()
        end
    end
end

local function CreateTickMarks()
    for _, fraction in ipairs(TICK_FRACTIONS) do
        local tick = bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(1, 1, 1, 0.85)
        tick:SetHeight(2)
        tickLines[fraction] = tick
    end
    UpdateTickMarks()
end

local function UpdateResourceBarLayout()
    if not resourceBar or not bar then return end
    resourceBar:ClearAllPoints()
    local mode = config.resourceDisplay or DEFAULTS.resourceDisplay

    if mode == "left" then
        resourceBar:SetPoint("TOPRIGHT", bar, "TOPLEFT", -2, 0)
        resourceBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -2, 0)
        resourceBar:SetWidth(RESOURCE_BAR_WIDTH)
        resourceBar:Show()
    elseif mode == "right" then
        resourceBar:SetPoint("TOPLEFT", bar, "TOPRIGHT", 2, 0)
        resourceBar:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 2, 0)
        resourceBar:SetWidth(RESOURCE_BAR_WIDTH)
        resourceBar:Show()
    else
        resourceBar:Hide()
    end
end

local specialResourceContainer
local specialCircles = {}
local specialProgress = {}
local specialOrder = {}

for index = 1, MAX_SPECIAL_CIRCLES do
    specialProgress[index] = 0
    specialOrder[index] = index
end

-- White while charging/empty; snaps to gold the instant a pip is ready/full.
-- This is the only state that changes per pip; slot identity never does.
local CHARGING_COLOR = { 1, 1, 1 }
local READY_COLOR = { 1, 0.82, 0 }

local function CreatePowerResourceProvider(powerType, powerToken)
    return {
        token = powerToken,
        GetMax = function()
            return UnitPowerMax("player", powerType) or 0
        end,
        Update = function()
            local currentPower = UnitPower("player", powerType) or 0
            local maxPower = math.min(UnitPowerMax("player", powerType) or 0, MAX_SPECIAL_CIRCLES)

            for index = 1, maxPower do
                local circle = specialCircles[index]
                circle:SetMinMaxValues(0, 1)
                if index <= currentPower then
                    specialProgress[index] = 1
                    circle:SetValue(1)
                    circle:SetStatusBarColor(READY_COLOR[1], READY_COLOR[2], READY_COLOR[3], 1)
                else
                    circle:SetValue(0)
                    circle:SetStatusBarColor(CHARGING_COLOR[1], CHARGING_COLOR[2], CHARGING_COLOR[3], 1)
                end
            end

            return maxPower
        end,
    }
end

local ResourceProviders = {
    DEATHKNIGHT = {
        GetMax = function() return 6 end,
        Update = function()
            local now = GetTime()
            for index = 1, 6 do
                local start, duration, ready = GetRuneCooldown(index)
                local circle = specialCircles[index]
                circle:SetMinMaxValues(0, 1)
                if ready then
                    specialProgress[index] = 1
                    circle:SetValue(1)
                    circle:SetStatusBarColor(READY_COLOR[1], READY_COLOR[2], READY_COLOR[3], 1)
                elseif start and duration and duration > 0 then
                    local progress = (now - start) / duration
                    if progress < 0 then progress = 0 end
                    if progress > 1 then progress = 1 end
                    specialProgress[index] = progress
                    circle:SetMinMaxValues(0, duration)
                    circle:SetValue(now - start)
                    circle:SetStatusBarColor(CHARGING_COLOR[1], CHARGING_COLOR[2], CHARGING_COLOR[3], 1)
                else
                    circle:SetValue(0)
                    circle:SetStatusBarColor(CHARGING_COLOR[1], CHARGING_COLOR[2], CHARGING_COLOR[3], 1)
                end
            end

            return 6
        end,
    },
}

if powerTypes then
    ResourceProviders.PALADIN = CreatePowerResourceProvider(powerTypes.HolyPower, "HOLY_POWER")
    ResourceProviders.EVOKER = CreatePowerResourceProvider(powerTypes.Essence, "ESSENCE")
    ResourceProviders.WARLOCK = CreatePowerResourceProvider(powerTypes.SoulShards, "SOUL_SHARDS")
    ResourceProviders.MONK = CreatePowerResourceProvider(powerTypes.Chi, "CHI")
    ResourceProviders.ROGUE = CreatePowerResourceProvider(powerTypes.ComboPoints, "COMBO_POINTS")
    ResourceProviders.DRUID = CreatePowerResourceProvider(powerTypes.ComboPoints, "COMBO_POINTS")
end

local specialResourceProvider = ResourceProviders[playerClass]
local SPECIAL_POWER_TOKEN = specialResourceProvider and specialResourceProvider.token

local function CreateSpecialResources()
    if specialResourceContainer or not bar then return end

    specialResourceContainer = CreateFrame("Frame", nil, resourceBar)
    specialResourceContainer:SetAllPoints(resourceBar)

    for index = 1, MAX_SPECIAL_CIRCLES do
        local circle = CreateFrame("StatusBar", nil, specialResourceContainer)
        circle:SetFrameLevel(resourceBar:GetFrameLevel() + 1)
        circle:SetStatusBarTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
        circle:SetStatusBarColor(1, 1, 1, 1)
        circle:SetOrientation("VERTICAL")

        local background = circle:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(circle)
        background:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
        background:SetVertexColor(0.15, 0.15, 0.15, 0.6)

        circle:EnableMouse(false)
        circle:Hide()
        specialCircles[index] = circle
    end
end

local function UpdateSpecialResourcesLayout()
    if not specialResourceContainer then return end

    if not config.showSpecialResources or config.hideExternalBar
        or config.resourceDisplay == "none" then
        specialResourceContainer:Hide()
        return
    end

    local maxPower = specialResourceProvider and specialResourceProvider.GetMax() or 0
    maxPower = math.min(maxPower, MAX_SPECIAL_CIRCLES)

    if maxPower <= 0 then
        specialResourceContainer:Hide()
        return
    end

    -- SetAllPoints can report zero before the parent has completed its first
    -- layout pass. Read the actual resource bar dimensions as the authority.
    local parentWidth = resourceBar:GetWidth()
    local parentHeight = resourceBar:GetHeight()
    local slotSize = math.min(SPECIAL_CIRCLE_SIZE, math.floor(parentHeight / maxPower))
    if slotSize < 3 then slotSize = 3 end
    local circleWidth = math.max(2, parentWidth - 2)

    specialResourceContainer:Show()
    for index = 1, MAX_SPECIAL_CIRCLES do
        local circle = specialCircles[specialOrder[index]]
        if index <= maxPower then
            circle:SetSize(circleWidth, math.max(1, slotSize - 2))
            circle:ClearAllPoints()
            circle:SetPoint("TOPLEFT", resourceBar, "TOPLEFT", 1,
                -((index - 1) * slotSize + 1))
            circle:Show()
        else
            circle:Hide()
        end
    end
end

local function SortSpecialResources(count)
    -- The collection has at most seven entries. Stable insertion sort keeps
    -- ready runes at the top without table.sort or a comparator closure.
    for position = 2, count do
        local candidate = specialOrder[position]
        local candidateProgress = specialProgress[candidate]
        local insertAt = position - 1

        while insertAt >= 1
            and specialProgress[specialOrder[insertAt]] < candidateProgress do
            specialOrder[insertAt + 1] = specialOrder[insertAt]
            insertAt = insertAt - 1
        end
        specialOrder[insertAt + 1] = candidate
    end
end

local function UpdateSpecialResources()
    if not specialResourceContainer or not specialResourceContainer:IsShown() then return end

    for index = 1, MAX_SPECIAL_CIRCLES do
        specialProgress[index] = 0
    end

    if specialResourceProvider then
        local count = specialResourceProvider.Update()
        SortSpecialResources(count)
    end

    UpdateSpecialResourcesLayout()
end

addon.UpdateSpecialResourcesLayout = UpdateSpecialResourcesLayout
addon.UpdateSpecialResources = UpdateSpecialResources

local function CreateBar()
    if bar then return end

    bar = CreateFrame("StatusBar", "BloodShieldOverlayBar", UIParent)
    bar:SetSize(config.width or DEFAULTS.width, config.height or DEFAULTS.height)
    bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(1.0, 1.0, 1.0, 1.0)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(1)
    bar:SetOrientation("VERTICAL")
    bar:SetReverseFill(false)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.4)

    -- Barra de Salud (Roja)
    healthBar = CreateFrame("StatusBar", nil, bar)
    healthBar:SetAllPoints(bar)
    healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healthBar:SetStatusBarColor(0.85, 0.15, 0.15, 0.85)
    healthBar:SetOrientation("VERTICAL")
    healthBar:SetReverseFill(false)
    healthBar:SetFrameLevel(bar:GetFrameLevel())

    -- Barra de Recursos Personales (Azul, Vertical, Ancho 8)
    resourceBar = CreateFrame("StatusBar", nil, bar)
    resourceBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    resourceBar:SetStatusBarColor(0.0, 0.5, 1.0, 0.9) -- Azul
    resourceBar:SetOrientation("VERTICAL")
    resourceBar:SetReverseFill(false)
    resourceBar:SetFrameLevel(bar:GetFrameLevel())

    local rBg = resourceBar:CreateTexture(nil, "BACKGROUND")
    rBg:SetAllPoints(resourceBar)
    rBg:SetColorTexture(0, 0, 0, 0.5)

    UpdateResourceBarLayout()
    CreateSpecialResources()
    UpdateSpecialResourcesLayout()

    bar:SetScript("OnSizeChanged", function()
        UpdateTickMarks()
        UpdateResourceBarLayout()
    end)

    CreateTickMarks()
    UpdateBarLock()
end

local function UpdateExternalBarVisibility()
    if not bar then return end

    if config.hideExternalBar then
        bar:Hide()
        if healthBar then healthBar:Hide() end
        if resourceBar then resourceBar:Hide() end
        if specialResourceContainer then specialResourceContainer:Hide() end
    else
        bar:Show()
        if healthBar and config.showHealth then healthBar:Show() end
        UpdateResourceBarLayout()
        UpdateSpecialResourcesLayout()
        UpdateSpecialResources()
    end
end

local function UpdateBar(absorb, maxHP)
    if not bar then CreateBar() end
    if not bar then return end

    if config.hideExternalBar then
        bar:Hide()
        if healthBar then healthBar:Hide() end
        if resourceBar then resourceBar:Hide() end
        if specialResourceContainer then specialResourceContainer:Hide() end
        return
    end

    bar:Show()

    absorb = absorb or GetAbsorbAmount("player")
    maxHP = maxHP or UnitHealthMax("player") or 1
    local currentHP = UnitHealth("player") or maxHP

    if healthBar then
        if config.showHealth then
            healthBar:Show()
            healthBar:SetMinMaxValues(0, maxHP)
            healthBar:SetValue(currentHP)
        else
            healthBar:Hide()
        end
    end

    local displayMax = maxHP * (config.capMultiplier or DEFAULTS.capMultiplier)
    if displayMax > 0 then
        bar:SetMinMaxValues(0, displayMax)
        bar:SetValue(absorb)
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end

    -- Actualización segura de la Barra de Recursos (Maná, Poder Rúnico, Ira, Enfoque, etc.)
    if resourceBar and config.resourceDisplay ~= "none" then
        resourceBar:Show()
        local curPower = UnitPower("player") or 0
        local maxPower = UnitPowerMax("player") or 1

        -- Si maxPower es 0 evitar divisiones/mínimos erróneos
        if maxPower <= 0 then maxPower = 1 end

        resourceBar:SetMinMaxValues(0, maxPower)
        resourceBar:SetValue(curPower)
    elseif resourceBar then
        resourceBar:Hide()
    end

    UpdateSpecialResourcesLayout()
    UpdateSpecialResources()
end

local function ApplyBarDimensions(width, height, capPercent)
    if not (width and width > 0 and height and height > 0) then
        print("BloodShieldOverlay: width and height must be positive numbers.")
        return false
    end
    if not (capPercent and capPercent >= MIN_CAP_PERCENT) then
        print(string.format("BloodShieldOverlay: Max %% must be at least %d.", MIN_CAP_PERCENT))
        return false
    end

    config.width = width
    config.height = height
    config.capMultiplier = capPercent / 100

    if bar then
        bar:SetSize(width, height)
    end

    -- Re-render even when only Max % changed. SetSize can invoke OnSizeChanged,
    -- but the cap value itself must always trigger a complete refresh.
    UpdateBar()
    UpdateTickMarks()
    return true
end

local function CreateConfigMenu()
    if menuFrame then return end

    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(480, 350)
    menuFrame:SetPoint("CENTER")
    menuFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    menuFrame:SetMovable(true)
    menuFrame:EnableMouse(true)
    menuFrame:RegisterForDrag("LeftButton")
    menuFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    menuFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", menuFrame, "TOP", 0, -12)
    title:SetText("Shield Bar Settings")

    local info = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 16, -40)
    info:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -16, -40)
    info:SetJustifyH("LEFT")
    info:SetText("Click Unlock to drag the bar. Click Lock to anchor. Use /shield reset for defaults.")

    local widthLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -12)
    widthLabel:SetText("Width:")

    local widthEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    widthEdit:SetSize(50, 24)
    widthEdit:SetPoint("LEFT", widthLabel, "RIGHT", 12, 0)
    widthEdit:SetAutoFocus(false)
    menuFrame.widthEdit = widthEdit

    local heightLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightLabel:SetPoint("LEFT", widthEdit, "RIGHT", 12, 0)
    heightLabel:SetText("Height:")

    local heightEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    heightEdit:SetSize(50, 24)
    heightEdit:SetPoint("LEFT", heightLabel, "RIGHT", 12, 0)
    heightEdit:SetAutoFocus(false)
    menuFrame.heightEdit = heightEdit

    local capLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capLabel:SetPoint("LEFT", heightEdit, "RIGHT", 12, 0)
    capLabel:SetText("Max %:")

    local capEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    capEdit:SetSize(50, 24)
    capEdit:SetPoint("LEFT", capLabel, "RIGHT", 12, 0)
    capEdit:SetAutoFocus(false)
    menuFrame.capEdit = capEdit

    local applyButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    applyButton:SetSize(70, 24)
    applyButton:SetPoint("LEFT", capEdit, "RIGHT", 12, 0)
    applyButton:SetText("Apply")
    menuFrame.applyButton = applyButton

    local visibilityCheck = CreateFrame("CheckButton", nil, menuFrame, "UICheckButtonTemplate")
    visibilityCheck:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", -2, -8)
    visibilityCheck.Text:SetText("Hide external shield bar")
    visibilityCheck:SetScript("OnClick", function(self)
        config.hideExternalBar = self:GetChecked() and true or false
        UpdateExternalBarVisibility()
    end)
    menuFrame.visibilityCheck = visibilityCheck

    local healthCheck = CreateFrame("CheckButton", nil, menuFrame, "UICheckButtonTemplate")
    healthCheck:SetPoint("TOPLEFT", visibilityCheck, "BOTTOMLEFT", 0, -4)
    healthCheck.Text:SetText("Show health bar (red, 100% base)")
    healthCheck:SetScript("OnClick", function(self)
        config.showHealth = self:GetChecked() and true or false
        UpdateBar()
    end)
    menuFrame.healthCheck = healthCheck

    local specialResCheck = CreateFrame("CheckButton", nil, menuFrame, "UICheckButtonTemplate")
    specialResCheck:SetPoint("TOPLEFT", healthCheck, "BOTTOMLEFT", 0, -4)
    specialResCheck.Text:SetText("Show special resources (circles)")
    specialResCheck:SetScript("OnClick", function(self)
        config.showSpecialResources = self:GetChecked() and true or false
        UpdateSpecialResourcesLayout()
        UpdateSpecialResources()
    end)
    menuFrame.specialResCheck = specialResCheck

    local resLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resLabel:SetPoint("TOPLEFT", specialResCheck, "BOTTOMLEFT", 2, -10)
    resLabel:SetText("Personal Resource Bar:")

    local resButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    resButton:SetSize(90, 24)
    resButton:SetPoint("LEFT", resLabel, "RIGHT", 12, 0)
    resButton.UpdateText = function(self)
        local mode = config.resourceDisplay or "left"
        self:SetText(mode:gsub("^%l", string.upper))
    end
    resButton:SetScript("OnClick", function(self)
        if config.resourceDisplay == "left" then
            config.resourceDisplay = "right"
        elseif config.resourceDisplay == "right" then
            config.resourceDisplay = "none"
        else
            config.resourceDisplay = "left"
        end
        self:UpdateText()
        UpdateResourceBarLayout()
        UpdateBar()
    end)
    menuFrame.resButton = resButton

    applyButton:SetScript("OnClick", function()
        local width = tonumber(widthEdit:GetText())
        local height = tonumber(heightEdit:GetText())
        local capPercent = tonumber(capEdit:GetText())
        ApplyBarDimensions(width, height, capPercent)
    end)

    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(90, 24)
    unlock:SetPoint("BOTTOMLEFT", menuFrame, "BOTTOMLEFT", 16, 16)
    unlock:SetText("Unlock")
    unlock:SetScript("OnClick", function()
        config.locked = false
        UpdateBarLock()
    end)

    local lock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    lock:SetSize(90, 24)
    lock:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -16, 16)
    lock:SetText("Lock")
    lock:SetScript("OnClick", function()
        config.locked = true
        UpdateBarLock()
        menuFrame:Hide()
    end)
end

local function RefreshConfigMenuFields()
    if not menuFrame then return end
    menuFrame.widthEdit:SetText(tostring(config.width or DEFAULTS.width))
    menuFrame.heightEdit:SetText(tostring(config.height or DEFAULTS.height))
    menuFrame.capEdit:SetText(tostring((config.capMultiplier or DEFAULTS.capMultiplier) * 100))
    menuFrame.visibilityCheck:SetChecked(config.hideExternalBar and true or false)
    menuFrame.healthCheck:SetChecked(config.showHealth and true or false)
    if menuFrame.specialResCheck then
        menuFrame.specialResCheck:SetChecked(config.showSpecialResources and true or false)
    end
    if menuFrame.resButton and menuFrame.resButton.UpdateText then
        menuFrame.resButton:UpdateText()
    end
end

local function ShowConfigMenu()
    CreateConfigMenu()
    RefreshConfigMenuFields()
    menuFrame:Show()
end

addon.RegisterInitializer(function()
    if not profileKey then
        profileKey = BuildProfileKey()
    end
    EnsureConfig()
    UpdateBar()
    addon.RegisterPlayerUpdateListener(UpdateBar)
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
initFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
initFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
initFrame:RegisterEvent("RUNE_POWER_UPDATE")
initFrame:SetScript("OnEvent", function(_, event, unit, powerType)
    if event == "RUNE_POWER_UPDATE" then
        UpdateSpecialResources()
    elseif event == "UNIT_MAXPOWER" then
        -- Rare event; always safe to recompute (pip count can change, e.g. talents).
        UpdateBar()
        UpdateSpecialResources()
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        UpdateBar()
        -- UNIT_POWER_FREQUENT fires very often for the class's primary
        -- resource (e.g. Energy/Rage/Mana). Only recompute the special-
        -- resource pips when the power type that actually changed is the
        -- one they track, instead of on every unrelated tick.
        if SPECIAL_POWER_TOKEN and powerType == SPECIAL_POWER_TOKEN then
            UpdateSpecialResources()
        end
    end
end)

addon.HandleSlashCommand = function(msg)
    msg = msg and msg:lower():gsub("^%s*(.-)%s*$", "%1") or ""

    if msg == "" then
        ShowConfigMenu()
        return
    elseif msg == "lock" then
        config.locked = true
        UpdateBarLock()
        print("BloodShieldOverlay locked.")
        return
    elseif msg == "unlock" or msg == "move" then
        config.locked = false
        UpdateBarLock()
        print("BloodShieldOverlay is unlocked. Drag to move, then type /shield lock.")
        return
    elseif msg == "hide" then
        config.hideExternalBar = true
        UpdateExternalBarVisibility()
        RefreshConfigMenuFields()
        print("BloodShieldOverlay external bar hidden.")
        return
    elseif msg == "show" then
        config.hideExternalBar = false
        UpdateExternalBarVisibility()
        UpdateBar()
        RefreshConfigMenuFields()
        print("BloodShieldOverlay external bar shown.")
        return
    elseif msg == "reset" then
        ResetConfig()
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
            bar:SetSize(config.width, config.height)
            UpdateBarLock()
        end
        RefreshConfigMenuFields()
        UpdateBar()
        print("BloodShieldOverlay settings reset to defaults.")
        return
    elseif msg == "party" then
        if addon.RequestRefresh then
            addon.RequestRefresh()
            print("BloodShieldOverlay: party frames refreshed.")
        elseif addon.RefreshPartyFiles or addon.RefreshPartyFrames then
            (addon.RefreshPartyFiles or addon.RefreshPartyFrames)()
            print("BloodShieldOverlay: party frames refreshed.")
        else
            print("BloodShieldOverlay: party refresh unavailable.")
        end
        return
    end

    if config.locked then
        print("BloodShieldOverlay is locked. Use /shield unlock to move it.")
    else
        print("BloodShieldOverlay is unlocked. Drag the bar to move it, then use /shield lock.")
    end
end
