-- Standalone player absorption, health, resource bars, and configuration UI.
-- Rendering and menu orchestration for the standalone player bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local bar
local healthBar
local resourceBar
local menuFrame
local tickLines = {}
local resourceThresholdLines = {}

-- Cached as upvalues, consistent with ResourceProviders.lua and
-- ClassResourceOverlay.lua, since UpdateSpecialResourcesLayout runs on the
-- ~30 Hz shared throttle and the 10 Hz resource-charging ticker.
local math_min = math.min
local math_max = math.max
local math_floor = math.floor

local TICK_FRACTIONS = { 0.5, 1.0, 1.5 }
local RESOURCE_THRESHOLDS = { 0.28, 0.56 }
local RESOURCE_BAR_WIDTH = 8
local MAX_SPECIAL_CIRCLES = 7
local SPECIAL_CIRCLE_SIZE = 12

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local DEFAULTS = addon.PlayerBarConfig.GetDefaults and addon.PlayerBarConfig.GetDefaults() or {}
local MIN_CAP_PERCENT = addon.PlayerBarConfig.GetMinCapPercent()
local config = {}

local function GetAbsorbAmount(unit)
    if UnitGetTotalAbsorbs then
        return UnitGetTotalAbsorbs(unit) or 0
    end
    return 0
end

local function SaveBarPosition()
    if not bar then return end
    local point, _, relativePoint, xOffset, yOffset = bar:GetPoint()
    if type(point) ~= "string" or type(relativePoint) ~= "string"
        or type(xOffset) ~= "number" or type(yOffset) ~= "number" then
        return
    end
    config.point = point
    config.relativePoint = relativePoint
    config.xOffset = xOffset
    config.yOffset = yOffset
end

local function UpdateBarLock()
    if not bar then return end
    bar:EnableMouse(not config.locked)
    bar:SetMovable(not config.locked)
    if config.locked then
        bar:SetScript("OnDragStart", nil)
        bar:SetScript("OnDragStop", nil)
    else
        bar:RegisterForDrag("LeftButton")
        bar:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        bar:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            SaveBarPosition()
        end)
    end
end

local function UpdateTickMarks()
    if not bar then return end

    local capMultiplier = config.capMultiplier or DEFAULTS.capMultiplier
    local totalHeight = bar:GetHeight()

    for _, fraction in ipairs(TICK_FRACTIONS) do
        local tick = tickLines[fraction]

        if fraction <= capMultiplier then
            local yOffset = totalHeight * (fraction / capMultiplier)

            tick:ClearAllPoints()
            tick:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, yOffset - 1)
            tick:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, yOffset - 1)
            tick:Show()
        else
            tick:Hide()
        end
    end
end

local function CreateTickMarks()
    for _, fraction in ipairs(TICK_FRACTIONS) do
        local tick = bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(1, 1, 1, 0.85)
        tick:SetHeight(2)
        tickLines[fraction] = tick
    end
    UpdateTickMarks()
end

local function UpdateResourceBarLayout()
    if not resourceBar or not bar then return end
    resourceBar:ClearAllPoints()
    local mode = config.resourceDisplay or DEFAULTS.resourceDisplay

    if mode == "left" then
        resourceBar:SetPoint("TOPRIGHT", bar, "TOPLEFT", -2, 0)
        resourceBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -2, 0)
        resourceBar:SetWidth(RESOURCE_BAR_WIDTH)
        resourceBar:Show()
    elseif mode == "right" then
        resourceBar:SetPoint("TOPLEFT", bar, "TOPRIGHT", 2, 0)
        resourceBar:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 2, 0)
        resourceBar:SetWidth(RESOURCE_BAR_WIDTH)
        resourceBar:Show()
    else
        resourceBar:Hide()
    end

    for _, threshold in ipairs(RESOURCE_THRESHOLDS) do
        local line = resourceThresholdLines[threshold]
        if line then
            if mode == "none" then
                line:Hide()
            else
                local yOffset = resourceBar:GetHeight() * threshold
                line:ClearAllPoints()
                line:SetPoint("BOTTOMLEFT", resourceBar, "BOTTOMLEFT", 0, yOffset - 1)
                line:SetPoint("BOTTOMRIGHT", resourceBar, "BOTTOMRIGHT", 0, yOffset - 1)
                line:Show()
            end
        end
    end
end

local specialResourceContainer
local specialCircles = {}
local specialProgress = {}
local specialOrder = {}

