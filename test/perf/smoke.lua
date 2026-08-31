-- Offline smoke tests for current public entry points and major event paths.
local wow = dofile("test/perf/harness.lua")
local passed = 0
local function check(condition, message)
    assert(condition, message)
    passed = passed + 1
end

wow.load()
dofile("RuntimeGuards.lua")
local addon = BloodShieldOverlay
wow.fire("PLAYER_LOGIN")

local playerBar = _G["BloodShieldOverlayBar"]
check(playerBar and playerBar:IsShown(), "PlayerBar.lua did not initialize the standalone bar")
check(playerBar.min == 0 and playerBar.max == 2000 and playerBar.value == 250, "standalone absorb bar was not updated")
check(type(addon.RegisterPlayerUpdateListener) == "function", "player listener API missing")
check(type(addon.RegisterUnitUpdateListener) == "function", "unit listener API missing")
check(type(addon.RegisterRegenListener) == "function", "regen listener API missing")
check(type(addon.RegisterLayoutListener) == "function", "layout listener API missing")
check(type(addon.CreateAbsorbOverlay) == "function", "overlay factory missing")
check(type(addon.UpdateAbsorbOverlay) == "function", "overlay updater missing")
check(type(addon.RefreshPartyFrames) == "function", "party refresh API missing")
check(type(addon.RequestRefresh) == "function", "refresh API missing")
check(type(addon.UpdateSpecialResourcesLayout) == "function", "special resource layout API missing")
check(type(addon.UpdateSpecialResources) == "function", "special resource update API missing")
check(type(addon.GetSpecialResourceProvider) == "function", "shared resource provider API missing")
check(type(addon.SetClassResourceOverlayEnabled) == "function", "group resource toggle API missing")
check(type(addon.SetClassResourceOverlayPipSize) == "function", "group pip size API missing")
check(type(addon.SetSpecialResourcePipSize) == "function", "special resource pip API missing")
check(addon.SetClassResourceOverlayPipSize(16, 8), "valid group pip size was rejected")
check(addon.SetSpecialResourcePipSize(10, 8), "valid special resource pip size was rejected")
check(not addon.SetClassResourceOverlayPipSize(3, 8), "invalid group pip width was accepted")
check(not addon.SetSpecialResourcePipSize(1, 8), "invalid special pip width was accepted")

local healthBar = wow.new_frame("StatusBar", "TestHealthBar")
local overlay = addon.CreateAbsorbOverlay(healthBar)
check(overlay.parent == healthBar and overlay.mouseEnabled == false, "overlay setup failed")
addon.UpdateAbsorbOverlay(overlay, 42, 100)
check(overlay.min == 0 and overlay.max == 100 and overlay.value == 42 and overlay.shown, "overlay update failed")

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
addon.RegisterRegenListener(function(event)
    regen = regen + 1
    check(event == "PLAYER_REGEN_ENABLED", "invalid regen event")
end)

wow.fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
wow.fire("UNIT_HEALTH", "player")
wow.fire("UNIT_POWER_FREQUENT", "player")
wow.tick(0.034)
check(units == 1 and players == 1, "throttle did not coalesce player events")
wow.fire("PLAYER_REGEN_ENABLED")
check(regen == 1, "regen dispatcher failed")

check(type(SlashCmdList.BLOODSHIELDOVERLAY) == "function", "slash command missing")
SlashCmdList.BLOODSHIELDOVERLAY("")
SlashCmdList.BLOODSHIELDOVERLAY("reload")
wow.flush_timers()
check(type(BloodShieldOverlayProfiles) == "table", "profile store was not created")
check(_G["BloodShieldOverlayConfig"] and _G["BloodShieldOverlayConfig"].widthEdit, "configuration menu was not created")

local configMenu = _G["BloodShieldOverlayConfig"]
check(configMenu.healthCheck:GetChecked() == true, "show health bar should be enabled by default")
check(configMenu.specialResCheck:GetChecked() == true, "special resources should be enabled by default")
check(configMenu.classOverlayCheck:GetChecked() == true, "group resource overlay should be enabled by default")
check(_G["BloodShieldOverlayResourceDisplayDropdown"] ~= nil, "resource display dropdown was not created")
check(configMenu.unlockButton and configMenu.unlockButton:GetText() == "Unlock bars", "unlock button text does not match current UI")

local unlockButton = configMenu.unlockButton
unlockButton:GetScript("OnClick")(unlockButton)
check(playerBar.movable == true and playerBar.mouseEnabled == true, "unlock handler failed")

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
check(wow.get_children_calls() >= 1, "container discovery did not scan the expected hierarchy")

-- Target-of-target secure operations requested in combat must be retried after regen.
wow.set_combat(true)
check(addon.TargetTargetBarAPI.Enable(true) == false, "TargetTarget Enable should defer during combat")
check(addon.TargetTargetBarAPI.ApplySize(160, 12) == false, "TargetTarget ApplySize should defer during combat")
wow.set_combat(false)
wow.fire("PLAYER_REGEN_ENABLED")
wow.flush_timers()
check(_G["BloodShieldOverlayTargetTargetBar"] ~= nil, "TargetTarget Enable did not retry after combat")
local targetConfig = addon.PlayerBarConfig.Initialize()
check(targetConfig.targetTargetWidth == 160 and targetConfig.targetTargetHeight == 12,
    "TargetTarget ApplySize did not retry after combat")

-- Class resource discovery must also defer protected reparenting during combat.
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

print(string.format("smoke: PASS (%d assertions)", passed))
