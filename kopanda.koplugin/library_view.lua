-- The library window's view: what it draws for a folder at a page, built on the chrome's frame
-- (library_chrome.lua) with the parts its gestures and covers read. The header holds the count, "Library"
-- or the back mark and the folder's name, and the sort and status pickers; then two rows of three tiles
-- (library_tiles.lua) or the empty note, and the chrome's pager and nav bar. What a folder shows, in what
-- order, is library_order.lua's. Lengths are board pixels; the text ignores text_size, as the tiles'.
local Books = require("books")
local Geom = require("ui/geometry")
local Helpers = require("helpers")
local Icons = require("icons")
local LibraryChrome = require("library_chrome")
local LibraryOrder = require("library_order")
local LibraryTiles = require("library_tiles")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local ffiutil = require("ffi/util")
local Screen = require("device").screen

local LibraryView = {}

local SORT_LABELS = { recent = "Recent", title = "Title", author = "Author", series = "Series" }
local STATUS_LABELS = { reading = "Reading", finished = "Finished", all = "All" }
-- The notes for a folder with nothing to show under each status.
local EMPTY_NOTES = { all = "No books here", finished = "No finished books here", reading = "No books being read here" }

-- KOReader's home folder, the library's root, as Books.folder reads it (books.lua:171-173).
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

local new_box, add, tools = LibraryChrome.box, LibraryChrome.add, LibraryChrome.tools

-- A picker: its label in part, then the chevron_down mark sized to the label's line in the
-- label's colour, inside the header's picker padding and outline, on fill, rounded by the
-- header's picker radius where it has one (Toybox's pills). Returns the chip and { label, mark }.
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
    if tokens.picker_radius > 0 then
        chip.radius = scale(tokens.picker_radius)
        chip.fill_radius = chip.radius
    end
    add(chip, label, pad_x, pad_y)
    add(chip, mark, pad_x + size.w, pad_y)
    return chip, { label = label, mark = mark }
end

-- The header, w wide, LibraryTiles.header_height tall: the chrome's header frame (LibraryChrome.header),
-- the count over the title in its left column, the back mark before the folder's name inside a sub-folder,
-- and the status and sort pickers at the right. Returns the header and its parts: the frame's, count,
-- sort and status ({ rect, hit, label, mark }), and text ({ count, title, sort, status }), which the
-- empty-space sheet's header and chips repeat.
local function header(built, w, books, choice)
    local ctx = built.ctx
    local scale = tools(ctx)
    local look = ctx.look
    local tokens = look.library.header
    local sub = not LibraryView.same_dir(built.dir, LibraryView.root())
    local text = { count = Helpers.count_text(books, look.title_bar.count_on_shelf),
        title = sub and name_of(built.dir) or "Library", sort = SORT_LABELS[choice.sort],
        status = STATUS_LABELS[choice.status] }
    local status_chip, status = picker(look.type.library_picker_status, text.status, tokens.status_fill_color, ctx)
    local sort_chip, sort = picker(look.type.library_picker, text.sort, tokens.sort_fill_color, ctx)
    local box, parts = LibraryChrome.header(ctx, w, {
        height = LibraryTiles.header_height(ctx),
        band = tokens.fill_color,
        right = { status_chip, sort_chip },
        aside = { part = look.type.library_count, text = text.count },
        title = { part = look.type.library_title, text = text.title },
        back = sub,
    })
    parts.text = text
    status.rect, sort.rect = parts.right[1], parts.right[2]
    -- Where a tap opens each picker: its chip, reaching down through the padding to the edge, as far up, and
    -- halfway across the gap at each side, so Editorial's unpadded label line is not the whole target.
    local gap, reach = scale(tokens.picker_gap), scale(tokens.padding.bottom)
    for _, part in ipairs({ sort, status }) do
        part.hit = Geom:new{ x = part.rect.x - math.floor(gap / 2), y = part.rect.y - reach,
            w = part.rect.w + 2 * math.floor(gap / 2), h = part.rect.h + 2 * reach }
    end
    parts.sort, parts.status, parts.count = sort, status, parts.aside
    return box, parts
end

-- The counts a folder's tile shows, and its sheet's meta: the books directly in it and how many are
-- reading and finished, from the folder's scan and each book's progress, with no record read.
local function folder_counts(folder)
    local books = Books.files(folder.path)
    local reading, finished = 0, 0
    for _, book in ipairs(books) do
        local status = Books.progress(book).status
        if status == "reading" then
            reading = reading + 1
        elseif status == "complete" then
            finished = finished + 1
        end
    end
    return { books = #books, reading = reading, finished = finished }
end

-- The folder's listing as built keeps it for the builds after: { dir, listing (Books.folder(dir), hidden
-- sub-folders left out), history, sort, status, items (LibraryOrder.view under that sort and status, or nil
-- when it must be made again) }. kept, the one an earlier build gave, is used when it is of dir; otherwise
-- the folder is listed now. items are made again when nil or of another sort or status than choice. Returns
-- a new table, so kept's own fields are left as they were (its listing is shared).
local function keep(kept, dir, choice)
    local now = {}
    if kept and kept.dir == dir then
        for k, v in pairs(kept) do
            now[k] = v
        end
    else
        local listing = Books.folder(dir)
        listing = { books = listing.books, folders = LibraryOrder.visible(listing.folders) }
        now.dir, now.listing, now.history = dir, listing, LibraryOrder.history_times()
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

-- Fills built (dir, page, ctx) from the folder's listing under its sort and status, the listing kept or
-- listed now: the frame (header, the page's tiles or the empty note, the chrome's foot), and what gestures
-- and covers read: page and pages, header, tiles ({ rect, kind, record or folder and counts, widget, index }),
-- box, note, and kept for the next build. A hide or unhide shows once the listing is made again.
local function fill(built, frame, w)
    local ctx = built.ctx
    local scale = tools(ctx)
    local look = ctx.look
    local choice = LibraryOrder.choice(built.dir)
    local kept = keep(built.kept, built.dir, choice)
    built.kept = kept
    local listing, items = kept.listing, kept.items
    local slice
    slice, built.pages, built.page = LibraryOrder.page(items, built.page)
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
            tile.kind, tile.folder, tile.counts = "folder", item, folder_counts(item)
            tile.widget = LibraryTiles.folder(item, tile.counts, box, ctx)
        end
        tile.index = add(frame, tile.widget, x, y)
        built.tiles[i] = tile
    end
    LibraryChrome.foot(built, frame, "library")
    if #items == 0 then
        local side = scale(grid.side)
        local note = Typeset.line(look.type.pager_label, EMPTY_NOTES[choice.status], math.max(1, w - 2 * side), ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        add(frame, note, math.floor((w - size.w) / 2), top + math.floor((below - top - size.h) / 2))
        built.note = note
    end
end

-- What the library shows at dir and page now, at the screen's size in the active look and variant: { frame,
-- dir, page (clamped), pages, dimen, ctx, header, tiles, box, pager, note, nav, kept }. kept is the listing
-- an earlier build gave: one of dir is sliced, or filtered and sorted again under a changed choice, without
-- listing the folder. A failure frees what was built and raises.
function LibraryView.build(dir, page, kept)
    return LibraryChrome.build({ dir = dir, page = page, kept = kept }, fill)
end

return LibraryView
