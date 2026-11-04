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

    -- The output without its slowest-tests lines, for the tests that read what surrounds them.
    local function without_slowest(output)
        return (output:gsub("%[  SLOWEST %] [^\n]*\n", ""))
    end

    -- A scratch checkout holding only bin/, .luacheckrc, the spec helper and
    -- environment_spec.lua under both spec layers, so a full run stays small;
    -- at copy, an existing directory, when given.
    local function small_checkout(copy)
        copy = copy or run("mktemp -d"):gsub("\n$", "")
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

    -- Environment assignments for a PATH of /usr/bin:/bin plus a directory holding only a link to luacheck, so it finds
    -- luacheck but no node; and the directory, for removal. Homebrew's bin/ holds a node, so KO_DYLD_PREFIX gives
    -- KOReader's ffi/loadlib.lua:150-152 the prefix it otherwise asks `brew --prefix` for.
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
        output = without_slowest(output)
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
        assert.falsy(contains(without_slowest(output), "environment_spec.lua"))
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
        assert.truthy(without_slowest(output):find("\n== unit\n" .. layer .. "$"), output)
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

    local function write(path, text)
        local f = assert(io.open(path, "w"))
        f:write(text)
        f:close()
    end

    -- A spec named name that claims its KO_HOME, failing when another file already has, appends the KO_HOME to
    -- $KOPANDA_CLAIM_LOG, then waits up to wait_s (default 10) s for the spec named other to start, failing when it
    -- hasn't: it passes only beside other, each under a KO_HOME of its own.
    local function rendezvous_spec(path, name, other, wait_s)
        write(path, table.concat({
            'describe("rendezvous ' .. name .. '", function()',
            '    it("meets ' .. other .. ' in its own KO_HOME", function()',
            '        local home, dir = os.getenv("KO_HOME"), os.getenv("KOPANDA_RENDEZVOUS")',
            '        assert.is_nil(io.open(home .. "/claimed", "r"), "KO_HOME already claimed: " .. home)',
            '        io.open(home .. "/claimed", "w"):close()',
            '        local log = io.open(os.getenv("KOPANDA_CLAIM_LOG"), "a")',
            '        log:write(home, "\\n")',
            '        log:close()',
            '        io.open(dir .. "/' .. name .. '", "w"):close()',
            '        for _ = 1, ' .. math.ceil((wait_s or 10) * 10) .. ' do',
            '            local met = io.open(dir .. "/' .. other .. '", "r")',
            '            if met then met:close() return end',
            '            os.execute("sleep 0.1")',
            '        end',
            '        error("' .. other .. ' never started")',
            '    end)',
            'end)',
            '',
        }, "\n"))
    end

    it("runs each layer's spec files in parallel shards, each under its own KO_HOME, removed afterwards", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        for _, layer in ipairs({ "unit", "emulator" }) do
            rendezvous_spec(copy .. "/spec/" .. layer .. "/a_spec.lua", layer .. "_a", layer .. "_b")
            rendezvous_spec(copy .. "/spec/" .. layer .. "/b_spec.lua", layer .. "_b", layer .. "_a")
        end
        local env = "KOPANDA_RENDEZVOUS='" .. copy .. "' KOPANDA_CLAIM_LOG='" .. copy .. "/claims'"
        local output, status = run(env .. " KOPANDA_CHECK_JOBS=3 KOPANDA_CHECK_EMULATOR_JOBS=3 '" .. copy
            .. "/bin/check'")
        local claims = {}
        for line in io.lines(copy .. "/claims") do
            claims[#claims + 1] = line
        end
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, status, output)
        local layer = "%[==========%] 9 tests from 3 test files ran%.[^\n]*\n%[  PASSED  %] 9 tests%.\n"
        assert.truthy(without_slowest(output):find("\n== unit\n" .. layer .. "== emulator\n" .. layer .. "$"), output)
        assert.equals(4, #claims)
        local seen = {}
        for _, home in ipairs(claims) do
            assert.is_nil(seen[home], home)
            seen[home] = true
            assert.is_nil(lfs.attributes(home, "mode"), home)
        end
    end)

    it("fails a spec that shares a layer's single shard with the spec it waits for", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        rendezvous_spec(copy .. "/spec/unit/a_spec.lua", "a", "b", 1)
        rendezvous_spec(copy .. "/spec/unit/b_spec.lua", "b", "a", 1)
        local env = "KOPANDA_RENDEZVOUS='" .. copy .. "' KOPANDA_CLAIM_LOG='" .. copy .. "/claims'"
        local output, status = run(env .. " KOPANDA_CHECK_JOBS=1 '" .. copy .. "/bin/check' --unit")
        run("rm -rf '" .. copy .. "'")
        assert.equals(1, status, output)
        assert.truthy(contains(output, "[  FAILED  ] in spec/unit/a_spec.lua"), output)
        assert.truthy(contains(output, "b never started"), output)
    end)

    it("sums the shards into one total, prints each failing file in full and every note, and stops there", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        local _, setup = run("cp '" .. root .. "/spec/fixtures/failing_spec.lua' '" .. copy .. "/spec/unit/'")
        assert.equals(0, setup)
        write(copy .. "/spec/unit/noting_spec.lua", 'describe("scratch", function()\n'
            .. '    it("notes", function() print("chatter"); print("[  NOTE    ] wall time not judged") end)\n'
            .. 'end)\n')
        local output, status = run("KOPANDA_CHECK_JOBS=3 '" .. copy .. "/bin/check'")
        run("rm -rf '" .. copy .. "'")
        assert.equals(1, status, output)
        assert.truthy(contains(output, "\n[  FAILED  ] in spec/unit/failing_spec.lua\n"), output)
        assert.truthy(contains(output, "failing_spec.lua:3: Expected objects to be equal.\nPassed in:\n(number) 2\n"
            .. "Expected:\n(number) 1\n"), output)
        assert.truthy(contains(output, "failing_spec.lua:7: Expected objects to be the same."), output)
        assert.truthy(contains(output, "\n[  NOTE    ] wall time not judged\n"), output)
        assert.falsy(contains(output, "chatter"), output)
        assert.truthy(without_slowest(output):find("\n%[==========%] 10 tests from 3 test files ran%.[^\n]*\n"
            .. "%[  PASSED  %] 8 tests%.\n"
            .. "%[  FAILED  %] 2 tests, listed below:\n%[  FAILED  %] [^\n]*fails on purpose the first time\n"
            .. "%[  FAILED  %] [^\n]*fails on purpose the second time\n\n 2 FAILED TESTS\n$"), output)
        assert.falsy(contains(output, "== emulator"), output)
    end)

    -- A sysctl reporting load 0.5, so the paint-budget pass starts at once whatever else the host is running; anything
    -- else goes to the real one. Returns the PATH assignment that puts it first.
    local function quiet_host(copy)
        local bin = copy .. "/fake-bin"
        assert.equals(0, select(2, run("mkdir '" .. bin .. "'")))
        write(bin .. "/sysctl", '#!/bin/sh\nif [ "$2" = vm.loadavg ]; then echo "{ 0.50 0.50 0.50 }"; exit; fi\n'
            .. 'exec /usr/sbin/sysctl "$@"\n')
        assert.equals(0, select(2, run("chmod +x '" .. bin .. "/sysctl'")))
        return "PATH='" .. bin .. ":'\"$PATH\""
    end

    -- A spec that opens with header, which names paint_budget in some case and sets pause_ms, so bin/check holds it
    -- for the serial pass: it fails when the other emulator specs haven't all finished, or when another such spec is
    -- running beside it.
    local function budget_spec(path, header)
        write(path, table.concat({
            header,
            'describe("a paint budget", function()',
            '    it("runs alone, after the batch", function()',
            '        local dir = os.getenv("KOPANDA_RENDEZVOUS")',
            '        assert.truthy(io.open(dir .. "/batch_done", "r"), "the batch is still running")',
            '        assert.is_nil(io.open(dir .. "/budget_running", "r"), "another budget spec is running")',
            '        io.open(dir .. "/budget_running", "w"):close()',
            '        os.execute("sleep " .. pause_ms / 1000)',
            '        os.remove(dir .. "/budget_running")',
            '    end)',
            'end)',
            '',
        }, "\n"))
    end

    it("runs the emulator specs that name paint_budget in any case one at a time, after the others", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        budget_spec(copy .. "/spec/emulator/a_budget_spec.lua",
            "-- Stands in for a spec that holds a capture to emulator.paint_budget.\nlocal pause_ms = 500")
        budget_spec(copy .. "/spec/emulator/b_budget_spec.lua",
            "local PAINT_BUDGET_MS = 1\nlocal pause_ms = 500 * PAINT_BUDGET_MS")
        write(copy .. "/spec/emulator/z_batch_spec.lua", 'describe("the batch", function()\n'
            .. '    it("finishes", function()\n'
            .. '        os.execute("sleep 1")\n'
            .. '        io.open(os.getenv("KOPANDA_RENDEZVOUS") .. "/batch_done", "w"):close()\n'
            .. '    end)\n'
            .. 'end)\n')
        local output, status = run(quiet_host(copy) .. " KOPANDA_RENDEZVOUS='" .. copy
            .. "' KOPANDA_CHECK_EMULATOR_JOBS=4 '" .. copy .. "/bin/check'")
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, status, output)
        assert.truthy(without_slowest(output):find("\n== emulator\n"
            .. "%[==========%] 10 tests from 4 test files ran%.[^\n]*\n"
            .. "%[  PASSED  %] 10 tests%.\n$"), output)
    end)

    it("waits for the host's load to fall to its core count before the paint-budget specs", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        write(copy .. "/spec/emulator/budget_spec.lua", "-- Names paint_budget.\n"
            .. 'describe("a paint budget", function() it("runs", function() end) end)\n')
        local bin = copy .. "/fake-bin"
        local _, setup = run("mkdir '" .. bin .. "'")
        assert.equals(0, setup)
        -- A sysctl reporting load 99 the first time it is asked, 0.5 after; anything else goes to the real one.
        write(bin .. "/sysctl", table.concat({
            "#!/bin/sh",
            'if [ "$2" = vm.loadavg ]; then',
            '    if [ -e "$0.asked" ]; then echo "{ 0.50 0.50 0.50 }"; exit; fi',
            '    touch "$0.asked"; echo "{ 99.00 0.50 0.50 }"',
            "else",
            '    exec /usr/sbin/sysctl "$@"',
            "fi",
            "",
        }, "\n"))
        assert.equals(0, select(2, run("chmod +x '" .. bin .. "/sysctl'")))
        local output, status = run("PATH='" .. bin .. ":'\"$PATH\" '" .. copy .. "/bin/check'")
        local asked = lfs.attributes(bin .. "/sysctl.asked", "mode")
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, status, output)
        assert.equals("file", asked)
        assert.truthy(output:find("\n== emulator\nwaiting for the host's load 99%.00 to fall to %d+ cores\n"), output)
        assert.truthy(without_slowest(output):find("%[==========%] 8 tests from 2 test files ran%.[^\n]*\n"
            .. "%[  PASSED  %] 8 tests%.\n$"),
            output)
    end)

    it("refuses with exit 2 when a job count isn't a positive whole number, naming the variable", function()
        for _, setting in ipairs({ "KOPANDA_CHECK_JOBS=0", "KOPANDA_CHECK_EMULATOR_JOBS=four" }) do
            local output, status = run(setting .. " '" .. check .. "' --lint")
            assert.equals(2, status, output)
            assert.truthy(contains(output, setting:match("^[%w_]+")), output)
        end
    end)

    local quitting_spec = 'describe("scratch", function() it("quits", function() os.exit(0) end) end)\n'

    it("fails a shard whose test ends the process with exit 0, naming the file, with or without --verbose", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        write(copy .. "/spec/unit/quitting_spec.lua", quitting_spec)
        local output, status = run("KOPANDA_CHECK_JOBS=2 '" .. copy .. "/bin/check' --unit")
        local verbose, verbose_status = run("KOPANDA_CHECK_JOBS=2 '" .. copy .. "/bin/check' --unit --verbose")
        run("rm -rf '" .. copy .. "'")
        assert.equals(1, status, output)
        assert.truthy(contains(output, "[  FAILED  ] in spec/unit/quitting_spec.lua"), output)
        assert.equals(1, verbose_status, verbose)
        assert.truthy(contains(verbose, "quitting_spec.lua"), verbose)
    end)

    it("fails a named spec whose test ends the process with exit 0", function()
        local dir = run("mktemp -d"):gsub("\n$", "")
        write(dir .. "/quitting_spec.lua", quitting_spec)
        local output, status = run("'" .. check .. "' '" .. dir .. "/quitting_spec.lua'")
        run("rm -rf '" .. dir .. "'")
        assert.equals(1, status, output)
        assert.truthy(contains(output, "scratch quits"), output)
    end)

    -- Polls a shell condition every 0.1 s for at most seconds, returning whether it came true.
    local function eventually(condition, seconds)
        for _ = 1, seconds * 10 do
            if select(2, run(condition)) == 0 then
                return true
            end
            os.execute("sleep 0.1")
        end
        return false
    end

    it("stops every process it started and removes its KO_HOME when terminated or interrupted", function()
        for _, signal in ipairs({ "TERM", "INT" }) do
            local copy = small_checkout()
            fake_studio(copy, "true")
            -- The sleep ignores SIGINT as a background job's luajit does; macOS's system() would reset it.
            write(copy .. "/spec/unit/sleeper_spec.lua", 'describe("a sleeper", function()\n'
                .. '    it("sleeps", function()\n'
                .. '        os.execute("trap \'\' INT; echo $$ > \\"$KOPANDA_SLEEPER\\"; exec sleep 30")\n'
                .. '    end)\n'
                .. 'end)\n')
            -- In a process group of its own, with the SIGINT the shell's & ignores restored, as at a terminal.
            local started = run("KOPANDA_SLEEPER='" .. copy .. "/sleeper' perl -e '$SIG{INT} = q(DEFAULT); setpgrp;"
                .. " exec @ARGV' '" .. copy
                .. "/bin/check' --unit >'" .. copy .. "/out' 2>&1 </dev/null & echo $!")
            local pid = started:match("(%d+)")
            local slept = eventually("test -s '" .. copy .. "/sleeper'", 60)
            local sleeper = slept and run("cat '" .. copy .. "/sleeper'"):match("(%d+)")
            -- The sole job, the INT case's whole process group: the ignored SIGINT background jobs inherit.
            run(signal == "TERM" and "kill -TERM " .. pid or "kill -INT -- -" .. pid)
            local stopped = eventually("! kill -0 " .. pid, 10)
            local slept_on = sleeper and not eventually("! kill -0 " .. sleeper, 2)
            local output = run("cat '" .. copy .. "/out'")
            local home = inner_ko_home(output)
            local left = home and lfs.attributes(home, "mode")
            run("kill -KILL -- -" .. pid .. (sleeper and " " .. sleeper or "") .. " 2>/dev/null; rm -rf '" .. copy
                .. "'" .. (home and " '" .. home .. "'" or ""))
            assert.is_true(slept, output)
            assert.is_true(stopped, signal .. ": bin/check still running\n" .. output)
            assert.is_false(slept_on, signal .. ": the spec's sleep outlived bin/check\n" .. output)
            assert.is_string(home, output)
            assert.is_nil(left, signal .. ": KO_HOME left behind")
        end
    end)

    it("runs named specs and --unit's shards from a checkout whose path contains a space", function()
        local parent = run("mktemp -d"):gsub("\n$", "")
        local copy = parent .. "/with space"
        assert.equals(0, select(2, run("mkdir '" .. copy .. "'")))
        small_checkout(copy)
        fake_studio(copy, "true")
        assert.equals(0, select(2, run("cp '" .. root .. "/spec/unit/environment_spec.lua' '" .. copy
            .. "/spec/unit/second_spec.lua'")))
        local named, named_status = run("cd '" .. copy .. "' && '" .. copy
            .. "/bin/check' spec/unit/environment_spec.lua")
        local unit, unit_status = run("KOPANDA_CHECK_JOBS=2 '" .. copy .. "/bin/check' --unit")
        run("rm -rf '" .. parent .. "'")
        assert.equals(0, named_status, named)
        assert.equals(0, unit_status, unit)
        assert.truthy(without_slowest(unit):find("\n== unit\n%[==========%] 14 tests from 2 test files ran%.[^\n]*\n"
            .. "%[  PASSED  %] 14 tests%.\n$"), unit)
    end)

    -- A spec under header, when given, whose describe is name and whose tests each sleep their ms: { { "t1", 60 } }.
    local function timed_spec(path, name, tests, header)
        local lines = { header }
        lines[#lines + 1] = 'describe("' .. name .. '", function()'
        for _, test in ipairs(tests) do
            lines[#lines + 1] = '    it("' .. test[1] .. '", function() os.execute("sleep ' .. test[2] / 1000
                .. '") end)'
        end
        lines[#lines + 1] = "end)\n"
        write(path, table.concat(lines, "\n"))
    end

    -- The output with each slowest-tests line's milliseconds read as N.
    local function any_ms(output)
        return (output:gsub("(%[  SLOWEST %] )%d+ ms ", "%1N ms "))
    end

    it("prints each layer's 5 slowest tests after its summary, across its shards and its paint-budget pass", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        assert.equals(0, select(2, run("rm '" .. copy .. "/spec/unit/environment_spec.lua' '" .. copy
            .. "/spec/emulator/environment_spec.lua'")))
        timed_spec(copy .. "/spec/unit/a_spec.lua", "unit a", { { "t0", 0 }, { "t2", 120 }, { "t4", 240 } })
        timed_spec(copy .. "/spec/unit/b_spec.lua", "unit b", { { "t1", 60 }, { "t3", 180 }, { "t5", 300 } })
        timed_spec(copy .. "/spec/emulator/batch_spec.lua", "batch", { { "quick", 0 } })
        timed_spec(copy .. "/spec/emulator/budget_spec.lua", "a paint budget", { { "waits", 100 } },
            "-- Names paint_budget.")
        local output, status = run(quiet_host(copy) .. " KOPANDA_CHECK_JOBS=2 '" .. copy .. "/bin/check'")
        run("rm -rf '" .. copy .. "'")
        assert.equals(0, status, output)
        assert.truthy(contains(any_ms(output), "[  PASSED  ] 6 tests.\n"
            .. "[  SLOWEST ] 5 slowest tests\n"
            .. "[  SLOWEST ] N ms spec/unit/b_spec.lua:4 unit b t5\n"
            .. "[  SLOWEST ] N ms spec/unit/a_spec.lua:4 unit a t4\n"
            .. "[  SLOWEST ] N ms spec/unit/b_spec.lua:3 unit b t3\n"
            .. "[  SLOWEST ] N ms spec/unit/a_spec.lua:3 unit a t2\n"
            .. "[  SLOWEST ] N ms spec/unit/b_spec.lua:2 unit b t1\n"
            .. "== emulator\n"), output)
        assert.truthy(any_ms(output):find("\n%[  PASSED  %] 2 tests%.\n"
            .. "%[  SLOWEST %] 2 slowest tests\n"
            .. "%[  SLOWEST %] N ms spec/emulator/budget_spec%.lua:3 a paint budget waits\n"
            .. "%[  SLOWEST %] N ms spec/emulator/batch_spec%.lua:2 batch quick\n$"), output)
        assert.is_true(tonumber(output:match("(%d+) ms spec/unit/b_spec.lua:4 ")) >= 300, output)
    end)

    it("prints a named run's slowest tests, only as many as ran, with or without --verbose", function()
        local dir = run("mktemp -d"):gsub("\n$", "")
        timed_spec(dir .. "/timed_spec.lua", "scratch", { { "quick", 0 }, { "slow", 60 } })
        local quiet, quiet_status = run("'" .. check .. "' '" .. dir .. "/timed_spec.lua'")
        local verbose, verbose_status = run("'" .. check .. "' --verbose '" .. dir .. "/timed_spec.lua'")
        run("rm -rf '" .. dir .. "'")
        local block = "[  PASSED  ] 2 tests.\n[  SLOWEST ] 2 slowest tests\n"
            .. "[  SLOWEST ] N ms " .. dir .. "/timed_spec.lua:3 scratch slow\n"
            .. "[  SLOWEST ] N ms " .. dir .. "/timed_spec.lua:2 scratch quick\n"
        for _, pair in ipairs({ { quiet, quiet_status }, { verbose, verbose_status } }) do
            local output, status = pair[1], pair[2]
            assert.equals(0, status, output)
            assert.equals(block, any_ms(output):sub(-#block), output)
        end
    end)

    it("keeps a failing run's exit 1 and its listed failures, then prints the slowest tests", function()
        local copy = small_checkout()
        fake_studio(copy, "true")
        assert.equals(0, select(2, run("cp '" .. root .. "/spec/fixtures/failing_spec.lua' '" .. copy
            .. "/spec/unit/'")))
        local output, status = run("KOPANDA_CHECK_JOBS=2 '" .. copy .. "/bin/check' --unit")
        local named, named_status = run("cd '" .. copy .. "' && '" .. copy .. "/bin/check' spec/unit/failing_spec.lua")
        run("rm -rf '" .. copy .. "'")
        assert.equals(1, status, output)
        assert.truthy(contains(output, "[  FAILED  ] in spec/unit/failing_spec.lua\n"), output)
        assert.truthy(output:find("\n 2 FAILED TESTS\n%[  SLOWEST %] 5 slowest tests\n"), output)
        assert.equals(1, named_status, named)
        assert.truthy(named:find("\n 2 FAILED TESTS\n%[  SLOWEST %] 2 slowest tests\n"), named)
    end)
end)
