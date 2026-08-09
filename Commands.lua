-- Public chat command adapter for the standalone player bar.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

addon.HandleSlashCommand = function(msg)
    local bar = addon.PlayerBarAPI
    if not bar then return end
    msg = msg and msg:lower():gsub("^%s*(.-)%s*$", "%1") or ""
    if msg == "" then
        bar.ShowConfigMenu()
    elseif msg == "lock" then
        bar.SetLocked(true)
        print("BloodShieldOverlay locked.")
    elseif msg == "unlock" or msg == "move" then
        bar.SetLocked(false)
        print("BloodShieldOverlay is unlocked. Drag to move, then type /shield lock.")
    elseif msg == "hide" then
        bar.SetHidden(true)
        print("BloodShieldOverlay external bar hidden.")
    elseif msg == "show" then
        bar.SetHidden(false)
        print("BloodShieldOverlay external bar shown.")
    elseif msg == "reset" then
        bar.Reset()
        print("BloodShieldOverlay settings reset to defaults.")
    elseif msg == "party" then
        if addon.RequestRefresh then
            addon.RequestRefresh()
            print("BloodShieldOverlay: party frames refreshed.")
        else
            print("BloodShieldOverlay: party refresh unavailable.")
        end
    elseif bar.IsLocked() then
        print("BloodShieldOverlay is locked. Use /shield unlock to move it.")
    else
        print("BloodShieldOverlay is unlocked. Drag to move it, then use /shield lock.")
    end
end