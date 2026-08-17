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

local function SetAllBarsLocked(locked)
    if addon.PlayerBarAPI and addon.PlayerBarAPI.SetLocked then addon.PlayerBarAPI.SetLocked(locked) end
    if addon.TargetTargetBarAPI and addon.TargetTargetBarAPI.SetLocked then addon.TargetTargetBarAPI.SetLocked(locked) end
    config.locked = locked and true or false
    config.targetTargetLocked = locked and true or false
end

local function GetMouseCooldownOptions()
    return addon.GetMouseCooldownOptions and addon.GetMouseCooldownOptions() or {}
end

local function FindSpellName(spellID)
    if not spellID then return "None" end
    local options = GetMouseCooldownOptions()
    for index = 1, #options do
        local entry = options[index]
        local id = type(entry) == "number" and entry or entry.id
        if id == spellID then return type(entry) == "number" and tostring(entry) or entry.name end
    end
    return "None"
end

local function RefreshMouseCooldownDropdowns()
    if not menuFrame or not menuFrame.mouseCooldown1Button then return end
    UIDropDownMenu_SetText(FindSpellName(config.mouseCooldown1Spell), menuFrame.mouseCooldown1Button)
    UIDropDownMenu_SetText(FindSpellName(config.mouseCooldown2Spell), menuFrame.mouseCooldown2Button)
end

local function Refresh()
    if not menuFrame or not config then return end
    menuFrame.widthEdit:SetText(tostring(config.width))
    menuFrame.heightEdit:SetText(tostring(config.height))
    menuFrame.capEdit:SetText(tostring((config.capMultiplier or 2) * 100))
    menuFrame.targetTargetWidthEdit:SetText(tostring(config.targetTargetWidth))
    menuFrame.targetTargetHeightEdit:SetText(tostring(config.targetTargetHeight))
    menuFrame.resourcePipWidthEdit:SetText(tostring(config.specialResourcePipWidth))
    menuFrame.resourcePipHeightEdit:SetText(tostring(config.specialResourcePipHeight))
    menuFrame.pipWidthEdit:SetText(tostring(config.classResourcePipWidth))
    menuFrame.pipHeightEdit:SetText(tostring(config.classResourcePipHeight))
    menuFrame.visibilityCheck:SetChecked(config.hideExternalBar and true or false)
    menuFrame.healthCheck:SetChecked(config.showHealth and true or false)
    menuFrame.specialResCheck:SetChecked(config.showSpecialResources and true or false)
    menuFrame.classOverlayCheck:SetChecked(config.showClassResourceOverlay and true or false)
    menuFrame.targetTargetCheck:SetChecked(config.showTargetTarget and true or false)
    menuFrame.mouseResourceCheck:SetChecked(config.showMouseSpecialResources and true or false)
    menuFrame.mouseCooldown1Check:SetChecked(config.showMouseCooldown1 and true or false)
    menuFrame.mouseCooldown2Check:SetChecked(config.showMouseCooldown2 and true or false)
    RefreshMouseCooldownDropdowns()
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
    if addon.PlayerBarAPI and addon.PlayerBarAPI.ApplyDimensions then
        if addon.PlayerBarAPI.ApplyDimensions(width, height, capPercent) then
            config.width, config.height, config.capMultiplier = width, height, capPercent / 100
        end
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

local function ApplyPips()
    local rw = tonumber(menuFrame.resourcePipWidthEdit:GetText())
    local rh = tonumber(menuFrame.resourcePipHeightEdit:GetText())
    if addon.SetSpecialResourcePipSize and addon.SetSpecialResourcePipSize(rw, rh) then
        config.specialResourcePipWidth, config.specialResourcePipHeight = rw, rh
    else
        print("BloodShieldOverlay: resource pip width must be 2-20 and height 2-32.")
        menuFrame.resourcePipWidthEdit:SetText(tostring(config.specialResourcePipWidth))
        menuFrame.resourcePipHeightEdit:SetText(tostring(config.specialResourcePipHeight))
    end
    local gw = tonumber(menuFrame.pipWidthEdit:GetText())
    local gh = tonumber(menuFrame.pipHeightEdit:GetText())
    if addon.SetClassResourceOverlayPipSize and addon.SetClassResourceOverlayPipSize(gw, gh) then
        config.classResourcePipWidth, config.classResourcePipHeight = gw, gh
    else
        print("BloodShieldOverlay: group pip width must be 4-32 and height 2-20.")
        menuFrame.pipWidthEdit:SetText(tostring(config.classResourcePipWidth))
        menuFrame.pipHeightEdit:SetText(tostring(config.classResourcePipHeight))
    end
end

