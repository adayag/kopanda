--[[--
KoPanda's apply patch, and the module the plugin uses to arm it and read what it did.

Required by main.lua, this file returns its functions and does nothing else. Copied by `arm` to
<data>/patches/1-kopanda-apply.lua it is an early user patch: KOReader dofile()s it under pcall
before G_reader_settings is opened and before any plugin loads (frontend/userpatch.lua:84-92,
reader.lua:25-27, :39-40), and it runs `run` on the data folder. `require` calls the chunk with
the module name and `dofile` with nothing, which is how the two uses are told apart.

`run` applies a stage the pull left in settings/kopanda/push/ (the plugin folder swapped, the
settings file replaced unless the stage is plugin-only, a release's, whose record's settings is
false, the other shells disabled), puts the install on probation until its home paints, and
restores the previous install at the next start when it never did. Every outcome
goes to push/result.lua, which the plugin shows; an early patch's error is only logged by
KOReader (frontend/userpatch.lua:89-100), so none escapes this file.

Only modules that load before G_reader_settings exists are required here.
--]]
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local dump = require("dump")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local PushApply = {}

local FORMAT = 1
local PATCH = "1-kopanda-apply.lua"
local PLUGIN_SUFFIX = "/kopanda.koplugin"

-- The push folder and every path the patch reads or writes, under data_dir.
function PushApply.paths(data_dir)
    local kopanda = data_dir .. "/settings/kopanda"
    local push = kopanda .. "/push"
    return {
        push = push,
        download = push .. "/download",
        staged = push .. "/staged",
        staged_record = push .. "/staged.lua",
        rollback = push .. "/rollback",
        probation = push .. "/probation.lua",
        result = push .. "/result.lua",
        discard = push .. "/discard",
        kopanda = kopanda,
        settings = kopanda .. "/settings.lua",
        state = kopanda .. "/state.lua",
        reader = data_dir .. "/settings.reader.lua",
        patches = data_dir .. "/patches",
    }
end

-- Whether anything is at path, a link included and never followed.
local function exists(path)
    return lfs.symlinkattributes(path, "mode") ~= nil
end

local function mode(path)
    return lfs.symlinkattributes(path, "mode")
end

-- Raises err unless ok, so a helper that returns nil, err can stop a step.
local function must(ok, err)
    if not ok then
        error(tostring(err), 0)
    end
    return ok
end

local function remove_if_present(path)
    if exists(path) then
        must(os.remove(path))
    end
end

local function make_dir(path)
    if mode(path) ~= "directory" then
        must(lfs.mkdir(path))
    end
end

-- A table from a record file: loaded with an empty environment, so it can only build data.
-- Returns the table, or nil and why.
local function read_record(path)
    local f, open_err = io.open(path, "rb")
    if not f then
        return nil, "could not open " .. path .. ": " .. tostring(open_err)
    end
    local chunk = f:read("*a")
    f:close()
    if not chunk then
        return nil, "could not read " .. path
    end
    local loader, load_err = load(chunk, "=" .. path, "t", {})
    if not loader then
        return nil, tostring(load_err)
    end
    local ok, value = pcall(loader)
    if not ok then
        return nil, tostring(value)
    end
    if type(value) ~= "table" then
        return nil, path .. " does not return a table"
    end
    return value
end

-- Removes path and, for a folder, everything in it, without following links: a link is removed,
-- never its target. Returns true, or nil and why.
function PushApply._purge(path)
    local kind = mode(path)
    if kind == nil then
        return true
    end
    if kind ~= "directory" then
        return os.remove(path)
    end
    for name in lfs.dir(path) do
        if name ~= "." and name ~= ".." then
            local ok, err = PushApply._purge(path .. "/" .. name)
            if not ok then
                return nil, err
            end
        end
    end
    return lfs.rmdir(path)
end

