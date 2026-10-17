-- The library window's view: what it draws for a folder at a page (cover-grid "The window", "The
-- header", "The page", "The pager"), built as a frame the window (library.lua) puts in place, with
-- the parts its gestures and covers read. The header holds the count, "Library" or the back mark
-- and the folder's name, and the sort and status pickers; then two rows of three tiles
-- (library_tiles.lua) or the empty note, the pager, and the nav bar with Library active. What a
-- folder shows, in what order, is library_order.lua's. Lengths are board pixels scaled by the
-- screen, and the text ignores text_size (D12), as the tiles'.
local Books = require("books")
local FeaturedCover = require("featured_cover")
local Geom = require("ui/geometry")
local Icons = require("icons")
local LibraryOrder = require("library_order")
local LibraryTiles = require("library_tiles")
local Looks = require("looks")
local NavBar = require("nav_bar")
local Paint = require("paint")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local Widget = require("ui/widget/widget")
local ffiutil = require("ffi/util")
local Screen = require("device").screen

local LibraryView = {}

local SORT_LABELS = { recent = "Recent", title = "Title", author = "Author", series = "Series" }
local STATUS_LABELS = { reading = "Reading", finished = "Finished", all = "All" }
-- D17's notes for a folder with nothing to show under each status.
local EMPTY_NOTES = { all = "No books here", finished = "No finished books here", reading = "No books being read here" }

-- KOReader's home folder, the library's root (D7), as Books.folder reads it (books.lua:171-173).
function LibraryView.root()
    return require("apps/filemanager/filemanagerutil").getHomeFolder()
end

local function real(dir)
    return ffiutil.realpath(dir) or dir:gsub("(.)/+$", "%1")
end

