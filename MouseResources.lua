local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local MouseResources = {}
addon.MouseResources = MouseResources

local math_min, math_max = math.min, math.max
local math_cos, math_sin = math.cos, math.sin
local PI = math.pi
local Enum = Enum
local CreateFrame = CreateFrame

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local MAX_PIPS = 7
local PIP_SIZE = 5
local CURSOR_RADIUS = 17

local pips = {}
local progress, pipOrder = {}, {}

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

function MouseResources:Initialize(parent)
    if self.overlay then return end

    self.overlay = parent
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

function MouseResources:Hide()
    for index = 1, MAX_PIPS do
        pips[index]:Hide()
    end
end

function MouseResources:Update(config)
    local overlay = self.overlay
    local resourceProvider = self:GetProvider()
    if not resourceProvider or not overlay or not config or config.showMouseSpecialResources ~= true then
        self:Hide()
        return 0
    end

    local state = resourceProvider:GetState()
    local maximum = addon.RenderResourcePips(state, pips, progress, pipOrder, MAX_PIPS)
    maximum = math_min(maximum, MAX_PIPS)
    if maximum <= 0 then
        self:Hide()
        return 0
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

    return maximum
end

function MouseResources:RefreshCharging(config, GetTime)
    local provider = config and config.showMouseSpecialResources and self:GetProvider()
    if not provider then return end

    local state = provider:GetState()
    if state and state.charging then
        provider:Refresh(GetTime())
        self:Update(config)
    end
end