for index = 1, MAX_SPECIAL_CIRCLES do
    specialProgress[index] = 0
    specialOrder[index] = index
end

-- White while charging/empty; snaps to gold the instant a pip is ready/full.
-- Class rules remain in ResourceProviders.lua, outside the rendering module.
local specialResourceProvider = addon.GetSpecialResourceProvider(
    playerClass, powerTypes
)
local UpdateSpecialResources
local function CreateSpecialResources()
    if specialResourceContainer or not bar then return end

    specialResourceContainer = CreateFrame("Frame", nil, resourceBar)
    specialResourceContainer:SetAllPoints(resourceBar)

    for index = 1, MAX_SPECIAL_CIRCLES do
        local circle = CreateFrame("StatusBar", nil, specialResourceContainer)
        circle:SetFrameLevel(resourceBar:GetFrameLevel() + 1)
        circle:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        circle:SetStatusBarColor(1, 1, 1, 1)
        circle:SetOrientation("VERTICAL")

        local background = circle:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(circle)
        background:SetTexture("Interface\\Buttons\\WHITE8x8")
        background:SetVertexColor(0.15, 0.15, 0.15, 0.6)

        circle:EnableMouse(false)
        circle:Hide()
        specialCircles[index] = circle
    end
end

local function UpdateSpecialResourcesLayout()
    if not specialResourceContainer then return end

    if not config.showSpecialResources or config.hideExternalBar
        or config.resourceDisplay == "none" then
        specialResourceContainer:Hide()
        return
    end

    local maxPower = specialResourceProvider and specialResourceProvider.GetMax() or 0
    maxPower = math_min(maxPower, MAX_SPECIAL_CIRCLES)

    if maxPower <= 0 then
        specialResourceContainer:Hide()
        return
    end

    -- SetAllPoints can report zero before the parent has completed its first
    -- layout pass. Read the actual resource bar dimensions as the authority.
    local parentWidth = resourceBar:GetWidth()
    local parentHeight = resourceBar:GetHeight()
    local customWidth = config.specialResourcePipWidth or DEFAULTS.specialResourcePipWidth
    local customHeight = config.specialResourcePipHeight or DEFAULTS.specialResourcePipHeight
    local slotSize = math_min(math_max(3, customHeight), math_floor(parentHeight / maxPower))
    if slotSize < 3 then slotSize = 3 end
    local circleWidth = math_max(2, math_min(customWidth, math_max(2, parentWidth - 2)))
    local xOffset = math_max(1, (parentWidth - circleWidth) / 2)

    specialResourceContainer:Show()
    for index = 1, MAX_SPECIAL_CIRCLES do
        local circle = specialCircles[specialOrder[index]]
        if index <= maxPower then
            circle:SetSize(circleWidth, math_max(1, slotSize - 2))
            circle:ClearAllPoints()
            circle:SetPoint("TOPLEFT", resourceBar, "TOPLEFT", xOffset,
                -((index - 1) * slotSize + 1))
            circle:Show()
        else
            circle:Hide()
        end
    end
end

UpdateSpecialResources = function()
    if not specialResourceContainer then return end

    if not config.showSpecialResources or config.hideExternalBar
        or config.resourceDisplay == "none" then
        UpdateSpecialResourcesLayout()
        return
    end

    if specialResourceProvider then
        local state = specialResourceProvider:GetState()
        -- Shared with ClassResourceOverlay.lua's pip rendering: fills
        -- progress/order and applies value/color/sort to each circle.
        addon.RenderResourcePips(state, specialCircles, specialProgress, specialOrder, MAX_SPECIAL_CIRCLES)
    else
        for index = 1, MAX_SPECIAL_CIRCLES do
            specialProgress[index] = 0
        end
    end

    UpdateSpecialResourcesLayout()
end

addon.UpdateSpecialResourcesLayout = UpdateSpecialResourcesLayout
addon.UpdateSpecialResources = UpdateSpecialResources

function addon.SetSpecialResourcePipSize(width, height)
    if type(width) ~= "number" or type(height) ~= "number" then return false end
    if width < 2 or width > 20 or height < 2 or height > 32 then return false end

    config.specialResourcePipWidth = width
    config.specialResourcePipHeight = height
    if specialResourceContainer then
        UpdateSpecialResourcesLayout()
    end
    return true
end

