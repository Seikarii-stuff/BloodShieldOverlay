-- Reusable, mouse-transparent absorb overlay for a unit health bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local OVERLAY_ALPHA = 0.35

function addon.CreateAbsorbOverlay(healthBar)
    local overlay = CreateFrame("StatusBar", nil, healthBar)
    overlay:SetAllPoints(healthBar)
    overlay:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    overlay:SetStatusBarColor(1, 1, 1, OVERLAY_ALPHA)
    overlay:SetOrientation("HORIZONTAL")
    overlay:SetReverseFill(true)
    overlay:EnableMouse(false)
    overlay:Hide()
    return overlay
end

function addon.UpdateAbsorbOverlay(overlay, absorb, maxHealth)
    overlay:SetMinMaxValues(0, maxHealth)
    overlay:SetValue(absorb)
    overlay:Show()
end
