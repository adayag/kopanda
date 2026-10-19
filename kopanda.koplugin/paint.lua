-- Fills and borders that keep a colour's hue, the box a widget paints around its content, a plain fill
-- widget, and board pixels scaled to the screen's. A colour goes through the RGB32 variants, since the plain
-- ones grey it (base/ffi/blitbuffer.lua:1704-1724, :1827, :2096, :2118-2126, :2169-2197).
local Blitbuffer = require("ffi/blitbuffer")
local Widget = require("ui/widget/widget")

local Paint = {}

-- A filled rectangle. With no radius it is painted square through paintRect; with one, even 0,
-- through paintRoundedRect, which rounds its rectangle up to whole pixels first.
function Paint.fill(bb, x, y, w, h, color, radius)
    local color8 = Blitbuffer.isColor8(color)
    if radius == nil then
        if color8 then
            bb:paintRect(x, y, w, h, color)
        else
            bb:paintRectRGB32(x, y, w, h, color)
        end
    elseif color8 then
        bb:paintRoundedRect(x, y, w, h, color, radius)
    else
        bb:paintRoundedRectRGB32(x, y, w, h, color, radius)
    end
end

-- A border width wide inside the rectangle, its corners rounded by radius when one is given.
function Paint.border(bb, x, y, w, h, width, color, radius)
    if Blitbuffer.isColor8(color) then
        bb:paintBorder(x, y, w, h, width, color, radius)
    else
        bb:paintBorderRGB32(x, y, w, h, width, color, radius)
    end
end

-- A w by h box at x, y has a shadow (shadow_color offset by shadow_x and shadow_y, rounded by radius; with a
-- shadow_outline above 0 a border that wide), a fill (fill_color, rounded by fill_radius) and an outline
-- (outline wide in outline_color, rounded by radius). A box without a colour paints no shadow or fill. The
-- widget paints backing, then its content, then outline.
function Paint.backing(bb, x, y, w, h, box)
    if box.shadow_color then
        local sx, sy = x + box.shadow_x, y + box.shadow_y
        if box.shadow_outline and box.shadow_outline > 0 then
            Paint.border(bb, sx, sy, w, h, box.shadow_outline, box.shadow_color, box.radius)
        else
            Paint.fill(bb, sx, sy, w, h, box.shadow_color, box.radius)
        end
    end
    if box.fill_color then
        Paint.fill(bb, x, y, w, h, box.fill_color, box.fill_radius)
    end
end

function Paint.outline(bb, x, y, w, h, box)
    if box.outline > 0 then
        Paint.border(bb, x, y, w, h, box.outline, box.outline_color, box.radius)
    end
end

-- A plain fill of dimen in color, rounded by radius, square without one; nothing at a width of 0
-- or without a colour.
Paint.Fill = Widget:extend{
    name = "kopanda_fill",
}

function Paint.Fill:paintTo(bb, x, y)
    if self.dimen.w > 0 and self.color then
        Paint.fill(bb, x, y, self.dimen.w, self.dimen.h, self.color, self.radius)
    end
end

-- Board pixels to device pixels on ctx's screen.
function Paint.scaler(ctx)
    return function(px)
        return ctx.screen:scaleBySize(px)
    end
end

-- A negative length, an overhang, scaled as its size is, so a corner overhangs as far as it insets.
function Paint.scale_signed(scale, px)
    if px < 0 then
        return -scale(-px)
    end
    return scale(px)
end

return Paint
