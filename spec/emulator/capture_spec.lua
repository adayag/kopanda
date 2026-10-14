describe("capturing the probe plugin on the emulator", function()
    local lfs = require("libs/libkoreader-lfs")
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
            assert.truthy(has(result.sidecar.plugins, "probe"))
            for _, disabled in ipairs(driver.disabled_plugins) do
                assert.falsy(has(result.sidecar.plugins, disabled), disabled .. " loaded")
            end
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
            assert.equals(0, count(log, "BookInfo cache DB schema updated"))
            assert.is_nil(lfs.attributes(result.scratch, "mode"))
        end)
    end

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
        assert.truthy(tostring(err):find("settle cap", 1, true), err)
        assert.truthy(elapsed < 30, "took " .. elapsed .. " s")
    end)
end)
