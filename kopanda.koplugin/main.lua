-- KoPanda: the owner's own interface for KOReader. KOReader makes an instance of this plugin in every file
-- manager and every reader; in a file manager it puts the home over the file browser when it is shown, and
-- closes it when the file browser closes. Every KoPanda module is required here, at load time: KOReader
-- prepends the plugin root to package.path only while it dofile()s this file (frontend/pluginloader.lua:242,
-- :269-270), so a later require could resolve to another plugin's same-named file (:283-286).
local AuthorsScreen = require("authors_screen")
local BookStatusScreen = require("book_status_screen")
local DispatchBridge = require("dispatch_bridge")
local Dispatcher = require("dispatcher")
local FmNav = require("fm_nav")
local FocusedHooks = require("focused_hooks")
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
local SearchScreen = require("search_screen")
local SeriesScreen = require("series_screen")
local State = require("state")
local StatsScreen = require("stats_screen")
local StudioMenu = require("studio_menu")
local SubjectsScreen = require("subjects_screen")
local Swatch = require("swatch")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local time = require("ui/time")
-- Required here only so they load while the plugin root is on package.path; the modules that
-- use them get them from the require cache.
require("book_covers")
require("book_index")
require("book_search")
require("book_sheet")
require("book_status")
require("books")
require("cloud_books")
require("editor")
require("entries_edit")
require("entry_picker")
require("featured_book")
require("featured_cover")
require("focused")
require("focused_panel")
require("folder_sheet")
require("goto_list")
require("goto_rows")
require("goto_screen")
require("helpers")
require("home_gestures")
require("home_rows")
require("home_sheet")
require("icons")
require("insight_tile")
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
require("looks/base")
require("looks/diner")
require("looks/editorial")
require("looks/frosted")
require("migrations")
require("nav_bar")
require("paint")
require("plate")
require("push_apply")
require("push_bundle")
require("push_pull")
require("quick_settings")
require("quotes")
require("reading_stats")
require("release_source")
require("schema")
require("settings")
require("settings_menu")
require("sheet")
require("sheet_layout")
require("shelf_order")
require("shelf_rows")
require("steppers")
require("tinted_icon")
require("title_bar")
require("typeset")
require("wallpaper")
require("weather")
require("widgets")
require("widgets/clock")
require("widgets/date")
require("widgets/featured")
require("widgets/forecast")
require("widgets/hours")
require("widgets/launcher")
require("widgets/months")
require("widgets/quote")
require("widgets/reading")
require("widgets/records")
require("widgets/streak")
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
                PushNotice.on_refused(self.path)
            end
            self.ui.menu:registerToMainMenu(self)
            return
        end
        self.in_fm = in_fm
        -- A reader starting means no file browser followed the last close, so that close is no
        -- longer one the next Show should answer at once.
        if not self.in_fm then
            Home.just_closed = false
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
        else
            -- Once per process; each gesture reads focused.on.
            FocusedHooks.install()
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
                PushNotice.on_painted(self.path)
            end
        end
    end
    Home.show(opts)
end

