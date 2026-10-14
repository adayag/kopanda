describe("bin/check", function()
    local lfs = require("libs/libkoreader-lfs")
    local root = os.getenv("KOPANDA_ROOT")
    local check = root .. "/bin/check"

    -- Runs a shell command, returning its combined output and exit status. The
    -- status is read from the output rather than from io.popen's close(), whose
    -- return values differ across LuaJIT platforms.
    local function run(command)
        local quoted = command:gsub("'", "'\\''")
        local pipe = assert(io.popen("sh -c '" .. quoted .. "' 2>&1; s=$?; echo; echo $s"))
        local output = pipe:read("*a")
        pipe:close()
        local body, status = output:match("^(.*)\n(%d+)\n$")
        return body, tonumber(status)
    end

    local function contains(text, needle)
        return text:find(needle, 1, true) ~= nil
    end

    -- The KO_HOME an inner bin/check announced on its first output line.
    local function inner_ko_home(output)
        return output:match("KOPANDA_KO_HOME=([^\n]+)\n")
    end

    it("exits 1 on a spec with failing tests and names each failing test", function()
        local output, status = run("cd '" .. root .. "' && bin/check spec/fixtures/failing_spec.lua")
        assert.equals(1, status)
        assert.truthy(contains(output, "fails on purpose the first time"))
        assert.truthy(contains(output, "fails on purpose the second time"))
        assert.is_nil(lfs.attributes(inner_ko_home(output), "mode"))
    end)

    it("runs only the named specs, without luacheck, and removes its KO_HOME afterwards", function()
        local output, status = run("cd '" .. root .. "' && bin/check spec/unit/environment_spec.lua")
        assert.equals(0, status)
        assert.falsy(contains(output, "luacheck"))
        local inner_home = inner_ko_home(output)
        assert.is_string(inner_home)
        assert.not_equals(os.getenv("KO_HOME"), inner_home)
        assert.is_nil(lfs.attributes(inner_home, "mode"))
        assert.equals("directory", lfs.attributes(os.getenv("KO_HOME"), "mode"))
    end)

    it("refuses with exit 2 when the emulator is missing, naming the path", function()
        local output, status = run("KOPANDA_EMULATOR=/nonexistent '" .. check .. "' --lint")
        assert.equals(2, status)
        assert.truthy(contains(output, "/nonexistent"))
    end)

    it("refuses with exit 2 when luacheck is missing, naming the brew command", function()
        local output, status = run("PATH=/usr/bin:/bin '" .. check .. "' --lint")
        assert.equals(2, status)
        assert.truthy(contains(output, "brew install luacheck"))
    end)

    it("fails the lint stage with exit 1 on a warning, naming the file", function()
        local copy = run("mktemp -d"):gsub("\n$", "")
        local _, setup = run("cp -R '" .. root .. "/bin' '" .. root .. "/spec' '" .. root .. "/.luacheckrc' '" .. copy
            .. "' && mv '" .. copy .. "/spec/fixtures/lint-warning.lua' '" .. copy .. "/spec/unit/'")
        assert.equals(0, setup)
        local output, status = run("'" .. copy .. "/bin/check' --lint")
        run("rm -rf '" .. copy .. "'")
        assert.equals(1, status)
        assert.truthy(contains(output, "lint-warning.lua"))
    end)

    it("runs from a checkout whose path contains a space", function()
        local copy = run("mktemp -d"):gsub("\n$", "") .. "/with space"
        local _, setup = run("mkdir '" .. copy .. "' && cp -R '" .. root .. "/bin' '" .. root .. "/spec' '"
            .. root .. "/.luacheckrc' '" .. copy .. "'")
        assert.equals(0, setup)
        local output, status = run("cd '" .. copy .. "' && '" .. copy .. "/bin/check' spec/unit/environment_spec.lua")
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, status, output)
    end)
end)
