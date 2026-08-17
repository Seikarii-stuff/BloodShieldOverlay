-- Central /shield configuration UI.
-- All menu layout and controls live here so feature modules only expose APIs.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local menuFrame
local config

local function CreateLabel(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetText(text)
    return label
end

local function CreateInputBox(parent, width)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width or 45, 24)
    editBox:SetAutoFocus(false)
    return editBox
end

local function CreateCheckBox(parent, labelText, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check.Text:SetText(labelText)
    check:SetScript("OnClick", onClick)
    return check
end

local function Refresh()
    if not menuFrame or not config then return end

    menuFrame.widthEdit:SetText(tostring(config.width))
    menuFrame.heightEdit:SetText(tostring(config.height))
    menuFrame.capEdit:SetText(tostring((config.capMultiplier or 2) * 100))
    menuFrame.resourcePipWidthEdit:SetText(tostring(config.specialResourcePipWidth))
    menuFrame.resourcePipHeightEdit:SetText(tostring(config.specialResourcePipHeight))
    menuFrame.pipWidthEdit:SetText(tostring(config.classResourcePipWidth))
    menuFrame.pipHeightEdit:SetText(tostring(config.classResourcePipHeight))

    menuFrame.visibilityCheck:SetChecked(config.hideExternalBar and true or false)
    menuFrame.healthCheck:SetChecked(config.showHealth and true or false)
    menuFrame.specialResCheck:SetChecked(config.showSpecialResources and true or false)
    menuFrame.classOverlayCheck:SetChecked(config.showClassResourceOverlay and true or false)
    menuFrame.targetTargetCheck:SetChecked(config.showTargetTarget and true or false)
    menuFrame.targetTargetWidthEdit:SetText(tostring(config.targetTargetWidth))
    menuFrame.targetTargetHeightEdit:SetText(tostring(config.targetTargetHeight))

    if menuFrame.resButton then
        local mode = config.resourceDisplay or "left"
        menuFrame.resButton:SetText(mode:gsub("^%l", string.upper))
    end
end

local function ApplyMainBar()
    local width = tonumber(menuFrame.widthEdit:GetText())
    local height = tonumber(menuFrame.heightEdit:GetText())
    local capPercent = tonumber(menuFrame.capEdit:GetText())
    local minCap = addon.PlayerBarConfig.GetMinCapPercent()

    if not width or width <= 0 or not height or height <= 0 then
        print("BloodShieldOverlay: width and height must be positive numbers.")
        return
    end
    if not capPercent or capPercent < minCap then
        print(string.format("BloodShieldOverlay: Max %% must be at least %d.", minCap))
        return
    end

    config.width = width
    config.height = height
    config.capMultiplier = capPercent / 100

    local bar = _G.BloodShieldOverlayBar
    if bar then
        bar:SetSize(width, height)
    end

    -- Reuse the existing Core 30 Hz player-update pipeline rather than adding
    -- a second update loop just for the menu.
    if addon.ScheduleUnitUpdate then
        addon.ScheduleUnitUpdate("player")
    end
end

local function ApplyPips()
    local rw = tonumber(menuFrame.resourcePipWidthEdit:GetText())
    local rh = tonumber(menuFrame.resourcePipHeightEdit:GetText())
    if addon.SetSpecialResourcePipSize and addon.SetSpecialResourcePipSize(rw, rh) then
        config.specialResourcePipWidth = rw
        config.specialResourcePipHeight = rh
    else
        print("BloodShieldOverlay: resource pip width must be 2-20 and height 2-32.")
        menuFrame.resourcePipWidthEdit:SetText(tostring(config.specialResourcePipWidth))
        menuFrame.resourcePipHeightEdit:SetText(tostring(config.specialResourcePipHeight))
    end

    local gw = tonumber(menuFrame.pipWidthEdit:GetText())
    local gh = tonumber(menuFrame.pipHeightEdit:GetText())
    if addon.SetClassResourceOverlayPipSize and addon.SetClassResourceOverlayPipSize(gw, gh) then
        config.classResourcePipWidth = gw
        config.classResourcePipHeight = gh
    else
        print("BloodShieldOverlay: group pip width must be 4-32 and height 2-20.")
        menuFrame.pipWidthEdit:SetText(tostring(config.classResourcePipWidth))
        menuFrame.pipHeightEdit:SetText(tostring(config.classResourcePipHeight))
    end
end

local function ApplyTargetTarget()
    local width = tonumber(menuFrame.targetTargetWidthEdit:GetText())
    local height = tonumber(menuFrame.targetTargetHeightEdit:GetText())
    if addon.TargetTargetBarAPI and addon.TargetTargetBarAPI.ApplySize then
        if not addon.TargetTargetBarAPI.ApplySize(width, height) then
            menuFrame.targetTargetWidthEdit:SetText(tostring(config.targetTargetWidth))
            menuFrame.targetTargetHeightEdit:SetText(tostring(config.targetTargetHeight))
        end
    end
end

local function CreateConfigMenu()
    if menuFrame then return end

    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(500, 545)
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

    local info = CreateLabel(menuFrame,
        "Click Unlock to drag the bar. Click Lock to anchor. Use /shield reload to refresh frames.",
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 18, -40)
    info:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -18, -40)
    info:SetJustifyH("LEFT")

    local colWidthHeader = CreateLabel(menuFrame, "Width", "GameFontNormalSmall")
    colWidthHeader:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 182, -14)
    local colHeightHeader = CreateLabel(menuFrame, "Height", "GameFontNormalSmall")
    colHeightHeader:SetPoint("LEFT", colWidthHeader, "LEFT", 65, 0)
    local colMaxHeader = CreateLabel(menuFrame, "Max %", "GameFontNormalSmall")
    colMaxHeader:SetPoint("LEFT", colHeightHeader, "LEFT", 65, 0)

    local row1 = CreateLabel(menuFrame, "Main Shield Bar:")
    row1:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -32)
    menuFrame.widthEdit = CreateInputBox(menuFrame, 45)
    menuFrame.widthEdit:SetPoint("LEFT", colWidthHeader, "LEFT", -4, -18)
    menuFrame.heightEdit = CreateInputBox(menuFrame, 45)
    menuFrame.heightEdit:SetPoint("LEFT", colHeightHeader, "LEFT", -4, -18)
    menuFrame.capEdit = CreateInputBox(menuFrame, 45)
    menuFrame.capEdit:SetPoint("LEFT", colMaxHeader, "LEFT", -4, -18)

    local mainApply = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    mainApply:SetSize(60, 24)
    mainApply:SetPoint("LEFT", menuFrame.capEdit, "RIGHT", 12, 0)
    mainApply:SetText("Apply")
    mainApply:SetScript("OnClick", ApplyMainBar)

    local row2 = CreateLabel(menuFrame, "Personal Pips:")
    row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -18)
    menuFrame.resourcePipWidthEdit = CreateInputBox(menuFrame, 45)
    menuFrame.resourcePipWidthEdit:SetPoint("LEFT", colWidthHeader, "LEFT", -4, -46)
    menuFrame.resourcePipHeightEdit = CreateInputBox(menuFrame, 45)
    menuFrame.resourcePipHeightEdit:SetPoint("LEFT", colHeightHeader, "LEFT", -4, -46)

    local row3 = CreateLabel(menuFrame, "Group Pips:")
    row3:SetPoint("TOPLEFT", row2, "BOTTOMLEFT", 0, -18)
    menuFrame.pipWidthEdit = CreateInputBox(menuFrame, 45)
    menuFrame.pipWidthEdit:SetPoint("LEFT", colWidthHeader, "LEFT", -4, -74)
    menuFrame.pipHeightEdit = CreateInputBox(menuFrame, 45)
    menuFrame.pipHeightEdit:SetPoint("LEFT", colHeightHeader, "LEFT", -4, -74)

    local pipApply = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    pipApply:SetSize(60, 24)
    pipApply:SetPoint("LEFT", colMaxHeader, "LEFT", -4, -74)
    pipApply:SetText("Apply")
    pipApply:SetScript("OnClick", ApplyPips)

    local resLabel = CreateLabel(menuFrame, "Personal Resource Bar:")
    resLabel:SetPoint("TOPLEFT", row3, "BOTTOMLEFT", 0, -18)
    local resButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    resButton:SetSize(80, 22)
    resButton:SetPoint("LEFT", resLabel, "RIGHT", 12, 0)
    resButton:SetScript("OnClick", function(self)
        if config.resourceDisplay == "left" then
            config.resourceDisplay = "right"
        elseif config.resourceDisplay == "right" then
            config.resourceDisplay = "none"
        else
            config.resourceDisplay = "left"
        end
        self:SetText(config.resourceDisplay:gsub("^%l", string.upper))
        if addon.UpdateSpecialResourcesLayout then addon.UpdateSpecialResourcesLayout() end
        if addon.ScheduleUnitUpdate then addon.ScheduleUnitUpdate("player") end
    end)
    menuFrame.resButton = resButton

    local visibilityCheck = CreateCheckBox(menuFrame, "Hide external shield bar", function(self)
        config.hideExternalBar = self:GetChecked() and true or false
        if addon.PlayerBarAPI and addon.PlayerBarAPI.SetHidden then addon.PlayerBarAPI.SetHidden(config.hideExternalBar) end
    end)
    visibilityCheck:SetPoint("TOPLEFT", resLabel, "BOTTOMLEFT", -2, -14)
    menuFrame.visibilityCheck = visibilityCheck

    local healthCheck = CreateCheckBox(menuFrame, "Show health bar (red, 100% base)", function(self)
        config.showHealth = self:GetChecked() and true or false
        if addon.ScheduleUnitUpdate then addon.ScheduleUnitUpdate("player") end
    end)
    healthCheck:SetPoint("TOPLEFT", visibilityCheck, "BOTTOMLEFT", 0, -2)
    menuFrame.healthCheck = healthCheck

    local specialResCheck = CreateCheckBox(menuFrame, "Show special resources (circles)", function(self)
        config.showSpecialResources = self:GetChecked() and true or false
        if addon.UpdateSpecialResources then addon.UpdateSpecialResources() end
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
    -- Target of Target: deliberately uses the same row/column language and
    -- controls as the rest of this menu. It is not a separate popup.
    ---------------------------------------------------------------------------
    local targetTitle = CreateLabel(menuFrame, "Target of Target:")
    targetTitle:SetPoint("TOPLEFT", classOverlayCheck, "BOTTOMLEFT", 0, -14)

    local targetCheck = CreateCheckBox(menuFrame, "Show target of target frame", function(self)
        local enabled = self:GetChecked() and true or false
        if addon.TargetTargetBarAPI and addon.TargetTargetBarAPI.Enable then
            if not addon.TargetTargetBarAPI.Enable(enabled) then
                self:SetChecked(config.showTargetTarget and true or false)
            end
        end
    end)
    targetCheck:SetPoint("TOPLEFT", targetTitle, "BOTTOMLEFT", -2, -2)
    menuFrame.targetTargetCheck = targetCheck

    local tw = CreateLabel(menuFrame, "Width", "GameFontNormalSmall")
    tw:SetPoint("TOPLEFT", targetCheck, "BOTTOMLEFT", 4, -6)
    menuFrame.targetTargetWidthEdit = CreateInputBox(menuFrame, 45)
    menuFrame.targetTargetWidthEdit:SetPoint("LEFT", tw, "RIGHT", 8, 0)

    local th = CreateLabel(menuFrame, "Height", "GameFontNormalSmall")
    th:SetPoint("LEFT", menuFrame.targetTargetWidthEdit, "RIGHT", 16, 0)
    menuFrame.targetTargetHeightEdit = CreateInputBox(menuFrame, 45)
    menuFrame.targetTargetHeightEdit:SetPoint("LEFT", th, "RIGHT", 8, 0)

    local targetApply = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    targetApply:SetSize(60, 22)
    targetApply:SetPoint("LEFT", menuFrame.targetTargetHeightEdit, "RIGHT", 12, 0)
    targetApply:SetText("Apply")
    targetApply:SetScript("OnClick", ApplyTargetTarget)

    local targetUnlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    targetUnlock:SetSize(75, 22)
    targetUnlock:SetPoint("TOPLEFT", tw, "BOTTOMLEFT", -4, -8)
    targetUnlock:SetText("Unlock")
    targetUnlock:SetScript("OnClick", function()
        if addon.TargetTargetBarAPI then addon.TargetTargetBarAPI.SetLocked(false) end
    end)

    local targetLock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    targetLock:SetSize(65, 22)
    targetLock:SetPoint("LEFT", targetUnlock, "RIGHT", 6, 0)
    targetLock:SetText("Lock")
    targetLock:SetScript("OnClick", function()
        if addon.TargetTargetBarAPI then addon.TargetTargetBarAPI.SetLocked(true) end
    end)

    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(85, 24)
    unlock:SetPoint("BOTTOMLEFT", menuFrame, "BOTTOMLEFT", 16, 16)
    unlock:SetText("Unlock")
    unlock:SetScript("OnClick", function()
        if addon.PlayerBarAPI then addon.PlayerBarAPI.SetLocked(false) end
    end)

    local lock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    lock:SetSize(85, 24)
    lock:SetPoint("LEFT", unlock, "RIGHT", 8, 0)
    lock:SetText("Lock")
    lock:SetScript("OnClick", function()
        if addon.PlayerBarAPI then addon.PlayerBarAPI.SetLocked(true) end
    end)

    local closeBtn = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(85, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -16, 16)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() menuFrame:Hide() end)
end

local function ShowConfigMenu()
    if not config then config = addon.PlayerBarConfig.Initialize() end
    CreateConfigMenu()
    Refresh()
    menuFrame:Show()
end

addon.MenuAPI = {
    ShowConfigMenu = ShowConfigMenu,
    Refresh = Refresh,
}

addon.RegisterInitializer(function()
    config = addon.PlayerBarConfig.Initialize()

    -- Menu.lua is the sole owner of the active /shield UI. PlayerBar's legacy
    -- menu remains unreachable for compatibility, but its API is replaced here.
    if addon.PlayerBarAPI then
        addon.PlayerBarAPI.ShowConfigMenu = ShowConfigMenu
    end
    addon.ShowConfigMenu = ShowConfigMenu
end)
