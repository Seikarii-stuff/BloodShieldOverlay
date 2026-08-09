-- Offline smoke tests for every public entry point and major event path.
local wow = dofile("test/perf/harness.lua")
local passed = 0
local function check(condition, message)
    assert(condition, message)
    passed = passed + 1
end

wow.load()
local addon = BloodShieldOverlay
wow.fire("PLAYER_LOGIN")
check(type(addon.RegisterPlayerUpdateListener) == "function", "player listener API missing")
check(type(addon.RegisterUnitUpdateListener) == "function", "unit listener API missing")
check(type(addon.RegisterRegenListener) == "function", "regen listener API missing")
check(type(addon.CreateAbsorbOverlay) == "function", "overlay factory missing")
check(type(addon.UpdateAbsorbOverlay) == "function", "overlay updater missing")
check(type(addon.RefreshPartyFrames) == "function", "party refresh API missing")
check(type(addon.RequestRefresh) == "function", "refresh API missing")

local healthBar = wow.new_frame("StatusBar", "TestHealthBar")
local overlay = addon.CreateAbsorbOverlay(healthBar)
check(overlay.parent == healthBar and overlay.mouseEnabled == false, "overlay setup failed")
addon.UpdateAbsorbOverlay(overlay, 42, 100)
check(overlay.min == 0 and overlay.max == 100 and overlay.value == 42 and overlay.shown, "overlay update failed")

local units, players, regen = 0, 0, 0
addon.RegisterUnitUpdateListener(function(unit, absorb, maxHealth)
    units = units + 1
    check(absorb >= 0 and maxHealth > 0, "invalid unit payload")
end)
addon.RegisterPlayerUpdateListener(function(absorb, maxHealth)
    players = players + 1
    check(absorb == 250 and maxHealth == 1000, "invalid player payload")
end)
addon.RegisterRegenListener(function(event) regen = regen + 1; check(event == "PLAYER_REGEN_ENABLED", "invalid regen event") end)

wow.fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
wow.fire("UNIT_HEALTH", "player")
wow.tick(0.033)
check(units == 1 and players == 1, "throttle did not coalesce player events")
wow.fire("PLAYER_REGEN_ENABLED")
check(regen == 1, "regen dispatcher failed")

check(type(SlashCmdList.BLOODSHIELDOVERLAY) == "function", "slash command missing")
SlashCmdList.BLOODSHIELDOVERLAY("unlock")
SlashCmdList.BLOODSHIELDOVERLAY("lock")
SlashCmdList.BLOODSHIELDOVERLAY("hide")
SlashCmdList.BLOODSHIELDOVERLAY("show")
SlashCmdList.BLOODSHIELDOVERLAY("reset")
SlashCmdList.BLOODSHIELDOVERLAY("party")
SlashCmdList.BLOODSHIELDOVERLAY("")
wow.flush_timers()
check(type(BloodShieldOverlayProfiles) == "table", "profile store was not created")
check(_G["BloodShieldOverlayConfig"] and _G["BloodShieldOverlayConfig"].widthEdit, "configuration menu was not created")

local configMenu = _G["BloodShieldOverlayConfig"]
local bar = _G["BloodShieldOverlayBar"]
check(bar and bar.resourceBar == nil, "bar should not expose implementation details")
check(bar and bar:GetScript("OnDragStart") == nil, "locked bar still has a drag handler")

-- Regression test for the historical unlock-button crash: Button:Text is not
-- a WoW API; CreateConfigMenu must complete and its handler must be callable.
local unlockButton
for _, frame in ipairs(wow.frames()) do
    if frame.parent == configMenu and frame.text == "Unlock" then
        unlockButton = frame
        break
    end
end
check(unlockButton and unlockButton:GetScript("OnClick"), "unlock button was not created")
unlockButton:GetScript("OnClick")(unlockButton)
check(bar.movable == true and bar.mouseEnabled == true, "unlock handler failed")

configMenu.healthCheck:SetChecked(true)
configMenu.healthCheck:GetScript("OnClick")(configMenu.healthCheck)
check(configMenu.healthCheck:GetChecked() == true, "health toggle failed")
configMenu.resButton:GetScript("OnClick")(configMenu.resButton)
check(configMenu.resButton.text == "Right", "resource layout toggle failed")
configMenu.resButton:GetScript("OnClick")(configMenu.resButton)
check(configMenu.resButton.text == "None", "resource layout second toggle failed")

-- Exercise player-frame discovery and combat-deferred refresh paths.
local content = wow.new_frame("Frame", "PlayerFrameContent")
local main = wow.new_frame("Frame", "PlayerFrameContentMain", content)
local area = wow.new_frame("Frame", "HealthBarArea", main)
area.HealthBar = wow.new_frame("StatusBar", "PlayerHealthBar", area)
PlayerFrame = { PlayerFrameContent = content }
content.PlayerFrameContentMain = main
main.HealthBarArea = area
wow.set_group(false, false)
addon.RequestRefresh()
wow.flush_timers()
local partyContainer = wow.new_frame("Frame", "SmokePartyContainer")
local partyMember = wow.new_frame("Frame", "SmokePartyMember", partyContainer)
partyMember.displayedUnit = "party1"
partyMember.healthBar = wow.new_frame("StatusBar", "SmokePartyHealthBar", partyMember)
PartyFrame = partyContainer
wow.set_group(true, false)
wow.reset_get_children_calls()
addon.RequestRefresh()
wow.flush_timers()
check(wow.get_children_calls() == 2, "container discovery called GetChildren more than once per level")
wow.set_combat(true)
addon.RequestRefresh()
wow.set_combat(false)
wow.fire("PLAYER_REGEN_ENABLED")
wow.flush_timers()

print(string.format("smoke: PASS (%d assertions)", passed))
