-- Single group-display state used by BlizzardFrames.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local IsInRaid = IsInRaid
local IsInGroup = IsInGroup

function addon.GetGroupMode()
    if type(addon.IsAlwaysInPartyEnabled) == "function" and addon.IsAlwaysInPartyEnabled() then
        return "party"
    end
    if IsInRaid and IsInRaid() then
        return "raid"
    end
    if IsInGroup and IsInGroup() then
        return "party"
    end
    return "solo"
end
