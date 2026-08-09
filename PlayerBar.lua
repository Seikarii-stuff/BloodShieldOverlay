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

local DEFAULTS = {
    point = "BOTTOM",
    relativePoint = "BOTTOM",
    xOffset = 100,
    yOffset = 450,
    width = 18,
    height = 150,
    locked = true,
    hideExternalBar = false,
    capMultiplier = 2.0,
    showHealth = false,
    resourceDisplay = "left", -- "left", "right", "none"
}

local RESOURCE_DISPLAY_MODES = { left = true, right = true, none = true }

local config = {}

local function GetProfileKey()
    local playerName = UnitName("player") or "Player"
    local realmName = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName and GetRealmName() or "Unknown"
    return string.format("%s-%s", playerName, realmName)
end

local function EnsureProfileStore()
    if type(BloodShieldOverlayProfiles) ~= "table" then
        BloodShieldOverlayProfiles = {}
    end
    return BloodShieldOverlayProfiles
end

local function ApplyDefaults(db)
    db = db or {}
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
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
    else
        bar:Show()
        if healthBar and config.showHealth then healthBar:Show() end
        UpdateResourceBarLayout()
    end
end

local function UpdateBar(absorb, maxHP)
    if not bar then CreateBar() end
    if not bar then return end

    if config.hideExternalBar then
        bar:Hide()
        if healthBar then healthBar:Hide() end
        if resourceBar then resourceBar:Hide() end
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
end

local function CreateConfigMenu()
    if menuFrame then return end

    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(320, 310)
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
    heightLabel:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -12)
    heightLabel:SetText("Height:")

    local heightEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    heightEdit:SetSize(50, 24)
    heightEdit:SetPoint("LEFT", heightLabel, "RIGHT", 12, 0)
    heightEdit:SetAutoFocus(false)
    menuFrame.heightEdit = heightEdit

    local capLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capLabel:SetPoint("TOPLEFT", heightLabel, "BOTTOMLEFT", 0, -12)
    capLabel:SetText("Max %:")

    local capEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    capEdit:SetSize(50, 24)
    capEdit:SetPoint("LEFT", capLabel, "RIGHT", 12, 0)
    capEdit:SetAutoFocus(false)
    menuFrame.capEdit = capEdit

    local visibilityCheck = CreateFrame("CheckButton", nil, menuFrame, "UICheckButtonTemplate")
    visibilityCheck:SetPoint("TOPLEFT", capLabel, "BOTTOMLEFT", -2, -8)
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

    local resLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resLabel:SetPoint("TOPLEFT", healthCheck, "BOTTOMLEFT", 2, -10)
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

    local applyButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    applyButton:SetSize(90, 24)
    applyButton:SetPoint("TOPLEFT", resLabel, "BOTTOMLEFT", -2, -12)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", function()
        local width = tonumber(widthEdit:GetText())
        local height = tonumber(heightEdit:GetText())
        local capPercent = tonumber(capEdit:GetText())

        if not (width and width > 0 and height and height > 0) then
            print("BloodShieldOverlay: width and height must be positive numbers.")
            return
        end
        if not (capPercent and capPercent >= MIN_CAP_PERCENT) then
            print(string.format("BloodShieldOverlay: Max %% must be at least %d.", MIN_CAP_PERCENT))
            return
        end

        config.width = width
        config.height = height
        config.capMultiplier = capPercent / 100

        if bar then
            bar:SetSize(width, height)
        end
        UpdateBar()
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
    if menuFrame.resButton and menuFrame.resButton.UpdateText then
        menuFrame.resButton:UpdateText()
    end
end

local function ShowConfigMenu()
    CreateConfigMenu()
    RefreshConfigMenuFields()
    menuFrame:Show()
end

if addon.RegisterPlayerUpdateListener then
    addon.RegisterPlayerUpdateListener(UpdateBar)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("UNIT_POWER_UPDATE")
initFrame:RegisterEvent("UNIT_MAXPOWER")
initFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        EnsureConfig()
        UpdateBar()
    elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER") and unit == "player" then
        UpdateBar()
    end
end)

SlashCmdList["BLOODSHIELDOVERLAY"] = function(msg)
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
SLASH_BLOODSHIELDOVERLAY1 = "/shield"
SLASH_BLOODSHIELDOVERLAY2 = "/shieldbar"
SLASH_BLOODSHIELDOVERLAY3 = "/shields"
