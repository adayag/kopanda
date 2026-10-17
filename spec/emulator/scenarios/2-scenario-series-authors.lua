-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/series_authors_golden_spec.lua after the home fixture patch, whose name sorts
-- before this one (frontend/userpatch.lua:60-61), so the look it stores is in place before
-- anything here reads it. It runs beside KOPANDA_HOME_FIXTURE=empty, which sets up no featured
-- book.
-- KOPANDA_SHELF_DIR is the capture library the spec built (the driver's library_dir): the three
-- fixture books under their own names and, beside them, copies of one fixture book under the
-- names CATALOGUE lists, every file at its root. At patch time, before any plugin loads
-- (reader.lua:190), it:
--   - checks the folder holds exactly the originals and CATALOGUE's copies;
--   - stores that folder, realpath'd as FileManager:showFiles realpaths its start directory
--     (filemanager.lua:1320), as KOReader's home folder, the root Books.all walks (books.lua);
--   - puts sidecars under <KO_HOME>/docsettings/ (document_metadata_folder "dir",
--     frontend/docsettings.lua:118-136), so nothing but books lies in the capture library, and
--     writes one for each book PROGRESS lists, with its status and percent read (the keys
--     ReaderUI saves, readerrolling.lua:338, and the status booklist.lua:371-378 reads).
-- Once PluginLoader:loadPlugins has run, as the home fixture extracts the featured cover
-- (2-scenario-home-fixture.lua), it:
--   - registers one path-less source book in a series with no cover (Books.add_source), the
--     not-downloaded book;
--   - extracts every book's CoverBrowser row, synchronously, at the library grid's cover box
--     (library_tiles.lua, LibraryTiles.geometry), the box the windows' own request asks at
--     (library_chrome.lua, LibraryChrome.request_records), so the request finds every row
--     present and asks for none (book_covers.lua, BookCovers.wants);
--   - then gives each copy its scripted title, authors (newline-joined, as crengine joins them
--     and books.lua splits them), series and series_index through
--     BookInfoManager:setBookInfoProperties (plugins/coverbrowser.koplugin/bookinfomanager.lua:572-588,
--     which updates the row the extraction wrote, keyed by directory and file name), with
--     ignore_cover = "Y" (bookinfomanager.lua:47), so a copy's tile draws its scripted title's
--     placeholder rather than the copied book's cover (books.lua, cover_state); the originals keep
--     their real covers, and A Christmas Carol is also given its place in Dickens' Christmas
--     Books, so one series stack draws a real cover;
--   - wraps BookInfoManager:extractInBackground to log each batch asked for, so the spec can
--     prove the windows asked for no extraction and nothing arrived to repaint them.
-- On the first home's settled signal, from the next tick, it shows, per KOPANDA_SHELF_VIEW, the
-- window directly at its view through the plugin (KoPanda:showSeries, KoPanda:showAuthors), so
-- that window's one settled signal is the capture's:
--   - series-list: the Series list at its first page;
--   - series-books: the series SERIES at its first page;
--   - authors-list: the Authors list at its first page;
--   - author-books: the author AUTHOR at its first page.
-- A failure before the UI runs exits with status 4, as the home fixture does, since a half-made
-- library would be captured as if it were the golden's; one after is reported as a settled signal
-- with error on the screen the view's capture shoots, so the spec fails with the message.
local logger = require("logger")

-- The views, each the window's show and the view it is shown at.
local SERIES = "Sherlock Holmes"
local AUTHOR = "Arthur Conan Doyle"
local VIEWS = {
    ["series-list"] = { screen = "series", show = "showSeries", view = { kind = "list" } },
    ["series-books"] = { screen = "series", show = "showSeries", view = { kind = "series", name = SERIES } },
    ["authors-list"] = { screen = "authors", show = "showAuthors", view = { kind = "list" } },
    ["author-books"] = { screen = "authors", show = "showAuthors", view = { kind = "author", name = AUTHOR } },
}

-- The fixture books, kept under their own names, with their own metadata and covers.
local ORIGINALS = { "a-christmas-carol.epub", "frankenstein.epub", "the-time-machine.epub" }

-- The copies' metadata, by file name: public-domain titles and authors. Eight series, the copies'
-- seven and Frankenstein's own (its EPUB's belongs-to-collection, which CoverBrowser reads as a
-- series), so the Series list runs to two pages of five: three under way (Christmas Books, The
-- Leatherstocking Tales, Sherlock Holmes), one finished (Alice), and four not started, three of
-- them on page 2.
-- Arthur Conan Doyle has six books, three in Sherlock Holmes (one of them the path-less source
-- book) and three outside it, two rows of three on his own grid. The Wrong Box has two authors.
-- Authors' surnames start with B, C, D, O, S, T and W.
local CATALOGUE = {
    ["a-study-in-scarlet.epub"] = { title = "A Study in Scarlet", authors = "Arthur Conan Doyle",
        series = "Sherlock Holmes", series_index = 1 },
    ["the-sign-of-the-four.epub"] = { title = "The Sign of the Four", authors = "Arthur Conan Doyle",
        series = "Sherlock Holmes", series_index = 2 },
    ["the-lost-world.epub"] = { title = "The Lost World", authors = "Arthur Conan Doyle" },
    ["micah-clarke.epub"] = { title = "Micah Clarke", authors = "Arthur Conan Doyle" },
    ["the-white-company.epub"] = { title = "The White Company", authors = "Arthur Conan Doyle" },
    ["the-chimes.epub"] = { title = "The Chimes", authors = "Charles Dickens",
        series = "Christmas Books", series_index = 2 },
    ["the-cricket-on-the-hearth.epub"] = { title = "The Cricket on the Hearth", authors = "Charles Dickens",
        series = "Christmas Books", series_index = 3 },
    ["the-pioneers.epub"] = { title = "The Pioneers", authors = "James Fenimore Cooper",
        series = "The Leatherstocking Tales", series_index = 1 },
    ["the-last-of-the-mohicans.epub"] = { title = "The Last of the Mohicans", authors = "James Fenimore Cooper",
        series = "The Leatherstocking Tales", series_index = 2 },
    ["alices-adventures-in-wonderland.epub"] = { title = "Alice's Adventures in Wonderland",
        authors = "Lewis Carroll", series = "Alice", series_index = 1 },
    ["through-the-looking-glass.epub"] = { title = "Through the Looking-Glass", authors = "Lewis Carroll",
        series = "Alice", series_index = 2 },
    ["the-warden.epub"] = { title = "The Warden", authors = "Anthony Trollope",
        series = "Chronicles of Barsetshire", series_index = 1 },
    ["barchester-towers.epub"] = { title = "Barchester Towers", authors = "Anthony Trollope",
        series = "Chronicles of Barsetshire", series_index = 2 },
    ["the-three-musketeers.epub"] = { title = "The Three Musketeers", authors = "Alexandre Dumas",
        series = "The d'Artagnan Romances", series_index = 1 },
    ["twenty-years-after.epub"] = { title = "Twenty Years After", authors = "Alexandre Dumas",
        series = "The d'Artagnan Romances", series_index = 2 },
    ["the-wonderful-wizard-of-oz.epub"] = { title = "The Wonderful Wizard of Oz", authors = "L. Frank Baum",
        series = "Oz", series_index = 1 },
    ["the-marvelous-land-of-oz.epub"] = { title = "The Marvelous Land of Oz", authors = "L. Frank Baum",
        series = "Oz", series_index = 2 },
    ["the-wrong-box.epub"] = { title = "The Wrong Box", authors = "Robert Louis Stevenson\nLloyd Osbourne" },
}

