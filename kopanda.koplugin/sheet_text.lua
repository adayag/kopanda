-- The sheet's text block (sheet.lua's text): paragraphs set in a look's type parts, each wrapped in a TextBoxWidget
-- whose height_overflow_show_ellipsis ends it (frontend/ui/widget/textboxwidget.lua:53-54).
local Fonts = require("fonts")
local Layout = require("layout")
local Math = require("optmath")
local TextBoxWidget = require("ui/widget/textboxwidget")
local Typeset = require("typeset")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local SheetText = {}

-- paragraphs stacked width wide under ctx, gap apart, at most max_h tall: each keeps a line, and the room over goes to
-- the first that wants it, so a long highlight can't take its note's place. Raises when a font won't load.
function SheetText.block(paragraphs, width, max_h, gap, ctx)
    local room = max_h
    local set = {}
    for i, paragraph in ipairs(paragraphs) do
        local part = ctx.look.type[paragraph.part]
        local face = Fonts.face(ctx.look.faces[part.face].file, Layout.font_size(part.size, ctx.text_size))
        if not face then
            error("the font for the sheet's text didn't load")
        end
        -- As TextBoxWidget counts a line (textboxwidget.lua:151).
        local line_px = Math.round((1 + part.line_height) * face.size)
        set[i] = { part = part, face = face, line_px = line_px, text = paragraph.text }
        room = room - line_px - (i > 1 and gap or 0)
    end
    local group = VerticalGroup:new{ align = "left" }
    for i, p in ipairs(set) do
        if i > 1 then
            group[#group + 1] = VerticalSpan:new{ width = gap }
        end
        local lines = 1 + math.max(0, math.floor(room / p.line_px))
        local box = Typeset.printed(p.part, width, ctx, function(box_w, fgcolor, bgcolor)
            return TextBoxWidget:new{
                text = p.part.uppercase and p.text:upper() or p.text,
                face = p.face,
                width = box_w,
                line_height = p.part.line_height,
                fgcolor = fgcolor,
                bgcolor = bgcolor,
                height = lines * p.line_px,
                height_adjust = true,
                height_overflow_show_ellipsis = true,
            }
        end)
        group[#group + 1] = box
        room = room - (box:getSize().h - p.line_px)
    end
    return group
end

return SheetText
