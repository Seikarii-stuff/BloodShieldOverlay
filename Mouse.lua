-- Cursor overlay: special resources on the left, cooldowns on the right.
-- Resource state/layout is shared with the existing resource provider/renderer.
-- Cooldowns are ordinary Blizzard Cooldown frames; the game paints their timer.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local GetCursorPosition = GetCursorPosition
local UIParent = UIParent
local Enum = Enum
local InCombatLockdown = InCombatLockdown
local math_min = math.min
local math_max = math.max
local math_cos = math.cos
local math_sin = math.sin
local PI = math.pi

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local resourceProvider = addon.GetSpecialResourceProvider and addon.GetSpecialResourceProvider(playerClass, powerTypes)

local MAX_PIPS = 7
local PIP_SIZE = 5
local PIP_GAP = 3
local CURSOR_RADIUS = 10
local UPDATE_INTERVAL = 0.033
local COOLDOWN_SIZE = 8
local COOLDOWN_GAP = 3

local enabled = false
local overlay
local pips = {}
local cooldownFrames = {}
local progress = {}
local pipOrder = {}
local lastElapsed = 0

for index = 1, MAX_PIPS do
    progress[index] = 0
    pipOrder[index] = index
end

local function ApplyCircularMask(texture)
    local parent = texture:GetParent()
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )
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

local function CreateCooldown(parent, index)
    local frame = CreateFrame("Cooldown", "BloodShieldOverlayMouseCooldown" .. index, parent, "CooldownFrameTemplate")
    frame:SetSize(COOLDOWN_SIZE, COOLDOWN_SIZE)
    frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 6)
    frame:EnableMouse(false)
    if frame.SetDrawEdge then frame:SetDrawEdge(false) end
    if frame.SetUseCircularEdge then frame:SetUseCircularEdge(true) end
    if frame.SetDrawSwipe then frame:SetDrawSwipe(true) end
    if frame.SetDrawBling then frame:SetDrawBling(false) end
    if frame.SetReverse then frame:SetReverse(false) end
    if frame.SetHideCountdownNumbers then frame:SetHideCountdownNumbers(true) end
    if frame.SetSwipeTexture then frame:SetSwipeTexture("Interface\\Masks\\CircleMaskScalable") end
    frame.BSOMouseSpellID = nil
    frame:Hide()
    return frame
end

local function EnsureOverlay()
    if overlay then return end

    overlay = CreateFrame("Frame", "BloodShieldOverlayMouseResources", UIParent)
    overlay:SetSize(48, 30)
    overlay:SetFrameStrata("HIGH")
    overlay:EnableMouse(false)
    overlay:Hide()

    for index = 1, MAX_PIPS do
        pips[index] = CreateCircularPip(overlay, index)
    end
    for index = 1, 2 do
        cooldownFrames[index] = CreateCooldown(overlay, index)
    end
end

local function GetMouseCooldownOptions()
    local data = addon.Data and addon.Data.MOUSE_COOLDOWNS
    local bySpec = addon.Data and addon.Data.MOUSE_COOLDOWNS_BY_SPEC
    if not data then return nil end

    local specIndex = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and select(1, GetSpecializationInfo(specIndex))
    if specID and bySpec and bySpec[specID] then
        return bySpec[specID]
    end
    return data[playerClass]
end

local function IsSpellKnown(spellID)
    if not spellID then return false end
    if IsPlayerSpell then return IsPlayerSpell(spellID) end
    if IsSpellKnown then return IsSpellKnown(spellID) end
    return true
end

local function FindSpellEntry(spellID)
    if not spellID then return nil end
    local options = GetMouseCooldownOptions()
    if not options then return nil end
    for index = 1, #options do
        local entry = options[index]
        local id = type(entry) == "number" and entry or entry.id
        if id == spellID then return entry end
    end
    return nil
end