-- Renames from to to, refusing when to exists, so no rename this file makes replaces anything.
function PushApply._move(from, to)
    if exists(to) then
        error("could not move " .. from .. ": " .. to .. " exists", 0)
    end
    local ok, err = os.rename(from, to)
    if not ok then
        error("could not move " .. from .. " to " .. to .. ": " .. tostring(err), 0)
    end
end

-- Writes value to path as a Lua table: to a temporary name, synced, then renamed onto path once
-- path is removed.
function PushApply._write_record(path, value)
    local tmp = path .. ".tmp"
    local f, open_err = io.open(tmp, "wb")
    if not f then
        error("could not write " .. tmp .. ": " .. tostring(open_err), 0)
    end
    local written, write_err = f:write("return " .. dump(value, nil, true) .. "\n")
    if written then
        ffiUtil.fsyncOpenedFile(f)
    end
    f:close()
    if not written then
        os.remove(tmp)
        error("could not write " .. tmp .. ": " .. tostring(write_err), 0)
    end
    remove_if_present(path)
    PushApply._move(tmp, path)
    ffiUtil.fsyncDirectory(path)
end

-- One level of table equality, for reading back what a flush wrote.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for k, v in pairs(a) do
        if b[k] ~= v then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

-- Sets key in the LuaSettings file at file (deletes it for nil) and flushes as KOReader does.
-- flush ignores a failed write (frontend/luasettings.lua:270-275), so the file is read back.
local function set_setting(file, key, value)
    local settings = LuaSettings:open(file)
    if value == nil then
        settings:delSetting(key)
    else
        settings:saveSetting(key, value)
    end
    settings:flush()
    local ok, data = pcall(dofile, file)
    if not (ok and type(data) == "table" and same(data[key], value)) then
        error(file .. " did not take " .. key, 0)
    end
end

-- Sets key in KOReader's settings.reader.lua (deletes it for nil).
function PushApply._set_reader_key(paths, key, value)
    set_setting(paths.reader, key, value)
end

-- Sets key in KoPanda's runtime state file, making settings/kopanda/ first as state.lua does.
local function set_state(paths, key, value)
    make_dir(paths.kopanda)
    set_setting(paths.state, key, value)
end

local function write_result(paths, outcome)
    PushApply._write_record(paths.result, outcome)
end

-- Removes the stage's record, then its folder; a failure is only logged.
local function purge_stage(paths)
    for _, path in ipairs{ paths.staged_record, paths.staged } do
        local ok, err = pcall(function()
            must(PushApply._purge(path))
        end)
        if not ok then
            logger.err("KoPanda: the apply patch could not remove", path, err)
        end
    end
end

-- Runs f; on an error raises "<what>: <error>".
local function step(what, f)
    local ok, err = pcall(f)
    if not ok then
        error(what .. ": " .. tostring(err), 0)
    end
end

