-- The library window's covers (cover-grid "Covers", "Book close"): the request for a shown page's
-- covers, the tiles an arrival rebuilds, and the closed book's tile a pre-built library rebuilds.
-- It works on a library (library.lua) it is handed and asks alive() whether that one is still the
-- library shown, so it needs no module state of its own.
local BookCovers = require("book_covers")
local Books = require("books")
local Geom = require("ui/geometry")
local LibraryTiles = require("library_tiles")
local LibraryView = require("library_view")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local LibraryCovers = {}

-- The record of a tile's book read again and its progress read now: a file book's from one open
-- of its sidecar (Books.with_progress), another's by its id; the tile's own record when it can't
-- be read again.
local function read_again(shown)
    local record, progress
    if shown.path then
        record, progress = Books.with_progress(shown.path)
    else
        record = Books.get(shown.id)
    end
    record = record or shown
    return record, progress or Books.progress(record)
end

-- Rebuilds in place the tiles of the books whose ids are keys of ids, from their records read again
-- (a title that came with an extraction replaces the file name) and their progress read now,
-- keeping the page's order; the library's kept listing takes each record (LibraryView.renew), so
-- the next build filters and sorts with it. A failure is logged with what and leaves every tile
-- as it was. Returns how many tiles it rebuilt, and those tiles.
function LibraryCovers.rebuild_tiles(library, ids, what)
    local fresh = {}
    local ok, err = pcall(function()
        for _, tile in ipairs(library.tiles) do
            if tile.record and ids[tile.record.id] then
                local record, progress = read_again(tile.record)
                fresh[#fresh + 1] = { tile = tile, record = record,
                    widget = LibraryTiles.book(record, progress, library.box, library.ctx) }
            end
        end
    end)
    if not ok then
        for _, entry in ipairs(fresh) do
            entry.widget:free()
        end
        logger.err("KoPanda: " .. what .. " failed:", err)
        return 0, {}
    end
    local rebuilt = {}
    for _, entry in ipairs(fresh) do
        local tile = entry.tile
        local old = library[1][tile.index]
        library[1][tile.index] = entry.widget
        tile.widget, tile.record = entry.widget, entry.record
        LibraryView.renew(library.kept, entry.record)
        old:free()
        rebuilt[#rebuilt + 1] = tile
    end
    return #fresh, rebuilt
end

-- The screen region tiles paint: the bounding box of their rects, each widened by what a tile
-- paints past its box (LibraryTiles.overhang), inside the library's. A rebuilt tile keeps its rect
-- (its box is fixed, its title one line), so this covers what it painted before too.
local function painted(library, tiles)
    local over = LibraryTiles.overhang(library.box, library.ctx)
    local region
    for _, tile in ipairs(tiles) do
        local rect = tile.rect
        local widened = Geom:new{ x = rect.x, y = rect.y - over.top, w = rect.w + over.right,
            h = rect.h + over.top + over.bottom }
        region = region and region:combine(widened) or widened
    end
    return region:intersect(library.dimen)
end

-- Puts each arrived record the page shows no tile of in the library's kept listing, read again
-- (LibraryView.renew), so a page turned to shows the title that came with its extraction: Refresh
-- covers (context-menu D9) asks for the whole folder's covers at once. One that can't be read again
-- is left as kept; a failure is logged and leaves the rest as kept.
local function renew_off_page(library, arrived)
    if not library.kept then
        return
    end
    local ok, err = pcall(function()
        local on_page = {}
        for _, tile in ipairs(library.tiles) do
            if tile.record then
                on_page[tile.record.id] = true
            end
        end
        for _, record in ipairs(arrived) do
            if not on_page[record.id] then
                local fresh = Books.get(record.id)
                if fresh then
                    LibraryView.renew(library.kept, fresh)
                end
            end
        end
    end)
    if not ok then
        logger.err("KoPanda: the library could not keep the covers that arrived off its page:", err)
    end
end

-- Rebuilds the arrived records' tiles the page shows and repaints, while the library is alive,
-- refreshing "ui" over just those tiles with the dither hint, as CoverBrowser refreshes an item
-- whose cover came (plugins/coverbrowser.koplugin/covermenu.lua:144-157); the others' records are
-- kept for a page turned to (renew_off_page).
local function on_arrival(library, arrived, alive)
    if not alive() then
        return
    end
    local ids = {}
    for _, record in ipairs(arrived) do
        ids[record.id] = true
    end
    renew_off_page(library, arrived)
    local count, rebuilt = LibraryCovers.rebuild_tiles(library, ids, "the library's cover arrival")
    if count > 0 then
        local region = painted(library, rebuilt)
        UIManager:setDirty(library, function()
            return "ui", region, true
        end)
    end
end

-- Asks for the covers of records (default: the library's page's books) at the cover box's size
-- (BookCovers.request), each arrival rebuilding the tiles the page shows of them while alive() says
-- the library is the one shown; an arrival off the page rebuilds none and stays in CoverBrowser's
-- cache for a later page, its record read again into the kept listing. A failure is logged; the
-- tiles keep their placeholders.
function LibraryCovers.request(library, alive, records)
    if not alive() then
        return
    end
    local ok, err = pcall(function()
        if not records then
            records = {}
            for _, tile in ipairs(library.tiles) do
                if tile.record then
                    records[#records + 1] = tile.record
                end
            end
        end
        if #records == 0 then
            return
        end
        BookCovers.request(records, { max_cover_w = library.box.cover_w, max_cover_h = library.box.cover_h },
            function(arrived)
                on_arrival(library, arrived, alive)
            end,
            alive)
    end)
    if not ok then
        logger.err("KoPanda: the library's cover request failed:", err)
    end
end

return LibraryCovers
