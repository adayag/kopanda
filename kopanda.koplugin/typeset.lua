-- One line of home text set in a look's type part ({ face, size, uppercase, tracking,
-- line_height, color } from look.type): its face at the text size, its palette colour, its case,
-- its tracking and its line height. And the height-then-build pairing the text widgets share, so a
-- widget is built once per show.
--
-- KOReader's TextWidget has no letter spacing, so a tracked line is set glyph by glyph, a
-- TextWidget per character with the tracking between them. Built and painted on the emulator's
-- LuaJIT, a label costs at most 0.3 ms that way at twice the boards' sizes, against 0.1-0.7 ms as
-- one TextWidget, well under the 5 ms the task allowed. A tracked line too wide for its width is
-- set as one TextWidget instead, untracked and cut with KOReader's ellipsis.
local Fonts = require("fonts")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Layout = require("layout")
local Looks = require("looks")
local TextWidget = require("ui/widget/textwidget")
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

-- The forced height and baseline that set a line at part's line height in face. At line height
-- 0, none: the face's own height and baseline (frontend/ui/widget/textwidget.lua:112-114).
-- Otherwise (1 + line_height) em, rounded, as TextBoxWidget sizes its lines
-- (frontend/ui/widget/textboxwidget.lua:151), with the face's height centred in it, as CSS shares
-- out the leading whether the line is taller or shorter than the face (TextBoxWidget centres it
-- only when taller, :153-158). TextWidget reports a forced height and paints at a forced
-- baseline (textwidget.lua:43-44, :298, :362).
local function forced(part, face)
    if part.line_height == 0 then
        return nil, nil
    end
    local height = math.floor((1 + part.line_height) * face.size + 0.5)
    local face_height, face_ascender = face.ftsize:getHeightAndAscender()
    return height, math.floor(face_ascender + (height - face_height) / 2)
end

-- text in part under ctx, at most max_width wide: a TextWidget, or a HorizontalGroup of one
-- TextWidget per character when the part is tracked.
function Typeset.line(part, text, max_width, ctx)
    local face = face_of(part, ctx)
    local color = Looks.color(Looks.palette(ctx.look, ctx.variant)[part.color])
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

-- The y of the baseline of a line from Typeset.line, from the line's top. TextWidget:getBaseline
-- gives the face's baseline, not a forced one (textwidget.lua:312); a tracked line's glyphs share
-- one height and sit on the line's bottom.
function Typeset.baseline(line)
    if getmetatable(line) == TextWidget then
        return line.forced_baseline or line:getBaseline()
    end
    local glyph = line[1]
    return line:getSize().h - glyph:getSize().h + Typeset.baseline(glyph)
end

-- A widget module's height, build and baseline for make(width, ctx), which returns its widget
-- and the y of its last line's baseline from the widget's top: height and baseline build the
-- widget and keep it, and the build for the same width and ctx that follows hands that one over,
-- so the home builds each widget once.
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
