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
    -- (seed_fails: prints "no sqlite here" and exits 1) and, run as the emulator, records
    -- its pid and sleeps (exit_now: exits 0 at once; ignore_term: ignores SIGTERM first,
    -- which survives the exec; record_args: writes its arguments one per line to <emu>/args
    -- and exits 0; record_env: writes its environment to <emu>/env and exits 0).
    local function fake_emulator(opts)
        opts = opts or {}
        local dir = fresh_dir("emu")
        assert(lfs.mkdir(dir .. "/plugins"))
        if not opts.no_luajit then
            local seed = opts.seed_fails and '{ echo "no sqlite here"; exit 1; }' or "exit 0"
            local body = "echo $$ > '" .. dir .. "/pid'\n"
            if opts.exit_now then
                body = "exit 0\n"
            elseif opts.record_args then
                body = "printf '%s\\n' \"$@\" > '" .. dir .. "/args'\nexit 0\n"
            elseif opts.record_env then
                body = "env > '" .. dir .. "/env'\nexit 0\n"
            elseif opts.ignore_term then
                body = body .. "trap '' TERM\n"
            end
            write(dir .. "/luajit", "#!/bin/sh\n[ \"$1\" = -e ] && " .. seed .. "\n" .. body .. "exec sleep 30\n",
                true)
        end
        if opts.kopanda_present then
            assert(lfs.mkdir(dir .. "/plugins/kopanda.koplugin"))
        end
        return dir
    end

    -- default_library: leave library_dir unset so the driver picks its own.
    local function capture_error(opts)
        opts.profile = opts.profile or "colorsoft"
        opts.plugin_dir = opts.plugin_dir or probe
        if not opts.default_library then
            opts.library_dir = opts.library_dir or fresh_dir("lib")
        end
        opts.default_library = nil
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

    local function recorded_args(emu)
        local args = {}
        for line in assert(io.open(emu .. "/args")):lines() do
            args[#args + 1] = line
        end
        return args
    end

    it("runs reader.lua over the fixture library when library_dir is not given", function()
        local emu = fake_emulator{ record_args = true }
        capture_error{ emulator_dir = emu, default_library = true }
        assert.same({ "reader.lua", root .. "/spec/fixtures/library" }, recorded_args(emu))
    end)

    it("runs reader.lua over an explicit library_dir, even an empty one", function()
        local emu = fake_emulator{ record_args = true }
        local empty = fresh_dir("lib")
        capture_error{ emulator_dir = emu, library_dir = empty }
        assert.same({ "reader.lua", empty }, recorded_args(emu))
    end)

    it("passes each env variable to the emulator beside its own", function()
        local emu = fake_emulator{ record_env = true }
        capture_error{ emulator_dir = emu, env = { TZ = "America/Chicago", KOPANDA_FIXTURE = "it's empty" } }
        local env = {}
        for line in assert(io.open(emu .. "/env")):lines() do
            local name, value = line:match("^([%w_]+)=(.*)$")
            if name then
                env[name] = value
            end
        end
        assert.equals("America/Chicago", env.TZ)
        assert.equals("it's empty", env.KOPANDA_FIXTURE)
        assert.equals("offscreen", env.SDL_VIDEO_DRIVER)
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

        -- The device toggles night mode before any UI exists when the key is set
        -- (frontend/device/generic/device.lua:344-347).
        it("writes night_mode true only when asked", function()
            local night = fresh_dir("profile")
            driver.write_profile(night, "colorsoft", probe, nil, nil, { night_mode = true })
            assert.is_true(dofile(night .. "/settings.reader.lua").night_mode)
            local day = fresh_dir("profile")
            driver.write_profile(day, "colorsoft", probe)
            assert.is_nil(dofile(day .. "/settings.reader.lua").night_mode)
        end)

        it("passes capture's night_mode through to the profile", function()
            local emu = fake_emulator{ exit_now = true }
            local out = fresh_dir("out")
            capture_error{ emulator_dir = emu, out_dir = out, night_mode = true }
            assert.is_true(dofile(out .. "/profile-colorsoft/settings.reader.lua").night_mode)
        end)

        -- Off, the emulator's NetworkMgr:isConnected() is false (frontend/device/sdl/device.lua:478-500),
        -- so no capture fetches the weather.
        it("turns the emulator's fake Wi-Fi off", function()
            local dir = fresh_dir("profile")
            driver.write_profile(dir, "colorsoft", probe)
            local settings = LuaSettings:open(dir .. "/settings.reader.lua")
            assert.is_false(settings:readSetting("emulator_fake_wifi_connected"))
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

        it("quotes the seed's output when seeding fails", function()
            local emu = fake_emulator{ seed_fails = true }
            local ok, err = pcall(driver.write_profile, fresh_dir("profile"), "colorsoft", probe, emu)
            assert.is_false(ok)
            assert.truthy(contains(tostring(err), "no sqlite here"), err)
        end)

        it("places the capture patch and the plugin copy", function()
            local dir = fresh_dir("profile")
            driver.write_profile(dir, "colorsoft", probe)
            assert.equals("file", lfs.attributes(dir .. "/patches/2-kopanda-capture.lua", "mode"))
            assert.equals("directory", lfs.attributes(dir .. "/plugins/probe.koplugin", "mode"))
            assert.equals("file", lfs.attributes(dir .. "/plugins/probe.koplugin/main.lua", "mode"))
        end)

        local function read(path)
            local f = assert(io.open(path, "r"))
            local text = f:read("*a")
            f:close()
            return text
        end

        it("copies each extra patch into patches/", function()
            local src = fresh_dir("patches")
            write(src .. "/2-one.lua", "-- one\n")
            write(src .. "/2-two.lua", "-- two\n")
            local dir = fresh_dir("profile")
            driver.write_profile(dir, "colorsoft", probe, nil, { src .. "/2-one.lua", src .. "/2-two.lua" })
            assert.equals("-- one\n", read(dir .. "/patches/2-one.lua"))
            assert.equals("-- two\n", read(dir .. "/patches/2-two.lua"))
            assert.equals("file", lfs.attributes(dir .. "/patches/2-kopanda-capture.lua", "mode"))
        end)

        it("refuses an extra patch whose name does not start with 2-, naming it", function()
            local src = fresh_dir("patches")
            local early = src .. "/1-early.lua"
            write(early, "-- early\n")
            local ok, err = pcall(driver.write_profile, fresh_dir("profile"), "colorsoft", probe, nil, { early })
            assert.is_false(ok)
            assert.truthy(contains(tostring(err), early), err)
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

    it("escalates to SIGKILL when the emulator ignores SIGTERM", function()
        local emu = fake_emulator{ ignore_term = true }
        local started = os.time()
        local err = capture_error{ emulator_dir = emu, timeout_s = 2 }
        local elapsed = os.time() - started
        assert.truthy(contains(err, "timed out after 2 s"), err)
        assert.truthy(elapsed <= 12, "took " .. elapsed .. " s")
        local pid = assert(io.open(emu .. "/pid")):read("*n")
        assert.not_equals(0, os.execute("kill -0 " .. pid .. " 2>/dev/null"))
    end)

    it("leaves no sleeping killer behind when the emulator exits first", function()
        local emu = fake_emulator{ exit_now = true }
        capture_error{ emulator_dir = emu, timeout_s = 777 }
        assert.not_equals(0, os.execute("pgrep -f 'sleep 77[7]' >/dev/null"))
    end)
end)
