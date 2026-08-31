-- Aggregate offline test runner.
-- Runs smoke, unit tests, and the synthetic benchmark as separate processes.
-- The child scripts keep their own detailed diagnostics; this runner collects
-- their exit status and prints a final failure summary suitable for CI/logs.

local commands = {
    { name = "Smoke", command = "lua test/perf/smoke.lua" },
    { name = "Unit", command = "lua test/unit/unit.lua" },
    { name = "Benchmark", command = "lua test/benchmark/benchmark.lua 100000" },
}

local failures = {}
local results = {}

local function run_test(test)
    print(string.format("\n=== %s ===", test.name))
    print(test.command)
    local code = os.execute(test.command)

    -- Lua 5.1 commonly returns a numeric status; newer Lua versions may
    -- return (success, reason, code). Normalize both forms without requiring
    -- shell-specific features.
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
            reason = "process exited with code " .. tostring(exitCode),
        }
    end

    print(string.format("%s: %s (exit code %s)", test.name, passed and "PASS" or "FAIL", tostring(exitCode)))
    return passed
end

print("BloodShieldOverlay test suite")
print("=============================")

for _, test in ipairs(commands) do
    run_test(test)
end

print("\n=============================")
print("Final test summary")
print("=============================")

for _, result in ipairs(results) do
    print(string.format("  %-12s %s", result.name, result.passed and "PASS" or "FAIL"))
end

if #failures == 0 then
    print("\nFailures: 0")
    print("All tests passed.")
    os.exit(0)
end

print(string.format("\nFailures: %d", #failures))
for _, failure in ipairs(failures) do
    print(string.format("  [FAIL] %s", failure.name))
    print(string.format("    reason: %s", failure.reason))
end

print("\ntest_all: FAIL")
os.exit(1)
