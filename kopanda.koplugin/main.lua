-- KoPanda: the owner's own interface for KOReader. KOReader makes an instance of this plugin
-- in every file manager and every reader; in a file manager it puts the home over the file
-- browser when the file browser is shown, and closes it when the file browser closes.
--
-- Every KoPanda module is required here, at load time: KOReader prepends the plugin root to
-- package.path only while it dofile()s this file (frontend/pluginloader.lua:242, :269-270),
-- so a later require could resolve to another plugin's same-named file (:283-286).
local AuthorsScreen = require("authors_screen")
local DispatchBridge = require("dispatch_bridge")
local Dispatcher = require("dispatcher")
local FmNav = require("fm_nav")
require("fonts") -- loaded now for the looks and swatch modules, which reach it later
local Guards = require("guards")
local Home = require("home")
local InfoMessage = require("ui/widget/infomessage")
local Library = require("library")
local LibraryChrome = require("library_chrome")
local MenuEntries = require("menu_entries")
local PaintClock = require("paint_clock")
local PushNotice = require("push_notice")
local SchemaMenu = require("menu")
local SeriesScreen = require("series_screen")
local State = require("state")
local StudioMenu = require("studio_menu")
local Swatch = require("swatch")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local time = require("ui/time")
-- Required here only so they load while the plugin root is on package.path; the modules that
-- use them get them from the require cache.
require("book_covers")
require("book_index")
require("book_sheet")
require("books")
require("cloud_books")
require("edit_layout")
require("editor")
require("entries_edit")
require("entry_picker")
require("featured_book")
require("featured_cover")
require("folder_sheet")
require("home_gestures")
require("home_rows")
require("home_sheet")
require("icons")
require("launcher_entries")
require("launcher_manage")
require("layout")
require("library_covers")
require("library_order")
require("library_pickers")
require("library_sheets")
require("library_tiles")
require("library_view")
require("location_search")
require("looks")
require("looks/diner")
require("looks/editorial")
require("migrations")
require("nav_bar")
require("paint")
require("push_apply")
require("push_bundle")
require("push_pull")
require("quick_settings")
require("quotes")
require("reading_stats")
require("rows_edit")
require("schema")
require("settings")
require("settings_menu")
require("sheet")
require("sheet_layout")
require("shelf_order")
require("shelf_rows")
require("tinted_icon")
require("title_bar")
require("typeset")
require("weather")
require("widgets")
require("widgets/clock")
require("widgets/date")
require("widgets/featured")
require("widgets/launcher")
require("widgets/quote")
require("widgets/stats")
require("widgets/weather")

-- The boot guard covers only the first show of a process.
local first_show_done = false

local KoPanda = WidgetContainer:extend{
    name = "kopanda",
    is_doc_only = false,
}

function KoPanda:init()
    local ok, err = pcall(function()
        -- The file manager makes instances with { ui = self }; the reader adds `document`.
        local in_fm = self.ui ~= nil and self.ui.document == nil
        -- With another shell enabled this instance does nothing but offer Tools › KoPanda ›
        -- Swatches, a test pattern rather than part of the shell; every handler checks it first.
        if Guards.refused() then
            self.refused = true
            if in_fm then
                Guards.notify_once()
                -- A pull's result shows here in place of the home, unless it is on probation.
                PushNotice.on_refused()
            end
            self.ui.menu:registerToMainMenu(self)
            return
        end
        self.in_fm = in_fm
        -- A reader starting means no file browser followed the last close, so that close is no
        -- longer one the next Show should answer at once, and the chrome window built for it is
        -- not needed.
        if not self.in_fm then
            Home.just_closed = false
            LibraryChrome.drop_pending()
        end
        -- DispatcherRegisterActions is broadcast once, from Dispatcher:init (frontend/dispatcher.lua:585-586,
        -- :645), which can run before this instance exists, so the action is also registered here.
        self:onDispatcherRegisterActions()
        self.ui.menu:registerToMainMenu(self)
        -- Once per process; it acts only while a home is shown.
        DispatchBridge.install()
        -- Once per process, before the file manager's first layout (filemanager.lua:418-431).
        if self.in_fm then
            FmNav.install()
        end
    end)
    if not ok then
        logger.err("KoPanda: init failed:", err)
    end
