-- KoPanda's settings, in settings/kopanda/settings.lua, held to schema.lua: a read returns the
-- stored value when the key's type allows it and the schema default otherwise; a write outside
-- the schema is refused. The file carries schema_version beside the keys: an older file is
-- migrated on open (migrations.lua), a newer one is read but never written.
-- Every call catches its own errors: a failure is logged and reads as the default.
-- Module state: the opened file and whether it is read-only, on first use.
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local Migrations = require("migrations")
local Schema = require("schema")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local Settings = {}

-- One validator per type a schema key uses: validate(entry, value) is true when value is
-- allowed for entry.
Settings.validators = {
    choice = function(entry, value)
        for _, choice in ipairs(entry.choices) do
            if choice.value == value then
                return true
            end
        end
        return false
    end,
}

local entries = {}
for _, entry in ipairs(Schema.keys) do
    entries[entry.id] = entry
end

local settings
local read_only = false

local function dir()
    return DataStorage:getSettingsDir() .. "/kopanda"
end

local function path()
    return dir() .. "/settings.lua"
end

-- data brought from its schema_version (none is 1) to target by steps[v + 1] … steps[target],
-- then stamped with target.
local function migrate(data, steps, target)
    for version = (data.schema_version or 1) + 1, target do
        local step = assert(steps[version], "no migration step to schema version " .. version)
        data = step(data)
    end
    data.schema_version = target
    return data
end

-- The opened file. LuaSettings:open never raises: a missing file reads as {}, a corrupt one
-- falls back to .old then {} (frontend/luasettings.lua:21-48), but a file returning a non-table
-- is taken as the data (:32-33), so that reads as {} here. Not cached until the version is
-- handled, so a failed migration leaves the file alone and is retried on the next call.
local function open()
    if settings then
        return settings
    end
    local opened = LuaSettings:open(path())
    if type(opened.data) ~= "table" then
        opened:reset({})
    end
    local version = opened.data.schema_version or 1
    if version > Schema.version then
        read_only = true
        logger.warn("KoPanda: the settings file is from schema version " .. version
            .. ", newer than this plugin's " .. Schema.version .. "; it is read but not written")
    elseif version < Schema.version then
        opened:reset(migrate(opened.data, Migrations, Schema.version))
        opened:flush()
    end
    settings = opened
    return settings
end

-- The value of key: the stored one when its type allows it, the schema default otherwise.
-- nil, logged, for a key the schema doesn't define.
function Settings.get(key)
    local entry = entries[key]
    if not entry then
        logger.err("KoPanda: no setting named", key)
        return nil
    end
    local ok, value = pcall(function()
        local stored = open():readSetting(key)
        if stored ~= nil and Settings.validators[entry.type](entry, stored) then
            return stored
        end
    end)
    if not ok then
        logger.err("KoPanda: could not read the settings file:", value)
        value = nil
    end
    if value == nil then
        return entry.default
    end
    return value
end

-- Stores value under key, stamps schema_version and writes the file at once. Returns true when
-- written; false and the reason, writing nothing, for a key the schema doesn't define, a value
-- its type doesn't allow or a file from a newer schema; false and the error when the write
-- fails. LuaSettings:flush neither creates the directory nor reports a failed write
-- (frontend/luasettings.lua:270-275, frontend/util.lua:1124-1143), so the directory is made
-- and checked first, and the file is read back after.
function Settings.set(key, value)
    local entry = entries[key]
    if not entry then
        return false, "no setting named " .. tostring(key)
    end
    local valid_ok, valid = pcall(Settings.validators[entry.type], entry, value)
    if not (valid_ok and valid) then
        return false, tostring(value) .. " is not allowed for " .. key
    end
    local opened, previous, previous_version
    local ok, err = pcall(function()
        opened = open()
        if read_only then
            error("the settings file is from a newer schema version than "
                .. Schema.version .. ", so it is not written", 0)
        end
        if lfs.attributes(dir(), "mode") ~= "directory" then
            lfs.mkdir(dir())
        end
        if lfs.attributes(dir(), "mode") ~= "directory" then
            error(dir() .. " is not a directory", 0)
        end
        previous = { value = opened.data[key] }
        previous_version = opened.data.schema_version
        opened:saveSetting(key, value):saveSetting("schema_version", Schema.version):flush()
        local read_ok, data = pcall(dofile, path())
        if not (read_ok and type(data) == "table" and data[key] == value
                and data.schema_version == Schema.version) then
            error("the file did not take " .. key, 0)
        end
    end)
    if not ok then
        -- Reads keep what they saw before the failed write.
        if previous then
            opened.data[key] = previous.value
            opened.data.schema_version = previous_version
        end
        logger.err("KoPanda: could not write the settings file:", err)
        return false, err
    end
    return true
end

-- For the spec: the migration runner with injected steps.
Settings._migrate = migrate

-- For the spec: forget the opened file, so the next call opens it again.
function Settings._reset()
    settings = nil
    read_only = false
end

return Settings
