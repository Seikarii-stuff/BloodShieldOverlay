-- Standalone player absorption, health, resource bars.
-- Configuration UI lives exclusively in Menu.lua.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local bar
local healthBar
local resourceBar
local tickLines = {}
local resourceThresholdLines = {}
local specialResourceContainer
local specialCircles = {}
local specialProgress = {}
local specialOrder = {}

local math_min = math.min
local math_max = math.max
local math_floor = math.floor

local TICK_FRACTIONS = { 0.33, 0.66 }
local RESOURCE_THRESHOLDS = { 0.28, 0.56 }
local RESOURCE_BAR_WIDTH = 8
local MAX_SPECIAL_CIRCLES = 7
local SHIELD_CAP_MULTIPLIER = 1.0

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local DEFAULTS = addon.PlayerBarConfig.GetDefaults()

local function CurrentConfig()
    local config = addon.PlayerBarConfig and addon.PlayerBarConfig.Get and addon.PlayerBarConfig.Get() or nil
    return config or DEFAULTS
end

local function GetAbsorbAmount(unit)
    if UnitGetTotalAbsorbs then return UnitGetTotalAbsorbs(unit) or 0 end
    return 0
end

local function SaveBarPosition()
    if not bar then return end
    local point, _, relativePoint, xOffset, yOffset = bar:GetPoint()
    if type(point) ~= "string" or type(relativePoint) ~= "string" or type(xOffset) ~= "number" or type(yOffset) ~= "number" then
        return
    end
    addon.PlayerBarConfig.SetMany({ point = point, relativePoint = relativePoint, xOffset = xOffset, yOffset = yOffset })
end

local function UpdateBarLock()
    local config = CurrentConfig()
    if not bar then return end
    bar:EnableMouse(not config.locked)
    bar:SetMovable(not config.locked)
    if config.locked then
        bar:RegisterForDrag()
        bar:SetScript("OnDragStart", nil)
        bar:SetScript("OnDragStop", nil)
    else
        bar:RegisterForDrag("LeftButton")
        bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
        bar:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            SaveBarPosition()
        end)
    end
end

local function UpdateTickMarks()
    if not bar then return end
    local totalHeight = bar:GetHeight()
    for _, fraction in ipairs(TICK_FRACTIONS) do
        local tick = tickLines[fraction]
        if tick then
            local yOffset = totalHeight * (fraction / SHIELD_CAP_MULTIPLIER)
            tick:ClearAllPoints()
            tick:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, yOffset - 1)
            tick:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, yOffset - 1)
            tick:Show()
        end
    end
end

local function UpdateResourceBarLayout()
    if not resourceBar or not bar then return end
    resourceBar:ClearAllPoints()
    resourceBar:SetPoint("TOPRIGHT", bar, "TOPLEFT", -2, 0)
    resourceBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -2, 0)
    resourceBar:SetWidth(RESOURCE_BAR_WIDTH)
    resourceBar:Show()
    for _, threshold in ipairs(RESOURCE_THRESHOLDS) do
        local line = resourceThresholdLines[threshold]
        if line then
            local yOffset = resourceBar:GetHeight() * threshold
            line:ClearAllPoints()
            line:SetPoint("BOTTOMLEFT", resourceBar, "BOTTOMLEFT", 0, yOffset - 1)
            line:SetPoint("BOTTOMRIGHT", resourceBar, "BOTTOMRIGHT", 0, yOffset - 1)
            line:Show()
        end
    end
end

for index = 1, MAX_SPECIAL_CIRCLES do
    specialProgress[index], specialOrder[index] = 0, index
end

local specialResourceProvider = addon.GetSpecialResourceProvider(playerClass, powerTypes)

