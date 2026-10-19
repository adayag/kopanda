-- The apply patch (C8, C9): on scratch data folders under the run's KO_HOME, a stage written by
-- hand is applied, a failed apply undoes itself, an install left on probation is rolled back,
-- and a start cut short at each apply step is restored. The patch's own seams (_move, _purge,
-- _write_record, _set_reader_key) inject the failures; a seam that yields freezes the run as a
-- crash would leave it.
describe("the apply patch", function()
    local DataStorage = require("datastorage")
    local LuaSettings = require("luasettings")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local PushApply = require("push_apply")
    local ko_home = os.getenv("KO_HOME")
    local plugin_source = os.getenv("KOPANDA_ROOT") .. "/kopanda.koplugin/push_apply.lua"
    local HASH = string.rep("a", 64)

    local seams = { "_move", "_purge", "_write_record", "_set_reader_key" }
    local saved_seams = {}
    for _, name in ipairs(seams) do
        saved_seams[name] = PushApply[name]
    end

    local counter = 0
    local dir, p, logged

    local function read(path)
        local f = io.open(path, "rb")
        if not f then
            return nil
        end
        local text = f:read("*a")
        f:close()
        return text
    end

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function mkdirs(path)
        local built = ""
        for part in path:gmatch("[^/]+") do
            built = built .. "/" .. part
            if not lfs.attributes(built, "mode") then
                assert(lfs.mkdir(built))
            end
        end
    end

    local function mode(path)
        return lfs.symlinkattributes(path, "mode")
    end

    local function load_lua(path)
        local ok, value = pcall(dofile, path)
        if ok then
            return value
        end
    end

    -- Every entry under root as relative path -> bytes ("<dir>" for a folder), skipping the
    -- relative paths in skip.
    local function tree(root, skip)
        skip = skip or {}
        local out = {}
        local function walk(path, rel)
            for name in lfs.dir(path) do
                if name ~= "." and name ~= ".." then
                    local child_rel = rel == "" and name or rel .. "/" .. name
                    if not skip[child_rel] then
                        local child = path .. "/" .. name
                        if mode(child) == "directory" then
                            out[child_rel] = "<dir>"
                            walk(child, child_rel)
                        else
                            out[child_rel] = read(child)
                        end
                    end
                end
            end
        end
        walk(root, "")
        return out
    end

    -- The device outside the push folder and the state file, which every run that acts rewrites.
    local function device()
        return tree(dir, { ["settings/kopanda/push"] = true, ["settings/kopanda/state.lua"] = true })
    end

    local function reader_value(key)
        return LuaSettings:open(p.reader):readSetting(key)
    end

    local function state_value(key)
        return LuaSettings:open(p.state):readSetting(key)
    end

    local function result()
        return load_lua(p.result)
    end

    local function logged_error(text)
        for _, call in ipairs(logged.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    -- A data folder: the old plugin, its settings, KOReader's settings with an unrelated disabled
    -- plugin, and the boot flag set. opts.no_settings leaves out settings.lua; opts.no_disabled
    -- leaves plugins_disabled out of settings.reader.lua.
    local function device_fixture(opts)
        opts = opts or {}
        mkdirs(dir .. "/plugins/kopanda.koplugin")
        write(dir .. "/plugins/kopanda.koplugin/main.lua", "-- old plugin\n")
        write(dir .. "/plugins/kopanda.koplugin/_meta.lua", "return {}\n")
        write(dir .. "/plugins/kopanda.koplugin/marker.txt", "old\n")
        mkdirs(dir .. "/settings/kopanda")
        if not opts.no_settings then
            write(p.settings, "-- settings/kopanda/settings.lua\nreturn { marker = \"old\" }\n")
        end
        local reader = LuaSettings:open(p.reader)
        reader:saveSetting("device_id", "kopanda-test")
        if not opts.no_disabled then
            reader:saveSetting("plugins_disabled", { hello = true })
        end
        reader:flush()
        LuaSettings:open(p.state):saveSetting("boot_pending", true):flush()
    end

    -- A complete stage; record overrides fields of its record (a string replaces the record).
    local function stage(record)
        mkdirs(p.staged .. "/plugin")
        write(p.staged .. "/plugin/main.lua", "-- new plugin\n")
        write(p.staged .. "/plugin/_meta.lua", "return {}\n")
        write(p.staged .. "/plugin/marker.txt", "new\n")
        write(p.staged .. "/settings.lua", "-- settings/kopanda/settings.lua\nreturn { marker = \"new\" }\n")
        if type(record) == "string" then
            write(p.staged_record, record)
            return
        end
        local fields = {
            format = 1,
            profile = "vector",
            hash = HASH,
            plugin_dir = dir .. "/plugins/kopanda.koplugin",
            disable = { "simpleui", "ennUI" },
            at = "2026-10-16T14:02:11Z",
        }
        for k, v in pairs(record or {}) do
            fields[k] = v
        end
        write(p.staged_record, "return " .. require("dump")(fields, nil, true) .. "\n")
    end

    -- A release's stage: the plugin only, no staged settings.lua, the record's settings false.
    local function plugin_only_stage(record)
        local fields = { settings = false }
        for k, v in pairs(record or {}) do
            fields[k] = v
        end
        stage(fields)
        os.remove(p.staged .. "/settings.lua")
    end

    local function no_stage()
        assert.is_nil(mode(p.staged_record))
        assert.is_nil(mode(p.staged))
    end

    local function plugin_marker()
        return read(dir .. "/plugins/kopanda.koplugin/marker.txt")
    end

    local function settings_marker()
        local data = load_lua(p.settings)
        return data and data.marker
    end

    before_each(function()
        counter = counter + 1
        dir = ko_home .. "/push-apply-" .. counter
        mkdirs(dir)
        p = PushApply.paths(dir)
        logged = spy.on(logger, "err")
    end)

    after_each(function()
        for _, name in ipairs(seams) do
            PushApply[name] = saved_seams[name]
        end
        logger.err:revert()
        os.execute("rm -rf '" .. dir .. "'")
    end)

    describe("paths", function()
        it("puts the push folder under settings/kopanda and names every file", function()
            local paths = PushApply.paths("/data")
            assert.equals("/data/settings/kopanda/push", paths.push)
            assert.equals("/data/settings/kopanda/push/staged.lua", paths.staged_record)
            assert.equals("/data/settings/kopanda/push/staged", paths.staged)
            assert.equals("/data/settings/kopanda/push/download", paths.download)
            assert.equals("/data/settings/kopanda/push/rollback", paths.rollback)
            assert.equals("/data/settings/kopanda/push/probation.lua", paths.probation)
            assert.equals("/data/settings/kopanda/push/result.lua", paths.result)
            assert.equals("/data/settings/kopanda/push/discard", paths.discard)
            assert.equals("/data/settings/kopanda/settings.lua", paths.settings)
            assert.equals("/data/settings/kopanda/state.lua", paths.state)
            assert.equals("/data/settings.reader.lua", paths.reader)
            assert.equals("/data/patches", paths.patches)
        end)
    end)

    describe("apply", function()
        it("swaps the plugin and settings, disables the shells and puts the install on probation", function()
            device_fixture()
            stage()
            PushApply.run(dir)
            assert.equals("new\n", plugin_marker())
            assert.equals("new", settings_marker())
            assert.equals("old\n", read(p.rollback .. "/plugin/marker.txt"))
            assert.equals("old", load_lua(p.rollback .. "/settings.lua").marker)
            assert.same({ hello = true, simpleui = true, ennUI = true }, reader_value("plugins_disabled"))
            assert.equals("kopanda-test", reader_value("device_id"))
            assert.is_false(state_value("boot_pending"))
            local probation = load_lua(p.probation)
            assert.equals("vector", probation.profile)
            assert.equals(HASH, probation.hash)
            assert.is_string(probation.at)
            assert.same({ ok = true, kind = "applied", profile = "vector", hash = HASH }, result())
            local record = load_lua(p.rollback .. "/record.lua")
            assert.equals("vector", record.profile)
            assert.equals(HASH, record.hash)
            assert.equals(dir .. "/plugins/kopanda.koplugin", record.plugin_dir)
            assert.is_true(record.had_settings)
            assert.is_false(record.had_settings_old)
            assert.is_true(record.had_plugins_disabled)
            assert.same({ hello = true }, record.plugins_disabled)
            no_stage()
        end)

        it("records an absent settings file and an absent plugins_disabled", function()
            device_fixture{ no_settings = true, no_disabled = true }
            stage()
            PushApply.run(dir)
            assert.equals("new", settings_marker())
            assert.is_nil(mode(p.rollback .. "/settings.lua"))
            local record = load_lua(p.rollback .. "/record.lua")
            assert.is_false(record.had_settings)
            assert.is_false(record.had_plugins_disabled)
            assert.is_nil(record.plugins_disabled)
            assert.same({ simpleui = true, ennUI = true }, reader_value("plugins_disabled"))
        end)

        it("swaps only the plugin for a plugin-only stage, the settings file byte-identical", function()
            device_fixture()
            write(p.settings .. ".old", "return { marker = \"older\" }\n")
            local settings = read(p.settings)
            plugin_only_stage()
            PushApply.run(dir)
            assert.equals("new\n", plugin_marker())
            assert.equals("old\n", read(p.rollback .. "/plugin/marker.txt"))
            assert.equals(settings, read(p.settings))
            assert.equals("return { marker = \"older\" }\n", read(p.settings .. ".old"))
            assert.is_nil(mode(p.rollback .. "/settings.lua"))
            assert.is_true(load_lua(p.rollback .. "/record.lua").settings_untouched)
            assert.same({ hello = true, simpleui = true, ennUI = true }, reader_value("plugins_disabled"))
            assert.same({ ok = true, kind = "applied", profile = "vector", hash = HASH }, result())
            no_stage()
        end)

        it("creates no settings file for a plugin-only stage when there was none", function()
            device_fixture{ no_settings = true }
            plugin_only_stage()
            PushApply.run(dir)
            assert.equals("new\n", plugin_marker())
            assert.is_nil(mode(p.settings))
            assert.equals("applied", result().kind)
        end)

        it("marks the settings touched for a stage that carries them", function()
            device_fixture()
            stage{ settings = true }
            PushApply.run(dir)
            assert.equals("new", settings_marker())
            assert.is_falsy(load_lua(p.rollback .. "/record.lua").settings_untouched)
        end)

        it("changes nothing when nothing is staged and nothing is on probation", function()
            device_fixture()
            local long_ago = os.time() - 3600
            local before = tree(dir)
            local times = {}
            for rel in pairs(before) do
                assert.truthy(lfs.touch(dir .. "/" .. rel, long_ago, long_ago))
                times[rel] = long_ago
            end
            PushApply.run(dir)
            assert.same(before, tree(dir))
            for rel, time in pairs(times) do
                assert.equals(time, lfs.attributes(dir .. "/" .. rel, "modification"))
            end
        end)

        local bad_stages = {
            { "a record that doesn't load", function() stage("return {") end },
            { "a record that isn't a table", function() stage("return 42") end },
            { "a relative plugin_dir", function() stage{ plugin_dir = "plugins/kopanda.koplugin" } end },
            { "a plugin_dir not ending /kopanda.koplugin", function()
                stage{ plugin_dir = dir .. "/plugins" }
            end },
            { "a plugin_dir that is not a folder", function()
                stage{ plugin_dir = dir .. "/missing/kopanda.koplugin" }
            end },
            { "another format", function() stage{ format = 2 } end },
            { "a disable that isn't a list", function() stage{ disable = "simpleui" } end },
            { "a disable holding a non-name", function() stage{ disable = { 1 } } end },
            { "a missing staged/plugin/main.lua", function()
                stage()
                os.remove(p.staged .. "/plugin/main.lua")
            end },
            { "a missing staged/plugin/_meta.lua", function()
                stage()
                os.remove(p.staged .. "/plugin/_meta.lua")
            end },
            { "a missing staged/settings.lua", function()
                stage()
                os.remove(p.staged .. "/settings.lua")
            end },
            { "a missing staged/settings.lua with settings true", function()
                plugin_only_stage{ settings = true }
            end },
            { "a settings that isn't a boolean", function() stage{ settings = "no" } end },
            { "a plugin-only stage missing staged/plugin/main.lua", function()
                plugin_only_stage()
                os.remove(p.staged .. "/plugin/main.lua")
            end },
            { "a plugin-only stage missing staged/plugin/_meta.lua", function()
                plugin_only_stage()
                os.remove(p.staged .. "/plugin/_meta.lua")
            end },
        }
        for _, case in ipairs(bad_stages) do
            it("fails with nothing moved for " .. case[1], function()
                device_fixture()
                local before = device()
                case[2]()
                PushApply.run(dir)
                assert.same(before, device())
                assert.is_true(state_value("boot_pending"))
                local outcome = result()
                assert.is_false(outcome.ok)
                assert.equals("failed", outcome.kind)
                assert.is_string(outcome.message)
                no_stage()
                assert.is_nil(mode(p.probation))
            end)
        end

        local swap_faults = {
            { "the plugin move", "plugin folder", function(from)
                return from == dir .. "/plugins/kopanda.koplugin"
            end },
            { "the staged plugin's move", "plugin folder", function(from)
                return from == p.staged .. "/plugin"
            end },
            { "the settings move", "settings", function(from)
                return from == p.settings
            end },
            { "the staged settings' move", "settings", function(from)
                return from == p.staged .. "/settings.lua"
            end },
        }
        for _, fault in ipairs(swap_faults) do
            it("restores everything and fails when " .. fault[1] .. " fails", function()
                device_fixture()
                local before = device()
                stage()
                local move = PushApply._move
                PushApply._move = function(from, to)
                    if fault[3](from) then
                        error("kopanda-test: move failed")
                    end
                    return move(from, to)
                end
                PushApply.run(dir)
                assert.same(before, device())
                assert.is_false(state_value("boot_pending"))
                local outcome = result()
                assert.equals("failed", outcome.kind)
                assert.equals("vector", outcome.profile)
                assert.truthy(outcome.message:find(fault[2], 1, true))
                assert.truthy(outcome.message:find("kopanda-test: move failed", 1, true))
                assert.is_nil(mode(p.probation))
                no_stage()
            end)
        end

        it("restores everything and fails when the plugins_disabled write fails", function()
            device_fixture()
            local before = device()
            stage()
            local set = PushApply._set_reader_key
            PushApply._set_reader_key = function(paths, key, value)
                if type(value) == "table" and value.simpleui then
                    error("kopanda-test: write failed")
                end
                return set(paths, key, value)
            end
            PushApply.run(dir)
            assert.same(before, device())
            local outcome = result()
            assert.equals("failed", outcome.kind)
            assert.truthy(outcome.message:find("plugins_disabled", 1, true))
            assert.is_nil(mode(p.probation))
            no_stage()
        end)

        it("fails with nothing moved when the rollback record can't be written", function()
            device_fixture()
            local before = device()
            stage()
            local write_record = PushApply._write_record
            PushApply._write_record = function(path, value)
                if path == p.rollback .. "/record.lua" then
                    error("kopanda-test: record failed")
                end
                return write_record(path, value)
            end
            PushApply.run(dir)
            assert.same(before, device())
            assert.is_true(state_value("boot_pending"))
            assert.equals("failed", result().kind)
            assert.is_nil(mode(p.probation))
            no_stage()
        end)

        local finish_faults = {
            { "the result write", "_write_record", function(path) return path == p.result end, false },
            { "the removal of staged.lua", "_purge", function(path) return path == p.staged_record end, true },
            { "the purge of staged/", "_purge", function(path) return path == p.staged end, false },
        }
        for _, fault in ipairs(finish_faults) do
            it("keeps the install applied and on probation when " .. fault[1] .. " fails", function()
                device_fixture()
                stage()
                local original = PushApply[fault[2]]
                PushApply[fault[2]] = function(path, ...)
                    if fault[3](path) then
                        error("kopanda-test: finish failed")
                    end
                    return original(path, ...)
                end
                PushApply.run(dir)
                PushApply[fault[2]] = original
                assert.equals("new\n", plugin_marker())
                assert.equals("new", settings_marker())
                assert.same({ hello = true, simpleui = true, ennUI = true }, reader_value("plugins_disabled"))
                assert.is_false(state_value("boot_pending"))
                assert.equals("file", mode(p.probation))
                assert.equals("directory", mode(p.rollback .. "/plugin"))
                assert.is_true(logged_error("kopanda-test: finish failed"))
                local outcome = result()
                assert.is_true(outcome == nil or outcome.kind == "applied")
                if fault[4] then
                    -- A painted home clears probation; the leftover record then fails harmlessly.
                    assert.equals("file", mode(p.staged_record))
                    assert.is_nil(mode(p.staged .. "/plugin"))
                    assert.truthy(PushApply.clear_probation(dir))
                    local applied = device()
                    PushApply.run(dir)
                    assert.same(applied, device())
                    assert.equals("failed", result().kind)
                    no_stage()
                    assert.is_nil(mode(p.probation))
                end
            end)
        end
    end)

    describe("rollback", function()
        it("restores the plugin, settings, plugins_disabled and the flag after probation", function()
            device_fixture()
            local before = device()
            stage()
            PushApply.run(dir)
            assert.equals("applied", result().kind)
            PushApply.run(dir)
            assert.same(before, device())
            assert.same({ hello = true }, reader_value("plugins_disabled"))
            assert.is_false(state_value("boot_pending"))
            assert.is_nil(mode(p.probation))
            assert.is_nil(mode(p.rollback))
            no_stage()
            local outcome = result()
            assert.is_false(outcome.ok)
            assert.equals("rolled_back", outcome.kind)
            assert.equals("vector", outcome.profile)
            assert.equals(HASH, outcome.hash)
        end)

        it("restores an absent settings file and an absent plugins_disabled", function()
            device_fixture{ no_settings = true, no_disabled = true }
            local before = device()
            stage()
            PushApply.run(dir)
            PushApply.run(dir)
            assert.same(before, device())
            assert.is_nil(mode(p.settings))
            assert.is_nil(reader_value("plugins_disabled"))
            assert.equals("rolled_back", result().kind)
        end)

        it("removes a settings.lua.old the new install made when there was none", function()
            device_fixture{ no_settings = true }
            stage()
            PushApply.run(dir)
            write(p.settings .. ".old", "return { marker = \"new\" }\n")
            PushApply.run(dir)
            assert.is_nil(mode(p.settings))
            assert.is_nil(mode(p.settings .. ".old"))
            assert.same({}, LuaSettings:open(p.settings).data)
        end)

        it("leaves a settings.lua.old that was there before the apply", function()
            device_fixture()
            write(p.settings .. ".old", "return { marker = \"older\" }\n")
            stage()
            PushApply.run(dir)
            assert.is_true(load_lua(p.rollback .. "/record.lua").had_settings_old)
            PushApply.run(dir)
            assert.equals("return { marker = \"older\" }\n", read(p.settings .. ".old"))
            assert.equals("old", settings_marker())
        end)

        it("restores the plugin of a plugin-only apply and leaves the settings file as it is", function()
            device_fixture()
            local before = device()
            plugin_only_stage()
            PushApply.run(dir)
            assert.equals("applied", result().kind)
            PushApply.run(dir)
            assert.same(before, device())
            assert.equals("old\n", plugin_marker())
            assert.equals("rolled_back", result().kind)
            assert.is_nil(mode(p.rollback))
        end)

        it("leaves the settings file the new install wrote, and its .old, after a plugin-only apply", function()
            device_fixture{ no_settings = true }
            plugin_only_stage()
            PushApply.run(dir)
            write(p.settings, "return { marker = \"kept\" }\n")
            write(p.settings .. ".old", "return {}\n")
            PushApply.run(dir)
            assert.equals("old\n", plugin_marker())
            assert.equals("return { marker = \"kept\" }\n", read(p.settings))
            assert.equals("return {}\n", read(p.settings .. ".old"))
            assert.equals("rolled_back", result().kind)
        end)

        it("creates and removes no settings file rolling back a plugin-only apply when there was none", function()
            device_fixture{ no_settings = true }
            local before = device()
            plugin_only_stage()
            PushApply.run(dir)
            assert.is_nil(mode(p.settings))
            PushApply.run(dir)
            assert.same(before, device())
            assert.is_nil(mode(p.settings))
            assert.equals("rolled_back", result().kind)
        end)

        it("purges a stage left while on probation", function()
            device_fixture()
            stage()
            PushApply.run(dir)
            stage()
            PushApply.run(dir)
            no_stage()
            assert.equals("old\n", plugin_marker())
            assert.equals("rolled_back", result().kind)
        end)

        -- Runs the apply in a coroutine that a seam freezes at the point the crash cuts it short.
        local function crash_at(name, at)
            local original = PushApply[name]
            PushApply[name] = function(...)
                if at(...) then
                    coroutine.yield()
                end
                return original(...)
            end
            coroutine.wrap(function()
                PushApply.run(dir)
            end)()
            PushApply[name] = original
        end

        local crashes = {
            { "after probation is written", "_move", function(from)
                return from == dir .. "/plugins/kopanda.koplugin"
            end },
            { "with the plugin moved aside", "_move", function(from)
                return from == p.staged .. "/plugin"
            end },
            { "with the plugin swapped", "_move", function(from)
                return from == p.settings
            end },
            { "with the settings moved aside", "_move", function(from)
                return from == p.staged .. "/settings.lua"
            end },
            { "with the settings swapped", "_set_reader_key", function()
                return true
            end },
            { "before the result is written", "_write_record", function(path)
                return path == p.result
            end },
        }
        for _, crash in ipairs(crashes) do
            it("returns the device to before the apply when a start was cut short " .. crash[1], function()
                device_fixture()
                local before = device()
                stage()
                crash_at(crash[2], crash[3])
                assert.equals("file", mode(p.probation))
                PushApply.run(dir)
                assert.same(before, device())
                assert.is_false(state_value("boot_pending"))
                assert.equals("rolled_back", result().kind)
                assert.is_nil(mode(p.probation))
                assert.is_nil(mode(p.rollback))
                no_stage()
            end)
        end

        -- The crash points a plugin-only apply reaches: no settings move is made.
        for _, crash in ipairs{ crashes[1], crashes[2], crashes[5], crashes[6] } do
            it("returns a plugin-only apply to before it when a start was cut short " .. crash[1], function()
                device_fixture()
                local before = device()
                plugin_only_stage()
                crash_at(crash[2], crash[3])
                assert.equals("file", mode(p.probation))
                PushApply.run(dir)
                assert.same(before, device())
                assert.equals("rolled_back", result().kind)
                assert.is_nil(mode(p.probation))
                no_stage()
            end)
        end

        local plugin_faults = {
            { "moving the new plugin aside", function(_, to) return to == p.discard end },
            { "moving the old plugin back", function(from) return from == p.rollback .. "/plugin" end },
        }
        for _, fault in ipairs(plugin_faults) do
            it("tries every other step and keeps probation when " .. fault[1] .. " fails", function()
                device_fixture()
                local before = device()
                stage()
                PushApply.run(dir)
                local move = PushApply._move
                PushApply._move = function(from, to)
                    if fault[2](from, to) then
                        error("kopanda-test: restore move failed")
                    end
                    return move(from, to)
                end
                PushApply.run(dir)
                PushApply._move = move
                assert.same({ hello = true }, reader_value("plugins_disabled"))
                assert.equals("old", settings_marker())
                assert.is_false(state_value("boot_pending"))
                local outcome = result()
                assert.equals("restore_failed", outcome.kind)
                assert.truthy(outcome.message:find("plugin folder", 1, true))
                assert.equals("file", mode(p.probation))
                assert.equals("directory", mode(p.rollback .. "/plugin"))
                PushApply.run(dir)
                assert.same(before, device())
                assert.equals("rolled_back", result().kind)
                assert.is_nil(mode(p.probation))
                assert.is_nil(mode(p.rollback))
            end)
        end

        it("tries every other step when restoring plugins_disabled fails", function()
            device_fixture()
            stage()
            PushApply.run(dir)
            local set = PushApply._set_reader_key
            PushApply._set_reader_key = function()
                error("kopanda-test: reader write failed")
            end
            PushApply.run(dir)
            PushApply._set_reader_key = set
            assert.equals("old\n", plugin_marker())
            assert.equals("old", settings_marker())
            assert.is_false(state_value("boot_pending"))
            local outcome = result()
            assert.equals("restore_failed", outcome.kind)
            assert.truthy(outcome.message:find("plugins_disabled", 1, true))
            assert.equals("file", mode(p.probation))
        end)

        it("gives up and clears probation when the rollback record doesn't load", function()
            device_fixture()
            stage()
            PushApply.run(dir)
            write(p.rollback .. "/record.lua", "return {")
            PushApply.run(dir)
            assert.equals("restore_failed", result().kind)
            assert.is_nil(mode(p.probation))
        end)

        it("gives up and moves nothing when the rollback record's plugin folder is not the plugin's", function()
            device_fixture()
            stage()
            PushApply.run(dir)
            local record = load_lua(p.rollback .. "/record.lua")
            record.plugin_dir = dir .. "/plugins"
            write(p.rollback .. "/record.lua", "return " .. require("dump")(record, nil, true) .. "\n")
            local before = device()
            PushApply.run(dir)
            assert.equals("restore_failed", result().kind)
            assert.is_nil(mode(p.probation))
            assert.same(before, device())
            assert.equals("new\n", plugin_marker())
            assert.is_nil(mode(p.discard))
        end)

        it("only logs a failed purge of discard/ after the swap", function()
            device_fixture()
            local before = device()
            stage()
            PushApply.run(dir)
            local purge = PushApply._purge
            PushApply._purge = function(path)
                if path == p.discard and mode(path) then
                    error("kopanda-test: discard purge failed")
                end
                return purge(path)
            end
            PushApply.run(dir)
            PushApply._purge = purge
            assert.same(before, device())
            assert.equals("rolled_back", result().kind)
            assert.is_true(logged_error("kopanda-test: discard purge failed"))
            assert.is_nil(mode(p.probation))
        end)

        it("never renames onto an existing path itself", function()
            -- An assert here would raise inside run's pcalls and be swallowed, so a rename onto an
            -- existing path is recorded and checked after the runs.
            local renames, violations = 0, {}
            local move = PushApply._move
            PushApply._move = function(from, to)
                if mode(to) then
                    violations[#violations + 1] = to
                end
                renames = renames + 1
                return move(from, to)
            end
            device_fixture()
            write(p.settings .. ".old", "return {}\n")
            stage()
            PushApply.run(dir)
            write(p.result, "return {}\n")
            PushApply.run(dir)
            device_fixture()
            stage()
            PushApply.run(dir)
            assert.truthy(PushApply.clear_probation(dir))
            stage()
            PushApply.run(dir)
            PushApply.run(dir)
            assert.truthy(PushApply.arm(os.getenv("KOPANDA_ROOT") .. "/kopanda.koplugin", dir))
            assert.truthy(PushApply.arm(os.getenv("KOPANDA_ROOT") .. "/kopanda.koplugin", dir))
            assert.same({}, violations)
            assert.truthy(renames >= 12)
        end)
    end)

    describe("the module", function()
        local get_data_dir = DataStorage.getDataDir
        local loaded = package.loaded.push_apply

        after_each(function()
            DataStorage.getDataDir = get_data_dir
            package.loaded.push_apply = loaded
        end)

        it("changes nothing when required", function()
            device_fixture()
            stage()
            local before = tree(dir)
            DataStorage.getDataDir = function()
                return dir
            end
            package.loaded.push_apply = nil
            local module = require("push_apply")
            assert.is_function(module.run)
            assert.same(before, tree(dir))
        end)

        it("applies a stage when dofile'd as a patch", function()
            device_fixture()
            stage()
            mkdirs(p.patches)
            local patch = p.patches .. "/1-kopanda-apply.lua"
            write(patch, read(plugin_source))
            DataStorage.getDataDir = function()
                return dir
            end
            local returned = dofile(patch)
            assert.is_function(returned.run)
            assert.equals("new\n", plugin_marker())
            assert.equals("applied", result().kind)
        end)

        it("writes a result and raises nothing when the dofile'd run raises", function()
            device_fixture()
            stage()
            mkdirs(p.patches)
            local patch = p.patches .. "/1-kopanda-apply.lua"
            write(patch, read(plugin_source))
            local calls = 0
            DataStorage.getDataDir = function()
                calls = calls + 1
                if calls == 1 then
                    return false
                end
                return dir
            end
            local ok = pcall(dofile, patch)
            assert.is_true(ok)
            local outcome = result()
            assert.is_false(outcome.ok)
            assert.equals("failed", outcome.kind)
            assert.truthy(outcome.message:find("the apply patch failed", 1, true))
            assert.equals("old\n", plugin_marker())
        end)
    end)

    describe("arm", function()
        local plugin_dir = os.getenv("KOPANDA_ROOT") .. "/kopanda.koplugin"

        it("copies push_apply.lua to patches/1-kopanda-apply.lua", function()
            assert.is_true(PushApply.arm(plugin_dir, dir))
            assert.equals(read(plugin_source), read(p.patches .. "/1-kopanda-apply.lua"))
            assert.is_nil(mode(p.patches .. "/1-kopanda-apply.lua.tmp"))
        end)

        it("replaces an earlier patch", function()
            mkdirs(p.patches)
            write(p.patches .. "/1-kopanda-apply.lua", "-- an older build\n")
            assert.is_true(PushApply.arm(plugin_dir, dir))
            assert.equals(read(plugin_source), read(p.patches .. "/1-kopanda-apply.lua"))
        end)

        it("refuses when user patches are disabled", function()
            mkdirs(p.patches)
            write(p.patches .. "/.patches_disabled", "")
            local ok, err = PushApply.arm(plugin_dir, dir)
            assert.is_nil(ok)
            assert.truthy(err:find(".patches_disabled", 1, true))
            assert.is_nil(mode(p.patches .. "/1-kopanda-apply.lua"))
        end)

        it("refuses when the copy is short", function()
            local ffiUtil = require("ffi/util")
            local copy = ffiUtil.copyFile
            finally(function()
                ffiUtil.copyFile = copy
            end)
            ffiUtil.copyFile = function(_, to)
                write(to, "-- short\n")
            end
            local ok, err = PushApply.arm(plugin_dir, dir)
            assert.is_nil(ok)
            assert.is_string(err)
            assert.is_nil(mode(p.patches .. "/1-kopanda-apply.lua"))
            assert.is_nil(mode(p.patches .. "/1-kopanda-apply.lua.tmp"))
        end)
    end)

    describe("the plugin's side", function()
        it("reports, clears probation and takes the result once", function()
            assert.is_false(PushApply.probation(dir))
            assert.is_nil(PushApply.take_result(dir))
            mkdirs(p.push)
            write(p.probation, "return {}\n")
            write(p.result, "return { ok = true, kind = \"applied\", profile = \"vector\" }\n")
            assert.is_true(PushApply.probation(dir))
            assert.truthy(PushApply.clear_probation(dir))
            assert.is_false(PushApply.probation(dir))
            assert.same({ ok = true, kind = "applied", profile = "vector" }, PushApply.take_result(dir))
            assert.is_nil(mode(p.result))
            assert.is_nil(PushApply.take_result(dir))
        end)

        it("removes a result that doesn't load and returns nil", function()
            mkdirs(p.push)
            write(p.result, "return {")
            assert.is_nil(PushApply.take_result(dir))
            assert.is_nil(mode(p.result))
        end)
    end)
end)
