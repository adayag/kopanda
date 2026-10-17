-- The library: a full-screen KoPanda window over the file manager showing one folder a page at a
-- time (cover-grid "The window"). What it draws is library_view.lua's, what a folder shows and the
-- memory library_order.lua's, and its gestures' order library_gestures.lua's; here are its show
-- and close, its paint and settled signal, what a tap on each part does, its covers and the events
-- that keep it current.
-- Module state: Library.shown, the library on screen or nil; Library.pending, one built on book
-- close and not yet shown, or nil; Library.return_to, { dir, page } a book was opened from, which
-- the next file manager's show returns to (D4), or nil, in memory only; Library.on_picker(kind),
-- run on a tap on the "sort" or "status" picker, a hook the rest of KoPanda fills (here a no-op).
local BookCovers = require("book_covers")
local Books = require("books")
local Device = require("device")
local InputContainer = require("ui/widget/container/inputcontainer")
local LibraryGestures = require("library_gestures")
local LibraryOrder = require("library_order")
local LibraryTiles = require("library_tiles")
local LibraryView = require("library_view")
local Looks = require("looks")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local time = require("ui/time")
local ffiutil = require("ffi/util")
local Screen = Device.screen

local Library = InputContainer:extend{
    name = "kopanda_library",
    -- UIManager:_repaint skips paintTo beneath the topmost such widget.
    covers_fullscreen = true,
    dir = nil,
    page = nil,
}

Library.shown = nil
Library.pending = nil
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

local FIELDS = { "dir", "page", "pages", "dimen", "ctx", "header", "tiles", "box", "pager", "note", "nav" }

-- Puts built in place of what the library showed, and frees that.
local function apply(library, built)
    local old = library[1]
    library[1] = built.frame
    for _, field in ipairs(FIELDS) do
        library[field] = built[field]
    end
    if old then
        old:free()
    end
end

local function close_library(library)
    if Library.shown == library then
        Library.shown = nil
    end
    local ok, err = pcall(UIManager.close, UIManager, library, "full")
    if not ok then
        logger.err("KoPanda: could not close the library:", err)
    end
end

function Library:init()
    self.dimen = Screen:getSize()
    self:registerTouchZones(LibraryGestures.own_zones(self))
    -- As Menu registers its page keys (frontend/ui/widget/menu.lua:984-992).
    if Device:hasKeys() then
        self.key_events.NextPage = { { Device.input.group.PgFwd } }
        self.key_events.PrevPage = { { Device.input.group.PgBack } }
    end
    apply(self, LibraryView.build(self.dir or LibraryView.root(), self.page))
    self.covers_due = true
end

-- Builds dir at page in place and repaints. A failure is logged and leaves the page as it was.
-- Returns whether it built.
local function rebuild(library, dir, page)
    local ok, built = pcall(LibraryView.build, dir, page)
    if not ok then
        logger.err("KoPanda: could not build the library at", dir, "page", page, ":", built)
        return false
    end
    apply(library, built)
    UIManager:setDirty(library, "ui")
    return true
end

-- Shows dir at page (clamped to its pages) in place, its covers asked for after its first paint.
-- The check in flight goes on: a request that starts a new batch replaces it, and its arrivals
-- rebuild only the tiles the page shows. A failure is logged and leaves the page as it was.
function Library:go(dir, page)
    if not rebuild(self, dir, page) then
        return
    end
    self.covers_due = true
end

-- The page delta pages on, unless that is past the first or the last (no wrap).
function Library:turn(delta)
    local page = self.page + delta
    if page >= 1 and page <= self.pages then
        self:go(self.dir, page)
    end
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

-- The action a tap at pos runs, or nil where no part of the library acts on taps: a book with a
-- file opens; a book without one does nothing; a folder shows at its page; the title inside a
-- sub-folder goes up one folder; a picker runs Library.on_picker; a live pager arrow turns the page.
local function action_at(library, pos)
    for _, tile in ipairs(library.tiles) do
        if LibraryView.inside(tile.rect, pos) then
            if tile.folder then
                return function()
                    library:go(tile.folder.path, page_for(tile.folder.path))
                end
            end
            return function()
                if tile.record.path then
                    library:open(tile.record)
                end
            end
        end
    end
    local top, foot = library.header, library.pager
    if top.title_rect and LibraryView.inside(top.title_rect, pos) then
        return function()
            local parent = LibraryView.parent_of(library.dir)
            library:go(parent, page_for(parent))
        end
    end
    for _, kind in ipairs({ "sort", "status" }) do
        if LibraryView.inside(top[kind].rect, pos) then
            return function()
                Library.on_picker(kind)
            end
        end
    end
    for delta, which in pairs({ [-1] = "prev", [1] = "next" }) do
        if foot[which].live and LibraryView.inside(foot[which].rect, pos) then
            return function()
                library:turn(delta)
            end
        end
    end
    return nil
