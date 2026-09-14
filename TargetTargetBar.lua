-- Minimal healer target-of-target bar.
-- The frame is a SecureUnitButton; click interaction remains intentionally disabled for now.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local UNIT = "targettarget"
local W, H = 130, 10
local frame, bar, nameText
local pendingLocked
local pendingEnable
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local type = type
local math_max = math.max
local UnitName = UnitName
local UnitClass = UnitClass
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local C_ClassColor = C_ClassColor

local function CurrentConfig()
    return addon.PlayerBarConfig.Get()
end

local function UpdateVisuals()
    local config = CurrentConfig()
    if not frame or not bar or not nameText or not config or not config.showTargetTarget then return end
    nameText:SetText(UnitName(UNIT))
    local _, classFilename = UnitClass(UNIT)
    if classFilename ~= nil and C_ClassColor then
        local classColor = C_ClassColor.GetClassColor(classFilename)
        if classColor then
            bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 0.95)
            return
        end
    end
    bar:SetStatusBarColor(0.20, 0.85, 0.25, 0.95)
end

local function UpdateHealth()
    local config = CurrentConfig()
    if not frame or not bar or not config or not config.showTargetTarget then return end
    bar:SetMinMaxValues(0, UnitHealthMax(UNIT))
    bar:SetValue(UnitHealth(UNIT))
end

local function Update()
    UpdateVisuals()
    UpdateHealth()
end

local function SavePosition()
    if not frame then return end
    local p, _, rp, x, y = frame:GetPoint()
    if type(p) == "string" and type(rp) == "string" and type(x) == "number" and type(y) == "number" then
        addon.PlayerBarConfig.SetMany({
            targetTargetPoint = p,
            targetTargetRelativePoint = rp,
            targetTargetXOffset = x,
            targetTargetYOffset = y,
        })
    end
end

local function SetLocked(locked)
    locked = locked and true or false
    if not frame or InCombatLockdown() then
        pendingLocked = locked
        return false
    end

    pendingLocked = nil
    local didSet = addon.PlayerBarConfig.Set("targetTargetLocked", locked)
    if not didSet then return false end

    local config = CurrentConfig()
    frame:SetMovable(not config.targetTargetLocked)
    frame:EnableMouse(true)
    if config.targetTargetLocked then
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    else
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self)
            if not InCombatLockdown() then self:StartMoving() end
        end)
        frame:SetScript("OnDragStop", function(self)
            if not InCombatLockdown() then
                self:StopMovingOrSizing()
                SavePosition()
            end
        end)
    end
    return true
end

local function Create()
    local config = CurrentConfig()
    if frame or InCombatLockdown() then return frame ~= nil end

    frame = CreateFrame("Button", "BloodShieldOverlayTargetTargetBar", UIParent, "SecureUnitButtonTemplate")
    frame:SetSize(config.targetTargetWidth, config.targetTargetHeight)
    frame:SetPoint(config.targetTargetPoint, UIParent, config.targetTargetRelativePoint, config.targetTargetXOffset, config.targetTargetYOffset)
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

    local textOverlay = CreateFrame("Frame", nil, frame)
    textOverlay:SetAllPoints(frame)
    textOverlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    textOverlay:EnableMouse(false)

    nameText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("CENTER", textOverlay, "CENTER", 0, 0)
    nameText:SetWidth(math_max(1, config.targetTargetWidth - 4))
    nameText:SetJustifyH("CENTER")
    nameText:SetJustifyV("MIDDLE")
    nameText:SetWordWrap(false)
    nameText:SetMaxLines(1)
    nameText:SetTextColor(1, 1, 1, 1)

    if RegisterUnitWatch then RegisterUnitWatch(frame) end
    local deferredLocked = pendingLocked
    SetLocked(config.targetTargetLocked)
    if deferredLocked ~= nil then
        pendingLocked = deferredLocked
    end
    Update()
    return true
end

