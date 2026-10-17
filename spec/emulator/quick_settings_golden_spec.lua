-- The quick-settings goldens and their paint budget (quick-settings C12): the quick-settings sheet
-- opened over the populated home, in each look on the Colorsoft, at 2026-10-13 08:42 in Chicago,
-- with the battery stubbed at 84. The home fixture patch freezes the clock and writes the scenario;
-- the quick-settings patch opens the sheet once the home settles; the capture is taken on the
-- sheet's own settled signal. The look is always passed (empty for Diner) so a KOPANDA_HOME_LOOK in
-- the caller's environment cannot leak in.
describe("the quick-settings goldens", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-quick-settings.lua"
    -- The sheets' paint budget (sheet_golden_spec.lua): a sheet paints within this many ms of its
    -- open, in the emulator on this Mac. A regression tripwire, not a device figure.
    local PAINT_BUDGET_MS = 250
    -- About 42 px at 1264×1680, against compare's default of about 1,060, which let the battery
    -- at 83 % and a hyphen for the slider's minus sign through. Clean captures differ from these
    -- goldens by 0 px.
    local MAX_FRACTION = 0.00002

    local scenarios = {
        { name = "quick-settings-diner" },
        { name = "quick-settings-editorial", look = "editorial" },
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
        it("match a fresh capture of " .. scenario_opts.name .. " on colorsoft, within the paint budget", function()
            local result = driver.capture{
                profile = "colorsoft",
                plugin_dir = plugin,
                patches = { fixture, scenario },
                shot_screen = "sheet",
                env = {
                    TZ = "America/Chicago",
                    KOPANDA_HOME_FIXTURE = "populated",
                    KOPANDA_HOME_LOOK = scenario_opts.look or "",
                },
            }
            local sidecar = result.sidecar
            assert.is_nil(sidecar.error, sidecar.error)
            assert.equals("sheet", sidecar.screen)
            assert.equals("quick_settings", sidecar.name)
            assert.is_number(sidecar.paint_ms)
            assert.truthy(sidecar.paint_ms > 0)
            assert.truthy(sidecar.paint_ms <= PAINT_BUDGET_MS,
                string.format("paint_ms %s over the %d ms budget", tostring(sidecar.paint_ms), PAINT_BUDGET_MS))
            print(string.format("%s paint on colorsoft: paint_ms=%s", scenario_opts.name, tostring(sidecar.paint_ms)))
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
            local checked = golden.check(scenario_opts.name, "colorsoft", result, { max_fraction = MAX_FRACTION })
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_true(checked.ok)
            end
        end)
    end
end)
