-- Toggling night mode under a settled day home (C8): through the menu's ToggleNightMode
-- broadcast and, in a second run, through Dispatcher's night_mode action. The night-toggle
-- scenario patch counts the home's paints from the toggle to the next settled signal; the
-- capture taken on that signal is what the panel shows, and must be the Diner night golden.
-- The golden is checked with update off, so this spec never writes it.
describe("toggling night mode under the home", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local toggle = root .. "/spec/emulator/scenarios/2-scenario-night-toggle.lua"

    for _, route in ipairs{ "menu", "dispatcher" } do
        it("repaints the home once into the night palette, through the " .. route, function()
            local result = driver.capture{
                profile = "colorsoft",
                plugin_dir = plugin,
                patches = { fixture, toggle },
                shot_screen = "scenario",
                env = {
                    TZ = "America/Chicago",
                    KOPANDA_HOME_FIXTURE = "populated",
                    KOPANDA_HOME_LOOK = "",
                    KOPANDA_NIGHT_ROUTE = route,
                },
            }
            local s = result.sidecar
            assert.is_nil(s.error)
            assert.equals("scenario", s.screen)
            assert.is_true(s.night_mode)
            print(string.format("night toggle %s: home_paints=%s", route, tostring(s.home_paints)))
            assert.equals(1, s.home_paints)
            assert.is_true(golden.check("home-night-diner", "colorsoft", result, { update = false }).ok)
        end)
    end
end)
