local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local MouseResources = {}
addon.MouseResources = MouseResources

local math_min, math_max = math.min, math.max
local math_cos, math_sin = math.cos, math.sin
local PI = math.pi
local Enum = Enum
local CreateFrame = CreateFrame
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local MAX_PIPS = 7
local PIP_SIZE = 5
local CURSOR_RADIUS = 17

local RESOURCE_BAR_WIDTH = 6
local RESOURCE_BAR_HEIGHT = CURSOR_RADIUS * 2
local RESOURCE_BAR_THRESHOLDS = { 0.28, 0.56 }

local pips = {}
local progress, pipOrder = {}, {}
local resourceBar
local resourceBarThresholdLines = {}

for index = 1, MAX_PIPS do
    progress[index] = 0
    pipOrder[index] = index
end

local function ApplyCircularMask(texture)
    local parent = texture:GetParent()
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    texture:AddMaskTexture(mask)
    return mask
end

local function CreateCircularPip(parent, index)
    local pip = CreateFrame("StatusBar", nil, parent)
    pip:SetFrameLevel((parent:GetFrameLevel() or 0) + 2)
    pip:SetSize(PIP_SIZE, PIP_SIZE)
    pip:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    pip:SetStatusBarColor(1, 1, 1, 1)
    pip:SetOrientation("HORIZONTAL")
    pip:SetReverseFill(false)
    pip:EnableMouse(false)

    local background = pip:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.15, 0.15, 0.15, 0.75)
    pip.BSOMouseBackgroundMask = ApplyCircularMask(background)

    local fill = pip:GetStatusBarTexture()
    if fill and fill.AddMaskTexture then
        pip.BSOMouseMask = ApplyCircularMask(fill)
    end

    pip.BSOMouseIndex = index
    pip:Hide()
    return pip
end

local function CreateMouseResourceBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(RESOURCE_BAR_WIDTH, RESOURCE_BAR_HEIGHT)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(0, 0.5, 1, 0.9)
    bar:SetOrientation("VERTICAL")
    bar:SetReverseFill(false)
    bar:EnableMouse(false)
    bar:SetFrameLevel((parent:GetFrameLevel() or 0) + 1)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetColorTexture(0, 0, 0, 0.5)

    for _, threshold in ipairs(RESOURCE_BAR_THRESHOLDS) do
        local line = bar:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1, 0.85)
        line:SetHeight(1)
        line:ClearAllPoints()
        line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, RESOURCE_BAR_HEIGHT * threshold - 1)
        line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, RESOURCE_BAR_HEIGHT * threshold - 1)
        resourceBarThresholdLines[threshold] = line
    end

    bar:Hide()
    return bar
end

function MouseResources:Initialize(parent)
    if self.overlay then return end

    self.overlay = parent
    resourceBar = CreateMouseResourceBar(parent)
    resourceBar:ClearAllPoints()
    resourceBar:SetPoint("CENTER", parent, "CENTER", 0, 0)

    for index = 1, MAX_PIPS do
        pips[index] = CreateCircularPip(parent, index)
    end
end

function MouseResources:GetPips()
    return pips
end

function MouseResources:GetProvider()
    if type(addon.GetSpecialResourceProvider) ~= "function" then return nil end
    return addon.GetSpecialResourceProvider(playerClass, powerTypes)
end

function MouseResources:Hide(keepResourceBar)
    for index = 1, MAX_PIPS do
        pips[index]:Hide()
    end
    if not keepResourceBar and resourceBar then
        resourceBar:Hide()
    end
end

function MouseResources:UpdateResourceBar(config)
    if not resourceBar then return false end

    if not config or config.showMouseResourceBar ~= true then
        resourceBar:Hide()
        return false
    end

    local maxPower = UnitPowerMax("player") or 0
    if maxPower <= 0 then
        resourceBar:Hide()
        return false
    end

    local curPower = UnitPower("player") or 0
    resourceBar:SetMinMaxValues(0, maxPower)
    resourceBar:SetValue(curPower)
    resourceBar:Show()
    return true
end

function MouseResources:Update(config)
    local overlay = self.overlay
    local barVisible = self:UpdateResourceBar(config)

    local resourceProvider = self:GetProvider()
    if not resourceProvider or not overlay or not config or config.showMouseSpecialResources ~= true then
        self:Hide(true)
        return 0, barVisible
    end

    local state = resourceProvider:GetState()
    local maximum = addon.RenderResourcePips(state, pips, progress, pipOrder, MAX_PIPS)
    maximum = math_min(maximum, MAX_PIPS)
    if maximum <= 0 then
        self:Hide(true)
        return 0, barVisible
    end

    local spacing = tonumber(config.mouseResourceArcSpacing) or 1.0
    spacing = math_max(0.5, math_min(1.5, spacing))
    local arcStart = tonumber(config.mouseResourceArcStart) or 0.83
    arcStart = math_max(0.5, math_min(1.5, arcStart))

    local baseStep = PI / math_max(1, maximum - 1)
    local step = baseStep * spacing
    local startAngle = (PI * 0.5) - (baseStep * arcStart)

    for index = 1, MAX_PIPS do
        local pip = pips[pipOrder[index]]
        if index <= maximum then
            local angle = startAngle + (index - 1) * step
            pip:ClearAllPoints()
            pip:SetPoint("CENTER", overlay, "CENTER", math_cos(angle) * CURSOR_RADIUS, math_sin(angle) * CURSOR_RADIUS)
            pip:Show()
        else
            pip:Hide()
        end
    end

    return maximum, barVisible
end

function MouseResources:RefreshCharging(config, GetTime)
    local provider = config and config.showMouseSpecialResources and self:GetProvider()

    if provider then
        local state = provider:GetState()
        if state and state.charging then
            provider:Refresh(GetTime())
            self:Update(config)
            return
        end
    end

    if config and config.showMouseResourceBar == true then
        self:UpdateResourceBar(config)
    end
end
