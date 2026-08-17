-- Central /shield configuration UI.
-- Numeric fields are staged and committed with Apply ALL. Checkboxes and spell selections are immediate.

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

local function RefreshMouseOverlay()
    local enabled = config.showMouseSpecialResources == true
        or config.showMouseCooldown1 == true
        or config.showMouseCooldown2 == true
    if type(addon.SetMouseResourceOverlayEnabled) == "function" then addon.SetMouseResourceOverlayEnabled(enabled) end
end

local function SetAllBarsLocked(locked)
    locked = locked == true
    if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetLocked) == "function" then addon.PlayerBarAPI.SetLocked(locked) end
    if addon.TargetTargetBarAPI and type(addon.TargetTargetBarAPI.SetLocked) == "function" then addon.TargetTargetBarAPI.SetLocked(locked) end
    config.locked = locked
    config.targetTargetLocked = locked
end

local function SpellOptions()
    return type(addon.GetMouseCooldownOptions) == "function" and addon.GetMouseCooldownOptions() or {}
end

local function SpellName(spellID)
    if not spellID then return "None" end
    for _, entry in ipairs(SpellOptions()) do
        local id = type(entry) == "number" and entry or entry.id
        if id == spellID then return (type(entry) == "table" and entry.name) or tostring(id) end
    end
    return "None"
end

local function SetDropdownText(dropdown, spellID)
    if dropdown then UIDropDownMenu_SetText(dropdown, SpellName(spellID)) end
end

local function SetMouseSpell(slot, spellID)
    local other = slot == 1 and 2 or 1
    if spellID and config["mouseCooldown" .. other .. "Spell"] == spellID then return end
    config["mouseCooldown" .. slot .. "Spell"] = spellID
    RefreshMouseOverlay()
    SetDropdownText(menuFrame["mouseCooldown" .. slot .. "Button"], spellID)
end

local function CreateSpellDropdown(parent, name, slot)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetSize(160, 28)
    dropdown.initialize = function(_, level)
        if level ~= 1 then return end
        local selected = config["mouseCooldown" .. slot .. "Spell"]
        local other = slot == 1 and 2 or 1
        local otherID = config["mouseCooldown" .. other .. "Spell"]
        local none = UIDropDownMenu_CreateInfo()
        none.text = "None"
        none.checked = selected == nil
        none.func = function() SetMouseSpell(slot, nil); CloseDropDownMenus() end
        UIDropDownMenu_AddButton(none, level)
        for _, entry in ipairs(SpellOptions()) do
            local id = type(entry) == "number" and entry or entry.id
            local nameText = type(entry) == "table" and entry.name or tostring(id)
            if id and id ~= otherID then
                local info = UIDropDownMenu_CreateInfo()
                info.text = nameText
                info.value = id
                info.checked = selected == id
                info.func = function() SetMouseSpell(slot, id); CloseDropDownMenus() end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end
    UIDropDownMenu_Initialize(dropdown, dropdown.initialize)
    UIDropDownMenu_SetWidth(dropdown, 145)
    return dropdown
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
    local mw = tonumber(menuFrame.mouseCooldownPipSizeEdit:GetText())
    local spacing = tonumber(menuFrame.mouseResourceArcSpacingEdit:GetText())
    local start = tonumber(menuFrame.mouseResourceArcStartEdit:GetText())
    if not rw or not rh or not gw or not gh or not mw or not spacing or not start then return false end
    if spacing < 0.5 or spacing > 1.5 or start < 0.5 or start > 1.5 then return false end
    local ok = true
    if type(addon.SetSpecialResourcePipSize) == "function" then ok = addon.SetSpecialResourcePipSize(rw, rh) == true and ok end
    if type(addon.SetClassResourceOverlayPipSize) == "function" then ok = addon.SetClassResourceOverlayPipSize(gw, gh) == true and ok end
    config.mouseCooldownPipSize = mw
    config.mouseResourceArcSpacing = spacing
    config.mouseResourceArcStart = start
    if type(addon.RefreshMouseCooldowns) == "function" then addon.RefreshMouseCooldowns() end
    if type(addon.UpdateMouseResourceOverlay) == "function" then addon.UpdateMouseResourceOverlay() end
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
    menuFrame.mouseCooldownPipSizeEdit:SetText(tostring(config.mouseCooldownPipSize or 8))
    menuFrame.mouseResourceArcSpacingEdit:SetText(tostring(config.mouseResourceArcSpacing or 1.0))
    menuFrame.mouseResourceArcStartEdit:SetText(tostring(config.mouseResourceArcStart or 1.0))

    menuFrame.visibilityCheck:SetChecked(config.hideExternalBar == true)
    menuFrame.healthCheck:SetChecked(config.showHealth ~= false)
    menuFrame.specialResCheck:SetChecked(config.showSpecialResources ~= false)
    menuFrame.classOverlayCheck:SetChecked(config.showClassResourceOverlay ~= false)
    menuFrame.targetTargetCheck:SetChecked(config.showTargetTarget == true)
    menuFrame.mouseResourceCheck:SetChecked(config.showMouseSpecialResources == true)
    menuFrame.mouseCooldown1Check:SetChecked(config.showMouseCooldown1 == true)
    menuFrame.mouseCooldown2Check:SetChecked(config.showMouseCooldown2 == true)
    SetDropdownText(menuFrame.mouseCooldown1Button, config.mouseCooldown1Spell)
    SetDropdownText(menuFrame.mouseCooldown2Button, config.mouseCooldown2Spell)
    menuFrame.unlockButton:SetText(config.locked == false and "Lock ALL" or "Unlock ALL")
end

