-- The home goldens (C9): each look on each profile with a known weather cache and reading
-- history, and each look on the Colorsoft with neither, all at 2026-10-13 08:42 in Chicago.
-- The home fixture patch freezes the clock and writes the scenario before any plugin runs.
-- Diner scenarios store no look, so they show the schema's default; the look is always passed
-- (empty for Diner) so a KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("the home goldens", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"

    local scenarios = {
        { name = "home-diner", fixture = "populated", profile = "colorsoft" },
        { name = "home-diner", fixture = "populated", profile = "paperwhite" },
        { name = "home-editorial", look = "editorial", fixture = "populated", profile = "colorsoft" },
        { name = "home-editorial", look = "editorial", fixture = "populated", profile = "paperwhite" },
        { name = "home-empty-diner", fixture = "empty", profile = "colorsoft" },
        { name = "home-empty-editorial", look = "editorial", fixture = "empty", profile = "colorsoft" },
    }

    for _, scenario in ipairs(scenarios) do
        it("match a fresh capture of " .. scenario.name .. " on " .. scenario.profile, function()
            local result = driver.capture{
                profile = scenario.profile,
                plugin_dir = plugin,
                patches = { fixture },
                env = {
                    TZ = "America/Chicago",
                    KOPANDA_HOME_FIXTURE = scenario.fixture,
                    KOPANDA_HOME_LOOK = scenario.look or "",
                },
            }
            assert.equals("home", result.sidecar.screen)
            local checked = golden.assert_golden(scenario.name, scenario.profile, result)
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_true(checked.ok)
            end
        end)
    end
end)
