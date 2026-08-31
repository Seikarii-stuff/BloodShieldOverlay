-- Deterministic offline unit tests. Every case gets a fresh mock state and
-- freshly loaded addon so listeners, frames, timers and configuration cannot leak.
local wow = dofile("test/perf/harness.lua")
local passed, failed, errors, assertions = 0, 0, 0, 0
local addon

local function value_text(value)
    if type(value) == "string" then return string.format("%q", value) end
    if value == nil then return "nil" end
    return tostring(value)
end

local function check(condition, message, expected, actual)
    assertions = assertions + 1
    if condition then passed = passed + 1 return true end
    failed = failed + 1
    io.write(string.format("[FAIL] %s\n", message))
    if expected ~= nil or actual ~= nil then
        io.write(string.format("  expected: %s\n", value_text(expected)))
        io.write(string.format("  actual:   %s\n", value_text(actual)))
    end
    return false
end

local function case(name, fn)
    print(string.format("  %-52s RUN", name))
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
        print(string.format("  %-52s PASS", name))
    else
        print(string.format("  %-52s FAIL", name))
    end
end

print("BloodShieldOverlay unit tests")
print("------------------------------")

case("Configuration > defaults", function()
    local config = addon.PlayerBarConfig.Initialize()
    check(config.width == 18, "Configuration > default width", 18, config.width)
    check(config.height == 150, "Configuration > default height", 150, config.height)
    check(config.showHealth == true, "Configuration > default showHealth", true, config.showHealth)
    check(config.graphicsUpdateRate == 30, "Configuration > default graphicsUpdateRate", 30, config.graphicsUpdateRate)
    check(config.resourceDisplay == "left", "Configuration > default resourceDisplay", "left", config.resourceDisplay)
end)

case("Configuration > validation and cleanup", function()
    local key = "Tester-Realm"
    BloodShieldOverlayProfiles = {
        [key] = {
            configVersion = 1,
            width = -10,
            height = "bad",
            classResourcePipWidth = 100,
            specialResourcePipWidth = 1,
            resourceDisplay = "invalid",
            graphicsUpdateRate = 120,
            unexpectedLegacyField = true,
        },
    }
    BloodShieldOverlayDB = nil
    local config = addon.PlayerBarConfig.Initialize()
    check(config.width == 18, "Configuration > invalid width is repaired", 18, config.width)
    check(config.height == 150, "Configuration > invalid height is repaired", 150, config.height)
    check(config.classResourcePipWidth == 12, "Configuration > invalid class pip width is repaired", 12, config.classResourcePipWidth)
    check(config.specialResourcePipWidth == 2, "Configuration > invalid special pip width is repaired", 2, config.specialResourcePipWidth)
    check(config.resourceDisplay == "left", "Configuration > invalid resource display is repaired", "left", config.resourceDisplay)
    check(config.graphicsUpdateRate == 30, "Configuration > invalid update rate is repaired", 30, config.graphicsUpdateRate)
    check(config.unexpectedLegacyField == nil, "Configuration > stale fields are removed", nil, config.unexpectedLegacyField)
    check(BloodShieldOverlayProfiles[key] == config, "Configuration > repaired profile is persisted")
end)

case("Configuration > legacy migration", function()
    BloodShieldOverlayProfiles = nil
    BloodShieldOverlayDB = { width = 22, height = 140, showHealth = true }
    local migrated = addon.PlayerBarConfig.Initialize()
    check(migrated.width == 22, "Configuration > legacy width is preserved", 22, migrated.width)
    check(migrated.height == 140, "Configuration > legacy height is preserved", 140, migrated.height)
    check(migrated.showHealth == true, "Configuration > legacy showHealth is preserved", true, migrated.showHealth)
    check(BloodShieldOverlayDB == nil, "Configuration > legacy DB is removed after migration", nil, BloodShieldOverlayDB)
    check(type(BloodShieldOverlayProfiles["Tester-Realm"]) == "table", "Configuration > migrated profile is created")
end)

case("Configuration > legacy migration repairs invalid values", function()
    BloodShieldOverlayProfiles = nil
    BloodShieldOverlayDB = {
        width = -5,
        height = "bad",
        classResourcePipWidth = 100,
        specialResourcePipWidth = 1,
        resourceDisplay = "invalid",
        graphicsUpdateRate = 120,
    }
    local migrated = addon.PlayerBarConfig.Initialize()
    check(migrated.width == 18, "Configuration > invalid legacy width is repaired", 18, migrated.width)
    check(migrated.height == 150, "Configuration > invalid legacy height is repaired", 150, migrated.height)
    check(migrated.classResourcePipWidth == 12, "Configuration > invalid legacy class pip is repaired", 12, migrated.classResourcePipWidth)
    check(migrated.specialResourcePipWidth == 2, "Configuration > invalid legacy special pip is repaired", 2, migrated.specialResourcePipWidth)
    check(migrated.resourceDisplay == "left", "Configuration > invalid legacy display is repaired", "left", migrated.resourceDisplay)
    check(migrated.graphicsUpdateRate == 30, "Configuration > invalid legacy update rate is repaired", 30, migrated.graphicsUpdateRate)
    check(BloodShieldOverlayDB == nil, "Configuration > invalid legacy DB is removed", nil, BloodShieldOverlayDB)
end)

case("Configuration > reset", function()
    addon.PlayerBarConfig.Initialize()
    local reset = addon.PlayerBarConfig.Reset()
    check(reset.width == 18, "Configuration > reset width", 18, reset.width)
    check(reset.height == 150, "Configuration > reset height", 150, reset.height)
    check(reset.showTargetTarget == false, "Configuration > reset disables target-target", false, reset.showTargetTarget)
    check(addon.PlayerBarConfig.Get() == reset, "Configuration > reset updates active config")
end)