local function UpdateSpecialResourcesLayout()
    local config = CurrentConfig()
    if not specialResourceContainer then return end
    if config.hideExternalBar then
        specialResourceContainer:Hide()
        return
    end
    local maxPower = specialResourceProvider and specialResourceProvider.GetMax() or 0
    maxPower = math_min(maxPower, MAX_SPECIAL_CIRCLES)
    if maxPower <= 0 then
        specialResourceContainer:Hide()
        return
    end
    local parentWidth, parentHeight = resourceBar:GetWidth(), resourceBar:GetHeight()
    local customWidth = config.specialResourcePipWidth or DEFAULTS.specialResourcePipWidth
    local customHeight = config.specialResourcePipHeight or DEFAULTS.specialResourcePipHeight
    local slotSize = math_min(math_max(3, customHeight), math_floor(parentHeight / maxPower))
    if slotSize < 3 then slotSize = 3 end
    local circleWidth = math_max(2, math_min(customWidth, math_max(2, parentWidth - 2)))
    local xOffset = math_max(1, (parentWidth - circleWidth) / 2)
    specialResourceContainer:Show()
    for index = 1, MAX_SPECIAL_CIRCLES do
        local circle = specialCircles[specialOrder[index]]
        if index <= maxPower then
            circle:SetSize(circleWidth, math_max(1, slotSize - 2))
            circle:ClearAllPoints()
            circle:SetPoint("TOPLEFT", resourceBar, "TOPLEFT", xOffset, -((index - 1) * slotSize + 1))
            circle:Show()
        else
            circle:Hide()
        end
    end
end

local function UpdateSpecialResources()
    local config = CurrentConfig()
    if not specialResourceContainer then return end
    if config.hideExternalBar then
        UpdateSpecialResourcesLayout()
        return
    end
    if specialResourceProvider then
        local state = specialResourceProvider:GetState()
        addon.RenderResourcePips(state, specialCircles, specialProgress, specialOrder, MAX_SPECIAL_CIRCLES)
    else
        for index = 1, MAX_SPECIAL_CIRCLES do specialProgress[index] = 0 end
    end
    UpdateSpecialResourcesLayout()
end

addon.UpdateSpecialResourcesLayout = UpdateSpecialResourcesLayout
addon.UpdateSpecialResources = UpdateSpecialResources

function addon.SetSpecialResourcePipSize(width, height)
    if type(width) ~= "number" or type(height) ~= "number" then return false end
    if width < 2 or width > 20 or height < 2 or height > 32 then return false end
    return addon.PlayerBarConfig.SetMany({ specialResourcePipWidth = width, specialResourcePipHeight = height })
end

function addon.SetPlayerBarDimensions(width, height)
    if type(width) ~= "number" or type(height) ~= "number" then return false end
    if width <= 0 or height <= 0 then
        print("BloodShieldOverlay: width and height must be positive numbers.")
        return false
    end
    return addon.PlayerBarConfig.SetMany({ width = width, height = height })
end

local function CreateSpecialResources()
    if specialResourceContainer or not bar then return end
    specialResourceContainer = CreateFrame("Frame", nil, resourceBar)
    specialResourceContainer:SetAllPoints(resourceBar)
    for index = 1, MAX_SPECIAL_CIRCLES do
        local circle = CreateFrame("StatusBar", nil, specialResourceContainer)
        circle:SetFrameLevel(resourceBar:GetFrameLevel() + 1)
        circle:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        circle:SetStatusBarColor(1, 1, 1, 1)
        circle:SetOrientation("VERTICAL")
        local background = circle:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(circle)
        background:SetTexture("Interface\\Buttons\\WHITE8x8")
        background:SetVertexColor(0.15, 0.15, 0.15, 0.6)
        circle:EnableMouse(false)
        circle:Hide()
        specialCircles[index] = circle
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
    local config = CurrentConfig()
    bar = CreateFrame("StatusBar", "BloodShieldOverlayBar", UIParent)
    bar:SetSize(config.width or DEFAULTS.width, config.height or DEFAULTS.height)
    bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(1, 1, 1, 1)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(1)
    bar:SetOrientation("VERTICAL")
    bar:SetReverseFill(false)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.4)

    healthBar = CreateFrame("StatusBar", nil, bar)
    healthBar:SetAllPoints(bar)
    healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healthBar:SetStatusBarColor(0.85, 0.15, 0.15, 0.85)
    healthBar:SetOrientation("VERTICAL")
    healthBar:SetReverseFill(false)
    healthBar:SetFrameLevel(bar:GetFrameLevel())

    resourceBar = CreateFrame("StatusBar", nil, bar)
    resourceBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    resourceBar:SetStatusBarColor(0, 0.5, 1, 0.9)
    resourceBar:SetOrientation("VERTICAL")
    resourceBar:SetReverseFill(false)
    resourceBar:SetFrameLevel(bar:GetFrameLevel())
    local rBg = resourceBar:CreateTexture(nil, "BACKGROUND")
    rBg:SetAllPoints(resourceBar)
    rBg:SetColorTexture(0, 0, 0, 0.5)

    for _, threshold in ipairs(RESOURCE_THRESHOLDS) do
        local line = resourceBar:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1, 0.85)
        line:SetHeight(2)
        resourceThresholdLines[threshold] = line
    end

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
    local config = CurrentConfig()
    if not bar then return end
    if config.hideExternalBar then
        bar:Hide()
    else
        bar:Show()
        healthBar:Show()
        UpdateResourceBarLayout()
        UpdateSpecialResources()
    end
