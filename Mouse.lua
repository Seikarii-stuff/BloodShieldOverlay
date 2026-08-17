-- Cursor overlay: special resources on the left, cooldowns on the right.
-- Blizzard owns cooldown timing; the addon only assigns spell IDs to Cooldown widgets.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local GetCursorPosition = GetCursorPosition
local UIParent = UIParent
local Enum = Enum
local math_min = math.min
local math_max = math.max
local math_cos = math.cos
local math_sin = math.sin
local PI = math.pi

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType

local MAX_PIPS = 7
local PIP_SIZE = 5
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
    if fill and fill.AddMaskTexture then pip.BSOMouseMask = ApplyCircularMask(fill) end
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

    local icon = frame:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(frame)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.BSOMouseIcon = icon
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
    for index = 1, MAX_PIPS do pips[index] = CreateCircularPip(overlay, index) end
    for index = 1, 2 do cooldownFrames[index] = CreateCooldown(overlay, index) end
end

local function GetResourceProvider()
    if type(addon.GetSpecialResourceProvider) ~= "function" then return nil end
    return addon.GetSpecialResourceProvider(playerClass, powerTypes)
end

local function GetMouseCooldownOptions()
    local data = addon.Data and addon.Data.MOUSE_COOLDOWNS
    if not data then return {} end
    return data[playerClass] or {}
end

local function FindSpellEntry(spellID)
    if not spellID then return nil end
    for _, entry in ipairs(GetMouseCooldownOptions()) do
        local id = type(entry) == "number" and entry or entry.id
        if id == spellID then return entry end
    end
    return nil
end

local function GetSpellTexture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(spellID)
        if texture then return texture end
    end
    if GetSpellTexture then
        return GetSpellTexture(spellID)
    end
    return nil
end

local function ApplyCooldown(frame, spellID)
    if not frame or not spellID or not FindSpellEntry(spellID) then
        if frame then
            frame.BSOMouseSpellID = nil
            if frame.BSOMouseIcon then frame.BSOMouseIcon:SetTexture(nil) end
            frame:Hide()
        end
        return false
    end

    frame.BSOMouseSpellID = spellID
    if frame.BSOMouseIcon then
        frame.BSOMouseIcon:SetTexture(GetSpellTexture(spellID))
    end

    -- The icon is the persistent visual for the selected spell. The Cooldown
    -- widget is only the timer layer on top of it. Do not require cooldown data
    -- to exist before showing the frame: a spell that is ready still needs to
    -- be visible in the mouse overlay.
    local cooldownApplied = false

    if C_Spell and C_Spell.GetSpellCooldownDuration and frame.SetCooldownFromDurationObject then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            frame:SetCooldownFromDurationObject(duration, true)
            cooldownApplied = true
        end
    end

    if not cooldownApplied and C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            if frame.SetCooldownTable then
                frame:SetCooldownTable(info)
                cooldownApplied = true
            elseif frame.SetCooldownFromExpression then
                frame:SetCooldownFromExpression(spellID)
                cooldownApplied = true
            end
        end
    end

    if not cooldownApplied and GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start ~= nil and duration ~= nil then
            frame:SetCooldown(start, duration)
            cooldownApplied = true
        end
    end

    frame:Show()
    return true
end

local function GetConfig()
    return addon.PlayerBarConfig and addon.PlayerBarConfig.Initialize()
end

local function UpdateResourcePips()
    local config = GetConfig()
    local resourceProvider = GetResourceProvider()
    if not resourceProvider or not overlay or not config or not config.showMouseSpecialResources then
        for index = 1, MAX_PIPS do pips[index]:Hide() end
        return false
    end

    local state = resourceProvider:GetState()
    local maximum = addon.RenderResourcePips(state, pips, progress, pipOrder, MAX_PIPS)
    maximum = math_min(maximum, MAX_PIPS)
    if maximum <= 0 then
        for index = 1, MAX_PIPS do pips[index]:Hide() end
        return false
    end

    local radius = CURSOR_RADIUS
    local step = PI / math_max(1, maximum - 1)
    for index = 1, MAX_PIPS do
        local pip = pips[pipOrder[index]]
        if index <= maximum then
            local angle = (PI * 0.5) + (index - 1) * step
            pip:ClearAllPoints()
            pip:SetPoint("CENTER", overlay, "CENTER", math_cos(angle) * radius, math_sin(angle) * radius)
            pip:Show()
        else
            pip:Hide()
        end
    end
    return true
end

local function UpdateCooldowns()
    local config = GetConfig()
    if not config or not overlay then return false end
    local anyVisible = false
    local radius = CURSOR_RADIUS

    for index = 1, 2 do
        local frame = cooldownFrames[index]
        local spellID = config["mouseCooldown" .. index .. "Spell"]
        local slotEnabled = config["showMouseCooldown" .. index] == true
        if slotEnabled and spellID then
            if ApplyCooldown(frame, spellID) then anyVisible = true end
            -- Keep the two cooldown widgets on the opposite half from resources.
            local angle = (PI * 1.5) - (index - 1) * (COOLDOWN_SIZE + COOLDOWN_GAP) / math_max(radius, 1)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", overlay, "CENTER", math_cos(angle) * radius, math_sin(angle) * radius)
        else
            frame.BSOMouseSpellID = nil
            if frame.BSOMouseIcon then frame.BSOMouseIcon:SetTexture(nil) end
            frame:Hide()
        end
    end
    return anyVisible
end

local function UpdateVisuals()
    if not enabled or not overlay then return end
    local resourceVisible = UpdateResourcePips()
    local cooldownVisible = UpdateCooldowns()
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
    enabled = value == true
    EnsureOverlay()
    if not enabled then
        overlay:Hide()
        for index = 1, MAX_PIPS do pips[index]:Hide() end
        for index = 1, 2 do cooldownFrames[index]:Hide() end
        return true
    end
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
addon.RefreshMouseCooldowns = Refresh

if addon.RegisterSpecialResourceListener then addon.RegisterSpecialResourceListener(Refresh) end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", function()
    Refresh()
end)

addon.RegisterInitializer(function()
    local cfg = addon.PlayerBarConfig.Initialize()
    SetEnabled(cfg.showMouseSpecialResources == true or cfg.showMouseCooldown1 == true or cfg.showMouseCooldown2 == true)
end)
