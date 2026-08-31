-- Interface Options panel for Shield Overlay.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local function OpenConfigMenu()
    if addon.PlayerBarAPI and addon.PlayerBarAPI.ShowConfigMenu then
        addon.PlayerBarAPI.ShowConfigMenu()
        return
    end
    if addon.ShowConfigMenu then
        addon.ShowConfigMenu()
        return
    end
    print("BloodShieldOverlay: configuration panel is not ready yet.")
end

local function SetGraphicsRate(config, rate)
    rate = tonumber(rate)
    if rate ~= 30 and rate ~= 60 then return end
    config.graphicsUpdateRate = rate
    if addon.SetGraphicsUpdateRate then addon.SetGraphicsUpdateRate(rate) end
end

local function CreatePerformanceControls(panel)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -132)
    title:SetText("Graphics update rate")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    description:SetText("Non-realtime addon visuals only")

    local config = addon.PlayerBarConfig.Initialize()
    local rate30 = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    rate30:SetPoint("TOPLEFT", 16, -178)
    rate30.Text:SetText("30 FPS")

    local rate60 = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    rate60:SetPoint("TOPLEFT", 100, -178)
    rate60.Text:SetText("60 FPS")

    local function Refresh()
        local current = addon.GetGraphicsUpdateRate and addon.GetGraphicsUpdateRate() or config.graphicsUpdateRate or 30
        rate30:SetChecked(current == 30)
        rate60:SetChecked(current == 60)
    end

    rate30:SetScript("OnClick", function()
        SetGraphicsRate(config, 30)
        Refresh()
    end)
    rate60:SetScript("OnClick", function()
        SetGraphicsRate(config, 60)
        Refresh()
    end)

    panel.BloodShieldOverlayGraphicsRateRefresh = Refresh
    Refresh()
end

local function CreateInterfaceOptionsPanel()
    -- Modern Settings API (Dragonflight 10.0+, still current in Midnight 12.1).
    -- InterfaceOptions_AddCategory was removed, so the old codepath silently
    -- no-ops and the panel never appears under AddOns.
    if type(Settings) ~= "table" or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
        return
    end

    local panel = CreateFrame("Frame", "BloodShieldOverlayOptionsPanel", UIParent)
    panel.name = "Shield Overlay"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Shield Overlay")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", -16, 0)
    description:SetJustifyH("LEFT")
    description:SetText("Open the floating Shield Overlay menu from the AddOns options panel. Use /shield to open it from chat, or /shield reload to refresh party/group frames.")

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetSize(150, 24)
    openButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    openButton:SetText("Open Shield Menu")
    openButton:SetScript("OnClick", OpenConfigMenu)

    local slashHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slashHint:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", 0, -12)
    slashHint:SetPoint("RIGHT", -16, 0)
    slashHint:SetJustifyH("LEFT")
    slashHint:SetText("Chat shortcut: /shield    Reload shortcut: /shield reload")

    CreatePerformanceControls(panel)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    -- Keep the category's ID so other code (e.g. a future slash command) can
    -- reopen this exact panel via Settings.OpenToCategory(category:GetID()).
    panel.settingsCategory = category
    Settings.RegisterAddOnCategory(category)
end

addon.RegisterInitializer(CreateInterfaceOptionsPanel)
