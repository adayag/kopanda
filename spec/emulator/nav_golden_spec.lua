-- The file-browser goldens (nav-bar C8) and their paint budget (C11): KOReader's file browser on the
-- populated fixture's library with the nav bar in its band and Library active, in each look on each
-- profile, at 2026-10-13 08:42 in Chicago. The home fixture patch freezes the clock and writes the
-- scenario; the file-browser scenario closes the home once it settles, leaving the file browser on
-- top; the capture is taken on the file browser's own settled signal. The look is always passed
-- (empty for Diner) so a KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("the file-browser goldens", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-file-browser.lua"
    -- The file browser's paint budget: the wrapped setupLayout and its first paint on top within
    -- this many ms, in the emulator on this Mac, the home's tripwire (home_capture_spec.lua). A
    -- regression tripwire, not a device figure.
    local PAINT_BUDGET_MS = 250

    local scenarios = {
        { name = "filebrowser-diner", profile = "colorsoft" },
        { name = "filebrowser-diner", profile = "paperwhite" },
        { name = "filebrowser-editorial", look = "editorial", profile = "colorsoft" },
        { name = "filebrowser-editorial", look = "editorial", profile = "paperwhite" },
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
        it("match a fresh capture of " .. scenario_opts.name .. " on " .. scenario_opts.profile
                .. ", within the paint budget", function()
            local result = driver.capture{
                profile = scenario_opts.profile,
                plugin_dir = plugin,
                patches = { fixture, scenario },
                shot_screen = "file_browser",
                env = {
                    TZ = "America/Chicago",
                    KOPANDA_HOME_FIXTURE = "populated",
                    KOPANDA_HOME_LOOK = scenario_opts.look or "",
                },
            }
            local sidecar = result.sidecar
            assert.is_nil(sidecar.error, sidecar.error)
            assert.equals("file_browser", sidecar.screen)
            assert.is_number(sidecar.paint_ms)
            assert.truthy(sidecar.paint_ms > 0)
            assert.truthy(sidecar.paint_ms <= PAINT_BUDGET_MS,
                string.format("paint_ms %s over the %d ms budget", tostring(sidecar.paint_ms), PAINT_BUDGET_MS))
            print(string.format("%s paint on %s: paint_ms=%s", scenario_opts.name, scenario_opts.profile,
                tostring(sidecar.paint_ms)))
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
            local checked = golden.assert_golden(scenario_opts.name, scenario_opts.profile, result)
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_true(checked.ok)
            end
        end)
    end
end)