-- Shows the library with opts (Library.show's) unless the file manager has gone since the show was asked
-- for; the caller has closed the home. The library takes no part in the boot guard, which only the home's
-- first show arms. A library that fails to build is logged and the file browser left at the folder.
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

-- The Series, Authors and Subjects windows, by the screen a return names.
local SHELVES = { series = SeriesScreen, authors = AuthorsScreen, subjects = SubjectsScreen }

-- Shows a window of cls (SeriesScreen, AuthorsScreen, SubjectsScreen, SearchScreen or StatsScreen) with opts unless
-- the file manager has gone since the show was asked for; the window's show closes the home. Like the library's, it
-- takes no part in the boot guard; one that fails to build is logged by the chrome and the file browser left up.
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

-- The Subjects window with opts (SubjectsScreen.show's), as show_shelf.
function KoPanda:showSubjects(opts)
    show_shelf(SubjectsScreen, opts)
end

-- The Stats window with opts (StatsScreen.show's), as show_shelf.
function KoPanda:showStats(opts)
    show_shelf(StatsScreen, opts)
end

-- The library search's results with opts (SearchScreen.show's), as show_shelf.
function KoPanda:showSearch(opts)
    show_shelf(SearchScreen, opts)
end

-- The screen opener names shown again: the home for { screen = "home" }; the library at its folder (view) and
-- page; the Series, Authors or Subjects window at its view and page; the search's results for its query and
-- start (from) at their page.
local function show_opener(kopanda, opener)
    local screen = opener and opener.screen
    if screen == "library" then
        kopanda:showLibrary{ dir = opener.view, page = opener.page }
    elseif screen == "search" then
        show_shelf(SearchScreen, { query = opener.view.query, from = opener.from, page = opener.page })
    elseif SHELVES[screen] then
        show_shelf(SHELVES[screen], { view = opener.view, page = opener.page })
    else
        kopanda:showHome()
    end
end

-- The book status page with opts (BookStatusScreen.show's) unless the file manager has gone; like the library's,
-- it takes no part in the boot guard. One that fails to show is logged by the chrome, which closed the screen it
-- was opened from, so that is shown again. Returns the window shown, or nil.
function KoPanda:showBookStatus(opts)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if not (FileManager and FileManager.instance) then
        return nil
    end
    local screen = BookStatusScreen.show(opts)
    if not screen then
        show_opener(self, opts.opener)
    end
    return screen
end

-- The screen a book status page was opened from (its opener), shown again by the page's back control.
function KoPanda:showOpener(opener)
    show_opener(self, opener)
end

-- The window a book's close returns to and the fields it is built with: the library at the folder and page
-- a book was opened from, or the Series, Authors or Subjects window at the view and page; nil with no return
-- recorded.
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

-- The return after a book opened from a chrome window, cleared as it is taken: the window built and shown
-- now, inside the file manager's Show, so it reads the progress, status and counts the reader saved on its
-- close (frontend/apps/reader/readerui.lua:893, UIManager:close's FlushSettings, frontend/ui/uimanager.lua:298),
-- at the screen's size after showFiles reset the rotation (frontend/apps/filemanager/filemanager.lua:1322).
-- A view gone by then shows the list, which the window's build does itself.
local function show_return(kopanda)
    local cls, fields = return_window()
    Library.return_to, LibraryChrome.return_to = nil, nil
    local started = time.monotonic()
    if cls == Library then
        kopanda:showLibrary{ dir = fields.dir, page = fields.page, started = started }
    else
        show_shelf(cls, { view = fields.showing, page = fields.page, started = started })
    end
end

-- The file manager's Show. With a return to a chrome window recorded, that window goes up at once. Otherwise,
-- right after a book closed, the home goes up at once, inside Show, so it is on the stack before the next
-- repaint: the UI loop runs due tasks and then repaints (frontend/ui/uimanager.lua:1537-1564), and a nextTick
-- from inside a task, as when the end-of-book action closes the book
-- (frontend/apps/reader/modules/readerstatus.lua:144-148), is due at a fresh time.now() (uimanager.lua:416),
-- later than the _now that pass runs tasks to (:1082, :1090), so it would land after the repaint. Otherwise
-- the home goes up from the next tick, over whatever KOReader shows synchronously after showFiles. Returns
-- nothing: a true return would stop Show reaching later modules.
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

-- The closing book's file and the TOC title of its current page, into the state for the featured book. The
-- document is still open: CloseDocument is broadcast before closeDocument() (frontend/apps/reader/readerui.lua:887,
-- :891). The lookup fills an unfilled TOC itself and is "" when no entry covers the page
-- (frontend/apps/reader/modules/readertoc.lua:383-384, :446-453, :476-480). A failed lookup or write is
-- logged and the chapter cleared, so an old chapter never pairs with a new file. Both keys go in one write,
-- skipped when they hold these values already (each write fsyncs); State.unsaved() holds the skip off after
-- a failed state write, which can leave State's copy ahead of the file.
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
        if not State.unsaved() and State.get("featured_chapter_file") == ui.document.file
                and State.get("featured_chapter") == chapter then
            return
        end
        if not State.set_many({ featured_chapter_file = ui.document.file, featured_chapter = chapter }) then
            logger.err("KoPanda: could not record the chapter, clearing it")
            State.set("featured_chapter", "")
        end
    end)
    if not set_ok then
        logger.err("KoPanda: could not record the chapter:", err)
    end
end

-- A reader closing its book: record its chapter for the featured book, then, unless the book was opened from
-- a chrome window whose return the open recorded, mark the close, so Show builds the home at once. Neither
-- is built here: the window or the home is built at Show, after the reader saved its sidecar (UIManager:close's
-- FlushSettings, frontend/apps/reader/readerui.lua:893) and Statistics flushed the closing session. A reload
-- or switch sets tearing_down before closing (readerui.lua:952, :973; reader to reader, :600, :609) and marks
-- nothing. Returns nothing, so the event reaches later modules.
function KoPanda:onCloseDocument()
    if self.refused then
        return
    end
    record_chapter(self.ui)
    if self.in_fm then
        return
    end
    if return_window() then
        return
    end
    if self.ui and self.ui.tearing_down then
        return
    end
    Home.just_closed = true
end

-- The file manager closing (quit, or a book opening) takes the home and the chrome window with it; a window
-- left on the stack would keep KOReader from quitting. A return recorded by an open that never closed the
-- file manager is dropped once the window it was opened from has closed (the library's, from the library or
-- the search window).
function KoPanda:onCloseWidget()
    if self.refused then
        return
    end
    if self.in_fm then
        if not (Library.shown or SearchScreen.shown) then
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
        callback = Guards.after_menu("Tools › KoPanda › Swatches", Swatch.show),
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
            callback = Guards.guarded("the Home tab", function()
                self.ui.menu:onCloseFileManagerMenu()
                self:goHome()
            end),
        }
    end
    -- The quick-settings tab, just before Main in both menus: the shape of the reader's file-browser tab
    -- (readermenu.lua:65-74). Its callback closes the menu, then opens the sheet; in the reader nothing lies
    -- beneath the sheet to close on failure, so the page stays.
    local app = self.in_fm and "filemanager" or "reader"
    if MenuEntries.tab(app .. "_quick_settings") then
        menu_items.kopanda_quick_settings = {
            icon = "appbar.contrast",
            remember = false,
            callback = Guards.guarded("the Quick settings tab", function()
                local started = PaintClock.now()
                if self.in_fm then
                    self.ui.menu:onCloseFileManagerMenu()
                else
                    self.ui.menu:onTapCloseMenu()
                end
                require("quick_settings").open{
                    started = started,
                    beneath = not self.in_fm and { close = function() end } or nil,
                }
            end),
        }
    end
    menu_items.kopanda = {
        text = "KoPanda",
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = "Home",
                callback = Guards.after_menu("Tools › KoPanda › Home", function()
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
