-- One line of home text set in a look's type part ({ face, size, uppercase, tracking, color }
-- from look.type): its face at the text size, its palette colour, its case and its tracking.
-- And the height-then-build pairing the text widgets share, so a widget is built once per show.
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

-- text in part under ctx, at most max_width wide: a TextWidget, or a HorizontalGroup of one
-- TextWidget per character when the part is tracked.
function Typeset.line(part, text, max_width, ctx)
    local face = face_of(part, ctx)
    local color = Looks.color(ctx.look.palettes[ctx.variant][part.color])
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
            group[#group + 1] = TextWidget:new{ text = char, face = face, fgcolor = color }
        end
        if group:getSize().w <= max_width then
            return group
        end
        group:free()
    end
    return TextWidget:new{ text = text, face = face, fgcolor = color, max_width = max_width }
end

-- A widget module's height and build for make(width, ctx), which builds its widget: height
-- builds and keeps it, and the build for the same width and ctx that follows hands that one
-- over, so the home builds each widget once.
function Typeset.measured(make)
    local kept
    local function keeps(width, ctx)
        return kept and kept.width == width and kept.ctx == ctx
    end
    local function height(width, ctx)
        if not keeps(width, ctx) then
            if kept then
                kept.widget:free()
            end
            kept = { width = width, ctx = ctx, widget = make(width, ctx) }
        end
        return kept.widget:getSize().h
    end
    local function build(width, ctx)
        if keeps(width, ctx) then
            local widget = kept.widget
            kept = nil
            return widget
        end
        return make(width, ctx)
    end
    return height, build
end

return Typeset
