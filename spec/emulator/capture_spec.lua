describe("capturing the probe plugin on the emulator", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local RenderImage = require("ui/renderimage")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local ko_home = os.getenv("KO_HOME")
    local probe = root .. "/spec/fixtures/probe.koplugin"

    local counter = 0
    local function fresh_dir(name)
        counter = counter + 1
        local dir = string.format("%s/capture-spec-%s-%d", ko_home, name, counter)
        assert(lfs.mkdir(dir))
        return dir
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

    local function has(list, value)
        for _, v in ipairs(list) do
            if v == value then
                return true
            end
        end
        return false
    end

    -- The probe's corner squares: 40 px, 20 px in from each corner
    -- (spec/fixtures/probe.koplugin/main.lua).
    local SQUARE, MARGIN = 40, 20

    local function grey_at(bb, x, y)
        return bb:getPixel(x, y):getColor8().a
    end

    for _, name in ipairs({ "colorsoft", "paperwhite" }) do
        it("captures the probe at the " .. name .. " size with a settled sidecar", function()
            local profile = driver.profiles[name]
            local result = driver.capture{ profile = name, plugin_dir = probe, library_dir = fresh_dir("library") }
            assert.equals(profile.width, result.width)
            assert.equals(profile.height, result.height)
            assert.equals("home", result.sidecar.screen)
            assert.is_number(result.sidecar.paint_ms)
            assert.truthy(result.sidecar.paint_ms > 0)
            assert.equals(profile.width, result.sidecar.width)
            assert.equals(profile.height, result.sidecar.height)
            assert.equals(profile.color, result.sidecar.color)
            assert.truthy(has(result.sidecar.plugins, "probe"))
            for _, disabled in ipairs(driver.disabled_plugins) do
                assert.falsy(has(result.sidecar.plugins, disabled), disabled .. " loaded")
            end
            local shot = assert(RenderImage:renderImageFile(result.png))
            assert.equals(0, grey_at(shot, MARGIN + SQUARE / 2, MARGIN + SQUARE / 2))
            assert.equals(255, grey_at(shot, result.width / 2, MARGIN + SQUARE / 2))
            shot:free()
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
            assert.equals(0, count(log, "BookInfo cache DB schema updated"))
            assert.is_nil(lfs.attributes(result.scratch, "mode"))
        end)
    end

    it("captures the probe over the fixture library when library_dir is not given", function()
        local result = driver.capture{ profile = "colorsoft", plugin_dir = probe }
        assert.equals("file", lfs.attributes(result.png, "mode"))
        assert.equals(driver.profiles.colorsoft.width, result.width)
        assert.equals(driver.profiles.colorsoft.height, result.height)
        assert.equals("home", result.sidecar.screen)
    end)

    it("hits the settle cap when the plugin never signals", function()
        local mute = fresh_dir("mute") .. "/probe.koplugin"
        assert.equals(0, os.execute("cp -R '" .. probe .. "' '" .. mute .. "'"))
        local main = read(mute .. "/main.lua")
        local stripped, replaced = main:gsub("[^\n]*event_hook:execute[^\n]*\n", "")
        assert.equals(1, replaced)
        local f = assert(io.open(mute .. "/main.lua", "w"))
        f:write(stripped)
        f:close()

        local started = os.time()
        local ok, err = pcall(driver.capture,
            { profile = "colorsoft", plugin_dir = mute, library_dir = fresh_dir("library"), cap_s = 5 })
        local elapsed = os.time() - started
        assert.is_false(ok)
        assert.truthy(tostring(err):match("^[^\n]*settle cap"), err)
        assert.truthy(elapsed >= 4 and elapsed <= 12, "took " .. elapsed .. " s")
    end)
end)
