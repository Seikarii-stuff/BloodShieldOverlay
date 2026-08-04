local addonName = "AlwaysInParty"
local frame

local function Trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function TryShowPartyFrame()
    if PartyFrame then
        PartyFrame:Show()
        if PartyFrame.Update then
            PartyFrame:Update()
        end
    end

    if CompactPartyFrame then
        CompactPartyFrame:Show()
        if _G.CompactPartyFrame_Update then
            _G.CompactPartyFrame_Update()
        end
    end

    if _G.PartyMemberFrame1 then
        _G.PartyMemberFrame1:Show()
        _G.PartyMemberFrame1.unit = "player"
        if _G.PartyMemberFrame_Update then
            _G.PartyMemberFrame_Update(_G.PartyMemberFrame1, "player")
        end
    end

    if _G.CompactPartyFrameMemberFrame1 then
        _G.CompactPartyFrameMemberFrame1:Show()
        if _G.CompactPartyFrameMemberFrame1.SetUnit then
            _G.CompactPartyFrameMemberFrame1:SetUnit("player")
        end
    end
end

local function HandleSlashCommand(msg)
    local command = Trim(msg or ""):lower()

    if command == "hide" then
        if PartyFrame then
            PartyFrame:Hide()
        end
        if CompactPartyFrame then
            CompactPartyFrame:Hide()
        end
        print("|cff00ff00AlwaysInParty|r: marcos de party ocultados.")
    elseif command == "show" then
        TryShowPartyFrame()
        print("|cff00ff00AlwaysInParty|r: intentando mostrar los marcos nativos de Blizzard.")
    elseif command == "reset" then
        TryShowPartyFrame()
        print("|cff00ff00AlwaysInParty|r: marcos de party reiniciados.")
    else
        print("|cff00ff00AlwaysInParty|r: /aip show | hide | reset")
    end
end

local function OnEvent(_, event, loadedName)
    if event ~= "ADDON_LOADED" or loadedName ~= addonName then
        return
    end

    frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PARTY_INVITE_REQUEST")
    frame:RegisterEvent("PARTY_LEADER_CHANGED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(self, eventName)
        if eventName == "PLAYER_ENTERING_WORLD" or eventName == "GROUP_ROSTER_UPDATE" or eventName == "PARTY_INVITE_REQUEST" or eventName == "PARTY_LEADER_CHANGED" or eventName == "PLAYER_REGEN_ENABLED" or eventName == "PLAYER_REGEN_DISABLED" then
            C_Timer.After(0.2, TryShowPartyFrame)
        end
    end)

    TryShowPartyFrame()
    print("|cff00ff00AlwaysInParty|r: addon cargado. Si Blizzard no muestra el party frame en modo solo, es porque el juego no lo permite sin un grupo real.")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnEvent)

SLASH_ALWAYSINPARTY1 = "/alwaysinparty"
SLASH_ALWAYSINPARTY2 = "/aip"
SlashCmdList["ALWAYSINPARTY"] = HandleSlashCommand
