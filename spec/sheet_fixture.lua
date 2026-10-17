-- Helpers shared by the sheet's spec (spec/unit/sheet_spec.lua): gestures, pixel reads of a
-- painted buffer, the Colorsoft's screen, sheet specs to show, and spies. Each reads the plugin's
-- modules at call time, so it sees the ones the spec's harness.load() left loaded.
local harness = require("plugin_harness")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Screen = Device.screen

local function send(ges)
    UIManager:sendEvent(Event:new("Gesture", ges))
end

local function centre(rect)
    return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
end

-- { r, g, b } of a #rrggbb; the grey KOReader draws a TextWidget in for it
-- (frontend/ui/widget/textwidget.lua:369); and the per-channel inverse of that grey.
local function rgb(hex)
    local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
    return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

local function grey(hex)
    local v = Blitbuffer.colorFromString(hex):getColor8().a
    return { v, v, v }
end

local function inverse_grey(hex)
    local v = 255 - Blitbuffer.colorFromString(hex):getColor8().a
    return { v, v, v }
end

local function near(a, b, tolerance)
    return math.abs(a[1] - b[1]) <= tolerance and math.abs(a[2] - b[2]) <= tolerance
        and math.abs(a[3] - b[3]) <= tolerance
end

local function pixel(bb, x, y)
    local c = bb:getPixel(x, y):getColorRGB32()
    return { c:getR(), c:getG(), c:getB() }
end

-- Every pixel of rect in bb, passed to f.
local function each_pixel(bb, rect, f)
    for y = rect.y, rect.y + rect.h - 1 do
        for x = rect.x, rect.x + rect.w - 1 do
            f(pixel(bb, x, y))
        end
    end
end

-- A white w by h RGB32 buffer, its inverse flag set when night.
local function buffer(w, h, night)
    local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
    bb:fill(Blitbuffer.COLOR_WHITE)
    if night then
        bb:invert()
    end
    return bb
end

-- The Colorsoft's screen, 1264 by 1680, scaled as KOReader scales it by its size
-- (base/ffi/framebuffer.lua:414).
local colorsoft = setmetatable({
    getWidth = function() return 1264 end,
    getHeight = function() return 1680 end,
    getSize = function() return Geom:new{ x = 0, y = 0, w = 1264, h = 1680 } end,
}, { __index = Screen })

-- The shown home's ctx in look id, on screen (default: the device's).
local function ctx_for(id, screen)
    local ctx = {}
    for k, v in pairs(package.loaded["home"].shown.ctx) do
        ctx[k] = v
    end
    ctx.look = package.loaded["looks"].get(id)
    ctx.variant = package.loaded["looks"].variant()
    ctx.screen = screen or Screen
    return ctx
end

-- A heading sheet of three rows: a plain detail, a status chip and a muted row. runs[i]
-- counts row i's taps; shown[i] is Sheet.shown when row i ran.
local function three_rows(runs, shown)
    runs, shown = runs or {}, shown or {}
    local function counter(i)
        return function()
            runs[i] = (runs[i] or 0) + 1
            shown[i] = package.loaded["sheet"].shown or false
        end
    end
    return {
        name = "test",
        band = "home",
        header = { heading = "Home", aside = "KoPanda" },
        rows = {
            { icon = "sun", label = "Refresh weather", detail = "20 min ago", run = counter(1) },
            { icon = "bookmark", label = "Read status", detail = "Reading", chip = "status", run = counter(2) },
            { icon = "moon", label = "Sleep", detail = "not available", muted = true, run = counter(3) },
        },
    }
end

-- Wraps t[name] to record each call's arguments as passed (a spy keeps copies), then call
-- through. Returns the calls and a function that restores t[name].
local function record(t, name)
    local original, calls = t[name], {}
    t[name] = function(...)
        calls[#calls + 1] = { ... }
        return original(...)
    end
    return calls, function()
        t[name] = original
    end
end

local function sheets_on_stack()
    local count = 0
    for _, widget in ipairs(harness.stack()) do
        if widget.name == "kopanda_sheet" then
            count = count + 1
        end
    end
    return count
end

-- A stand-in for a book's cover widget, counting its paints and frees; get_size, if given,
-- replaces its getSize.
local function stub_cover(get_size)
    local cover = { paints = 0, frees = 0 }
    cover.getSize = get_size or function() return Geom:new{ w = 40, h = 60 } end
    cover.paintTo = function()
        cover.paints = cover.paints + 1
    end
    cover.free = function()
        cover.frees = cover.frees + 1
    end
    return cover
end

local function book_sheet(cover)
    local spec = three_rows()
    spec.band = "book"
    spec.header = { cover = cover, title = "A book", author = "An author", meta = "12%" }
    return spec
end

-- How many of the calls spied on logger.warn carry text.
local function warnings(warned, text)
    local count = 0
    for _, call in ipairs(warned.calls) do
        for _, arg in ipairs(call.vals) do
            if tostring(arg):find(text, 1, true) then
                count = count + 1
            end
        end
    end
    return count
end

return {
    send = send,
    centre = centre,
    rgb = rgb,
    grey = grey,
    inverse_grey = inverse_grey,
    near = near,
    pixel = pixel,
    each_pixel = each_pixel,
    buffer = buffer,
    colorsoft = colorsoft,
    ctx_for = ctx_for,
    three_rows = three_rows,
    record = record,
    sheets_on_stack = sheets_on_stack,
    stub_cover = stub_cover,
    book_sheet = book_sheet,
    warnings = warnings,
}
