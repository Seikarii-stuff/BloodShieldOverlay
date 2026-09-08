-- Deterministic offline unit tests for configuration schema and public player-bar API.
local wow = dofile("test/perf/harness.lua")
local passed, failed, errors, assertions = 0, 0, 0, 0
local addon

local function check(condition, message, expected, actual)
    assertions = assertions + 1
    if condition then passed = passed + 1 return true end
    failed = failed + 1
    io.write(string.format("[FAIL] %s\n", message))
    if expected ~= nil or actual ~= nil then
        io.write(string.format("  expected: %s\n  actual:   %s\n", tostring(expected), tostring(actual)))
    end
    return false
end

local function case(name, fn)
    print(string.format("  %-58s RUN", name))
    local beforeFailed, beforeErrors = failed, errors
    local ok, err = xpcall(function()
        addon = wow.reset_and_load()
        fn()
    end, debug.traceback)
    if not ok then
        errors = errors + 1
        failed = failed + 1
        io.write(string.format("[ERROR] %s\n%s\n", name, err))
    end
    if ok and failed == beforeFailed and errors == beforeErrors then
        print(string.format("  %-58s PASS", name))
    else
        print(string.format("  %-58s FAIL", name))
    end
end

print("BloodShieldOverlay unit tests")
print("------------------------------")

case("Configuration > current schema", function()
    local config = addon.PlayerBarConfig.Initialize()
    check(config.configVersion == 8, "Configuration > schema version", 8, config.configVersion)
    check(config.width == 18, "Configuration > default width", 18, config.width)
    check(config.height == 150, "Configuration > default height", 150, config.height)
    check(config.graphicsUpdateRate == 30, "Configuration > default graphicsUpdateRate", 30, config.graphicsUpdateRate)

    local defaults = addon.PlayerBarConfig.GetDefaults()
    local removed = { "capMultiplier", "showHealth", "showSpecialResources", "resourceDisplay" }
    for _, key in ipairs(removed) do
        check(defaults[key] == nil, "Configuration > removed default " .. key, nil, defaults[key])
        check(config[key] == nil, "Configuration > removed active field " .. key, nil, config[key])
    end
end)

case("Configuration > migration strips removed and unknown fields", function()
    local key = "Tester-Realm"
    BloodShieldOverlayProfiles = {
        [key] = {
            configVersion = 7,
            width = 22,
            height = 140,
            capMultiplier = 1.5,
            showHealth = false,
            showSpecialResources = false,
            resourceDisplay = "right",
            classResourcePipWidth = 20,
            unexpectedLegacyField = true,
        },
    }
    BloodShieldOverlayDB = nil

    local config = addon.PlayerBarConfig.Initialize()
    check(config.width == 22, "Configuration > valid width is preserved", 22, config.width)
    check(config.height == 140, "Configuration > valid height is preserved", 140, config.height)
    check(config.classResourcePipWidth == 20, "Configuration > valid pip width is preserved", 20, config.classResourcePipWidth)
    check(config.configVersion == 8, "Configuration > migration updates schema version", 8, config.configVersion)
    check(config.capMultiplier == nil, "Configuration > old capMultiplier is discarded")
    check(config.showHealth == nil, "Configuration > old showHealth is discarded")
    check(config.showSpecialResources == nil, "Configuration > old showSpecialResources is discarded")
    check(config.resourceDisplay == nil, "Configuration > old resourceDisplay is discarded")
    check(config.unexpectedLegacyField == nil, "Configuration > unknown fields are discarded")
    check(BloodShieldOverlayProfiles[key] == config, "Configuration > cleaned profile is persisted")
end)

case("Configuration > legacy SavedVariable migration", function()
    BloodShieldOverlayProfiles = nil
    BloodShieldOverlayDB = {
        width = 22,
        height = 140,
        capMultiplier = 1.8,
        showHealth = false,
        showSpecialResources = false,
        resourceDisplay = "right",
    }
    local migrated = addon.PlayerBarConfig.Initialize()
    check(migrated.width == 22, "Configuration > legacy width is preserved", 22, migrated.width)
    check(migrated.height == 140, "Configuration > legacy height is preserved", 140, migrated.height)
    check(migrated.capMultiplier == nil, "Configuration > legacy capMultiplier is discarded")
    check(migrated.showHealth == nil, "Configuration > legacy showHealth is discarded")
    check(migrated.showSpecialResources == nil, "Configuration > legacy showSpecialResources is discarded")
    check(migrated.resourceDisplay == nil, "Configuration > legacy resourceDisplay is discarded")
    check(BloodShieldOverlayDB == nil, "Configuration > legacy DB is removed after migration")
end)

case("Configuration > invalid values are repaired", function()
    local key = "Tester-Realm"
    BloodShieldOverlayProfiles = {
        [key] = {
            configVersion = 1,
            width = -10,
            height = "bad",
            classResourcePipWidth = 100,
            specialResourcePipWidth = 1,
            graphicsUpdateRate = 120,
        },
    }
    BloodShieldOverlayDB = nil
    local config = addon.PlayerBarConfig.Initialize()
    check(config.width == 18, "Configuration > invalid width is repaired", 18, config.width)
    check(config.height == 150, "Configuration > invalid height is repaired", 150, config.height)
    check(config.classResourcePipWidth == 12, "Configuration > invalid class pip width is repaired", 12, config.classResourcePipWidth)
    check(config.specialResourcePipWidth == 2, "Configuration > invalid special pip width is repaired", 2, config.specialResourcePipWidth)
    check(config.graphicsUpdateRate == 30, "Configuration > invalid update rate is repaired", 30, config.graphicsUpdateRate)
end)