local function CreateBar()
    if bar then return end

    bar = CreateFrame("StatusBar", "BloodShieldOverlayBar", UIParent)
    bar:SetSize(config.width or DEFAULTS.width, config.height or DEFAULTS.height)
    bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(1.0, 1.0, 1.0, 1.0)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(1)
    bar:SetOrientation("VERTICAL")
    bar:SetReverseFill(false)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.4)

    -- Health bar (red).
    healthBar = CreateFrame("StatusBar", nil, bar)
    healthBar:SetAllPoints(bar)
    healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healthBar:SetStatusBarColor(0.85, 0.15, 0.15, 0.85)
    healthBar:SetOrientation("VERTICAL")
    healthBar:SetReverseFill(false)
    healthBar:SetFrameLevel(bar:GetFrameLevel())

    -- Personal resource bar (blue, vertical, width 8).
    resourceBar = CreateFrame("StatusBar", nil, bar)
    resourceBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    resourceBar:SetStatusBarColor(0.0, 0.5, 1.0, 0.9)
    resourceBar:SetOrientation("VERTICAL")
    resourceBar:SetReverseFill(false)
    resourceBar:SetFrameLevel(bar:GetFrameLevel())

    local rBg = resourceBar:CreateTexture(nil, "BACKGROUND")
    rBg:SetAllPoints(resourceBar)
    rBg:SetColorTexture(0, 0, 0, 0.5)

    for _, threshold in ipairs(RESOURCE_THRESHOLDS) do
        local thresholdLine = resourceBar:CreateTexture(nil, "OVERLAY")
        thresholdLine:SetColorTexture(1, 1, 1, 0.85)
        thresholdLine:SetHeight(2)
        resourceThresholdLines[threshold] = thresholdLine
    end

    UpdateResourceBarLayout()
    CreateSpecialResources()
    UpdateSpecialResourcesLayout()

    bar:SetScript("OnSizeChanged", function()
        UpdateTickMarks()
        UpdateResourceBarLayout()
    end)

    CreateTickMarks()
    UpdateBarLock()
end

local function UpdateExternalBarVisibility()
    if not bar then return end

    if config.hideExternalBar then
        bar:Hide()
    else
        bar:Show()
        if healthBar and config.showHealth then healthBar:Show() end
        UpdateResourceBarLayout()
        UpdateSpecialResources()
    end
end

local function UpdateBar(absorb, maxHP)
    if not bar then CreateBar() end
    if not bar then return end

    if config.hideExternalBar then
        bar:Hide()
        return
    end

    bar:Show()

    absorb = absorb or GetAbsorbAmount("player")
    maxHP = maxHP or UnitHealthMax("player") or 1
    local currentHP = UnitHealth("player") or maxHP

    if healthBar then
        if config.showHealth then
            healthBar:Show()
            healthBar:SetMinMaxValues(0, maxHP)
            healthBar:SetValue(currentHP)
        else
            healthBar:Hide()
        end
    end

    local displayMax = maxHP * (config.capMultiplier or DEFAULTS.capMultiplier)
    if displayMax > 0 then
        bar:SetMinMaxValues(0, displayMax)
        bar:SetValue(absorb)
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end

    -- Safely update the personal resource bar.
    if resourceBar and config.resourceDisplay ~= "none" then
        resourceBar:Show()
        local curPower = UnitPower("player") or 0
        local maxPower = UnitPowerMax("player") or 1

        -- Avoid invalid ranges when the resource has no maximum.
        if maxPower <= 0 then maxPower = 1 end

        resourceBar:SetMinMaxValues(0, maxPower)
        resourceBar:SetValue(curPower)
    elseif resourceBar then
        resourceBar:Hide()
    end

    UpdateSpecialResources()
end

local function ApplyBarDimensions(width, height, capPercent)
    if not (width and width > 0 and height and height > 0) then
        print("BloodShieldOverlay: width and height must be positive numbers.")
        return false
    end
    if not (capPercent and capPercent >= MIN_CAP_PERCENT) then
        print(string.format("BloodShieldOverlay: Max %% must be at least %d.", MIN_CAP_PERCENT))
        return false
    end

    config.width = width
    config.height = height
    config.capMultiplier = capPercent / 100

    if bar then
        bar:SetSize(width, height)
    end

    -- Re-render even when only Max % changed. SetSize can invoke OnSizeChanged,
    -- but the cap value itself must always trigger a complete refresh.
    UpdateBar()
    UpdateTickMarks()
    return true
