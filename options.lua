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

local function CreateInterfaceOptionsPanel()
    if type(InterfaceOptions_AddCategory) ~= "function" then
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

    InterfaceOptions_AddCategory(panel)
end

addon.RegisterInitializer(CreateInterfaceOptionsPanel)
