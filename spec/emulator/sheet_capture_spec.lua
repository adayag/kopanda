-- The sheet's paint budget: the book sheet and the home sheet a hold opens over the populated home, in Diner on the
-- Colorsoft, at 2026-10-13 08:42 in Chicago. The home fixture patch freezes the clock and writes the scenario; the
-- sheet-hold patch holds the featured slot or the side margin once the home settles; the capture is taken on the
-- sheet's own settled signal. The look is passed empty so a KOPANDA_HOME_LOOK in the caller's environment cannot leak
-- in.
describe("the sheets a hold opens over the home", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local paint_budget = require("emulator.paint_budget")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-sheet-hold.lua"

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

    for _, hold in ipairs({ "book", "home" }) do
        it("open the " .. hold .. " sheet on colorsoft, within the paint budget", function()
            local result = driver.capture{
                profile = "colorsoft",
                plugin_dir = plugin,
                patches = { fixture, scenario },
                shot_screen = "sheet",
                env = {
                    TZ = "America/Chicago",
                    KOPANDA_HOME_FIXTURE = "populated",
                    KOPANDA_HOME_LOOK = "",
                    KOPANDA_SHEET_HOLD = hold,
                },
            }
            local sidecar = result.sidecar
            assert.is_nil(sidecar.error, sidecar.error)
            assert.equals("sheet", sidecar.screen)
            assert.equals(hold, sidecar.name)
            paint_budget.check("sheet-" .. hold .. " paint on colorsoft", sidecar)
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
        end)
    end
end)
