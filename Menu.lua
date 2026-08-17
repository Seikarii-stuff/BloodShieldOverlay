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

local function RefreshMouseCooldownDropdowns()
    if not menuFrame or not menuFrame.mouseCooldown1Button then return end
    local options = addon.GetMouseCooldownOptions and addon.GetMouseCooldownOptions() or {}

    local function findName(spellID)
        for index = 1, #options do
            local entry = options[index]
            local id = type(entry) == "number" and entry or entry.id
            local name = type(entry) == "number" and tostring(entry) or entry.name
            if id == spellID then return name end
        end
        return "None"
    end

    menuFrame.mouseCooldown1Button:SetText(findName(config.mouseCooldown1Spell))
    menuFrame.mouseCooldown2Button:SetText(findName(config.mouseCooldown2Spell))
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
    if spellID and config["mouseCooldown" .. otherSlot .. "Spell"] == spellID then
        return false
    end
    config["mouseCooldown" .. slot .. "Spell"] = spellID
    if addon.RefreshMouseCooldowns then addon.RefreshMouseCooldowns() end
    RefreshMouseCooldownDropdowns()
    return true
end

local function CreateMouseCooldownDropdown(parent, button, slot)
    button:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, self, "cursor", 0, 0)
    end)
    button:SetScript("OnShow", function(self)
        UIDropDownMenu_Initialize(self, function(frame, level)
            if level ~= 1 then return end
            local options = addon.GetMouseCooldownOptions and addon.GetMouseCooldownOptions() or {}
            local otherSlot = slot == 1 and 2 or 1
            local otherID = config["mouseCooldown" .. otherSlot .. "Spell"]

            local noneInfo = UIDropDownMenu_CreateInfo()
            noneInfo.text = "None"
            noneInfo.checked = config["mouseCooldown" .. slot .. "Spell"] == nil
            noneInfo.func = function()
                SetMouseCooldown(slot, nil)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(noneInfo)

            for index = 1, #options do
                local entry = options[index]
                local id = type(entry) == "number" and entry or entry.id
                local name = type(entry) == "number" and tostring(entry) or entry.name
                if id and id ~= otherID then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = name or tostring(id)
                    info.value = id
                    info.checked = config["mouseCooldown" .. slot .. "Spell"] == id
                    info.disabled = IsPlayerSpell and not IsPlayerSpell(id) or false
                    info.func = function()
                        SetMouseCooldown(slot, id)
                        CloseDropDownMenus()
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end)
    end)
    UIDropDownMenu_SetWidth(145, button)
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

    local title = CreateLabel(menuFrame, "Shield Bar Settings", "GameFontNormalLarge")
    title:SetPoint("TOP", menuFrame, "TOP", 0, -14)
    local info = CreateLabel(menuFrame, "Unlock moves all addon bars. Lock anchors them. Use /shield reload to refresh frames.", "GameFontHighlightSmall")
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

    local targetRow = CreateLabel(menuFrame, "Target of Target:")
    targetRow:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -12)
    menuFrame.targetTargetWidthEdit = CreateInputBox(menuFrame, 45)
    menuFrame.targetTargetWidthEdit:SetPoint("LEFT", colWidthHeader, "LEFT", -4, -44)
    menuFrame.targetTargetHeightEdit = CreateInputBox(menuFrame, 45)
    menuFrame.targetTargetHeightEdit:SetPoint("LEFT", colHeightHeader, "LEFT", -4, -44)
    local targetApply = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    targetApply:SetSize(60, 24)
    targetApply:SetPoint("LEFT", colMaxHeader, "LEFT", -4, -44)
    targetApply:SetText("Apply")
    targetApply:SetScript("OnClick", ApplyTargetTarget)
    local targetCheck = CreateCheckBox(menuFrame, "Show target of target frame", function(self)
        local enabled = self:GetChecked() and true or false
        if addon.TargetTargetBarAPI and addon.TargetTargetBarAPI.Enable then
            if not addon.TargetTargetBarAPI.Enable(enabled) then self:SetChecked(config.showTargetTarget and true or false) end
        end
    end)
    targetCheck:SetPoint("LEFT", targetApply, "RIGHT", 10, 0)
    menuFrame.targetTargetCheck = targetCheck

    local row2 = CreateLabel(menuFrame, "Personal Pips:")
    row2:SetPoint("TOPLEFT", targetRow, "BOTTOMLEFT", 0, -18)
    menuFrame.resourcePipWidthEdit = CreateInputBox(menuFrame, 45)
    menuFrame.resourcePipWidthEdit:SetPoint("LEFT", colWidthHeader, "LEFT", -4, -74)
    menuFrame.resourcePipHeightEdit = CreateInputBox(menuFrame, 45)
    menuFrame.resourcePipHeightEdit:SetPoint("LEFT", colHeightHeader, "LEFT", -4, -74)

    local row3 = CreateLabel(menuFrame, "Group Pips:")
    row3:SetPoint("TOPLEFT", row2, "BOTTOMLEFT", 0, -18)
    menuFrame.pipWidthEdit = CreateInputBox(menuFrame, 45)
    menuFrame.pipWidthEdit:SetPoint("LEFT", colWidthHeader, "LEFT", -4, -102)
    menuFrame.pipHeightEdit = CreateInputBox(menuFrame, 45)
    menuFrame.pipHeightEdit:SetPoint("LEFT", colHeightHeader, "LEFT", -4, -102)
    local pipApply = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    pipApply:SetSize(60, 24)
    pipApply:SetPoint("LEFT", colMaxHeader, "LEFT", -4, -102)
    pipApply:SetText("Apply")
    pipApply:SetScript("OnClick", ApplyPips)

    local resLabel = CreateLabel(menuFrame, "Personal Resource Bar:")
    resLabel:SetPoint("TOPLEFT", row3, "BOTTOMLEFT", 0, -18)
    local resButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    resButton:SetSize(80, 22)
    resButton:SetPoint("LEFT", resLabel, "RIGHT", 12, 0)
    resButton:SetScript("OnClick", function(self)
        if config.resourceDisplay == "left" then config.resourceDisplay = "right"
        elseif config.resourceDisplay == "right" then config.resourceDisplay = "none"
        else config.resourceDisplay = "left" end
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
        if addon.SetClassResourceOverlayEnabled then addon.SetClassResourceOverlayEnabled(config.showClassResourceOverlay) end
    end)
    classOverlayCheck:SetPoint("TOPLEFT", specialResCheck, "BOTTOMLEFT", 0, -2)
    menuFrame.classOverlayCheck = classOverlayCheck

    local mouseResourceCheck = CreateCheckBox(menuFrame, "Show special resources around mouse", function(self)
        local enabled = self:GetChecked() and true or false
        config.showMouseSpecialResources = enabled
        if addon.SetMouseResourceOverlayEnabled then addon.SetMouseResourceOverlayEnabled(enabled) end
    end)
    mouseResourceCheck:SetPoint("TOPLEFT", classOverlayCheck, "BOTTOMLEFT", 0, -2)
    menuFrame.mouseResourceCheck = mouseResourceCheck

    local mouseHeader = CreateLabel(menuFrame, "Mouse Cooldowns:", "GameFontNormal")
    mouseHeader:SetPoint("TOPLEFT", mouseResourceCheck, "BOTTOMLEFT", 2, -12)

    local mouseCooldown1Check = CreateCheckBox(menuFrame, "Slot 1", function(self)
        config.showMouseCooldown1 = self:GetChecked() and true or false
        if addon.SetMouseResourceOverlayEnabled then
            addon.SetMouseResourceOverlayEnabled(config.showMouseSpecialResources or config.showMouseCooldown1 or config.showMouseCooldown2)
        end
    end)
    mouseCooldown1Check:SetPoint("TOPLEFT", mouseHeader, "BOTTOMLEFT", -2, -4)
    menuFrame.mouseCooldown1Check = mouseCooldown1Check

    local mouseCooldown1Button = CreateFrame("Button", "BloodShieldOverlayMouseCooldownDropdown1", menuFrame, "UIPanelButtonTemplate")
    mouseCooldown1Button:SetSize(145, 22)
    mouseCooldown1Button:SetPoint("LEFT", mouseCooldown1Check, "RIGHT", 10, 0)
    menuFrame.mouseCooldown1Button = mouseCooldown1Button
    CreateMouseCooldownDropdown(menuFrame, mouseCooldown1Button, 1)

    local mouseCooldown2Check = CreateCheckBox(menuFrame, "Slot 2", function(self)
        config.showMouseCooldown2 = self:GetChecked() and true or false
        if addon.SetMouseResourceOverlayEnabled then
            addon.SetMouseResourceOverlayEnabled(config.showMouseSpecialResources or config.showMouseCooldown1 or config.showMouseCooldown2)
        end
    end)
    mouseCooldown2Check:SetPoint("TOPLEFT", mouseCooldown1Check, "BOTTOMLEFT", 0, -4)
    menuFrame.mouseCooldown2Check = mouseCooldown2Check

    local mouseCooldown2Button = CreateFrame("Button", "BloodShieldOverlayMouseCooldownDropdown2", menuFrame, "UIPanelButtonTemplate")
    mouseCooldown2Button:SetSize(145, 22)
    mouseCooldown2Button:SetPoint("LEFT", mouseCooldown2Check, "RIGHT", 10, 0)
    menuFrame.mouseCooldown2Button = mouseCooldown2Button
    CreateMouseCooldownDropdown(menuFrame, mouseCooldown2Button, 2)

    local unlock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    unlock:SetSize(85, 24)
    unlock:SetPoint("BOTTOMLEFT", menuFrame, "BOTTOMLEFT", 16, 16)
    unlock:SetText("Unlock")
    unlock:SetScript("OnClick", function() SetAllBarsLocked(false) end)
    local lock = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    lock:SetSize(85, 24)
    lock:SetPoint("LEFT", unlock, "RIGHT", 8, 0)
    lock:SetText("Lock")
    lock:SetScript("OnClick", function() SetAllBarsLocked(true) end)
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

addon.MenuAPI = { ShowConfigMenu = ShowConfigMenu, Refresh = Refresh }

addon.RegisterInitializer(function()
    config = addon.PlayerBarConfig.Initialize()
    if addon.PlayerBarAPI then addon.PlayerBarAPI.ShowConfigMenu = ShowConfigMenu end
    addon.ShowConfigMenu = ShowConfigMenu
end)