end

-- Helpers de arquitectura para creación limpia de UI
local function CreateLabel(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetText(text)
    return label
end

local function CreateLabeledEditBox(parent, labelText, boxWidth)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(boxWidth + 80, 24)

    local label = CreateLabel(container, labelText)
    label:SetPoint("LEFT", container, "LEFT", 0, 0)

    local editBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    editBox:SetSize(boxWidth or 50, 24)
    editBox:SetPoint("LEFT", label, "RIGHT", 8, 0)
    editBox:SetAutoFocus(false)

    container.editBox = editBox
    container.label = label
    return container, editBox
end

local function CreateCheckBox(parent, labelText, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check.Text:SetText(labelText)
    check:SetScript("OnClick", onClick)
    return check
end

local function CreateConfigMenu()
    if menuFrame then return end

    -- Se amplía la altura a 440px para acomodar las 3 filas de opciones y las checkboxes cómodamente
    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(500, 440)
    menuFrame:SetPoint("CENTER")
    menuFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    menuFrame:SetMovable(true)
    menuFrame:EnableMouse(true)
    menuFrame:RegisterForDrag("LeftButton")
    menuFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    menuFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local title = CreateLabel(menuFrame, "Shield Bar Settings", "GameFontNormalLarge")
    title:SetPoint("TOP", menuFrame, "TOP", 0, -14)

    local info = CreateLabel(menuFrame, "Click Unlock to drag the bar. Click Lock to anchor. Use /shield reload to refresh frames.", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 18, -40)
    info:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -18, -40)
    info:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- FILA 1: Dimensiones Principales (Width, Height, Max %, Apply)
    ---------------------------------------------------------------------------
    local cWidth, widthEdit = CreateLabeledEditBox(menuFrame, "Width:", 45)
    cWidth:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -14)
    menuFrame.widthEdit = widthEdit

    local cHeight, heightEdit = CreateLabeledEditBox(menuFrame, "Height:", 45)
    cHeight:SetPoint("LEFT", cWidth, "RIGHT", 10, 0)
    menuFrame.heightEdit = heightEdit

    local cCap, capEdit = CreateLabeledEditBox(menuFrame, "Max %:", 45)
    cCap:SetPoint("LEFT", cHeight, "RIGHT", 10, 0)
    menuFrame.capEdit = capEdit

    local applyButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    applyButton:SetSize(65, 24)
    applyButton:SetPoint("LEFT", cCap, "RIGHT", 10, 0)
    applyButton:SetText("Apply")
    menuFrame.applyButton = applyButton

    ---------------------------------------------------------------------------
    -- FILA 2: Personal Resource Bar Pip (Width, Height)
    ---------------------------------------------------------------------------
    local cResPipW, resPipWidthEdit = CreateLabeledEditBox(menuFrame, "Resource Pip W:", 45)
    cResPipW:SetPoint("TOPLEFT", cWidth, "BOTTOMLEFT", 0, -10)
    menuFrame.resourcePipWidthEdit = resPipWidthEdit

    local cResPipH, resPipHeightEdit = CreateLabeledEditBox(menuFrame, "Height:", 45)
    cResPipH:SetPoint("LEFT", cResPipW, "RIGHT", 10, 0)
    menuFrame.resourcePipHeightEdit = resPipHeightEdit

    ---------------------------------------------------------------------------
    -- FILA 3: Group Overlay Pip (Width, Height)
    ---------------------------------------------------------------------------
    local cGrpPipW, grpPipWidthEdit = CreateLabeledEditBox(menuFrame, "Group Pip W:", 45)
    cGrpPipW:SetPoint("TOPLEFT", cResPipW, "BOTTOMLEFT", 0, -10)
    menuFrame.pipWidthEdit = grpPipWidthEdit

    local cGrpPipH, grpPipHeightEdit = CreateLabeledEditBox(menuFrame, "Height:", 45)
    cGrpPipH:SetPoint("LEFT", cGrpPipW, "RIGHT", 10, 0)
    menuFrame.pipHeightEdit = grpPipHeightEdit

    ---------------------------------------------------------------------------
    -- FILA 4: Personal Resource Bar Position Toggle
    ---------------------------------------------------------------------------
    local resLabel = CreateLabel(menuFrame, "Personal Resource Bar:")
    resLabel:SetPoint("TOPLEFT", cGrpPipW, "BOTTOMLEFT", 0, -12)

    local resButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    resButton:SetSize(80, 22)
    resButton:SetPoint("LEFT", resLabel, "RIGHT", 10, 0)
    resButton.UpdateText = function(self)
        local mode = config.resourceDisplay or "left"
        self:SetText(mode:gsub("^%l", string.upper))
    end
    resButton:SetScript("OnClick", function(self)
        if config.resourceDisplay == "left" then
            config.resourceDisplay = "right"
        elseif config.resourceDisplay == "right" then
            config.resourceDisplay = "none"
        else
            config.resourceDisplay = "left"
        end
        self:UpdateText()
        UpdateResourceBarLayout()
        UpdateBar()
    end)
    menuFrame.resButton = resButton

    ---------------------------------------------------------------------------
    -- BLOQUE DE CHECKBOXES (Alineadas verticalmente debajo del bloque de pips)
    ---------------------------------------------------------------------------
    local visibilityCheck = CreateCheckBox(menuFrame, "Hide external shield bar", function(self)
        config.hideExternalBar = self:GetChecked() and true or false
        UpdateExternalBarVisibility()
    end)
    visibilityCheck:SetPoint("TOPLEFT", resLabel, "BOTTOMLEFT", -2, -12)
    menuFrame.visibilityCheck = visibilityCheck

    local healthCheck = CreateCheckBox(menuFrame, "Show health bar (red, 100% base)", function(self)
        config.showHealth = self:GetChecked() and true or false
        UpdateBar()
    end)
    healthCheck:SetPoint("TOPLEFT", visibilityCheck, "BOTTOMLEFT", 0, -2)
    menuFrame.healthCheck = healthCheck

    local specialResCheck = CreateCheckBox(menuFrame, "Show special resources (circles)", function(self)
        config.showSpecialResources = self:GetChecked() and true or false
        UpdateSpecialResources()
    end)
    specialResCheck:SetPoint("TOPLEFT", healthCheck, "BOTTOMLEFT", 0, -2)
    menuFrame.specialResCheck = specialResCheck

    local classOverlayCheck = CreateCheckBox(menuFrame, "Show special resources on group frames", function(self)
        config.showClassResourceOverlay = self:GetChecked() and true or false
        if addon.SetClassResourceOverlayEnabled then
            addon.SetClassResourceOverlayEnabled(config.showClassResourceOverlay)
        end
    end)
    classOverlayCheck:SetPoint("TOPLEFT", specialResCheck, "BOTTOMLEFT", 0, -2)
    menuFrame.classOverlayCheck = classOverlayCheck

    ---------------------------------------------------------------------------
    -- MANEJO DEL BOTÓN DE APLICAR
    ---------------------------------------------------------------------------
    applyButton:SetScript("OnClick", function()
        local width = tonumber(widthEdit:GetText())
        local height = tonumber(heightEdit:GetText())
        local capPercent = tonumber(capEdit:GetText())
        ApplyBarDimensions(width, height, capPercent)

        local resourcePipWidth = tonumber(resPipWidthEdit:GetText())
        local resourcePipHeight = tonumber(resPipHeightEdit:GetText())
        if addon.SetSpecialResourcePipSize and addon.SetSpecialResourcePipSize(resourcePipWidth, resourcePipHeight) then
            config.specialResourcePipWidth = resourcePipWidth
            config.specialResourcePipHeight = resourcePipHeight
        else
            print("BloodShieldOverlay: resource pip width must be 2-20 and height 2-32.")
            resPipWidthEdit:SetText(tostring(config.specialResourcePipWidth or DEFAULTS.specialResourcePipWidth))
            resPipHeightEdit:SetText(tostring(config.specialResourcePipHeight or DEFAULTS.specialResourcePipHeight))
        end

        local pipWidth = tonumber(grpPipWidthEdit:GetText())
        local pipHeight = tonumber(grpPipHeightEdit:GetText())
        if addon.SetClassResourceOverlayPipSize and addon.SetClassResourceOverlayPipSize(pipWidth, pipHeight) then
            config.classResourcePipWidth = pipWidth
            config.classResourcePipHeight = pipHeight
        else
            print("BloodShieldOverlay: group pip width must be 4-32 and height 2-20.")
            grpPipWidthEdit:SetText(tostring(config.classResourcePipWidth or 12))
            grpPipHeightEdit:SetText(tostring(config.classResourcePipHeight or 6))
        end
    end)

    ---------------------------------------------------------------------------
    -- BOTONES INFERIORES (Unlock, Lock, Close)
    ---------------------------------------------------------------------------
    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(85, 24)
    unlock:SetPoint("BOTTOMLEFT", menuFrame, "BOTTOMLEFT", 16, 16)
    unlock:SetText("Unlock")
    unlock:SetScript("OnClick", function()
        config.locked = false
        UpdateBarLock()
    end)

    local lock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    lock:SetSize(85, 24)
    lock:SetPoint("LEFT", unlock, "RIGHT", 8, 0)
    lock:SetText("Lock")
    lock:SetScript("OnClick", function()
        config.locked = true
        UpdateBarLock()
    end)

    local closeBtn = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(85, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -16, 16)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        menuFrame:Hide()
    end)
