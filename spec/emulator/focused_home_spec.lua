-- Focused mode on the home, on the emulator, with focused.on at its default: a tap at the home's top centre opens
-- the quick-settings sheet over it, and a tap on an empty spot leaves the home shown and on top. The home fixture
-- patch makes the populated home; the focused-home scenario patch runs one step per capture
-- (spec/emulator/scenarios/2-scenario-focused-home.lua). The look is passed empty so a KOPANDA_HOME_LOOK in the
-- caller's environment cannot leak in.
describe("focused mode on the home on the emulator", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-focused-home.lua"

    local function capture(step, shot_screen)
        return driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            patches = { fixture, scenario },
            shot_screen = shot_screen,
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "populated",
                KOPANDA_HOME_LOOK = "",
                KOPANDA_FOCUSED_STEP = step,
            },
        }
    end

    it("opens the quick-settings sheet over the home on a tap at the top centre", function()
        local sidecar = capture("top", "sheet").sidecar
        assert.is_nil(sidecar.error, sidecar.error)
        assert.equals("sheet", sidecar.screen)
        assert.equals("quick_settings", sidecar.name)
    end)

    it("leaves the home shown and on top after a tap on an empty spot", function()
        local sidecar = capture("empty", "scenario").sidecar
        assert.is_nil(sidecar.error, sidecar.error)
        assert.equals("scenario", sidecar.screen)
        assert.is_true(sidecar.home_shown)
        assert.is_true(sidecar.home_on_top)
    end)
end)
