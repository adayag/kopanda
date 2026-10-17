-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/library_golden_spec.lua after the home fixture patch, whose name sorts before
-- this one (frontend/userpatch.lua:60-61), so the look it stores is in place before anything here
-- reads it. It runs beside KOPANDA_HOME_FIXTURE=empty, which sets up no featured book.
-- KOPANDA_LIBRARY_DIR is the capture library the spec built (the driver's library_dir): its books
-- at its root and one sub-folder holding one more book. At patch time, before any plugin loads
-- (reader.lua:190), it:
--   - stores that folder, realpath'd as FileManager:showFiles realpaths its start directory
--     (filemanager.lua:1320), as KOReader's home folder, the library's root
--     (library_view.lua, LibraryView.root);
--   - puts sidecars under <KO_HOME>/docsettings/ (document_metadata_folder "dir",
--     frontend/docsettings.lua:118-136), so nothing but books lies in the capture library, and
--     writes one for the-time-machine.epub at its root: 38 % read, status reading, so its tile
--     shows the strip.
-- Once PluginLoader:loadPlugins has run, as the home fixture extracts the featured cover
-- (2-scenario-home-fixture.lua), it registers one path-less source book with no cover, so its tile
-- is the not-downloaded one, and extracts every book's cover in the library and its sub-folder,
-- synchronously, at the grid's cover box (library_tiles.lua, LibraryTiles.geometry), so no capture
-- waits on an extraction and the library asks for none (book_covers.lua, BookCovers.request).
-- On the first home's settled signal, from the next tick, it runs the launcher's library target
-- (launcher_entries.lua), which closes the home and shows the library; then, per
-- KOPANDA_LIBRARY_STEP:
--   - root: nothing more; the library's own settled signal is the capture's;
--   - folder and book: before the target runs, the library is recorded as left in the sub-folder
--     at its first page (library_order.lua, LibraryOrder.leave), so the target shows the sub-folder
--     in one show; for folder, its settled signal is the capture's;
--   - sort: on the library's settled signal, from the next tick, a tap at the centre of the sort
--     picker, which opens the sort sheet; the sheet's settled signal is the capture's;
--   - book: on the sub-folder's settled signal, from the next tick, a tap at the centre of its
--     first downloaded book's tile, which opens it; once the reader has it, from a scheduled task,
--     the reader goes home, as book_close's scenario closes its book; on the next library's
--     settled signal it reports, as a "scenario" signal, whether that library was pre-built, its
--     paint_ms, how often the file manager painted between the close and that signal, and whether
--     it shows the folder and page the book was opened from. The book opens from the sub-folder,
--     not the root, so a library that came back at the root fails same_dir; the capture library
--     holds one page per folder, so the page is 1 either way.
-- A failure before the UI runs exits with status 4, as the home fixture does, since a half-made
-- library would be captured as if it were the golden's; one after is reported as a settled signal
-- with error on the screen the step's capture shoots, so the spec fails with the message.
local logger = require("logger")

local POLL_S = 0.5
local POLL_TRIES = 20 -- 10 s for the book to open

-- The screen each step's capture shoots on.
local SHOT_SCREEN = { root = "library", folder = "library", sort = "sheet", book = "scenario" }

local ok, err = pcall(function()
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local Geom = require("ui/geometry")
    local PluginLoader = require("pluginloader")
    local ReaderUI = require("apps/reader/readerui")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")
    local Screen = require("device").screen

    local step = os.getenv("KOPANDA_LIBRARY_STEP")
    if not SHOT_SCREEN[step] then
        error("KOPANDA_LIBRARY_STEP must be root, folder, sort or book, not " .. tostring(step))
    end
    local library_dir = os.getenv("KOPANDA_LIBRARY_DIR")
    local root = library_dir and library_dir ~= "" and ffiutil.realpath(library_dir)
    if not root or lfs.attributes(root, "mode") ~= "directory" then
        error("KOPANDA_LIBRARY_DIR is not a folder: " .. tostring(library_dir))
    end

    -- The library's books, as Books.folder lists them (dir .. "/" .. name, the stored home folder
    -- being realpath'd), and its one sub-folder.
    local books, folders = {}, {}
    for name in lfs.dir(root) do
        local path = root .. "/" .. name
        if name:sub(1, 1) ~= "." then
            local mode = lfs.attributes(path, "mode")
            if mode == "directory" then
                folders[#folders + 1] = path
            elseif name:match("%.epub$") then
                books[#books + 1] = path
            end
        end
    end
    if #folders ~= 1 then
        error(string.format("expected one sub-folder in %s, found %d", root, #folders))
    end
    local sub = folders[1]
    for name in lfs.dir(sub) do
        if name:match("%.epub$") then
            books[#books + 1] = sub .. "/" .. name
        end
    end
    table.sort(books)

    G_reader_settings:saveSetting("home_dir", root)
    G_reader_settings:saveSetting("document_metadata_folder", "dir")
    local in_progress = root .. "/the-time-machine.epub"
    if lfs.attributes(in_progress, "mode") ~= "file" then
        error("no the-time-machine.epub in " .. root)
    end
    -- The sidecar keys ReaderUI saves (readerrolling.lua:338 percent_finished; the status
    -- booklist.lua:371-378 reads), written through DocSettings:flush.
    require("docsettings"):open(in_progress)
        :saveSetting("percent_finished", 0.38)
        :saveSetting("summary", { status = "reading" })
        :flush()

    -- bookinfomanager and the plugin's modules join package.path once PluginLoader:loadPlugins has
    -- run (frontend/pluginloader.lua:283-287), which FileManager:init calls before it instantiates
    -- any plugin (frontend/apps/filemanager/filemanager.lua:418), long before the library shows.
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
                    return { { id = "scenario:pride-and-prejudice", title = "Pride and Prejudice",
                        authors = { "Jane Austen" } } }
                end,
            }
            local started = time.monotonic()
            local BookInfoManager = require("bookinfomanager")
            local Looks = require("looks")
            local box = require("library_tiles").geometry(Screen:getWidth(),
                { look = Looks.active(), variant = Looks.variant(), screen = Screen })
            -- extractBookInfo is synchronous (plugins/coverbrowser.koplugin/bookinfomanager.lua:422-570).
            for _, book in ipairs(books) do
                local specs = { max_cover_w = box.cover_w, max_cover_h = box.cover_h }
                if not BookInfoManager:extractBookInfo(book, specs) then
                    error("CoverBrowser could not read " .. book)
                end
                local info = BookInfoManager:getBookInfo(book, false)
                if not (info and info.has_cover) then
                    error("CoverBrowser found no cover in " .. book)
                end
            end
            logger.info(string.format("KOPANDA_SCENARIO: %d library covers extracted for %dx%d in %d ms",
                #books, box.cover_w, box.cover_h, time.to_ms(time.monotonic() - started)))
        end)
        if not prepare_ok then
            logger.warn("KOPANDA_SCENARIO: library fixture failed", prepare_err)
            os.exit(4)
        end
        return enabled, disabled
    end

    local function report(args)
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local function fail(message)
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        report{ screen = SHOT_SCREEN[step], error = tostring(message) }
    end

    -- fn run from the UI loop, any error reported as the step's.
    local function guarded(fn)
        return function()
            local run_ok, run_err = pcall(fn)
            if not run_ok then
                fail(run_err)
            end
        end
    end

    -- A tap at the centre of rect, through the UI's gesture path (the fields GestureRange:match
    -- reads, frontend/ui/gesturerange.lua:21-51).
    local function tap_centre(rect)
        local pos = Geom:new{ x = rect.x + math.floor(rect.w / 2), y = rect.y + math.floor(rect.h / 2), w = 0, h = 0 }
        logger.info(string.format("KOPANDA_SCENARIO: tap at %d,%d", pos.x, pos.y))
        UIManager:sendEvent(Event:new("Gesture", { ges = "tap", pos = pos, time = time.now() }))
    end

    local function shown_library()
        local library = require("library").shown
        if not library then
            error("no library is shown")
        end
        return library
    end

    local open_library = guarded(function()
        if step == "folder" or step == "book" then
            if not require("library_order").leave(sub, 1) then
                error("could not record the library as left in " .. sub)
            end
        end
        logger.info("KOPANDA_SCENARIO: run the launcher's library target")
        require("launcher_entries").run({ kind = "kopanda", target = "library" })
    end)

    local open_sort = guarded(function()
        tap_centre(shown_library().header.sort.rect)
    end)

    -- The book step's count of file manager paints, armed from the close to the library's
    -- settled signal. FileManager inherits paintTo from InputContainer
    -- (frontend/ui/widget/container/inputcontainer.lua:73); this wraps it before any plugin runs.
    local armed, fm_paints = false, 0
    if step == "book" then
        local inherited_paint = FileManager.paintTo
        FileManager.paintTo = function(self, ...)
            if armed then
                fm_paints = fm_paints + 1
            end
            return inherited_paint(self, ...)
        end
    end

    local opened_at
    -- The close runs inside _checkTasks, as KOReader's end-of-book file-browser action does
    -- (frontend/apps/reader/modules/readerstatus.lua:144-148).
    local close_book = guarded(function()
        armed = true
        ReaderUI.instance:onHome()
    end)

    local tries = 0
    local function wait_for_reader()
        tries = tries + 1
        local reader = ReaderUI.instance
        if reader and reader.document then
            UIManager:nextTick(close_book)
        elseif tries >= POLL_TRIES then
            fail(string.format("the book did not open within %.0f s", POLL_S * POLL_TRIES))
        else
            UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
        end
    end

    local open_book = guarded(function()
        local library = shown_library()
        for _, tile in ipairs(library.tiles) do
            if tile.record and tile.record.path then
                opened_at = { dir = library.dir, page = library.page, path = tile.record.path }
                logger.info("KOPANDA_SCENARIO: open " .. tile.record.path)
                tap_centre(tile.rect)
                UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
                return
            end
        end
        error("the library shows no downloaded book")
    end)

    local homes, libraries = 0, 0
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if not args then
            return
        end
        if args.screen == "home" then
            homes = homes + 1
            if homes == 1 then
                UIManager:nextTick(open_library)
            end
        elseif args.screen == "library" then
            libraries = libraries + 1
            if libraries == 1 and step == "sort" then
                UIManager:nextTick(open_sort)
            elseif libraries == 1 and step == "book" then
                UIManager:nextTick(open_book)
            elseif libraries == 2 and step == "book" then
                armed = false
                local shown = require("library").shown
                report{
                    screen = "scenario",
                    prebuilt = args.prebuilt,
                    paint_ms = args.paint_ms,
                    fm_paints = fm_paints,
                    same_dir = shown ~= nil and require("library_view").same_dir(shown.dir, opened_at.dir),
                    same_page = shown ~= nil and shown.page == opened_at.page,
                }
            end
        end
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: library fixture failed", err)
    os.exit(4)
end
