-- The weather: Open-Meteo's current conditions for the weather.location setting in its units,
-- kept in settings/kopanda/weather.lua, and the line the weather widget draws from it.
-- The cache is runtime state like state.lua: not a setting, no schema entry, never read by the
-- studio. A fetch blocks the UI for its duration, so it runs only after the home's first paint,
-- once per process when connected, on NetworkConnected until one succeeds, and on a tap.
-- Module state: whether a fetch was attempted in this process, and how many have succeeded.
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local Settings = require("settings")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local rapidjson = require("rapidjson")
local socketutil = require("socketutil")

local Weather = {}

local attempted = false
local successes = 0

local NO_READING = "Weather needs Wi\u{2011}Fi" -- U+2011, as the board writes it (EmptyStates.dc.html:25)

-- WMO weather interpretation codes (open-meteo.com/en/docs) to plain words.
local CONDITIONS = { [0] = "Clear", [1] = "Mainly clear", [2] = "Partly cloudy", [3] = "Overcast",
    [45] = "Fog", [48] = "Fog" }
local function condition_range(first, last, word)
    for code = first, last do
        CONDITIONS[code] = word
    end
end
condition_range(51, 57, "Drizzle")
condition_range(61, 67, "Rain")
condition_range(71, 77, "Snow")
condition_range(80, 82, "Showers")
condition_range(85, 86, "Snow showers")
condition_range(95, 99, "Thunderstorm")

local function dir()
    return DataStorage:getSettingsDir() .. "/kopanda"
end

local function cache_path()
    return dir() .. "/weather.lua"
end

-- The forecast URL for location ({ name, latitude, longitude }) in units ("fahrenheit" or
-- "celsius"). Coordinates have five places, so the URL for a place never changes.
function Weather.url(location, units)
    return string.format("https://api.open-meteo.com/v1/forecast?latitude=%.5f&longitude=%.5f"
        .. "&current=temperature_2m,weather_code,is_day&temperature_unit=%s&timezone=auto",
        location.latitude, location.longitude, units)
end

-- The current conditions in a decoded response, or nil when they are missing or not numbers.
local function current_of(data)
    local current = type(data) == "table" and data.current
    if type(current) ~= "table" then
        return nil
    end
    for _, field in ipairs({ "temperature_2m", "weather_code", "is_day" }) do
        if type(current[field]) ~= "number" then
            return nil
        end
    end
    return current
end

-- The response body for url, or nil and why not. socket.http is looked up here, not at load,
-- so a spec can stub it. socketutil's timeouts are reset on every path, a raising request
-- included (frontend/socketutil.lua:52-70; the pattern of frontend/ui/wikipedia.lua:146-215).
local function get(url)
    local chunks = {}
    local http = require("socket.http")
    socketutil:set_timeout(5, 10)
    local ok, _, code, headers = pcall(http.request, {
        url = url,
        method = "GET",
        sink = socketutil.table_sink(chunks),
    })
    socketutil:reset_timeout()
    if not ok then
        return nil, "the request raised: " .. tostring(code)
    end
    if headers == nil then
        return nil, "no response: " .. tostring(code)
    end
    if code ~= 200 then
        return nil, "HTTP status " .. tostring(code)
    end
    return table.concat(chunks)
end

-- Fetches the current conditions for the stored location and units and caches them. Returns
-- true on success; false, logged, on any failure, leaving the cache as it was.
function Weather.fetch()
    local ok, err = pcall(function()
        local location, units = Settings.get("weather.location"), Settings.get("weather.units")
        local body, why = get(Weather.url(location, units))
        if not body then
            error(why, 0)
        end
        local decoded_ok, data = pcall(rapidjson.decode, body)
        local current = decoded_ok and current_of(data)
        if not current then
            error("the response has no current temperature, code and day flag", 0)
        end
        if lfs.attributes(dir(), "mode") ~= "directory" then
            lfs.mkdir(dir())
        end
        if lfs.attributes(dir(), "mode") ~= "directory" then
            error(dir() .. " is not a directory", 0)
        end
        -- LuaSettings:flush doesn't create the directory (frontend/luasettings.lua:270-275).
        LuaSettings:open(cache_path()):reset({
            fetched_at = os.time(),
            temperature = current.temperature_2m,
            weather_code = current.weather_code,
            is_day = current.is_day,
            units = units,
            latitude = location.latitude,
            longitude = location.longitude,
        }):flush()
    end)
    if not ok then
        logger.warn("KoPanda: could not update the weather:", err)
        return false
    end
    return true