case("Configuration > reset uses only schema defaults", function()
    addon.PlayerBarConfig.Initialize()
    local reset = addon.PlayerBarConfig.Reset()
    check(reset.width == 18, "Configuration > reset width", 18, reset.width)
    check(reset.height == 150, "Configuration > reset height", 150, reset.height)
    check(reset.showTargetTarget == false, "Configuration > reset disables target-target", false, reset.showTargetTarget)
    check(reset.showHealth == nil, "Configuration > reset does not recreate showHealth")
    check(reset.resourceDisplay == nil, "Configuration > reset does not recreate resourceDisplay")
    check(addon.PlayerBarConfig.Get() == reset, "Configuration > reset updates active config")
end)

case("PlayerBar > fixed behavior has no config dependency", function()
    local config = addon.PlayerBarConfig.Get()
    check(config.capMultiplier == nil, "PlayerBar > cap is not persisted")
    check(config.showHealth == nil, "PlayerBar > health visibility is not persisted")
    check(config.showSpecialResources == nil, "PlayerBar > special-resource visibility is not persisted")
    check(config.resourceDisplay == nil, "PlayerBar > resource position is not persisted")

    check(addon.PlayerBarAPI.SetHealthShown == nil, "PlayerBar > obsolete health API is absent")
    check(addon.PlayerBarAPI.SetSpecialResourcesShown == nil, "PlayerBar > obsolete special-resource API is absent")
    check(addon.PlayerBarAPI.SetResourceDisplay == nil, "PlayerBar > obsolete resource-display API is absent")

    local bar = _G["BloodShieldOverlayBar"]
    check(bar and bar.max == 1000, "PlayerBar > shield cap is fixed at 100%", 1000, bar and bar.max)
end)

case("Menu > removed options are absent", function()
    addon.ShowConfigMenu()
    local menu = _G["BloodShieldOverlayConfig"]
    check(menu.healthCheck == nil, "Menu > show health checkbox is removed")
    check(menu.specialResCheck == nil, "Menu > special resources checkbox is removed")
    check(menu.resourceDisplaySelector == nil, "Menu > resource display selector is removed")
    check(type(menu.widthEdit) == "table", "Menu > width input remains")
    check(type(menu.heightEdit) == "table", "Menu > height input remains")
end)

case("EventBus > registration and dispatch", function()
    local unitCalls, playerCalls = 0, 0
    addon.RegisterUnitUpdateListener(function(unit, absorb, maxHealth)
        unitCalls = unitCalls + 1
        check(unit == "player", "EventBus > unit listener receives player")
        check(absorb == 250 and maxHealth == 1000, "EventBus > unit payload is current")
    end)
    addon.RegisterPlayerUpdateListener(function(absorb, maxHealth)
        playerCalls = playerCalls + 1
        check(absorb == 250 and maxHealth == 1000, "EventBus > player payload is current")
    end)
    wow.fire("UNIT_HEALTH", "player")
    wow.tick(0.034)
    check(unitCalls == 1, "EventBus > unit listener dispatches once", 1, unitCalls)
    check(playerCalls == 1, "EventBus > player listener dispatches once", 1, playerCalls)
end)

case("TargetTarget > combat deferral", function()
    wow.set_combat(true)
    local enableResult = addon.TargetTargetBarAPI.Enable(true)
    local lockResult = addon.TargetTargetBarAPI.SetLocked(false)
    check(enableResult == false, "TargetTarget > enable is deferred during combat", false, enableResult)
    check(lockResult == false, "TargetTarget > lock change is deferred during combat", false, lockResult)
    wow.set_combat(false)
    wow.fire("PLAYER_REGEN_ENABLED")
    wow.flush_timers()
    local targetBar = _G["BloodShieldOverlayTargetTargetBar"]
    check(targetBar ~= nil, "TargetTarget > enable retries after combat")
    check(targetBar and targetBar.movable == true, "TargetTarget > deferred lock change retries after combat")
end)

case("Mouse overlay removal > legacy regression", function()
    local legacyApis = { "SetMouseResourceOverlayEnabled", "UpdateMouseResourceOverlay", "RefreshMouseCooldowns", "GetMouseCooldownOptions" }
    local missingApis = {}
    for _, name in ipairs(legacyApis) do if addon[name] ~= nil then missingApis[#missingApis + 1] = name end end
    check(#missingApis == 0, "legacy Mouse overlay removal > APIs are absent", "none", table.concat(missingApis, ", "))
    check(_G.MOUSE_COOLDOWNS == nil, "legacy Mouse overlay removal > global spell catalog is absent")
end)

print(string.format("\nAssertions: %d\nPassed:     %d\nFailed:     %d\nErrors:     %d", assertions, passed, failed, errors))
if failed == 0 and errors == 0 then print("\nunit: PASS") os.exit(0) end
print("\nunit: FAIL")
os.exit(1)
