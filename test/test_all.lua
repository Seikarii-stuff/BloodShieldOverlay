-- Aggregate functional test runner.
-- Smoke and unit tests are suites; the benchmark remains a separate
-- performance measurement and is intentionally not part of this aggregate.

local commands = {
    { name = "Smoke", command = "lua test/perf/smoke.lua" },
    { name = "Unit", command = "lua test/unit/unit.lua" },
}

local failures = {}
local results = {}

local function run_test(test)
    print(string.format("\n=== %s ===", test.name))
    print(test.command)
    local code = os.execute(test.command)
    local exitCode
    if type(code) == "number" then
        exitCode = code
    elseif code == true then
        exitCode = 0
    else
        exitCode = -1
    end

    local passed = exitCode == 0
    results[#results + 1] = { name = test.name, passed = passed, code = exitCode }
    if not passed then
        failures[#failures + 1] = {
            name = test.name,
            reason = "process exited with code " .. tostring(exitCode) .. "; see the detailed failure/error output above",
        }
    end
    print(string.format("%s: %s (exit code %s)", test.name, passed and "PASS" or "FAIL", tostring(exitCode)))
end

print("BloodShieldOverlay functional test suite")
print("========================================")

for _, test in ipairs(commands) do run_test(test) end

print("\n========================================")
print("Final test summary")
print("========================================")
for _, result in ipairs(results) do
    print(string.format("  %-12s %s", result.name, result.passed and "PASS" or "FAIL"))
end

if #failures == 0 then
    print("\nFailures: 0")
    print("All functional tests passed.")
    print("\ntest_all: PASS")
    os.exit(0)
end

print(string.format("\nFailures: %d", #failures))
for _, failure in ipairs(failures) do
    print(string.format("  [FAIL] %s", failure.name))
    print(string.format("    reason: %s", failure.reason))
end

print("\ntest_all: FAIL")
os.exit(1)
