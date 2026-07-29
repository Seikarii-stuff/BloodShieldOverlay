-- BloodShieldOverlay.lua
-- Movable absorb bar for the player with slash command /shield.

local ADDON_NAME = "BloodShieldOverlay"

local addon = CreateFrame("Frame")
local bar
local bg
local menuFrame
local warnedNoAbsorbAPI = false

local DEFAULTS = {
    point = "BOTTOM",
    relativePoint = "BOTTOM",
    xOffset = 100,
    yOffset = 450,
    width = 18,
    height = 150,
    locked = true,
}

local config = {}

local function ApplyDefaults(db)
    db = db or {}
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end
    return db
end

local function EnsureConfig()
    if not config then
        config = {}
    end

    if BloodShieldOverlayDB then
        config = ApplyDefaults(BloodShieldOverlayDB)
        BloodShieldOverlayDB = config
    else
        config = ApplyDefaults(config)
        BloodShieldOverlayDB = config
    end

    return config
end

local function ResetConfig()
    config = ApplyDefaults({})
    BloodShieldOverlayDB = config
end

local function GetAbsorbAmount(unit)
    if UnitGetTotalAbsorbs then
        return UnitGetTotalAbsorbs(unit) or 0
    end
    if not warnedNoAbsorbAPI then
        warnedNoAbsorbAPI = true
        print("|cffff5555BloodShieldOverlay:|r this version of WoW does not expose UnitGetTotalAbsorbs; the bar will stay empty.")
    end
    return 0
end

local function SaveBarPosition()
    if not bar then
        return
    end
    local point, _, relativePoint, xOffset, yOffset = bar:GetPoint()
    config.point = point
    config.relativePoint = relativePoint
    config.xOffset = xOffset
    config.yOffset = yOffset
    BloodShieldOverlayDB = config
end

local function UpdateBarLock()
    if not bar then
        return
    end

    bar:EnableMouse(true)
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

local function CreateBar()
    if bar then
        return
    end

    bar = CreateFrame("StatusBar", "BloodShieldOverlayBar", UIParent)
    bar:SetSize(config.width or DEFAULTS.width, config.height or DEFAULTS.height)
    bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.7, 0.1, 0.1, 0.85)
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel(20)
    bar:SetOrientation("VERTICAL")
    bar:SetReverseFill(false)
    bar:EnableMouse(true)
    bar:Show()

    bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.4)

    bar:SetScript("OnEnter", function(self)
        local absorb = GetAbsorbAmount("player")
        local maxHP = UnitHealthMax("player") or 1
        local percent = maxHP > 0 and (absorb / maxHP * 100) or 0

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Blood Shield Overlay", 1, 1, 1)
        GameTooltip:AddLine(string.format("Absorb: %d", absorb), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(string.format("%.0f%% of max health", percent), 0.9, 0.9, 0.9)
        if config.locked then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("/shield unlock to move this bar", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateBarLock()
end

local function CreateConfigMenu()
    if menuFrame then
        return
    end

    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(300, 180)
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
    info:SetText("Click Unlock to drag the absorb bar. Click Lock to anchor it again. Use /shield reset to restore defaults.")

    local widthLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -16)
    widthLabel:SetText("Width:")

    local widthEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    widthEdit:SetSize(60, 24)
    widthEdit:SetPoint("LEFT", widthLabel, "RIGHT", 12, 0)
    widthEdit:SetAutoFocus(false)
    widthEdit:SetText(tostring(config.width or DEFAULTS.width))
    menuFrame.widthEdit = widthEdit

    local heightLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -12)
    heightLabel:SetText("Height:")

    local heightEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    heightEdit:SetSize(60, 24)
    heightEdit:SetPoint("LEFT", heightLabel, "RIGHT", 12, 0)
    heightEdit:SetAutoFocus(false)
    heightEdit:SetText(tostring(config.height or DEFAULTS.height))
    menuFrame.heightEdit = heightEdit

    local applySize = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    applySize:SetSize(80, 24)
    applySize:SetPoint("LEFT", heightEdit, "RIGHT", 12, 0)
    applySize:SetText("Apply")
    applySize:SetScript("OnClick", function()
        local width = tonumber(widthEdit:GetText())
        local height = tonumber(heightEdit:GetText())
        if width and width > 0 and height and height > 0 then
            config.width = width
            config.height = height
            BloodShieldOverlayDB = config
            if bar then
                bar:SetSize(width, height)
            end
        else
            print("BloodShieldOverlay: width and height must be positive numbers.")
        end
    end)

    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(100, 24)
    unlock:SetPoint("BOTTOMLEFT", menuFrame, "BOTTOMLEFT", 16, 16)
    unlock:SetText("Unlock")
    unlock:SetScript("OnClick", function()
        config.locked = false
        BloodShieldOverlayDB = config
        UpdateBarLock()
    end)

    local lock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    lock:SetSize(100, 24)
    lock:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -16, 16)
    lock:SetText("Lock")
    lock:SetScript("OnClick", function()
        config.locked = true
        BloodShieldOverlayDB = config
        UpdateBarLock()
        menuFrame:Hide()
    end)
end

local function ShowConfigMenu()
    CreateConfigMenu()
    if menuFrame then
        menuFrame:Show()
    end
end

local function UpdateBar()
    EnsureConfig()

    if not bar then
        CreateBar()
    end
    if not bar then
        return
    end

    local absorb = GetAbsorbAmount("player")
    local maxHP = UnitHealthMax("player") or 1
    if maxHP > 0 then
        bar:SetMinMaxValues(0, maxHP)
    else
        bar:SetMinMaxValues(0, 1)
    end

    bar:SetValue(absorb)
end

SlashCmdList["BLOODSHIELDOVERLAY"] = function(msg)
    msg = msg and msg:lower():gsub("^%s*(.-)%s*$", "%1") or ""
    if msg == "" then
        ShowConfigMenu()
        return
    end
    if msg == "lock" then
        config.locked = true
        BloodShieldOverlayDB = config
        UpdateBarLock()
        print("BloodShieldOverlay locked.")
        return
    elseif msg == "unlock" or msg == "move" then
        config.locked = false
        BloodShieldOverlayDB = config
        UpdateBarLock()
        print("BloodShieldOverlay unlocked. Drag the bar to move it, then type /shield lock.")
        return
    elseif msg == "reset" then
        ResetConfig()
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
            bar:SetSize(config.width, config.height)
            UpdateBarLock()
        end
        print("BloodShieldOverlay settings reset to defaults.")
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

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("UNIT_AURA")
addon:RegisterEvent("UNIT_MAXHEALTH")
addon:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")

addon:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            EnsureConfig()
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureConfig()
        CreateBar()
        UpdateBar()
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateBar()
    elseif event == "UNIT_AURA" or event == "UNIT_MAXHEALTH" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        local unit = ...
        if unit == "player" then
            UpdateBar()
        end
    end
end)