local function SetMouseCooldown(slot, spellID)
    local otherSlot = slot == 1 and 2 or 1
    if spellID and config["mouseCooldown" .. otherSlot .. "Spell"] == spellID then return false end
    config["mouseCooldown" .. slot .. "Spell"] = spellID
    if addon.RefreshMouseCooldowns then addon.RefreshMouseCooldowns() end
    RefreshMouseCooldownDropdowns()
    return true
end

local function CreateMouseCooldownDropdown(parent, button, slot)
    UIDropDownMenu_Initialize(button, function(frame, level)
        if level ~= 1 then return end

        local options = GetMouseCooldownOptions()
        local otherSlot = slot == 1 and 2 or 1
        local otherID = config["mouseCooldown" .. otherSlot .. "Spell"]

        local noneInfo = UIDropDownMenu_CreateInfo()
        noneInfo.text = "None"
        noneInfo.checked = config["mouseCooldown" .. slot .. "Spell"] == nil
        noneInfo.hasArrow = false
        noneInfo.icon = nil
        noneInfo.func = function()
            SetMouseCooldown(slot, nil)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(noneInfo, level)

        for index = 1, #options do
            local entry = options[index]
            local id = type(entry) == "number" and entry or entry.id
            local name = type(entry) == "number" and tostring(entry) or entry.name
            if id and id ~= otherID then
                local info = UIDropDownMenu_CreateInfo()
                info.text = name or tostring(id)
                info.value = id
                info.checked = config["mouseCooldown" .. slot .. "Spell"] == id
                info.hasArrow = false
                info.icon = nil
                info.func = function()
                    SetMouseCooldown(slot, id)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)
    -- Midnight's UIDropDownMenu_SetWidth signature is (width, frame).
    UIDropDownMenu_SetWidth(145, button)
    button:SetScript("OnShow", function(self)
        UIDropDownMenu_SetText(FindSpellName(config["mouseCooldown" .. slot .. "Spell"]), self)
    end)
end

