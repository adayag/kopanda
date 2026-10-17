-- The library: a window on the chrome (library_chrome.lua) showing one folder a page at a time
-- (cover-grid "The window"). The chrome holds its show and close, its paint and settled signal,
-- its pager, nav bar and gesture route, the events that keep it current and the pre-build on a
-- book's close; what it draws is library_view.lua's, what a folder shows and the memory
-- library_order.lua's, and its covers library_covers.lua's. Here are what a tap on each of its
-- own parts does, where it was left and the return a book's open records.
-- Module state: Library.shown, the library on screen or nil, and Library.pending, one built on
-- book close and not yet shown, or nil, both the chrome's slots; Library.return_to, { dir, page }
-- a book was opened from, which the next file manager's show returns to (D4), or nil, in memory
-- only; Library.on_picker(kind), run on a tap on the "sort" or "status" picker, a hook
-- library_pickers.lua fills (here a no-op).
local LibraryChrome = require("library_chrome")
local LibraryCovers = require("library_covers")
local LibraryOrder = require("library_order")
local LibraryView = require("library_view")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local ffiutil = require("ffi/util")

local Library = LibraryChrome.Window:extend{
    name = "kopanda_library",
    screen = "library",
    fields = { "dir", "tiles", "box", "note", "kept" },
    dir = nil,
}

Library.return_to = nil

-- Run when a tap's book open goes ahead: the book closes back to dir at page.
function Library.on_open(dir, page)
    Library.return_to = { dir = dir, page = page }
end

function Library.on_picker(_kind) end

-- The page the library shows dir at: the one it was left at there, else the first.
local function page_for(dir)
    local left = LibraryOrder.left()
    if left and LibraryView.same_dir(left.dir, dir) then
        return left.page
    end
    return 1
end

-- The folder the library shows: its dir, or the library's root before its first build.
function Library:view()
    return self.dir or LibraryView.root()
end

-- dir at page, from the library's kept listing (LibraryView.build's): the folder shown is not listed
-- again on a page turn, a picker choice or a repaint in another variant or size; its kept listing
-- is sliced, or filtered and sorted again under a choice made since; another folder is listed.
function Library:build(dir, page)
    return LibraryView.build(dir, page, self.kept)
end

-- Opens record's file as the file browser's own tap does (D15; filemanager.lua:160-169), which
-- asks first when the owner set "ask before opening", running Library.on_open with the folder and
-- page once the open goes ahead (filemanagerutil.lua:498-502).
function Library:open(record)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if not fm then
        return
    end
    local dir, page = self.dir, self.page
    require("apps/filemanager/filemanagerutil").openFile(fm, record.path, function()
        Library.on_open(dir, page)
    end)
end

-- The back control, the title inside a sub-folder: up one folder, at its page.
function Library:back()
    local parent = LibraryView.parent_of(self.dir)
    self:go(parent, page_for(parent))
end

-- The action a tap at pos on the library's own parts runs, or nil: a book with a file opens; a
-- book without one does nothing; a folder shows at its page; a picker runs Library.on_picker.
function Library:action_at(pos)
    for _, tile in ipairs(self.tiles) do
        if LibraryChrome.inside(tile.rect, pos) then
            if tile.folder then
                return function()
                    self:go(tile.folder.path, page_for(tile.folder.path))
                end
            end
            return function()
                if tile.record.path then
                    self:open(tile.record)
                end
            end
        end
    end
    for _, kind in ipairs({ "sort", "status" }) do
        if LibraryChrome.inside(self.header[kind].hit, pos) then
            return function()
                Library.on_picker(kind)
            end
        end
    end
    return nil
end

-- What lies at (x, y) on the shown library: { kind = "book", record }, { kind = "folder",
-- folder } or { kind = "empty" }; nil with no library shown.
function Library.hit(x, y)
    local library = Library.shown
    if not library then
        return nil
    end
    local pos = { x = x, y = y }
    for _, tile in ipairs(library.tiles) do
        if LibraryChrome.inside(tile.rect, pos) then
            if tile.record then
                return { kind = "book", record = tile.record }
            end
            return { kind = "folder", folder = tile.folder }
        end
    end
    return { kind = "empty" }
end

-- opts: widget (a pre-built library to show; default: a fresh build at dir and page), dir (default:
-- the library's root), page, started (LibraryChrome.show's). Returns the library shown, or nil.
function Library.show(opts)
    opts = opts or {}
    return LibraryChrome.show(Library, opts, { dir = opts.dir, page = opts.page })
end

function Library.close()
    if Library.shown then
        LibraryChrome.close()
    end
end

-- The closed book's tile is rebuilt; a failure leaves the tile as built. Its progress the build
-- kept is forgotten, so a page turned to reads it again wherever the book is.
function Library:book_closed(file)
    -- A file's record id, as books.lua's record() makes it.
    local id = "file:" .. (ffiutil.realpath(file) or file)
    LibraryView.forget(self.kept, id)
    LibraryCovers.rebuild_tiles(self, { [id] = true }, "the closed book's tile")
end

-- The metadata events re-list: the kept listing dropped, then the folder listed again and the page
-- shown rebuilt (LibraryChrome.Window.refresh).
function Library:refresh()
    if Library.shown ~= self then
        return
    end
    self.kept = nil
    LibraryChrome.Window.refresh(self)
end

-- Marks the library stale and refreshes it once from the next tick, however many events marked it
-- before: one change broadcasts InvalidateMetadataCache and BookMetadataChanged, and a second
-- BookMetadataChanged when the summary changed too (filemanagerbookinfo.lua:276-280, :556-557). The
-- book-info page broadcasts from its close callback after UIManager:close
-- (frontend/ui/widget/keyvaluepage.lua:841-846), inside the input dispatch at the end of
-- handleInput (frontend/ui/uimanager.lua:1607-1620), so the tick runs at the next pass's
-- _checkTasks, before that pass's _repaint paints the close (:431-433, :1537-1564, :1663). A
-- library closed by then is not refreshed (refresh's Library.shown check).
local function refresh_soon(library)
    if library.stale then
        return
    end
    library.stale = true
    UIManager:nextTick(function()
        if library.stale then
            library.stale = nil
            library:refresh()
        end
    end)
end

-- Over the chrome's handlers (library_chrome.lua), which refresh on each event: broadcast to every
-- window when a book's metadata or status changes and when its cached metadata is dropped
-- (frontend/apps/filemanager/filemanagerbookinfo.lua:276-277, :556-557; frontend/ui/uimanager.lua:1042-1061).
function Library:onBookMetadataChanged()
    refresh_soon(self)
end

function Library:onInvalidateMetadataCache()
    refresh_soon(self)
end

-- The page's covers, while this is the library shown. The check in flight goes on: a request that
-- starts a new batch replaces it, and its arrivals rebuild only the tiles the page shows.
function Library:request_covers()
    LibraryCovers.request(self, function()
        return Library.shown == self
    end)
end

-- The folder and page the library was left at are stored (D11).
function Library:closing()
    local ok, err = pcall(LibraryOrder.leave, self.dir, self.page)
    if not ok then
        logger.err("KoPanda: could not store where the library was left:", err)
    end
end

return Library
