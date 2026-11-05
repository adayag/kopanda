-- The battery's time left, from KOReader's Battery statistics file, settings/battery_stats.lua
-- (plugins/batterystat.koplugin/main.lua:17), read and never written: its totals are in that plugin's shape (:138-147)
-- and its times in fts (:51-55).
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")
local time = require("ui/time")

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

return DeviceStats
