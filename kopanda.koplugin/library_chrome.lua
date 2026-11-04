-- The chrome the library's windows share: a full-screen KoPanda window over the file manager (the Go to screen's over
-- the reader), its paint and settled signal and the library's books the windows share while one is up, with the
-- drawing (library_chrome_frame.lua, re-exported here) and the gesture route (library_chrome_gestures.lua) beside it.
-- A window module extends LibraryChrome.Window and supplies the fields and functions library.lua shows;
-- LibraryChrome.shown is the window on screen.
local BookCovers = require("book_covers")
local Books = require("books")
local ChromeFrame = require("library_chrome_frame")
local ChromeGestures = require("library_chrome_gestures")
local Device = require("device")
local Home = require("home")
local InputContainer = require("ui/widget/container/inputcontainer")
local LibraryTiles = require("library_tiles")
local Looks = require("looks")
local Sheet = require("sheet")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local time = require("ui/time")
local Screen = Device.screen

local LibraryChrome = {}

LibraryChrome.box = ChromeFrame.box
LibraryChrome.add = ChromeFrame.add
LibraryChrome.tools = ChromeFrame.tools
LibraryChrome.detail_header_height = ChromeFrame.detail_header_height
LibraryChrome.chip = ChromeFrame.chip
LibraryChrome.header = ChromeFrame.header
LibraryChrome.foot = ChromeFrame.foot
LibraryChrome.build = ChromeFrame.build

LibraryChrome.shown = nil
-- { screen, view, page }: where the next file manager's show returns to after a book opened from the Series,
-- Authors or Subjects window; in memory only.
LibraryChrome.return_to = nil

-- The library's books (LibraryChrome.books) while a window is up: { root, launched, running, records }, or nil until
-- the next take.
local books = nil
-- Whether LibraryChrome.show is closing the window shown to put its own in its place, which leaves the books kept.
local swapping = false

-- The library's books as Books.all lists them, in a list of the caller's own, its records shared (keep_downloaded's
-- patch stays in them, so a downloaded book keeps its place on the other windows): walked once while the library
-- stays open under one root (filemanagerutil.lua:25-27). Books.all reads CoverBrowser's rows (books.lua's record), so
-- a walk is trusted only while no extraction started since and none ran when it was taken (BookCovers.extractions).
function LibraryChrome.books()
    local root = require("apps/filemanager/filemanagerutil").getHomeFolder()
    local launched, running = BookCovers.extractions()
    if not books or books.root ~= root or books.launched ~= launched or books.running then
        books = { root = root, launched = launched, running = running, records = Books.all() }
    end
    local list = {}
    for i, record in ipairs(books.records) do
        list[i] = record
    end
    return list
end

-- Drops the library's books, so the next take walks the library again.
function LibraryChrome.forget_books()
    books = nil
end

-- Sets LibraryChrome[slot] ("shown") to window or nil, and the same slot of the class of the window
-- it names, so the class slot names only one of its own.
local function hold(slot, window)
    local old = LibraryChrome[slot]
    if old then
        getmetatable(old)[slot] = nil
    end
    LibraryChrome[slot] = window
    if window then
        getmetatable(window)[slot] = window
    end
end

local Window = InputContainer:extend{
    name = "kopanda_library_window",
    -- UIManager:_repaint skips paintTo beneath the topmost such widget.
    covers_fullscreen = true,
    screen = "window",
    fields = {},
    page = nil,
}
LibraryChrome.Window = Window
Window.tap = ChromeGestures.tap
Window.routeGesture = ChromeGestures.routeGesture

local FIELDS = { "page", "pages", "dimen", "ctx", "header", "pager", "nav" }

-- Puts built in place of what the window showed, and frees that.
local function apply(window, built)
    local old = window[1]
    window[1] = built.frame
    for _, list in ipairs({ FIELDS, window.fields }) do
        for _, field in ipairs(list) do
            window[field] = built[field]
        end
    end
    if old then
        old:free()
    end
end

