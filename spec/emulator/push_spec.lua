-- A pull end to end on the emulator, over several starts of one scratch KO_HOME: the first
-- start pulls a bundle from push_server.lua through the plugin's own pull code (the push-pull
-- scenario) and restarts; the next applies it before any plugin loads (patches/1-kopanda-apply.lua),
-- and a home that never draws is rolled back at the start after. The notices scenario writes
-- each InfoMessage shown to a file, so the spec reads what the owner would have seen.
describe("pulling from the studio on the emulator", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local driver = require("emulator.driver")
    local push_bundles = require("emulator.push_bundles")
    local root = os.getenv("KOPANDA_ROOT")
    local emulator = os.getenv("KOPANDA_EMULATOR")
    local ko_home = os.getenv("KO_HOME")
    local plugin = root .. "/kopanda.koplugin"
    local scenarios = {
        root .. "/spec/emulator/scenarios/2-scenario-notices.lua",
        root .. "/spec/emulator/scenarios/2-scenario-push-pull.lua",
    }
    local ennui = root .. "/spec/fixtures/push/shells/ennui.koplugin"
    local PROFILE = "colorsoft"
    -- The server's idle bound: it exits after this long with no request, should a spec die
    -- before its finally kills it.
    local SERVER_LIFETIME_S = 120
    local SETTINGS = "-- settings/kopanda/settings.lua\nreturn {\n    [\"look\"] = \"editorial\",\n}\n"

    local counter = 0
    local function fresh_dir(name)
        counter = counter + 1
        local dir = string.format("%s/push-spec-%s-%d", ko_home, name, counter)
        assert(lfs.mkdir(dir))
        return dir
    end

    local function quote(s)
        return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
    end

    local function read(path)
        local f = io.open(path, "rb")
        if not f then
            return nil
        end
        local text = f:read("*a")
        f:close()
        return text
    end

    local function last_line(path)
        local last
        for line in assert(io.open(path)):lines() do
            last = line
        end
        return last
    end

    local function mode(path)
        return lfs.attributes(path, "mode")
    end

    -- Starts push_server.lua in its own process (Busted blocks while the emulator runs) and
    -- waits for the port it bound. Returns { port, pid, log }.
    local function start_server(serve_root)
        local dir = fresh_dir("server")
        local port_file, pid_file, log = dir .. "/port", dir .. "/pid", dir .. "/server.log"
        local command = table.concat({
            "cd " .. quote(emulator) .. " || exit 1",
            "env LUA_PATH='?.lua;common/?.lua;frontend/?.lua' LUA_CPATH='?.so;common/?.so' ./luajit "
                .. quote(root .. "/spec/emulator/push_server.lua") .. " " .. quote(serve_root) .. " "
                .. quote(port_file) .. " " .. SERVER_LIFETIME_S .. " > " .. quote(log) .. " 2>&1 &",
            "echo $! > " .. quote(pid_file),
        }, "\n")
        assert.equals(0, os.execute("sh -c " .. quote(command)))
        local pid = assert(tonumber(read(pid_file)), "no server pid")
        for _ = 1, 100 do
            local port = tonumber(read(port_file) or "")
            if port then
                return { port = port, pid = pid, log = log }
            end
            os.execute("sleep 0.1")
        end
        os.execute("kill " .. pid .. " 2>/dev/null")
        error("the push server wrote no port; its log:\n" .. tostring(read(log)))
    end

    local function stop_server(server)
        os.execute("kill " .. server.pid .. " 2>/dev/null")
    end

    local function pull_env(server, notices)
        return {
            KOPANDA_PUSH_ADDRESS = "127.0.0.1:" .. server.port,
            KOPANDA_PUSH_PROFILE = PROFILE,
            KOPANDA_NOTICES = notices,
        }
    end

    local function loaded(sidecar)
        local names = {}
        for _, name in ipairs(sidecar.plugins) do
            names[name] = true
        end
        return names
    end

    it("switches over: the pull turns ennui off, applies, and the home says what was pulled", function()
        local serve = fresh_dir("serve")
        local pushed = "pushed by push_spec\n"
        local manifest = push_bundles.write(serve, {
            id = PROFILE,
            plugin_dir = plugin,
            settings = SETTINGS,
            files = { ["pushed.txt"] = pushed },
        })
        local server = start_server(serve)
        finally(function()
            stop_server(server)
        end)
        local out = fresh_dir("switch")
        local notices = out .. "/notices.txt"
        local result = driver.run_starts{
            profile = PROFILE,
            plugin_dir = plugin,
            library_dir = fresh_dir("library"),
            out_dir = out,
            patches = scenarios,
            extra_plugins = { ennui },
            starts = {
                { env = pull_env(server, notices), accept = { 85 } },
                { shot = true, env = { KOPANDA_NOTICES = notices } },
            },
        }
        local scratch = result.scratch
        local push = scratch .. "/settings/kopanda/push"

        local plugins = loaded(result.starts[2].sidecar)
        assert.is_true(plugins.kopanda)
        assert.is_nil(plugins.ennui)
        local disabled = dofile(scratch .. "/settings.reader.lua").plugins_disabled
        assert.is_true(disabled.ennui)
        for _, name in ipairs(driver.disabled_plugins) do
            assert.is_true(disabled[name], name)
        end

        assert.equals(pushed, read(scratch .. "/plugins/kopanda.koplugin/pushed.txt"))
        assert.equals("directory", mode(push .. "/rollback/plugin"))
        assert.equals("file", mode(push .. "/rollback/plugin/main.lua"))
        assert.is_nil(mode(push .. "/rollback/plugin/pushed.txt"))
        assert.equals(SETTINGS, read(scratch .. "/settings/kopanda/settings.lua"))
        assert.is_nil(mode(push .. "/probation.lua"))
        assert.is_nil(mode(push .. "/staged.lua"))
        assert.is_nil(mode(push .. "/result.lua"))
        assert.equals(string.format("KoPanda pulled %s from the studio (bundle %s).", PROFILE,
            manifest.hash:sub(1, 12)), last_line(notices))
        os.execute("rm -rf " .. quote(out))
    end)

    it("rolls back a pulled plugin whose home never draws, at the start after", function()
        local serve = fresh_dir("serve")
        push_bundles.write(serve, {
            id = PROFILE,
            plugin_dir = plugin,
            settings = SETTINGS,
            files = { ["main.lua"] = "error(\"kopanda-test: broken bundle\")\n" },
        })
        local server = start_server(serve)
        finally(function()
            stop_server(server)
        end)
        local out = fresh_dir("rollback")
        local notices = out .. "/notices.txt"
        local settings_path, push
        local settings_before
        local result = driver.run_starts{
            profile = PROFILE,
            plugin_dir = plugin,
            library_dir = fresh_dir("library"),
            out_dir = out,
            patches = scenarios,
            starts = {
                {
                    env = pull_env(server, notices),
                    accept = { 85 },
                    -- The pull stages; it never touches the settings file.
                    after = function(_, scratch)
                        settings_path = scratch .. "/settings/kopanda/settings.lua"
                        push = scratch .. "/settings/kopanda/push"
                        settings_before = read(settings_path)
                        assert.equals("file", mode(push .. "/staged.lua"))
                    end,
                },
                {
                    -- KoPanda doesn't load, so no home settles: the capture patch's cap ends it.
                    shot = true,
                    cap_s = 15,
                    accept = { 3 },
                    env = { KOPANDA_NOTICES = notices },
                    after = function()
                        assert.equals("file", mode(push .. "/probation.lua"))
                    end,
                },
                { shot = true, env = { KOPANDA_NOTICES = notices } },
            },
        }
        local scratch = result.scratch

        assert.equals("home", result.starts[3].sidecar.screen)
        assert.is_true(loaded(result.starts[3].sidecar).kopanda)
        assert.equals(read(plugin .. "/main.lua"), read(scratch .. "/plugins/kopanda.koplugin/main.lua"))
        assert.equals(settings_before, read(settings_path))
        assert.is_nil(mode(settings_path .. ".old"))
        assert.is_nil(mode(push .. "/probation.lua"))
        assert.is_nil(mode(push .. "/rollback"))
        assert.equals(string.format("KoPanda's home didn't draw after the pull of %s, so the previous KoPanda "
            .. "and its settings are back.", PROFILE), last_line(notices))
        os.execute("rm -rf " .. quote(out))
    end)
end)
