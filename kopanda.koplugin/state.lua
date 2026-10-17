-- KoPanda's runtime state: flags the plugin keeps between starts (the boot guard), in
-- settings/kopanda/state.lua. Not a setting: no schema entry, and the studio never sees it.
-- A missing or corrupt file reads as empty. Every call catches its own errors, and callers
-- treat a failure as the flag being absent.
-- Module state: the opened file, on first use.
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local State = {}

local settings

local function dir()
    return DataStorage:getSettingsDir() .. "/kopanda"
end

local function open()
    if not settings then
        settings = LuaSettings:open(dir() .. "/state.lua")
    end
    return settings
end

-- The stored value of key, or nil when it is absent or the file can't be read.
function State.get(key)
    local ok, value = pcall(function()
        return open():readSetting(key)
    end)
    if not ok then
        logger.err("KoPanda: could not read the state file:", value)
        return nil
    end
    return value
end

-- Whether a and b hold the same values: equal, or tables with the same keys whose values are
-- the same, all the way down.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for k, v in pairs(a) do
        if not same(v, b[k]) then
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

-- Stores value under key and writes the file at once, so the value survives a crash.
-- Returns true when written, false otherwise. LuaSettings:flush neither creates the directory
-- nor reports a failed write (frontend/luasettings.lua:270-275, frontend/util.lua:1131-1133),
-- so the directory is made and checked first, and the file is read back after, a table value
-- compared key by key.
function State.set(key, value)
    local ok, err = pcall(function()
        if lfs.attributes(dir(), "mode") ~= "directory" then
            lfs.mkdir(dir())
        end
        if lfs.attributes(dir(), "mode") ~= "directory" then
            error(dir() .. " is not a directory")
        end
        open():saveSetting(key, value):flush()
        local read_ok, data = pcall(dofile, dir() .. "/state.lua")
        if not (read_ok and type(data) == "table" and same(data[key], value)) then
            error("the file did not take " .. key)
        end
    end)
    if not ok then
        logger.err("KoPanda: could not write the state file:", err)
        return false
    end
    return true
end

return State
