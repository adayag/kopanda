-- The paint budget (paint_budget.lua) on the screens it holds to it, one capture each, in Diner on the Colorsoft at
-- 2026-10-13 08:42 in Chicago: the populated home at the default text size and at Extra large, the library at its
-- root over the capture library (capture_library.lua), the Series list over the shelf library (shelf_library.lua), the
-- book status page opened from a library hold, the Stats window and its wall of covers; and, held to 100 ms, the
-- home's share of a book's close (book_close_spec.lua's scenario).
-- Each screen's own spec judges what it shows; this one judges only its time, so bin/check runs it alone, after the
-- others, on a settled host. The look is passed empty so a KOPANDA_HOME_LOOK in the caller's environment cannot leak
-- in.
describe("the paint budget on the emulator", function()
    require("commonrequire")
    local capture_library = require("emulator.capture_library")
    local driver = require("emulator.driver")
    local lfs = require("libs/libkoreader-lfs")
    local paint_budget = require("emulator.paint_budget")
    local shelf_library = require("emulator.shelf_library")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenarios_dir = root .. "/spec/emulator/scenarios/"
    local fixture = scenarios_dir .. "2-scenario-home-fixture.lua"

    -- A settings file holding text_size, removed after the test.
    local function settings_at(text_size)
        local path = os.tmpname()
        local f = assert(io.open(path, "w"))
        f:write(string.format('return { schema_version = 1, text_size = %q }\n', text_size))
        f:close()
        finally(function()
            os.remove(path)
        end)
        return path
    end

    -- The settled signal of a capture shot on screen, with library (nil: the fixture library), patches after the home
    -- fixture, env beside the frozen clock and the empty look, and settings_file (nil: none).
    local function settled(screen, library, patches, env, settings_file)
        env.TZ = "America/Chicago"
        env.KOPANDA_HOME_LOOK = ""
        table.insert(patches, 1, fixture)
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library,
            patches = patches,
            shot_screen = screen,
            settings_file = settings_file,
            env = env,
        }
        local where = "\npng " .. result.png .. "\nlog " .. result.log
        assert.is_nil(result.sidecar.error, tostring(result.sidecar.error) .. where)
        assert.equals(screen, result.sidecar.screen, where)
        return result.sidecar
    end

    -- A window's settled signal carries paint_ms alone (library_chrome.lua, settle): wall time, judged as
    -- paint_budget.check judges it, a note in its place on a loaded host.
    local function check_wall(label, sidecar)
        assert.is_number(sidecar.paint_ms, label .. ": no paint_ms")
        assert.truthy(sidecar.paint_ms > 0, label)
        print(string.format("%s: paint_ms=%s", label, sidecar.paint_ms))
        local host = paint_budget.host()
        local judged, line = paint_budget.judges_wall(host.load, host.cores)
        if judged then
            assert.truthy(sidecar.paint_ms <= paint_budget.MS,
                string.format("%s: paint_ms %s over the %d ms budget", label, sidecar.paint_ms, paint_budget.MS))
        else
            print("[  NOTE    ] " .. label .. ": " .. line)
        end
    end

    it("paints the populated home within the budget", function()
        local sidecar = settled("home", nil, {}, { KOPANDA_HOME_FIXTURE = "populated" })
        paint_budget.check("home paint on colorsoft", sidecar)
    end)

    it("paints the populated home at Extra large within the budget", function()
        local sidecar = settled("home", nil, {}, { KOPANDA_HOME_FIXTURE = "populated" }, settings_at("extra_large"))
        paint_budget.check("extra-large home paint on colorsoft", sidecar)
    end)

    it("paints the library at its root within the budget", function()
        local library = capture_library.make()
        local sidecar = settled("library", library, { scenarios_dir .. "2-scenario-library.lua" }, {
            KOPANDA_HOME_FIXTURE = "empty",
            KOPANDA_LIBRARY_DIR = library,
            KOPANDA_LIBRARY_STEP = "root",
        })
        check_wall("library paint on colorsoft", sidecar)
    end)

    it("paints the Series list within the budget", function()
        local library = shelf_library.make()
        local sidecar = settled("series", library, { scenarios_dir .. "2-scenario-series-authors.lua" }, {
            KOPANDA_HOME_FIXTURE = "empty",
            KOPANDA_SHELF_DIR = library,
            KOPANDA_SHELF_VIEW = "series-list",
        })
        check_wall("series-list paint on colorsoft", sidecar)
    end)

    it("paints the book status page within the budget", function()
        local library = capture_library.make()
        local sidecar = settled("book_status", library, {
            scenarios_dir .. "2-scenario-library.lua",
            scenarios_dir .. "2-scenario-library_hold.lua",
            scenarios_dir .. "2-scenario-library_status.lua",
        }, {
            KOPANDA_HOME_FIXTURE = "empty",
            KOPANDA_LIBRARY_DIR = library,
            KOPANDA_LIBRARY_STEP = "root",
            KOPANDA_LIBRARY_HOLD = "book",
            KOPANDA_BOOK_STATUS_STEP = "page1",
        })
        check_wall("book-status paint on colorsoft", sidecar)
    end)

    -- The window's first build measures every row but the wall's, those of its later pages too.
    it("paints the Stats window within the budget", function()
        local sidecar = settled("stats", nil, { scenarios_dir .. "2-scenario-stats-screen.lua" },
            { KOPANDA_HOME_FIXTURE = "populated" })
        check_wall("stats paint on colorsoft", sidecar)
    end)

    -- Opened at the wall, so paint_ms holds the flow, the wall's build and a full page of covers' paint.
    it("paints a full page of the wall within the budget", function()
        local sidecar = settled("stats", nil, { scenarios_dir .. "2-scenario-stats-screen.lua" }, {
            KOPANDA_HOME_FIXTURE = "populated",
            KOPANDA_STATS_FINISHED = "30",
            KOPANDA_STATS_PAGE = "3",
        })
        check_wall("wall paint on colorsoft", sidecar)
    end)

    -- Opening a book writes its .sdr sidecar beside it (document_metadata_folder defaults to "doc",
    -- frontend/docsettings.lua:102), so the book is copied out of spec/fixtures/library/.
    it("builds and paints the home on a book's close within 100 ms", function()
        local library = os.getenv("KO_HOME") .. "/book-close-budget-library"
        if lfs.attributes(library, "mode") then
            assert.equals(0, os.execute("rm -rf '" .. library .. "'"))
        end
        assert(lfs.mkdir(library))
        assert.equals(0, os.execute("cp '" .. root .. "/spec/fixtures/library/frankenstein.epub' '" .. library .. "/'"))
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library,
            patches = { scenarios_dir .. "2-scenario-book-close.lua" },
            shot_screen = "scenario",
            env = { KOPANDA_HOME_LOOK = "" },
        }
        local where = "\npng " .. result.png .. "\nlog " .. result.log
        assert.is_nil(result.sidecar.error, tostring(result.sidecar.error) .. where)
        assert.equals("scenario", result.sidecar.screen, where)
        paint_budget.check("book close home on colorsoft", result.sidecar, nil, 100)
    end)
end)
