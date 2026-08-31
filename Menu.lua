-- Central /shield configuration UI.
-- Numeric fields are staged and committed with Apply ALL. Checkboxes are immediate.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local menuFrame
local config
local Refresh

local function Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetText(text)
    return fs
end

local function Input(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width or 55, 24)
    box:SetAutoFocus(false)
    return box
end

local function Check(parent, text, callback)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    if check.Text then check.Text:SetText(text) end
    check:SetScript("OnClick", callback)
    return check
end

local function SetAllBarsLocked(locked)
    locked = locked == true
    if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetLocked) == "function" then addon.PlayerBarAPI.SetLocked(locked) end
    if addon.TargetTargetBarAPI and type(addon.TargetTargetBarAPI.SetLocked) == "function" then addon.TargetTargetBarAPI.SetLocked(locked) end
    config.locked = locked
    config.targetTargetLocked = locked
end

local function ResetBarEditState()
    SetAllBarsLocked(true)
    if menuFrame and menuFrame.unlockButton then
        menuFrame.unlockButton:SetText("Unlock bars")
    end
end

local function ApplyMainBar()
    local width = tonumber(menuFrame.widthEdit:GetText())
    local height = tonumber(menuFrame.heightEdit:GetText())
    local cap = tonumber(menuFrame.capEdit:GetText())
    local minCap = addon.PlayerBarConfig.GetMinCapPercent()
    if not width or width <= 0 or not height or height <= 0 then print("BloodShieldOverlay: width and height must be positive numbers."); return false end
    if not cap or cap < minCap then print(string.format("BloodShieldOverlay: Max %% must be at least %d.", minCap)); return false end
    return addon.PlayerBarAPI and type(addon.PlayerBarAPI.ApplyDimensions) == "function" and addon.PlayerBarAPI.ApplyDimensions(width, height, cap) == true
end

local function ApplyTargetTarget()
    local width = tonumber(menuFrame.targetTargetWidthEdit:GetText())
    local height = tonumber(menuFrame.targetTargetHeightEdit:GetText())
    if not width or width <= 0 or not height or height <= 0 then return false end
    return addon.TargetTargetBarAPI and type(addon.TargetTargetBarAPI.ApplySize) == "function" and addon.TargetTargetBarAPI.ApplySize(width, height) == true
end

local function ApplyPips()
    local rw = tonumber(menuFrame.resourcePipWidthEdit:GetText())
    local rh = tonumber(menuFrame.resourcePipHeightEdit:GetText())
    local gw = tonumber(menuFrame.pipWidthEdit:GetText())
    local gh = tonumber(menuFrame.pipHeightEdit:GetText())
    if not rw or not rh or not gw or not gh then return false end
    local ok = true
    if type(addon.SetSpecialResourcePipSize) == "function" then ok = addon.SetSpecialResourcePipSize(rw, rh) == true and ok end
    if type(addon.SetClassResourceOverlayPipSize) == "function" then ok = addon.SetClassResourceOverlayPipSize(gw, gh) == true and ok end
    return ok
end

local function ApplyAll()
    local okMain = ApplyMainBar()
    local okTarget = ApplyTargetTarget()
    local okPips = ApplyPips()
    if okMain and okTarget and okPips then print("BloodShieldOverlay: size / cap settings applied.") else print("BloodShieldOverlay: one or more size settings could not be applied.") end
    Refresh()
end

Refresh = function()
    if not menuFrame or not config then return end
    menuFrame.widthEdit:SetText(tostring(config.width or 18))
    menuFrame.heightEdit:SetText(tostring(config.height or 150))
    menuFrame.capEdit:SetText(tostring((config.capMultiplier or 2) * 100))
    menuFrame.targetTargetWidthEdit:SetText(tostring(config.targetTargetWidth or 130))
    menuFrame.targetTargetHeightEdit:SetText(tostring(config.targetTargetHeight or 10))
    menuFrame.resourcePipWidthEdit:SetText(tostring(config.specialResourcePipWidth or 2))
    menuFrame.resourcePipHeightEdit:SetText(tostring(config.specialResourcePipHeight or 10))
    menuFrame.pipWidthEdit:SetText(tostring(config.classResourcePipWidth or 12))
    menuFrame.pipHeightEdit:SetText(tostring(config.classResourcePipHeight or 6))

    menuFrame.visibilityCheck:SetChecked(config.hideExternalBar == true)
    menuFrame.healthCheck:SetChecked(config.showHealth ~= false)
    menuFrame.specialResCheck:SetChecked(config.showSpecialResources ~= false)
    menuFrame.classOverlayCheck:SetChecked(config.showClassResourceOverlay ~= false)
    menuFrame.targetTargetCheck:SetChecked(config.showTargetTarget == true)
    menuFrame.unlockButton:SetText("Unlock bars")
end

