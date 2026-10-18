-- cwngsync's placeholders (cwng-placeholders C1, C2): CloudBooks' detection through the cwngsync
-- module the file manager registers (D12, D13), the record's placeholder flag from every public
-- Books entry (D14), and the surfaces that draw a flagged record as not downloaded (D1, D5, D6). Run
-- on a scratch library under the data directory, by its realpath, with home_dir pointed at it and
-- sidecars in the "dir" location, under a real file manager. cwngsync is never loaded: a stub
-- stands for it, registered on the file manager as cwngsync and removed after each case, with only
-- isConfigured and getLibraryState, its state naming files the case wrote. CoverBrowser is
-- unrequirable, so every record's cover is none.
describe("cwngsync's placeholders", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local EventListener = require("ui/widget/eventlistener")
    local FileManager = require("apps/filemanager/filemanager")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local texts = require("library_fixture").texts
    local Screen = require("device").screen
    local Books, Looks

    local scratch = DataStorage:getDataDir() .. "/cloud-books-library"
    local link = DataStorage:getDataDir() .. "/cloud-books-link"
    local home, a, b, logged

    -- Undo steps for the running case, run last first after it.
    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
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

    local function size_of(path)
        return lfs.attributes(path, "size")
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

    -- A configured cwngsync stub whose library state's books are books, keyed by book id as
    -- cwng_library.lua:17-20 keeps them, counting its getLibraryState calls in reads; fields
    -- replace its methods. Registered.
    local function cwngsync(books, fields)
        local stub = EventListener:new{ reads = 0 }
        function stub.isConfigured()
            return true
        end
        function stub.getLibraryState(self)
            self.reads = self.reads + 1
            return { version = 1, books = books }
        end
        for k, v in pairs(fields or {}) do
            stub[k] = v
        end
        return register(stub)
    end

    -- The state's record of path as a placeholder of size (default: the file's own size).
    local function placeholder(path, size)
        return { kind = "placeholder", path = path, size = size or size_of(path), mtime = 0, rev = 1 }
    end

    local function record_of(records, path)
        for _, record in ipairs(records) do
            if record.path == path then
                return record
            end
        end
        error("no record of " .. path)
    end

    local function replace(t, key, value)
        local saved = t[key]
        t[key] = value
        cleanup(function()
            t[key] = saved
        end)
    end

    local saved_err, saved_warn

    before_each(function()
        harness.load()
        Books = package.loaded["books"]
        Looks = package.loaded["looks"]
        Books.reset()
        package.loaded["bookinfomanager"] = nil
        package.preload["bookinfomanager"] = function()
            error("CoverBrowser is disabled in this spec")
        end
        G_reader_settings:saveSetting("document_metadata_folder", "dir")
        remove_tree(scratch)
        os.remove(link)
        remove_tree(DataStorage:getDocSettingsDir())
        assert(lfs.mkdir(scratch))
        home = ffiutil.realpath(scratch)
        G_reader_settings:saveSetting("home_dir", home)
        a, b = home .. "/a.epub", home .. "/b.epub"
        write(a, "a placeholder")
        write(b, "a book that is on the Kindle")
        harness.show_fm(home)
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
        package.preload["bookinfomanager"] = nil
        G_reader_settings:delSetting("document_metadata_folder")
        G_reader_settings:delSetting("home_dir")
        Books.reset()
        harness.teardown()
        remove_tree(scratch)
        os.remove(link)
        remove_tree(DataStorage:getDocSettingsDir())
    end)

    describe("detection and records", function()
        it("flags a recorded placeholder of the file's own size from every public entry, its path kept", function()
            cwngsync({ ["1"] = placeholder(a) })
            local listed = Books.folder(home).books
            assert.is_true(record_of(listed, a).placeholder)
            assert.equals(a, record_of(listed, a).path)
            assert.is_nil(record_of(listed, b).placeholder)
            local all = Books.all()
            assert.is_true(record_of(all, a).placeholder)
            assert.is_nil(record_of(all, b).placeholder)
            assert.is_true(Books.for_path(a).placeholder)
            assert.equals(a, Books.for_path(a).path)
            assert.is_nil(Books.for_path(b).placeholder)
            assert.is_true(Books.get("file:" .. ffiutil.realpath(a)).placeholder)
            assert.is_nil(Books.get("file:" .. ffiutil.realpath(b)).placeholder)
            local book, progress = Books.with_progress(a)
            assert.is_true(book.placeholder)
            assert.same({ status = "new" }, progress)
            assert.is_nil(Books.with_progress(b).placeholder)
            assert.same({}, logged)
        end)

        it("reads the state afresh at each call, so a download or a changed file shows at once", function()
            local books = { ["1"] = placeholder(a) }
            cwngsync(books)
            assert.is_true(Books.for_path(a).placeholder)
            books["1"] = { kind = "downloaded", path = a, size = size_of(a) }
            assert.is_nil(Books.for_path(a).placeholder)
            books["1"] = placeholder(a)
            assert.is_true(Books.for_path(a).placeholder)
            write(a, "the real book, downloaded over the placeholder")
            assert.is_nil(Books.for_path(a).placeholder)
        end)

        -- The listing with nothing registered, to compare a stubbed one with.
        local function baseline()
            return { folder = Books.folder(home), all = Books.all(), a = Books.for_path(a) }
        end

        local function listing()
            return { folder = Books.folder(home), all = Books.all(), a = Books.for_path(a) }
        end

        local silent = {
            ["a recorded size one byte off"] = function()
                cwngsync({ ["1"] = placeholder(a, size_of(a) + 1) })
            end,
            ["a downloaded kind"] = function()
                cwngsync({ ["1"] = { kind = "downloaded", path = a, size = size_of(a) } })
            end,
            ["a path recorded with a doubled slash"] = function()
                cwngsync({ ["1"] = placeholder(home .. "//a.epub", size_of(a)) })
            end,
            ["a path recorded through a symlink"] = function()
                assert.equals(0, os.execute(string.format("ln -s %q %q", home, link)))
                assert.equals(size_of(a), size_of(link .. "/a.epub"))
                cwngsync({ ["1"] = placeholder(link .. "/a.epub", size_of(a)) })
            end,
            ["a size that isn't a number"] = function()
                cwngsync({ ["1"] = placeholder(a, tostring(size_of(a))) })
            end,
            ["an unconfigured plugin"] = function()
                cwngsync({ ["1"] = placeholder(a) }, {
                    isConfigured = function()
                        return false
                    end,
                })
            end,
            ["no cwngsync module"] = function() end,
            ["no file manager instance"] = function()
                cwngsync({ ["1"] = placeholder(a) })
                replace(FileManager, "instance", nil)
            end,
        }
        for name, arrange in pairs(silent) do
            it("flags nothing and logs nothing for " .. name, function()
                local before = baseline()
                arrange()
                logged = {}
                assert.same(before, listing())
                assert.same({}, logged)
            end)
        end

        local logged_cases = {
            ["getLibraryState missing"] = { getLibraryState = false },
            ["isConfigured missing"] = { isConfigured = false },
            ["getLibraryState raising"] = {
                getLibraryState = function()
                    error("kopanda-test: state unreadable")
                end,
            },
            ["isConfigured raising"] = {
                isConfigured = function()
                    error("kopanda-test: settings unreadable")
                end,
            },
            ["a state of {}"] = {
                getLibraryState = function()
                    return {}
                end,
            },
            ["a state whose books is a string"] = {
                getLibraryState = function()
                    return { books = "x" }
                end,
            },
        }
        for name, fields in pairs(logged_cases) do
            it("flags nothing and logs one error for " .. name .. ", the listing otherwise as it was", function()
                local before = Books.folder(home)
                cwngsync({ ["1"] = placeholder(a) }, fields)
                logged = {}
                assert.same(before, Books.folder(home))
                assert.equals(1, #logged)
            end)
        end

        it("reads the state once per Books call, not once per book", function()
            write(home .. "/c.epub", "a third book")
            assert(lfs.mkdir(home .. "/nested"))
            write(home .. "/nested/d.epub", "a book in a folder")
            local stub = cwngsync({ ["1"] = placeholder(a), ["2"] = placeholder(home .. "/c.epub") })
            local all = Books.all()
            assert.equals(4, #all)
            assert.equals(1, stub.reads)
            stub.reads = 0
            assert.equals(3, #Books.folder(home).books)
            assert.equals(1, stub.reads)
            stub.reads = 0
            Books.get("file:" .. a)
            assert.equals(1, stub.reads)
            stub.reads = 0
            Books.with_progress(a)
            assert.equals(1, stub.reads)
        end)

        it("leaves path-less source records and Books.files as they were", function()
            Books.add_source({
                name = "shelf",
                books = function()
                    return { { id = "shelf:x", title = "X", authors = { "Ann" } } }
                end,
            })
            local files = Books.files(home)
            local before = Books.folder(home).books
            local stub = cwngsync({ ["1"] = placeholder(a) })
            stub.reads = 0
            assert.same(files, Books.files(home))
            assert.equals(0, stub.reads)
            local after = Books.folder(home).books
            assert.equals(#before, #after)
            assert.same(before[#before], after[#after])
            assert.equals("shelf:x", after[#after].id)
            assert.is_nil(after[#after].placeholder)
        end)
    end)

    describe("the surfaces", function()
        local NEW = { status = "new" }
        local READING = { status = "reading", percent = 0.4 }
        local COMPLETE = { status = "complete", percent = 1 }

        local function ctx_for(id)
            return { look = Looks.get(id), variant = "day", screen = Screen }
        end

        local function lower(list)
            local out = {}
            for i, line in ipairs(list) do
                out[i] = line:lower()
            end
            return out
        end

        local function each_look(fn)
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    fn(id, ctx_for(id))
                end
            end)
        end

        it("puts the badge and the Not downloaded chip on a placeholder's tile, Up next in the chip's place "
            .. "with the badge kept, and its strip beside them", function()
            local LibraryTiles = package.loaded["library_tiles"]
            cwngsync({ ["1"] = placeholder(a) })
            local record = Books.for_path(a)
            assert.is_true(record.placeholder)
            each_look(function(id, ctx)
                local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                local tile = LibraryTiles.book(record, NEW, box, ctx)
                assert.is_table(tile.badge, id)
                assert.same({ "not downloaded" }, lower(texts(tile.chip)), id)
                assert.is_nil(tile.strip, id)
                tile:free()
                tile = LibraryTiles.book(record, NEW, box, ctx, { label = "Up next" })
                assert.is_table(tile.badge, id)
                assert.same({ "up next" }, lower(texts(tile.chip)), id)
                tile:free()
                tile = LibraryTiles.book(record, READING, box, ctx)
                assert.is_table(tile.strip, id)
                assert.is_table(tile.badge, id)
                assert.is_table(tile.chip, id)
                tile:free()
            end)
        end)

        it("puts the badge, the chip and the note on a placeholder's one-series row", function()
            local ShelfRows = package.loaded["shelf_rows"]
            cwngsync({ ["1"] = placeholder(a) })
            local record = Books.for_path(a)
            each_look(function(id, ctx)
                local width = Screen:getWidth() - 2 * Screen:scaleBySize(ctx.look.shelf.list.side)
                local row = ShelfRows.book(record, NEW, false, width, ctx)
                assert.is_table(row.badge, id)
                assert.same({ "not downloaded" }, lower(texts(row.chip)), id)
                assert.same({ "not on the kindle yet" }, lower(texts(row.note)), id)
                assert.is_nil(row.bar, id)
                row:free()
                row = ShelfRows.book(record, COMPLETE, false, width, ctx)
                assert.is_table(row.badge, id)
                assert.same({ "finished" }, lower(texts(row.chip)), id)
                assert.is_table(row.bar, id)
                assert.is_nil(row.note, id)
                row:free()
                row = ShelfRows.book(record, READING, false, width, ctx)
                assert.is_table(row.badge, id)
                assert.is_table(row.bar, id)
                assert.is_nil(row.note, id)
                row:free()
                row = ShelfRows.book(record, NEW, true, width, ctx)
                assert.is_table(row.badge, id)
                assert.same({ "read this one next" }, lower(texts(row.note)), id)
                row:free()
            end)
        end)

        it("draws the same file's tile and row as downloaded without cwngsync", function()
            local LibraryTiles = package.loaded["library_tiles"]
            local ShelfRows = package.loaded["shelf_rows"]
            local record = Books.for_path(a)
            assert.is_nil(record.placeholder)
            each_look(function(id, ctx)
                local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                local tile = LibraryTiles.book(record, NEW, box, ctx)
                assert.is_nil(tile.badge, id)
                assert.is_nil(tile.chip, id)
                tile:free()
                local width = Screen:getWidth() - 2 * Screen:scaleBySize(ctx.look.shelf.list.side)
                local row = ShelfRows.book(record, NEW, false, width, ctx)
                assert.is_nil(row.badge, id)
                assert.is_nil(row.chip, id)
                assert.is_nil(row.note, id)
                row:free()
            end)
        end)

        local function centre(rect)
            return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
        end

        -- The window's tap at the centre of rect, its open recorded rather than run.
        local function tap_opens(window, rect)
            local opened = {}
            window.open = function(_, record)
                opened[#opened + 1] = record
            end
            local x, y = centre(rect)
            local action = window:action_at({ x = x, y = y })
            assert.is_function(action)
            action()
            return opened
        end

        it("opens a placeholder on a tap on its library tile, the tile badged", function()
            cwngsync({ ["1"] = placeholder(a) })
            harness.tick(2)
            package.loaded["home"].close()
            local library = package.loaded["library"].show{ dir = home }
            harness.tick(2)
            local tile
            for _, t in ipairs(library.tiles) do
                if t.record and t.record.path == a then
                    tile = t
                end
            end
            assert.is_true(tile.record.placeholder)
            assert.is_table(tile.widget.badge)
            local opened = tap_opens(library, tile.rect)
            assert.equals(1, #opened)
            assert.equals(tile.record, opened[1])
        end)

        it("opens a placeholder on a tap on its one-series row and its one-author tile", function()
            local shelf = require("shelf_fixture")
            local record = shelf.book("Held 1", { series = "Held", series_index = 1, authors = { "Ann Author" },
                placeholder = true })
            shelf.install({ record, shelf.book("Held 2", { series = "Held", series_index = 2,
                authors = { "Ann Author" } }) })
            local screen = shelf.show({ kind = "series", name = "Held" })
            assert.equals(record, screen.rows[1].record)
            assert.is_table(screen.rows[1].widget.badge)
            local opened = tap_opens(screen, screen.rows[1].rect)
            assert.same({ record }, opened)
            harness.teardown()
            screen = shelf.show_authors({ kind = "author", name = "Ann Author" })
            local tile
            for _, t in ipairs(screen.tiles) do
                if t.record == record then
                    tile = t
                end
            end
            assert.is_table(tile.widget.badge)
            opened = tap_opens(screen, tile.rect)
            assert.same({ record }, opened)
        end)

        describe("the book sheet", function()
            local BookSheet, Sheet

            before_each(function()
                BookSheet = package.loaded["book_sheet"]
                Sheet = package.loaded["sheet"]
            end)

            -- A window as the library's and the shelf screens' are to the sheet, as
            -- book_sheet_spec.lua's: ctx, open(record), refresh() and close(), each recorded.
            local function window()
                local w = {
                    screen = "library",
                    ctx = { look = Looks.active(), variant = Looks.variant(), screen = Screen },
                    opened = {},
                    refreshes = 0,
                    closes = 0,
                }
                function w:open(record)
                    self.opened[#self.opened + 1] = record
                end
                function w:refresh()
                    self.refreshes = self.refreshes + 1
                end
                function w.close()
                    w.closes = w.closes + 1
                end
                return w
            end

            local function open(record)
                harness.tick(4)
                local w = window()
                BookSheet.open_record(record, w, w.ctx, { beneath = w })
                return w
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

            local function rows()
                local got = {}
                for i, row in ipairs(Sheet.shown.spec.rows) do
                    got[i] = { row.label, row.muted == true, row.run ~= nil }
                end
                return got
            end

            -- This stub has no openLibraryPlaceholder, so Download is greyed too
            -- (cloud_download_spec.lua has the row with it).
            it("reads Not downloaded over a placeholder and greys Delete and Download alone", function()
                cwngsync({ ["1"] = placeholder(a) })
                local record = Books.for_path(a)
                open(record)
                assert.equals("Not downloaded", Sheet.shown.spec.header.meta)
                assert.same({
                    { "Open", false, true },
                    { "Download", true, false },
                    { "Book details", false, true },
                    { "Read status", false, true },
                    { "More by this author", false, true },
                    { "Add to the home", false, true },
                    { "Delete…", true, false },
                }, rows())
            end)

            it("closes the sheet and runs nothing on a tap on a placeholder's Delete", function()
                cwngsync({ ["1"] = placeholder(a) })
                local w = open(Books.for_path(a))
                local top = harness.top(2)
                tap("Delete…")
                assert.is_nil(Sheet.shown)
                assert.equals(top, harness.top())
                assert.equals("file", lfs.attributes(a, "mode"))
                assert.same({ 0, 0 }, { w.refreshes, w.closes })
            end)

            it("shows KOReader's book details for a placeholder's path", function()
                cwngsync({ ["1"] = placeholder(a) })
                open(Books.for_path(a))
                local shown = {}
                FileManager.instance.bookinfo.show = function(_, file)
                    shown[#shown + 1] = file
                end
                tap("Book details")
                assert.same({ a }, shown)
            end)

            it("reads the same file as downloaded without cwngsync, Delete running", function()
                open(Books.for_path(a))
                assert.is_not.equals("Not downloaded", Sheet.shown.spec.header.meta)
                local delete = place_of("Delete…").row
                assert.is_nil(delete.muted)
                assert.is_function(delete.run)
            end)
        end)
    end)
end)
