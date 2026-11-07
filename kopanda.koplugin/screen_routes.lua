-- Which screen goes up next: a chrome window unless the file manager has gone (FileManager.instance,
-- frontend/apps/filemanager/filemanager.lua:447), the screen a book status page was opened from, and the window a
-- book's close returns to. KoPanda's methods (main.lua) call these with the plugin instance.
local AuthorsScreen = require("authors_screen")
local BookListsScreen = require("book_lists_screen")
local BookStatusScreen = require("book_status_screen")
local Library = require("library")
local LibraryChrome = require("library_chrome")
local SearchScreen = require("search_screen")
local SeriesScreen = require("series_screen")
local SubjectsScreen = require("subjects_screen")
local time = require("ui/time")

local ScreenRoutes = {}

-- The Series, Authors, Subjects and book list windows, by the screen a return names.
local SHELVES = { series = SeriesScreen, authors = AuthorsScreen, subjects = SubjectsScreen,
    book_list = BookListsScreen }
ScreenRoutes.SHELVES = SHELVES

-- Shows a window of cls (a shelf's, SearchScreen or StatsScreen) with opts unless the file manager has gone since the
-- show was asked for; the window's show closes the home. Like the library's, it takes no part in the boot guard; one
-- that fails to build is logged by the chrome and the file browser left up. Returns the window shown, or nil.
function ScreenRoutes.show_shelf(cls, opts)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if FileManager and FileManager.instance then
        return cls.show(opts)
    end
    return nil
end

-- The screen opener names shown again: the home for { screen = "home" }; the library at its folder (view) and
-- page; the Series, Authors, Subjects or book list window at its view and page; the search's results for its query
-- and start (from) at their page.
function ScreenRoutes.show_opener(kopanda, opener)
    local screen = opener and opener.screen
    if screen == "library" then
        kopanda:showLibrary{ dir = opener.view, page = opener.page }
    elseif screen == "search" then
        ScreenRoutes.show_shelf(SearchScreen, { query = opener.view.query, from = opener.from, page = opener.page })
    elseif SHELVES[screen] then
        ScreenRoutes.show_shelf(SHELVES[screen], { view = opener.view, page = opener.page })
    else
        kopanda:showHome()
    end
end

-- The book status page with opts (BookStatusScreen.show's) unless the file manager has gone; like the library's,
-- it takes no part in the boot guard. One that fails to show is logged by the chrome, which closed the screen it
-- was opened from, so that is shown again. Returns the window shown, or nil.
function ScreenRoutes.show_book_status(kopanda, opts)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if not (FileManager and FileManager.instance) then
        return nil
    end
    local screen = BookStatusScreen.show(opts)
    if not screen then
        ScreenRoutes.show_opener(kopanda, opts.opener)
    end
    return screen
end

-- The window a book's close returns to and the fields it is built with: the library at the folder and page
-- a book was opened from, or the Series, Authors, Subjects or book list window at the view and page; nil with no
-- return recorded.
function ScreenRoutes.return_window()
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
function ScreenRoutes.show_return(kopanda)
    local cls, fields = ScreenRoutes.return_window()
    Library.return_to, LibraryChrome.return_to = nil, nil
    local started = time.monotonic()
    if cls == Library then
        kopanda:showLibrary{ dir = fields.dir, page = fields.page, started = started }
    else
        ScreenRoutes.show_shelf(cls, { view = fields.showing, page = fields.page, started = started })
    end
end

return ScreenRoutes