end

-- The cached reading when it is for the stored units and coordinates; nil when there is none,
-- it is unreadable, or the location or units have changed since.
function Weather.reading()
    local ok, data = pcall(function()
        return LuaSettings:open(cache_path()).data
    end)
    if not ok or type(data) ~= "table" then
        return nil
    end
    for _, field in ipairs({ "fetched_at", "temperature", "weather_code", "is_day", "latitude", "longitude" }) do
        if type(data[field]) ~= "number" then
            return nil
        end
    end
    local location = Settings.get("weather.location")
    if data.units ~= Settings.get("weather.units") or data.latitude ~= location.latitude
            or data.longitude ~= location.longitude then
        return nil
    end
    return data
end

-- The line the widget draws for reading at now in the look look_id: "Partly cloudy, 61°" in
-- Editorial (Main.dc.html:25), "61° partly cloudy" in Diner (HomeRetro.dc.html:48-51), the
-- temperature alone for an unknown code, then " · 3 h ago" once the reading is an hour old
-- (" · 2 d ago" from two days); with no reading, "Weather needs Wi‑Fi".
function Weather.line(reading, now, look_id)
    if not reading then
        return NO_READING
    end
    local degrees = string.format("%d°", math.floor(reading.temperature + 0.5))
    local condition = CONDITIONS[reading.weather_code]
    local text
    if not condition then
        text = degrees
    elseif look_id == "diner" then
        text = degrees .. " " .. condition:lower()
    else
        text = condition .. ", " .. degrees
    end
    local age = now - reading.fetched_at
    if age >= 48 * 3600 then
        text = text .. string.format(" · %d d ago", math.floor(age / 86400))
    elseif age >= 3600 then
        text = text .. string.format(" · %d h ago", math.floor(age / 3600))
    end
    return text
end

-- NetworkMgr, looked up at call time so a spec can stub it.
local function network()
    return require("ui/network/manager")
end

-- One fetch, recorded for the session's triggers; the home is rebuilt on success.
local function run(home)
    attempted = true
    if not Weather.fetch() then
        return false
    end
    successes = successes + 1
    home:refresh()
    return true
end

-- After the home's first paint: one fetch per process, when connected. isConnected has no
-- prompt and no network I/O; isOnline would resolve a hostname (frontend/ui/network/manager.lua:641-648).
function Weather.after_show(home)
    if attempted or not network():isConnected() then
        return
    end
    run(home)
end

-- On NetworkConnected (frontend/ui/network/manager.lua:109, :154): a fetch while connected,
-- until one has succeeded this process.
function Weather.on_connected(home)
    if successes > 0 or not network():isConnected() then
        return
    end
    run(home)
end

-- A tap on the weather: a fetch now when connected; otherwise once online, which may ask to
-- turn Wi-Fi on as the user's wifi_enable_action says (frontend/ui/network/manager.lua:605-618,
-- :698-709). NetworkMgr broadcasts NetworkConnected before it runs the callback (:109, :116),
-- so the callback skips its fetch when one has succeeded since the tap. A failed fetch says so
-- for 3 s.
function Weather.tap(home)
    local successes_at_tap = successes
    local function fetch_now()
        if successes > successes_at_tap then
            return
        end
        if not run(home) then
            UIManager:show(InfoMessage:new{ text = "Couldn't update the weather", timeout = 3 })
        end
    end
    local NetworkMgr = network()
    if NetworkMgr:isConnected() then
        fetch_now()
    else
        NetworkMgr:runWhenOnline(fetch_now)
    end
end

return Weather