local function close_window(window)
    if LibraryChrome.shown == window then
        hold("shown", nil)
    end
    local ok, err = pcall(UIManager.close, UIManager, window, "full")
    if not ok then
        logger.err("KoPanda: could not close the " .. window.screen .. ":", err)
    end
end

function Window:init()
    self.dimen = Screen:getSize()
    self:registerTouchZones(ChromeGestures.own_zones(self))
    -- As Menu registers its page keys (frontend/ui/widget/menu.lua:984-992).
    if Device:hasKeys() then
        self.key_events.NextPage = { { Device.input.group.PgFwd } }
        self.key_events.PrevPage = { { Device.input.group.PgBack } }
    end
    apply(self, self:build(self:view(), self.page))
    self.covers_due = true
end

-- Builds view at page in place and repaints. A failure is logged and leaves the page as it was.
-- Returns whether it built.
local function rebuild(window, view, page)
    local ok, built = pcall(window.build, window, view, page)
    if not ok then
        logger.err("KoPanda: could not build the " .. window.screen .. " at", view, "page", page, ":", built)
        return false
    end
    apply(window, built)
    UIManager:setDirty(window, "ui")
    return true
end

-- Shows view at page (clamped to its pages) in place, its covers asked for after its first paint.
-- A failure is logged and leaves the page as it was.
function Window:go(view, page)
    if not rebuild(self, view, page) then
        return
    end
    self.covers_due = true
end

-- An arrival of records for window (LibraryChrome.request_records), while alive.
local function arrive(window, arrived, alive)
    if not alive() then
        return
    end
    local ok, err = pcall(function()
        local fresh, drawn = {}, false
        for _, record in ipairs(arrived) do
            fresh[record.id] = Books.get(record.id) or record
            drawn = drawn or window.drawn[record.id] or false
            if window.downloads then
                window.downloads[record.id] = nil
            end
        end
        local records = {}
        for i, record in ipairs(window.records) do
            records[i] = fresh[record.id] or record
        end
        window.records = records
        local keys = window:page_keys(window:view(), window.page)
        if drawn or table.concat(keys, "\0") ~= table.concat(window.keys, "\0") then
            rebuild(window, window:view(), window.page)
        end
    end)
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s cover arrival failed:", err)
    end
end

-- Asks once per window, while it is the one shown, for the covers of every one of window.records at the
-- cover box the library grid draws on a window this size, the largest these windows draw. An arrival
-- re-reads each arrived record (Books.get) and rebuilds the view, repainting, only when
-- window:page_keys(view, page) differs from window.keys or the page draws an arrived record (window.drawn).
-- A failure is logged with the page as it was.
function LibraryChrome.request_records(window)
    if window.records_asked or LibraryChrome.shown ~= window then
        return
    end
    window.records_asked = true
    local function alive()
        return LibraryChrome.shown == window
    end
    local ok, err = pcall(function()
        local box = LibraryTiles.geometry(window.dimen.w, window.ctx,
            { room = LibraryTiles.room(window.dimen.h, window.ctx) })
        BookCovers.request(window.records, { max_cover_w = box.cover_w, max_cover_h = box.cover_h },
            function(arrived)
                arrive(window, arrived, alive)
            end,
            alive)
    end)
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s cover request failed:", err)
    end
end

-- The page delta pages on, unless that is past the first or the last (no wrap).
function Window:turn(delta)
    local page = self.page + delta
    if page >= 1 and page <= self.pages then
        self:go(self:view(), page)
    end
end

-- Opens record's file as the file browser's own tap does (filemanager.lua:160-169), which asks first when
-- "ask before opening" is set, running the window's on_open with the view and page once the open goes ahead
-- (filemanagerutil.lua:498-502). Without a file manager it opens nothing.
function Window:open(record)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if not fm then
        return
    end
    local view, page = self:view(), self.page
    require("apps/filemanager/filemanagerutil").openFile(fm, record.path, function()
        self.on_open(view, page)
    end)
end