-- Whether a and b name one folder, by their realpaths (or the paths themselves, trailing slashes
-- dropped, for a folder that isn't there).
function LibraryView.same_dir(a, b)
    return real(a) == real(b)
end

-- The folder dir is in.
function LibraryView.parent_of(dir)
    local parent = dir:gsub("(.)/+$", "%1"):match("^(.*)/[^/]*$")
    return parent == "" and "/" or parent or dir
end

local function name_of(dir)
    return dir:match("([^/]+)/*$") or dir
end

-- The count's words, as the file browser's title bar words its own (title_bar.lua:233-248, bars/
-- title-bar's D2), so the two headers read alike: "3 books", "1 book", "No books", and "on the
-- shelf" after them in a look whose title bar says so.
local function count_text(n, on_shelf)
    local text = n == 0 and "No books" or n == 1 and "1 book" or n .. " books"
    if on_shelf then
        text = text .. " on the shelf"
    end
    return text
end

-- Whether pos lies in rect, its right and bottom edges outside, as the nav bar tests its columns.
function LibraryView.inside(rect, pos)
    return pos.x >= rect.x and pos.x < rect.x + rect.w and pos.y >= rect.y and pos.y < rect.y + rect.h
end

-- A filled rectangle of its dimen in color.
local Fill = Widget:extend{
    name = "kopanda_library_fill",
    color = nil,
}

function Fill:paintTo(bb, x, y)
    Paint.fill(bb, x, y, self.dimen.w, self.dimen.h, self.color)
end

-- A box w by h in fill (a colour or nil) with an outline wide in outline_color, its children
-- painted at their places.
local function new_box(w, h, fill, outline, outline_color)
    return FeaturedCover.Box:new{
        dimen = Geom:new{ w = w, h = h },
        box_w = w,
        box_h = h,
        fill_color = fill,
        outline = outline or 0,
        outline_color = outline_color,
        places = {},
    }
end

-- Adds child to box at (x, y) from its top left; returns its index.
local function add(box, child, x, y)
    box[#box + 1] = child
    box.places[#box] = { x = x, y = y }
    return #box
end

-- The tools a build draws with under ctx: lengths scaled, roles as colours (nil for a role the
-- look lacks), and a part's line height, which is its face's whatever the text
-- (frontend/ui/widget/textwidget.lua:112-113).
local function tools(ctx)
    local palette = Looks.palette(ctx.look, ctx.variant)
    local function scale(px)
        return Screen:scaleBySize(px)
    end
    local function color(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
    local function line_height(part)
        local line = Typeset.line(part, "Library", math.huge, ctx)
        local h = line:getSize().h
        line:free()
        return h
    end
    return scale, color, line_height
end

-- A picker: its label in part, then the chevron_down mark sized to the label's line in the
-- label's colour, inside the header's picker padding and outline, on fill. Returns the chip and
-- { label, mark }.
local function picker(part, text, fill, ctx)
    local scale, color = tools(ctx)
    local tokens = ctx.look.library.header
    local outline_color = color(tokens.picker_outline_color)
    local outline = outline_color and scale(tokens.picker_outline_width) or 0
    local pad_x, pad_y = outline + scale(tokens.picker_padding.x), outline + scale(tokens.picker_padding.y)
    local label = Typeset.line(part, text, Screen:getWidth(), ctx)
    local size = label:getSize()
    local mark = TintedIcon:new{ file = Icons.path("chevron_down"), size = size.h, color = color(part.color) }
    local chip = new_box(size.w + size.h + 2 * pad_x, size.h + 2 * pad_y, color(fill), outline, outline_color)
    add(chip, label, pad_x, pad_y)
    add(chip, mark, pad_x + size.w, pad_y)
    return chip, { label = label, mark = mark }
end

-- The header, w wide, LibraryTiles.header_height tall (Main.dc.html:19-27, GridA.dc.html:19-27):
-- the count over the title at the left and the two pickers at the right, both resting on the
-- padding's bottom, then the edge. Returns the header and its parts: rect, count, title, back
-- (the back mark, nil at the root), back_place and title_place, title_rect (where a tap goes up,
-- nil at the root), sort and status ({ rect, hit, label, mark }).
local function header(built, w, books, choice)
    local ctx = built.ctx
    local scale, color, line_height = tools(ctx)
    local look = ctx.look
    local tokens = look.library.header
    local h = LibraryTiles.header_height(ctx)
    local box = new_box(w, h, color(tokens.fill_color))
    local parts = { rect = Geom:new{ x = 0, y = 0, w = w, h = h } }
    local side, gap = scale(tokens.padding.side), scale(tokens.picker_gap)
    local edge = scale(tokens.edge_width)
    local bottom = h - edge - scale(tokens.padding.bottom)
    local status_chip, status = picker(look.type.library_picker_status, STATUS_LABELS[choice.status],
        tokens.status_fill_color, ctx)
    local sort_chip, sort = picker(look.type.library_picker, SORT_LABELS[choice.sort], tokens.sort_fill_color, ctx)
    local status_size, sort_size = status_chip:getSize(), sort_chip:getSize()
    status.rect = Geom:new{ x = w - side - status_size.w, y = bottom - status_size.h, w = status_size.w,
        h = status_size.h }
    sort.rect = Geom:new{ x = status.rect.x - gap - sort_size.w, y = bottom - sort_size.h, w = sort_size.w,
        h = sort_size.h }
    -- Where a tap opens each picker: its chip, reaching down through the padding to the edge, as
    -- far up, and halfway across the gap at each side, so Editorial's unpadded label line
    -- (GridA.dc.html:25) is not the whole target. The drawing is the chip's.
    local reach = scale(tokens.padding.bottom)
    for _, part in ipairs({ sort, status }) do
        part.hit = Geom:new{ x = part.rect.x - math.floor(gap / 2), y = part.rect.y - reach,
            w = part.rect.w + 2 * math.floor(gap / 2), h = part.rect.h + 2 * reach }
    end
    add(box, sort_chip, sort.rect.x, sort.rect.y)
    add(box, status_chip, status.rect.x, status.rect.y)
    parts.sort, parts.status = sort, status
    local column_w = math.max(1, sort.rect.x - gap - side)
    local count = Typeset.line(look.type.library_count, count_text(books, look.title_bar.count_on_shelf),
        column_w, ctx)
    local title_h = line_height(look.type.library_title)
    local count_h = count:getSize().h
    local top = bottom - (count_h + scale(tokens.line_gap) + title_h)
    add(box, count, side, top)
    parts.count = count
    local title_y = top + count_h + scale(tokens.line_gap)
    local title_x, text = side, "Library"
    if not LibraryView.same_dir(built.dir, LibraryView.root()) then
        -- Sized to the title's line, as LibraryTiles.header_height counts it.
        parts.back = TintedIcon:new{ file = Icons.path("back"), size = title_h,
            color = color(look.type.library_title.color) }
        parts.back_place = { x = side, y = title_y }
        add(box, parts.back, side, title_y)
        title_x, text = side + title_h, name_of(built.dir)
    end
    parts.title = Typeset.line(look.type.library_title, text, math.max(1, column_w - (title_x - side)), ctx)
    parts.title_place = { x = title_x, y = title_y }
    add(box, parts.title, title_x, title_y)
    if parts.back then
        parts.title_rect = Geom:new{ x = side, y = title_y, w = title_x - side + parts.title:getSize().w, h = title_h }
    end
    local edge_color = color(tokens.edge_color)
    if edge > 0 and edge_color then
        add(box, Fill:new{ dimen = Geom:new{ w = w, h = edge }, color = edge_color }, 0, h - edge)
    end
    return box, parts
end

-- The counts a folder's tile shows: the books directly in it and how many are reading, from the
-- folder's scan and each book's progress, with no record read.
local function folder_counts(folder)
    local books = Books.files(folder.path)
    local reading = 0
    for _, book in ipairs(books) do
        if Books.progress(book).status == "reading" then
            reading = reading + 1
        end
    end
    return { books = #books, reading = reading }
end

-- One pager button, which ("prev" or "next"): its box in the pager's fill and outline and, when
-- live, its arrow in the look's arrow colour for it, or when dead, in dead_color, or none where the
-- look has no dead colour (D16). Returns the box and { live, arrow }.
local function button(which, live, arrow_size, ctx)
    local scale, color = tools(ctx)
    local tokens = ctx.look.library.pager
    local w, h = scale(tokens.button_w), scale(tokens.button_h)
    local outline_color = color(tokens.outline_color)
    local box = new_box(w, h, color(tokens[which .. "_fill_color"]),
        outline_color and scale(tokens.outline_width) or 0, outline_color)
    local arrow_color = color(live and tokens[which .. "_icon_color"] or tokens.dead_color)
    local parts = { live = live }
    if arrow_color then
        parts.arrow = TintedIcon:new{ file = Icons.path(which == "prev" and "back" or "forward"), size = arrow_size,
            color = arrow_color }
        add(box, parts.arrow, math.floor((w - arrow_size) / 2), math.floor((h - arrow_size) / 2))
    end
    return box, parts
end

-- The pager, centred across w with its foot bottom above y (Main.dc.html:85-88, GridA.dc.html:85-88):
-- the previous button, the page label, the next button, each centred in the pager's band. The
-- arrows are the label's line tall. Adds them to frame and returns { prev, next, label }, each
-- button with its rect.
local function pager(built, frame, w, y)
    local ctx = built.ctx
    local scale = tools(ctx)
    local look = ctx.look
    local tokens = look.library.pager
    local height = LibraryTiles.pager_height(ctx)
    local band = height - scale(tokens.bottom)
    local top = y - height
    local text = tokens.label_in_words and ("Page %d of %d"):format(built.page, built.pages)
        or ("%d / %d"):format(built.page, built.pages)
    local label = Typeset.line(look.type.pager_label, text, w, ctx)
    local label_size = label:getSize()
    local prev_box, prev = button("prev", built.page > 1, label_size.h, ctx)
    local next_box, next = button("next", built.page < built.pages, label_size.h, ctx)
    local bw, bh = prev_box:getSize().w, prev_box:getSize().h
    local gap = scale(tokens.gap)
    local x = math.floor((w - (2 * bw + 2 * gap + label_size.w)) / 2)
    local by = top + math.floor((band - bh) / 2)
    prev.rect = Geom:new{ x = x, y = by, w = bw, h = bh }
    next.rect = Geom:new{ x = x + bw + gap + label_size.w + gap, y = by, w = bw, h = bh }
    add(frame, prev_box, prev.rect.x, by)
    add(frame, label, x + bw + gap, top + math.floor((band - label_size.h) / 2))
    add(frame, next_box, next.rect.x, by)
    return { prev = prev, next = next, label = label }
end

-- The folder's listing as built keeps it for the builds after: { dir, listing (Books.folder(dir)),
-- history (LibraryOrder.history_times() then), sort, status, items (LibraryOrder.view of the
-- listing under that sort and status, or nil when it must be made again) }. kept, the one an
-- earlier build gave, is used when it is of dir; otherwise the folder is listed now. Its items are
-- made again when nil or of another sort or status than choice, with each book's progress as
-- Books.progress reads it then (its memo opens only a changed sidecar). Returns a new table, so
-- kept's own fields are left as they were (its listing is shared).
local function keep(kept, dir, choice)
    local now = {}
    if kept and kept.dir == dir then
        for k, v in pairs(kept) do
            now[k] = v
        end
    else
        now.dir, now.listing, now.history = dir, Books.folder(dir), LibraryOrder.history_times()
    end
    if now.items == nil or now.sort ~= choice.sort or now.status ~= choice.status then
        now.items = LibraryOrder.view(now.listing, choice.sort, choice.status, Books.progress, now.history)
        now.sort, now.status = choice.sort, choice.status
    end
    return now
end

-- The place in kept's listing (as keep gives it) of the book whose id is id, or nil.
local function listed_at(kept, id)
    if not kept then
        return nil
    end
    for i, record in ipairs(kept.listing.books) do
        if record.id == id then
            return i
        end
    end
    return nil
end

-- Puts record, read again, in kept's listing in place of the record of its id, and leaves kept's
-- items to be made again, so the next build filters and sorts the listing as it now stands. A kept
-- of nil, or without that id, is left as it was.
function LibraryView.renew(kept, record)
    local i = listed_at(kept, record.id)
    if i then
        kept.listing.books[i] = record
        kept.items = nil
    end
end

-- Leaves kept's items to be made again when it lists the book whose id is id, whose progress has
-- changed, so the next build filters and sorts with the progress read then. A kept of nil, or
-- without that id, is left as it was.
function LibraryView.forget(kept, id)
    if listed_at(kept, id) then
        kept.items = nil
    end
end

-- Fills built (dir, page, ctx) from the folder's listing under the folder's sort and status, the
-- listing kept (built.kept on entry, as keep takes it) or listed now: the frame (the paper, the
-- header, the page's tiles at the geometry's boxes or the empty note, the pager and the nav bar),
-- and what gestures and covers read: page and pages, header, tiles ({ rect, kind, record or
-- folder, widget, index in the frame }), box (LibraryTiles.geometry), pager, note, nav; and kept,
-- the listing for the next build.
local function fill(built, frame, w, h)
    local ctx = built.ctx
    local scale, color = tools(ctx)
    local look = ctx.look
    local choice = LibraryOrder.choice(built.dir)
    local kept = keep(built.kept, built.dir, choice)
    built.kept = kept
    local listing, items = kept.listing, kept.items
    local slice
    slice, built.pages, built.page = LibraryOrder.page(items, built.page)
    frame.fill_color = color("paper")
    local header_box
    header_box, built.header = header(built, w, #items - #listing.folders, choice)
    add(frame, header_box, 0, 0)
    local grid = look.library.grid
    local box = LibraryTiles.geometry(w, ctx)
    built.box = box
    local top = built.header.rect.h + scale(grid.padding_top)
    built.tiles = {}
    for i, item in ipairs(slice) do
        local x = box.columns[(i - 1) % #box.columns + 1].x
        local y = top + math.floor((i - 1) / #box.columns) * (box.height + scale(grid.row_gap))
        local tile = { rect = Geom:new{ x = x, y = y, w = box.cover_w, h = box.height } }
        if item.id then
            tile.kind, tile.record = "book", item
            tile.widget = LibraryTiles.book(item, Books.progress(item), box, ctx)
        else
            tile.kind, tile.folder = "folder", item
            tile.widget = LibraryTiles.folder(item, folder_counts(item), box, ctx)
        end
        tile.index = add(frame, tile.widget, x, y)
        built.tiles[i] = tile
    end
    local nav = NavBar.new{ look = look, variant = ctx.variant, width = w, where = "library", listen = false }
    nav.dimen.x, nav.dimen.y = 0, h - nav.dimen.h
    built.nav = nav
    built.pager = pager(built, frame, w, nav.dimen.y)
    if #items == 0 then
        local side = scale(grid.side)
        local note = Typeset.line(look.type.pager_label, EMPTY_NOTES[choice.status], math.max(1, w - 2 * side), ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        add(frame, note, math.floor((w - size.w) / 2), top + math.floor((below - top - size.h) / 2))
        built.note = note
    end
    add(frame, nav, 0, nav.dimen.y)
end

-- What the library shows at dir and page now, at the screen's size in the active look and
-- variant: { frame, dir, page (clamped), pages, dimen, ctx, header, tiles, box, pager, note, nav,
-- kept }, as fill gives them. kept is the kept listing an earlier build gave (built.kept): one of
-- dir is sliced, or filtered and sorted again under a changed choice, without listing the folder;
-- nil or one of another folder lists it now. A failure frees what was built and raises.
function LibraryView.build(dir, page, kept)
    local size = Screen:getSize()
    local built = {
        dir = dir,
        page = page,
        kept = kept,
        dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h },
        ctx = { look = Looks.active(), variant = Looks.variant(), screen = Screen },
    }
    built.frame = new_box(size.w, size.h)
    local ok, err = pcall(fill, built, built.frame, size.w, size.h)
    if not ok then
        built.frame:free()
        error(err, 0)
    end
    return built
end

return LibraryView
