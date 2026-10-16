-- bin/layout-fit's process: a headless KOReader (KOReader's spec/front/unit/commonrequire.lua: a
-- dummy screen and input, G_reader_settings under KO_HOME) whose screen is sized to the profile's,
-- then Layout.overflow for each row list read on stdin, under the ctx the home builds its rows
-- with (home_rows.lua:84-91) less home, which no widget's height reads.
--
--   luajit bin/layout-fit.lua <width> <height>    (run by bin/layout-fit, which sets the rest)
--
-- The DPI arrives as EMULATE_READER_DPI, which ffi/framebuffer.lua:128 reads when it loads and
-- fb:getDPI answers (:364-380). Without a "screen_dpi" override it doesn't enter scaleBySize
-- (:414-425), as on the emulator's captures. The answer is written to file descriptor 3.
local width, height = tonumber(arg[1]), tonumber(arg[2])
local out = assert(io.open("/dev/fd/3", "w"))

local function fail(message)
    io.stderr:write("bin/layout-fit: ", message, "\n")
    os.exit(1)
end

local ok, err = xpcall(function()
    require("ffi/loadlib")
    require("commonrequire")
    local rapidjson = require("rapidjson")

    -- commonrequire's dummy framebuffer is a 600x800 blitbuffer (ffi/framebuffer_SDL3.lua:18-20)
    -- and the screen's width and height are its blitbuffer's (ffi/framebuffer.lua:344-354). It is
    -- replaced before any plugin module or ui/size, which scales its lengths once when it loads
    -- (frontend/ui/size.lua), is required.
    local BB = require("ffi/blitbuffer")
    local Screen = require("device").screen
    Screen.bb:free()
    Screen.bb = BB.new(width, height)
    Screen.screen_size = Screen:getRawSize()

    local Layout = require("layout")
    local Looks = require("looks")
    local Schema = require("schema")
    local Settings = require("settings")

    local entry
    for _, key in ipairs(Schema.keys) do
        if key.id == "layout.rows" then
            entry = key
        end
    end

    local function is_array(value)
        local mt = type(value) == "table" and getmetatable(value)
        return mt and mt.__jsontype == "array"
    end

    local input = rapidjson.decode(io.read("*a"))
    if not is_array(input) then
        fail("input is not a JSON array of row lists")
    end
    for _, rows in ipairs(input) do
        if not is_array(rows) then
            fail("input is not a JSON array of row lists")
        end
    end
    for i, rows in ipairs(input) do
        if not Settings.validators.rows(entry, rows) then
            fail("row list " .. i .. " is not a layout the plugin accepts")
        end
    end

    local ctx = {
        look = Looks.active(),
        variant = Looks.variant(),
        text_size = Settings.get("text_size"),
        now = os.time(),
        screen = Screen,
    }
    local overflow = {}
    for i, rows in ipairs(input) do
        overflow[i] = Layout.overflow(rows, ctx)
    end
    out:write(rapidjson.encode({
        screen = { width = Screen:getWidth(), height = Screen:getHeight() },
        overflow = rapidjson.array(overflow),
    }), "\n")
    out:close()
end, debug.traceback)

if not ok then
    fail(tostring(err))
end
