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
    elseif msg == "raidprof start" then
        if addon.Raid40ProfilerStart then
            addon.Raid40ProfilerStart()
        else
            print("BloodShieldOverlay: raid profiler unavailable.")
        end
    elseif msg == "raidprof stop" then
        if addon.Raid40ProfilerStop then
            addon.Raid40ProfilerStop()
        else
            print("BloodShieldOverlay: raid profiler unavailable.")
        end
    elseif msg == "raidprof reset" then
        if addon.Raid40Profiler then
            addon.Raid40Profiler:Reset()
            print("BloodShieldOverlay: raid40 profiler reset.")
        else
            print("BloodShieldOverlay: raid profiler unavailable.")
        end
    elseif msg == "raidprof report" then
        if addon.Raid40Profiler then
            addon.Raid40Profiler:Report()
        else
            print("BloodShieldOverlay: raid profiler unavailable.")
        end
    elseif msg == "raidprof status" then
        if addon.Raid40Profiler then
            print("BloodShieldOverlay raid40 profiler enabled=" .. tostring(addon.Raid40Profiler:IsEnabled()))
        else
            print("BloodShieldOverlay: raid profiler unavailable.")
        end
    else
        print("BloodShieldOverlay commands: /shield to open the menu, /shield reload to refresh group frames, /shield raidprof start|stop|reset|report|status")
    end
end
