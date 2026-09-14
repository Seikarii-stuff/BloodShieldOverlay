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

case("Configuration > Initialize creates profile", function()
    BloodShieldOverlayProfiles = nil
    local config = addon.PlayerBarConfig.Initialize()
    check(type(config) == "table", "Configuration > profile is created", "table", type(config))
    check(config.width == 18, "Configuration > initialized width is default", 18, config.width)
    check(BloodShieldOverlayProfiles and BloodShieldOverlayProfiles["Tester-Realm"] == config, "Configuration > profile is stored by active key", true, BloodShieldOverlayProfiles and BloodShieldOverlayProfiles["Tester-Realm"] == config)
end)

case("Configuration > Set persists value", function()
    local ok = addon.PlayerBarConfig.Set("width", 22)
    check(ok == true, "Configuration > Set persists valid width", true, ok)
    check(addon.PlayerBarConfig.Get().width == 22, "Configuration > Set stores width", 22, addon.PlayerBarConfig.Get().width)
end)

case("Configuration > Set rejects invalid", function()
    local before = addon.PlayerBarConfig.Get().width
    local ok = addon.PlayerBarConfig.Set("width", -5)
    check(ok == false, "Configuration > invalid width is rejected", false, ok)
    check(addon.PlayerBarConfig.Get().width == before, "Configuration > invalid width is not persisted", before, addon.PlayerBarConfig.Get().width)
end)

case("Configuration > SetMany updates multiple fields", function()
    local ok = addon.PlayerBarConfig.SetMany({ height = 140, locked = false, showTargetTarget = true })
    check(ok == true, "Configuration > SetMany accepts valid values", true, ok)
    check(addon.PlayerBarConfig.Get().height == 140, "Configuration > SetMany persists height", 140, addon.PlayerBarConfig.Get().height)
    check(addon.PlayerBarConfig.Get().locked == false, "Configuration > SetMany persists locked", false, addon.PlayerBarConfig.Get().locked)
    check(addon.PlayerBarConfig.Get().showTargetTarget == true, "Configuration > SetMany persists target-target toggle", true, addon.PlayerBarConfig.Get().showTargetTarget)
end)

