-- The screens' paint budget (device-menus C12): edit layout with row 2 selected, and launcher
-- management over a launcher with a Tools folder, each opened over the populated home in Diner on
-- the Colorsoft, at 2026-10-13 08:42 in Chicago. The home fixture patch freezes the clock and
-- writes the scenario; the screens patch opens the screen KOPANDA_SCREEN names once the home
-- settles; the capture is taken on the screen's own settled signal. The look is passed empty so a
-- KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("the device-menu screens", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local paint_budget = require("emulator.paint_budget")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-screens.lua"

    local scenarios = {
        { screen = "layout", shot_screen = "edit_layout" },
        { screen = "launcher", shot_screen = "launcher" },
    }

    local function read(path)
        local f = assert(io.open(path, "r"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function count(text, needle)
        local n = 0
        for _ in text:gmatch(needle:gsub("%p", "%%%0")) do
            n = n + 1
        end
        return n
    end

    for _, scenario_opts in ipairs(scenarios) do
        it("open " .. scenario_opts.shot_screen .. " over the home on colorsoft, within the paint budget", function()
            local result = driver.capture{
                profile = "colorsoft",
                plugin_dir = plugin,
                patches = { fixture, scenario },
                shot_screen = scenario_opts.shot_screen,
                env = {
                    TZ = "America/Chicago",
                    KOPANDA_HOME_FIXTURE = "populated",
                    KOPANDA_HOME_LOOK = "",
                    KOPANDA_SCREEN = scenario_opts.screen,
                },
            }
            local sidecar = result.sidecar
            assert.is_nil(sidecar.error, sidecar.error)
            assert.equals(scenario_opts.shot_screen, sidecar.screen)
            paint_budget.check(scenario_opts.shot_screen .. " paint on colorsoft", sidecar)
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
        end)
    end
end)
