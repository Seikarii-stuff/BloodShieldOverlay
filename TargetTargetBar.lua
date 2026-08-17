-- Lightweight target-of-target health bar for healers.
-- One secure unit button, event-driven updates, and a 10 Hz fallback poll.
-- The visual is deliberately minimal: no name, portrait, aura, or extra widgets.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local UNIT = "targettarget"
local POLL_INTERVAL = 0.10
local DEFAULT_WIDTH = 100
local DEFAULT_HEIGHT = 8

local frame
local healthBar
local background
local config
local optionsPanel
local updateElapsed = 0
local dirty = true
local hookedMenu = false

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local InCombatLockdown = InCombatLockdown
local tonumber = tonumber
local tostring = tostring
local type = type
local math_max = math.max

local function GetConfig()
    if config then return config end
    if addon.PlayerBarConfig and addon.PlayerBarConfig.Initialize then
        config = addon.PlayerBarConfig.Initialize()
    end
    return config
end

local function MarkDirty()
    dirty = true
end

local function UpdateHealth()
    if not frame or not config or not config.showTargetTarget then return end
    if not UnitExists(UNIT) then
        frame:Hide()
        return
    end

    local maxHealth = UnitHealthMax(UNIT) or 0
    local health = UnitHealth(UNIT) or 0
    if maxHealth <= 0 then
        frame:Hide()
        return
    end

    healthBar:SetMinMaxValues(0, maxHealth)
    healthBar:SetValue(math_max(0, health))
    frame:Show()
end

local function SavePosition()
    if not frame or not config then return end
    local point, _, relativePoint, xOffset, yOffset = frame:GetPoint()
    if type(point) ~= "string" or type(relativePoint) ~= "string"
        or type(xOffset) ~= "number" or type(yOffset) ~= "number" then
        return
    end
    config.targetTargetPoint = point
    config.targetTargetRelativePoint = relativePoint
    config.targetTargetXOffset = xOffset
    config.targetTargetYOffset = yOffset
end

local function UpdateDragState()
    if not frame or not config then return end
    if config.targetTargetLocked then
        frame:EnableMouse(true)
        frame:SetMovable(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    else
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self)
            if InCombatLockdown() then return end
            self:StartMoving()
        end)
        frame:SetScript("OnDragStop", function(self)
            if InCombatLockdown() then return end
            self:StopMovingOrSizing()
            SavePosition()
        end)
    end
end

local function CreateFrameOnce()
    if frame then return true end
    if InCombatLockdown() then return false end

    frame = CreateFrame("Button", "BloodShieldOverlayTargetTargetBar", UIParent, "SecureUnitButtonTemplate")
    frame:SetSize(config.targetTargetWidth or DEFAULT_WIDTH, config.targetTargetHeight or DEFAULT_HEIGHT)
    frame:SetPoint(
        config.targetTargetPoint or "CENTER",
        UIParent,
        config.targetTargetRelativePoint or "CENTER",
        config.targetTargetXOffset or 0,
        config.targetTargetYOffset or -140
    )
    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(10)
    frame:SetAttribute("unit", UNIT)
    frame:SetAttribute("type1", "none")
    frame:SetAttribute("type2", "none")
    frame:RegisterForClicks("AnyUp", "AnyDown")

    background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(0, 0, 0, 0.55)

    healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetAllPoints(frame)
    healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healthBar:SetStatusBarColor(0.20, 0.85, 0.25, 0.95)
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(0)
    healthBar:SetOrientation("HORIZONTAL")
    healthBar:SetReverseFill(false)
    healthBar:SetFrameLevel(frame:GetFrameLevel() + 1)

    if RegisterUnitWatch then
        RegisterUnitWatch(frame)
    end

    UpdateDragState()
    UpdateHealth()
    return true
end

local function ApplySize(width, height)
    if type(width) ~= "number" or type(height) ~= "number"
        or width <= 0 or height <= 0 then
        return false
    end
    if InCombatLockdown() then
        print("BloodShieldOverlay: target-of-target bar size cannot be changed in combat.")
        return false
    end

    config.targetTargetWidth = width
    config.targetTargetHeight = height
    if frame then frame:SetSize(width, height) end
    return true
end

local function SetEnabled(enabled)
    if type(enabled) ~= "boolean" then return false end
    if InCombatLockdown() then
        print("BloodShieldOverlay: target-of-target visibility cannot be changed in combat.")
        return false
    end

    config.showTargetTarget = enabled
    if not enabled then
        if frame and UnregisterUnitWatch then UnregisterUnitWatch(frame) end
        if frame then frame:Hide() end
    else
        if not CreateFrameOnce() then return false end
        if RegisterUnitWatch then RegisterUnitWatch(frame) end
        MarkDirty()
        UpdateHealth()
    end
    return true
end