end

-- Builds and shows the home unless one is up or the file manager has gone since the show was
-- scheduled. started is the PaintClock stamp of when the show path began (default: now).
function KoPanda:showHome(started)
    if Home.shown then
        return
    end
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if not (FileManager and FileManager.instance) then
        return
    end
    started = started or PaintClock.now()
    local opts = { started = started }
    if not first_show_done then
        first_show_done = true
        -- Still set from the last start: that home never finished drawing. Skip it this once,
        -- but only once the flag is cleared; a flag that can't be cleared would skip it on every
        -- start, so then the home shows without a guard.
        if State.get("boot_pending") then
            if State.set("boot_pending", false) then
                UIManager:nextTick(function()
                    local ok, err = pcall(function()
                        UIManager:show(InfoMessage:new{
                            text = "At the last start KoPanda's home stopped before it was drawn, "
                                .. "so it's left out this once. The Home tab or Tools › KoPanda "
                                .. "brings it back.",
                            timeout = 8,
                        })
                    end)
                    if not ok then
                        logger.err("KoPanda: could not show the boot guard notice:", err)
                    end
                end)
                return
            end
            logger.err("KoPanda: could not clear the boot guard flag; showing the home unguarded")
            Home.show(opts)
            return
        end
        State.set("boot_pending", true)
        -- Run after the home's first paint, or on a caught failure of its build, show or paint;
        -- only a home that painted ends a pull's probation and shows its result.
        opts.finished = function(painted)
            State.set("boot_pending", false)
            if painted then
                PushNotice.on_painted()
            end
        end
    end
    Home.show(opts)
end

