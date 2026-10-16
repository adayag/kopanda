-- KoPanda: the owner's own interface for KOReader. KOReader makes an instance of this plugin
-- in every file manager and every reader; in a file manager it puts the home over the file
-- browser when the file browser is shown, and closes it when the file browser closes.
--
-- Every KoPanda module is required here, at load time: KOReader prepends the plugin root to
-- package.path only while it dofile()s this file (frontend/pluginloader.lua:242, :269-270),
-- so a later require could resolve to another plugin's same-named file (:283-286).
local DispatchBridge = require("dispatch_bridge")
local Dispatcher = require("dispatcher")
require("fonts") -- loaded now for the looks and swatch modules, which reach it later
local Guards = require("guards")
local Home = require("home")
local InfoMessage = require("ui/widget/infomessage")
local MenuEntries = require("menu_entries")
local SchemaMenu = require("menu")
local State = require("state")
local Swatch = require("swatch")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local time = require("ui/time")
-- Required here only so they load while the plugin root is on package.path; the modules that
-- use them get them from the require cache.
require("book_sheet")
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
require("location_search")
require("looks")
require("looks/diner")
require("looks/editorial")
require("migrations")
require("nav_bar")
require("paint")
require("quotes")
require("reading_stats")
require("rows_edit")
require("schema")
require("settings")
require("settings_menu")
require("sheet")
require("tinted_icon")
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
            end
            self.ui.menu:registerToMainMenu(self)
            return
        end
        self.in_fm = in_fm
        -- A reader starting means no file browser followed the last close (a switch or a
        -- reload), so the home built for it is not needed.
        if not self.in_fm then
            Home.drop_pending()
        end
        -- DispatcherRegisterActions is broadcast once, from Dispatcher:init (frontend/dispatcher.lua:585-586,
        -- :645), which can run before this instance exists, so the action is also registered here.
        self:onDispatcherRegisterActions()
        self.ui.menu:registerToMainMenu(self)
        -- Once per process; it acts only while a home is shown.
        DispatchBridge.install()
    end)
    if not ok then
        logger.err("KoPanda: init failed:", err)
    end
end

-- Shows the home unless one is up or the file manager has gone since the show was scheduled:
-- the pending home when there is one at the screen's size, a fresh build otherwise. started is
-- when the show path began (default: now).
function KoPanda:showHome(started)
    if Home.shown then
        return
    end
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if not (FileManager and FileManager.instance) then
        return
    end
    started = started or time.monotonic()
    local opts = { started = started }
    -- The home built when the last book closed, if it still fits the screen.
    local function use_pending()
        local pending = Home.take_pending()
        if pending then
            opts.widget = pending
            opts.prebuilt = true
        end
    end
    if not first_show_done then
        first_show_done = true
        -- Still set from the last start: that home never finished drawing. Skip it this once,
        -- but only once the flag is cleared; a flag that can't be cleared would skip it on every
        -- start, so then the home shows without a guard.
        if State.get("boot_pending") then
            if State.set("boot_pending", false) then
                Home.drop_pending()
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
            use_pending()
            Home.show(opts)
            return
        end
        State.set("boot_pending", true)
        -- Run after the home's first paint, or on a caught failure of its build, show or paint.
        opts.finished = function()
            State.set("boot_pending", false)
        end
    end
    use_pending()
    Home.show(opts)
end

-- The file manager's Show. With a home pending (a book just closed) it goes up at once, inside
-- Show, so it is on the stack before the next repaint even when the close ran from a scheduled
-- task, and nothing of start_with follows a book close. Otherwise the home goes up from the
-- next tick, so it lands over whatever KOReader shows synchronously after showFiles (history,
-- favorites, folder shortcuts). Returns nothing: a true return would stop Show reaching later
-- modules.
function KoPanda:onShow()
    if self.refused then
        return
    end
    if not self.in_fm then
        return
    end
    if Home.pending then
        local show_ok, show_err = pcall(self.showHome, self, time.monotonic())
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
-- keeps no chapter from an earlier close. A failed write is logged and the chapter cleared, so
-- an old chapter never pairs with a new file.
local function record_chapter(ui)
    if not (ui and ui.document and ui.toc) then
        return
    end
    local ok, chapter = pcall(ui.toc.getTocTitleOfCurrentPage, ui.toc)
    if not ok then
        logger.err("KoPanda: could not look up the chapter:", chapter)
        chapter = ""
    end
    local set_ok, err = pcall(function()
        local file_written = State.set("featured_chapter_file", ui.document.file)
        local chapter_written = State.set("featured_chapter", chapter or "")
        if not (file_written and chapter_written) then
            logger.err("KoPanda: could not record the chapter, clearing it")
            State.set("featured_chapter", "")
        end
    end)
    if not set_ok then
        logger.err("KoPanda: could not record the chapter:", err)
    end
end

-- A reader closing its book: record its chapter for the featured book, then build the home
-- now, so the file browser that usually follows shows it without a build. CloseDocument also
-- fires on reload, switch and exit, with no file browser after; that build is wasted, which is
-- accepted since the home is cheap to build, and the next reader's init drops it. Returns
-- nothing, so the event reaches later modules.
function KoPanda:onCloseDocument()
    if self.refused then
        return
    end
    record_chapter(self.ui)
    if self.in_fm or Home.pending then
        return
    end
    Home.prebuild()
end

-- The file manager closing (quit, or a book opening) takes the home with it; a home left on
-- the stack would keep KOReader from quitting.
function KoPanda:onCloseWidget()
    if self.refused then
        return
    end
    if self.in_fm then
        Home.close()
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
    if self.refused then
        menu_items.kopanda = {
            text = "KoPanda",
            sorting_hint = "tools",
            sub_item_table = { swatches },
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
            swatches,
        },
    }
end

return KoPanda
