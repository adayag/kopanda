-- The library's paint budget (cover-grid C14): the library window over a capture library this spec
-- builds in its scratch space, in Diner on the Colorsoft, at its root, in its sub-folder and with
-- the sort sheet over its root; and, beside them, a book opened from the library closing back to
-- the library, built at the file manager's Show. The capture library (capture_library.lua) holds
-- copies of the three fixture books at its root and a sub-folder holding one more copy, so
-- spec/fixtures/library/ (counted by fixtures_spec.lua) is not changed. The home fixture patch (at
-- empty, which sets up no featured book) freezes the clock and stores the look; the library
-- scenario patch stores the capture library as the home folder, writes one book's reading
-- position, adds one path-less book, extracts every cover before the library shows, and opens the
-- library once the home settles. The look is passed empty so a KOPANDA_HOME_LOOK in the caller's
-- environment cannot leak in.
describe("the library on the emulator", function()
    require("commonrequire")
    local capture_library = require("emulator.capture_library")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-library.lua"
    -- The library's paint budget: the library, or the sort sheet over it, paints within this many
    -- ms of its show, in the emulator on this Mac, the home's tripwire (paint_budget.lua). A
    -- regression tripwire, not a device figure.
    local PAINT_BUDGET_MS = 250

    local scenarios = {
        { step = "root" },
        { step = "folder" },
        { step = "sort", screen = "sheet" },
    }

    local function capture(opts)
        local library = capture_library.make()
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
                KOPANDA_LIBRARY_DIR = library,
                KOPANDA_LIBRARY_STEP = opts.step,
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

    local function within_budget(paint_ms)
        assert.is_number(paint_ms)
        assert.truthy(paint_ms > 0)
        assert.truthy(paint_ms <= PAINT_BUDGET_MS,
            string.format("paint_ms %s over the %d ms budget", tostring(paint_ms), PAINT_BUDGET_MS))
    end

    for _, scenario_opts in ipairs(scenarios) do
        local screen = scenario_opts.screen or "library"
        it("settles at the " .. scenario_opts.step .. " step on colorsoft, within the paint budget", function()
            local result = capture{ step = scenario_opts.step, screen = screen }
            local sidecar = result.sidecar
            assert.is_nil(sidecar.error, sidecar.error)
            assert.equals(screen, sidecar.screen)
            if screen ~= "library" then
                assert.equals("sort", sidecar.name)
            end
            within_budget(sidecar.paint_ms)
            print(string.format("library %s paint on colorsoft: paint_ms=%s", scenario_opts.step,
                tostring(sidecar.paint_ms)))
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
        end)
    end

    -- Left by the routing task (cover-grid D4): its book-close scenario opens its book with
    -- ReaderUI:showReader on the home's settle, not from the library.
    -- The book opens from the sub-folder, so same_dir fails on a library that came back at the
    -- root. The capture library holds one page per folder, so same_page is trivially true here;
    -- the page kept across a close is the unit specs' to prove.
    it("closes a book opened from a sub-folder onto the library built at the file manager's Show at "
            .. "that folder, the file browser never painted", function()
        local result = capture{ step = "book", screen = "scenario" }
        local sidecar = result.sidecar
        assert.is_nil(sidecar.error, sidecar.error)
        assert.equals("scenario", sidecar.screen)
        assert.equals(0, sidecar.fm_paints)
        assert.is_true(sidecar.same_dir)
        assert.is_true(sidecar.same_page)
        within_budget(sidecar.paint_ms)
        print(string.format("library book close: fm_paints=%d paint_ms=%s", sidecar.fm_paints,
            tostring(sidecar.paint_ms)))
    end)
end)