-- Shows the library with opts (Library.show's) unless the file manager has gone since the show
-- was asked for; the caller has closed the home. The library takes no part in the boot guard,
-- which only the process's first show, the home's, arms. A library that fails to build is logged
-- by Library.show and the file browser left at the folder (opts.dir, else the library's root).
function KoPanda:showLibrary(opts)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if not fm then
        return
    end
    if Library.show(opts) then
        return
    end
    fm.file_chooser:changeToPath(opts.dir or require("library_view").root())
end

-- The Series and Authors windows, by the screen a return names.
local SHELVES = { series = SeriesScreen, authors = AuthorsScreen }

-- Shows a window of cls (SeriesScreen or AuthorsScreen) with opts (its show's) unless the file
-- manager has gone since the show was asked for; the window's show closes the home. As the
-- library's, it takes no part in the boot guard; one that fails to build is logged by the chrome
-- and the file browser left up.
local function show_shelf(cls, opts)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if FileManager and FileManager.instance then
        cls.show(opts)
    end
end

-- The Series window with opts (SeriesScreen.show's), as show_shelf.
function KoPanda:showSeries(opts)
    show_shelf(SeriesScreen, opts)
end

-- The Authors window with opts (AuthorsScreen.show's), as show_shelf.
function KoPanda:showAuthors(opts)
    show_shelf(AuthorsScreen, opts)
end

-- The window a book's close returns to and the fields it is built with: the library at the folder
-- and page a book was opened from (cover-grid D4), or the Series or Authors window at the view and
-- page (series-and-authors D7); nil with no return recorded.
local function return_window()
    local back = Library.return_to
    if back then
        return Library, { dir = back.dir, page = back.page }
    end
    back = LibraryChrome.return_to
    if back then
        return SHELVES[back.screen], { showing = back.view, page = back.page }
    end
    return nil
end

-- The return after a book opened from a chrome window, cleared as it is taken: the window pre-built
-- on its close when one fits the screen, else one built afresh at the return (another size or
-- variant, or a failed open that sent no CloseDocument). A view gone by then shows the list
-- (series-and-authors D23), which the window's build does itself.
local function show_return(kopanda)
    local cls, fields = return_window()
    Library.return_to, LibraryChrome.return_to = nil, nil
    local started = time.monotonic()
    local pending = LibraryChrome.take_pending()
    if cls == Library then
        kopanda:showLibrary{ widget = pending, dir = fields.dir, page = fields.page, started = started }
    else
        show_shelf(cls, { widget = pending, view = fields.showing, page = fields.page, started = started })
    end
end

-- The file manager's Show. With a return to a chrome window recorded, that window goes up at once.
-- Otherwise, right after a book closed, the home is built and goes up at once, inside Show, so
-- it is on the stack before the next repaint even when the close ran from a scheduled task, and
-- nothing of start_with follows a book close. The UI loop runs due tasks and then repaints
-- (frontend/ui/uimanager.lua:1537-1564); a nextTick from inside a task, as when the end-of-book
-- action closes the book (frontend/apps/reader/modules/readerstatus.lua:144-148), is due at a
-- fresh time.now() (uimanager.lua:416), later than the _now that pass runs tasks to (:1082,
-- :1090), so it would land after that repaint and the file browser would be painted first.
-- Otherwise the home goes up from the next tick, so it lands over whatever KOReader shows
-- synchronously after showFiles (history, favorites, folder shortcuts). Returns nothing: a true
-- return would stop Show reaching later modules.
function KoPanda:onShow()
    if self.refused then
        return
    end
    if not self.in_fm then
        return
    end
    if return_window() then
        local show_ok, show_err = pcall(show_return, self)
        if not show_ok then
            logger.err("KoPanda: could not show the window returned to:", show_err)
        end
        return
    end
    if Home.just_closed then
        Home.just_closed = false
        local show_ok, show_err = pcall(self.showHome, self, PaintClock.now())
        if not show_ok then
            logger.err("KoPanda: could not show the home:", show_err)
        end
        return
    end
    local ok, err = pcall(UIManager.nextTick, UIManager, function()
        local show_ok, show_err = pcall(self.showHome, self)
        if not show_ok then
            logger.err("KoPanda: could not show the home:", show_err)
        end
    end)
    if not ok then
        logger.err("KoPanda: could not schedule the home:", err)
    end
end

-- The closing book's file and the TOC title of its current page, into the state for the
-- featured book. The document is still open: CloseDocument is broadcast before closeDocument()
-- (frontend/apps/reader/readerui.lua:887, :891). The lookup fills an unfilled TOC itself and is
-- "" when no entry covers the page (frontend/apps/reader/modules/readertoc.lua:383-384,
-- :446-453, :476-480). A failed lookup is logged and records the chapter as "", so the book
-- keeps no chapter from an earlier close. Both keys go in one write, skipped when they hold
-- these values already, since each write fsyncs on the way to the home. A failed write is logged
-- and the chapter cleared, so an old chapter never pairs with a new file. A failed write leaves
-- State's in-memory copy ahead of the file, so chapter_unsaved holds off the skip until a write
-- succeeds: the skip compares against the last successful write.
local chapter_unsaved = false

local function record_chapter(ui)
    if not (ui and ui.document and ui.toc) then
        return
    end
    local ok, chapter = pcall(ui.toc.getTocTitleOfCurrentPage, ui.toc)
    if not ok then
        logger.err("KoPanda: could not look up the chapter:", chapter)
        chapter = ""
    end
    chapter = chapter or ""
    local set_ok, err = pcall(function()
        if not chapter_unsaved and State.get("featured_chapter_file") == ui.document.file
                and State.get("featured_chapter") == chapter then
            return
        end
        if State.set_many({ featured_chapter_file = ui.document.file, featured_chapter = chapter }) then
            chapter_unsaved = false
        else
            chapter_unsaved = true
            logger.err("KoPanda: could not record the chapter, clearing it")
            State.set("featured_chapter", "")
        end
    end)
    if not set_ok then
        logger.err("KoPanda: could not record the chapter:", err)
    end
end

-- A reader closing its book: record its chapter for the featured book, then, when the book was
-- opened from a chrome window (the library, Series or Authors), build that window for the return
-- (CloseDocument also fires on reload, switch and exit, with no file browser after; that build is
-- wasted, which is accepted, and the next reader's init drops it); else mark the close, so the
-- file manager's Show that usually follows builds the home at once. The home is built there,
-- after the reader saved its sidecar (UIManager:close's FlushSettings,
-- frontend/apps/reader/readerui.lua:893) and Statistics, whose handler runs after this one,
-- flushed the closing session. A reload or switch sets tearing_down before closing
-- (readerui.lua:952, :973; reader to reader, :600, :609) and marks nothing; exit marks the close,
-- but no Show follows. Returns nothing, so the event reaches later modules.
function KoPanda:onCloseDocument()
    if self.refused then
        return
    end
    record_chapter(self.ui)
    if self.in_fm then
        return
    end
    local cls, fields = return_window()
    if cls then
        if not LibraryChrome.pending then
            LibraryChrome.prebuild(cls, fields, self.ui.document and self.ui.document.file)
        end
        return
    end
    if self.ui and self.ui.tearing_down then
        return
    end
    Home.just_closed = true
end

-- The file manager closing (quit, or a book opening) takes the home and the chrome window with it;
-- a window left on the stack would keep KOReader from quitting. A return recorded by an open that
-- never closed the file manager (a refused file) is dropped once the window it names has closed,
-- so a book opened from anywhere else closes to the home.
function KoPanda:onCloseWidget()
    if self.refused then
        return
    end
    if self.in_fm then
        if not Library.shown then
            Library.return_to = nil
        end
        local back = LibraryChrome.return_to
        if back and not SHELVES[back.screen].shown then
            LibraryChrome.return_to = nil
        end
        Home.close()
        LibraryChrome.close()
    end
end

-- The home from anywhere: in the file manager it goes up (nothing happens when it is up); in
-- the reader the book closes and the file manager's Show brings the home.
function KoPanda:goHome()
    if self.in_fm then
        self:showHome()
    else
        self.ui:onHome()
    end
end

-- f wrapped so an error is logged rather than reaching KOReader's menu or UI loop.
local function guarded(what, f)
    return function()
        local ok, err = pcall(f)
        if not ok then
            logger.err("KoPanda: " .. what .. " failed:", err)
        end
    end
end

-- A menu item's callback runs before the menu closes (frontend/ui/widget/touchmenu.lua:913-926),
-- so the item acts from the next tick.
local function after_menu(what, f)
    return guarded(what, function()
        UIManager:nextTick(guarded(what, f))
    end)
end

function KoPanda:onDispatcherRegisterActions()
    if self.refused then
        return
    end
    Dispatcher:registerAction("kopanda_home", {
        category = "none",
        event = "KoPandaHome",
        title = "KoPanda: home",
        general = true,
    })
end

-- The KoPanda: home action. When the home is up it is on top and consumes the event first.
function KoPanda:onKoPandaHome()
    if self.refused then
        return
    end
    self:goHome()
    return true
end

function KoPanda:addToMainMenu(menu_items)
    local swatches = {
        text = "Swatches",
        callback = after_menu("Tools › KoPanda › Swatches", Swatch.show),
    }
    -- The Studio's pull works from both menus: the first pull onto a device runs while another
    -- shell is still enabled.
    local studio = StudioMenu.item(self)
    if self.refused then
        menu_items.kopanda = {
            text = "KoPanda",
            sorting_hint = "tools",
            sub_item_table = { studio, swatches },
        }
        return
    end
    if self.in_fm and MenuEntries.home_tab() then
        -- A tab that acts on tap (filemanagermenu.lua:841-848). remember = false keeps its index
        -- from being saved (touchmenu.lua:452-464, :777-779).
        menu_items.kopanda_home = {
            icon = "home",
            remember = false,
            callback = guarded("the Home tab", function()
                self.ui.menu:onCloseFileManagerMenu()
                self:goHome()
            end),
        }
    end
    menu_items.kopanda = {
        text = "KoPanda",
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = "Home",
                callback = after_menu("Tools › KoPanda › Home", function()
                    self:goHome()
                end),
            },
            -- A native submenu: the rows open inside KOReader's menu, whose back arrow returns
            -- here. A failed build gives no rows, which TouchMenu ignores (touchmenu.lua:892-911).
            {
                text = "Settings",
                sub_item_table_func = function()
                    local ok, items = pcall(SchemaMenu.items)
                    if not ok then
                        logger.err("KoPanda: Tools › KoPanda › Settings failed:", items)
                        return {}
                    end
                    return items
                end,
            },
            studio,
            swatches,
        },
    }
end

return KoPanda
