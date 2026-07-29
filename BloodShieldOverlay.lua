-- BloodShieldOverlay.lua
-- Tracks the Blood DK Mastery: Blood Shield (Spell ID: 77535)

local BLOOD_SHIELD_SPELL_ID = 77535
local addon = CreateFrame("Frame")

-- Helper function to get the current Blood Shield absorb amount
local function GetBloodShieldAmount()
    -- Retail exposes the actual absorb value through the unit's total absorbs.
    -- We use that first because it is the most reliable source for Blood Shield.
    if UnitGetTotalAbsorbs then
        local absorb = UnitGetTotalAbsorbs("player")
        if absorb and absorb > 0 then
            return absorb
        end
    end

    -- Fallback for older or less direct aura data.
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(BLOOD_SHIELD_SPELL_ID)
    if aura then
        if type(aura.points) == "number" then
            return aura.points
        end

        if type(aura.points) == "table" and #aura.points > 0 then
            return aura.points[1] or 0
        end

        if aura.absorbAmount and aura.absorbAmount > 0 then
            return aura.absorbAmount
        end

        if aura.amount and aura.amount > 0 then
            return aura.amount
        end
    end

    return 0
end

-- ==========================================
-- PLAYER FRAME BAR
-- ==========================================
local playerShieldBar
local playerShieldText

local function SetupPlayerBar()
    if playerShieldBar then
        return
    end

    if not PlayerFrameHealthBar then
        return
    end

    playerShieldBar = CreateFrame("StatusBar", "BloodShieldPlayerBar", PlayerFrameHealthBar)
    playerShieldBar:SetPoint("TOPLEFT", PlayerFrameHealthBar, "TOPLEFT", 0, 0)
    playerShieldBar:SetPoint("BOTTOMRIGHT", PlayerFrameHealthBar, "BOTTOMRIGHT", 0, 0)
    playerShieldBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    -- Dark red semi-transparent color for Death Knight vibes
    playerShieldBar:SetStatusBarColor(0.7, 0.1, 0.1, 0.65)
    playerShieldBar:SetFrameStrata("MEDIUM")
    playerShieldBar:SetFrameLevel(PlayerFrameHealthBar:GetFrameLevel() + 5)
    playerShieldBar:SetMinMaxValues(0, 1)
    playerShieldBar:SetValue(0)
    playerShieldBar:Hide()

    -- Optional: Add text to show exact value on the player frame
    playerShieldText = playerShieldBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    playerShieldText:SetPoint("CENTER", playerShieldBar, "CENTER", 0, 0)
    playerShieldText:SetTextColor(1, 1, 1, 1)
    playerShieldText:SetText("")
end

local function UpdatePlayerBar()
    SetupPlayerBar()
    if not playerShieldBar then return end

    local shield = GetBloodShieldAmount()
    local maxHP = UnitHealthMax("player")

    if maxHP and maxHP > 0 then
        playerShieldBar:SetMinMaxValues(0, maxHP)
        playerShieldBar:SetValue(shield)

        if shield > 0 then
            playerShieldBar:Show()
            playerShieldText:SetText(tostring(shield))
        else
            playerShieldBar:Hide()
            playerShieldText:SetText("")
        end
    else
        playerShieldBar:Hide()
        playerShieldText:SetText("")
    end
end

-- ==========================================
-- COMPACT RAID / PARTY FRAMES
-- ==========================================
local function UpdateCompactFrame(frame)
    -- Ensure the frame exists, is shown, and is the player's frame
    if not frame or not frame.unit or not frame.healthBar then return end
    if not UnitIsUnit(frame.unit, "player") then return end

    -- Create the overlay bar if it doesn't exist yet for this specific frame
    if not frame.bloodShieldBar then
        local bar = CreateFrame("StatusBar", nil, frame.healthBar)
        bar:SetAllPoints(frame.healthBar)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(0.7, 0.1, 0.1, 0.65)
        bar:SetFrameStrata("MEDIUM")
        bar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 5)
        bar:Hide()
        frame.bloodShieldBar = bar
    end

    -- Update the bar values
    local shield = GetBloodShieldAmount()
    local maxHP = UnitHealthMax("player")

    if maxHP > 0 then
        frame.bloodShieldBar:SetMinMaxValues(0, maxHP)
        frame.bloodShieldBar:SetValue(shield)

        if shield > 0 then
            frame.bloodShieldBar:Show()
        else
            frame.bloodShieldBar:Hide()
        end
    end
end

-- ==========================================
-- EVENT HANDLING & HOOKING
-- ==========================================
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("UNIT_AURA")
addon:RegisterEvent("UNIT_MAXHEALTH")
addon:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")

addon:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    
    if event == "PLAYER_LOGIN" then
        -- Delay the setup until the player frames are fully created.
        C_Timer.After(0.1, function()
            SetupPlayerBar()
            UpdatePlayerBar()
        end)
        
        -- Hook the Raid/Party Frame update functions
        if CompactUnitFrame_UpdateHealth then
            hooksecurefunc("CompactUnitFrame_UpdateHealth", UpdateCompactFrame)
        end
        if CompactUnitFrame_UpdateAuras then
            hooksecurefunc("CompactUnitFrame_UpdateAuras", UpdateCompactFrame)
        end
        if CompactUnitFrame_UpdateAll then
            hooksecurefunc("CompactUnitFrame_UpdateAll", UpdateCompactFrame)
        end
        
    elseif event == "UNIT_AURA" or event == "UNIT_MAXHEALTH" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        -- Only trigger if the aura/health/absorb change happened to the player
        if arg1 == "player" then
            UpdatePlayerBar()
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Delay update slightly to ensure frames are fully loaded
        C_Timer.After(0.2, function()
            SetupPlayerBar()
            UpdatePlayerBar()
        end)
    end
end)