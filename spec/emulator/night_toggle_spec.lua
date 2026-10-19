-- Toggling night mode under a settled day home: through the menu's ToggleNightMode broadcast and, in a second run,
-- through Dispatcher's night_mode action. The night-toggle scenario patch counts the home's paints from the toggle
-- to the next settled signal; the capture taken on that signal is what the panel shows
-- (base/ffi/framebuffer.lua:566-581), so its paper, read in the left margin at mid-height, must be Diner's designed
-- night paper.
describe("toggling night mode under the home", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local compare = require("emulator.compare")
    local Looks = require("looks")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local toggle = root .. "/spec/emulator/scenarios/2-scenario-night-toggle.lua"
    local paper = Looks.get("diner").palettes.night.paper
    -- A flat fill, so close to exact: KOReader's own inversion of the day paper, #f5f1e6, would
    -- read #0a0e19, within compare's default tolerance of #1e1c1a on two channels of three.
    local PAPER_TOLERANCE = 4
    local want = { tonumber(paper:sub(2, 3), 16), tonumber(paper:sub(4, 5), 16), tonumber(paper:sub(6, 7), 16) }

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
            local got = compare.pixel(result.png, 2, math.floor(result.height / 2))
            for c = 1, 3 do
                assert.truthy(math.abs(got[c] - want[c]) <= PAPER_TOLERANCE,
                    string.format("paper %02x%02x%02x, want %s", got[1], got[2], got[3], paper))
            end
        end)
    end
end)