local function CreateConfigMenu()
    if menuFrame then return end
    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(500, 620)
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

    local title = CreateLabel(menuFrame, "BloodShieldOverlay", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -20)

    local y = -58
    local function nextRow(height)
        local rowY = y
        y = y - (height or 30)
        return rowY
    end

    local function AddSizeRow(label, widthField, heightField)
        local rowY = nextRow(32)
        CreateLabel(menuFrame, label):SetPoint("TOPLEFT", 30, rowY)
        widthField:SetPoint("TOPLEFT", 210, rowY + 3)
        heightField:SetPoint("TOPLEFT", 275, rowY + 3)
    end

    menuFrame.widthEdit = CreateInputBox(menuFrame, 55)
    menuFrame.heightEdit = CreateInputBox(menuFrame, 55)
    AddSizeRow("Main bar Width / Height", menuFrame.widthEdit, menuFrame.heightEdit)

    menuFrame.targetTargetWidthEdit = CreateInputBox(menuFrame, 55)
    menuFrame.targetTargetHeightEdit = CreateInputBox(menuFrame, 55)
    AddSizeRow("Target of Target Width / Height", menuFrame.targetTargetWidthEdit, menuFrame.targetTargetHeightEdit)

    menuFrame.resourcePipWidthEdit = CreateInputBox(menuFrame, 55)
    menuFrame.resourcePipHeightEdit = CreateInputBox(menuFrame, 55)
    AddSizeRow("Special Resource Width / Height", menuFrame.resourcePipWidthEdit, menuFrame.resourcePipHeightEdit)

    menuFrame.pipWidthEdit = CreateInputBox(menuFrame, 55)
    menuFrame.pipHeightEdit = CreateInputBox(menuFrame, 55)
    AddSizeRow("Group Resource Width / Height", menuFrame.pipWidthEdit, menuFrame.pipHeightEdit)

    local capRow = nextRow(32)
    CreateLabel(menuFrame, "Main bar Max %"):SetPoint("TOPLEFT", 30, capRow)
    menuFrame.capEdit = CreateInputBox(menuFrame, 70)
    menuFrame.capEdit:SetPoint("TOPLEFT", 210, capRow + 3)

    local checkY = nextRow(32)
    menuFrame.visibilityCheck = CreateCheckBox(menuFrame, "Hide external bar", function(self)
        config.hideExternalBar = self:GetChecked()
        if addon.PlayerBarAPI and addon.PlayerBarAPI.Refresh then addon.PlayerBarAPI.Refresh() end
    end)
    menuFrame.visibilityCheck:SetPoint("TOPLEFT", 30, checkY)

    checkY = nextRow(28)
    menuFrame.healthCheck = CreateCheckBox(menuFrame, "Show health", function(self)
        config.showHealth = self:GetChecked()
        if addon.PlayerBarAPI and addon.PlayerBarAPI.Refresh then addon.PlayerBarAPI.Refresh() end
    end)
    menuFrame.healthCheck:SetPoint("TOPLEFT", 30, checkY)

    checkY = nextRow(28)
    menuFrame.specialResCheck = CreateCheckBox(menuFrame, "Show special resources", function(self)
        config.showSpecialResources = self:GetChecked()
        if addon.PlayerBarAPI and addon.PlayerBarAPI.Refresh then addon.PlayerBarAPI.Refresh() end
    end)
    menuFrame.specialResCheck:SetPoint("TOPLEFT", 30, checkY)

    checkY = nextRow(28)
    menuFrame.classOverlayCheck = CreateCheckBox(menuFrame, "Show group resource overlay", function(self)
        config.showClassResourceOverlay = self:GetChecked()
        if addon.ClassResourceOverlayAPI and addon.ClassResourceOverlayAPI.Refresh then addon.ClassResourceOverlayAPI.Refresh() end
    end)
    menuFrame.classOverlayCheck:SetPoint("TOPLEFT", 30, checkY)

    checkY = nextRow(28)
    menuFrame.targetTargetCheck = CreateCheckBox(menuFrame, "Show target of target frame", function(self)
        config.showTargetTarget = self:GetChecked()
        if addon.TargetTargetBarAPI and addon.TargetTargetBarAPI.Refresh then addon.TargetTargetBarAPI.Refresh() end
    end)
    menuFrame.targetTargetCheck:SetPoint("TOPLEFT", 30, checkY)

    checkY = nextRow(28)
    menuFrame.mouseResourceCheck = CreateCheckBox(menuFrame, "Show special resources around mouse", function(self)
        config.showMouseSpecialResources = self:GetChecked()
        if addon.SetMouseResourceOverlayEnabled then addon.SetMouseResourceOverlayEnabled(self:GetChecked()) end
    end)
    menuFrame.mouseResourceCheck:SetPoint("TOPLEFT", 30, checkY)

    checkY = nextRow(28)
    menuFrame.mouseCooldown1Check = CreateCheckBox(menuFrame, "Show mouse cooldown 1", function(self)
        config.showMouseCooldown1 = self:GetChecked()
        if addon.RefreshMouseCooldowns then addon.RefreshMouseCooldowns() end
    end)
    menuFrame.mouseCooldown1Check:SetPoint("TOPLEFT", 30, checkY)

    menuFrame.mouseCooldown1Button = CreateFrame("Button", "BloodShieldOverlayMouseCooldownDropdown1", menuFrame, "UIDropDownMenuTemplate")
    menuFrame.mouseCooldown1Button:SetPoint("TOPLEFT", 245, checkY - 4)
    CreateMouseCooldownDropdown(menuFrame, menuFrame.mouseCooldown1Button, 1)

    checkY = nextRow(28)
    menuFrame.mouseCooldown2Check = CreateCheckBox(menuFrame, "Show mouse cooldown 2", function(self)
        config.showMouseCooldown2 = self:GetChecked()
        if addon.RefreshMouseCooldowns then addon.RefreshMouseCooldowns() end
    end)
    menuFrame.mouseCooldown2Check:SetPoint("TOPLEFT", 30, checkY)

    menuFrame.mouseCooldown2Button = CreateFrame("Button", "BloodShieldOverlayMouseCooldownDropdown2", menuFrame, "UIDropDownMenuTemplate")
    menuFrame.mouseCooldown2Button:SetPoint("TOPLEFT", 245, checkY - 4)
    CreateMouseCooldownDropdown(menuFrame, menuFrame.mouseCooldown2Button, 2)

    local applyRow = nextRow(36)
    local apply = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    apply:SetSize(100, 24)
    apply:SetPoint("TOPLEFT", 30, applyRow)
    apply:SetText("Apply")
    apply:SetScript("OnClick", function()
        ApplyMainBar()
        ApplyTargetTarget()
        ApplyPips()
        Refresh()
    end)

    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(100, 24)
    unlock:SetPoint("TOPLEFT", 140, applyRow)
    unlock:SetText(config and config.locked == false and "Lock" or "Unlock")
    unlock:SetScript("OnClick", function(self)
        local shouldLock = not (config.locked == false)
        SetAllBarsLocked(shouldLock)
        self:SetText(shouldLock and "Unlock" or "Lock")
    end)

    local close = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    close:SetSize(100, 24)
    close:SetPoint("TOPLEFT", 250, applyRow)
    close:SetText("Close")
    close:SetScript("OnClick", function() menuFrame:Hide() end)
end

function addon.ShowConfigMenu()
    config = addon.PlayerBarConfig.Initialize()
    CreateConfigMenu()
    Refresh()
    menuFrame:Show()
end

addon.RegisterInitializer(function()
    config = addon.PlayerBarConfig.Initialize()
end)