end

-- Whether a tap at pos is the library's: one on a part that acts on taps runs its action, a
-- raising one logged with the page left as it was.
function Library:tap(pos)
    local action = action_at(self, pos)
    if not action then
        return false
    end
    local ok, err = pcall(action)
    if not ok then
        logger.err("KoPanda: the library's tap failed:", err)
    end
    return true
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
        if LibraryView.inside(tile.rect, pos) then
            if tile.record then
                return { kind = "book", record = tile.record }
            end
            return { kind = "folder", folder = tile.folder }
        end
    end
    return { kind = "empty" }
end

-- Rebuilds in place the tiles of the books whose ids are keys of ids, from their records read again
-- (a title that came with an extraction replaces the file name) and their progress read now,
-- keeping the page's order. A failure is logged with what and leaves every tile as it was. Returns
-- how many tiles it rebuilt.
local function rebuild_tiles(library, ids, what)
    local fresh = {}
    local ok, err = pcall(function()
        for _, tile in ipairs(library.tiles) do
            if tile.record and ids[tile.record.id] then
                local record = Books.get(tile.record.id) or tile.record
                fresh[#fresh + 1] = { tile = tile, record = record,
                    widget = LibraryTiles.book(record, Books.progress(record), library.box, library.ctx) }
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
        old:free()
    end
    return #fresh
end

-- Rebuilds the arrived records' tiles and repaints.
local function on_arrival(library, arrived)
    if Library.shown ~= library then
        return
    end
    local ids = {}
    for _, record in ipairs(arrived) do
        ids[record.id] = true
    end
    if rebuild_tiles(library, ids, "the library's cover arrival") > 0 then
        UIManager:setDirty(library, "ui")
    end
end

-- Asks for the shown page's covers at the cover box's size (BookCovers.request), each arrival
-- rebuilding its tiles while this library is shown. A failure is logged; the tiles keep their
-- placeholders.
local function request_covers(library)
    if Library.shown ~= library then
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
                on_arrival(library, arrived)
            end,
            function()
                return Library.shown == library
            end)
    end)
    if not ok then
        logger.err("KoPanda: the library's cover request failed:", err)
    end
end

-- Signals the library's first paint on the dev loop's settled hook, once per show, as the home's
-- (home.lua:156-200); paint_ms runs from opts.started to that paint. A library whose paint
-- failed sends none.
local function settle(library, opts)
    if library.paint_failed then
        return
    end
    local ok, err = pcall(UIManager.event_hook.execute, UIManager.event_hook, "KoPandaSettled", {
        screen = "library",
        paint_ms = time.to_ms((library.painted_at or time.monotonic()) - opts.started),
        prebuilt = opts.prebuilt,
    })
    if not ok then
        logger.err("KoPanda: the library's settled signal failed:", err)
    end
end

-- opts: widget (a pre-built library to show; default: a fresh build at dir and page), dir (default:
-- the library's root), page, started (time.monotonic() at the start of the show path, which
-- paint_ms runs from; default: now). Closes a library shown, then shows this one and returns it;
-- its settled signal says whether it was pre-built. On any error it is taken off the stack and nil
-- returned, logged, the screen beneath left as it is.
function Library.show(opts)
    opts = opts or {}
    local started = opts.started or time.monotonic()
    local library
    local ok, err = pcall(function()
        Library.close()
        library = opts.widget or Library:new{ dir = opts.dir, page = opts.page }
        Library.shown = library
        UIManager:show(library, "full")
        library.settle_opts = { started = started, prebuilt = opts.widget ~= nil }
    end)
    if ok then
        return library
    end
    logger.err("KoPanda: could not show the library:", err)
    if library and UIManager:isWidgetShown(library) then
        close_library(library)
    end
    Library.shown = nil
    return nil
end

function Library.close()
    if Library.shown then
        close_library(Library.shown)
    end
end

-- Builds the library at dir and page and keeps it as Library.pending, not shown; closed is the
-- file of the book that just closed, whose tile take_pending rebuilds. A failed build is logged and
-- leaves nothing pending, so the show builds afresh.
function Library.prebuild(dir, page, closed)
    Library.drop_pending()
    local ok, library = pcall(Library.new, Library, { dir = dir, page = page })
    if not ok then
        logger.err("KoPanda: could not pre-build the library:", library)
        return
    end
    library.closed = closed
    Library.pending = library
end

