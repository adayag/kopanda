-- The library window's covers (cover-grid "Covers", "Book close"): the request for a shown page's
-- covers, the tiles an arrival rebuilds, and the closed book's tile a pre-built library rebuilds.
-- It works on a library (library.lua) it is handed and asks alive() whether that one is still the
-- library shown, so it needs no module state of its own.
local BookCovers = require("book_covers")
local Books = require("books")
local LibraryTiles = require("library_tiles")
local LibraryView = require("library_view")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local LibraryCovers = {}

-- Rebuilds in place the tiles of the books whose ids are keys of ids, from their records read again
-- (a title that came with an extraction replaces the file name) and their progress read now,
-- keeping the page's order; the library's kept listing takes each record and progress
-- (LibraryView.renew), so the next build filters and sorts with them. A failure is logged with what
-- and leaves every tile as it was. Returns how many tiles it rebuilt.
function LibraryCovers.rebuild_tiles(library, ids, what)
    local fresh = {}
    local ok, err = pcall(function()
        for _, tile in ipairs(library.tiles) do
            if tile.record and ids[tile.record.id] then
                local record = Books.get(tile.record.id) or tile.record
                local progress = Books.progress(record)
                fresh[#fresh + 1] = { tile = tile, record = record, progress = progress,
                    widget = LibraryTiles.book(record, progress, library.box, library.ctx) }
            end
        end
    end)
    if not ok then
        for _, entry in ipairs(fresh) do
            entry.widget:free()
        end
        logger.err("KoPanda: " .. what .. " failed:", err)
        return 0
    end
    for _, entry in ipairs(fresh) do
        local tile = entry.tile
        local old = library[1][tile.index]
        library[1][tile.index] = entry.widget
        tile.widget, tile.record = entry.widget, entry.record
        LibraryView.renew(library.kept, entry.record, entry.progress)
        old:free()
    end
    return #fresh
end

-- Rebuilds the arrived records' tiles and repaints, while the library is alive.
local function on_arrival(library, arrived, alive)
    if not alive() then
        return
    end
    local ids = {}
    for _, record in ipairs(arrived) do
        ids[record.id] = true
    end
    if LibraryCovers.rebuild_tiles(library, ids, "the library's cover arrival") > 0 then
        UIManager:setDirty(library, "ui")
    end
end

-- Asks for the library's page's covers at the cover box's size (BookCovers.request), each arrival
-- rebuilding its tiles while alive() says the library is the one shown. A failure is logged; the
-- tiles keep their placeholders.
function LibraryCovers.request(library, alive)
    if not alive() then
        return
    end
    local ok, err = pcall(function()
        local records = {}
        for _, tile in ipairs(library.tiles) do
            if tile.record then
                records[#records + 1] = tile.record
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
