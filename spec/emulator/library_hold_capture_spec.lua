-- The library's hold sheets and their paint budget (context-menu C12): the sheet a hold on the
-- library opens, over cover-grid's capture library (capture_library.lua) at its root, in Diner on
-- the Colorsoft, at 2026-10-13 08:42 in Chicago: the book sheet of the reading book and of the
-- path-less source book, the folder sheet of its sub-folder and the empty-space sheet of its sixth
-- cell. The home fixture patch (at empty) freezes the clock and stores the look; the library
-- scenario patch (at its root step) stores the capture library as the home folder, writes the
-- reading book's position, adds the path-less book, extracts every cover and opens the library
-- once the home settles; the library-hold patch writes the reading book's history entry and holds
-- the tile or cell once the library settles; the capture is taken on the sheet's own settled
-- signal. The look is passed empty so a KOPANDA_HOME_LOOK in the caller's environment cannot leak
-- in.
describe("the library's hold sheets", function()
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
        scenarios_dir .. "2-scenario-library_hold.lua",
    }

    local scenarios = {
        { hold = "book", sheet = "book" },
        { hold = "remote", sheet = "book" },
        { hold = "folder", sheet = "library_folder" },
        { hold = "empty", sheet = "library_empty" },
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
        it("open the " .. scenario_opts.sheet .. " sheet on a " .. scenario_opts.hold
                .. " hold on colorsoft, within the paint budget", function()
            local library = capture_library.make()
            local result = driver.capture{
                profile = "colorsoft",
                plugin_dir = plugin,
                library_dir = library,
                patches = patches,
                shot_screen = "sheet",
                env = {
                    TZ = "America/Chicago",
                    KOPANDA_HOME_FIXTURE = "empty",
                    KOPANDA_HOME_LOOK = "",
                    KOPANDA_LIBRARY_DIR = library,
                    KOPANDA_LIBRARY_STEP = "root",
                    KOPANDA_LIBRARY_HOLD = scenario_opts.hold,
                },
            }
            local sidecar = result.sidecar
            assert.is_nil(sidecar.error, sidecar.error)
            assert.equals("sheet", sidecar.screen)
            assert.equals(scenario_opts.sheet, sidecar.name)
            paint_budget.check("library-hold-" .. scenario_opts.hold .. " paint on colorsoft", sidecar)
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
        end)
    end
end)