-- Forgets the pending library and frees it.
function Library.drop_pending()
    local pending = Library.pending
    Library.pending = nil
    if pending then
        local ok, err = pcall(pending.free, pending)
        if not ok then
            logger.err("KoPanda: could not free the pending library:", err)
        end
    end
end

-- Hands over the pending library when it was built at the screen's current size and in the
-- current variant; one of another size (showFiles resets the rotation) or variant is dropped.
-- Returns the library or nil. The closed book's tile is rebuilt, since the reader saves its
-- sidecar after CloseDocument, when the library was built (frontend/apps/reader/readerui.lua:887,
-- then :874-877 on its close at :893); a failure leaves the tile as built.
function Library.take_pending()
    local pending = Library.pending
    if not pending then
        return nil
    end
    local size = Screen:getSize()
    if pending.dimen.w ~= size.w or pending.dimen.h ~= size.h or pending.ctx.variant ~= Looks.variant() then
        Library.drop_pending()
        return nil
    end
    Library.pending = nil
    if pending.closed then
        -- A file's record id, as books.lua's record() makes it.
        local id = "file:" .. (ffiutil.realpath(pending.closed) or pending.closed)
        rebuild_tiles(pending, { [id] = true }, "the closed book's tile")
    end
    return pending
end

-- Paints the library, rebuilt first when the variant or the screen's size changed since its build
-- (night mode marks every window dirty, frontend/device/devicelistener.lua:14-27; a rotation), as
-- the editor does (editor.lua:360-369), with no repaint of its own.
local function paint(library, bb, x, y)
    local size = Screen:getSize()
    if library.ctx.variant ~= Looks.variant() or size.w ~= library.dimen.w or size.h ~= library.dimen.h then
        apply(library, LibraryView.build(library.dir, library.page))
    end
    InputContainer.paintTo(library, bb, x, y)
end

-- A widget can't be closed from inside the repaint, so a failed paint closes the library from the
-- next tick, leaving the file browser beneath. A page's covers are asked for, and a show settles,
-- from the next tick after its first paint.
function Library:paintTo(bb, x, y)
    local ok, err = pcall(paint, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = time.monotonic()
    end
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the library failed to paint:", err)
        UIManager:nextTick(function()
            close_library(self)
        end)
    end
    if ok and self.covers_due then
        self.covers_due = nil
        UIManager:nextTick(function()
            request_covers(self)
        end)
    end
    local opts = self.settle_opts
    if opts then
        self.settle_opts = nil
        UIManager:nextTick(function()
            settle(self, opts)
        end)
    end
end

-- Re-lists the folder and rebuilds the page shown, its page clamped if books went. A failure is
-- logged and leaves the page as it was.
function Library:refresh()
    if Library.shown == self then
        rebuild(self, self.dir, self.page)
    end
end

-- Broadcast to every window when a book's metadata or status changes and when its cached
-- metadata is dropped (frontend/apps/filemanager/filemanagerbookinfo.lua:276-277, :556-557;
-- frontend/ui/uimanager.lua:1042-1061). Return nothing, so the event reaches the other windows.
function Library:onBookMetadataChanged()
    self:refresh()
end

function Library:onInvalidateMetadataCache()
    self:refresh()
end

-- The page keys registered at init.
function Library:onNextPage()
    self:turn(1)
    return true
end

function Library:onPrevPage()
    self:turn(-1)
    return true
end

-- KOReader may close the library itself; Library.shown must not outlive it, nor its cover check.
-- The folder and page it was left at are stored (D11), and its tiles freed.
function Library:onCloseWidget()
    if Library.shown == self then
        Library.shown = nil
    end
    self.settle_opts = nil
    local ok, err = pcall(BookCovers.cancel)
    if not ok then
        logger.err("KoPanda: could not drop the library's cover check:", err)
    end
    local left_ok, left_err = pcall(LibraryOrder.leave, self.dir, self.page)
    if not left_ok then
        logger.err("KoPanda: could not store where the library was left:", left_err)
    end
    local frame = self[1]
    self[1] = nil
    if frame then
        local free_ok, free_err = pcall(frame.free, frame)
        if not free_ok then
            logger.err("KoPanda: could not free the library:", free_err)
        end
    end
end

-- The library's gestures, in order (LibraryGestures.route).
function Library:routeGesture(ges)
    return LibraryGestures.route(self, ges)
end

-- The library is not a plugin, so KOReader does not sandbox this handler: an error here would
-- reach the UI loop. A failure closes the library onto the file browser and consumes the gesture.
function Library:onGesture(ges)
    local ok, consumed = pcall(self.routeGesture, self, ges)
    if ok then
        return consumed
    end
    logger.err("KoPanda: the library failed to handle a gesture:", consumed)
    close_library(self)
    return true
end

return Library
