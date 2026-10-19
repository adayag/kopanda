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

    -- A fake emulator dir: ./luajit answers the driver's seeding one-liner (-e) with exit 0 (seed_fails: prints "no
    -- sqlite here" and exits 1) and, run as the emulator, records its pid and sleeps (exit_now exits 0 at once;
    -- ignore_term ignores SIGTERM first; record_args writes its arguments one per line to <emu>/args; record_env writes
    -- its environment to <emu>/env).
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

    describe("run_starts", function()
        local function read(path)
            local f = assert(io.open(path, "r"))
            local text = f:read("*a")
            f:close()
            return text
        end

        local function lines(path)
            local found = {}
            for line in assert(io.open(path)):lines() do
                found[#found + 1] = line
            end
            return found
        end

        -- A fake emulator run as each start: appends KO_HOME's start count and the start's own variables to
        -- <emu>/starts, writes a tiny PNG and a sidecar where KOPANDA_SHOT says, and exits with KOPANDA_FAKE_STATUS
        -- (default 0).
        local function counting_emulator()
            local dir = fresh_dir("emu")
            assert(lfs.mkdir(dir .. "/plugins"))
            local Blitbuffer = require("ffi/blitbuffer")
            local bb = Blitbuffer.new(2, 3, Blitbuffer.TYPE_BBRGB32)
            assert.is_true(bb:writePNG(dir .. "/tiny.png"))
            bb:free()
            write(dir .. "/luajit", table.concat({
                "#!/bin/sh",
                "[ \"$1\" = -e ] && exit 0",
                "n=$(cat \"$KO_HOME/count\" 2>/dev/null || echo 0); n=$((n + 1)); echo $n > \"$KO_HOME/count\"",
                "echo \"$n shot=${KOPANDA_SHOT:+set} cap=${KOPANDA_SHOT_CAP_S:-} fake=${KOPANDA_FAKE:-}\" >> '"
                    .. dir .. "/starts'",
                "if [ -n \"$KOPANDA_SHOT\" ]; then cp '" .. dir .. "/tiny.png' \"$KOPANDA_SHOT\"; "
                    .. "echo '{\"plugins\":[\"probe\"]}' > \"$KOPANDA_SHOT.json\"; fi",
                "exit ${KOPANDA_FAKE_STATUS:-0}",
                "",
            }, "\n"), true)
            return dir
        end

        local function extra_plugin(name)
            local dir = fresh_dir("extra") .. "/" .. name .. ".koplugin"
            assert(lfs.mkdir(dir))
            write(dir .. "/_meta.lua", "return { name = \"" .. name .. "\" }\n")
            write(dir .. "/main.lua", "return {}\n")
            return dir
        end

        local function run(opts)
            opts.profile = opts.profile or "colorsoft"
            opts.plugin_dir = opts.plugin_dir or probe
            opts.library_dir = opts.library_dir or fresh_dir("lib")
            opts.out_dir = opts.out_dir or fresh_dir("out")
            return opts, driver.run_starts(opts)
        end

        it("writes the profile once with the default disabled list and copies extra_plugins", function()
            local emu = counting_emulator()
            local extra = extra_plugin("ennui")
            local opts, result = run{ emulator_dir = emu, extra_plugins = { extra },
                starts = { { env = { KOPANDA_FAKE = "one" } }, { env = { KOPANDA_FAKE = "two" } } } }
            assert.equals(opts.out_dir .. "/profile-colorsoft", result.scratch)
            assert.same({ "1 shot= cap= fake=one", "2 shot= cap= fake=two" }, lines(emu .. "/starts"))
            assert.equals(0, result.starts[1].status)
            assert.equals(0, result.starts[2].status)
            local settings = dofile(result.scratch .. "/settings.reader.lua")
            local disabled = {}
            for name in pairs(settings.plugins_disabled) do
                disabled[#disabled + 1] = name
            end
            table.sort(disabled)
            assert.same({ "bookshelf", "ennUI", "simpleui", "solariconpack" }, disabled)
            assert.equals("return {}\n", read(result.scratch .. "/plugins/ennui.koplugin/main.lua"))
            assert.equals("file", lfs.attributes(result.scratch .. "/plugins/probe.koplugin/main.lua", "mode"))
        end)

        it("sets KOPANDA_SHOT only for a shot start and returns its PNG and sidecar", function()
            local emu = counting_emulator()
            local _, result = run{ emulator_dir = emu,
                starts = { { env = { KOPANDA_FAKE = "plain" } }, { shot = true, cap_s = 15 } } }
            assert.same({ "1 shot= cap= fake=plain", "2 shot=set cap=15 fake=" }, lines(emu .. "/starts"))
            assert.is_nil(result.starts[1].png)
            assert.equals("file", lfs.attributes(result.starts[2].png, "mode"))
            assert.same({ "probe" }, result.starts[2].sidecar.plugins)
            assert.equals("file", lfs.attributes(result.starts[2].log, "mode"))
        end)

        it("runs a start's after with its result and the scratch before the next start", function()
            local emu = counting_emulator()
            local seen = {}
            local function after(start_result, scratch)
                seen[#seen + 1] = { status = start_result.status, count = read(scratch .. "/count"):match("%d+") }
            end
            run{ emulator_dir = emu, starts = {
                { env = { KOPANDA_FAKE_STATUS = "85" }, accept = { 85 }, after = after },
                { after = after },
            } }
            assert.same({ { status = 85, count = "1" }, { status = 0, count = "2" } }, seen)
        end)

        it("refuses an extra plugin the emulator's plugins/ also holds, before any start", function()
            local emu = counting_emulator()
            assert(lfs.mkdir(emu .. "/plugins/ennui.koplugin"))
            local out = fresh_dir("out")
            local ok, err = pcall(run, { emulator_dir = emu, out_dir = out, extra_plugins = { extra_plugin("ennui") },
                starts = { {} } })
            assert.is_false(ok)
            assert.truthy(contains(tostring(err), emu .. "/plugins/ennui.koplugin"), err)
            assert.is_nil(lfs.attributes(emu .. "/starts", "mode"))
            assert.is_nil(lfs.attributes(out .. "/profile-colorsoft", "mode"))
        end)

        it("refuses a status outside a start's accept list, naming the start, and keeps the scratch", function()
            local emu = counting_emulator()
            local out = fresh_dir("out")
            local ok, err = pcall(run, { emulator_dir = emu, out_dir = out, starts = {
                { env = { KOPANDA_FAKE_STATUS = "85" }, accept = { 85 } },
                { env = { KOPANDA_FAKE_STATUS = "7" } },
            } })
            assert.is_false(ok)
            err = tostring(err)
            assert.truthy(contains(err, "start 2"), err)
            assert.truthy(contains(err, "status 7"), err)
            assert.equals("directory", lfs.attributes(out .. "/profile-colorsoft", "mode"))
            assert.equals("2", read(out .. "/profile-colorsoft/count"):match("%d+"))
        end)

        -- The real emulator: a scenario patch quits with the status KOPANDA_TEST_QUIT names, so
        -- the first start ends as a restart does (85) and the second, without it, is shot.
        it("runs the probe across starts on the emulator, a scenario quitting 85 before the shot", function()
            local patch = fresh_dir("patches") .. "/2-quit.lua"
            write(patch, table.concat({
                "local code = tonumber(os.getenv(\"KOPANDA_TEST_QUIT\"))",
                "if code then",
                "    local UIManager = require(\"ui/uimanager\")",
                "    UIManager:scheduleIn(0.5, function() UIManager:quit(code) end)",
                "end",
                "",
            }, "\n"))
            local _, result = run{ patches = { patch }, starts = {
                { env = { KOPANDA_TEST_QUIT = "85" }, accept = { 85 } },
                { shot = true },
            } }
            assert.equals(85, result.starts[1].status)
            assert.is_nil(result.starts[1].png)
            assert.equals(0, result.starts[2].status)
            assert.equals("home", result.starts[2].sidecar.screen)
            local loaded = {}
            for _, name in ipairs(result.starts[2].sidecar.plugins) do
                loaded[name] = true
            end
            assert.is_true(loaded.probe)
            assert.equals(1264, (driver.png_size(result.starts[2].png)))
            assert.equals("directory", lfs.attributes(result.scratch, "mode"))
        end)
    end)
end)
