-- The Series and Authors goldens and their paint budget (series-and-authors C13): each of the four
-- views (the Series list, one series, the Authors list, one author) in each look on the Colorsoft,
-- over a capture library this spec builds in its scratch space: the three fixture books under their
-- own names and copies of one of them under the names the scenario's catalogue lists, so
-- spec/fixtures/library/ (counted by fixtures_spec.lua, listed by the file-browser goldens) is not
-- changed. The home fixture patch (at empty, which sets up no featured book) freezes the clock and
-- stores the look; the scenario patch stores the capture library as the home folder, writes the
-- sidecars, adds one path-less book, extracts every book's row and gives each copy its scripted
-- metadata before any window shows, and shows the view's window directly once the home settles,
-- so the window's one settled signal is the shot. The look is always passed (empty for Diner) so a
-- KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("the series and authors goldens", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-series-authors.lua"
    -- The windows' paint budget: each paints within this many ms of its show, in the emulator on
    -- this Mac, the home's tripwire (home_capture_spec.lua). A regression tripwire, not a device
    -- figure. The chrome's settled signal carries paint_ms alone, as the library's
    -- (library_golden_spec.lua).
    local PAINT_BUDGET_MS = 250
    -- About 42 px at 1264×1680, as the file-browser and library goldens allow (nav_golden_spec.lua).
    local MAX_FRACTION = 0.00002
    local ORIGINALS = { "a-christmas-carol.epub", "frankenstein.epub", "the-time-machine.epub" }
    -- The copies, each of COPIED, under the names the scenario's catalogue gives metadata to
    -- (2-scenario-series-authors.lua, CATALOGUE); the scenario refuses a library that holds any
    -- other file or lacks one.
    local COPIED = "the-time-machine.epub"
    local COPIES = {
        "a-study-in-scarlet.epub", "the-sign-of-the-four.epub", "the-lost-world.epub", "micah-clarke.epub",
        "the-white-company.epub", "the-chimes.epub", "the-cricket-on-the-hearth.epub", "the-pioneers.epub",
        "the-last-of-the-mohicans.epub", "alices-adventures-in-wonderland.epub", "through-the-looking-glass.epub",
        "the-warden.epub", "barchester-towers.epub", "the-three-musketeers.epub", "twenty-years-after.epub",
        "the-wonderful-wizard-of-oz.epub", "the-marvelous-land-of-oz.epub", "the-wrong-box.epub",
    }

    local scenarios = {
        { name = "series-list-diner", view = "series-list", screen = "series" },
        { name = "series-list-editorial", look = "editorial", view = "series-list", screen = "series" },
        { name = "series-books-diner", view = "series-books", screen = "series" },
        { name = "series-books-editorial", look = "editorial", view = "series-books", screen = "series" },
        { name = "authors-list-diner", view = "authors-list", screen = "authors" },
        { name = "authors-list-editorial", look = "editorial", view = "authors-list", screen = "authors" },
        { name = "author-books-diner", view = "author-books", screen = "authors" },
        { name = "author-books-editorial", look = "editorial", view = "author-books", screen = "authors" },
    }

    local function quote(s)
        return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
    end

    local function copy(from, to)
        assert.equals(0, os.execute("cp " .. quote(from) .. " " .. quote(to)))
    end

    -- A fresh capture library under KO_HOME. A copy has its own path, so its CoverBrowser row and
    -- sidecar are its own.
    local made = 0
    local function capture_library()
        made = made + 1
        local dir = string.format("%s/shelf-capture-%d", os.getenv("KO_HOME"), made)
        if lfs.attributes(dir, "mode") then
            assert.equals(0, os.execute("rm -rf " .. quote(dir)))
        end
        assert(lfs.mkdir(dir))
        local fixtures = root .. "/spec/fixtures/library/"
        for _, book in ipairs(ORIGINALS) do
            copy(fixtures .. book, dir .. "/" .. book)
        end
        for _, name in ipairs(COPIES) do
            copy(fixtures .. COPIED, dir .. "/" .. name)
        end
        return dir
    end

    local function capture(opts)
        local library = capture_library()
        return driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library,
            patches = { fixture, scenario },
            shot_screen = opts.screen,
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "empty",
                KOPANDA_HOME_LOOK = opts.look or "",
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
        it("match a fresh capture of " .. scenario_opts.name .. " on colorsoft, within the paint budget", function()
            local result = capture(scenario_opts)
            local sidecar = result.sidecar
            assert.is_nil(sidecar.error, sidecar.error)
            assert.equals(scenario_opts.screen, sidecar.screen)
            assert.is_number(sidecar.paint_ms)
            assert.truthy(sidecar.paint_ms > 0)
            print(string.format("%s paint on colorsoft: paint_ms=%s", scenario_opts.name,
                tostring(sidecar.paint_ms)))
            assert.truthy(sidecar.paint_ms <= PAINT_BUDGET_MS,
                string.format("paint_ms %s over the %d ms budget", tostring(sidecar.paint_ms), PAINT_BUDGET_MS))
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
            -- Every row was extracted before the show, so the window's request after its first
            -- paint asks for nothing and no arrival repaints it.
            assert.equals(0, count(log, "KOPANDA_SCENARIO: extraction asked"))
            local checked = golden.check(scenario_opts.name, "colorsoft", result, { max_fraction = MAX_FRACTION })
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_true(checked.ok)
            end
        end)
    end
end)