local function CreateTargetOptions(menu)
    if optionsPanel or not menu then return end

    menu:SetHeight(math_max(menu:GetHeight(), 520))

    local anchor = menu.classOverlayCheck or menu.specialResCheck
    local panel = CreateFrame("Frame", nil, menu)
    panel:SetSize(440, 110)
    if anchor then
        panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    else
        panel:SetPoint("TOPLEFT", menu, "TOPLEFT", 18, -250)
    end
    optionsPanel = panel

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Target of Target:")

    local showCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    showCheck.Text:SetText("Show target of target frame")
    showCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -2)
    showCheck:SetChecked(config.showTargetTarget and true or false)
    showCheck:SetScript("OnClick", function(self)
        local requested = self:GetChecked() and true or false
        if not SetEnabled(requested) then
            self:SetChecked(config.showTargetTarget and true or false)
        end
    end)
    panel.showCheck = showCheck

    local widthLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    widthLabel:SetPoint("TOPLEFT", showCheck, "BOTTOMLEFT", 4, -6)
    widthLabel:SetText("Width")

    local widthEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    widthEdit:SetSize(45, 22)
    widthEdit:SetPoint("LEFT", widthLabel, "RIGHT", 8, 0)
    widthEdit:SetAutoFocus(false)
    widthEdit:SetText(tostring(config.targetTargetWidth or DEFAULT_WIDTH))
    panel.widthEdit = widthEdit

    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heightLabel:SetPoint("LEFT", widthEdit, "RIGHT", 16, 0)
    heightLabel:SetText("Height")

    local heightEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    heightEdit:SetSize(45, 22)
    heightEdit:SetPoint("LEFT", heightLabel, "RIGHT", 8, 0)
    heightEdit:SetAutoFocus(false)
    heightEdit:SetText(tostring(config.targetTargetHeight or DEFAULT_HEIGHT))
    panel.heightEdit = heightEdit

    local apply = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    apply:SetSize(60, 22)
    apply:SetPoint("LEFT", heightEdit, "RIGHT", 12, 0)
    apply:SetText("Apply")
    apply:SetScript("OnClick", function()
        local width = tonumber(widthEdit:GetText())
        local height = tonumber(heightEdit:GetText())
        if not ApplySize(width, height) then
            widthEdit:SetText(tostring(config.targetTargetWidth or DEFAULT_WIDTH))
            heightEdit:SetText(tostring(config.targetTargetHeight or DEFAULT_HEIGHT))
        end
    end)

    local unlock = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    unlock:SetSize(75, 22)
    unlock:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", -4, -8)
    unlock:SetText("Unlock")
    unlock:SetScript("OnClick", function()
        if InCombatLockdown() then
            print("BloodShieldOverlay: target-of-target position cannot be changed in combat.")
            return
        end
        config.targetTargetLocked = false
        UpdateDragState()
    end)

    local lock = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lock:SetSize(65, 22)
    lock:SetPoint("LEFT", unlock, "RIGHT", 6, 0)
    lock:SetText("Lock")
    lock:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        config.targetTargetLocked = true
        UpdateDragState()
    end)
end

local function RefreshOptions()
    if not optionsPanel or not config then return end
    optionsPanel.showCheck:SetChecked(config.showTargetTarget and true or false)
    optionsPanel.widthEdit:SetText(tostring(config.targetTargetWidth or DEFAULT_WIDTH))
    optionsPanel.heightEdit:SetText(tostring(config.targetTargetHeight or DEFAULT_HEIGHT))
end

local function HookConfigMenu()
    if hookedMenu then return end
    if not addon.PlayerBarAPI or not addon.PlayerBarAPI.ShowConfigMenu then return end

    local originalShow = addon.PlayerBarAPI.ShowConfigMenu
    if originalShow.__targetTargetWrapped then
        hookedMenu = true
        return
    end

    local wrappedShow = function(...)
        originalShow(...)
        local menu = _G.BloodShieldOverlayConfig
        if menu then
            CreateTargetOptions(menu)
            RefreshOptions()
        end
    end
    wrappedShow.__targetTargetWrapped = true
    addon.PlayerBarAPI.ShowConfigMenu = wrappedShow
    addon.ShowConfigMenu = wrappedShow
    hookedMenu = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_TARGET")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        MarkDirty()
        return
    end

    if unit == "target" or unit == UNIT then
        MarkDirty()
    end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not config or not config.showTargetTarget or not frame then return end
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < POLL_INTERVAL then return end
    updateElapsed = 0

    -- Event-driven first; the small 10 Hz fallback catches target changes on
    -- hostile units that do not emit UNIT_TARGET to the client.
    if dirty or UnitExists(UNIT) then
        dirty = false
        UpdateHealth()
    end
end)

addon.TargetTargetBarAPI = {
    Enable = function(enabled) return SetEnabled(enabled) end,
    ApplySize = ApplySize,
    SetLocked = function(locked)
        if InCombatLockdown() then return false end
        config.targetTargetLocked = locked and true or false
        UpdateDragState()
        return true
    end,
    Refresh = function()
        MarkDirty()
        UpdateHealth()
    end,
}

addon.RegisterInitializer(function()
    config = GetConfig()
    config.showTargetTarget = config.showTargetTarget ~= false
    config.targetTargetWidth = config.targetTargetWidth or DEFAULT_WIDTH
    config.targetTargetHeight = config.targetTargetHeight or DEFAULT_HEIGHT
    config.targetTargetLocked = config.targetTargetLocked ~= false
    config.targetTargetPoint = config.targetTargetPoint or "CENTER"
    config.targetTargetRelativePoint = config.targetTargetRelativePoint or "CENTER"
    config.targetTargetXOffset = config.targetTargetXOffset or 0
    config.targetTargetYOffset = config.targetTargetYOffset or -140

    if config.showTargetTarget then
        CreateFrameOnce()
    end

    -- PlayerBar's initializer creates PlayerBarAPI. If initializer ordering ever
    -- changes, retrying here keeps this module independent of that implementation.
    HookConfigMenu()
end)

addon.RegisterInitializer(function()
    HookConfigMenu()
end)
