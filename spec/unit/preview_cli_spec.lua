-- bin/preview's refusals and plumbing (C4), against a fake emulator directory whose luajit is a
-- shell script: it records the KO_HOME it was given, prints chatter on stdout as KOReader's
-- library loader does, and either writes the PNG and the JSON line or fails with a message and
-- two log lines. No real emulator runs; spec/emulator/preview_spec.lua renders for real.
describe("bin/preview", function()
    local lfs = require("libs/libkoreader-lfs")
    local root = os.getenv("KOPANDA_ROOT")

    local scratch

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
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

    local function entries(dir)
        local names = {}
        for name in lfs.dir(dir) do
            if name ~= "." and name ~= ".." then
                names[#names + 1] = name
            end
        end
        return names
    end

    -- A fake emulator directory: its luajit runs as `luajit bin/preview.lua <args>`, so the
    -- output PNG is $8. FAKE_MODE (success or failure) and FAKE_RECORD reach it through the
    -- environment bin/preview passes on.
    local function fake_emulator()
        local dir = scratch .. "/emulator"
        assert(lfs.mkdir(dir))
        write(dir .. "/luajit", table.concat({
            "#!/bin/sh",
            'printf "%s\\n" "$KO_HOME" > "$FAKE_RECORD"',
            'echo "ffi.load: chatter on stdout"',
            'if [ "$FAKE_MODE" = success ]; then',
            '    printf "PNG" > "$8"',
            '    printf "%s\\n" "{\\"png\\":\\"$8\\",\\"width\\":1264,\\"height\\":1680,\\"paint_ms\\":12}"'
                .. ' > "$KO_HOME/result.json"',
            "    exit 0",
            "fi",
            'printf "%s\\n" "capture preview: boom" "log line one" "log line two" >&2',
            "exit 1",
            "",
        }, "\n"))
        assert.equals(0, os.execute("chmod +x '" .. dir .. "/luajit'"))
        return dir
    end

    -- Runs bin/preview with args from the repo root, TMPDIR a directory of this spec's own (so
    -- the scratch KO_HOME the script makes lands there), and env (NAME=value words) before it.
    -- Returns stdout, stderr and the exit status.
    local function run(args, env)
        local stdout, stderr = scratch .. "/stdout", scratch .. "/stderr"
        local command = string.format("cd '%s' && TMPDIR='%s' FAKE_RECORD='%s' %s bin/preview %s > '%s' 2> '%s'",
            root, scratch .. "/tmp", scratch .. "/record", env or "", args, stdout, stderr)
        local quoted = command:gsub("'", "'\\''")
        local pipe = assert(io.popen("sh -c '" .. quoted .. "'; echo $?"))
        local status = tonumber(pipe:read("*a"):match("(%d+)%s*$"))
        pipe:close()
        return read(stdout), read(stderr), status
    end

    before_each(function()
        scratch = os.tmpname()
        os.remove(scratch)
        assert.equals(0, os.execute("mkdir -p '" .. scratch .. "/tmp'"))
    end)

    after_each(function()
        os.execute("rm -rf '" .. scratch .. "'")
    end)

    it("refuses with exit 2 and its usage, running nothing, for each bad argument list", function()
        local emulator = fake_emulator()
        local settings = scratch .. "/settings.lua"
        write(settings, "return {}\n")
        local out = scratch .. "/out.png"
        local refused = {
            "",
            "1264 1680 300 color diner day",
            "1264 1680 300 color diner day '" .. out .. "' '" .. settings .. "' extra",
            "0 1680 300 color diner day '" .. out .. "'",
            "1264 12a 300 color diner day '" .. out .. "'",
            "1264 1680 0 color diner day '" .. out .. "'",
            "1264 1680 300 colour diner day '" .. out .. "'",
            "1264 1680 300 color Diner day '" .. out .. "'",
            "1264 1680 300 color 9look day '" .. out .. "'",
            "1264 1680 300 color di-ner day '" .. out .. "'",
            "1264 1680 300 color '' day '" .. out .. "'",
            "1264 1680 300 color diner dusk '" .. out .. "'",
            "1264 1680 300 color diner day '" .. out .. "' '" .. scratch .. "/missing.lua'",
            "1264 1680 300 color diner day '" .. out .. "' '" .. scratch .. "'",
        }
        for _, args in ipairs(refused) do
            local stdout, stderr, status = run(args, "KOPANDA_EMULATOR='" .. emulator .. "' FAKE_MODE=success")
            assert.equals(2, status, args)
            assert.equals("", stdout, args)
            assert.truthy(stderr:find("usage: bin/preview <width> <height> <dpi> <color|grey> <look>"
                .. " <day|night> <out.png> [settings file]", 1, true), args .. ": " .. stderr)
            assert.is_nil(read(scratch .. "/record"), args .. ": the emulator ran")
        end
    end)

    -- Which ids are looks is the plugin's to say (spec/emulator/preview_spec.lua runs one that
    -- isn't); the script passes any id-shaped look on.
    it("passes on any look id, a look it has never heard of included", function()
        local emulator = fake_emulator()
        for _, look in ipairs({ "riso", "frosted_2" }) do
            os.remove(scratch .. "/record")
            local _, stderr, status = run("1264 1680 300 color " .. look .. " day '" .. scratch .. "/out.png'",
                "KOPANDA_EMULATOR='" .. emulator .. "' FAKE_MODE=success")
            assert.equals(0, status, look .. ": " .. stderr)
            assert.is_not_nil(read(scratch .. "/record"), look .. ": the emulator did not run")
        end
    end)

    it("refuses with exit 2 naming the path when there is no luajit at KOPANDA_EMULATOR", function()
        local stdout, stderr, status = run("1264 1680 300 color diner day '" .. scratch .. "/out.png'",
            "KOPANDA_EMULATOR=/nonexistent")
        assert.equals(2, status)
        assert.equals("", stdout)
        assert.truthy(stderr:find("/nonexistent/luajit", 1, true), stderr)
    end)

    it("prints the script's JSON line alone on success, the emulator's stdout dropped", function()
        local emulator = fake_emulator()
        local out = scratch .. "/out.png"
        local stdout, stderr, status = run("1264 1680 300 grey editorial night '" .. out .. "'",
            "KOPANDA_EMULATOR='" .. emulator .. "' FAKE_MODE=success")
        assert.equals(0, status, stderr)
        assert.equals('{"png":"' .. out .. '","width":1264,"height":1680,"paint_ms":12}\n', stdout)
        assert.equals("", stderr)
        assert.equals("PNG", read(out))
    end)

    it("makes a relative out path absolute against the caller's directory", function()
        local emulator = fake_emulator()
        local caller = scratch .. "/caller"
        assert(lfs.mkdir(caller))
        local stdout, stderr = scratch .. "/stdout", scratch .. "/stderr"
        local command = string.format("cd '%s' && TMPDIR='%s' FAKE_RECORD='%s' KOPANDA_EMULATOR='%s' FAKE_MODE=success"
            .. " '%s/bin/preview' 1264 1680 300 color diner day out.png > '%s' 2> '%s'",
            caller, scratch .. "/tmp", scratch .. "/record", emulator, root, stdout, stderr)
        local quoted = command:gsub("'", "'\\''")
        local pipe = assert(io.popen("sh -c '" .. quoted .. "'; echo $?"))
        local status = tonumber(pipe:read("*a"):match("(%d+)%s*$"))
        pipe:close()
        assert.equals(0, status, read(stderr))
        -- Both directories by their physical path: os.tmpname's /tmp is /private/tmp on macOS.
        local function physical(dir)
            local resolve = assert(io.popen("cd '" .. dir .. "' 2>/dev/null && pwd -P"))
            local path = resolve:read("*l")
            resolve:close()
            return path
        end
        local png = read(stdout):match('^{"png":"([^"]*)"')
        local png_dir = png and png:match("^(/.*)/out%.png$")
        assert.truthy(png_dir, png)
        assert.equals(physical(caller), physical(png_dir))
        assert.equals("PNG", read(caller .. "/out.png"))
    end)

    it("copies the settings file into the scratch KO_HOME the script runs under", function()
        local emulator = fake_emulator()
        write(emulator .. "/luajit", table.concat({
            "#!/bin/sh",
            'cat "$KO_HOME/settings/kopanda/settings.lua" >&2',
            "exit 1",
            "",
        }, "\n"))
        local settings = scratch .. "/settings.lua"
        local text = 'return { ["text_size"] = "large" }\n'
        write(settings, text)
        local _, stderr, status = run("1264 1680 300 color diner day '" .. scratch .. "/out.png' '" .. settings .. "'",
            "KOPANDA_EMULATOR='" .. emulator .. "'")
        assert.equals(1, status)
        assert.equals(text, stderr)
    end)

    it("exits 1 with the failure's message and log lines on stderr and nothing on stdout", function()
        local emulator = fake_emulator()
        local stdout, stderr, status = run("1264 1680 300 color diner day '" .. scratch .. "/out.png'",
            "KOPANDA_EMULATOR='" .. emulator .. "' FAKE_MODE=failure")
        assert.equals(1, status)
        assert.equals("", stdout)
        assert.equals("capture preview: boom\nlog line one\nlog line two\n", stderr)
    end)

    it("removes its scratch directory on success and on failure", function()
        local emulator = fake_emulator()
        for _, mode in ipairs({ "success", "failure" }) do
            os.remove(scratch .. "/record")
            run("1264 1680 300 color diner day '" .. scratch .. "/out.png'",
                "KOPANDA_EMULATOR='" .. emulator .. "' FAKE_MODE=" .. mode)
            local ko_home = assert(read(scratch .. "/record"), mode .. ": the emulator did not run"):gsub("\n$", "")
            assert.truthy(ko_home:find(scratch .. "/tmp/", 1, true), ko_home)
            assert.is_nil(lfs.attributes(ko_home, "mode"), mode .. ": " .. ko_home .. " is left")
            assert.same({}, entries(scratch .. "/tmp"), mode)
        end
    end)
end)
