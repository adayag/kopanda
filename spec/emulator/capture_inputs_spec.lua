-- The capture inputs a studio profile needs (C1): the driver's device, a screen given in place of
-- a profiles.lua entry, and settings_file, copied into the scratch KO_HOME as the plugin's
-- settings; the home fixture's KOPANDA_HOME_WEATHER_* variables, which write its weather reading
-- for the location and units a profile's settings store; and a copied settings file whose chunk
-- returns a non-table, which renders as every key at its default.
describe("the capture inputs", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local driver = require("emulator.driver")
    local compare = require("emulator.compare")
    local root = os.getenv("KOPANDA_ROOT")
    local ko_home = os.getenv("KO_HOME")
    local probe = root .. "/spec/fixtures/probe.koplugin"
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    -- About 42 px at 1264×1680, against compare's default of about 1,060: two clean captures of
    -- the same home differ by 0 px, and the featured caption at 60 s a page or at 63 % differs by
    -- 356 px or more (TW-i9qml9), which the default lets through.
    local HOME_MAX_FRACTION = 0.00002

    local counter = 0
    local function fresh_dir(name)
        counter = counter + 1
        local dir = string.format("%s/capture-inputs-%s-%d", ko_home, name, counter)
        assert(lfs.mkdir(dir))
        return dir
    end

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function read(path)
        local f = assert(io.open(path, "rb"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function contains(text, needle)
        return text:find(needle, 1, true) ~= nil
    end

    local function entries(dir)
        local names = {}
        for name in lfs.dir(dir) do
            if name ~= "." and name ~= ".." then
                names[#names + 1] = name
            end
        end
        return names
    end

    -- The capture options of the populated home in Diner on the Colorsoft, with the weather
    -- variables weather sets and settings_file, if any, as the plugin's settings.
    local function home(weather, settings_file)
        local env = {
            TZ = "America/Chicago",
            KOPANDA_HOME_FIXTURE = "populated",
            KOPANDA_HOME_LOOK = "diner",
        }
        for name, value in pairs(weather) do
            env[name] = value
        end
        return {
            profile = "colorsoft",
            plugin_dir = plugin,
            patches = { fixture },
            settings_file = settings_file,
            env = env,
        }
    end

    -- The PNG of that home with no weather variable set and no settings file, captured once: what
    -- an empty variable and a settings file returning a non-table must render.
    local default_png
    local function default_home()
        default_png = default_png or driver.capture(home({})).png
        return default_png
    end

    local function capture_error(opts)
        local ok, err = pcall(driver.capture, opts)
        assert.is_false(ok)
        return tostring(err)
    end

    describe("device", function()
        it("captures at the device's size and colour under a name profiles.lua lacks", function()
            local result = driver.capture{
                profile = "studio-1",
                device = { width = 1072, height = 1448, dpi = 300, color = false },
                plugin_dir = probe,
                library_dir = fresh_dir("library"),
            }
            assert.equals(1072, result.width)
            assert.equals(1448, result.height)
            assert.equals(1072, result.sidecar.width)
            assert.equals(1448, result.sidecar.height)
            assert.is_false(result.sidecar.color)
        end)

        it("refuses a device without dpi, naming it, before anything runs", function()
            local out = fresh_dir("out")
            local err = capture_error{
                profile = "studio-1",
                device = { width = 1072, height = 1448, color = false },
                plugin_dir = probe,
                library_dir = fresh_dir("library"),
                out_dir = out,
            }
            assert.truthy(contains(err, "dpi"), err)
            assert.same({}, entries(out))
        end)

        it("refuses a profile name outside ^[a-z0-9-]+$, naming it, before anything runs", function()
            local out = fresh_dir("out")
            local err = capture_error{
                profile = "../x",
                device = { width = 1072, height = 1448, dpi = 300, color = false },
                plugin_dir = probe,
                library_dir = fresh_dir("library"),
                out_dir = out,
            }
            assert.truthy(contains(err, "../x"), err)
            assert.same({}, entries(out))
        end)
    end)

    describe("settings_file", function()
        it("leaves the file's exact bytes at settings/kopanda/settings.lua", function()
            local src = fresh_dir("settings") .. "/profile.lua"
            local bytes = "-- a profile's settings\nreturn {\n"
                .. "    [\"look\"] = \"editorial\",\n    [\"schema_version\"] = 1,\n}\n"
            write(src, bytes)
            local dir = fresh_dir("profile")
            driver.write_profile(dir, "colorsoft", probe, nil, nil, { settings_file = src })
            assert.equals(bytes, read(dir .. "/settings/kopanda/settings.lua"))
        end)

        it("refuses a missing path, naming it", function()
            local missing = ko_home .. "/no-such-settings.lua"
            local ok, err = pcall(driver.write_profile, fresh_dir("profile"), "colorsoft", probe, nil, nil,
                { settings_file = missing })
            assert.is_false(ok)
            assert.truthy(contains(tostring(err), missing), err)
        end)
    end)

    describe("the home fixture's weather variables", function()
        -- Paris as the studio's geocoding stores it, coordinates crossing the environment as
        -- bin/preview.lua formats them.
        local LATITUDE, LONGITUDE = 48.85341, 2.3488
        local PARIS = "return {\n"
            .. "    [\"schema_version\"] = 1,\n"
            .. "    [\"weather.location\"] = {\n"
            .. "        name = \"Paris, Île-de-France\", latitude = 48.85341, longitude = 2.3488,\n"
            .. "    },\n"
            .. "    [\"weather.units\"] = \"celsius\",\n"
            .. "}\n"

        it("show a reading for the stored location and units only when set to them", function()
            local settings = fresh_dir("settings") .. "/paris.lua"
            write(settings, PARIS)
            local with = driver.capture(home({
                KOPANDA_HOME_WEATHER_LATITUDE = string.format("%.17g", LATITUDE),
                KOPANDA_HOME_WEATHER_LONGITUDE = string.format("%.17g", LONGITUDE),
                KOPANDA_HOME_WEATHER_UNITS = "celsius",
            }, settings))
            local without = driver.capture(home({}, settings))
            -- Without them the cache is Chicago's in Fahrenheit, which reads as none for Paris in
            -- Celsius: "Weather needs Wi-Fi" (kopanda.koplugin/weather.lua).
            assert.is_false(compare.compare(with.png, without.png).ok)
        end)

        it("take a variable set to the empty string as unset", function()
            -- An exported .env block (.env.example lists them empty) reaches the fixture through
            -- the driver's inherited environment; empty, the reading is for the schema's defaults.
            local result = driver.capture(home({
                KOPANDA_HOME_WEATHER_LATITUDE = "",
                KOPANDA_HOME_WEATHER_LONGITUDE = "",
                KOPANDA_HOME_WEATHER_UNITS = "",
            }))
            local same = compare.compare(result.png, default_home(), { max_fraction = HOME_MAX_FRACTION })
            assert.is_true(same.ok, string.format("%d px differ", same.differing or -1))
        end)

        local failures = {
            {
                what = "only the units set",
                env = { KOPANDA_HOME_WEATHER_UNITS = "celsius" },
                names = { "KOPANDA_HOME_WEATHER_LATITUDE", "KOPANDA_HOME_WEATHER_LONGITUDE" },
            },
            {
                what = "the coordinates set without the units",
                env = { KOPANDA_HOME_WEATHER_LATITUDE = "48.85341", KOPANDA_HOME_WEATHER_LONGITUDE = "2.3488" },
                names = { "KOPANDA_HOME_WEATHER_UNITS" },
            },
            {
                what = "a latitude that isn't a number",
                env = {
                    KOPANDA_HOME_WEATHER_LATITUDE = "abc",
                    KOPANDA_HOME_WEATHER_LONGITUDE = "2.3488",
                    KOPANDA_HOME_WEATHER_UNITS = "celsius",
                },
                names = { "KOPANDA_HOME_WEATHER_LATITUDE", "abc" },
            },
            {
                what = "a unit outside the schema's",
                env = {
                    KOPANDA_HOME_WEATHER_LATITUDE = "48.85341",
                    KOPANDA_HOME_WEATHER_LONGITUDE = "2.3488",
                    KOPANDA_HOME_WEATHER_UNITS = "kelvin",
                },
                names = { "KOPANDA_HOME_WEATHER_UNITS", "kelvin" },
            },
        }
        for _, failure in ipairs(failures) do
            it("end the run with status 4 for " .. failure.what .. ", naming the problem", function()
                local err = capture_error(home(failure.env))
                assert.truthy(contains(err, "emulator exited with status 4"), err)
                assert.truthy(contains(err, "home fixture failed"), err)
                for _, name in ipairs(failure.names) do
                    assert.truthy(contains(err, name), err)
                end
            end)
        end
    end)

    it("renders a copied settings file returning a non-table as every key at its default", function()
        local settings = fresh_dir("settings") .. "/five.lua"
        write(settings, "return 5\n")
        local result = driver.capture(home({}, settings))
        local same = compare.compare(result.png, default_home(), { max_fraction = HOME_MAX_FRACTION })
        assert.is_true(same.ok, string.format("%d px differ", same.differing or -1))
    end)
end)
