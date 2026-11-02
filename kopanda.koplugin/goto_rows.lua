-- The Go to screen's rows: a chapter's title indented by its depth with its page at the right, right of the toggle
-- column in a nested list, where a parent shows its toggle; the current one with "You are here" under its title; and
-- a bookmark's chapter with its page at the right. They are drawn in the author rows' parts, padding and rule
-- (shelf_rows.lua's letter groups), the indent step the list's side; the text follows ctx.text_size.
local Geom = require("ui/geometry")
local Icons = require("icons")
local LibraryChrome = require("library_chrome")
local Looks = require("looks")
local Paint = require("paint")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")

local GotoRows = {}

local HERE = "You are here"

-- The rows' lengths under ctx in device pixels and their colourer.
local function metrics(ctx)
    local scale, color = Paint.scaler(ctx), Looks.colorer(ctx)
    local look = ctx.look
    local shelf, types = look.shelf, look.type
    local name_h = Typeset.line_height(types.author_name, ctx)
    local count_h = Typeset.line_height(types.author_count, ctx)
    return {
        color = color,
        pad_x = scale(shelf.author.padding.x),
        pad_y = scale(shelf.author.padding.y),
        rule = color(shelf.author.rule_color) and scale(shelf.author.rule_width) or 0,
        gap = scale(shelf.row.gap),
        line_gap = scale(shelf.row.line_gap),
        indent = scale(shelf.list.side),
        line_h = math.max(name_h, count_h),
        here_h = count_h,
    }
end

-- A row's height under ctx: kind is "chapter" or "bookmark", and a current chapter is a line taller.
function GotoRows.height(kind, is_current, ctx)
    local m = metrics(ctx)
    local h = 2 * m.pad_y + m.line_h + m.rule
    if kind == "chapter" and is_current then
        h = h + m.line_gap + m.here_h
    end
    return h
end

-- The toggle column's width under ctx: the tallest chapter row's height, so a toggle is at least as wide as its row
-- is tall.
function GotoRows.toggle_width(ctx)
    return GotoRows.height("chapter", true, ctx)
end

-- The toggle column's left edge in a row at depth under ctx: past the depth's indent.
function GotoRows.toggle_x(depth, ctx)
    return depth * metrics(ctx).indent
end

-- A row width wide and h tall: name in the name part from text_x, page in the count part ending at page_end, both
-- centred on the first line, then the rule at the foot.
local function row(name, page, text_x, h, width, m, ctx, page_end)
    local types = ctx.look.type
    local box = LibraryChrome.box(width, h)
    local right = Typeset.line(types.author_count, page, math.max(1, page_end - m.pad_x), ctx)
    local right_size = right:getSize()
    local right_x = page_end - right_size.w
    local left = Typeset.line(types.author_name, name, math.max(1, right_x - m.gap - text_x), ctx)
    LibraryChrome.add(box, left, text_x, m.pad_y + math.floor((m.line_h - left:getSize().h) / 2))
    LibraryChrome.add(box, right, right_x, m.pad_y + math.floor((m.line_h - right_size.h) / 2))
    if m.rule > 0 then
        LibraryChrome.add(box, Paint.Fill:new{ dimen = Geom:new{ w = width, h = m.rule },
            color = m.color(ctx.look.shelf.author.rule_color) }, 0, h - m.rule)
    end
    return box
end

-- chapter (GotoList.chapters' row) width wide under ctx, marked when is_current. In a nested list its title starts
-- past the toggle column, where a parent shows "▸", or "▾" when open. Returns it and its height.
function GotoRows.chapter(chapter, is_current, width, ctx, nested, open)
    local m = metrics(ctx)
    local h = GotoRows.height("chapter", is_current, ctx)
    local indent = chapter.depth * m.indent
    local column = nested and GotoRows.toggle_width(ctx) or m.pad_x
    local text_x = indent + column
    local box = row(chapter.title, chapter.page_label, text_x, h, width, m, ctx, width - m.pad_x)
    if nested and chapter.has_children then
        local size = m.line_h + m.pad_y
        local icon = TintedIcon:new{ file = Icons.path(open and "chevron_down" or "forward"), size = size,
            color = m.color(ctx.look.type.author_name.color) }
        LibraryChrome.add(box, icon, indent + math.floor((column - size) / 2),
            m.pad_y + math.floor((m.line_h - size) / 2))
    end
    if is_current then
        local here = Typeset.line(ctx.look.type.author_count, HERE, math.max(1, width - m.pad_x - text_x), ctx)
        LibraryChrome.add(box, here, text_x, m.pad_y + m.line_h + m.line_gap)
    end
    return box, h
end

-- entry's bookmark (GotoList.bookmarks' entry) width wide under ctx. Returns it and its height.
function GotoRows.bookmark(entry, width, ctx)
    local m = metrics(ctx)
    local h = GotoRows.height("bookmark", false, ctx)
    return row(entry.chapter, entry.page_label, m.pad_x, h, width, m, ctx, width - m.pad_x), h
end

return GotoRows