-- The original's place in a series, its title, authors and cover its own.
local ORIGINAL_SERIES = {
    ["a-christmas-carol.epub"] = { series = "Christmas Books", series_index = 1 },
}

-- The sidecars: { status, percent }. Every other book is new.
local PROGRESS = {
    ["a-study-in-scarlet.epub"] = { status = "complete", percent = 1 },
    ["the-sign-of-the-four.epub"] = { status = "reading", percent = 0.38 },
    ["a-christmas-carol.epub"] = { status = "complete", percent = 1 },
    ["the-pioneers.epub"] = { status = "complete", percent = 1 },
    ["alices-adventures-in-wonderland.epub"] = { status = "complete", percent = 1 },
    ["through-the-looking-glass.epub"] = { status = "complete", percent = 1 },
}

-- The path-less source book: Sherlock Holmes' third, not downloaded.
local SOURCE_BOOK = { id = "scenario:the-hound-of-the-baskervilles", title = "The Hound of the Baskervilles",
    authors = { "Arthur Conan Doyle" }, series = "Sherlock Holmes", series_index = 3 }

local view_name = os.getenv("KOPANDA_SHELF_VIEW")
local VIEW = VIEWS[view_name]

local ok, err = pcall(function()
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")
    local Screen = require("device").screen

    if not VIEW then
        error("KOPANDA_SHELF_VIEW must be series-list, series-books, authors-list or author-books, not "
            .. tostring(view_name))
    end
    local library_dir = os.getenv("KOPANDA_SHELF_DIR")
    local root = library_dir and library_dir ~= "" and ffiutil.realpath(library_dir)
    if not root or lfs.attributes(root, "mode") ~= "directory" then
        error("KOPANDA_SHELF_DIR is not a folder: " .. tostring(library_dir))
    end

    -- The folder holds the originals and CATALOGUE's copies, nothing else.
    local expected = {}
    for _, name in ipairs(ORIGINALS) do
        expected[name] = true
    end
    for name in pairs(CATALOGUE) do
        expected[name] = true
    end
    local books = {}
    for name in lfs.dir(root) do
        if name ~= "." and name ~= ".." then
            if not expected[name] or lfs.attributes(root .. "/" .. name, "mode") ~= "file" then
                error("unexpected entry in " .. root .. ": " .. name)
            end
            expected[name] = nil
            books[#books + 1] = name
        end
    end
    local missing = next(expected)
    if missing then
        error("no " .. missing .. " in " .. root)
    end
    table.sort(books)

    G_reader_settings:saveSetting("home_dir", root)
    G_reader_settings:saveSetting("document_metadata_folder", "dir")
    for name, progress in pairs(PROGRESS) do
        require("docsettings"):open(root .. "/" .. name)
            :saveSetting("percent_finished", progress.percent)
            :saveSetting("summary", { status = progress.status })
            :flush()
    end

    -- bookinfomanager and the plugin's modules join package.path once PluginLoader:loadPlugins has
    -- run (frontend/pluginloader.lua:283-287), which FileManager:init calls before it instantiates
    -- any plugin (frontend/apps/filemanager/filemanager.lua:418), long before any window shows.
    local load_plugins = PluginLoader.loadPlugins
    local prepared = false
    PluginLoader.loadPlugins = function(self, ...)
        local enabled, disabled = load_plugins(self, ...)
        if prepared then
            return enabled, disabled
        end
        prepared = true
        local prepare_ok, prepare_err = pcall(function()
            require("books").add_source{
                name = "scenario",
                books = function()
                    return { SOURCE_BOOK }
                end,
            }
            local started = time.monotonic()
            local BookInfoManager = require("bookinfomanager")
            local Looks = require("looks")
            local box = require("library_tiles").geometry(Screen:getWidth(),
                { look = Looks.active(), variant = Looks.variant(), screen = Screen })
            local specs = { max_cover_w = box.cover_w, max_cover_h = box.cover_h }
            -- extractBookInfo is synchronous (plugins/coverbrowser.koplugin/bookinfomanager.lua:422-570).
            for _, name in ipairs(books) do
                local path = root .. "/" .. name
                if not BookInfoManager:extractBookInfo(path, specs) then
                    error("CoverBrowser could not read " .. path)
                end
                local props = CATALOGUE[name] or ORIGINAL_SERIES[name]
                if props then
                    local fields = {}
                    for k, v in pairs(props) do
                        fields[k] = v
                    end
                    if CATALOGUE[name] then
                        fields.ignore_cover = "Y"
                    end
                    BookInfoManager:setBookInfoProperties(path, fields)
                end
                local info = BookInfoManager:getBookInfo(path, false)
                if not info then
                    error("CoverBrowser has no row for " .. path)
                end
                if CATALOGUE[name] then
                    if info.title ~= props.title or not info.ignore_cover then
                        error("CoverBrowser's row for " .. path .. " did not take its properties")
                    end
                elseif not info.has_cover then
                    error("CoverBrowser found no cover in " .. path)
                end
            end
            logger.info(string.format("KOPANDA_SCENARIO: %d shelf books extracted for %dx%d in %d ms",
                #books, box.cover_w, box.cover_h, time.to_ms(time.monotonic() - started)))

            local extract = BookInfoManager.extractInBackground
            BookInfoManager.extractInBackground = function(bim, files, ...)
                logger.info(string.format("KOPANDA_SCENARIO: extraction asked for %d files", #files))
                return extract(bim, files, ...)
            end
        end)
        if not prepare_ok then
            logger.warn("KOPANDA_SCENARIO: shelf fixture failed", prepare_err)
            os.exit(4)
        end
        return enabled, disabled
    end

    local function fail(message)
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        UIManager.event_hook:execute("KoPandaSettled", { screen = VIEW.screen, error = tostring(message) })
    end

    local open_view = function()
        local run_ok, run_err = pcall(function()
            local FileManager = require("apps/filemanager/filemanager")
            local fm = FileManager.instance
            if not (fm and fm.kopanda) then
                error("no file manager with the kopanda plugin")
            end
            logger.info("KOPANDA_SCENARIO: " .. VIEW.show .. " at " .. view_name)
            fm.kopanda[VIEW.show](fm.kopanda, { view = VIEW.view, page = 1 })
            local shown = require(VIEW.screen == "series" and "series_screen" or "authors_screen").shown
            if not shown then
                error(VIEW.show .. " showed no window")
            end
        end)
        if not run_ok then
            fail(run_err)
        end
    end

    local homes = 0
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if args and args.screen == "home" then
            homes = homes + 1
            if homes == 1 then
                UIManager:nextTick(open_view)
            end
        end
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: shelf fixture failed", err)
    os.exit(4)
end
