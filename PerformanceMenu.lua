-- Small performance selector for the non-realtime graphics throttle.
-- Mouse cursor tracking and active proc glow remain realtime and are unaffected.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local function SetRate(config, rate)
    rate = tonumber(rate)
    if rate ~= 30 and rate ~= 60 then return end
    config.graphicsUpdateRate = rate
    if addon.SetGraphicsUpdateRate then addon.SetGraphicsUpdateRate(rate) end
end

local function CreatePerformanceControls()
    local panel = _G.BloodShieldOverlayOptionsPanel
    if not panel or panel.BloodShieldOverlayGraphicsRateControls then return end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -132)
    title:SetText("Graphics update rate")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    description:SetText("Non-realtime addon visuals only. Mouse cursor tracking and proc glow stay realtime.")

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
        SetRate(config, 30)
        Refresh()
    end)
    rate60:SetScript("OnClick", function()
        SetRate(config, 60)
        Refresh()
    end)

    panel.BloodShieldOverlayGraphicsRateControls = true
    panel.BloodShieldOverlayGraphicsRateRefresh = Refresh
    Refresh()
end

addon.RegisterInitializer(CreatePerformanceControls)