case("EventBus > registration and dispatch", function()
    local unitCallsA, unitCallsB, playerCalls = 0, 0, 0
    addon.RegisterUnitUpdateListener(function(unit, absorb, maxHealth)
        unitCallsA = unitCallsA + 1
        check(unit == "player", "EventBus > listener A receives player unit", "player", unit)
        check(absorb == 250 and maxHealth == 1000, "EventBus > listener A receives current values")
    end)
    addon.RegisterUnitUpdateListener(function(unit)
        unitCallsB = unitCallsB + 1
        check(unit == "player", "EventBus > listener B receives player unit", "player", unit)
    end)
    addon.RegisterPlayerUpdateListener(function(absorb, maxHealth)
        playerCalls = playerCalls + 1
        check(absorb == 250 and maxHealth == 1000, "EventBus > player listener receives current values")
    end)
    wow.fire("UNIT_HEALTH", "player")
    wow.tick(0.034)
    check(unitCallsA == 1 and unitCallsB == 1, "EventBus > multiple listeners dispatch exactly once")
    check(playerCalls == 1, "EventBus > player listener dispatches exactly once", 1, playerCalls)
    wow.fire("UNIT_HEALTH", "unsupported-unit")
    wow.tick(0.034)
    check(unitCallsA == 1 and unitCallsB == 1, "EventBus > irrelevant units are ignored")
end)

case("Frame Discovery > unit and compact-frame lookup", function()
    local displayed = wow.new_frame("Frame", "DiscoveryDisplayed")
    displayed.displayedUnit = "party1"
    check(addon.GetUnit(displayed) == "party1", "Frame Discovery > displayedUnit is preferred", "party1", addon.GetUnit(displayed))
    local attribute = wow.new_frame("Frame", "DiscoveryAttribute")
    attribute:SetAttribute("unit", "raid2")
    check(addon.GetUnit(attribute) == "raid2", "Frame Discovery > unit attribute is discovered", "raid2", addon.GetUnit(attribute))
    local status = wow.new_frame("StatusBar", "DiscoveryStatus")
    check(addon.IsStatusBar(status) == true, "Frame Discovery > status bars are recognized", true, addon.IsStatusBar(status))
    check(addon.IsStatusBar(displayed) == false, "Frame Discovery > generic frames are rejected", false, addon.IsStatusBar(displayed))
    local forbidden = wow.new_frame("StatusBar", "DiscoveryForbidden")
    forbidden.IsForbidden = function() return true end
    check(addon.IsStatusBar(forbidden) == false, "Frame Discovery > forbidden frames are rejected", false, addon.IsStatusBar(forbidden))
    local member = wow.new_frame("Frame", "CompactPartyFrameMemberFrame1")
    _G["CompactPartyFrameMemberFrame1"] = member
    member.displayedUnit = "party1"
    local seen = 0
    wow.set_group(true, false, 1)
    addon.ForEachCompactFrame(function(frame) if frame == member then seen = seen + 1 end end)
    check(seen == 1, "Frame Discovery > party member is discovered once", 1, seen)
    wow.set_group(false, false, 0)
    local outsideGroup = 0
    addon.ForEachCompactFrame(function() outsideGroup = outsideGroup + 1 end)
    check(outsideGroup == 0, "Frame Discovery > no group produces no compact frames", 0, outsideGroup)
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
    local sizeResult = addon.TargetTargetBarAPI.ApplySize(160, 12)
    check(sizeResult == true, "TargetTarget > resize applies out of combat", true, sizeResult)
    check(targetBar.width == 160 and targetBar.height == 12, "TargetTarget > resized dimensions persist")
end)

case("Mouse overlay removal > legacy regression", function()
    local legacyApis = { "SetMouseResourceOverlayEnabled", "UpdateMouseResourceOverlay", "RefreshMouseCooldowns", "GetMouseCooldownOptions" }
    local missingApis = {}
    for _, name in ipairs(legacyApis) do if addon[name] ~= nil then missingApis[#missingApis + 1] = name end end
    check(#missingApis == 0, "legacy Mouse overlay removal > APIs are absent", "none", table.concat(missingApis, ", "))

    local function legacy_config_keys(config)
        local found = {}
        for key in pairs(config) do
            local lower = string.lower(tostring(key))
            if lower:match("^showmouse") or lower:match("^mousecooldown") or lower:match("^mouseresourcearc") or lower == "mouse_cooldowns" then
                found[#found + 1] = tostring(key)
            end
        end
        return found
    end
    local activeLegacy = legacy_config_keys(addon.PlayerBarConfig.Get())
    local defaultLegacy = legacy_config_keys(addon.PlayerBarConfig.GetDefaults())
    check(#activeLegacy == 0, "legacy Mouse overlay removal > active config is clean", "none", table.concat(activeLegacy, ", "))
    check(#defaultLegacy == 0, "legacy Mouse overlay removal > defaults are clean", "none", table.concat(defaultLegacy, ", "))
    check(_G.MOUSE_COOLDOWNS == nil, "legacy Mouse overlay removal > global spell catalog is absent", nil, _G.MOUSE_COOLDOWNS)
end)

print(string.format("\nAssertions: %d\nPassed:     %d\nFailed:     %d\nErrors:     %d", assertions, passed, failed, errors))
if failed == 0 and errors == 0 then print("\nunit: PASS") os.exit(0) end
print("\nunit: FAIL")
os.exit(1)