-- Signals the window's first paint on the dev loop's settled hook, once per show, as the home's;
-- paint_ms runs from opts.started. A window whose paint failed sends none.
local function settle(window, opts)
    if window.paint_failed then
        return
    end
    local ok, err = pcall(UIManager.event_hook.execute, UIManager.event_hook, "KoPandaSettled", {
        screen = window.screen,
        paint_ms = time.to_ms((window.painted_at or time.monotonic()) - opts.started),
    })
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s settled signal failed:", err)
    end
end

-- Shows a window of cls, built now as cls:new(fields). opts.started is time.monotonic() at the start of the
-- show path (default: now), so paint_ms includes the build. Closes the home and the window shown, the library's books
-- kept, shows this one and returns it; on any error it is taken off the stack, nil returned and the screen beneath
-- left alone, the books dropped.
function LibraryChrome.show(cls, opts, fields)
    local started = opts.started or time.monotonic()
    local window
    local ok, err = pcall(function()
        Home.close()
        swapping = true
        LibraryChrome.close()
        swapping = false
        window = cls:new(fields)
        hold("shown", window)
        UIManager:show(window, "full")
        window.settle_opts = { started = started }
    end)
    if ok then
        return window
    end
    logger.err("KoPanda: could not show the " .. cls.screen .. ":", err)
    swapping = false
    books = nil
    if window and UIManager:isWidgetShown(window) then
        close_window(window)
    end
    hold("shown", nil)
    return nil
end

-- Closes the window shown, if any.
function LibraryChrome.close()
    if LibraryChrome.shown then
        close_window(LibraryChrome.shown)
    end
end

-- Paints the window, rebuilt first when the variant or the screen's size changed since its build
-- (night mode marks every window dirty, frontend/device/devicelistener.lua:14-27; a rotation), as
-- the editor does (editor.lua:343-349), with no repaint of its own.
local function paint(window, bb, x, y)
    local size = Screen:getSize()
    if window.ctx.variant ~= Looks.variant() or size.w ~= window.dimen.w or size.h ~= window.dimen.h then
        apply(window, window:build(window:view(), window.page))
    end
    InputContainer.paintTo(window, bb, x, y)
end

