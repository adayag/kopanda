-- One line of home text set in a look's type part ({ face, size, uppercase, tracking, line_height, color } from
-- look.type), and the height-then-build pairing the text widgets share, so a widget is built once per show.
-- KOReader's TextWidget has no letter spacing, so a tracked line is set glyph by glyph, a TextWidget per
-- character; one too wide for its width is set as one untracked TextWidget cut with KOReader's ellipsis.
-- Every line keeps its colour: TextWidget:paintTo blits its glyphs through colorblitFrom
-- (frontend/ui/widget/textwidget.lua:369), which reduces a colour to getColor8A, a luminance grey
-- (base/ffi/blitbuffer.lua:1405-1407, :489-491). So each TextWidget a line holds paints its shaped glyphs
-- itself, as TextWidget:paintTo does (textwidget.lua:338-378), through colorblitFromRGB32
-- (base/ffi/blitbuffer.lua:1422-1437). A paint that raises is logged once and falls back to TextWidget:paintTo
-- in the colour's grey.
local Blitbuffer = require("ffi/blitbuffer")
local Fonts = require("fonts")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Layout = require("layout")
local Looks = require("looks")
local RenderText = require("ui/rendertext")
local TextWidget = require("ui/widget/textwidget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

-- Typeset.fitted's step down in size and the size it stops at.
local FIT_STEP = 2
local FIT_MIN_SIZE = 14
local logger = require("logger")
local util = require("util")

local Typeset = {}

-- The face of part under ctx. Raises when the font won't load, so the home blanks the slot.
local function face_of(part, ctx)
    local file = ctx.look.faces[part.face].file
    local face = Fonts.face(file, Layout.font_size(part.size, ctx.text_size))
    if not face then
        error("the font " .. tostring(file) .. " didn't load")
    end
    return face
end

-- The forced height and baseline that set a line at part's line height in face. At line height 0, none: the
-- face's own (frontend/ui/widget/textwidget.lua:112-114). Otherwise (1 + line_height) em, rounded, as
-- TextBoxWidget sizes its lines (frontend/ui/widget/textboxwidget.lua:151), the face's height centred in it
-- as CSS shares out the leading (TextBoxWidget centres only when taller, :153-158). TextWidget reports a
-- forced height and paints at a forced baseline (textwidget.lua:43-44, :298, :362).
local function forced(part, face)
    if part.line_height == 0 then
        return nil, nil
    end
    local height = math.floor((1 + part.line_height) * face.size + 0.5)
    local face_height, face_ascender = face.ftsize:getHeightAndAscender()
    return height, math.floor(face_ascender + (height - face_height) / 2)
end

-- A colour through a mask: a grey, an RGB one with equal channels included, through colorblitFrom,
-- as TextWidget paints (its getColor8A of such a grey is the grey itself), a colour through
-- colorblitFromRGB32, which keeps its hue (base/ffi/blitbuffer.lua:1405-1437, :489-491).
local function blit(bb, source, x, y, w, h, color)
    if not Blitbuffer.isColor8(color) then
        local rgb = color:getColorRGB32()
        if rgb.r == rgb.g and rgb.g == rgb.b then
            color = color:getColor8()
        end
    end
    if Blitbuffer.isColor8(color) then
        bb:colorblitFrom(source, x, y, 0, 0, w, h, color)
    else
        bb:colorblitFromRGB32(source, x, y, 0, 0, w, h, color)
    end
end

-- text's shaped glyphs at x, y in color, as TextWidget:paintTo draws them
-- (frontend/ui/widget/textwidget.lua:338-378) but keeping a colour's hue. A TextWidget without
-- xtext is left to TextWidget:paintTo, in the grey it gives.
function Typeset.paint_glyphs(text, bb, x, y, color)
    text:updateSize()
    if text._is_empty then
        return
    end
    if not text.use_xtext then
        local fgcolor = text.fgcolor
        text.fgcolor = color
        TextWidget.paintTo(text, bb, x, y)
        text.fgcolor = fgcolor
        return
    end
    if not text._xshaping then
        text._xshaping = text._xtext:shapeLine(text._shape_start, text._shape_end,
            text._shape_idx_to_substitute_with_ellipsis)
    end
    local text_width = bb:getWidth() - x
    if text.max_width and text.max_width < text_width then
        text_width = text.max_width
    end
    local pen_x = 0
    local baseline = text.forced_baseline or text._baseline_h
    for _, xglyph in ipairs(text._xshaping) do
        if pen_x >= text_width then
            break
        end
        local face = text.face.getFallbackFont(xglyph.font_num)
        local glyph = RenderText:getGlyphByIndex(face, xglyph.glyph, text.bold)
        blit(bb, glyph.bb, x + pen_x + glyph.l + xglyph.x_offset, y + baseline - glyph.t - xglyph.y_offset,
            glyph.bb:getWidth(), glyph.bb:getHeight(), color)
        pen_x = pen_x + xglyph.x_advance
    end
end

-- Whether a failed paint has been logged: once a process, as every line on a KOReader whose
-- TextWidget internals differ fails alike.
local warned = false

-- A paint's failure, logged the first time.
local function warn_once(err)
    if not warned then
        warned = true
        logger.warn("KoPanda: painting a line in its colour failed:", err)
    end
end

-- A TextWidget's paintTo: its glyphs in its fgcolor. When Typeset.paint_glyphs fails, TextWidget:paintTo
-- paints the line in that colour's grey.
local function paint_text(self, bb, x, y)
    local ok, err = pcall(Typeset.paint_glyphs, self, bb, x, y, self.fgcolor)
    if ok then
        return
    end
    warn_once(err)
    TextWidget.paintTo(self, bb, x, y)
end

-- The text widget self[1], made black on white, printed through its mask in self.color. The mask is the
-- text painted on white and inverted, so its ink is white (base/ffi/blitbuffer.lua:1506, :1567), made at the
-- first paint and freed with the widget. Used for a TextBoxWidget on a plate (Typeset.printed), whose ground
-- must show between its glyphs.
local Masked = WidgetContainer:extend{
    name = "kopanda_masked",
}

function Masked:paintTo(bb, x, y)
    if not self.mask then
        local size = self[1]:getSize()
        if size.w <= 0 or size.h <= 0 then
            return
        end
        local mask = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BB8)
        mask:fill(Blitbuffer.COLOR_WHITE)
        self[1]:paintTo(mask, 0, 0)
        mask:invertRect(0, 0, size.w, size.h)
        self.mask = mask
    end
    blit(bb, self.mask, x, y, self.mask:getWidth(), self.mask:getHeight(), self.color)
