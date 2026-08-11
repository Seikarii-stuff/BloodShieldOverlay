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
local playerBar = _G["BloodShieldOverlayBar"]
check(playerBar and playerBar:IsShown(), "PlayerBar.lua did not initialize the standalone bar")
check(playerBar.min == 0 and playerBar.max == 2000 and playerBar.value == 250, "standalone absorb bar was not updated")
check(type(addon.RegisterPlayerUpdateListener) == "function", "player listener API missing")
check(type(addon.RegisterUnitUpdateListener) == "function", "unit listener API missing")
check(type(addon.RegisterRegenListener) == "function", "regen listener API missing")
check(type(addon.CreateAbsorbOverlay) == "function", "overlay factory missing")
check(type(addon.UpdateAbsorbOverlay) == "function", "overlay updater missing")
check(type(addon.RefreshPartyFrames) == "function", "party refresh API missing")
check(type(addon.RequestRefresh) == "function", "refresh API missing")
check(type(addon.UpdateSpecialResourcesLayout) == "function", "special resource layout API missing")
check(type(addon.UpdateSpecialResources) == "function", "special resource update API missing")
check(type(addon.GetSpecialResourceProvider) == "function", "shared resource provider API missing")
check(type(addon.SetClassResourceOverlayEnabled) == "function", "group resource toggle API missing")
check(type(addon.SetClassResourceOverlayPipSize) == "function", "group pip size API missing")
check(addon.SetClassResourceOverlayPipSize(16, 8), "valid group pip size was rejected")
check(not addon.SetClassResourceOverlayPipSize(3, 8), "invalid group pip width was accepted")

local healthBar = wow.new_frame("StatusBar", "TestHealthBar")
local overlay = addon.CreateAbsorbOverlay(healthBar)
check(overlay.parent == healthBar and overlay.mouseEnabled == false, "overlay setup failed")
addon.UpdateAbsorbOverlay(overlay, 42, 100)
check(overlay.min == 0 and overlay.max == 100 and overlay.value == 42 and overlay.shown, "overlay update failed")

-- Retail regression: UnitGetTotalAbsorbs can be a secret number. The addon
-- must pass it through to StatusBar without comparing or retaining it.
local secretAbsorb = { __secret = true }
addon.UpdateAbsorbOverlay(overlay, secretAbsorb, 100)
check(overlay.value == secretAbsorb and overlay.lastAbsorb == nil and overlay.lastMaxHealth == nil,
    "secret absorb value was inspected or retained")

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
wow.fire("UNIT_POWER_FREQUENT", "player")
wow.tick(0.033)
check(units == 1 and players == 1, "throttle did not coalesce player events")
wow.fire("PLAYER_REGEN_ENABLED")
check(regen == 1, "regen dispatcher failed")

check(type(SlashCmdList.BLOODSHIELDOVERLAY) == "function", "slash command missing")
SlashCmdList.BLOODSHIELDOVERLAY("")
SlashCmdList.BLOODSHIELDOVERLAY("reload")
SlashCmdList.BLOODSHIELDOVERLAY("unknown")
wow.flush_timers()
check(type(BloodShieldOverlayProfiles) == "table", "profile store was not created")
check(_G["BloodShieldOverlayConfig"] and _G["BloodShieldOverlayConfig"].widthEdit, "configuration menu was not created")

local configMenu = _G["BloodShieldOverlayConfig"]
local bar = _G["BloodShieldOverlayBar"]
check(bar and bar.resourceBar == nil, "bar should not expose implementation details")
check(bar and bar:GetScript("OnDragStart") == nil, "locked bar still has a drag handler")
check(configMenu.healthCheck:GetChecked() == true, "show health bar should be enabled by default")
check(configMenu.specialResCheck:GetChecked() == true, "special resources should be enabled by default")
check(configMenu.classOverlayCheck:GetChecked() == true, "group resource overlay should be enabled by default")
check(configMenu.applyButton.point == "LEFT" and configMenu.applyButton.relative == configMenu.capEdit,
    "apply button should be beside the size and cap fields")

configMenu.specialResCheck:SetChecked(false)
configMenu.specialResCheck:GetScript("OnClick")(configMenu.specialResCheck)
check(configMenu.specialResCheck:GetChecked() == false, "special resource toggle failed")
configMenu.specialResCheck:SetChecked(true)
configMenu.specialResCheck:GetScript("OnClick")(configMenu.specialResCheck)
check(configMenu.specialResCheck:GetChecked() == true, "special resource re-enable failed")
configMenu.classOverlayCheck:SetChecked(false)
configMenu.classOverlayCheck:GetScript("OnClick")(configMenu.classOverlayCheck)
check(configMenu.classOverlayCheck:GetChecked() == false, "group resource overlay toggle failed")
configMenu.classOverlayCheck:SetChecked(true)
configMenu.classOverlayCheck:GetScript("OnClick")(configMenu.classOverlayCheck)

local originalWidth, originalHeight = bar.width, bar.height
configMenu.capEdit:SetText("300")
configMenu.applyButton:GetScript("OnClick")(configMenu.applyButton)
check(bar.max == 3000, "changing only Max % did not update the shield bar")
check(bar.width == originalWidth and bar.height == originalHeight,
    "changing only Max % unexpectedly changed bar dimensions")

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
check(wow.get_children_calls() >= 2, "container discovery did not scan the expected hierarchy")
wow.set_combat(true)
addon.RequestRefresh()
wow.set_combat(false)
wow.fire("PLAYER_REGEN_ENABLED")
wow.flush_timers()

-- Regression test: group-frame discovery must not reparent the overlay during combat.
local groupContainer = wow.new_frame("Frame", "CombatGroupContainer")
local groupMember = wow.new_frame("Frame", "CombatGroupMember", groupContainer)
groupMember.displayedUnit = "player"
local groupPowerBar = wow.new_frame("StatusBar", "CombatGroupPowerBar", groupMember)
PartyFrame = groupContainer
addon.SetClassResourceOverlayEnabled(true)
wow.set_combat(true)
wow.fire("GROUP_ROSTER_UPDATE")
wow.flush_timers()
local classOverlay = _G["BSO_ClassResourceOverlay"]
check(classOverlay.parent ~= groupPowerBar, "group overlay mutated a protected frame during combat")
wow.set_combat(false)
wow.fire("PLAYER_REGEN_ENABLED")
wow.flush_timers()
check(classOverlay.parent == groupPowerBar, "deferred group overlay discovery did not retry after combat")

-- Regression test: a raid layout may emit GROUP_ROSTER_UPDATE before its
-- child frames exist; the bounded retry must attach once the bar is created.
PartyFrame = nil
wow.fire("GROUP_ROSTER_UPDATE")
wow.flush_timers()
local delayedContainer = wow.new_frame("Frame", "DelayedRaidContainer")
local delayedMember = wow.new_frame("Frame", "DelayedRaidMember", delayedContainer)
delayedMember.displayedUnit = "player"
local delayedPowerBar = wow.new_frame("StatusBar", "DelayedRaidPowerBar", delayedMember)
PartyFrame = delayedContainer
wow.flush_timers()
check(classOverlay.parent == delayedPowerBar, "raid layout retry did not attach the late-created resource bar")

print(string.format("smoke: PASS (%d assertions)", passed))
