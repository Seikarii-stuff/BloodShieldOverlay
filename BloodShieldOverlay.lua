-- Movable absorb bar for the player with slash command /shield.

local ADDON_NAME = "BloodShieldOverlay"
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local bar
local menuFrame
local tickLines = {}

local TICK_FRACTIONS = { 0.5, 1.0, 1.5 }
local MIN_CAP_PERCENT = 20

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
}

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

-- FIX: Safe migration and profile handling without configuration desync
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

    bar:SetScript("OnSizeChanged", UpdateTickMarks)

    CreateTickMarks()
    UpdateBarLock()
end

local function UpdateExternalBarVisibility()
    if not bar then return end

    if config.hideExternalBar then
        bar:Hide()
    else
        bar:Show()
    end
end

local function CreateConfigMenu()
    if menuFrame then return end

    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(320, 260)
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
    menuFrame:SetScript("OnDragStart", menuFrame.StartMoving)
    menuFrame:SetScript("OnDragStop", menuFrame.StopMovingOrSizing)

    local title = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", menuFrame, "TOP", 0, -12)
    title:SetText("Shield Bar Settings")

    local info = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 16, -40)
    info:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -16, -40)
    info:SetJustifyH("LEFT")
    info:SetText("Click Unlock to drag the absorb bar. Click Lock to anchor it again. Use /shield reset to restore defaults. Settings are stored separately for each character.")

    local widthLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -16)
    widthLabel:SetText("Width:")

    local widthEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    widthEdit:SetSize(50, 24)
    widthEdit:SetPoint("LEFT", widthLabel, "RIGHT", 12, 0)
    widthEdit:SetAutoFocus(false)
    widthEdit:SetText(tostring(config.width or DEFAULTS.width))
    menuFrame.widthEdit = widthEdit

    local heightLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -14)
    heightLabel:SetText("Height:")

    local heightEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    heightEdit:SetSize(50, 24)
    heightEdit:SetPoint("LEFT", heightLabel, "RIGHT", 12, 0)
    heightEdit:SetAutoFocus(false)
    heightEdit:SetText(tostring(config.height or DEFAULTS.height))
    menuFrame.heightEdit = heightEdit

    local capLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capLabel:SetPoint("TOPLEFT", heightLabel, "BOTTOMLEFT", 0, -14)
    capLabel:SetText("Max %:")

    local capEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    capEdit:SetSize(50, 24)
    capEdit:SetPoint("LEFT", capLabel, "RIGHT", 12, 0)
    capEdit:SetAutoFocus(false)
    capEdit:SetText(tostring((config.capMultiplier or DEFAULTS.capMultiplier) * 100))
    menuFrame.capEdit = capEdit

    local capHint = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    capHint:SetPoint("LEFT", capEdit, "RIGHT", 8, 0)
    capHint:SetText("top of the bar,\ne.g. 200")
    capHint:SetJustifyH("LEFT")

    local visibilityCheck = CreateFrame("CheckButton", nil, menuFrame, "UICheckButtonTemplate")
    visibilityCheck:SetPoint("TOPLEFT", capLabel, "BOTTOMLEFT", -2, -12)
    visibilityCheck.Text:SetText("Hide external shield bar")
    visibilityCheck:SetScript("OnClick", function(self)
        config.hideExternalBar = self:GetChecked() and true or false
        UpdateExternalBarVisibility()
    end)
    menuFrame.visibilityCheck = visibilityCheck

    local applyButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    applyButton:SetSize(90, 24)
    applyButton:SetPoint("TOPLEFT", visibilityCheck, "BOTTOMLEFT", 2, -10)
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
            print(string.format("BloodShieldOverlay: Max %% must be a number of at least %d.", MIN_CAP_PERCENT))
            return
        end

        config.width = width
        config.height = height
        config.capMultiplier = capPercent / 100

        if bar then
            bar:SetSize(width, height)
            UpdateTickMarks()
        end
    end)

    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(100, 24)
    unlock:SetPoint("BOTTOMLEFT", menuFrame, "BOTTOMLEFT", 16, 16)
    unlock:SetText("Unlock")
    unlock:SetScript("OnClick", function()
        config.locked = false
        UpdateBarLock()
    end)

    local lock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    lock:SetSize(100, 24)
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
end

local function ShowConfigMenu()
    CreateConfigMenu()
    RefreshConfigMenuFields()
    menuFrame:Show()
end

local function UpdateBar(absorb, maxHP)
    if not bar then CreateBar() end
    if not bar then return end

    if config.hideExternalBar then
        bar:Hide()
        return
    end

    bar:Show()

    absorb = absorb or GetAbsorbAmount("player")
    maxHP = maxHP or UnitHealthMax("player") or 1
    local displayMax = maxHP * (config.capMultiplier or DEFAULTS.capMultiplier)

    if displayMax > 0 then
        bar:SetMinMaxValues(0, displayMax)
        bar:SetValue(absorb)
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end
end

if addon.RegisterPlayerUpdateListener then
    addon.RegisterPlayerUpdateListener(UpdateBar)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    EnsureConfig()
    UpdateBar()
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
        print("BloodShieldOverlay unlocked. Drag the bar to move it, then type /shield lock.")
        return
    elseif msg == "hide" then
        config.hideExternalBar = true
        UpdateExternalBarVisibility()
        RefreshConfigMenuFields()
        print("BloodShieldOverlay external bar hidden for this character.")
        return
    elseif msg == "show" then
        config.hideExternalBar = false
        UpdateExternalBarVisibility()
        UpdateBar()
        RefreshConfigMenuFields()
        print("BloodShieldOverlay external bar shown for this character.")
        return
    elseif msg == "reset" then
        ResetConfig()
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
            bar:SetSize(config.width, config.height)
            UpdateBarLock()
            UpdateTickMarks()
        end
        RefreshConfigMenuFields()
        UpdateBar()
        print("BloodShieldOverlay settings reset to defaults.")
        return
    elseif msg == "party" then
        if addon.RequestRefresh then
            addon.RequestRefresh()
            print("BloodShieldOverlay: party frames refreshed.")
        elseif addon.RefreshPartyFrames then
            addon.RefreshPartyFrames()
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