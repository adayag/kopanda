-- bin/preview's process: a headless KOReader (KOReader's spec/front/unit/commonrequire.lua, its DataStorage under
-- the scratch KO_HOME) where the plugin's own Settings reads the copied settings file for the weather location and
-- units, then the dev loop's driver.capture of the home with the populated home fixture. On success the PNG is
-- copied to <out.png> and the answer's JSON line written to $KO_HOME/result.json; on failure the message alone
-- goes to stderr and the exit status is 1. A look no look table holds fails before the capture.
--   luajit bin/preview.lua <width> <height> <dpi> <color|grey> <look> <day|night> <out.png> [settings copy]
local width, height, dpi = tonumber(arg[1]), tonumber(arg[2]), tonumber(arg[3])
local color, look, variant, out_png, settings_file = arg[4] == "color", arg[5], arg[6], arg[7], arg[8]
local ko_home = os.getenv("KO_HOME")
local root = os.getenv("KOPANDA_ROOT")

local ok, err = pcall(function()
    require("ffi/loadlib")
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local rapidjson = require("rapidjson")
    local driver = require("emulator.driver")
    local Looks = require("looks")
    local Settings = require("settings")

    if not Looks.get(look) then
        error("no look " .. look .. "; the looks are " .. table.concat(Looks.ids(), ", "), 0)
    end

    local location = Settings.get("weather.location")
    local units = Settings.get("weather.units")

    local out_dir = ko_home .. "/capture"
    assert(lfs.mkdir(out_dir))
    local result = driver.capture{
        profile = "preview",
        device = { width = width, height = height, dpi = dpi, color = color },
        settings_file = settings_file,
        plugin_dir = root .. "/kopanda.koplugin",
        patches = { root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua" },
        night_mode = variant == "night",
        out_dir = out_dir,
        env = {
            TZ = "America/Chicago",
            KOPANDA_HOME_FIXTURE = "populated",
            KOPANDA_HOME_LOOK = look,
            KOPANDA_HOME_WEATHER_LATITUDE = string.format("%.17g", location.latitude),
            KOPANDA_HOME_WEATHER_LONGITUDE = string.format("%.17g", location.longitude),
            KOPANDA_HOME_WEATHER_UNITS = units,
        },
    }

    local src = assert(io.open(result.png, "rb"))
    local png = src:read("*a")
    src:close()
    local dst, open_err = io.open(out_png, "wb")
    if not dst then
        error("cannot write " .. out_png .. ": " .. tostring(open_err), 0)
    end
    assert(dst:write(png))
    dst:close()

    local answer = assert(io.open(ko_home .. "/result.json", "w"))
    answer:write(rapidjson.encode({
        png = out_png,
        width = result.width,
        height = result.height,
        paint_ms = result.sidecar.paint_ms,
    }), "\n")
    answer:close()
end)

if not ok then
    -- The message alone: the position error() puts before it (the driver's file and line) goes.
    local message = tostring(err):gsub("^[^\n]-%.lua:%d+: ", "", 1)
    io.stderr:write(message, "\n")
    os.exit(1)
end
os.exit(0)