local function ApplyCooldown(frame, spellID)
    if not frame then return false end
    if not spellID or not FindSpellEntry(spellID) or not IsSpellKnown(spellID) then
        frame.BSOMouseSpellID = nil
        frame:Hide()
        return false
    end

    frame.BSOMouseSpellID = spellID
    local applied = false
    if C_Spell and C_Spell.GetSpellCooldownDuration and frame.SetCooldownFromDurationObject then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            frame:SetCooldownFromDurationObject(duration)
            applied = true
        end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            if frame.SetCooldownFromExpression then
                frame:SetCooldownFromExpression(spellID)
            elseif frame.SetCooldownTable then
                frame:SetCooldownTable(info)
            end
            applied = true
        end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start and duration then
            frame:SetCooldown(start, duration)
            applied = true
        end
    end

    frame:Show()
    return applied
end

local function GetConfig()
    return addon.PlayerBarConfig and addon.PlayerBarConfig.Initialize()
end

local function UpdateResourcePips()
    if not resourceProvider or not overlay then return end

    local state = resourceProvider:GetState()
    local maximum = addon.RenderResourcePips(state, pips, progress, pipOrder, MAX_PIPS)
    maximum = math_min(maximum, MAX_PIPS)

    if maximum <= 0 then
        for index = 1, MAX_PIPS do pips[index]:Hide() end
        return
    end

    local radius = CURSOR_RADIUS
    local centerX = overlay:GetWidth() * 0.5
    local centerY = overlay:GetHeight() * 0.5
    local step = PI / math_max(1, maximum - 1)

    for index = 1, MAX_PIPS do
        local pip = pips[pipOrder[index]]
        if index <= maximum then
            -- Left semicircle, now ordered top-to-bottom so the available/first
            -- resource is at the natural top position rather than the bottom.
            local angle = (PI * 0.5) + (index - 1) * step
            pip:ClearAllPoints()
            pip:SetPoint(
                "CENTER", overlay, "CENTER",
                math_cos(angle) * radius,
                math_sin(angle) * radius
            )
            pip:Show()
        else
            pip:Hide()
        end
    end
end

local function UpdateCooldowns()
    local config = GetConfig()
    if not config or not overlay then return end

    local anyVisible = false
    local ids = { config.mouseCooldown1Spell, config.mouseCooldown2Spell }
    local centerX = overlay:GetWidth() * 0.5
    local centerY = overlay:GetHeight() * 0.5
    local radius = CURSOR_RADIUS

    for index = 1, 2 do
        local frame = cooldownFrames[index]
        local spellID = config["mouseCooldown" .. index .. "Spell"]
        local enabledSlot = config["showMouseCooldown" .. index] == true
        if enabledSlot and spellID then
            if ApplyCooldown(frame, spellID) then anyVisible = true end
            local angle = (PI * 1.5) - (index - 1) * (COOLDOWN_SIZE + COOLDOWN_GAP) / math_max(radius, 1)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", overlay, "CENTER", math_cos(angle) * radius, math_sin(angle) * radius)
        else
            frame.BSOMouseSpellID = nil
            frame:Hide()
        end
    end
    return anyVisible
end

local function UpdateVisuals()
    if not enabled or not overlay then return end
    UpdateResourcePips()
    UpdateCooldowns()

    local resourceVisible = resourceProvider ~= nil
    local cooldownVisible = false
    for index = 1, 2 do
        if cooldownFrames[index]:IsShown() then cooldownVisible = true break end
    end
    if resourceVisible or cooldownVisible then overlay:Show() else overlay:Hide() end
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

    if InCombatLockdown() then return true end
    UpdateVisuals()
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
    UpdateVisuals()
    UpdateCursorPosition()
end

EnsureOverlay()
overlay:SetScript("OnUpdate", OnUpdate)

addon.GetMouseCooldownOptions = GetMouseCooldownOptions
addon.SetMouseResourceOverlayEnabled = SetEnabled
addon.UpdateMouseResourceOverlay = Refresh
addon.RefreshMouseCooldowns = UpdateCooldowns

if addon.RegisterSpecialResourceListener then
    addon.RegisterSpecialResourceListener(Refresh)
end

addon.RegisterInitializer(function()
    local config = addon.PlayerBarConfig.Initialize()
    SetEnabled(config.showMouseSpecialResources or config.showMouseCooldown1 or config.showMouseCooldown2)
end)
