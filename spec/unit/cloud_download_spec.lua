-- Download on a placeholder's book sheet (cwng-placeholders C3; D2, D7, D16, D17, D18): the row
-- under Open on the library, on one series and on one author, its tap handing cwngsync the path and
-- a callback in place of the open, and that callback's re-list of the window it was held on, with
-- the book's cover asked for again. Run on a scratch library under the data directory, by its
-- realpath, with home_dir pointed at it, under a real file manager. cwngsync is never loaded: a stub
-- stands for it, registered on the file manager as cwngsync and removed after each case, its
-- openLibraryPlaceholder recording its calls and returning what the case sets; a case calls the
-- recorded callback itself, after making the stub's state and the file say downloaded, as
-- cwngsync's download does before it calls back (cwng_library_runtime.lua:957-977, :1017).
-- CoverBrowser's bookinfomanager is a stub too: a row with a cached cover that fits for every book,
-- in the series Held by Ann Author, deleteBookInfo dropping a row and extractInBackground recording
-- what it was asked for and putting the row back, as an extraction would.
describe("Download on a placeholder's sheet", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local EventListener = require("ui/widget/eventlistener")
    local FileManager = require("apps/filemanager/filemanager")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local centre = require("library_fixture").centre
    local BookCovers, Books, LibrarySheets, PaintClock, Sheet

    local scratch = DataStorage:getDataDir() .. "/cloud-download-library"
    -- Eight books, so the held one, the seventh by title, is on the library's second page beside the
    -- eighth.
    local COUNT = 8
    local home, held, logged, bim

    -- Undo steps for the running case, run last first after it.
    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
    end

    local function replace(t, key, value)
        local saved = rawget(t, key)
        t[key] = value
        cleanup(function()
            t[key] = saved
        end)
    end

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function remove_tree(path)
        if lfs.symlinkattributes(path, "mode") == "directory" then
            for entry in lfs.dir(path) do
                if entry ~= "." and entry ~= ".." then
                    remove_tree(path .. "/" .. entry)
                end
            end
        end
        os.remove(path)
    end

    local function path_of(i)
        return home .. "/held-" .. i .. ".epub"
    end

    -- CoverBrowser's row of book i: its metadata and a cached cover bigger than any box.
    local function row_of(i)
        return { title = "Held " .. i, authors = "Ann Author", series = "Held", series_index = i,
            cover_fetched = true, has_cover = true, cover_w = 4000, cover_h = 6000 }
    end

    -- The bookinfomanager stub over rows ({ [path] = row }): deleted, the paths deleteBookInfo got;
    -- extracted, the file lists extractInBackground got, each extracted path's row put back.
    local function coverbrowser(rows)
        local stub = { rows = rows, deleted = {}, extracted = {} }
        function stub.getBookInfo(_, file)
            local found = stub.rows[file]
            if not found then
                return nil
            end
            local copy = {}
            for k, v in pairs(found) do
                copy[k] = v
            end
            return copy
        end
        function stub.isCachedCoverInvalid(info, specs)
            return not info.cover_w or info.cover_w < specs.max_cover_w or info.cover_h < specs.max_cover_h
        end
        function stub.deleteBookInfo(_, file)
            stub.deleted[#stub.deleted + 1] = file
            stub.rows[file] = nil
        end
        function stub.extractInBackground(_, files)
            local paths = {}
            for i, entry in ipairs(files) do
                paths[i] = entry.filepath
                local n = tonumber(entry.filepath:match("held%-(%d+)%.epub$"))
                stub.rows[entry.filepath] = n and row_of(n)
            end
            stub.extracted[#stub.extracted + 1] = paths
            return true
        end
        function stub.isExtractingInBackground()
            return false
        end
        package.loaded["bookinfomanager"] = stub
        return stub
    end

    -- Registers stub on the file manager as cwngsync, as the file manager registers a plugin
    -- (filemanager.lua:379-384, :424), removed after the case.
    local function register(stub)
        local fm = FileManager.instance
        fm:registerModule("cwngsync", stub)
        cleanup(function()
            for i = #fm, 1, -1 do
                if fm[i] == stub then
                    table.remove(fm, i)
                end
            end
            fm.cwngsync = nil
        end)
        return stub
    end

    -- A configured cwngsync stub whose state records the held book as a placeholder of its own size
    -- (cwng_library.lua:17-20). calls holds each openLibraryPlaceholder's { file, callback }; it
    -- returns stub.returns. fields replace its methods. Registered.
    local function cwngsync(fields)
        local stub = EventListener:new{
            calls = {},
            returns = true,
            books = { ["7"] = { kind = "placeholder", path = held, size = lfs.attributes(held, "size") } },
        }
        function stub.isConfigured()
            return true
        end
        function stub.getLibraryState(self)
            return { version = 1, books = self.books }
        end
        function stub.openLibraryPlaceholder(self, file, on_done)
            self.calls[#self.calls + 1] = { file = file, callback = on_done }
            return self.returns
        end
        for k, v in pairs(fields or {}) do
            stub[k] = v
        end
        return register(stub)
    end

    -- What cwngsync's download leaves before it calls back: the real book renamed over the
    -- placeholder, so its size differs, and recorded as downloaded (cwng_library_runtime.lua:957-973;
    -- cwng_library.lua:346-352).
    local function download(stub)
        write(held, "the real book, downloaded over the placeholder, longer than it")
        stub.books["7"] = { kind = "downloaded", path = held, size = lfs.attributes(held, "size") }
    end

    -- Whether any logged line (logger.err or logger.warn) contains text.
    local function was_logged(text)
        for _, call in ipairs(logged) do
            for _, arg in ipairs(call) do
                if tostring(arg):find(text, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    local saved_err, saved_warn

    before_each(function()
        harness.load()
        BookCovers = package.loaded["book_covers"]
        Books = package.loaded["books"]
        LibrarySheets = package.loaded["library_sheets"]
        PaintClock = package.loaded["paint_clock"]
        Sheet = package.loaded["sheet"]
        Books.reset()
        BookCovers.reset()
        remove_tree(scratch)
        assert(lfs.mkdir(scratch))
        home = ffiutil.realpath(scratch)
        G_reader_settings:saveSetting("home_dir", home)
        local rows = {}
        for i = 1, COUNT do
            write(path_of(i), "book " .. i)
            rows[path_of(i)] = row_of(i)
        end
        held = path_of(7)
        bim = coverbrowser(rows)
        harness.show_fm(home)
        harness.tick(2)
        package.loaded["home"].close()
        logged = {}
        saved_err, saved_warn = logger.err, logger.warn
        logger.err = function(...)
            logged[#logged + 1] = { ... }
        end
        logger.warn = logger.err
    end)

    after_each(function()
        logger.err, logger.warn = saved_err, saved_warn
        for i = #cleanups, 1, -1 do
            cleanups[i]()
        end
        cleanups = {}
        package.loaded["bookinfomanager"] = nil
        G_reader_settings:delSetting("home_dir")
        Books.reset()
        BookCovers.reset()
        harness.teardown()
        remove_tree(scratch)
    end)

    -- The windows a placeholder is held on: each shows its view at a page, and finds the held book's
    -- tile or row there (its parts: tiles on the library and one author, rows on one series).
    local WINDOWS = {
        library = {
            module = "library",
            show = function(page)
                return package.loaded["library"].show{ dir = home, page = page }
            end,
            parts = "tiles",
        },
        ["one series"] = {
            module = "series_screen",
            show = function(page)
                return package.loaded["series_screen"].show{ view = { kind = "series", name = "Held" }, page = page }
            end,
            parts = "rows",
        },
        ["one author"] = {
            module = "authors_screen",
            show = function(page)
                return package.loaded["authors_screen"].show{ view = { kind = "author", name = "Ann Author" },
                    page = page }
            end,
            parts = "tiles",
        },
    }

    -- The held book's part on window's page, or nil.
    local function part_of(window, kind)
        for _, part in ipairs(window[WINDOWS[kind].parts]) do
            if part.record and part.record.path == held then
                return part
            end
        end
    end

    -- The window of kind shown, painted and settled, at the page that holds the held book.
    local function show_held(kind)
        local page = 1
        while true do
            local window = WINDOWS[kind].show(page)
            assert.is_not_nil(window, kind)
            harness.tick(3)
            if part_of(window, kind) then
                return window
            end
            assert.truthy(page < window.pages, "the held book is on no page of the " .. kind)
            page = page + 1
        end
    end

    -- The held book held on window, the kind of window show_held shows, its sheet shown.
    local function hold(window, kind)
        local hit = package.loaded[WINDOWS[kind].module].hit(centre(part_of(window, kind).rect))
        assert.equals("book", hit.kind)
        assert.equals(held, hit.record.path)
        LibrarySheets.hold(window, hit, PaintClock.now())
        assert.is_not_nil(Sheet.shown)
        harness.tick(3)
    end

    local function place_of(label)
        for _, place in ipairs(Sheet.shown.rows) do
            if place.row.label == label then
                return place
            end
        end
        error("no row " .. label)
    end

    local function tap(label)
        local x, y = centre(place_of(label).rect)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", x, y)))
    end

    local function labels()
        local got = {}
        for i, row in ipairs(Sheet.shown.spec.rows) do
            got[i] = row.label
        end
        return got
    end

    -- Counts window's refresh calls, still running them.
    local function count_refreshes(window)
        local counts = { n = 0 }
        local refresh = window.refresh
        window.refresh = function(...)
            counts.n = counts.n + 1
            return refresh(...)
        end
        return counts
    end

    -- Every ReaderUI:showReader call, recorded rather than run, as the open would reach it
    -- (filemanager.lua:1637).
    local function watch_reader()
        local opened = {}
        replace(require("apps/reader/readerui"), "showReader", function(_, file)
            opened[#opened + 1] = file
        end)
        return opened
    end

    describe("the row", function()
        for kind in pairs(WINDOWS) do
            it("comes directly under Open with the download icon on a placeholder held on the " .. kind, function()
                cwngsync()
                hold(show_held(kind), kind)
                assert.same({ "Open", "Download", "Book details", "Read status", "More by this author",
                    "Add to the home", "Delete…" }, labels())
                local row = Sheet.shown.spec.rows[2]
                assert.equals("download", row.icon)
                assert.is_nil(row.muted)
                assert.is_nil(row.detail)
                assert.is_function(row.run)
            end)
        end

        it("is not on a downloaded book's sheet", function()
            cwngsync()
            local Library = package.loaded["library"]
            local library = Library.show{ dir = home, page = 1 }
            harness.tick(3)
            local other = library.tiles[1]
            assert.is_not.equals(held, other.record.path)
            LibrarySheets.hold(library, Library.hit(centre(other.rect)), PaintClock.now())
            assert.same({ "Open", "Book details", "Read status", "More by this author", "Add to the home",
                "Delete…" }, labels())
        end)

        it("is not on a path-less record's sheet", function()
            cwngsync()
            local library = show_held("library")
            local remote = { id = "shelf:remote", source = "shelf", title = "Remote", authors = {} }
            package.loaded["book_sheet"].open_record(remote, library, library.ctx, { beneath = library })
            assert.same({ "Open", "Book details", "Read status", "More by this author", "Add to the home",
                "Delete…" }, labels())
        end)

        it("is not on the held book's sheet without cwngsync", function()
            hold(show_held("library"), "library")
            assert.same({ "Open", "Book details", "Read status", "More by this author", "Add to the home",
                "Delete…" }, labels())
        end)

        it("is greyed with no run when cwngsync has no openLibraryPlaceholder, and a tap runs nothing", function()
            cwngsync({ openLibraryPlaceholder = false })
            local library = show_held("library")
            local refreshes = count_refreshes(library)
            local opened = watch_reader()
            hold(library, "library")
            local row = place_of("Download").row
            assert.is_true(row.muted)
            assert.is_nil(row.run)
            tap("Download")
            harness.tick(3)
            assert.is_nil(Sheet.shown)
            assert.equals(library, harness.top())
            assert.same({ 0 }, { refreshes.n })
            assert.same({}, opened)
        end)
    end)

    describe("the tap", function()
        it("closes the sheet and calls openLibraryPlaceholder once with the path and a callback, opening "
            .. "no reader", function()
            local stub = cwngsync()
            local library = show_held("library")
            local refreshes = count_refreshes(library)
            local opened = watch_reader()
            hold(library, "library")
            tap("Download")
            assert.is_nil(Sheet.shown)
            assert.equals(1, #stub.calls)
            assert.equals(held, stub.calls[1].file)
            assert.is_function(stub.calls[1].callback)
            harness.tick(3)
            assert.same({}, opened)
            assert.equals(0, refreshes.n)
            assert.equals(library, harness.top())
            assert.same({}, logged)
        end)

        it("re-lists the window once when openLibraryPlaceholder returns false", function()
            local stub = cwngsync()
            stub.returns = false
            local library = show_held("library")
            local refreshes = count_refreshes(library)
            hold(library, "library")
            tap("Download")
            assert.equals(1, #stub.calls)
            assert.equals(1, refreshes.n)
            assert.equals(library, harness.top())
        end)

        it("logs a raising openLibraryPlaceholder, the window shown and unchanged over the file manager", function()
            cwngsync({
                openLibraryPlaceholder = function()
                    error("kopanda-test: cwngsync failed")
                end,
            })
            local library = show_held("library")
            local refreshes = count_refreshes(library)
            local page, frame = library.page, library[1]
            hold(library, "library")
            tap("Download")
            harness.tick(3)
            assert.is_true(was_logged("kopanda-test: cwngsync failed"))
            assert.equals(library, harness.top())
            assert.equals(FileManager.instance, harness.top(2))
            assert.equals(page, library.page)
            assert.equals(frame, library[1])
            assert.equals(0, refreshes.n)
        end)

        it("logs and runs nothing when cwngsync went between the build and the tap", function()
            local stub = cwngsync()
            local library = show_held("library")
            local refreshes = count_refreshes(library)
            hold(library, "library")
            FileManager.instance.cwngsync = nil
            tap("Download")
            harness.tick(3)
            assert.equals(0, #stub.calls)
            assert.equals(0, refreshes.n)
            assert.equals(1, #logged)
            assert.equals(library, harness.top())
        end)
    end)

    describe("the callback", function()
        -- The held book held on the kind of window and downloaded; returns the window, the page it
        -- showed and the stub's callback, not yet called.
        local function tapped(kind)
            local stub = cwngsync()
            local window = show_held(kind)
            assert.truthy(window.page > 1, "the " .. kind .. " holds the book on page 1")
            hold(window, kind)
            tap("Download")
            assert.equals(1, #stub.calls)
            download(stub)
            return window, window.page, stub.calls[1].callback
        end

        for kind in pairs(WINDOWS) do
            it("re-lists the " .. kind .. " at its page, the book's badge gone, and asks for its cover "
                .. "again after the paint, opening no reader", function()
                local window, page, callback = tapped(kind)
                assert.is_table(part_of(window, kind).widget.badge)
                local forgotten = {}
                local forget = BookCovers.forget
                replace(BookCovers, "forget", function(paths)
                    forgotten[#forgotten + 1] = paths
                    return forget(paths)
                end)
                local opened = watch_reader()
                bim.extracted = {}
                callback(held)
                assert.same({ { held } }, forgotten)
                assert.same({}, bim.extracted)
                harness.tick(3)
                assert.equals(window, harness.top())
                assert.equals(page, window.page)
                assert.same({ { held } }, bim.extracted)
                local part = part_of(window, kind)
                assert.is_not_nil(part, kind)
                assert.is_nil(part.record.placeholder)
                assert.is_nil(part.widget.badge)
                assert.same({}, opened)
                assert.same({}, logged)
            end)
        end

        -- cwngsync's download as it runs once connected (cwng_library_runtime.lua:1010-1017): its
        -- notice shown and painted, the book renamed over the placeholder, the broadcasts of
        -- refreshLibraryViews (main.lua:1612-1630), CoverBrowser's row deleted on the first
        -- (plugins/coverbrowser.koplugin/main.lua:800-803), the notice closed, then the callback.
        local function cwngsync_download(stub, file, on_done)
            local InfoMessage = require("ui/widget/infomessage")
            local message = InfoMessage:new{ text = "Downloading…" }
            UIManager:show(message)
            UIManager:forceRePaint()
            download(stub)
            UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
            bim.rows[file] = nil
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            UIManager:close(message)
            on_done(file)
            return true
        end

        for _, kind in ipairs({ "library", "one series" }) do
            it("paints the " .. kind .. " once, with one refresh and one build, for cwngsync's re-lists and the "
                .. "callback's", function()
                local stub = cwngsync()
                stub.openLibraryPlaceholder = cwngsync_download
                local window = show_held(kind)
                hold(window, kind)
                local builds = 0
                local build = window.build
                window.build = function(...)
                    builds = builds + 1
                    return build(...)
                end
                local Screen = require("device").screen
                local paints = {}
                local after_paint = Screen.afterPaint
                replace(Screen, "afterPaint", function(...)
                    local refreshes = {}
                    for i, refresh in ipairs(UIManager._refresh_stack) do
                        refreshes[i] = refresh.region:copy()
                    end
                    paints[#paints + 1] = refreshes
                    return after_paint(...)
                end)
                tap("Download")
                -- The notice's own paint, cwngsync's forceRePaint.
                assert.equals(1, #paints)
                paints = {}
                harness.tick(1)
                assert.equals(1, #paints)
                assert.equals(1, #paints[1])
                assert.is_true(paints[1][1]:contains(window.dimen))
                -- The callback's re-list stands for the broadcasts' deferred one.
                assert.equals(1, builds)
                assert.equals(window, harness.top())
                assert.same({ { held } }, bim.extracted)
                -- Once its cover has arrived, the book is drawn without its badge.
                harness.tick(3)
                local part = part_of(window, kind)
                assert.is_not_nil(part)
                assert.is_nil(part.widget.badge)
                assert.same({}, logged)
            end)
        end

        it("does nothing when the window it was held on is no longer shown", function()
            local library, _, callback = tapped("library")
            local library_refreshes = count_refreshes(library)
            local series = show_held("one series")
            local series_refreshes = count_refreshes(series)
            local frame = series[1]
            bim.extracted = {}
            callback(held)
            harness.tick(3)
            assert.equals(series, harness.top())
            assert.equals(frame, series[1])
            -- The closed library freed its frame and builds none.
            assert.is_nil(library[1])
            assert.same({ 0, 0 }, { library_refreshes.n, series_refreshes.n })
            assert.same({}, bim.extracted)
            assert.same({}, logged)
        end)

        it("logs a raising re-list, the window shown over the file manager", function()
            local library, _, callback = tapped("library")
            library.downloaded = function()
                error("kopanda-test: the re-list failed")
            end
            callback(held)
            harness.tick(3)
            assert.is_true(was_logged("kopanda-test: the re-list failed"))
            assert.equals(library, harness.top())
            assert.equals(FileManager.instance, harness.top(2))
        end)
    end)
end)
