describe("the emulator capture driver", function()
    local lfs = require("libs/libkoreader-lfs")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local ko_home = os.getenv("KO_HOME")
    local probe = root .. "/spec/fixtures/probe.koplugin"

    local counter = 0
    local function fresh_dir(name)
        counter = counter + 1
        local dir = string.format("%s/driver-%s-%d", ko_home, name, counter)
        assert(lfs.mkdir(dir))
        return dir
    end

    local function write(path, text, executable)
        local f = assert(io.open(path, "w"))
        f:write(text)
        f:close()
        if executable then
            assert(os.execute("chmod +x '" .. path .. "'") == 0)
        end
    end

    -- A fake emulator dir: ./luajit answers the driver's seeding one-liner (-e) with exit 0
    -- and, run as the emulator, records its pid and sleeps.
    local function fake_emulator(opts)
        opts = opts or {}
        local dir = fresh_dir("emu")
        assert(lfs.mkdir(dir .. "/plugins"))
        if not opts.no_luajit then
            write(dir .. "/luajit", "#!/bin/sh\n[ \"$1\" = -e ] && exit 0\necho $$ > '" .. dir
                .. "/pid'\nexec sleep 1000\n", true)
        end
        if opts.kopanda_present then
            assert(lfs.mkdir(dir .. "/plugins/kopanda.koplugin"))
        end
        return dir
    end

    local function capture_error(opts)
        opts.profile = opts.profile or "colorsoft"
        opts.plugin_dir = opts.plugin_dir or probe
        opts.library_dir = opts.library_dir or fresh_dir("lib")
        opts.out_dir = opts.out_dir or fresh_dir("out")
        local ok, err = pcall(driver.capture, opts)
        assert.is_false(ok)
        return tostring(err)
    end

    local function contains(text, needle)
        return text:find(needle, 1, true) ~= nil
    end

    it("refuses an emulator dir without luajit, naming the path", function()
        local emu = fake_emulator{ no_luajit = true }
        local err = capture_error{ emulator_dir = emu }
        assert.truthy(contains(err, emu .. "/luajit"), err)
    end)

    it("refuses an emulator whose plugins/ holds kopanda.koplugin, naming the path", function()
        local emu = fake_emulator{ kopanda_present = true }
        local err = capture_error{ emulator_dir = emu }
        assert.truthy(contains(err, emu .. "/plugins/kopanda.koplugin"), err)
    end)

    it("refuses a missing plugin_dir, naming it", function()
        local emu = fake_emulator()
        local missing = ko_home .. "/nope.koplugin"
        local err = capture_error{ emulator_dir = emu, plugin_dir = missing }
        assert.truthy(contains(err, missing), err)
    end)

    describe("write_profile", function()
        local LuaSettings = require("luasettings")

        local function keys_of(t)
            local keys = {}
            for k in pairs(t) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            return keys
        end

        it("writes settings LuaSettings reads back, for paperwhite", function()
            local dir = fresh_dir("profile")
            driver.write_profile(dir, "paperwhite", probe)
            local settings = LuaSettings:open(dir .. "/settings.reader.lua")
            assert.is_false(settings:readSetting("color_rendering"))
            assert.same({ "bookshelf", "ennUI", "simpleui", "solariconpack" },
                keys_of(settings:readSetting("plugins_disabled")))
            assert.is_false(settings:has("extra_plugin_paths"))
        end)

        it("writes color_rendering true for colorsoft", function()
            local dir = fresh_dir("profile")
            driver.write_profile(dir, "colorsoft", probe)
            local settings = LuaSettings:open(dir .. "/settings.reader.lua")
            assert.is_true(settings:readSetting("color_rendering"))
        end)

        -- user_version sits at offset 60 of the SQLite file header, 4 bytes big-endian.
        -- Read raw: the emulator's sqlite binding cannot be required twice in one Busted run.
        it("seeds coverbrowser's cache database at its current schema version", function()
            local dir = fresh_dir("profile")
            driver.write_profile(dir, "colorsoft", probe)
            local f = assert(io.open(dir .. "/settings/bookinfo_cache.sqlite3", "rb"))
            local header = f:read(64)
            f:close()
            assert.equals("SQLite format 3\0", header:sub(1, 16))
            local a, b, c, d = header:byte(61, 64)
            assert.equals(20201210, ((a * 256 + b) * 256 + c) * 256 + d)
        end)

        it("places the capture patch and the plugin copy", function()
            local dir = fresh_dir("profile")
            driver.write_profile(dir, "colorsoft", probe)
            assert.equals("file", lfs.attributes(dir .. "/patches/2-kopanda-capture.lua", "mode"))
            assert.equals("directory", lfs.attributes(dir .. "/plugins/probe.koplugin", "mode"))
            assert.equals("file", lfs.attributes(dir .. "/plugins/probe.koplugin/main.lua", "mode"))
        end)
    end)

    it("reads a PNG's size from its IHDR", function()
        local Blitbuffer = require("ffi/blitbuffer")
        local path = fresh_dir("png") .. "/tiny.png"
        local bb = Blitbuffer.new(2, 3, Blitbuffer.TYPE_BBRGB32)
        assert.is_true(bb:writePNG(path))
        bb:free()
        local width, height = driver.png_size(path)
        assert.equals(2, width)
        assert.equals(3, height)
    end)

    it("kills an emulator that outlives timeout_s and reports the timeout", function()
        local emu = fake_emulator()
        local started = os.time()
        local err = capture_error{ emulator_dir = emu, timeout_s = 2 }
        local elapsed = os.time() - started
        assert.truthy(contains(err, "timed out after 2 s"), err)
        assert.truthy(elapsed >= 1 and elapsed <= 6, "took " .. elapsed .. " s")
        local pid = assert(io.open(emu .. "/pid")):read("*n")
        assert.not_equals(0, os.execute("kill -0 " .. pid .. " 2>/dev/null"))
    end)
end)
