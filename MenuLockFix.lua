-- Keep the temporary bar-edit state out of the persisted menu state.
-- The edit button is only a session control: bars are always locked again
-- when the configuration window closes, and the button returns to its
-- default "Unlock bars" label the next time the menu opens.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local function ResetBarEditState(frame)
    if addon.PlayerBarAPI and type(addon.PlayerBarAPI.SetLocked) == "function" then
        addon.PlayerBarAPI.SetLocked(true)
    end
    if addon.TargetTargetBarAPI and type(addon.TargetTargetBarAPI.SetLocked) == "function" then
        addon.TargetTargetBarAPI.SetLocked(true)
    end

    if frame and frame.unlockButton then
        frame.unlockButton:SetText("Unlock bars")
    end
end

local function InstallMenuLockFix()
    local frame = _G.BloodShieldOverlayConfig
    if not frame or not frame.unlockButton then
        return false
    end
    if frame.MinimizerBarLockFixInstalled then
        return true
    end

    frame.MinimizerBarLockFixInstalled = true

    frame.unlockButton:SetText("Unlock bars")
    frame.unlockButton:HookScript("OnClick", function(self)
        local locked = addon.PlayerBarAPI
            and type(addon.PlayerBarAPI.IsLocked) == "function"
            and addon.PlayerBarAPI.IsLocked()

        -- The original click handler has already toggled the bars when this
        -- hook runs, so derive the visible label from the resulting state.
        if locked == false then
            self:SetText("Lock bars")
        else
            self:SetText("Unlock bars")
        end
    end)

    frame:HookScript("OnHide", function(self)
        ResetBarEditState(self)
    end)

    frame:HookScript("OnShow", function(self)
        -- Never reopen the editor in its previous unlocked state.
        ResetBarEditState(self)
    end)

    return true
end

-- Menu.lua creates the configuration frame lazily, so keep a tiny one-shot
-- poll until the frame exists. Once installed, the ticker is cancelled.
local hookFrame = CreateFrame("Frame")
local ticker
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function()
    if InstallMenuLockFix() then return end

    if not ticker then
        ticker = C_Timer.NewTicker(0.1, function(t)
            if InstallMenuLockFix() then
                t:Cancel()
                ticker = nil
            end
        end)
    end
end)
