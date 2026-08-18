local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local MouseCooldowns = {}
addon.MouseCooldowns = MouseCooldowns

local CreateFrame = CreateFrame
local GetSpellTexture = _G.GetSpellTexture

local DEFAULT_COOLDOWN_SIZE = 12
local MIN_COOLDOWN_SIZE = 4
local MAX_COOLDOWN_SIZE = 24
local CHARGE_FONT_SIZE = 9
local GLOW_PULSE_SPEED = 3.2
local SLOT_ANGLES = { math.pi / 6, math.pi * 1.5 }
local CURSOR_RADIUS = 17

local frames = {}
local actionButtonCache = {}
local config
local parent

local function GetOptions()
    local data = addon.Data and addon.Data.MOUSE_COOLDOWNS
    if not data then return {} end
    local _, playerClass = UnitClass("player")
    return data[playerClass] or {}
end

function MouseCooldowns:GetOptions()
    return GetOptions()
end

local function FindSpellEntry(spellID)
    if not spellID then return nil end
    for _, entry in ipairs(GetOptions()) do
        local id = type(entry) == "number" and entry or entry.id
        if id == spellID then return entry end
    end
    return nil
end

local function GetSpellTextureSafe(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(spellID)
        if texture then return texture end
    end
    if GetSpellTexture then return GetSpellTexture(spellID) end
    return nil
end

local function ResolveBaseSpellID(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetBaseSpell then
        local baseID = C_Spell.GetBaseSpell(spellID)
        if baseID and baseID > 0 then return baseID end
    end
    return spellID
end

local function GetActionDisplayCount(spellID)
    if not spellID or not C_ActionBar or not C_ActionBar.FindSpellActionButtons or not C_ActionBar.GetActionDisplayCount then
        return nil
    end

    local baseID = ResolveBaseSpellID(spellID)
    if not baseID then return nil end

    local actionID = actionButtonCache[baseID]
    if actionID == nil then
        local buttons = C_ActionBar.FindSpellActionButtons(baseID)
        actionID = buttons and buttons[1] or false
        actionButtonCache[baseID] = actionID
    end
    if not actionID then return nil end

    return C_ActionBar.GetActionDisplayCount(actionID)
end

local function UpdateCharges(frame, spellID)
    local text = frame.BSOMouseChargeText
    if not text then return end

    local displayCount = GetActionDisplayCount(spellID)
    if displayCount ~= nil then
        text:SetText(displayCount)
        text:Show()
        return
    end

    if C_Spell and C_Spell.GetSpellCharges then
        local charges = C_Spell.GetSpellCharges(spellID)
        if charges and charges.maxCharges and charges.maxCharges > 1 and charges.currentCharges ~= nil then
            text:SetText(charges.currentCharges)
            text:Show()
            return
        end
    end

    if C_Spell and C_Spell.GetSpellDisplayCount then
        local displayCount = C_Spell.GetSpellDisplayCount(spellID)
        if displayCount ~= nil then
            text:SetText(displayCount)
            text:Show()
            return
        end
    end

    text:SetText(nil)
    text:Hide()
end

local function CreateCooldownFrame(index)
    local frame = CreateFrame("Button", "BloodShieldOverlayMouseCooldown" .. index, parent)
    frame:SetSize(DEFAULT_COOLDOWN_SIZE, DEFAULT_COOLDOWN_SIZE)
    frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 6)
    frame:EnableMouse(false)
    frame:Hide()

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.BSOMouseIcon = icon

    local chargeText = frame:CreateFontString(nil, "OVERLAY")
    chargeText:SetPoint("RIGHT", frame, "RIGHT", -0.5, 0)
    chargeText:SetJustifyH("RIGHT")
    chargeText:SetJustifyV("MIDDLE")
    chargeText:SetFont(STANDARD_TEXT_FONT, CHARGE_FONT_SIZE, "OUTLINE")
    chargeText:SetTextColor(1, 1, 1, 1)
    chargeText:SetShadowOffset(0, 0)
    chargeText:Hide()
    frame.BSOMouseChargeText = chargeText

    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -7, 7)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 7, -7)
    glow:SetVertexColor(1.0, 0.55, 0.02, 1.0)
    glow:SetAlpha(0)
    glow:Hide()
    frame.BSOMouseGlow = glow

    local flash = frame:CreateTexture(nil, "OVERLAY")
    flash:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    flash:SetBlendMode("ADD")
    flash:SetPoint("TOPLEFT", frame, "TOPLEFT", -11, 11)
    flash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 11, -11)
    flash:SetVertexColor(1.0, 0.82, 0.15, 1.0)
    flash:SetAlpha(0)
    flash:Hide()
    frame.BSOMouseGlowFlash = flash

    local cooldown = CreateFrame("Cooldown", "BloodShieldOverlayMouseCooldownTimer" .. index, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetFrameLevel((frame:GetFrameLevel() or 0) + 1)
    cooldown:EnableMouse(false)
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetReverse then cooldown:SetReverse(false) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture("Interface\\Masks\\CircleMaskScalable") end

    frame.BSOMouseCooldown = cooldown
    frame.BSOMouseSpellID = nil
    frame.BSOMouseGlowActive = false
    frame.BSOMouseGlowPhase = 0
    return frame
end

local function SetSpellGlow(frame, active)
    if not frame then return end
    frame.BSOMouseGlowActive = active == true
    if frame.BSOMouseGlowActive then
        frame.BSOMouseGlowPhase = 0
        frame.BSOMouseGlow:Show()
        frame.BSOMouseGlowFlash:Show()
        frame.BSOMouseGlow:SetAlpha(1.0)
        frame.BSOMouseGlowFlash:SetAlpha(1.0)
    else
        frame.BSOMouseGlow:Hide()
        frame.BSOMouseGlowFlash:Hide()
        frame.BSOMouseGlow:SetAlpha(0)
        frame.BSOMouseGlowFlash:SetAlpha(0)
    end
end

local function RefreshSpellGlow(frame)
    if not frame or not frame.BSOMouseSpellID then
        SetSpellGlow(frame, false)
        return
    end

    local active = false
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        active = C_SpellActivationOverlay.IsSpellOverlayed(frame.BSOMouseSpellID) == true
    end
    SetSpellGlow(frame, active)
end

local function UpdateSpellGlow(frame, elapsed)
    if not frame or not frame.BSOMouseGlowActive then return end

    frame.BSOMouseGlowPhase = (frame.BSOMouseGlowPhase or 0) + elapsed * GLOW_PULSE_SPEED
    local wave = (math.sin(frame.BSOMouseGlowPhase) + 1) * 0.5
    local flashWave = math.max(0, math.cos(frame.BSOMouseGlowPhase * 0.5))
    frame.BSOMouseGlow:SetAlpha(0.65 + wave * 0.35)
    frame.BSOMouseGlowFlash:SetAlpha(0.12 + flashWave * 0.72)
end

local function ClearFrame(frame)
    frame.BSOMouseSpellID = nil
    SetSpellGlow(frame, false)
    frame.BSOMouseIcon:SetTexture(nil)
    frame.BSOMouseChargeText:Hide()
    frame.BSOMouseCooldown:Clear()
    frame:Hide()
end

local function ApplyCooldown(frame, spellID)
    if not spellID or not FindSpellEntry(spellID) then
        ClearFrame(frame)
        return false
    end

    local iconTexture = GetSpellTextureSafe(spellID)
    if not iconTexture then
        ClearFrame(frame)
        return false
    end

    frame.BSOMouseSpellID = spellID
    frame.BSOMouseIcon:SetTexture(iconTexture)
    RefreshSpellGlow(frame)
    UpdateCharges(frame, spellID)

    local cooldown = frame.BSOMouseCooldown
    if C_Spell and C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then cooldown:SetCooldownFromDurationObject(duration) end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            if cooldown.SetCooldownFromExpression then
                cooldown:SetCooldownFromExpression(spellID)
            elseif cooldown.SetCooldownTable then
                cooldown:SetCooldownTable(info)
            end
        end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start and duration then cooldown:SetCooldown(start, duration) end
    end

    frame:Show()
    return true
end

function MouseCooldowns:Initialize(container)
    if parent then return end
    parent = container
    for index = 1, 2 do
        frames[index] = CreateCooldownFrame(index)
    end
end

function MouseCooldowns:Configure(newConfig)
    config = newConfig
end

function MouseCooldowns:GetFrames()
    return frames
end

function MouseCooldowns:InvalidateActionButtonCache()
    for key in pairs(actionButtonCache) do
        actionButtonCache[key] = nil
    end
end

function MouseCooldowns:Hide()
    for index = 1, 2 do
        ClearFrame(frames[index])
    end
end

function MouseCooldowns:Update()
    if not config or not parent then return false end

    local anyVisible = false
    local size = tonumber(config.mouseCooldownPipSize) or DEFAULT_COOLDOWN_SIZE
    size = math.max(MIN_COOLDOWN_SIZE, math.min(MAX_COOLDOWN_SIZE, size))

    for index = 1, 2 do
        local frame = frames[index]
        frame:SetSize(size, size)

        local spellID = config["mouseCooldown" .. index .. "Spell"]
        local enabled = config["showMouseCooldown" .. index] == true
        if enabled and spellID then
            if ApplyCooldown(frame, spellID) then
                anyVisible = true
            end
            local angle = SLOT_ANGLES[index]
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", parent, "CENTER", math.cos(angle) * CURSOR_RADIUS, math.sin(angle) * CURSOR_RADIUS)
        else
            ClearFrame(frame)
        end
    end

    return anyVisible
end

function MouseCooldowns:UpdateGlow(elapsed)
    for index = 1, 2 do
        UpdateSpellGlow(frames[index], elapsed)
    end
end

function MouseCooldowns:HandleGlowEvent(event, spellID)
    if event ~= "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" and event ~= "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        return false
    end

    for index = 1, 2 do
        local frame = frames[index]
        if frame.BSOMouseSpellID == spellID then
            SetSpellGlow(frame, event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        end
    end
    return true
end

function MouseCooldowns:RefreshGlows()
    for index = 1, 2 do
        RefreshSpellGlow(frames[index])
    end
end
