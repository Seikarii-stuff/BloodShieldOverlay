-- Restores the special-resource side selector without touching the main /shield menu logic.
-- The selector is intentionally instant: it only changes layout, so there is no
-- staged value or Apply button involved.

local addon = _G.BloodShieldOverlay
if not addon then return end

local originalShowConfigMenu = addon.ShowConfigMenu
local selector

local function GetConfig()
    return addon.PlayerBarConfig and addon.PlayerBarConfig.Initialize and addon.PlayerBarConfig.Initialize()
end

local function FindCheckButtonByText(parent, wanted)
    if not parent or not parent.GetChildren then return nil end
    local childCount = select("#", parent:GetChildren())
    for i = 1, childCount do
        local child = select(i, parent:GetChildren())
        if child and child.Text and child.Text.GetText and child.Text:GetText() == wanted then
            return child
        end
    end
    return nil
end

local function GetModeText(mode)
    if mode == "right" then return "Right" end
    if mode == "none" then return "Disabled" end
    return "Left"
end

local function ApplyMode(mode)
    local config = GetConfig()
    if not config then return end
    if mode ~= "left" and mode ~= "right" and mode ~= "none" then
        mode = "left"
    end

    config.resourceDisplay = mode

    if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetResourceDisplay) == "function" then
        addon.PlayerBarAPI.SetResourceDisplay(mode)
    elseif type(addon.UpdateSpecialResourcesLayout) == "function" then
        addon.UpdateSpecialResourcesLayout()
    end
end

local function CreateSelector(frame)
    if selector then return selector end

    selector = CreateFrame("Frame", "BloodShieldOverlayResourceDisplayDropdown", frame, "UIDropDownMenuTemplate")
    selector:SetSize(160, 28)

    local specialCheck = FindCheckButtonByText(frame, "Show special resources")
    if specialCheck then
        selector:SetPoint("TOPLEFT", specialCheck, "BOTTOMLEFT", 210, 4)
    else
        selector:SetPoint("TOPLEFT", frame, "TOPLEFT", 215, -305)
    end

    local label = selector:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", selector, "TOPLEFT", 18, 1)
    label:SetText("Special resources position")

    selector.initialize = function(_, level)
        if level ~= 1 then return end
        local config = GetConfig()
        local current = config and config.resourceDisplay or "left"

        local options = {
            { value = "left", text = "Left" },
            { value = "right", text = "Right" },
            { value = "none", text = "Disabled" },
        }

        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.checked = current == option.value
            info.func = function()
                ApplyMode(option.value)
                UIDropDownMenu_SetText(selector, option.text)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(selector, selector.initialize)
    UIDropDownMenu_SetWidth(selector, 145)

    selector.Refresh = function()
        local config = GetConfig()
        UIDropDownMenu_SetText(selector, GetModeText(config and config.resourceDisplay or "left"))
    end

    selector:Refresh()
    return selector
end

local function HookMenu()
    if type(originalShowConfigMenu) ~= "function" then return end

    addon.ShowConfigMenu = function(...)
        originalShowConfigMenu(...)
        local frame = _G.BloodShieldOverlayConfig
        if frame then
            CreateSelector(frame)
            selector:Refresh()
        end
    end
end

HookMenu()

addon.RegisterInitializer(function()
    if not selector then
        HookMenu()
    end
end)
