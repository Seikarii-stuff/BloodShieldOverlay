-- BloodShieldOverlay.lua
-- Movable absorb bar for the player with slash command /shield.
--
-- The bar represents the player's absorb shield as a percentage of max
-- health (not an absolute number), and can visually exceed 100% for
-- mechanics that let absorbs overshoot current health (e.g. Blood Shield).
-- Tick marks at 50% / 100% / 150% make it easy to read at a glance.

local ADDON_NAME = "BloodShieldOverlay"

local addon = CreateFrame("Frame")
local bar
local bg
local menuFrame
local tickLines = {}
local tickLabels = {}
local warnedNoAbsorbAPI = false

-- Fractions of max health at which we draw a tick mark on the bar.
local TICK_FRACTIONS = { 0.5, 1.0, 1.5 }

local DEFAULTS = {
    point = "BOTTOM",
    relativePoint = "BOTTOM",
    xOffset = 100,
    yOffset = 450,
    width = 18,
    height = 150,
    locked = true,
    -- How much overshoot the bar can display, expressed as a multiple of
    -- max health. 2.0 = the bar tops out at 200% of max health.
    capMultiplier = 2.0,
}

-- Populated from the BloodShieldOverlayDB SavedVariable once ADDON_LOADED
-- fires for this addon (see the OnEvent handler below). Starts as a plain
-- table (not nil) so that any event which fires out of order can't crash
-- CreateBar()/UpdateBar() by indexing a nil config.
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

-- Defensive re-entry point: guarantees config is a fully populated table
-- no matter what order events fire in. Safe to call as often as needed.
local function EnsureConfig()
    if BloodShieldOverlayDB then
        config = ApplyDefaults(BloodShieldOverlayDB)
    else
        config = ApplyDefaults(config)
    end
    BloodShieldOverlayDB = config
end

local function ResetConfig()
    for key, value in pairs(DEFAULTS) do
        config[key] = value
    end
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
end

local function UpdateBarLock()
    if not bar then
        return
    end
    -- Mouse stays enabled even when locked so the tooltip keeps working;
    -- only dragging is gated behind the lock state.
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

-- Repositions the 50% / 100% / 150% tick marks and their labels to match
-- the bar's current height and cap multiplier. Ticks beyond the current
-- cap are hidden rather than clamped to the edge.
local function UpdateTickMarks()
    if not bar then
        return
    end

    local capMultiplier = config.capMultiplier or DEFAULTS.capMultiplier
    local totalHeight = bar:GetHeight()

    for _, fraction in ipairs(TICK_FRACTIONS) do
        local tick = tickLines[fraction]
        local label = tickLabels[fraction]

        if fraction <= capMultiplier then
            local yOffset = totalHeight * (fraction / capMultiplier)

            tick:ClearAllPoints()
            tick:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, yOffset - 1)
            tick:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, yOffset - 1)
            tick:Show()

            label:ClearAllPoints()
            label:SetPoint("LEFT", bar, "BOTTOMLEFT", bar:GetWidth() + 4, yOffset)
            label:Show()
        else
            tick:Hide()
            label:Hide()
        end
    end
end

local function CreateTickMarks()
    for _, fraction in ipairs(TICK_FRACTIONS) do
        local tick = bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(1, 1, 1, 0.85)
        tick:SetHeight(2)
        tickLines[fraction] = tick

        local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetText("")
        label:SetTextColor(1, 1, 1, 0.9)
        tickLabels[fraction] = label
    end
    UpdateTickMarks()
end

-- Picks a bar color based on how far past 100% health the shield is.
-- Plain red under 100%, purple between 100-150%, gold above 150%.
local function UpdateBarColor(ratio)
    bar:SetStatusBarColor(1.0, 1.0, 1.0, 0.95)
end

local function OnBarEnter(self)
    local absorb = GetAbsorbAmount("player")
    local absorbText = tostring(absorb or 0)

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Blood Shield Overlay", 1, 1, 1)
    GameTooltip:AddLine(string.format("Absorb: %s", absorbText), 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Value shown live from the absorb API", 0.9, 0.9, 0.9)
    if config.locked then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("/shield unlock to move this bar", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function OnBarLeave()
    GameTooltip:Hide()
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
    bar:Show()

    bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.4)

    bar:SetScript("OnEnter", OnBarEnter)
    bar:SetScript("OnLeave", OnBarLeave)
    bar:SetScript("OnSizeChanged", UpdateTickMarks)

    CreateTickMarks()
    UpdateBarLock()
end

local function CreateConfigMenu()
    if menuFrame then
        return
    end

    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(320, 230)
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

    local applyButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    applyButton:SetSize(90, 24)
    applyButton:SetPoint("TOPLEFT", capLabel, "BOTTOMLEFT", 0, -16)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", function()
        local width = tonumber(widthEdit:GetText())
        local height = tonumber(heightEdit:GetText())
        local capPercent = tonumber(capEdit:GetText())

        if not (width and width > 0 and height and height > 0) then
            print("BloodShieldOverlay: width and height must be positive numbers.")
            return
        end
        if not (capPercent and capPercent >= 100) then
            print("BloodShieldOverlay: Max %% must be a number of at least 100.")
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

-- Keeps the open settings menu in sync after /shield reset changes config
-- outside of the menu's own Apply button.
local function RefreshConfigMenuFields()
    if not menuFrame then
        return
    end
    menuFrame.widthEdit:SetText(tostring(config.width or DEFAULTS.width))
    menuFrame.heightEdit:SetText(tostring(config.height or DEFAULTS.height))
    menuFrame.capEdit:SetText(tostring((config.capMultiplier or DEFAULTS.capMultiplier) * 100))
end

local function ShowConfigMenu()
    CreateConfigMenu()
    RefreshConfigMenuFields()
    menuFrame:Show()
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
    local capMultiplier = config.capMultiplier or DEFAULTS.capMultiplier
    local displayMax = maxHP * capMultiplier

    if displayMax > 0 then
        bar:SetMinMaxValues(0, displayMax)
        local ok = pcall(function()
            bar:SetValue(absorb or 0)
        end)
        if not ok then
            bar:SetValue(0)
        end
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end

    if maxHP > 0 then
        local ok, ratio = pcall(function()
            return (absorb or 0) / maxHP
        end)
        if ok then
            UpdateBarColor(ratio)
        else
            UpdateBarColor(0)
        end
    else
        UpdateBarColor(0)
    end
end

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
