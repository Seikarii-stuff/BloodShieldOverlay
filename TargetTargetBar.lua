-- Minimal healer target-of-target bar.
-- Midnight secret values are passed directly to Blizzard UI APIs.
-- Secret health/name values are never compared, converted, formatted, or inspected.
-- The frame is a SecureUnitButton; click interaction remains intentionally disabled for now.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local UNIT = "targettarget"
local W, H = 130, 10
local frame, bar, nameText, config
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local type = type

local function UpdateVisuals()
    if not frame or not bar or not nameText or not config or not config.showTargetTarget then return end

    -- UnitName may be a secret string on restricted unit identities. SetText is
    -- explicitly allowed to consume secret text, so pass it straight through.
    nameText:SetText(UnitName(UNIT))

    -- UnitClass can legitimately return nil for units without class data (for
    -- example NPCs). Never pass that nil to C_ClassColor. For units that do
    -- provide a class filename, Blizzard resolves the class color for us.
    local _, classFilename = UnitClass(UNIT)
    if classFilename ~= nil and C_ClassColor then
        local classColor = C_ClassColor.GetClassColor(classFilename)
        if classColor then
            bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 0.95)
            return
        end
    end

    -- Non-class units retain the neutral default.
    bar:SetStatusBarColor(0.20, 0.85, 0.25, 0.95)
end

local function UpdateHealth()
    if not frame or not bar or not config or not config.showTargetTarget then return end
    -- Never inspect secret health values. Blizzard's StatusBar consumes them.
    bar:SetMinMaxValues(0, UnitHealthMax(UNIT))
    bar:SetValue(UnitHealth(UNIT))
end

local function Update()
    UpdateVisuals()
    UpdateHealth()
end

local function SavePosition()
    local p, _, rp, x, y = frame:GetPoint()
    if type(p) == "string" and type(rp) == "string" and type(x) == "number" and type(y) == "number" then
        config.targetTargetPoint, config.targetTargetRelativePoint = p, rp
        config.targetTargetXOffset, config.targetTargetYOffset = x, y
    end
end

local function SetLocked(locked)
    if not frame or InCombatLockdown() then return false end
    config.targetTargetLocked = locked and true or false
    frame:SetMovable(not config.targetTargetLocked)
    frame:EnableMouse(true)
    if config.targetTargetLocked then
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    else
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self)
            if InCombatLockdown() then return end
            self:StartMoving()
        end)
        frame:SetScript("OnDragStop", function(self)
            if InCombatLockdown() then return end
            self:StopMovingOrSizing()
            SavePosition()
        end)
    end
    return true
end

local function Create()
    if frame or InCombatLockdown() then return frame ~= nil end

    frame = CreateFrame("Button", "BloodShieldOverlayTargetTargetBar", UIParent, "SecureUnitButtonTemplate")
    frame:SetSize(config.targetTargetWidth, config.targetTargetHeight)
    frame:SetPoint(
        config.targetTargetPoint,
        UIParent,
        config.targetTargetRelativePoint,
        config.targetTargetXOffset,
        config.targetTargetYOffset
    )
    frame:SetFrameStrata("LOW")
    frame:SetAttribute("unit", UNIT)
    -- No direct spell/click action yet. Secure unit identity remains available
    -- for the future interaction feature without performing protected actions.
    frame:SetAttribute("type1", "none")
    frame:SetAttribute("type2", "none")
    frame:RegisterForClicks("AnyUp", "AnyDown")
    frame:EnableMouse(true)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)

    bar = CreateFrame("StatusBar", nil, frame)
    bar:SetAllPoints()
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(0.20, 0.85, 0.25, 0.95)
    bar:SetOrientation("HORIZONTAL")
    bar:SetFrameLevel(frame:GetFrameLevel() + 1)

    nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    nameText:SetJustifyH("CENTER")
    nameText:SetJustifyV("MIDDLE")
    nameText:SetWordWrap(false)
    nameText:SetMaxLines(1)
    nameText:SetTextColor(1, 1, 1, 1)

    if RegisterUnitWatch then RegisterUnitWatch(frame) end
    SetLocked(config.targetTargetLocked)
    Update()
    return true
end

local function Enable(show)
    if InCombatLockdown() then return false end
    config.showTargetTarget = show and true or false

    if not config.showTargetTarget then
        if frame and UnregisterUnitWatch then UnregisterUnitWatch(frame) end
        if frame then frame:Hide() end
        return true
    end

    if not Create() then return false end
    if RegisterUnitWatch then RegisterUnitWatch(frame) end
    Update()
    return true
end

local function ApplySize(width, height)
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
        return false
    end
    if InCombatLockdown() then return false end
    config.targetTargetWidth, config.targetTargetHeight = width, height
    if frame then frame:SetSize(width, height) end
    return true
end

local events = CreateFrame("Frame")
for _, eventName in ipairs({ "PLAYER_TARGET_CHANGED", "UNIT_TARGET", "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
    events:RegisterEvent(eventName)
end

events:SetScript("OnEvent", function(_, _, unit)
    if not unit or unit == "target" or unit == UNIT then
        Update()
    end
end)

addon.TargetTargetBarAPI = {
    Enable = Enable,
    ApplySize = ApplySize,
    SetLocked = SetLocked,
    Refresh = Update,
}

addon.RegisterInitializer(function()
    config = addon.PlayerBarConfig.Initialize()
    config.showTargetTarget = config.showTargetTarget == true
    config.targetTargetWidth = config.targetTargetWidth or W
    config.targetTargetHeight = config.targetTargetHeight or H
    config.targetTargetLocked = config.targetTargetLocked ~= false
    config.targetTargetPoint = config.targetTargetPoint or "CENTER"
    config.targetTargetRelativePoint = config.targetTargetRelativePoint or "CENTER"
    config.targetTargetXOffset = config.targetTargetXOffset or 0
    config.targetTargetYOffset = config.targetTargetYOffset or -140

    if config.showTargetTarget then Create() end
end)