-- A widget can't be closed from inside the repaint, so a failed paint closes the window from the
-- next tick, leaving the file browser or the reader beneath. A page's covers are asked for, and a
-- show settles, from the next tick after its first paint.
function Window:paintTo(bb, x, y)
    local ok, err = pcall(paint, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = time.monotonic()
    end
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the " .. self.screen .. " failed to paint:", err)
        UIManager:nextTick(function()
            close_window(self)
        end)
    end
    if ok and self.covers_due then
        self.covers_due = nil
        UIManager:nextTick(function()
            self:request_covers()
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

function Window:request_covers() end

function Window:closing() end

-- The window's own re-read at a refresh, before its rebuild.
function Window:relist() end

-- Re-lists the view and rebuilds the page shown, its page clamped if items went: the library's books dropped, the
-- window's re-read (relist), then the rebuild. A failure is logged and leaves the page as it was.
function Window:refresh()
    if LibraryChrome.shown == self then
        books = nil
        self:relist()
        rebuild(self, self:view(), self.page)
    end
end

-- A re-list of window's books, keeping the title, authors, series, series_index and subjects of each book
-- window:downloaded was given whose CoverBrowser row hasn't come back (cover "missing"): cwngsync's
-- broadcast had CoverBrowser delete the row (plugins/coverbrowser.koplugin/main.lua:800-803), and the series,
-- authors and subjects come only from it, so the book stays in its place until the arrival re-reads it. A book whose
-- row is back is listed by it and forgotten. Returns records.
function LibraryChrome.keep_downloaded(window, records)
    local downloads = window.downloads or {}
    for _, record in ipairs(records) do
        local listed = downloads[record.id]
        if listed and record.cover == "missing" then
            record.title, record.authors = listed.title, listed.authors
            record.series, record.series_index = listed.series, listed.series_index
            record.subjects = listed.subjects
        elseif listed then
            downloads[record.id] = nil
        end
    end
    return records
end

-- After cwngsync downloaded record's book over its placeholder: the view re-listed (window:refresh()),
-- record kept in its place until its row is back (LibraryChrome.keep_downloaded), then every one of
-- window.records' covers asked for again after the paint (BookCovers asks only for a file not yet asked,
-- so on a page of cached covers that is the downloaded book alone). The re-list stands for the one
-- cwngsync's broadcasts left due (refresh_soon), which is dropped. The library's books are dropped either way;
-- nothing else while the window isn't shown.
function Window:downloaded(record)
    books = nil
    if LibraryChrome.shown ~= self then
        return
    end
    self.downloads = self.downloads or {}
    self.downloads[record.id] = record
    self:refresh()
    self.stale = nil
    self.records_asked = nil
    self.covers_due = true
end

-- Marks the window stale and refreshes it once from the next tick, however many events marked it: one
-- change broadcasts InvalidateMetadataCache and BookMetadataChanged, and a second BookMetadataChanged when
-- the summary changed too (filemanagerbookinfo.lua:276-280, :556-557). The book-info page broadcasts after
-- UIManager:close (frontend/ui/widget/keyvaluepage.lua:841-846), inside the input dispatch
-- (frontend/ui/uimanager.lua:1607-1620), so the tick runs at the next pass's _checkTasks, before that
-- pass's _repaint paints the close (:431-433, :1537-1564, :1663). A window closed by then is not refreshed. The
-- library's books are dropped at once.
local function refresh_soon(window)
    books = nil
    if window.stale then
        return
    end
    window.stale = true
    UIManager:nextTick(function()
        if window.stale then
            window.stale = nil
            window:refresh()
        end
    end)
end

-- Broadcast to every window when a book's metadata or status changes and when its cached
-- metadata is dropped (frontend/apps/filemanager/filemanagerbookinfo.lua:276-277, :556-557;
-- frontend/ui/uimanager.lua:1042-1061). Return nothing, so the event reaches the other windows.
function Window:onBookMetadataChanged()
    refresh_soon(self)
end

function Window:onInvalidateMetadataCache()
    refresh_soon(self)
end

-- The page keys registered at init.
function Window:onNextPage()
    self:turn(1)
    return true
end

function Window:onPrevPage()
    self:turn(-1)
    return true
end

-- KOReader may close the window itself; LibraryChrome.shown must not outlive it, nor its cover
-- check, nor a sheet shown over it, as the home closes its own. Then the
-- window's own part (closing), and its frame freed. UIManager:close sends CloseWidget before it returns
-- (frontend/ui/uimanager.lua:300), so a close that is no show's swap has left the library, and its books are dropped.
function Window:onCloseWidget()
    if LibraryChrome.shown == self then
        hold("shown", nil)
    end
    if not swapping then
        books = nil
    end
    self.settle_opts = nil
    local sheet_ok, sheet_err = pcall(Sheet.close)
    if not sheet_ok then
        logger.err("KoPanda: could not close the sheet over the " .. self.screen .. ":", sheet_err)
    end
    local ok, err = pcall(BookCovers.cancel)
    if not ok then
        logger.err("KoPanda: could not drop the " .. self.screen .. "'s cover check:", err)
    end
    self:closing()
    local frame = self[1]
    self[1] = nil
    if frame then
        local free_ok, free_err = pcall(frame.free, frame)
        if not free_ok then
            logger.err("KoPanda: could not free the " .. self.screen .. ":", free_err)
        end
    end
end

-- A window is not a plugin, so KOReader does not sandbox this handler: an error here would reach
-- the UI loop. A failure closes the window onto the file browser or the reader beneath it and
-- consumes the gesture.
function Window:onGesture(ges)
    local ok, consumed = pcall(self.routeGesture, self, ges)
    if ok then
        return consumed
    end
    logger.err("KoPanda: the " .. self.screen .. " failed to handle a gesture:", consumed)
    close_window(self)
    return true
end

return LibraryChrome
