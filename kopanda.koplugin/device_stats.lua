-- The device's own numbers. The battery's time left, from KOReader's Battery statistics file,
-- settings/battery_stats.lua (plugins/batterystat.koplugin/main.lua:17), read and never written: its totals are in that
-- plugin's shape (:138-147) and its times in fts (:51-55). The storage free on the home folder's disk
-- (frontend/util.lua:925, frontend/apps/filemanager/filemanagerutil.lua:25) and the memory KOReader uses, from
-- /proc/self/status (as frontend/document/document.lua:618 reads it), which only Linux has; a read that can't be had is
-- nil.
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local logger = require("logger")
local time = require("ui/time")
local util = require("util")

local DeviceStats = {}

local MIN_RECORD = 3600
local MAX_LEFT = 90 * 86400

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- The seconds left at percent, at the rate in totals (battery_stats.lua's table), as Usage:remainingTime works it
-- out (plugins/batterystat.koplugin/main.lua:69-73); nil on under MIN_RECORD of discharging, a malformed table, or
-- MAX_LEFT or more, which no record means.
function DeviceStats.time_left(percent, totals)
    local discharging = type(totals) == "table" and totals.discharging
    if type(discharging) ~= "table" or not finite(discharging.percentage) or not finite(discharging.time) then
        return nil
    end
    local seconds = time.to_s(discharging.time)
    if discharging.percentage <= 0 or seconds < MIN_RECORD then
        return nil
    end
    local left = percent * seconds / discharging.percentage
    if left >= MAX_LEFT then
        return nil
    end
    return left
end

function DeviceStats.left_text(seconds)
    if seconds >= 86400 then
        local days = math.floor(seconds / 86400)
        return "about " .. days .. (days == 1 and " day" or " days") .. " left"
    end
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        return "about " .. hours .. (hours == 1 and " hour" or " hours") .. " left"
    end
    return "under an hour left"
end

-- KOReader's Battery statistics totals, read and never written, or nil when they can't be read.
function DeviceStats.battery_totals()
    local ok, settings = pcall(LuaSettings.open, LuaSettings, DataStorage:getSettingsDir() .. "/battery_stats.lua")
    if not ok then
        logger.err("KoPanda: could not read the battery statistics:", settings)
        return nil
    end
    return settings.data
end

-- The bytes in VmRSS in text, /proc/self/status's contents, or nil without that line.
function DeviceStats.rss(text)
    local kb = type(text) == "string" and text:match("VmRSS:%s+(%d+)%s+kB")
    return kb and tonumber(kb) * 1024 or nil
end

function DeviceStats.memory()
    local f = io.open("/proc/self/status", "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return DeviceStats.rss(text)
end

function DeviceStats.storage()
    local ok, usage = pcall(function()
        return util.diskUsage(filemanagerutil.getHomeFolder())
    end)
    if not ok then
        logger.err("KoPanda: could not read the storage:", usage)
        return nil
    end
    return usage.available
end

return DeviceStats