end

function Masked:free()
    if self.mask then
        self.mask:free()
        self.mask = nil
    end
    WidgetContainer.free(self)
end

-- Whether text under ctx is printed on a plate (a look with plates, looks/frosted.lua), whose
-- ground, the wallpaper lightened, shows between its glyphs.
function Typeset.on_plate(ctx)
    return ctx.look.plate.fill_color and true or false
end

-- The widget make(width, fgcolor, bgcolor) builds for part under ctx, at most max_width wide: a TextBoxWidget,
-- which keeps a colour itself and fills its box with bgcolor (frontend/ui/widget/textboxwidget.lua:854-906),
-- made in part's colour on paper; a part on a plate is made black on white and printed through Masked, so the
-- plate's ground shows between its glyphs.
function Typeset.printed(part, max_width, ctx, make)
    local palette = Looks.palette(ctx.look, ctx.variant)
    local color = Looks.color(palette[part.color])
    if not Typeset.on_plate(ctx) then
        return make(max_width, color, Looks.color(palette.paper))
    end
    local text = make(max_width, Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE)
    local size = text:getSize()
    return Masked:new{
        dimen = Geom:new{ w = size.w, h = size.h },
        color = color,
        text,
    }
end

-- text in part under ctx, at most max_width wide, in color: a TextWidget, or a HorizontalGroup of
-- one TextWidget per character when the part is tracked.
local function plain_line(part, text, max_width, ctx, color)
    local face = face_of(part, ctx)
    local forced_height, forced_baseline = forced(part, face)
    if part.uppercase then
        text = text:upper()
    end
    -- face.size is the size in device pixels (frontend/ui/font.lua:276), so the tracking in em
    -- becomes pixels by it.
    local gap = math.floor(part.tracking * face.size + 0.5)
    if gap ~= 0 then
        local group = HorizontalGroup:new{ align = "bottom", allow_mirroring = false }
        for i, char in ipairs(util.splitToChars(text)) do
            if i > 1 then
                group[#group + 1] = HorizontalSpan:new{ width = gap }
            end
            group[#group + 1] = TextWidget:new{
                text = char,
                face = face,
                fgcolor = color,
                forced_height = forced_height,
                forced_baseline = forced_baseline,
            }
        end
        if group:getSize().w <= max_width then
            return group
        end
        group:free()
    end
    local line = TextWidget:new{
        text = text,
        face = face,
        fgcolor = color,
        max_width = max_width,
        forced_height = forced_height,
        forced_baseline = forced_baseline,
    }
    -- Measured now: TextWidget:paintTo measures first (textwidget.lua:339), but a patch that
    -- replaces it may not (Bookends' bookends_textwidget_patch.lua shapes a colour fgcolor's
    -- glyphs from _xtext straight away), and a line is often painted without being asked its size.
    line:updateSize()
    return line
end

-- text in part under ctx, at most max_width wide: plain_line's line in part's colour, each of its
-- TextWidgets painting its glyphs in their own colour (paint_text).
function Typeset.line(part, text, max_width, ctx)
    local color = Looks.color(Looks.palette(ctx.look, ctx.variant)[part.color])
    local line = plain_line(part, text, max_width, ctx, color)
    if getmetatable(line) == TextWidget then
        line.paintTo = paint_text
        return line
    end
    for _, child in ipairs(line) do
        if getmetatable(child) == TextWidget then
            child.paintTo = paint_text
        end
    end
    return line
end

-- Whether a line from Typeset.line shows its whole text: a tracked line is a group only when it fits, and a
-- TextWidget says when it cut its text (frontend/ui/widget/textwidget.lua:307).
function Typeset.whole(line)
    return getmetatable(line) ~= TextWidget or not line:isTruncated()
end

-- texts set in part, at its size or the largest smaller one, a step at a time down to FIT_MIN_SIZE, that sets
-- every text whole in max_width, so they read at one size; and that part.
function Typeset.fitted(part, texts, max_width, ctx)
    local sized = {}
    for k, v in pairs(part) do
        sized[k] = v
    end
    while true do
        local lines, fits = {}, true
        for i, text in ipairs(texts) do
            lines[i] = Typeset.line(sized, text, max_width, ctx)
            fits = fits and Typeset.whole(lines[i])
        end
        if fits or sized.size <= FIT_MIN_SIZE then
            return lines, sized
        end
        for _, line in ipairs(lines) do
            line:free()
        end
        sized.size = math.max(FIT_MIN_SIZE, sized.size - FIT_STEP)
    end
end

-- The height of part's line under ctx: its face's or its forced one, whatever its text
-- (frontend/ui/widget/textwidget.lua:112-113, :292-299), so one sample measures every line of a part.
function Typeset.line_height(part, ctx)
    local line = Typeset.line(part, "Library", math.huge, ctx)
    local h = line:getSize().h
    line:free()
    return h
end

-- The y of the baseline of a line from Typeset.line, from the line's top. TextWidget:getBaseline
-- gives the face's baseline, not a forced one (textwidget.lua:312); a tracked line's glyphs share
-- one height and sit on the line's bottom.
function Typeset.baseline(line)
    if getmetatable(line) == TextWidget then
        return line.forced_baseline or line:getBaseline()
    end
    local glyph = line[1]
    return HorizontalGroup.getSize(line).h - glyph:getSize().h + Typeset.baseline(glyph)
end

-- A widget module's height, build and baseline for make(width, ctx), which returns its widget and the y of its
-- last line's baseline: height and baseline build the widget and keep it, and the build that follows for the
-- same width and ctx hands that one over, so the home builds each widget once.
function Typeset.measured(make)
    local kept
    local function keeps(width, ctx)
        return kept and kept.width == width and kept.ctx == ctx
    end
    local function keep(width, ctx)
        if not keeps(width, ctx) then
            if kept then
                kept.widget:free()
            end
            local widget, baseline = make(width, ctx)
            kept = { width = width, ctx = ctx, widget = widget, baseline = baseline }
        end
        return kept
    end
    local function height(width, ctx)
        return keep(width, ctx).widget:getSize().h
    end
    local function baseline(width, ctx)
        return keep(width, ctx).baseline
    end
    local function build(width, ctx)
        if keeps(width, ctx) then
            local widget = kept.widget
            kept = nil
            return widget
        end
        return (make(width, ctx))
    end
    return height, build, baseline
end

return Typeset
