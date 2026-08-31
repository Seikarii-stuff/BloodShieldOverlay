-- Offline smoke tests for current public entry points and major event paths.
local wow = dofile("test/perf/harness.lua")
local assertions = 0
local passed = 0
local failed = 0
local errors = 0
local currentArea = ""

local function value_text(value)
    if type(value) == "string" then return string.format("%q", value) end
    if value == nil then return "nil" end
    return tostring(value)
end

local function check(condition, message, expected, actual)
    assertions = assertions + 1
    if condition then
        passed = passed + 1
        return true
    end

    failed = failed + 1
    io.write(string.format("[FAIL] %s > %s\n", currentArea, message))
    if expected ~= nil or actual ~= nil then
        io.write(string.format("  expected: %s\n", value_text(expected)))
        io.write(string.format("  actual:   %s\n", value_text(actual)))
    end
    return false
end

local function section(name, fn)
    currentArea = name
    print(string.format("  %-28s RUN", name))
    local beforeFailed, beforeErrors = failed, errors
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
        errors = errors + 1
        failed = failed + 1
        io.write(string.format("[ERROR] %s\n%s\n", name, err))
    end
    if failed == beforeFailed and errors == beforeErrors and ok then
        print(string.format("  %-28s PASS", name))
    else
        print(string.format("  %-28s FAIL", name))
    end
end

wow.load()
dofile("RuntimeGuards.lua")
local addon = BloodShieldOverlay
wow.fire("PLAYER_LOGIN")

print("BloodShieldOverlay smoke tests")
print("------------------------------")

section("Configuration", function()
    local playerBar = _G["BloodShieldOverlayBar"]
    check(playerBar and playerBar:IsShown(), "PlayerBar initialization", true, playerBar and playerBar:IsShown())
    check(playerBar.min == 0 and playerBar.max == 2000 and playerBar.value == 250,
        "standalone absorb bar update")
    check(type(addon.RegisterPlayerUpdateListener) == "function", "player listener API", "function", type(addon.RegisterPlayerUpdateListener))
    check(type(addon.RegisterUnitUpdateListener) == "function", "unit listener API", "function", type(addon.RegisterUnitUpdateListener))
    check(type(addon.RegisterRegenListener) == "function", "regen listener API", "function", type(addon.RegisterRegenListener))
    check(type(addon.RegisterLayoutListener) == "function", "layout listener API", "function", type(addon.RegisterLayoutListener))
    check(type(addon.CreateAbsorbOverlay) == "function", "overlay factory", "function", type(addon.CreateAbsorbOverlay))
    check(type(addon.UpdateAbsorbOverlay) == "function", "overlay updater", "function", type(addon.UpdateAbsorbOverlay))
    check(type(addon.RefreshPartyFrames) == "function", "party refresh API", "function", type(addon.RefreshPartyFrames))
    check(type(addon.RequestRefresh) == "function", "refresh API", "function", type(addon.RequestRefresh))
end)

section("Event bus", function()
    local units, players, regen = 0, 0, 0
    addon.RegisterUnitUpdateListener(function(unit, absorb, maxHealth)
        units = units + 1
        check(absorb >= 0 and maxHealth > 0, "unit payload")
    end)
    addon.RegisterPlayerUpdateListener(function(absorb, maxHealth)
        players = players + 1
        check(absorb == 250 and maxHealth == 1000, "player payload")
    end)
    addon.RegisterRegenListener(function(event)
        regen = regen + 1
        check(event == "PLAYER_REGEN_ENABLED", "regen payload")
    end)

    wow.fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    wow.fire("UNIT_HEALTH", "player")
    wow.fire("UNIT_POWER_FREQUENT", "player")
    wow.tick(0.034)
    check(units == 1 and players == 1, "throttle coalesces player events", "1/1", string.format("%d/%d", units, players))
    wow.fire("PLAYER_REGEN_ENABLED")
    check(regen == 1, "regen dispatcher", 1, regen)
end)

section("PlayerBar", function()
    local healthBar = wow.new_frame("StatusBar", "TestHealthBar")
    local overlay = addon.CreateAbsorbOverlay(healthBar)
    check(overlay.parent == healthBar and overlay.mouseEnabled == false, "overlay setup")
    addon.UpdateAbsorbOverlay(overlay, 42, 100)
    check(overlay.min == 0 and overlay.max == 100 and overlay.value == 42 and overlay.shown, "overlay update")

    local secretAbsorb = { __secret = true }
    addon.UpdateAbsorbOverlay(overlay, secretAbsorb, 100)
    check(overlay.value == secretAbsorb and overlay.lastAbsorb == nil and overlay.lastMaxHealth == nil,
        "secret absorb value is passed through without inspection")
end)

