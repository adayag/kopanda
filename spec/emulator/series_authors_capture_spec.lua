-- The Series, Authors, Subjects, search and History views: each of the eight views (Series list, one series, Authors
-- list, one author, Subjects list, one subject, the search's results, History) in Diner on the Colorsoft, over the
-- shelf library (shelf_library.lua). The home fixture patch (at empty) freezes the clock and stores the look; the
-- scenario patch stores the shelf library as the home folder, writes the sidecars, adds one path-less book, extracts
-- every book's row and gives each copy its scripted metadata before any window shows, and shows the view's window
-- directly once the home settles, so the window's one settled signal is the shot. The look is passed empty so a
-- KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("the series, authors, subjects, search and history views", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local shelf_library = require("emulator.shelf_library")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-series-authors.lua"

    local scenarios = {
        { view = "series-list", screen = "series" },
        { view = "series-books", screen = "series" },
        { view = "authors-list", screen = "authors" },
        { view = "author-books", screen = "authors" },
        { view = "subjects-list", screen = "subjects" },
        { view = "subject-books", screen = "subjects" },
        { view = "search-books", screen = "search" },
        { view = "history-books", screen = "book_list" },
    }

    local function capture(opts)
        local library = shelf_library.make()
        return driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library,
            patches = { fixture, scenario },
            shot_screen = opts.screen,
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "empty",
                KOPANDA_HOME_LOOK = "",
                KOPANDA_SHELF_DIR = library,
                KOPANDA_SHELF_VIEW = opts.view,
            },
        }
    end

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
        it("show " .. scenario_opts.view .. " on colorsoft", function()
            local result = capture(scenario_opts)
            local sidecar = result.sidecar
            assert.is_nil(sidecar.error, sidecar.error)
            assert.equals(scenario_opts.screen, sidecar.screen)
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
            -- Every row was extracted before the show, so the window's request after its first
            -- paint asks for nothing and no arrival repaints it.
            assert.equals(0, count(log, "KOPANDA_SCENARIO: extraction asked"))
        end)
    end
end)
