-- Minimal healer target-of-target bar.
-- IMPORTANT: Midnight returns secret values from UnitHealth/UnitHealthMax for
-- protected/hostile units. Never branch on, compare, or otherwise inspect those
-- values. Feed them directly to the Blizzard StatusBar; the game renders them.
-- The frame is a SecureUnitButton so the unit can also be used by @mouseover
-- secure spell macros without this module performing protected casts itself.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local UNIT = "targettarget"
local W, H = 100, 8
local frame, bar, config, options
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local tonumber, tostring = tonumber, tostring
local type = type

local function Update()
    if not frame or not config or not config.showTargetTarget then return end

    -- DO NOT call UnitHealthMax and compare the result. In Midnight the value
    -- can be secret. StatusBar is allowed to consume the secret directly and
    -- Blizzard performs the rendering internally.
    bar:SetMinMaxValues(0, UnitHealthMax(UNIT))
    bar:SetValue(UnitHealth(UNIT))
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

    -- SecureUnitButtonTemplate makes this a real unit frame. Because its unit
    -- attribute is "targettarget", hovering it exposes that unit to secure
    -- [@mouseover] macros. No insecure spell cast is performed here.
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

    -- Blizzard owns visibility based on the secure unit. This avoids any
    -- insecure UnitExists/branching logic and means the addon never needs to
    -- inspect whether the secret unit currently exists.
    if RegisterUnitWatch then
        RegisterUnitWatch(frame)
    end

    SetLocked(config.targetTargetLocked)
    Update()
    return true
end

local function Enable(show)
    if InCombatLockdown() then return false end

    config.showTargetTarget = show and true or false
    if not config.showTargetTarget then
        if frame and UnregisterUnitWatch then
            UnregisterUnitWatch(frame)
        end
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

local function BuildOptions(menu)
    if options or not menu then return end

    menu:SetHeight(math.max(menu:GetHeight(), 500))
    local anchor = menu.classOverlayCheck or menu.specialResCheck
    local p = CreateFrame("Frame", nil, menu)
    p:SetSize(440, 95)
    p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    options = p

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT")
    title:SetText("Target of Target:")

    local check = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    check.Text:SetText("Show target of target frame")
    check:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -2)
    check:SetScript("OnClick", function(self)
        local requested = self:GetChecked() and true or false
        if not Enable(requested) then
            self:SetChecked(config.showTargetTarget and true or false)
        end
    end)
    p.check = check

    local wl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wl:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 4, -6)
    wl:SetText("Width")

    local we = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    we:SetSize(45, 22)
    we:SetPoint("LEFT", wl, "RIGHT", 8, 0)
    we:SetAutoFocus(false)
    p.we = we

    local hl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hl:SetPoint("LEFT", we, "RIGHT", 16, 0)
    hl:SetText("Height")

    local he = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    he:SetSize(45, 22)
    he:SetPoint("LEFT", hl, "RIGHT", 8, 0)
    he:SetAutoFocus(false)
    p.he = he

    local apply = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    apply:SetSize(60, 22)
    apply:SetPoint("LEFT", he, "RIGHT", 12, 0)
    apply:SetText("Apply")
    apply:SetScript("OnClick", function()
        local w, h = tonumber(we:GetText()), tonumber(he:GetText())
        if not ApplySize(w, h) then
            we:SetText(tostring(config.targetTargetWidth))
            he:SetText(tostring(config.targetTargetHeight))
        end
    end)

    local unlock = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    unlock:SetSize(75, 22)
    unlock:SetPoint("TOPLEFT", wl, "BOTTOMLEFT", -4, -8)
    unlock:SetText("Unlock")
    unlock:SetScript("OnClick", function()
        SetLocked(false)
    end)

    local lock = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    lock:SetSize(65, 22)
    lock:SetPoint("LEFT", unlock, "RIGHT", 6, 0)
    lock:SetText("Lock")
    lock:SetScript("OnClick", function()
        SetLocked(true)
    end)
end

local function RefreshOptions()
    if not options then return end
    options.check:SetChecked(config.showTargetTarget)
    options.we:SetText(tostring(config.targetTargetWidth))
    options.he:SetText(tostring(config.targetTargetHeight))
end

local function HookMenu()
    if not addon.PlayerBarAPI or not addon.PlayerBarAPI.ShowConfigMenu then return end
    if addon.PlayerBarAPI.ShowConfigMenu.__tt then return end

    local old = addon.PlayerBarAPI.ShowConfigMenu
    local show = function(...)
        old(...)
        local menu = _G.BloodShieldOverlayConfig
        if menu then
            BuildOptions(menu)
            RefreshOptions()
        end
    end
    show.__tt = true
    addon.PlayerBarAPI.ShowConfigMenu = show
    addon.ShowConfigMenu = show
end

local events = CreateFrame("Frame")
for _, eventName in ipairs({
    "PLAYER_TARGET_CHANGED",
    "UNIT_TARGET",
    "UNIT_HEALTH",
    "UNIT_MAXHEALTH",
}) do
    events:RegisterEvent(eventName)
end

events:SetScript("OnEvent", function(_, _, unit)
    -- Event payloads are ordinary unit-token strings here. We do not inspect
    -- any health value; Update passes the potentially-secret values straight
    -- into Blizzard's StatusBar implementation.
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

    if config.showTargetTarget then
        Create()
    end
    HookMenu()
end)
