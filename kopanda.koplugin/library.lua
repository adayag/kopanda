-- The library: a window on the chrome (library_chrome.lua) showing one folder a page at a time
-- (cover-grid "The window"). The chrome holds its show and close, its paint and settled signal, its
-- pager, nav bar and gesture route and the events that keep it current; what it draws is
-- library_view.lua's, what a folder shows and the memory library_order.lua's, and its covers
-- library_covers.lua's. Here are what a tap on each of its own parts does, where it was left, the
-- return a book's open records and the root check its paint runs (context-menu D6).
-- Module state: Library.shown, the library on screen or nil, the chrome's slot; Library.return_to,
-- { dir, page } a book was opened from, which the next file manager's show returns to (D4), or nil,
-- in memory only; Library.on_picker(kind), run on a tap on the "sort" or "status" picker, a hook
-- library_pickers.lua fills (here a no-op).
local LibraryChrome = require("library_chrome")
local LibraryCovers = require("library_covers")
local LibraryOrder = require("library_order")
local LibraryView = require("library_view")
local logger = require("logger")

local Library = LibraryChrome.Window:extend{
    name = "kopanda_library",
    screen = "library",
    fields = { "dir", "root", "tiles", "box", "note", "kept" },
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
-- is sliced, or filtered and sorted again under a choice made since; another folder is listed. The
-- build keeps root, KOReader's home folder it was built under, for the root check.
function Library:build(dir, page)
    local root = LibraryView.root()
    local built = LibraryView.build(dir, page, self.kept)
    built.root = root
    return built
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

-- Shows folder ({ name, path }) at its page: a tap on its tile, and its sheet's Open.
function Library:open_folder(folder)
    self:go(folder.path, page_for(folder.path))
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
                    self:open_folder(tile.folder)
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

-- opts: dir (default: the library's root), page, started (LibraryChrome.show's). Returns the
-- library shown, or nil.
function Library.show(opts)
    opts = opts or {}
    return LibraryChrome.show(Library, opts, { dir = opts.dir, page = opts.page })
end

function Library.close()
    if Library.shown then
        LibraryChrome.close()
    end
end

-- The re-list of the metadata events and of the sheets (a Hide, a hidden folder shown again, a
-- status written, a delete): the kept listing dropped, then the folder listed again and the page
-- shown rebuilt (LibraryChrome.Window.refresh).
function Library:refresh()
    if Library.shown ~= self then
        return
    end
    self.kept = nil
    LibraryChrome.Window.refresh(self)
end

-- The page's covers, while this is the library shown. The check in flight goes on: a request that
-- starts a new batch replaces it, and its arrivals rebuild only the tiles the page shows. After
-- Library:refresh_covers, the folder's books in its place, so the re-list's paint makes the one
-- request, whatever the order of the ticks.
function Library:request_covers()
    local records = self.covers_records
    self.covers_records = nil
    LibraryCovers.request(self, function()
        return Library.shown == self
    end, records)
end

-- Refresh covers (context-menu D9): re-lists the folder at its page, the kept listing dropped, and,
-- from the tick after that paint, asks for the covers of records (the folder's books with a file,
-- their covers forgotten) in one request in place of the page's. A build that fails leaves the page
-- and asks nothing.
function Library:refresh_covers(records)
    self.covers_records = records
    self.kept = nil
    self:go(self:view(), self.page)
    if not self.covers_due then
        self.covers_records = nil
    end
end

-- The root check (context-menu D6): when KOReader's home folder is no longer the one the library
-- was built under (Set as library root's OK, whose ConfirmBox's close marks the library dirty),
-- the library shows the new root at page 1, recorded as where it was left. A build that fails
-- leaves the library where it was, and where it was left unchanged.
local function check_root(library)
    local root = LibraryView.root()
    if LibraryView.same_dir(root, library.root) then
        return
    end
    library.root = root
    library:go(root, 1)
    if LibraryView.same_dir(library.dir, root) then
        LibraryOrder.leave(library.dir, library.page)
    end
end

-- The root check before the chrome's paint; a check that raises is logged and the paint goes on.
function Library:paintTo(bb, x, y)
    local ok, err = pcall(check_root, self)
    if not ok then
        logger.err("KoPanda: the library could not check its root:", err)
    end
    LibraryChrome.Window.paintTo(self, bb, x, y)
end

-- The folder and page the library was left at are stored (D11).
function Library:closing()
    local ok, err = pcall(LibraryOrder.leave, self.dir, self.page)
    if not ok then
        logger.err("KoPanda: could not store where the library was left:", err)
    end
end

return Library