local function Enable(show)
    show = show and true or false
    if InCombatLockdown() then
        pendingEnable = show
        return false
    end

    pendingEnable = nil
    local result = addon.PlayerBarConfig.Set("showTargetTarget", show)
    if not result then return false end

    if not CurrentConfig().showTargetTarget then
        if frame and UnregisterUnitWatch then UnregisterUnitWatch(frame) end
        if frame then frame:Hide() end
        return true
    end

    if not Create() then
        pendingEnable = show
        return false
    end
    if RegisterUnitWatch then RegisterUnitWatch(frame) end
    Update()
    return true
end

local function ApplySize(width, height)
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then return false end
    if InCombatLockdown() then return false end
    local result = addon.PlayerBarConfig.SetMany({ targetTargetWidth = width, targetTargetHeight = height })
    if not result then return false end
    if frame then
        frame:SetSize(width, height)
        if nameText then nameText:SetWidth(math_max(1, width - 4)) end
    end
    return true
end

local function HandleConfigChange(change)
    if not change or not change.key then return end
    local config = CurrentConfig()
    if change.key == "showTargetTarget" then
        if not config.showTargetTarget then
            if frame and UnregisterUnitWatch then UnregisterUnitWatch(frame) end
            if frame then frame:Hide() end
            return
        end
        if not frame then
            Create()
        end
        if frame and RegisterUnitWatch then RegisterUnitWatch(frame) end
        Update()
    elseif change.key == "targetTargetWidth" or change.key == "targetTargetHeight" then
        if frame then
            frame:SetSize(config.targetTargetWidth, config.targetTargetHeight)
            if nameText then nameText:SetWidth(math_max(1, config.targetTargetWidth - 4)) end
        end
    elseif change.key == "targetTargetLocked" then
        if frame then
            frame:SetMovable(not config.targetTargetLocked)
            if config.targetTargetLocked then
                frame:RegisterForDrag()
                frame:SetScript("OnDragStart", nil)
                frame:SetScript("OnDragStop", nil)
            else
                frame:RegisterForDrag("LeftButton")
                frame:SetScript("OnDragStart", function(self)
                    if not InCombatLockdown() then self:StartMoving() end
                end)
                frame:SetScript("OnDragStop", function(self)
                    if not InCombatLockdown() then
                        self:StopMovingOrSizing()
                        SavePosition()
                    end
                end)
            end
        end
    elseif change.key == "targetTargetPoint" or change.key == "targetTargetRelativePoint" or change.key == "targetTargetXOffset" or change.key == "targetTargetYOffset" then
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint(config.targetTargetPoint, UIParent, config.targetTargetRelativePoint, config.targetTargetXOffset, config.targetTargetYOffset)
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UNIT_TARGET")
events:RegisterEvent("UNIT_HEALTH")
events:RegisterEvent("UNIT_MAXHEALTH")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingEnable ~= nil then
            local show = pendingEnable
            pendingEnable = nil
            Enable(show)
        end
        if pendingLocked ~= nil and frame then
            local locked = pendingLocked
            pendingLocked = nil
            SetLocked(locked)
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        if addon.ScheduleTargetTargetUpdate then addon.ScheduleTargetTargetUpdate() end
    elseif event == "UNIT_TARGET" then
        if unit == "target" or unit == UNIT then
            if addon.ScheduleTargetTargetUpdate then addon.ScheduleTargetTargetUpdate() end
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if unit == UNIT then
            if addon.ScheduleTargetTargetUpdate then addon.ScheduleTargetTargetUpdate() end
        end
    end
end)

addon.TargetTargetBarAPI = {
    Enable = Enable,
    ApplySize = ApplySize,
    SetLocked = SetLocked,
    Refresh = Update,
}

addon.RegisterTargetTargetUpdateListener(Update)
addon.PlayerBarConfig.Subscribe(HandleConfigChange)

addon.RegisterInitializer(function()
    local config = addon.PlayerBarConfig.Get() or addon.PlayerBarConfig.GetDefaults()
    if config.showTargetTarget then Create() end
end)


