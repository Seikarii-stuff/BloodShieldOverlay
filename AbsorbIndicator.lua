-- Reusable, mouse-transparent absorb overlay for a unit health bar.
-- # DEV: This module provides a lightweight overlay helper for any status bar.
-- # DEV: It is intentionally kept independent from frame discovery and update logic.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local OVERLAY_ALPHA = 0.35
local issecretvalue = issecretvalue

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

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
    -- Skip the SetMinMaxValues/SetValue pair (each recomputes the statusbar
    -- texture) when nothing actually changed since the last update. Cheap
    -- early-return that matters most in combat, where many throttle ticks
    -- carry no real absorb change.
    --
    -- UnitGetTotalAbsorbs() can return a secret number on Retail. Tainted Lua
    -- code must not compare, store-and-read, or otherwise inspect that value.
    -- StatusBar:SetValue() is deliberately called with the value directly;
    -- Blizzard's status bar implementation is the supported consumer for it.
    local absorbIsSecret = IsSecretValue(absorb)
    local maxHealthIsSecret = IsSecretValue(maxHealth)
    if not absorbIsSecret and not maxHealthIsSecret then
        if overlay:IsShown() and overlay.lastAbsorb == absorb and overlay.lastMaxHealth == maxHealth then
            return
        end

        overlay.lastAbsorb = absorb
        overlay.lastMaxHealth = maxHealth
    else
        -- Never retain a secret value in addon-owned state. Clearing both
        -- cache fields also prevents a later public update from comparing
        -- against a secret value received by an earlier update.
        overlay.lastAbsorb = nil
        overlay.lastMaxHealth = nil
    end

    overlay:SetMinMaxValues(0, maxHealth)
    overlay:SetValue(absorb)
    overlay:Show()
end
