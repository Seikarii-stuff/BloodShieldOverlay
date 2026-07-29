-- BloodShieldOverlay.lua
-- Movable absorb bar for the player with slash command /shield.

local addon = CreateFrame("Frame")
local bar
local barText
local defaults = {
    point = "BOTTOM",
    relativePoint = "BOTTOM",
    xOffset = 0,
    yOffset = 90,
    width = 200,
    height = 18,
    locked = true,
}

BloodShieldOverlayDB = BloodShieldOverlayDB or {}
local db = BloodShieldOverlayDB

local function EnsureDB()
    if not db.point then
        db.point = defaults.point
    end
    if not db.relativePoint then
        db.relativePoint = defaults.relativePoint
    end
    if not db.xOffset then
        db.xOffset = defaults.xOffset
    end
    if not db.yOffset then
        db.yOffset = defaults.yOffset
    end
    if not db.width then
        db.width = defaults.width
    end
    if not db.height then
        db.height = defaults.height
    end
    if db.locked == nil then
        db.locked = defaults.locked
    end
end

local function GetAbsorbAmount(unit)
    if UnitGetTotalAbsorbs then
        return UnitGetTotalAbsorbs(unit) or 0
    end
    return 0
end

local function SaveBarPosition()
    if not bar then
        return
    end
    local point, _, relativePoint, xOffset, yOffset = bar:GetPoint()
    db.point = point
    db.relativePoint = relativePoint
    db.xOffset = xOffset
    db.yOffset = yOffset
end

local function UpdateBarLock()
    if not bar then
        return
    end
    if db.locked then
        bar:EnableMouse(false)
        bar:SetMovable(false)
        bar:SetScript("OnDragStart", nil)
        bar:SetScript("OnDragStop", nil)
    else
        bar:EnableMouse(true)
        bar:SetMovable(true)
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
    bar:SetSize(db.width or defaults.width, db.height or defaults.height)
    bar:SetPoint(db.point, UIParent, db.relativePoint, db.xOffset, db.yOffset)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.7, 0.1, 0.1, 0.85)
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel(20)
    bar:SetReverseFill(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:Show()

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.4)

    barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    barText:SetTextColor(1, 1, 1, 1)
    barText:SetText("Absorb: 0")

    UpdateBarLock()
end

local menuFrame

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
    info:SetText("Click Unlock to drag the absorb bar. Click Lock to anchor it again. Use /shield reset to restore default position.")

    local widthLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -16)
    widthLabel:SetText("Width:")

    local widthEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    widthEdit:SetSize(60, 24)
    widthEdit:SetPoint("LEFT", widthLabel, "RIGHT", 12, 0)
    widthEdit:SetAutoFocus(false)
    widthEdit:SetText(tostring(db.width or defaults.width))

    local heightLabel = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -12)
    heightLabel:SetText("Height:")

    local heightEdit = CreateFrame("EditBox", nil, menuFrame, "InputBoxTemplate")
    heightEdit:SetSize(60, 24)
    heightEdit:SetPoint("LEFT", heightLabel, "RIGHT", 12, 0)
    heightEdit:SetAutoFocus(false)
    heightEdit:SetText(tostring(db.height or defaults.height))

    local applySize = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    applySize:SetSize(80, 24)
    applySize:SetPoint("LEFT", heightEdit, "RIGHT", 12, 0)
    applySize:SetText("Apply")
    applySize:SetScript("OnClick", function()
        local width = tonumber(widthEdit:GetText())
        local height = tonumber(heightEdit:GetText())
        if width and width > 0 and height and height > 0 then
            db.width = width
            db.height = height
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
        db.locked = false
        UpdateBarLock()
    end)

    local lock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    lock:SetSize(100, 24)
    lock:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -16, 16)
    lock:SetText("Lock")
    lock:SetScript("OnClick", function()
        db.locked = true
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
    barText:SetText(string.format("Absorb: %d", absorb))
end

SlashCmdList["BLOODSHIELDOVERLAY"] = function(msg)
    msg = msg and msg:lower():gsub("^%s*(.-)%s*$", "%1") or ""
    if msg == "" then
        ShowConfigMenu()
        return
    end
    if msg == "lock" then
        db.locked = true
        UpdateBarLock()
        print("BloodShieldOverlay locked.")
        return
    elseif msg == "unlock" or msg == "move" then
        db.locked = false
        UpdateBarLock()
        print("BloodShieldOverlay unlocked. Drag the bar to move it, then type /shield lock.")
        return
    elseif msg == "reset" then
        db.point = defaults.point
        db.relativePoint = defaults.relativePoint
        db.xOffset = defaults.xOffset
        db.yOffset = defaults.yOffset
        db.width = defaults.width
        db.height = defaults.height
        db.locked = defaults.locked
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint(db.point, UIParent, db.relativePoint, db.xOffset, db.yOffset)
            bar:SetSize(db.width, db.height)
            UpdateBarLock()
        end
        print("BloodShieldOverlay position reset.")
        return
    end

    if db.locked then
        print("BloodShieldOverlay is locked. Use /shield unlock to move it.")
    else
        print("BloodShieldOverlay is unlocked. Drag the bar to move it, then use /shield lock.")
    end
end
SLASH_BLOODSHIELDOVERLAY1 = "/shield"
SLASH_BLOODSHIELDOVERLAY2 = "/shieldbar"

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("UNIT_AURA")
addon:RegisterEvent("UNIT_MAXHEALTH")
addon:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")

addon:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
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
