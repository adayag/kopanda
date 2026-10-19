-- The plates a look with plates (Frosted) sets its home rows and launcher tiles on: a keyline
-- round a ground that is the wallpaper beneath lightened toward paper, by an amount per palette
-- variant, or paper itself when no wallpaper is drawn. The ground is painted first and the
-- keyline after it, so both are solid, and the plate's widgets paint on top of both.
--
-- The lighten is KOReader's BlitBuffer:lightenRect, which blends white at that opacity over a
-- rectangle (base/ffi/blitbuffer.lua:2273-2283), here row by row inside a rounded keyline so the
-- corners outside it keep the wallpaper. Under KOReader's night mode on a panel that can't invert,
-- the screen's buffer stores every write inverted (base/ffi/framebuffer.lua:476-488), and the C
-- blitter skips a buffer so flagged (base/ffi/blitbuffer.lua:733-740) for a per-pixel Lua path. So
-- on a flagged buffer the flag is lifted for the plate and the stored pixels are darkened toward
-- black by the same amount with darkenRect (:2295-2306): lightening the inverse is darkening what
-- is stored, which is what the panel shows.
--
-- A named deviation from frosted.md, which washes the plate toward the paper: lightenRect and
-- darkenRect blend toward white and black, not toward a colour, so the day's plates go toward
-- white rather than the paper #fbfaf6 (a few levels lighter), and the night's toward black rather
-- than the night paper #1d1c22 (about 24 levels darker than it at 0.84). Grey's paper is white,
-- so there it is exact.
local Paint = require("paint")

local Plate = {}

-- The plate tokens of look for variant, in device pixels and KOReader colours: { lighten,
-- fill_color, keyline, keyline_color, radius }, lighten the variant's amount when wallpaper is
-- drawn (and fill_color nil), fill_color the plate's fill otherwise; nil for a look without
-- plates. color(role) gives a role's colour, scale(px) a board length's device pixels.
function Plate.spec(look, variant, wallpaper, color, scale)
    local tokens = look.plate
    if not tokens.fill_color then
        return nil
    end
    local lighten = wallpaper and tokens.lighten[variant] or nil
    return {
        lighten = lighten,
        fill_color = not lighten and color(tokens.fill_color) or nil,
        keyline = scale(tokens.keyline),
        keyline_color = color(tokens.keyline_color),
        radius = scale(tokens.radius),
    }
end

-- How far in from each side row i of a radius-r rounded rectangle starts, from the circle at
-- the row's middle.
local function inset(r, i)
    local dy = r - i - 0.5
    return math.floor(r - math.sqrt(math.max(0, r * r - dy * dy)) + 0.5)
end

-- Calls blend(x, y, w, h) over the w by h rectangle at x, y rounded by r: a span per row of the
-- top and bottom r rows, one rectangle between them.
local function spans(x, y, w, h, r, blend)
    for i = 0, r - 1 do
        local d = inset(r, i)
        blend(x + d, y + i, w - 2 * d, 1)
        blend(x + d, y + h - 1 - i, w - 2 * d, 1)
    end
    if h - 2 * r > 0 then
        blend(x, y + r, w, h - 2 * r)
    end
end

-- Lightens the rounded rectangle by by, as the panel will show it whether or not bb stores its
-- writes inverted.
local function lighten(bb, x, y, w, h, r, by)
    if bb:getInverse() ~= 1 then
        spans(x, y, w, h, r, function(sx, sy, sw, sh)
            bb:lightenRect(sx, sy, sw, sh, by)
        end)
        return
    end
    bb:setInverse(0)
    local ok, err = pcall(spans, x, y, w, h, r, function(sx, sy, sw, sh)
        bb:darkenRect(sx, sy, sw, sh, by)
    end)
    bb:setInverse(1)
    if not ok then
        error(err, 0)
    end
end

-- Paints a w by h plate at x, y in spec (Plate.spec), rounded by radius, or spec.radius when
-- radius is nil, at most half its shorter side (a pill): the ground, then the keyline. A lightened
-- ground stops inside the keyline, rounded by the radius less its width, so none of it shows past
-- the keyline's outer arc.
function Plate.paint(bb, x, y, w, h, spec, radius)
    if w <= 0 or h <= 0 then
        return
    end
    local r = math.min(radius or spec.radius or 0, math.floor(math.min(w, h) / 2))
    local k = spec.keyline_color and spec.keyline or 0
    if spec.lighten then
        if w - 2 * k > 0 and h - 2 * k > 0 then
            lighten(bb, x + k, y + k, w - 2 * k, h - 2 * k, math.max(0, r - k), spec.lighten)
        end
    elseif spec.fill_color then
        Paint.fill(bb, x, y, w, h, spec.fill_color, r)
    end
    if k > 0 then
        Paint.border(bb, x, y, w, h, k, spec.keyline_color, r)
    end
end

return Plate
