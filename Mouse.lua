-- Cursor-side special-resource overlay.
-- Reuses the shared special-resource provider/state renderer; only the presentation
-- (circular pips + left semicircle placement) is unique to this module.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local Enum = Enum
local InCombatLockdown = InCombatLockdown
local math_min = math.min
local math_max = math.max
local math_cos = math.cos
local math_sin = math.sin
local PI = math.pi

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local resourceProvider = addon.GetSpecialResourceProvider(playerClass, powerTypes)
if not resourceProvider then return end

local MAX_PIPS = 7
local PIP_SIZE = 10
local PIP_GAP = 3
local CURSOR_RADIUS = 22
local UPDATE_INTERVAL = 0.033

local enabled = false
local overlay
local pips = {}
local progress = {}
local pipOrder = {}
local lastElapsed = 0

for index = 1, MAX_PIPS do
    progress[index] = 0
    pipOrder[index] = index
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

    -- Same supported circular mask pattern used by Minimizer.Widgets.CreatePip.
    local fill = pip:GetStatusBarTexture()
    if fill and fill.AddMaskTexture then
        local mask = pip:CreateMaskTexture()
        mask:SetAllPoints(fill)
        mask:SetTexture(
            "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE",
            "CLAMPTOBLACKADDITIVE"
        )
        fill:AddMaskTexture(mask)
        pip.BSOMouseMask = mask
    end

    pip.BSOMouseIndex = index
    pip:Hide()
    return pip
end

local function EnsureOverlay()
    if overlay then return end

    overlay = CreateFrame("Frame", "BloodShieldOverlayMouseResources", UIParent)
    overlay:SetSize(PIP_SIZE * MAX_PIPS + PIP_GAP * (MAX_PIPS - 1), PIP_SIZE * 2 + CURSOR_RADIUS)
    overlay:SetFrameStrata("HIGH")
    overlay:EnableMouse(false)
    overlay:Hide()

    for index = 1, MAX_PIPS do
        pips[index] = CreateCircularPip(overlay, index)
    end
end

local function UpdatePips()
    if not enabled or not overlay then return end

    local state = resourceProvider:GetState()
    local maximum = addon.RenderResourcePips(
        state, pips, progress, pipOrder, MAX_PIPS
    )
    maximum = math_min(maximum, MAX_PIPS)

    if maximum <= 0 then
        overlay:Hide()
        return
    end

    local diameter = PIP_SIZE
    local radius = CURSOR_RADIUS
    local centerX = radius + diameter * 0.5
    local centerY = overlay:GetHeight() * 0.5
    local step = PI / math_max(1, maximum - 1)

    for index = 1, MAX_PIPS do
        local pip = pips[pipOrder[index]]
        if index <= maximum then
            -- Left semicircle, ordered bottom-to-top while preserving the
            -- provider's existing pip order. The final/last resource remains
            -- at the upper end of the arc.
            local angle = (PI * 1.5) - (index - 1) * step
            pip:ClearAllPoints()
            pip:SetPoint(
                "CENTER", overlay, "BOTTOMLEFT",
                centerX + math_cos(angle) * radius,
                centerY + math_sin(angle) * radius
            )
            pip:Show()
        else
            pip:Hide()
        end
    end

    overlay:Show()
end

local function UpdateCursorPosition()
    if not enabled or not overlay then return end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not cursorX or not cursorY or not scale or scale <= 0 then return end

    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale - 1)
end

local function SetEnabled(value)
    enabled = value and true or false
    EnsureOverlay()

    if not enabled then
        overlay:Hide()
        return true
    end

    if InCombatLockdown() then
        -- This feature only creates/moves ordinary visual frames, but avoid
        -- changing parent/anchor state during combat if the UI is restricted.
        return true
    end

    UpdatePips()
    UpdateCursorPosition()
    return true
end

local function OnUpdate(_, elapsed)
    if not enabled then return end
    lastElapsed = lastElapsed + elapsed
    if lastElapsed < UPDATE_INTERVAL then return end
    lastElapsed = 0
    UpdateCursorPosition()
end

local function Refresh()
    if not enabled then return end
    UpdatePips()
    UpdateCursorPosition()
end

EnsureOverlay()
overlay:SetScript("OnUpdate", OnUpdate)

addon.SetMouseResourceOverlayEnabled = SetEnabled
addon.UpdateMouseResourceOverlay = Refresh

addon.RegisterSpecialResourceListener(Refresh)

addon.RegisterInitializer(function()
    local config = addon.PlayerBarConfig.Initialize()
    SetEnabled(config.showMouseSpecialResources == true)
end)
