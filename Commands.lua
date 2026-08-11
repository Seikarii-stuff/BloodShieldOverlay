-- Public chat command adapter for the standalone player bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

addon.HandleSlashCommand = function(msg)
    local bar = addon.PlayerBarAPI
    if not bar then return end
    msg = msg and msg:lower():gsub("^%s*(.-)%s*$", "%1") or ""
    if msg == "" then
        bar.ShowConfigMenu()
    elseif msg == "reload" then
        if addon.RequestRefresh then
            addon.RequestRefresh()
            print("BloodShieldOverlay: group frames reloaded.")
        else
            print("BloodShieldOverlay: group reload unavailable.")
        end
    else
        print("BloodShieldOverlay commands: /shield to open the menu, /shield reload to refresh group frames.")
    end
end