-- Mouse overlay coordinator.
-- Cursor tracking stays here; resource rendering and cooldown rendering live in
-- MouseResources.lua and MouseCooldowns.lua respectively.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local UIParent = UIParent
local GetTime = GetTime

local CURSOR_UPDATE_INTERVAL = 0.006944
local RESOURCE_UPDATE_INTERVAL = 0.033333

local enabled = false
local overlay
local mouseConfig
local cursorElapsed, resourceElapsed = 0, 0

local function GetConfig()
    if mouseConfig then return mouseConfig end
    if addon.PlayerBarConfig and addon.PlayerBarConfig.Get then
        mouseConfig = addon.PlayerBarConfig.Get()
    elseif addon.PlayerBarConfig and addon.PlayerBarConfig.Initialize then
        mouseConfig = addon.PlayerBarConfig.Initialize()
    end
    return mouseConfig
end

local function EnsureOverlay()
    if overlay then return end

    overlay = CreateFrame("Frame", "BloodShieldOverlayMouseResources", UIParent)
    overlay:SetSize(48, 30)
    overlay:SetFrameStrata("HIGH")
    overlay:EnableMouse(false)
    overlay:Hide()

    addon.MouseResources:Initialize(overlay)
    addon.MouseCooldowns:Initialize(overlay)
end

local function UpdateCursorPosition()
    if not enabled or not overlay then return end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not cursorX or not cursorY or not scale or scale <= 0 then return end

    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale - 1)
end

local function UpdateVisuals()
    if not enabled or not overlay then return end

    local config = GetConfig()
    local resourceVisible = addon.MouseResources:Update(config) > 0
    addon.MouseCooldowns:Configure(config)
    local cooldownVisible = addon.MouseCooldowns:Update()

    if resourceVisible or cooldownVisible then
        overlay:Show()
    else
        overlay:Hide()
    end
end

local function SetEnabled(value)
    enabled = value == true
    EnsureOverlay()

    if not enabled then
        overlay:Hide()
        addon.MouseResources:Hide()
        addon.MouseCooldowns:Hide()
        return true
    end

    UpdateVisuals()
    UpdateCursorPosition()
    return true
end

local function Refresh()
    if not enabled then return end
    UpdateVisuals()
    UpdateCursorPosition()
end

local function OnUpdate(_, elapsed)
    if not enabled then return end

    cursorElapsed = cursorElapsed + elapsed
    if cursorElapsed >= CURSOR_UPDATE_INTERVAL then
        cursorElapsed = 0
        UpdateCursorPosition()
    end

    resourceElapsed = resourceElapsed + elapsed
    if resourceElapsed >= RESOURCE_UPDATE_INTERVAL then
        resourceElapsed = 0
        addon.MouseResources:RefreshCharging(GetConfig(), GetTime)
    end

    -- The proc glow is deliberately visual-only and is the only other piece
    -- of Mouse work allowed to run every frame.
    addon.MouseCooldowns:UpdateGlow(elapsed)
end

local function OnEvent(_, event, spellID)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        addon.MouseCooldowns:HandleGlowEvent(event, spellID)
        return
    end

    if event == "ACTIONBAR_SLOT_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        addon.MouseCooldowns:InvalidateActionButtonCache()
    end

    Refresh()
end

EnsureOverlay()
overlay:SetScript("OnUpdate", OnUpdate)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
eventFrame:SetScript("OnEvent", OnEvent)

addon.GetMouseCooldownOptions = function()
    return addon.MouseCooldowns and addon.MouseCooldowns.GetOptions and addon.MouseCooldowns:GetOptions() or {}
end
addon.SetMouseResourceOverlayEnabled = SetEnabled
addon.UpdateMouseResourceOverlay = Refresh
addon.RefreshMouseCooldowns = Refresh

if addon.RegisterSpecialResourceListener then
    addon.RegisterSpecialResourceListener(Refresh)
end

addon.RegisterInitializer(function()
    mouseConfig = addon.PlayerBarConfig.Initialize()
    SetEnabled(
        mouseConfig.showMouseSpecialResources == true
        or mouseConfig.showMouseCooldown1 == true
        or mouseConfig.showMouseCooldown2 == true
    )
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    end
end)