end

local function RefreshConfigMenuFields()
    if not menuFrame then return end
    menuFrame.widthEdit:SetText(tostring(config.width or DEFAULTS.width))
    menuFrame.heightEdit:SetText(tostring(config.height or DEFAULTS.height))
    menuFrame.capEdit:SetText(tostring((config.capMultiplier or DEFAULTS.capMultiplier) * 100))
    if menuFrame.resourcePipWidthEdit then
        menuFrame.resourcePipWidthEdit:SetText(tostring(config.specialResourcePipWidth or DEFAULTS.specialResourcePipWidth))
    end
    if menuFrame.resourcePipHeightEdit then
        menuFrame.resourcePipHeightEdit:SetText(tostring(config.specialResourcePipHeight or DEFAULTS.specialResourcePipHeight))
    end
    menuFrame.pipWidthEdit:SetText(tostring(config.classResourcePipWidth or 12))
    menuFrame.pipHeightEdit:SetText(tostring(config.classResourcePipHeight or 6))
    menuFrame.visibilityCheck:SetChecked(config.hideExternalBar and true or false)
    menuFrame.healthCheck:SetChecked(config.showHealth and true or false)
    if menuFrame.specialResCheck then
        menuFrame.specialResCheck:SetChecked(config.showSpecialResources and true or false)
    end
    if menuFrame.classOverlayCheck then
        menuFrame.classOverlayCheck:SetChecked(config.showClassResourceOverlay and true or false)
    end
    if menuFrame.resButton and menuFrame.resButton.UpdateText then
        menuFrame.resButton:UpdateText()
    end