end

local UpdateBar

UpdateBar = function(absorb, maxHP)
    local config = CurrentConfig()
    if not bar then CreateBar() end
    if not bar then return end
    if config.hideExternalBar then
        bar:Hide()
        return
    end
    bar:Show()
    absorb = absorb or GetAbsorbAmount("player")
    maxHP = maxHP or UnitHealthMax("player") or 1
    local currentHP = UnitHealth("player") or maxHP
    healthBar:Show()
    healthBar:SetMinMaxValues(0, maxHP)
    healthBar:SetValue(currentHP)

    local displayMax = maxHP * SHIELD_CAP_MULTIPLIER
    if displayMax > 0 then
        bar:SetMinMaxValues(0, displayMax)
        bar:SetValue(absorb)
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end

    resourceBar:Show()
    local curPower = UnitPower("player") or 0
    local maxPower = UnitPowerMax("player") or 1
    if maxPower <= 0 then maxPower = 1 end
    resourceBar:SetMinMaxValues(0, maxPower)
    resourceBar:SetValue(curPower)
    UpdateSpecialResources()
end

addon.PlayerBarAPI = {
    IsLocked = function() return CurrentConfig().locked end,
    SetLocked = function(locked)
        return addon.PlayerBarConfig.Set("locked", locked == true)
    end,
    SetHidden = function(hidden)
        return addon.PlayerBarConfig.Set("hideExternalBar", hidden == true)
    end,
    ApplyDimensions = function(width, height)
        return addon.SetPlayerBarDimensions(width, height)
    end,
    Reset = function()
        addon.PlayerBarConfig.Reset()
        local config = CurrentConfig()
        if addon.SetClassResourceOverlayEnabled then addon.SetClassResourceOverlayEnabled(config.showClassResourceOverlay) end
        if addon.SetClassResourceOverlayPipSize then addon.SetClassResourceOverlayPipSize(config.classResourcePipWidth, config.classResourcePipHeight) end
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
            bar:SetSize(config.width, config.height)
            UpdateBarLock()
        end
        UpdateExternalBarVisibility()
        UpdateBar()
    end,
}

local function HandleConfigChange(change)
    if not change or not change.key then return end
    local config = CurrentConfig()
    if change.key == "locked" then
        UpdateBarLock()
    elseif change.key == "hideExternalBar" then
        UpdateExternalBarVisibility()
        if not config.hideExternalBar then UpdateBar() end
    elseif change.key == "width" or change.key == "height" then
        if bar then
            bar:SetSize(config.width or DEFAULTS.width, config.height or DEFAULTS.height)
        end
        UpdateBar()
    elseif change.key == "specialResourcePipWidth" or change.key == "specialResourcePipHeight" then
        UpdateSpecialResourcesLayout()
    elseif change.key == "point" or change.key == "relativePoint" or change.key == "xOffset" or change.key == "yOffset" then
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
        end
    end
end

addon.RegisterInitializer(function()
    local config = CurrentConfig()
    if addon.SetClassResourceOverlayEnabled then addon.SetClassResourceOverlayEnabled(config.showClassResourceOverlay) end
    if addon.SetClassResourceOverlayPipSize then addon.SetClassResourceOverlayPipSize(config.classResourcePipWidth, config.classResourcePipHeight) end
    if addon.SetSpecialResourcePipSize then addon.SetSpecialResourcePipSize(config.specialResourcePipWidth, config.specialResourcePipHeight) end
    addon.PlayerBarConfig.Subscribe(HandleConfigChange)
    UpdateBar()
    addon.RegisterPlayerUpdateListener(UpdateBar)
end)

addon.RegisterSpecialResourceListener(function()
    UpdateSpecialResources()
end)
