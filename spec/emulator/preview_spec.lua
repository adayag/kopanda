-- bin/preview renders a profile's home in one look, day or night (C2, C3): the default settings
-- render the committed goldens, never writing one, and a settings change renders differently.
-- Each case runs the script as the studio's server does, with KOPANDA_UPDATE_GOLDENS unset in
-- its environment, and TMPDIR under this run's KO_HOME, which bin/check removes.
describe("bin/preview", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local rapidjson = require("rapidjson")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local compare = require("emulator.compare")
    local root = os.getenv("KOPANDA_ROOT")
    local ko_home = os.getenv("KO_HOME")
    -- The home goldens' fraction, spec/emulator/home_golden_spec.lua.
    local HOME_MAX_FRACTION = 0.00002
    local COLORSOFT = "1264 1680 300 color"
    -- Paris as spec/emulator/capture_inputs_spec.lua has it.
    local function paris(units)
        return "return {\n"
            .. "    [\"schema_version\"] = 1,\n"
            .. "    [\"weather.location\"] = {\n"
            .. "        name = \"Paris, Île-de-France\", latitude = 48.85341, longitude = 2.3488,\n"
            .. "    },\n"
            .. "    [\"weather.units\"] = \"" .. units .. "\",\n"
            .. "}\n"
    end

    local scratch = ko_home .. "/preview-spec"
    local tmp = scratch .. "/tmp"
    if lfs.attributes(scratch, "mode") ~= "directory" then
        assert(lfs.mkdir(scratch))
        assert(lfs.mkdir(tmp))
    end

    local counter = 0
    local function fresh(name)
        counter = counter + 1
        return string.format("%s/%d-%s", scratch, counter, name)
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

    local function settings_file(text)
        local path = fresh("settings.lua")
        write(path, text)
        return path
    end

    -- Runs bin/preview <device> <look> <variant> <out> [settings] with env (NAME=value words)
    -- before it; returns the exit status, stdout and stderr.
    local function run(device, look, variant, out, settings, env)
        local stdout, stderr = fresh("stdout"), fresh("stderr")
        local command = string.format("cd '%s' && env -u KOPANDA_UPDATE_GOLDENS TMPDIR='%s' %s"
            .. " bin/preview %s %s %s '%s'%s > '%s' 2> '%s'", root, tmp, env or "", device, look, variant, out,
            settings and (" '" .. settings .. "'") or "", stdout, stderr)
        local quoted = command:gsub("'", "'\\''")
        local pipe = assert(io.popen("sh -c '" .. quoted .. "'; echo $?"))
        local status = tonumber(pipe:read("*a"):match("(%d+)%s*$"))
        pipe:close()
        return status, read(stdout), read(stderr)
    end

    -- Runs bin/preview <device> <look> <variant> <out> [settings]; returns out, the decoded JSON
    -- line, stdout and stderr, asserting exit 0.
    local function preview(device, look, variant, settings)
        local out = fresh("out.png")
        local status, out_text, err_text = run(device, look, variant, out, settings)
        assert.equals(0, status, err_text)
        return out, rapidjson.decode(out_text), out_text, err_text
    end

    local default_diner
    local function default_diner_render()
        default_diner = default_diner or preview(COLORSOFT, "diner", "day")
        return default_diner
    end

    local function assert_answer(out, answer, stdout, stderr, width, height)
        assert.truthy(stdout:match("^[^\n]+\n$"), stdout)
        assert.equals("", stderr)
        assert.equals(out, answer.png)
        assert.equals(width, answer.width)
        assert.equals(height, answer.height)
        assert.is_number(answer.paint_ms)
    end

    it("renders the Diner day golden with no settings file", function()
        local out, answer, stdout, stderr = preview(COLORSOFT, "diner", "day")
        default_diner = out
        assert_answer(out, answer, stdout, stderr, 1264, 1680)
        local checked = golden.check("home-diner", "colorsoft", { png = out },
            { update = false, max_fraction = HOME_MAX_FRACTION })
        assert.is_true(checked.ok)
    end)

    it("renders the Editorial night golden with no settings file", function()
        local out, answer, stdout, stderr = preview(COLORSOFT, "editorial", "night")
        assert_answer(out, answer, stdout, stderr, 1264, 1680)
        local checked = golden.check("home-night-editorial", "colorsoft", { png = out }, { update = false })
        assert.is_true(checked.ok)
    end)

    it("renders another text size differently from no settings file", function()
        local large = preview(COLORSOFT, "diner", "day",
            settings_file('return { ["schema_version"] = 1, ["text_size"] = "large" }\n'))
        assert.is_false(compare.compare(large, default_diner_render()).ok)
    end)

    it("renders a stored location in celsius differently from the same in fahrenheit", function()
        local celsius = preview(COLORSOFT, "diner", "day", settings_file(paris("celsius")))
        local fahrenheit = preview(COLORSOFT, "diner", "day", settings_file(paris("fahrenheit")))
        -- 16° against 61°: two swapped digits, fewer pixels than compare's default lets through.
        assert.is_false(compare.compare(celsius, fahrenheit, { max_fraction = HOME_MAX_FRACTION }).ok)
        -- A celsius render with no reading at all differs by thousands of pixels, past the default.
        assert.is_true(compare.compare(celsius, fahrenheit).ok, "the same weather row; only the temperature differs")
    end)

    it("renders the look it is given, not the look the settings file stores", function()
        local settings = settings_file('return { ["schema_version"] = 1, ["look"] = "editorial" }\n')
        local out = preview(COLORSOFT, "diner", "day", settings)
        local checked = golden.check("home-diner", "colorsoft", { png = out },
            { update = false, max_fraction = HOME_MAX_FRACTION })
        assert.is_true(checked.ok)
        assert.equals('return { ["schema_version"] = 1, ["look"] = "editorial" }\n', read(settings),
            "the profile's file is not written")
    end)

    it("exits 1 with the driver's message, no Lua position before it, first on stderr", function()
        -- An emulator directory like the real one, every entry linked, but whose own plugins/
        -- holds a kopanda.koplugin: the driver refuses before KOReader starts.
        local emulator = fresh("emulator")
        finally(function()
            os.execute("rm -rf '" .. emulator .. "'")
        end)
        local real = os.getenv("KOPANDA_EMULATOR")
        local build = string.format("set -e; mkdir '%s'; for e in '%s'/* '%s'/.[!.]*; do"
            .. ' if [ -e "$e" ] && [ "${e##*/}" != plugins ]; then ln -s "$e" \'%s\'/; fi; done;'
            .. " mkdir '%s/plugins'; ln -s '%s'/plugins/* '%s/plugins/';"
            .. " mkdir '%s/plugins/kopanda.koplugin'",
            emulator, real, real, emulator, emulator, real, emulator, emulator)
        assert.equals(0, os.execute(build))
        local status, stdout, stderr = run(COLORSOFT, "diner", "day", fresh("out.png"), nil,
            "KOPANDA_EMULATOR='" .. emulator .. "'")
        assert.equals(1, status, stderr)
        assert.equals("", stdout)
        assert.equals("capture: " .. emulator .. "/plugins/kopanda.koplugin exists;"
            .. " KOReader would load the plugin from both paths", stderr:match("^([^\n]*)"))
    end)

    -- The fixture stores whatever look it is given, and the plugin's Settings reads a choice it
    -- doesn't know as the default: an id no look holds would render Diner unless it is refused.
    it("exits 1 naming the look, rendering nothing, for an id no look holds", function()
        local out = fresh("out.png")
        local status, stdout, stderr = run(COLORSOFT, "classic", "day", out)
        assert.equals(1, status, stderr)
        assert.equals("", stdout)
        assert.equals(1, stderr:find("no look classic; the looks are editorial, diner", 1, true), stderr)
        assert.is_nil(lfs.attributes(out, "mode"))
    end)

    it("renders a grey device at its own size", function()
        local out, answer, stdout, stderr = preview("1072 1448 300 grey", "diner", "day")
        assert_answer(out, answer, stdout, stderr, 1072, 1448)
        local width, height = driver.png_size(out)
        assert.equals(1072, width)
        assert.equals(1448, height)
    end)
end)