end

local function ShowConfigMenu()
    CreateConfigMenu()
    RefreshConfigMenuFields()
    menuFrame:Show()
end

addon.RegisterInitializer(function()
    config = addon.PlayerBarConfig.Initialize()
    if addon.SetClassResourceOverlayEnabled then
        addon.SetClassResourceOverlayEnabled(config.showClassResourceOverlay)
    end
    if addon.SetClassResourceOverlayPipSize then
        addon.SetClassResourceOverlayPipSize(config.classResourcePipWidth, config.classResourcePipHeight)
    end
    if addon.SetSpecialResourcePipSize then
        addon.SetSpecialResourcePipSize(config.specialResourcePipWidth, config.specialResourcePipHeight)
    end
    UpdateBar()
    addon.RegisterPlayerUpdateListener(UpdateBar)
end)

addon.RegisterSpecialResourceListener(function()
    UpdateSpecialResources()
end)

addon.PlayerBarAPI = {
    ShowConfigMenu = ShowConfigMenu,
    IsLocked = function() return config.locked end,
    SetLocked = function(locked)
        config.locked = locked and true or false
        UpdateBarLock()
    end,
    SetHidden = function(hidden)
        config.hideExternalBar = hidden and true or false
        UpdateExternalBarVisibility()
        RefreshConfigMenuFields()
        if not hidden then UpdateBar() end
    end,
    Reset = function()
        config = addon.PlayerBarConfig.Reset()
        if addon.SetClassResourceOverlayEnabled then
            addon.SetClassResourceOverlayEnabled(config.showClassResourceOverlay)
        end
        if addon.SetClassResourceOverlayPipSize then
            addon.SetClassResourceOverlayPipSize(config.classResourcePipWidth, config.classResourcePipHeight)
        end
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint(config.point, UIParent, config.relativePoint, config.xOffset, config.yOffset)
            bar:SetSize(config.width, config.height)
            UpdateBarLock()
        end
        RefreshConfigMenuFields()
        UpdateBar()
    end,
}
addon.ShowConfigMenu = ShowConfigMenu

