-- The home goldens (C8): each look on each profile with a known weather cache, reading
-- statistics and a featured book with its real cover; each look on each profile with none of
-- them, the featured slot in its first-run state and the launcher's last entry a plugin that
-- isn't there; and each look on the Colorsoft with the featured book and CoverBrowser disabled,
-- its typographic cover. All at 2026-10-13 08:42 in Chicago, and no capture drops a row. The home
-- fixture patch freezes the clock and writes the scenario before any plugin runs. Diner scenarios
-- store no look, so they show the schema's default; the look is always passed (empty for Diner)
-- so a KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("the home goldens", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    -- About 42 px at 1264×1680, against compare's default of about 1,060. Clean captures differ
    -- from these goldens by 0 px; the featured caption at 60 s a page or at 63 % differs by 356 px
    -- or more on every golden that shows it (TW-i9qml9), which the default let through.
    local MAX_FRACTION = 0.00002

    local scenarios = {
        { name = "home-diner", fixture = "populated", profile = "colorsoft" },
        { name = "home-diner", fixture = "populated", profile = "paperwhite" },
        { name = "home-editorial", look = "editorial", fixture = "populated", profile = "colorsoft" },
        { name = "home-editorial", look = "editorial", fixture = "populated", profile = "paperwhite" },
        { name = "home-empty-diner", fixture = "empty", profile = "colorsoft" },
        { name = "home-empty-editorial", look = "editorial", fixture = "empty", profile = "colorsoft" },
        { name = "home-empty-diner", fixture = "empty", profile = "paperwhite" },
        { name = "home-empty-editorial", look = "editorial", fixture = "empty", profile = "paperwhite" },
        { name = "home-typecover-diner", fixture = "typecover", profile = "colorsoft" },
        { name = "home-typecover-editorial", look = "editorial", fixture = "typecover", profile = "colorsoft" },
    }

    local function read(path)
        local f = assert(io.open(path, "r"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function has(list, value)
        for _, v in ipairs(list) do
            if v == value then
                return true
            end
        end
        return false
    end

    for _, scenario in ipairs(scenarios) do
        it("match a fresh capture of " .. scenario.name .. " on " .. scenario.profile, function()
            local result = driver.capture{
                profile = scenario.profile,
                plugin_dir = plugin,
                patches = { fixture },
                env = {
                    TZ = "America/Chicago",
                    KOPANDA_HOME_FIXTURE = scenario.fixture,
                    KOPANDA_HOME_LOOK = scenario.look or "",
                },
            }
            assert.equals("home", result.sidecar.screen)
            -- The typographic cover is CoverBrowser's absence, not a missing cache entry.
            assert.equals(scenario.fixture ~= "typecover", has(result.sidecar.plugins, "coverbrowser"))
            -- Every row of the default layout fits: the row engine logs each row it drops
            -- (kopanda.koplugin/layout.lua, Layout.place).
            local dropped = read(result.log):match("[^\n]*doesn't fit the screen[^\n]*")
            assert.is_nil(dropped, dropped)
            local checked = golden.check(scenario.name, scenario.profile, result, { max_fraction = MAX_FRACTION })
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_true(checked.ok)
            end
        end)
    end
end)
