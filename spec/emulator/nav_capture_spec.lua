-- The file browser's paint budget (nav-bar C11): KOReader's file browser on the populated
-- fixture's library with the nav bar in its band and Library active, in Diner on the Colorsoft,
-- at 2026-10-13 08:42 in Chicago. The home fixture patch freezes the clock and writes the
-- scenario; the file-browser scenario closes the home once it settles, leaving the file browser on
-- top; the capture is taken on the file browser's own settled signal. The look is passed empty so
-- a KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("the file browser under the nav bar", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local paint_budget = require("emulator.paint_budget")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-file-browser.lua"

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

    it("settles on colorsoft once the home closes, within the paint budget", function()
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            patches = { fixture, scenario },
            shot_screen = "file_browser",
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "populated",
                KOPANDA_HOME_LOOK = "",
            },
        }
        local sidecar = result.sidecar
        assert.is_nil(sidecar.error, sidecar.error)
        assert.equals("file_browser", sidecar.screen)
        paint_budget.check("file browser paint on colorsoft", sidecar)
        local log = read(result.log)
        assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
        assert.equals(0, count(log, "settle cap"))
    end)
end)
