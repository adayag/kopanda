-- The library over a cwngsync placeholder and its paint budget: the library window over the capture library
-- (capture_library.lua) at its root, in Diner on the Colorsoft, at 2026-10-13 08:42 in Chicago, with a stub cwngsync
-- naming a-christmas-carol.epub a placeholder. The home fixture patch (at empty) freezes the clock and stores the
-- look; the library scenario patch stores the capture library as the home folder, writes the reading book's
-- position, adds the path-less book, extracts every cover and opens the library once the home settles; the
-- cwngsync patch registers the stub on the file manager. The capture is taken on the library's own settled signal.
-- The look is passed empty so a KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("the library over a placeholder", function()
    require("commonrequire")
    local capture_library = require("emulator.capture_library")
    local driver = require("emulator.driver")
    local paint_budget = require("emulator.paint_budget")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenarios_dir = root .. "/spec/emulator/scenarios/"
    local patches = {
        scenarios_dir .. "2-scenario-home-fixture.lua",
        scenarios_dir .. "2-scenario-library.lua",
        scenarios_dir .. "2-scenario-cwngsync.lua",
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

    it("settles on colorsoft with the stub registered, within the paint budget", function()
        local library = capture_library.make()
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library,
            patches = patches,
            shot_screen = "library",
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "empty",
                KOPANDA_HOME_LOOK = "",
                KOPANDA_LIBRARY_DIR = library,
                KOPANDA_LIBRARY_STEP = "root",
            },
        }
        local sidecar = result.sidecar
        assert.is_nil(sidecar.error, sidecar.error)
        assert.equals("library", sidecar.screen)
        -- The library's settled signal carries paint_ms and no cpu_ms (library_chrome.lua, settle),
        -- so it is held to the budget as library_capture_spec.lua holds the library's.
        assert.is_number(sidecar.paint_ms)
        assert.truthy(sidecar.paint_ms > 0)
        assert.truthy(sidecar.paint_ms <= paint_budget.MS,
            string.format("paint_ms %s over the %d ms budget", tostring(sidecar.paint_ms), paint_budget.MS))
        print(string.format("library placeholder paint on colorsoft: paint_ms=%s", tostring(sidecar.paint_ms)))
        local log = read(result.log)
        assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
        assert.equals(0, count(log, "settle cap"))
        assert.equals(1, count(log, "KOPANDA_SCENARIO: cwngsync stub registered"))
        assert.equals(1, count(log, "/" .. capture_library.BOOKS[1] .. "="))
    end)
end)