local function CreateConfigMenu()
    if menuFrame then return end
    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(520, 500)
    menuFrame:SetPoint("CENTER")
    menuFrame:SetFrameStrata("DIALOG")
    menuFrame:SetMovable(true)
    menuFrame:EnableMouse(true)
    menuFrame:RegisterForDrag("LeftButton")
    menuFrame:SetClampedToScreen(true)
    menuFrame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 }})
    menuFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    menuFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    menuFrame:SetScript("OnHide", ResetBarEditState)

    Label(menuFrame, "BloodShieldOverlay", "GameFontHighlightLarge"):SetPoint("TOP", 0, -18)
    Label(menuFrame, "Width / height / max % fields below are staged until Apply ALL. Checkboxes apply instantly.", "GameFontNormalSmall"):SetPoint("TOP", 0, -42)

    local y = -70
    local function row(step) local current = y; y = y - (step or 30); return current end
    local function SizeRow(text, widthBox, heightBox)
        local ry = row(32)
        Label(menuFrame, text):SetPoint("TOPLEFT", 28, ry)
        widthBox:SetPoint("TOPLEFT", 235, ry + 2)
        heightBox:SetPoint("TOPLEFT", 300, ry + 2)
    end

    menuFrame.widthEdit, menuFrame.heightEdit = Input(menuFrame), Input(menuFrame)
    SizeRow("Main bar Width / Height", menuFrame.widthEdit, menuFrame.heightEdit)
    menuFrame.targetTargetWidthEdit, menuFrame.targetTargetHeightEdit = Input(menuFrame), Input(menuFrame)
    SizeRow("Target of Target Width / Height", menuFrame.targetTargetWidthEdit, menuFrame.targetTargetHeightEdit)
    menuFrame.resourcePipWidthEdit, menuFrame.resourcePipHeightEdit = Input(menuFrame), Input(menuFrame)
    SizeRow("Special Resource Width / Height", menuFrame.resourcePipWidthEdit, menuFrame.resourcePipHeightEdit)
    menuFrame.pipWidthEdit, menuFrame.pipHeightEdit = Input(menuFrame), Input(menuFrame)
    SizeRow("Group Resource Width / Height", menuFrame.pipWidthEdit, menuFrame.pipHeightEdit)

    local capY = row(32)
    Label(menuFrame, "Main bar Max %"):SetPoint("TOPLEFT", 28, capY)
    menuFrame.capEdit = Input(menuFrame, 70)
    menuFrame.capEdit:SetPoint("TOPLEFT", 235, capY + 2)

    local function AddCheck(text, callback)
        local ry = row(27)
        local check = Check(menuFrame, text, callback)
        check:SetPoint("TOPLEFT", 24, ry)
        return check
    end

    menuFrame.visibilityCheck = AddCheck("Hide external bar", function(self)
        config.hideExternalBar = self:GetChecked()
        if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetHidden) == "function" then addon.PlayerBarAPI.SetHidden(config.hideExternalBar) end
    end)
    menuFrame.healthCheck = AddCheck("Show health", function(self)
        config.showHealth = self:GetChecked()
        if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetHealthShown) == "function" then addon.PlayerBarAPI.SetHealthShown(config.showHealth) end
    end)
    menuFrame.specialResCheck = AddCheck("Show special resources", function(self)
        config.showSpecialResources = self:GetChecked()
        if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetSpecialResourcesShown) == "function" then addon.PlayerBarAPI.SetSpecialResourcesShown(config.showSpecialResources) end
    end)
    menuFrame.classOverlayCheck = AddCheck("Show group resource overlay", function(self)
        config.showClassResourceOverlay = self:GetChecked()
        if type(addon.SetClassResourceOverlayEnabled) == "function" then addon.SetClassResourceOverlayEnabled(config.showClassResourceOverlay) end
    end)
    menuFrame.targetTargetCheck = AddCheck("Show target of target frame (target something to see it)", function(self)
        config.showTargetTarget = self:GetChecked()
        if addon.TargetTargetBarAPI and type(addon.TargetTargetBarAPI.Enable) == "function" then addon.TargetTargetBarAPI.Enable(config.showTargetTarget) end
    end)

    local actionY = row(36)
    local apply = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    apply:SetSize(120, 26)
    apply:SetPoint("TOPLEFT", 24, actionY)
    apply:SetText("Apply ALL")
    apply:SetScript("OnClick", ApplyAll)
    menuFrame.applyButton = apply

    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(120, 26)
    unlock:SetPoint("TOPLEFT", 154, actionY)
    unlock:SetText("Unlock bars")
    unlock:SetScript("OnClick", function(self)
        local lockedNow = config.locked ~= false
        SetAllBarsLocked(not lockedNow)
        self:SetText(config.locked == false and "Lock bars" or "Unlock bars")
    end)
    menuFrame.unlockButton = unlock

    local close = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    close:SetSize(100, 26)
    close:SetPoint("TOPLEFT", 284, actionY)
    close:SetText("Close")
    close:SetScript("OnClick", function() menuFrame:Hide() end)
end

function addon.ShowConfigMenu()
    config = addon.PlayerBarConfig.Initialize()
    CreateConfigMenu()
    ResetBarEditState()
    Refresh()
    menuFrame:Show()
end

addon.MenuAPI = addon.MenuAPI or {}
addon.MenuAPI.ShowConfigMenu = function() addon.ShowConfigMenu() end

addon.RegisterInitializer(function() config = addon.PlayerBarConfig.Initialize() end)
