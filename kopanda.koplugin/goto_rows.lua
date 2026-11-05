-- The Contents and Bookmarks rows, one height throughout: a chapter's title indented by its depth with its page at the
-- right, right of the toggle column in a nested list, where a parent shows its toggle; the current chapter's on an ink
-- fill; and a bookmark's chapter with its page at the right. The indent step is the list's side; the text follows
-- ctx.text_size.
local Geom = require("ui/geometry")
local Icons = require("icons")
local LibraryChrome = require("library_chrome")
local Looks = require("looks")
local Paint = require("paint")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")

local GotoRows = {}

-- The rows' lengths under ctx in device pixels and their colourer.
local function metrics(ctx)
    local scale, color = Paint.scaler(ctx), Looks.colorer(ctx)
    local look = ctx.look
    local shelf, types = look.shelf, look.type
    local rule_color = color(shelf.author.rule_color)
    return {
        color = color,
        pad_x = scale(shelf.author.padding.x),
        pad_y = scale(shelf.reader_list.row_padding_y),
        rule = rule_color and scale(shelf.reader_list.rule_width) or 0,
        rule_color = rule_color,
        gap = scale(shelf.row.gap),
        indent = scale(shelf.list.side),
        line_h = math.max(Typeset.line_height(types.reader_list_row, ctx),
            Typeset.line_height(types.reader_list_current, ctx)),
    }
end

-- A row's height under ctx.
function GotoRows.height(ctx)
    local m = metrics(ctx)
    return 2 * m.pad_y + m.line_h + m.rule
end

-- The toggle column's width under ctx: a row's height, so a toggle is as wide as its row is tall.
function GotoRows.toggle_width(ctx)
    return GotoRows.height(ctx)
end

-- The toggle column's left edge in a row at depth under ctx: past the depth's indent.
function GotoRows.toggle_x(depth, ctx)
    return depth * metrics(ctx).indent
end

-- A row width wide and h tall: name from text_x and page ending at page_end, both centred on the line, then the rule
-- at the foot; on the ink fill in the current part when is_current.
local function row(name, page, text_x, h, width, m, ctx, page_end, is_current)
    local types = ctx.look.type
    local part = is_current and types.reader_list_current or types.reader_list_row
    local box = LibraryChrome.box(width, h)
    if is_current then
        LibraryChrome.add(box, Paint.Fill:new{ dimen = Geom:new{ w = width, h = h - m.rule }, color = m.color("ink") },
            0, 0)
    end
    local right = Typeset.line(part, page, math.max(1, page_end - m.pad_x), ctx)
    local right_size = right:getSize()
    local right_x = page_end - right_size.w
    local left = Typeset.line(part, name, math.max(1, right_x - m.gap - text_x), ctx)
    LibraryChrome.add(box, left, text_x, m.pad_y + math.floor((m.line_h - left:getSize().h) / 2))
    LibraryChrome.add(box, right, right_x, m.pad_y + math.floor((m.line_h - right_size.h) / 2))
    if m.rule > 0 then
        LibraryChrome.add(box, Paint.Fill:new{ dimen = Geom:new{ w = width, h = m.rule }, color = m.rule_color },
            0, h - m.rule)
    end
    return box
end

-- chapter (GotoList.chapters' row) width wide under ctx, marked when is_current. In a nested list its title starts
-- past the toggle column, where a parent shows "▸", or "▾" when open. Returns it and its height.
function GotoRows.chapter(chapter, is_current, width, ctx, nested, open)
    local m = metrics(ctx)
    local h = GotoRows.height(ctx)
    local indent = chapter.depth * m.indent
    local column = nested and GotoRows.toggle_width(ctx) or m.pad_x
    local box = row(chapter.title, chapter.page_label, indent + column, h, width, m, ctx, width - m.pad_x, is_current)
    if nested and chapter.has_children then
        local part = is_current and ctx.look.type.reader_list_current or ctx.look.type.reader_list_row
        local icon = TintedIcon:new{ file = Icons.path(open and "chevron_down" or "forward"), size = m.line_h,
            color = m.color(part.color) }
        LibraryChrome.add(box, icon, indent + math.floor((column - m.line_h) / 2), m.pad_y)
    end
    return box, h
end

-- entry's bookmark (GotoList.bookmarks' entry) width wide under ctx. Returns it and its height.
function GotoRows.bookmark(entry, width, ctx)
    local m = metrics(ctx)
    local h = GotoRows.height(ctx)
    return row(entry.chapter, entry.page_label, m.pad_x, h, width, m, ctx, width - m.pad_x), h
end

return GotoRows
