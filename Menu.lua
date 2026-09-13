-- Central /shield configuration UI.
-- All values are written through the shared configuration API and reflect immediately.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local menuFrame
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
end

local function ResetBarEditState()
    SetAllBarsLocked(true)
    if menuFrame and menuFrame.unlockButton then
        menuFrame.unlockButton:SetText("Unlock bars")
    end
end

local function CommitNumericField(box, key, label, validator, defaultValue)
    if not box then return false end
    local value = tonumber(box:GetText())
    if value == nil or (validator and not validator(value)) then
        print("BloodShieldOverlay: " .. label .. " must be valid; restoring the saved value.")
        Refresh()
        return false
    end

    local ok = addon.PlayerBarConfig.Set(key, value)
    if not ok then
        print("BloodShieldOverlay: invalid " .. label .. " value; restoring the saved setting.")
        Refresh()
        return false
    end
    return true
end

Refresh = function()
    if not menuFrame then return end
    local config = addon.PlayerBarConfig.Get()
    if not config then return end

    menuFrame.widthEdit:SetText(tostring(config.width or 18))
    menuFrame.heightEdit:SetText(tostring(config.height or 150))
    menuFrame.targetTargetWidthEdit:SetText(tostring(config.targetTargetWidth or 130))
    menuFrame.targetTargetHeightEdit:SetText(tostring(config.targetTargetHeight or 10))
    menuFrame.resourcePipWidthEdit:SetText(tostring(config.specialResourcePipWidth or 2))
    menuFrame.resourcePipHeightEdit:SetText(tostring(config.specialResourcePipHeight or 10))
    menuFrame.pipWidthEdit:SetText(tostring(config.classResourcePipWidth or 12))
    menuFrame.pipHeightEdit:SetText(tostring(config.classResourcePipHeight or 6))

    menuFrame.visibilityCheck:SetChecked(config.hideExternalBar == true)
    menuFrame.classOverlayCheck:SetChecked(config.showClassResourceOverlay ~= false)
    menuFrame.targetTargetCheck:SetChecked(config.showTargetTarget == true)
    menuFrame.unlockButton:SetText(config.locked == false and "Lock bars" or "Unlock bars")
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
    Label(menuFrame, "Values update immediately and persist to the active profile.", "GameFontNormalSmall"):SetPoint("TOP", 0, -42)

    local y = -70
    local function row(step)
        local current = y
        y = y - (step or 30)
        return current
    end
    local function SizeRow(text, widthBox, heightBox)
        local ry = row(32)
        Label(menuFrame, text):SetPoint("TOPLEFT", 28, ry)
        widthBox:SetPoint("TOPLEFT", 235, ry + 2)
        heightBox:SetPoint("TOPLEFT", 300, ry + 2)
    end

    menuFrame.widthEdit, menuFrame.heightEdit = Input(menuFrame), Input(menuFrame)
    SizeRow("Main bar Width / Height", menuFrame.widthEdit, menuFrame.heightEdit)
    menuFrame.widthEdit:SetScript("OnEnterPressed", function(self) CommitNumericField(self, "width", "Main bar width", function(value) return type(value) == "number" and value > 0 end, 18) end)
    menuFrame.heightEdit:SetScript("OnEnterPressed", function(self) CommitNumericField(self, "height", "Main bar height", function(value) return type(value) == "number" and value > 0 end, 150) end)
    menuFrame.widthEdit:SetScript("OnEditFocusLost", function(self) CommitNumericField(self, "width", "Main bar width", function(value) return type(value) == "number" and value > 0 end, 18) end)
    menuFrame.heightEdit:SetScript("OnEditFocusLost", function(self) CommitNumericField(self, "height", "Main bar height", function(value) return type(value) == "number" and value > 0 end, 150) end)

    menuFrame.targetTargetWidthEdit, menuFrame.targetTargetHeightEdit = Input(menuFrame), Input(menuFrame)
    SizeRow("Target of Target Width / Height", menuFrame.targetTargetWidthEdit, menuFrame.targetTargetHeightEdit)
    menuFrame.targetTargetWidthEdit:SetScript("OnEnterPressed", function(self) CommitNumericField(self, "targetTargetWidth", "Target of target width", function(value) return type(value) == "number" and value > 0 end, 130) end)
    menuFrame.targetTargetHeightEdit:SetScript("OnEnterPressed", function(self) CommitNumericField(self, "targetTargetHeight", "Target of target height", function(value) return type(value) == "number" and value > 0 end, 10) end)
    menuFrame.targetTargetWidthEdit:SetScript("OnEditFocusLost", function(self) CommitNumericField(self, "targetTargetWidth", "Target of target width", function(value) return type(value) == "number" and value > 0 end, 130) end)
    menuFrame.targetTargetHeightEdit:SetScript("OnEditFocusLost", function(self) CommitNumericField(self, "targetTargetHeight", "Target of target height", function(value) return type(value) == "number" and value > 0 end, 10) end)

    menuFrame.resourcePipWidthEdit, menuFrame.resourcePipHeightEdit = Input(menuFrame), Input(menuFrame)
    SizeRow("Special Resource Width / Height", menuFrame.resourcePipWidthEdit, menuFrame.resourcePipHeightEdit)
    menuFrame.resourcePipWidthEdit:SetScript("OnEnterPressed", function(self) CommitNumericField(self, "specialResourcePipWidth", "Special resource width", function(value) return type(value) == "number" and value >= 2 and value <= 20 end, 2) end)
    menuFrame.resourcePipHeightEdit:SetScript("OnEnterPressed", function(self) CommitNumericField(self, "specialResourcePipHeight", "Special resource height", function(value) return type(value) == "number" and value >= 2 and value <= 32 end, 10) end)
    menuFrame.resourcePipWidthEdit:SetScript("OnEditFocusLost", function(self) CommitNumericField(self, "specialResourcePipWidth", "Special resource width", function(value) return type(value) == "number" and value >= 2 and value <= 20 end, 2) end)
    menuFrame.resourcePipHeightEdit:SetScript("OnEditFocusLost", function(self) CommitNumericField(self, "specialResourcePipHeight", "Special resource height", function(value) return type(value) == "number" and value >= 2 and value <= 32 end, 10) end)

    menuFrame.pipWidthEdit, menuFrame.pipHeightEdit = Input(menuFrame), Input(menuFrame)
    SizeRow("Group Resource Width / Height", menuFrame.pipWidthEdit, menuFrame.pipHeightEdit)
    menuFrame.pipWidthEdit:SetScript("OnEnterPressed", function(self) CommitNumericField(self, "classResourcePipWidth", "Group resource width", function(value) return type(value) == "number" and value >= 4 and value <= 32 end, 12) end)
    menuFrame.pipHeightEdit:SetScript("OnEnterPressed", function(self) CommitNumericField(self, "classResourcePipHeight", "Group resource height", function(value) return type(value) == "number" and value >= 2 and value <= 20 end, 6) end)
    menuFrame.pipWidthEdit:SetScript("OnEditFocusLost", function(self) CommitNumericField(self, "classResourcePipWidth", "Group resource width", function(value) return type(value) == "number" and value >= 4 and value <= 32 end, 12) end)
    menuFrame.pipHeightEdit:SetScript("OnEditFocusLost", function(self) CommitNumericField(self, "classResourcePipHeight", "Group resource height", function(value) return type(value) == "number" and value >= 2 and value <= 20 end, 6) end)

    local function AddCheck(text, callback)
        local ry = row(27)
        local check = Check(menuFrame, text, callback)
        check:SetPoint("TOPLEFT", 24, ry)
        return check
    end

    menuFrame.visibilityCheck = AddCheck("Hide external bar", function(self)
        addon.PlayerBarConfig.Set("hideExternalBar", self:GetChecked())
    end)
    menuFrame.classOverlayCheck = AddCheck("Show group resource overlay", function(self)
        addon.PlayerBarConfig.Set("showClassResourceOverlay", self:GetChecked())
    end)
    menuFrame.targetTargetCheck = AddCheck("Show target of target frame (target something to see it)", function(self)
        addon.PlayerBarConfig.Set("showTargetTarget", self:GetChecked())
    end)

    local actionY = row(36)
    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(120, 26)
    unlock:SetPoint("TOPLEFT", 24, actionY)
    unlock:SetText("Unlock bars")
    unlock:SetScript("OnClick", function(self)
        local lockedNow = addon.PlayerBarConfig.Get().locked ~= false
        SetAllBarsLocked(not lockedNow)
        self:SetText(addon.PlayerBarConfig.Get().locked == false and "Lock bars" or "Unlock bars")
    end)
    menuFrame.unlockButton = unlock

    local close = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    close:SetSize(100, 26)
    close:SetPoint("TOPLEFT", 154, actionY)
    close:SetText("Close")
    close:SetScript("OnClick", function() menuFrame:Hide() end)
end

function addon.ShowConfigMenu()
    CreateConfigMenu()
    Refresh()
    menuFrame:Show()
end

addon.MenuAPI = addon.MenuAPI or {}
addon.MenuAPI.ShowConfigMenu = function() addon.ShowConfigMenu() end

addon.PlayerBarConfig.Subscribe(function()
    if menuFrame then Refresh() end
end)
