-- Shared event dispatcher for player absorb updates.

local core = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = core

local listeners = {}
local eventFrame = CreateFrame("Frame")

function core.RegisterPlayerUpdateListener(listener)
    if type(listener) == "function" then
        listeners[#listeners + 1] = listener
    end
end

local function NotifyPlayerUpdate()
    local absorb = UnitGetTotalAbsorbs("player") or 0
    local maxHealth = UnitHealthMax("player") or 0

    for _, listener in ipairs(listeners) do
        listener(absorb, maxHealth)
    end
end

eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
eventFrame:SetScript("OnEvent", function(_, _, unit)
    if unit == "player" then
        NotifyPlayerUpdate()
    end
end)
