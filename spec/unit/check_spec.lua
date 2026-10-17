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

    local function line_count(text)
        return select(2, text:gsub("\n", ""))
    end

    -- A scratch checkout holding only bin/, .luacheckrc, the spec helper and
    -- environment_spec.lua under both spec layers, so a full run stays small.
    local function small_checkout()
        local copy = run("mktemp -d"):gsub("\n$", "")
        local _, setup = run("cp -R '" .. root .. "/bin' '" .. root .. "/.luacheckrc' '" .. copy .. "'"
            .. " && mkdir -p '" .. copy .. "/spec/unit' '" .. copy .. "/spec/emulator'"
            .. " && cp '" .. root .. "/spec/helper.lua' '" .. copy .. "/spec/'"
            .. " && cp '" .. root .. "/spec/unit/environment_spec.lua' '" .. copy .. "/spec/unit/'"
            .. " && cp '" .. root .. "/spec/unit/environment_spec.lua' '" .. copy .. "/spec/emulator/'")
        assert.equals(0, setup)
        return copy
    end

    -- Gives a scratch checkout a studio/ whose `check` script runs `script`
    -- instead of the real typecheck, lint and tests, with an empty node_modules/
    -- unless `installed` is false.
    local function fake_studio(copy, script, installed)
        local package_json = '{"name": "fake-studio", "private": true, "scripts": {"check": "' .. script .. '"}}'
        local _, setup = run("mkdir -p '" .. copy .. "/studio' && printf '%s\\n' '" .. package_json
            .. "' > '" .. copy .. "/studio/package.json'"
            .. (installed == false and "" or " && mkdir '" .. copy .. "/studio/node_modules'"))
        assert.equals(0, setup)
    end

    -- Environment assignments for a PATH of /usr/bin:/bin plus a directory
    -- holding only a link to luacheck, so it finds luacheck but no node; and the
    -- directory, for removal. Homebrew's bin/ holds a node, so instead of brew
    -- on PATH, KO_DYLD_PREFIX gives KOReader's ffi/loadlib.lua:150-152 the
    -- prefix it otherwise asks `brew --prefix` for.
    local function nodeless_env()
        local dir = run("mktemp -d"):gsub("\n$", "")
        local luacheck = run("command -v luacheck"):gsub("\n$", "")
        local prefix = run("brew --prefix"):gsub("\n$", "")
        local _, setup = run("ln -s '" .. luacheck .. "' '" .. dir .. "/luacheck'")
        assert.equals(0, setup)
        return "PATH='" .. dir .. ":/usr/bin:/bin' KO_DYLD_PREFIX='" .. prefix .. "'", dir
    end

    it("prints one summary line per stage on a green run, without per-test lines or library chatter", function()
        local copy = small_checkout()
        fake_studio(copy, "echo studio-check-passed")
        local output, status = run("'" .. copy .. "/bin/check'")
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, status, output)
        assert.is_true(line_count(output) < 20, output)
        assert.truthy(output:find("\n== lint: luacheck\nTotal: 0 warnings / 0 errors in %d+ files\n== studio\n"),
            output)
        assert.truthy(output:find("\n== studio\n.*studio%-check%-passed\n.*== unit\n"), output)
        local layer = "%[==========%] 7 tests from 1 test file ran%.[^\n]*\n%[  PASSED  %] 7 tests%.\n"
        assert.truthy(output:find("\n== unit\n" .. layer .. "== emulator\n" .. layer .. "$"), output)
        assert.falsy(contains(output, "ffi.findlib"))
        assert.falsy(contains(output, "[ RUN"))
        assert.falsy(contains(output, "[       OK ]"))
        assert.falsy(contains(output, "environment_spec.lua"))
    end)

    it("names each file with a failing test and prints Busted's failure block in full", function()
        local output, status = run("cd '" .. root .. "' && bin/check spec/fixtures/failing_spec.lua"
            .. " spec/unit/environment_spec.lua")
        assert.equals(1, status)
        assert.truthy(contains(output, "\n[  FAILED  ] in spec/fixtures/failing_spec.lua\n"), output)
        assert.truthy(contains(output, "failing_spec.lua:3: Expected objects to be equal.\nPassed in:\n(number) 2\n"
            .. "Expected:\n(number) 1\n"), output)
        assert.truthy(contains(output, "failing_spec.lua:7: Expected objects to be the same."), output)
        assert.falsy(contains(output, "environment_spec.lua"))
        assert.falsy(contains(output, "[ RUN"))
        assert.falsy(contains(output, "ffi.findlib"))
    end)

    it("prints the error of a spec file that does not load", function()
        local dir = run("mktemp -d"):gsub("\n$", "")
        local _, setup = run("printf 'this is not lua(\\n' > '" .. dir .. "/unloadable_spec.lua'")
        assert.equals(0, setup)
        local output, status = run("'" .. check .. "' '" .. dir .. "/unloadable_spec.lua'")
        run("rm -rf '" .. dir .. "'")
        assert.equals(1, status)
        assert.truthy(contains(output, "unloadable_spec.lua:1: '=' expected near 'is'"), output)
        assert.falsy(contains(output, "has monolibtic"), output)
    end)

    it("names the file and the test, and prints the test's output, when a test ends the process", function()
        local dir = run("mktemp -d"):gsub("\n$", "")
        local _, setup = run("printf '%s\\n' 'describe(\"scratch\", function()'"
            .. " '    it(\"dies\", function() print(\"last words\"); os.exit(3) end)' 'end)'"
            .. " > '" .. dir .. "/exiting_spec.lua'")
        assert.equals(0, setup)
        local output, status = run("'" .. check .. "' '" .. dir .. "/exiting_spec.lua'")
        run("rm -rf '" .. dir .. "'")
        assert.equals(1, status, output)
        assert.truthy(contains(output, "[  FAILED  ] in "), output)
        assert.truthy(contains(output, "last words"), output)
        assert.truthy(output:find("scratch dies\n"), output)
        assert.falsy(contains(output, "has monolibtic"), output)
    end)

    it("keeps a passing test's [  NOTE    ] lines and drops the rest of its output", function()
        local dir = run("mktemp -d"):gsub("\n$", "")
        local _, setup = run("printf '%s\\n' 'describe(\"scratch\", function()'"
            .. " '    it(\"notes\", function() print(\"chatter\"); print(\"[  NOTE    ] wall time not judged\") end)'"
            .. " 'end)' > '" .. dir .. "/noting_spec.lua'")
        assert.equals(0, setup)
        local output, status = run("'" .. check .. "' '" .. dir .. "/noting_spec.lua'")
        run("rm -rf '" .. dir .. "'")
        assert.equals(0, status, output)
        assert.truthy(contains(output, "\n[  NOTE    ] wall time not judged\n"), output)
        assert.falsy(contains(output, "chatter"), output)
        assert.falsy(contains(output, "[  FAILED  ]"), output)
    end)

    it("prints Busted's per-test lines and KOReader's library chatter with --verbose", function()
        local output, status = run("cd '" .. root .. "' && bin/check --verbose spec/unit/environment_spec.lua")
        assert.equals(0, status, output)
        assert.truthy(contains(output, "ffi.findlib"))
        assert.truthy(contains(output, "[----------] Running tests from " .. root .. "/spec/unit/environment_spec.lua"))
        assert.truthy(contains(output, "[ RUN      ]"))
        assert.truthy(contains(output, "[       OK ]"))
    end)

    it("lists every file luacheck checked with --verbose after --lint, and only the total without it", function()
        local copy = small_checkout()
        local verbose, verbose_status = run("'" .. copy .. "/bin/check' --lint --verbose")
        local quiet, quiet_status = run("'" .. copy .. "/bin/check' --lint")
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, verbose_status, verbose)
        assert.equals(0, quiet_status, quiet)
        assert.truthy(contains(verbose, "Checking"), verbose)
        assert.falsy(contains(quiet, "Checking"), quiet)
        assert.falsy(contains(quiet, "\27"), quiet)
    end)

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

    it("refuses with exit 2 when a named spec file does not exist, naming it", function()
        local output, status = run("cd '" .. root .. "' && bin/check spec/unit/nope_spec.lua")
        assert.equals(2, status)
        assert.truthy(contains(output, "nope_spec.lua"))
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

    it("runs the studio's check between lint and the unit specs, and exits 1 when it fails", function()
        local copy = small_checkout()
        fake_studio(copy, "echo studio-check-failed; exit 1")
        local output, status = run("'" .. copy .. "/bin/check'")
        run("rm -rf '" .. copy .. "'")
        assert.equals(1, status, output)
        assert.truthy(output:find("\n== lint: luacheck\n.*\n== studio\n.*studio%-check%-failed"), output)
        assert.falsy(contains(output, "== unit"), output)
    end)

    it("refuses with exit 2 when studio/node_modules is missing, naming npm ci", function()
        local copy = small_checkout()
        fake_studio(copy, "echo studio-check-ran", false)
        local output, status = run("'" .. copy .. "/bin/check'")
        run("rm -rf '" .. copy .. "'")
        assert.equals(2, status, output)
        assert.truthy(contains(output, "npm ci --prefix studio"), output)
        assert.falsy(contains(output, "brew install node"), output)
        assert.falsy(contains(output, "studio-check-ran"), output)
        assert.falsy(contains(output, "== lint"), output)
    end)

    it("refuses with exit 2 when node is not on PATH, naming brew and npm ci", function()
        local copy = small_checkout()
        fake_studio(copy, "echo studio-check-ran")
        local env, dir = nodeless_env()
        local output, status = run(env .. " '" .. copy .. "/bin/check'")
        run("rm -rf '" .. copy .. "' '" .. dir .. "'")
        assert.equals(2, status, output)
        assert.truthy(contains(output, "brew install node"), output)
        assert.truthy(contains(output, "npm ci --prefix studio"), output)
        assert.falsy(contains(output, "== lint"), output)
    end)

    -- A small checkout whose emulator layer holds a spec that fails, so a run
    -- that reaches spec/emulator/ says so.
    local function failing_emulator_checkout()
        local copy = small_checkout()
        local _, setup = run("cp '" .. root .. "/spec/fixtures/failing_spec.lua' '" .. copy .. "/spec/emulator/'")
        assert.equals(0, setup)
        return copy
    end

    it("runs lint, the studio and the unit specs with --unit, and no emulator spec", function()
        local copy = failing_emulator_checkout()
        fake_studio(copy, "echo studio-check-passed")
        local output, status = run("'" .. copy .. "/bin/check' --unit")
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, status, output)
        assert.truthy(output:find("\n== lint: luacheck\nTotal: 0 warnings / 0 errors in %d+ files\n== studio\n"),
            output)
        assert.truthy(output:find("\n== studio\n.*studio%-check%-passed\n.*== unit\n"), output)
        local layer = "%[==========%] 7 tests from 1 test file ran%.[^\n]*\n%[  PASSED  %] 7 tests%.\n"
        assert.truthy(output:find("\n== unit\n" .. layer .. "$"), output)
        assert.falsy(contains(output, "== emulator"), output)
        assert.falsy(contains(output, "failing_spec.lua"), output)
    end)

    it("exits 1 with --unit when a unit spec fails, naming the file", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        local _, setup = run("cp '" .. root .. "/spec/fixtures/failing_spec.lua' '" .. copy .. "/spec/unit/'")
        assert.equals(0, setup)
        local output, status = run("'" .. copy .. "/bin/check' --unit")
        run("rm -rf '" .. copy .. "'")
        assert.equals(1, status, output)
        assert.truthy(contains(output, "[  FAILED  ] in spec/unit/failing_spec.lua"), output)
    end)

    it("stops --unit at a failing studio check, before the unit specs", function()
        local copy = small_checkout()
        fake_studio(copy, "echo studio-check-failed; exit 1")
        local output, status = run("'" .. copy .. "/bin/check' --unit")
        run("rm -rf '" .. copy .. "'")
        assert.equals(1, status, output)
        assert.truthy(output:find("\n== lint: luacheck\n.*\n== studio\n.*studio%-check%-failed"), output)
        assert.falsy(contains(output, "== unit"), output)
    end)

    it("prints luacheck's per-file lines and Busted's per-test lines with --unit --verbose", function()
        local copy = failing_emulator_checkout()
        fake_studio(copy, "true")
        local output, status = run("'" .. copy .. "/bin/check' --unit --verbose")
        local reversed, reversed_status = run("'" .. copy .. "/bin/check' --verbose --unit")
        run("rm -rf '" .. copy .. "'")
        for _, pair in ipairs({ { output, status }, { reversed, reversed_status } }) do
            local out, st = pair[1], pair[2]
            assert.equals(0, st, out)
            assert.truthy(contains(out, "Checking"), out)
            assert.truthy(contains(out, "[ RUN      ]"), out)
            assert.falsy(contains(out, "== emulator"), out)
            assert.falsy(contains(out, "fails on purpose"), out)
        end
    end)

    it("refuses --unit with exit 2 when studio/node_modules is missing, naming npm ci", function()
        local copy = small_checkout()
        fake_studio(copy, "echo studio-check-ran", false)
        local output, status = run("'" .. copy .. "/bin/check' --unit")
        run("rm -rf '" .. copy .. "'")
        assert.equals(2, status, output)
        assert.truthy(contains(output, "npm ci --prefix studio"), output)
        assert.falsy(contains(output, "studio-check-ran"), output)
        assert.falsy(contains(output, "== lint"), output)
    end)

    it("refuses --unit with exit 2 when node is not on PATH, naming brew and npm ci", function()
        local copy = small_checkout()
        fake_studio(copy, "echo studio-check-ran")
        local env, dir = nodeless_env()
        local output, status = run(env .. " '" .. copy .. "/bin/check' --unit")
        run("rm -rf '" .. copy .. "' '" .. dir .. "'")
        assert.equals(2, status, output)
        assert.truthy(contains(output, "brew install node"), output)
        assert.falsy(contains(output, "== lint"), output)
    end)

    it("refuses --unit with exit 2 when luacheck is missing, naming the brew command", function()
        local output, status = run("PATH=/usr/bin:/bin '" .. check .. "' --unit")
        assert.equals(2, status, output)
        assert.truthy(contains(output, "brew install luacheck"), output)
    end)

    it("does not lint Lua files under studio/node_modules or studio/dist", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        local _, setup = run("mkdir -p '" .. copy .. "/studio/node_modules/pkg' '" .. copy .. "/studio/dist'"
            .. " && cp '" .. root .. "/spec/fixtures/lint-warning.lua' '" .. copy .. "/studio/node_modules/pkg/'"
            .. " && cp '" .. root .. "/spec/fixtures/lint-warning.lua' '" .. copy .. "/studio/dist/'")
        assert.equals(0, setup)
        local output, status = run("'" .. copy .. "/bin/check' --lint")
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, status, output)
        assert.falsy(contains(output, "lint-warning.lua"), output)
    end)

    it("runs named specs without node on PATH and without studio/", function()
        local copy = small_checkout()
        local env, dir = nodeless_env()
        local output, status = run("cd '" .. copy .. "' && " .. env .. " '" .. copy
            .. "/bin/check' spec/unit/environment_spec.lua")
        run("rm -rf '" .. copy .. "' '" .. dir .. "'")
        assert.equals(0, status, output)
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