local function valid_plugin_dir(plugin_dir)
    return type(plugin_dir) == "string" and plugin_dir:sub(1, 1) == "/"
        and plugin_dir:sub(-#PLUGIN_SUFFIX) == PLUGIN_SUFFIX
end

-- Whether the stage's record carries the settings file: true unless its settings is false. A
-- record from before plugin-only stages has no settings and carries it.
local function carries_settings(record)
    return record.settings ~= false
end

-- The stage's record when the stage is complete, or nil, why and whatever record loaded.
local function check_stage(paths)
    local record, err = read_record(paths.staged_record)
    if not record then
        return nil, "the stage's record doesn't load: " .. err
    end
    if record.format ~= FORMAT then
        return nil, "the stage's format is " .. tostring(record.format) .. ", not " .. FORMAT, record
    end
    if not valid_plugin_dir(record.plugin_dir) then
        return nil, "the plugin folder " .. tostring(record.plugin_dir) .. " is not an absolute path ending "
            .. PLUGIN_SUFFIX, record
    end
    if mode(record.plugin_dir) ~= "directory" then
        return nil, "the plugin folder " .. record.plugin_dir .. " is not a folder", record
    end
    if type(record.disable) ~= "table" then
        return nil, "the stage's disable list is not a list", record
    end
    for _, name in ipairs(record.disable) do
        if type(name) ~= "string" then
            return nil, "the stage's disable list holds a non-name", record
        end
    end
    if record.settings ~= nil and type(record.settings) ~= "boolean" then
        return nil, "the stage's settings is not true or false", record
    end
    local required = { "plugin/main.lua", "plugin/_meta.lua" }
    if carries_settings(record) then
        required[#required + 1] = "settings.lua"
    end
    for _, rel in ipairs(required) do
        if mode(paths.staged .. "/" .. rel) ~= "file" then
            return nil, "the stage has no " .. rel, record
        end
    end
    return record
end

local function profile_of(record)
    if record and type(record.profile) == "string" then
        return record.profile
    end
end

local function hash_of(record)
    if record and type(record.hash) == "string" then
        return record.hash
    end
end

-- Puts back the install rollback/record.lua describes. Idempotent: a restore cut short is
-- finished by the next start. The shells come back first, and every step after that is tried
-- even when an earlier one failed. Writes kind and message as the result when every step
-- worked, restore_failed otherwise.
local function restore(paths, kind, message)
    local record, err = read_record(paths.rollback .. "/record.lua")
    if record and not valid_plugin_dir(record.plugin_dir) then
        record, err = nil, "the rollback record's plugin folder is " .. tostring(record.plugin_dir)
    end
    if not record then
        logger.err("KoPanda: the apply patch can't restore:", err)
        -- Nothing could ever restore, so the next start is not to try.
        remove_if_present(paths.probation)
        write_result(paths, { ok = false, kind = "restore_failed",
            message = "the rollback record doesn't load: " .. err })
        return
    end
    local plugin_dir = record.plugin_dir
    local rollback_plugin = paths.rollback .. "/plugin"
    local rollback_settings = paths.rollback .. "/settings.lua"
    local failures = {}
    local function try(what, f)
        local ok, step_err = pcall(f)
        if not ok then
            logger.err("KoPanda: the apply patch could not restore " .. what .. ":", step_err)
            failures[#failures + 1] = "could not restore " .. what .. " (" .. tostring(step_err) .. ")"
        end
    end
    try("plugins_disabled", function()
        local value
        if record.had_plugins_disabled then
            value = record.plugins_disabled
        end
        PushApply._set_reader_key(paths, "plugins_disabled", value)
    end)
    try("the plugin folder", function()
        if mode(rollback_plugin) ~= "directory" then
            return
        end
        if exists(plugin_dir) then
            must(PushApply._purge(paths.discard))
            PushApply._move(plugin_dir, paths.discard)
        end
        PushApply._move(rollback_plugin, plugin_dir)
        local ok, purge_err = pcall(function()
            must(PushApply._purge(paths.discard))
        end)
        if not ok then
            logger.err("KoPanda: the apply patch could not remove the replaced plugin folder:", purge_err)
        end
    end)
    try("the settings file", function()
        -- A plugin-only apply never touched it, nor its .old.
        if record.settings_untouched then
            return
        end
        if exists(rollback_settings) then
            remove_if_present(paths.settings)
            PushApply._move(rollback_settings, paths.settings)
        elseif not record.had_settings then
            remove_if_present(paths.settings)
        end
        -- The new install's flush may have made a .old, which LuaSettings:open reads when the
        -- file is absent (frontend/luasettings.lua:36-40).
        if not record.had_settings_old then
            remove_if_present(paths.settings .. ".old")
        end
    end)
    try("boot_pending", function()
        set_state(paths, "boot_pending", false)
    end)
    local outcome = { ok = false, profile = profile_of(record), hash = hash_of(record) }
    if #failures > 0 then
        outcome.kind = "restore_failed"
        outcome.message = table.concat(failures, "; ")
        write_result(paths, outcome)
        return
    end
    -- Probation goes first: once it is gone the restore is done, whatever else is left.
    remove_if_present(paths.probation)
    purge_stage(paths)
    local ok, purge_err = pcall(function()
        must(PushApply._purge(paths.rollback))
    end)
    if not ok then
        logger.err("KoPanda: the apply patch could not remove the rollback set:", purge_err)
    end
    outcome.kind = kind
    outcome.message = message
    write_result(paths, outcome)
end

-- A restore that catches its own errors into a restore_failed result.
local function guarded_restore(paths, kind, message)
    local ok, err = pcall(restore, paths, kind, message)
    if not ok then
        logger.err("KoPanda: the apply patch's restore failed:", err)
        write_result(paths, { ok = false, kind = "restore_failed", message = tostring(err) })
    end
end

local function apply(paths)
    -- 1. The stage is complete and its record sound.
    local record, why, loaded = check_stage(paths)
    if not record then
        logger.err("KoPanda: the apply patch refused the stage:", why)
        purge_stage(paths)
        write_result(paths, { ok = false, kind = "failed", profile = profile_of(loaded), hash = hash_of(loaded),
            message = why })
        return
    end
    local plugin_dir = record.plugin_dir
    local rollback_plugin = paths.rollback .. "/plugin"
    local rollback_settings = paths.rollback .. "/settings.lua"
    local staged_settings = paths.staged .. "/settings.lua"
    local had_settings = exists(paths.settings)
    local settings = carries_settings(record)

    -- 2-4. The rollback set and probation; nothing has moved yet.
    local prepared, prepare_err = pcall(function()
        must(PushApply._purge(paths.rollback))
        make_dir(paths.rollback)
        local plugins_disabled = LuaSettings:open(paths.reader):readSetting("plugins_disabled")
        PushApply._write_record(paths.rollback .. "/record.lua", {
            profile = record.profile,
            hash = record.hash,
            plugin_dir = plugin_dir,
            had_settings = had_settings,
            had_settings_old = exists(paths.settings .. ".old"),
            settings_untouched = not settings,
            had_plugins_disabled = plugins_disabled ~= nil,
            plugins_disabled = plugins_disabled,
        })
        PushApply._write_record(paths.probation, {
            profile = record.profile,
            hash = record.hash,
            at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })
    end)
    if not prepared then
        logger.err("KoPanda: the apply patch could not prepare the rollback:", prepare_err)
        local ok, err = pcall(remove_if_present, paths.probation)
        if not ok then
            logger.err("KoPanda: the apply patch could not remove probation:", err)
        end
        purge_stage(paths)
        write_result(paths, { ok = false, kind = "failed", profile = profile_of(record), hash = hash_of(record),
            message = "could not prepare the rollback: " .. tostring(prepare_err) })
        return
    end

    -- 5-8. The swap; a failure undoes it at once.
    local swapped, swap_err = pcall(function()
        step("could not swap the plugin folder", function()
            PushApply._move(plugin_dir, rollback_plugin)
            PushApply._move(paths.staged .. "/plugin", plugin_dir)
        end)
        step("could not replace the settings file", function()
            if not settings then
                return
            end
            if had_settings then
                PushApply._move(paths.settings, rollback_settings)
            end
            PushApply._move(staged_settings, paths.settings)
        end)
        step("could not set plugins_disabled", function()
            local disabled = {}
            local current = LuaSettings:open(paths.reader):readSetting("plugins_disabled")
            if type(current) == "table" then
                for name, value in pairs(current) do
                    disabled[name] = value
                end
            end
            for _, name in ipairs(record.disable) do
                disabled[name] = true
            end
            PushApply._set_reader_key(paths, "plugins_disabled", disabled)
        end)
        step("could not clear boot_pending", function()
            set_state(paths, "boot_pending", false)
        end)
    end)
    if not swapped then
        logger.err("KoPanda: the apply patch failed, restoring:", swap_err)
        guarded_restore(paths, "failed", tostring(swap_err))
        return
    end

    -- 9. Applied and on probation; what follows is only logged when it fails.
    local finish = {
        { "write the result", function()
            write_result(paths, { ok = true, kind = "applied", profile = record.profile, hash = record.hash })
        end },
        { "remove staged.lua", function()
            must(PushApply._purge(paths.staged_record))
        end },
        { "remove staged/", function()
            must(PushApply._purge(paths.staged))
        end },
    }
    for _, part in ipairs(finish) do
        local ok, err = pcall(part[2])
        if not ok then
            logger.err("KoPanda: the apply patch could not " .. part[1] .. ":", err)
        end
    end
end

-- Every start: restores an install left on probation, applies a stage, or does nothing. Errors
-- are logged and written as the result, never raised.
function PushApply.run(data_dir)
    local paths = PushApply.paths(data_dir)
    local ok, err = pcall(function()
        if exists(paths.probation) then
            guarded_restore(paths, "rolled_back")
            return
        end
        if not exists(paths.staged_record) then
            return
        end
        apply(paths)
    end)
    if not ok then
        logger.err("KoPanda: the apply patch failed:", err)
        local written, write_err = pcall(write_result, paths, { ok = false, kind = "failed", message = tostring(err) })
        if not written then
            logger.err("KoPanda: the apply patch could not write its result:", write_err)
        end
    end
end

-- Copies plugin_dir's push_apply.lua to <data_dir>/patches/1-kopanda-apply.lua through a temporary
-- name. copyFile ignores write errors (base/ffi/util.lua:223-241), so the copy's size is checked.
-- Returns true, or nil and a message.
function PushApply.arm(plugin_dir, data_dir)
    local paths = PushApply.paths(data_dir)
    if exists(paths.patches .. "/.patches_disabled") then
        return nil, "user patches are disabled (patches/.patches_disabled)"
    end
    local ok, err = pcall(function()
        make_dir(paths.patches)
        local source = plugin_dir .. "/push_apply.lua"
        local target = paths.patches .. "/" .. PATCH
        local tmp = target .. ".tmp"
        local copy_err = ffiUtil.copyFile(source, tmp)
        local size = lfs.attributes(source, "size")
        if copy_err ~= nil or size == nil or lfs.attributes(tmp, "size") ~= size then
            os.remove(tmp)
            error("could not copy the apply patch: " .. tostring(copy_err or "the copy is incomplete"), 0)
        end
        remove_if_present(target)
        PushApply._move(tmp, target)
        ffiUtil.fsyncDirectory(target)
    end)
    if not ok then
        return nil, tostring(err)
    end
    return true
end

-- Whether an install is on probation in data_dir.
function PushApply.probation(data_dir)
    return exists(PushApply.paths(data_dir).probation)
end

-- Ends probation. Returns true, or nil and why.
function PushApply.clear_probation(data_dir)
    local path = PushApply.paths(data_dir).probation
    if not exists(path) then
        return true
    end
    return os.remove(path)
end

-- The last result, removed so it is reported once; nil when there is none or it doesn't load.
function PushApply.take_result(data_dir)
    local path = PushApply.paths(data_dir).result
    if not exists(path) then
        return nil
    end
    local outcome, err = read_record(path)
    must(os.remove(path))
    if not outcome then
        logger.err("KoPanda: could not read the pull's result:", err)
    end
    return outcome
end

-- dofile'd as the patch: no varargs. Required as a module: the module's name.
if select("#", ...) == 0 then
    local ok, err = pcall(function()
        PushApply.run(DataStorage:getDataDir())
    end)
    if not ok then
        -- Reached only when run could not start; the result says why.
        pcall(function()
            local f = io.open(DataStorage:getDataDir() .. "/settings/kopanda/push/result.lua", "wb")
            if f then
                f:write("return { ok = false, kind = \"failed\", message = ",
                    string.format("%q", "the apply patch failed: " .. tostring(err)), " }\n")
                f:close()
            end
        end)
        pcall(logger.err, "KoPanda: the apply patch failed:", err)
    end
end

return PushApply