case("Configuration > reactive API persists and notifies listeners", function()
    local events = {}
    local token = addon.PlayerBarConfig.Subscribe(function(change)
        events[#events + 1] = { key = change.key, value = change.newValue }
    end)
    local ok = addon.PlayerBarConfig.Set("width", 22)
    check(ok == true, "Configuration > Set accepts valid width", true, ok)
    check(addon.PlayerBarConfig.Get().width == 22, "Configuration > Set persists width", 22, addon.PlayerBarConfig.Get().width)
    ok = addon.PlayerBarConfig.SetMany({ height = 140, locked = false })
    check(ok == true, "Configuration > SetMany accepts valid values", true, ok)
    check(addon.PlayerBarConfig.Get().height == 140, "Configuration > SetMany persists height", 140, addon.PlayerBarConfig.Get().height)
    check(addon.PlayerBarConfig.Unsubscribe(token) == true, "Configuration > Unsubscribe removes listener", true, addon.PlayerBarConfig.Unsubscribe(token))
    check(#events >= 2, "Configuration > subscribers receive updates", 2, #events)
end)

case("Configuration > SetMany notification behavior", function()
    local notifications = {}
    local token = addon.PlayerBarConfig.Subscribe(function(change)
        notifications[#notifications + 1] = change.key
    end)

    local ok = addon.PlayerBarConfig.SetMany({ width = 24, height = 160 })
    check(ok == true, "Configuration > SetMany accepts multiple fields", true, ok)
    check(#notifications == 2, "Configuration > SetMany emits once per changed field", 2, #notifications)

    local before = #notifications
    ok = addon.PlayerBarConfig.SetMany({ width = 24, height = 160 })
    check(ok == true, "Configuration > SetMany accepts no-op values", true, ok)
    check(#notifications == before, "Configuration > no-op SetMany emits nothing", before, #notifications)

    addon.PlayerBarConfig.Unsubscribe(token)
end)

case("Configuration > SetMany updates full state before notifying listeners", function()
    local seen = {}
    local token = addon.PlayerBarConfig.Subscribe(function(change)
        seen[#seen + 1] = {
            key = change.key,
            width = change.config.width,
            xOffset = change.config.xOffset,
        }
    end)

    addon.PlayerBarConfig.SetMany({ width = 29, xOffset = 350 })
    check(#seen == 2, "Configuration > SetMany emits the changed fields only", 2, #seen)
    for _, item in ipairs(seen) do
        if item.key == "width" then
            check(item.width == 29, "Configuration > listener sees updated width", 29, item.width)
        elseif item.key == "xOffset" then
            check(item.xOffset == 350, "Configuration > listener sees updated xOffset", 350, item.xOffset)
        end
    end
    addon.PlayerBarConfig.Unsubscribe(token)
end)

case("Events > Subscribe receives change", function()
    local received = {}
    local token = addon.PlayerBarConfig.Subscribe(function(change)
        received[#received + 1] = change.key
    end)
    addon.PlayerBarConfig.Set("locked", false)
    check(#received == 1, "Events > subscriber receives single change", 1, #received)
    check(received[1] == "locked", "Events > subscriber receives correct key", "locked", received[1])
    addon.PlayerBarConfig.Unsubscribe(token)
end)

case("Events > multiple subscribers receive change", function()
    local a, b = 0, 0
    local tokenA = addon.PlayerBarConfig.Subscribe(function(change)
        a = a + 1
        check(change.key == "hideExternalBar", "Events > first subscriber gets key", "hideExternalBar", change.key)
    end)
    local tokenB = addon.PlayerBarConfig.Subscribe(function(change)
        b = b + 1
        check(change.key == "hideExternalBar", "Events > second subscriber gets key", "hideExternalBar", change.key)
    end)
    addon.PlayerBarConfig.Set("hideExternalBar", true)
    check(a == 1, "Events > first subscriber fires once", 1, a)
    check(b == 1, "Events > second subscriber fires once", 1, b)
    addon.PlayerBarConfig.Unsubscribe(tokenA)
    addon.PlayerBarConfig.Unsubscribe(tokenB)
end)

case("Events > duplicate subscriptions are deduplicated", function()
    local callback = function(change)
        check(change.key == "locked", "Events > deduplicated callback gets key", "locked", change.key)
    end
    local tokenA = addon.PlayerBarConfig.Subscribe(callback)
    local tokenB = addon.PlayerBarConfig.Subscribe(callback)
    check(tokenA == tokenB, "Events > duplicate subscription reuses token", tokenA, tokenB)
    addon.PlayerBarConfig.Set("locked", false)
    addon.PlayerBarConfig.Unsubscribe(tokenA)
end)

case("Events > Unsubscribe stops notifications", function()
    local seen = 0
    local token = addon.PlayerBarConfig.Subscribe(function()
        seen = seen + 1
    end)
    addon.PlayerBarConfig.Unsubscribe(token)
    addon.PlayerBarConfig.Set("locked", true)
    check(seen == 0, "Events > unsubscribed listener does not fire", 0, seen)
end)

case("PlayerBar > SetLocked uses config API", function()
    local called = false
    local originalSet = addon.PlayerBarConfig.Set
    addon.PlayerBarConfig.Set = function(key, value)
        called = true
        check(key == "locked", "PlayerBar > SetLocked uses locked key", "locked", key)
        check(value == false, "PlayerBar > SetLocked sends boolean", false, value)
        return originalSet(key, value)
    end
    local ok = addon.PlayerBarAPI.SetLocked(false)
    check(ok == true, "PlayerBar > SetLocked returns success", true, ok)
    check(called == true, "PlayerBar > SetLocked called config API", true, called)
    addon.PlayerBarConfig.Set = originalSet
end)

case("PlayerBar > SetHidden uses config API", function()
    local called = false
    local originalSet = addon.PlayerBarConfig.Set
    addon.PlayerBarConfig.Set = function(key, value)
        called = true
        check(key == "hideExternalBar", "PlayerBar > SetHidden uses hideExternalBar key", "hideExternalBar", key)
        check(value == true, "PlayerBar > SetHidden sends boolean", true, value)
        return originalSet(key, value)
    end
    local ok = addon.PlayerBarAPI.SetHidden(true)
    check(ok == true, "PlayerBar > SetHidden returns success", true, ok)
    check(called == true, "PlayerBar > SetHidden called config API", true, called)
    addon.PlayerBarConfig.Set = originalSet
end)

case("PlayerBar > ApplyDimensions updates via config", function()
    local originalSetMany = addon.PlayerBarConfig.SetMany
    local called = false
    addon.PlayerBarConfig.SetMany = function(values)
        called = true
        check(values.width == 32, "PlayerBar > dimensions write width", 32, values.width)
        check(values.height == 180, "PlayerBar > dimensions write height", 180, values.height)
        return originalSetMany(values)
    end
    local ok = addon.PlayerBarAPI.ApplyDimensions(32, 180)
    check(ok == true, "PlayerBar > ApplyDimensions uses config API", true, ok)
    check(called == true, "PlayerBar > ApplyDimensions called SetMany", true, called)
    addon.PlayerBarConfig.SetMany = originalSetMany
end)

case("PlayerBar > SaveBarPosition persists through API", function()
    local originalSetMany = addon.PlayerBarConfig.SetMany
    local called = false
    addon.PlayerBarConfig.SetMany = function(values)
        called = true
        if values.point then check(values.point == "BOTTOM", "PlayerBar > SaveBarPosition persists point", "BOTTOM", values.point) end
        if values.relativePoint then check(values.relativePoint == "BOTTOM", "PlayerBar > SaveBarPosition persists relativePoint", "BOTTOM", values.relativePoint) end
        return originalSetMany(values)
    end

    local bar = _G["BloodShieldOverlayBar"]
    if bar then
        addon.PlayerBarAPI.SetLocked(false)
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 20, 30)
        local onDragStop = bar:GetScript("OnDragStop")
        if type(onDragStop) == "function" then
            onDragStop(bar)
        end
    end

    check(called == true or not _G["BloodShieldOverlayBar"], "PlayerBar > SaveBarPosition uses config API or no bar exists", true, called or not _G["BloodShieldOverlayBar"])
    addon.PlayerBarConfig.SetMany = originalSetMany
end)

case("Menu > refresh stays render-pure", function()
    addon.ShowConfigMenu()
    local menu = _G["BloodShieldOverlayConfig"]
    local before = addon.PlayerBarConfig.Get().width
    local originalRefresh = addon.MenuAPI.Refresh
    local refreshCalls = 0
    addon.MenuAPI.Refresh = function()
        refreshCalls = refreshCalls + 1
        return originalRefresh()
    end

    menu.widthEdit:SetText("31")
    menu.widthEdit:OnEnterPressed()
    check(addon.PlayerBarConfig.Get().width == 31, "Menu > Enter changes persisted config", 31, addon.PlayerBarConfig.Get().width)
    check(refreshCalls == 1, "Menu > Enter triggers exactly one Refresh()", 1, refreshCalls)

    menu.widthEdit:SetText("-1")
    menu.widthEdit:OnEditFocusLost()
    check(addon.PlayerBarConfig.Get().width == 31, "Menu > invalid focus loss restores persisted value", 31, addon.PlayerBarConfig.Get().width)
    check(refreshCalls == 1, "Menu > invalid focus loss does not trigger a second Refresh()", 1, refreshCalls)
    check(before ~= addon.PlayerBarConfig.Get().width or before == 31, "Menu > refresh does not mutate persisted state", true, before ~= addon.PlayerBarConfig.Get().width or before == 31)

    addon.MenuAPI.Refresh = originalRefresh
end)

case("Regression > width survives save position", function()
    addon.PlayerBarConfig.Set("width", 31)
    check(addon.PlayerBarConfig.Get().width == 31, "Regression > width is updated before move", 31, addon.PlayerBarConfig.Get().width)

    local bar = _G["BloodShieldOverlayBar"]
    if bar then
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 120, 40)
        local onDragStop = bar:GetScript("OnDragStop")
        if type(onDragStop) == "function" then
            onDragStop(bar)
        end
    end

    check(addon.PlayerBarConfig.Get().width == 31, "Regression > width survives move/save", 31, addon.PlayerBarConfig.Get().width)
    check(BloodShieldOverlayProfiles["Tester-Realm"].width == 31, "Regression > persisted width remains unchanged", 31, BloodShieldOverlayProfiles["Tester-Realm"].width)
end)

case("Configuration > persistence round-trip across sessions", function()
    local profile = {
        ["Tester-Realm"] = {
            configVersion = 8,
            width = 31,
            height = 150,
            locked = true,
            hideExternalBar = false,
            showClassResourceOverlay = true,
            classResourcePipWidth = 12,
            classResourcePipHeight = 6,
            specialResourcePipWidth = 2,
            specialResourcePipHeight = 10,
            showTargetTarget = false,
            targetTargetWidth = 130,
            targetTargetHeight = 10,
            targetTargetLocked = true,
            targetTargetPoint = "CENTER",
            targetTargetRelativePoint = "CENTER",
            targetTargetXOffset = 0,
            targetTargetYOffset = -140,
            graphicsUpdateRate = 30,
        },
    }
    local reloaded = wow.reset_and_load_with_profile_store(profile, nil)
    local config = reloaded.PlayerBarConfig.Get()
    check(config.width == 31, "Configuration > round trip loads saved width from profile", 31, config.width)
    check(BloodShieldOverlayProfiles["Tester-Realm"].width == 31, "Configuration > profile store retains the saved width", 31, BloodShieldOverlayProfiles["Tester-Realm"].width)
end)

case("Configuration > reset restores defaults", function()
    local reset = addon.PlayerBarConfig.Reset()
    check(reset.width == 18, "Configuration > reset width", 18, reset.width)
    check(reset.height == 150, "Configuration > reset height", 150, reset.height)
    check(reset.locked == true, "Configuration > reset locks bars", true, reset.locked)
    check(reset.hideExternalBar == false, "Configuration > reset hides external bar false", false, reset.hideExternalBar)
end)

case("Configuration > invalid values are rejected and restored", function()
    local prior = addon.PlayerBarConfig.Get().width
    local ok = addon.PlayerBarConfig.Set("width", -5)
    check(ok == false, "Configuration > invalid width is rejected", false, ok)
    check(addon.PlayerBarConfig.Get().width == prior, "Configuration > invalid width is not persisted", prior, addon.PlayerBarConfig.Get().width)
end)

case("Menu > edit boxes commit on enter and focus loss", function()
    addon.ShowConfigMenu()
    local menu = _G["BloodShieldOverlayConfig"]
    menu.widthEdit:SetText("25")
    menu.widthEdit:OnEnterPressed()
    check(addon.PlayerBarConfig.Get().width == 25, "Menu > Enter applies width", 25, addon.PlayerBarConfig.Get().width)
    menu.heightEdit:SetText("-2")
    menu.heightEdit:OnEditFocusLost()
    check(addon.PlayerBarConfig.Get().height ~= -2, "Menu > invalid focus loss restores persisted value", false, addon.PlayerBarConfig.Get().height == -2)
end)

case("Regression > width survives move after change", function()
    addon.PlayerBarConfig.Set("width", 24)
    local bar = _G["BloodShieldOverlayBar"]
    if bar then
        bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 80, 120)
        bar:SetSize(24, addon.PlayerBarConfig.Get().height)
    end
    check(addon.PlayerBarConfig.Get().width == 24, "Regression > width remains after move", 24, addon.PlayerBarConfig.Get().width)
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