section("Class resources", function()
    check(type(addon.UpdateSpecialResourcesLayout) == "function", "special resource layout API", "function", type(addon.UpdateSpecialResourcesLayout))
    check(type(addon.UpdateSpecialResources) == "function", "special resource update API", "function", type(addon.UpdateSpecialResources))
    check(type(addon.GetSpecialResourceProvider) == "function", "shared resource provider API", "function", type(addon.GetSpecialResourceProvider))
    check(type(addon.SetClassResourceOverlayEnabled) == "function", "group resource toggle API", "function", type(addon.SetClassResourceOverlayEnabled))
    check(type(addon.SetClassResourceOverlayPipSize) == "function", "group pip size API", "function", type(addon.SetClassResourceOverlayPipSize))
    check(type(addon.SetSpecialResourcePipSize) == "function", "special pip size API", "function", type(addon.SetSpecialResourcePipSize))
    check(addon.SetClassResourceOverlayPipSize(16, 8), "valid group pip size")
    check(addon.SetSpecialResourcePipSize(10, 8), "valid special pip size")
    check(not addon.SetClassResourceOverlayPipSize(3, 8), "invalid group pip width rejected")
    check(not addon.SetSpecialResourcePipSize(1, 8), "invalid special pip width rejected")
end)

section("Group/Party", function()
    local partyContainer = wow.new_frame("Frame", "SmokePartyContainer")
    local partyMember = wow.new_frame("Frame", "SmokePartyMember", partyContainer)
    partyMember.displayedUnit = "party1"
    partyMember.healthBar = wow.new_frame("StatusBar", "SmokePartyHealthBar", partyMember)
    PartyFrame = partyContainer
    wow.set_group(true, false)
    wow.reset_get_children_calls()
    addon.RequestRefresh()
    wow.flush_timers()
    check(wow.get_children_calls() >= 1, "container discovery scans expected hierarchy")
end)

section("Target of target", function()
    wow.set_combat(true)
    local enableResult = addon.TargetTargetBarAPI.Enable(true)
    local lockResult = addon.TargetTargetBarAPI.SetLocked(false)
    check(enableResult == false, "Enable defers during combat", false, enableResult)
    check(lockResult == false, "SetLocked defers during combat", false, lockResult)
    wow.set_combat(false)
    wow.fire("PLAYER_REGEN_ENABLED")
    wow.flush_timers()
    check(_G["BloodShieldOverlayTargetTargetBar"] ~= nil, "Enable retries after combat")
    local targetConfig = addon.PlayerBarConfig.Get()
    local targetBar = _G["BloodShieldOverlayTargetTargetBar"]
    check(targetConfig.targetTargetLocked == false and targetBar.movable == true,
        "SetLocked retries after combat")
end)

section("Combat Lockdown", function()
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
    check(classOverlay.parent ~= groupPowerBar, "protected frame is not mutated during combat")
    wow.set_combat(false)
    wow.fire("PLAYER_REGEN_ENABLED")
    wow.flush_timers()
    check(classOverlay.parent == groupPowerBar, "deferred reparenting retries after combat")
end)

section("Menu", function()
    check(type(SlashCmdList.BLOODSHIELDOVERLAY) == "function", "slash command", "function", type(SlashCmdList.BLOODSHIELDOVERLAY))
    SlashCmdList.BLOODSHIELDOVERLAY("")
    SlashCmdList.BLOODSHIELDOVERLAY("reload")
    wow.flush_timers()
    check(type(BloodShieldOverlayProfiles) == "table", "profile store")
    check(_G["BloodShieldOverlayConfig"] and _G["BloodShieldOverlayConfig"].widthEdit, "configuration menu")

    local configMenu = _G["BloodShieldOverlayConfig"]
    check(configMenu.healthCheck:GetChecked() == true, "show health default")
    check(configMenu.specialResCheck:GetChecked() == true, "special resources default")
    check(configMenu.classOverlayCheck:GetChecked() == true, "group overlay default")
    check(_G["BloodShieldOverlayResourceDisplayDropdown"] ~= nil, "resource display dropdown")
    check(configMenu.unlockButton and configMenu.unlockButton:GetText() == "Unlock bars", "unlock button label")
    local unlockButton = configMenu.unlockButton
    unlockButton:GetScript("OnClick")(unlockButton)
    check(_G["BloodShieldOverlayBar"].movable == true and _G["BloodShieldOverlayBar"].mouseEnabled == true, "unlock handler")
end)

section("Frame discovery", function()
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
    check(#area.HealthBar.children >= 1, "player frame health bar receives absorb overlay")
end)

section("Legacy Mouse removal regression", function()
    local legacyApis = {
        "SetMouseResourceOverlayEnabled",
        "UpdateMouseResourceOverlay",
        "RefreshMouseCooldowns",
        "GetMouseCooldownOptions",
    }
    local found = {}
    for _, name in ipairs(legacyApis) do
        if addon[name] ~= nil then found[#found + 1] = name end
    end
    local config = addon.PlayerBarConfig.Get()
    for key in pairs(config) do
        local lower = string.lower(tostring(key))
        if lower:match("^showmouse") or lower:match("^mousecooldown")
            or lower:match("^mouseresourcearc") or lower == "mouse_cooldowns" then
            found[#found + 1] = tostring(key)
        end
    end
    if _G.MOUSE_COOLDOWNS ~= nil then found[#found + 1] = "MOUSE_COOLDOWNS" end
    check(#found == 0, "legacy Mouse APIs/configuration remain", "none", table.concat(found, ", "))
end)

print(string.format("\nAssertions: %d\nPassed:     %d\nFailed:     %d\nErrors:     %d", assertions, passed, failed, errors))
if failed == 0 and errors == 0 then
    print("\nsmoke: PASS")
    os.exit(0)
end
print("\nsmoke: FAIL")
os.exit(1)
