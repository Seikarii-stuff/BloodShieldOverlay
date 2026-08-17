-- Public chat command adapter.
-- Menu ownership lives exclusively in Menu.lua.
local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

addon.HandleSlashCommand = function(msg)
    msg = msg and msg:lower():gsub("^%s*(.-)%s*$", "%1") or ""

    if msg == "" then
        if addon.MenuAPI and addon.MenuAPI.ShowConfigMenu then
            addon.MenuAPI.ShowConfigMenu()
        elseif addon.ShowConfigMenu then
            addon.ShowConfigMenu()
        else
            print("BloodShieldOverlay: configuration panel is not ready yet.")
        end
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
