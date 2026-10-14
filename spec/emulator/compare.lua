-- Pixel comparison of a capture against its golden. Both PNGs are decoded to 8-bit RGB, so
-- the emulator's RGBA captures and grey images compare alike and alpha never enters.
local ffi = require("ffi")
local BB = require("ffi/blitbuffer")
local Png = require("ffi/png")

local M = {}

M.defaults = { tolerance = 16, max_fraction = 0.0005 }

-- Png.decodeFromFile with 3 components converts every colour type to RGB
-- (base/ffi/png.lua:97-98) and hands back lodepng's malloc'd buffer (png.lua:110-115).
-- Wrapping it in a blitbuffer marked allocated lets free() release it, as
-- Pic.openPNGDocument does (base/ffi/pic.lua:341-345).
local function load(path)
    local ok, image = Png.decodeFromFile(path, 3)
    if not ok then
        error("compare: cannot read " .. path .. ": " .. tostring(image))
    end
    local bb = BB.new(image.width, image.height, BB.TYPE_BBRGB24, image.data)
    bb:setAllocated(1)
    return { width = image.width, height = image.height, data = image.data, bb = bb }
end

-- One byte per pixel, 1 inside any mask; masks are clipped to the image. Returns the map
-- and the number of masked pixels, or nil when no mask covers any pixel.
local function mask_map(masks, w, h)
    if not masks or #masks == 0 then
        return nil, 0
    end
    local map = ffi.new("uint8_t[?]", w * h)
    local masked = 0
    for _, m in ipairs(masks) do
        local x0, y0 = math.max(0, m.x), math.max(0, m.y)
        local x1, y1 = math.min(w, m.x + m.w), math.min(h, m.y + m.h)
        for y = y0, y1 - 1 do
            for x = x0, x1 - 1 do
                local i = y * w + x
                if map[i] == 0 then
                    map[i] = 1
                    masked = masked + 1
                end
            end
        end
    end
    if masked == 0 then
        return nil, 0
    end
    return map, masked
end

-- The golden faded to light grey, with every differing pixel solid red.
local function write_diff(path, golden, differs, w, h)
    local out = ffi.new("uint8_t[?]", w * h * 3)
    local g = golden.data
    for i = 0, w * h - 1 do
        local o = i * 3
        if differs[i] == 1 then
            out[o], out[o + 1], out[o + 2] = 255, 0, 0
        else
            local lum = (g[o] * 299 + g[o + 1] * 587 + g[o + 2] * 114) / 1000
            local v = 191 + math.floor(lum / 4)
            out[o], out[o + 1], out[o + 2] = v, v, v
        end
    end
    local ok, err = Png.encodeToFile(path, out, w, h, 3)
    if not ok then
        error("compare: cannot write " .. path .. ": " .. tostring(err))
    end
end

-- opts: masks ({ {x=, y=, w=, h=}, ... } in pixels), tolerance (largest per-channel
-- difference still counted as equal), max_fraction (of compared pixels allowed to differ),
-- diff_png (path written when the compare fails on pixels).
-- Returns { ok, differing, compared, fraction, diff_png }, or on a size mismatch
-- { ok = false, reason = "size", actual = {w, h}, golden = {w, h} }.
function M.compare(actual_png, golden_png, opts)
    opts = opts or {}
    local tolerance = opts.tolerance or M.defaults.tolerance
    local max_fraction = opts.max_fraction or M.defaults.max_fraction

    local actual = load(actual_png)
    local golden = load(golden_png)
    if actual.width ~= golden.width or actual.height ~= golden.height then
        local result = { ok = false, reason = "size",
            actual = { actual.width, actual.height }, golden = { golden.width, golden.height } }
        actual.bb:free()
        golden.bb:free()
        return result
    end

    local w, h = golden.width, golden.height
    local map, masked = mask_map(opts.masks, w, h)
    local differs = ffi.new("uint8_t[?]", w * h)
    local a, g = actual.data, golden.data
    local differing = 0
    for i = 0, w * h - 1 do
        if not map or map[i] == 0 then
            local o = i * 3
            if math.abs(a[o] - g[o]) > tolerance
                or math.abs(a[o + 1] - g[o + 1]) > tolerance
                or math.abs(a[o + 2] - g[o + 2]) > tolerance then
                differs[i] = 1
                differing = differing + 1
            end
        end
    end

    local compared = w * h - masked
    local fraction = compared > 0 and differing / compared or 0
    local result = { ok = fraction <= max_fraction, differing = differing, compared = compared, fraction = fraction }
    if not result.ok and opts.diff_png then
        write_diff(opts.diff_png, golden, differs, w, h)
        result.diff_png = opts.diff_png
    end
    actual.bb:free()
    golden.bb:free()
    return result
end

return M