local function CreateConfigMenu()
    if menuFrame then return end
    menuFrame = CreateFrame("Frame", "BloodShieldOverlayConfig", UIParent, "BackdropTemplate")
    menuFrame:SetSize(520, 650)
    menuFrame:SetPoint("CENTER")
    menuFrame:SetFrameStrata("DIALOG")
    menuFrame:SetMovable(true)
    menuFrame:EnableMouse(true)
    menuFrame:RegisterForDrag("LeftButton")
    menuFrame:SetClampedToScreen(true)
    menuFrame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 }})
    menuFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    menuFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

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

    local mousePipY = row(32)
    Label(menuFrame, "Mouse cooldown pip size"):SetPoint("TOPLEFT", 28, mousePipY)
    menuFrame.mouseCooldownPipSizeEdit = Input(menuFrame, 55)
    menuFrame.mouseCooldownPipSizeEdit:SetPoint("TOPLEFT", 235, mousePipY + 2)

    local mouseArcY = row(32)
    Label(menuFrame, "Mouse resource arc spacing (0.5 to 1.5)"):SetPoint("TOPLEFT", 28, mouseArcY)
    menuFrame.mouseResourceArcSpacingEdit = Input(menuFrame, 55)
    menuFrame.mouseResourceArcSpacingEdit:SetPoint("TOPLEFT", 235, mouseArcY + 2)

    local mouseStartY = row(32)
    Label(menuFrame, "Mouse resource arc start (0.5 to 1.5)"):SetPoint("TOPLEFT", 28, mouseStartY)
    menuFrame.mouseResourceArcStartEdit = Input(menuFrame, 55)
    menuFrame.mouseResourceArcStartEdit:SetPoint("TOPLEFT", 235, mouseStartY + 2)

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

    menuFrame.visibilityCheck = AddCheck("Hide external bar", function(self) config.hideExternalBar = self:GetChecked(); if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetHidden) == "function" then addon.PlayerBarAPI.SetHidden(config.hideExternalBar) end end)
    menuFrame.healthCheck = AddCheck("Show health", function(self) config.showHealth = self:GetChecked(); if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetHealthShown) == "function" then addon.PlayerBarAPI.SetHealthShown(config.showHealth) end end)
    menuFrame.specialResCheck = AddCheck("Show special resources", function(self) config.showSpecialResources = self:GetChecked(); if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetSpecialResourcesShown) == "function" then addon.PlayerBarAPI.SetSpecialResourcesShown(config.showSpecialResources) end end)
    menuFrame.classOverlayCheck = AddCheck("Show group resource overlay", function(self) config.showClassResourceOverlay = self:GetChecked(); if type(addon.SetClassResourceOverlayEnabled) == "function" then addon.SetClassResourceOverlayEnabled(config.showClassResourceOverlay) end end)
    menuFrame.targetTargetCheck = AddCheck("Show target of target frame", function(self) config.showTargetTarget = self:GetChecked(); if addon.TargetTargetBarAPI and type(addon.TargetTargetBarAPI.Enable) == "function" then addon.TargetTargetBarAPI.Enable(config.showTargetTarget) end end)
    menuFrame.mouseResourceCheck = AddCheck("Show special resources around mouse", function(self) config.showMouseSpecialResources = self:GetChecked() == true; RefreshMouseOverlay() end)

    local cd1Y = row(30)
    menuFrame.mouseCooldown1Check = Check(menuFrame, "Show mouse cooldown 1")
    menuFrame.mouseCooldown1Check:SetPoint("TOPLEFT", 24, cd1Y)
    menuFrame.mouseCooldown1Check:SetScript("OnClick", function(self) config.showMouseCooldown1 = self:GetChecked() == true; RefreshMouseOverlay() end)
    menuFrame.mouseCooldown1Button = CreateSpellDropdown(menuFrame, "BloodShieldOverlayMouseCooldownDropdown1", 1)
    menuFrame.mouseCooldown1Button:SetPoint("TOPLEFT", 250, cd1Y - 5)

    local cd2Y = row(30)
    menuFrame.mouseCooldown2Check = Check(menuFrame, "Show mouse cooldown 2")
    menuFrame.mouseCooldown2Check:SetPoint("TOPLEFT", 24, cd2Y)
    menuFrame.mouseCooldown2Check:SetScript("OnClick", function(self) config.showMouseCooldown2 = self:GetChecked() == true; RefreshMouseOverlay() end)
    menuFrame.mouseCooldown2Button = CreateSpellDropdown(menuFrame, "BloodShieldOverlayMouseCooldownDropdown2", 2)
    menuFrame.mouseCooldown2Button:SetPoint("TOPLEFT", 250, cd2Y - 5)

    Label(menuFrame, "Cooldown slots share one class/spec spell list; the same spell cannot be selected twice.", "GameFontNormalSmall"):SetPoint("TOPLEFT", 28, row(30))

    local actionY = row(42)
    local apply = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    apply:SetSize(120, 26)
    apply:SetPoint("TOPLEFT", 24, actionY)
    apply:SetText("Apply ALL")
    apply:SetScript("OnClick", ApplyAll)

    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(120, 26)
    unlock:SetPoint("TOPLEFT", 154, actionY)
    unlock:SetText("Unlock ALL")
    unlock:SetScript("OnClick", function(self)
        local lockedNow = config.locked ~= false
        SetAllBarsLocked(not lockedNow)
        self:SetText(config.locked == false and "Lock ALL" or "Unlock ALL")
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
    Refresh()
    menuFrame:Show()
end

addon.MenuAPI = addon.MenuAPI or {}
addon.MenuAPI.ShowConfigMenu = function() addon.ShowConfigMenu() end

addon.RegisterInitializer(function() config = addon.PlayerBarConfig.Initialize() end)
