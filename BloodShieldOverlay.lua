-- BloodShieldOverlay.lua
-- Simple debug bar for Blood Shield absorb amount

local addon = CreateFrame("Frame")
local shieldBar
local shieldText
local debugEnabled = true

local function DebugPrint(message)
    if debugEnabled then
        print("|cffff6600BloodShieldOverlay|r " .. message)
    end
end

local function GetAbsorbAmount()
    if UnitGetTotalAbsorbs then
        local absorb = UnitGetTotalAbsorbs("player") or 0
        DebugPrint(string.format("total absorb amount=%s", tostring(absorb)))
        return absorb
    end

    DebugPrint("UnitGetTotalAbsorbs unavailable")
    return 0
end

local function SetupDebugBar()
    if shieldBar then
        return
    end

    shieldBar = CreateFrame("StatusBar", "BloodShieldDebugBar", UIParent)
    shieldBar:SetSize(320, 24)
    shieldBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 90)
    shieldBar:SetMinMaxValues(0, 1)
    shieldBar:SetValue(0)
    shieldBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    shieldBar:SetStatusBarColor(0.7, 0.1, 0.1, 0.85)
    shieldBar:SetFrameStrata("HIGH")
    shieldBar:SetFrameLevel(20)
    shieldBar:Show()

    local bg = shieldBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(shieldBar)
    bg:SetColorTexture(0, 0, 0, 0.35)

    shieldText = shieldBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    shieldText:SetPoint("CENTER", shieldBar, "CENTER", 0, 0)
    shieldText:SetTextColor(1, 1, 1, 1)
    shieldText:SetText("Absorb: 0")
end

local function UpdateDebugBar()
    SetupDebugBar()
    if not shieldBar then
        return
    end

    local absorb = GetAbsorbAmount()
    local maxHP = UnitHealthMax("player")
    if maxHP and maxHP > 0 then
        shieldBar:SetMinMaxValues(0, maxHP)
    else
        shieldBar:SetMinMaxValues(0, 1)
    end

    shieldBar:SetValue(absorb)
    shieldText:SetText(string.format("Absorb: %d", absorb))
end

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("UNIT_AURA")
addon:RegisterEvent("UNIT_MAXHEALTH")
addon:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")

addon:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.2, UpdateDebugBar)
    elseif event == "UNIT_AURA" or event == "UNIT_MAXHEALTH" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        if arg1 == "player" then
            UpdateDebugBar()
        end
    end
end)
