-- The library's covers (cover-grid C9): after a page's first paint it asks for that page's covers at
-- the cover box's size, an arrival rebuilds only the arrived tiles from their re-read records without
-- re-sorting, a new page replaces the request, a page turn leaves the extraction in flight checked,
-- closing the library cancels the check, and the frames and tiles it replaces are freed.
-- BookCovers.request and cancel are stubbed, except in the case that runs the real ones on a stub
-- bookinfomanager; Books.folder and progress are the fixture's.
describe("the library's lifecycle", function()
    local harness = require("plugin_harness")
    local fixture = require("library_fixture")
    local UIManager = require("ui/uimanager")
    local BookCovers, Books, Library

    local ROOT = fixture.ROOT

    local requests, cancels, real

    before_each(function()
        harness.load()
        Library = package.loaded["library"]
        BookCovers = package.loaded["book_covers"]
        Books = package.loaded["books"]
        real = { request = BookCovers.request, cancel = BookCovers.cancel }
        requests, cancels = {}, 0
        BookCovers.request = function(records, specs, on_arrival, alive)
            requests[#requests + 1] = { records = records, specs = specs, on_arrival = on_arrival, alive = alive }
        end
        BookCovers.cancel = function()
            cancels = cancels + 1
        end
    end)

    after_each(function()
        fixture.restore()
        harness.teardown()
    end)

    -- The library shown at dir over a file manager whose home has closed, painted and settled; the
    -- home's own cover request, made before, forgotten.
    local function show(dir)
        harness.show_fm()
        harness.tick(2)
        require("home").close()
        requests = {}
        local library = Library.show{ dir = dir or ROOT }
        harness.tick(2)
        return library
    end

    local function ids(records)
        local out = {}
        for i, record in ipairs(records) do
            out[i] = record.id
        end
        return out
    end

    local function page_ids(library)
        local out = {}
        for _, tile in ipairs(library.tiles) do
            if tile.record then
                out[#out + 1] = tile.record.id
            end
        end
        return out
    end

    describe("covers", function()
        it("are asked for the page's books at the cover box's size after the page's first paint", function()
            local books = fixture.books(8)
            fixture.install({ [ROOT] = { books = books, folders = { fixture.folder("Sci-fi") } } })
            local fm = harness.show_fm()
            harness.tick(2)
            require("home").close()
            requests = {}
            local library = Library.show{ dir = ROOT }
            assert.same({}, requests)
            harness.tick(2)
            assert.equals(1, #requests)
            local request = requests[1]
            assert.same({ books[1].id, books[2].id, books[3].id, books[4].id, books[5].id }, ids(request.records))
            assert.same({ max_cover_w = library.box.cover_w, max_cover_h = library.box.cover_h }, request.specs)
            assert.is_true(request.alive())
            assert.equals(fm, harness.top(2))
        end)

        it("rebuild only an arrived tile with its re-read title and set the library dirty, not re-sorted", function()
            local books = fixture.books(4)
            fixture.install({ [ROOT] = { books = books } })
            local library = show()
            local before, rects = {}, {}
            for i, tile in ipairs(library.tiles) do
                before[i] = tile.widget
                rects[i] = { x = tile.rect.x, y = tile.rect.y, w = tile.rect.w, h = tile.rect.h }
            end
            local order = page_ids(library)
            local fresh = {}
            for k, v in pairs(books[2]) do
                fresh[k] = v
            end
            fresh.title = "Zebra Stripes"
            local got = {}
            Books.get = function(id)
                got[#got + 1] = id
                return id == fresh.id and fresh or nil
            end
            local dirty = {}
            local set_dirty = UIManager.setDirty
            UIManager.setDirty = function(manager, widget, ...)
                dirty[#dirty + 1] = widget
                return set_dirty(manager, widget, ...)
            end
            local ok, err = pcall(requests[1].on_arrival, { books[2] })
            UIManager.setDirty = set_dirty
            assert.is_true(ok, tostring(err))
            assert.same({ books[2].id }, got)
            assert.same(order, page_ids(library))
            assert.equals("Zebra Stripes", library.tiles[2].record.title)
            assert.is_true(fixture.texts(library.tiles[2].widget)[1] ~= nil)
            local found = false
            for _, line in ipairs(fixture.texts(library.tiles[2].widget)) do
                found = found or line:lower() == "zebra stripes"
            end
            assert.is_true(found, "the arrived tile shows its re-read title")
            assert.is_not.equals(before[2], library.tiles[2].widget)
            -- Its box stays where a tap finds it.
            local rect = library.tiles[2].rect
            assert.same(rects[2], { x = rect.x, y = rect.y, w = rect.w, h = rect.h })
            for _, i in ipairs({ 1, 3, 4 }) do
                assert.equals(before[i], library.tiles[i].widget, "tile " .. i)
            end
            local marked = false
            for _, widget in ipairs(dirty) do
                marked = marked or widget == library
            end
            assert.is_true(marked, "the library is set dirty")
        end)

        it("are asked again for a new page's books", function()
            local books = fixture.books(14)
            fixture.install({ [ROOT] = { books = books } })
            local library = show()
            assert.equals(1, #requests)
            library:go(ROOT, 2)
            harness.tick(2)
            assert.equals(2, #requests)
            assert.same({ books[7].id, books[8].id, books[9].id, books[10].id, books[11].id, books[12].id },
                ids(requests[2].records))
            assert.same(page_ids(library), ids(requests[2].records))
        end)

        it("still arrive for a page left and come back to while its extraction runs", function()
            local books = fixture.books(12)
            fixture.install({ [ROOT] = { books = books } })
            harness.show_fm()
            harness.tick(2)
            require("home").close()
            -- CoverBrowser's rows by file: page 2's cached with a cover, page 1's none until their
            -- covers land. isCachedCoverInvalid is true for a row with no cover_w
            -- (bookinfomanager.lua:1014-1015).
            local rows = {}
            for i = 7, 12 do
                rows[books[i].path] = { has_cover = "Y", cover_fetched = "Y", cover_w = 10000, cover_h = 10000 }
            end
            local extracted = {}
            local bim = {}
            function bim:getBookInfo(file)
                return rows[file]
            end
            function bim.isCachedCoverInvalid(info)
                return not info.cover_w
            end
            function bim:extractInBackground(files)
                extracted[#extracted + 1] = files
                return true
            end
            function bim:isExtractingInBackground()
                return true
            end
            local loaded = package.loaded.bookinfomanager
            package.loaded.bookinfomanager = bim
            finally(function()
                package.loaded.bookinfomanager = loaded
            end)
            BookCovers.request, BookCovers.cancel = real.request, real.cancel
            Books.get = function() return nil end
            local library = Library.show{ dir = ROOT }
            harness.tick(2)
            assert.equals(1, #extracted)
            library:go(ROOT, 2)
            harness.tick(2)
            library:go(ROOT, 1)
            harness.tick(2)
            assert.same({ books[1].id, books[2].id, books[3].id, books[4].id, books[5].id, books[6].id },
                page_ids(library))
            local before = {}
            for i, tile in ipairs(library.tiles) do
                before[i] = tile.widget
            end
            for i = 1, 6 do
                rows[books[i].path] = { has_cover = "Y", cover_fetched = "Y", cover_w = 10000, cover_h = 10000 }
            end
            harness.tick()
            for i, tile in ipairs(library.tiles) do
                assert.is_not.equals(before[i], tile.widget, "tile " .. i .. " rebuilt on its cover's arrival")
            end
        end)

        it("are no longer checked once the library closes", function()
            fixture.install({ [ROOT] = { books = fixture.books(3) } })
            local library = show()
            local alive = requests[1].alive
            local cancelled = cancels
            Library.close()
            assert.equals(cancelled + 1, cancels)
            assert.is_false(alive())
            assert.is_nil(Library.shown)
            assert.is_false(UIManager:isWidgetShown(library))
        end)
    end)

    describe("freeing", function()
        it("frees the frame a page turn replaces, the tile an arrival replaces and the frame at close", function()
            local books = fixture.books(8)
            fixture.install({ [ROOT] = { books = books } })
            local library = show()
            Books.get = function() return nil end
            -- Records each free of widget in freed under name, then frees it.
            local freed = {}
            local function watch(name, widget)
                local free = widget.free
                widget.free = function(self, ...)
                    freed[name] = true
                    return free(self, ...)
                end
            end
            watch("tile", library[1][library.tiles[1].index])
            requests[1].on_arrival({ books[1] })
            assert.is_true(freed.tile, "the tile an arrival replaced is freed")
            watch("first frame", library[1])
            library:go(ROOT, 2)
            assert.is_true(freed["first frame"], "the frame a page turn replaced is freed")
            watch("last frame", library[1])
            Library.close()
            assert.is_true(freed["last frame"], "the frame shown at close is freed")
        end)
    end)

    describe("closing", function()
        it("stores the folder and page it was left at", function()
            local sub = fixture.folder("Sci-fi")
            fixture.install({ [ROOT] = { folders = { sub } }, [sub.path] = { books = fixture.books(8, sub.path) } })
            local library = show()
            library:go(sub.path, 2)
            Library.close()
            assert.same({ dir = sub.path, page = 2 }, package.loaded["library_order"].left())
        end)
    end)

    -- cover-grid C8, D6: the ways in. The library target is what the launcher's entry, the Library
    -- tab everywhere and the featured widget's first-run button run.
    describe("entry points", function()
        local Home, LauncherEntries, NavBar
        local sub = fixture.folder("Sci-fi")

        before_each(function()
            Home = package.loaded["home"]
            LauncherEntries = package.loaded["launcher_entries"]
            NavBar = package.loaded["nav_bar"]
            fixture.install({ [ROOT] = { folders = { sub }, books = fixture.books(8) },
                [sub.path] = { books = fixture.books(8, sub.path) } })
        end)

        local function fm_with_home()
            local fm = harness.show_fm()
            harness.tick(2)
            assert.equals(Home.shown, harness.top())
            return fm
        end

        local function run_target()
            LauncherEntries.run({ kind = "kopanda", target = "library" }, {})
        end

        -- The library shown on top of fm at dir and page, with the home closed.
        local function library_at(fm, dir, page)
            local library = Library.shown
            assert.is_not_nil(library)
            assert.equals(library, harness.top())
            assert.equals(fm, harness.top(2))
            assert.is_nil(Home.shown)
            assert.same({ dir, page }, { library.dir, library.page })
            return library
        end

        it("the first time, closes the home and shows the root's first page", function()
            local fm = fm_with_home()
            run_target()
            library_at(fm, ROOT, 1)
        end)

        it("from the file browser's Library tab shows the library over it", function()
            local fm = fm_with_home()
            Home.close()
            NavBar.run("library", "file_browser")
            library_at(fm, ROOT, 1)
        end)

        it("shows the folder and page last left, after the Home tab closed the library onto the home", function()
            local fm = fm_with_home()
            run_target()
            Library.shown:go(sub.path, 2)
            NavBar.run("home", "library")
            assert.is_nil(Library.shown)
            assert.equals(Home.shown, harness.top())
            run_target()
            library_at(fm, sub.path, 2)
        end)

        it("on the library's own Library tab goes to the root's first page in place", function()
            local fm = fm_with_home()
            run_target()
            local library = Library.shown
            library:go(sub.path, 2)
            harness.tick(2)
            local shows = spy.on(UIManager, "show")
            NavBar.run("library", "library")
            UIManager.show:revert()
            assert.equals(library, library_at(fm, ROOT, 1))
            assert.spy(shows).was_not_called()
        end)

        it("shows nothing through the plugin's showLibrary once the file manager has gone", function()
            assert.is_nil(require("apps/filemanager/filemanager").instance)
            local shows = spy.on(UIManager, "show")
            require("pluginloader").enabled_plugins[1]:showLibrary{}
            UIManager.show:revert()
            assert.is_nil(Library.shown)
            assert.spy(shows).was_not_called()
            assert.is_nil(harness.top())
        end)

        it("closes the library with the file manager", function()
            local fm = fm_with_home()
            run_target()
            local library = Library.shown
            assert.is_not_nil(library)
            fm:onClose()
            assert.is_nil(Library.shown)
            assert.is_false(UIManager:isWidgetShown(library))
        end)
    end)

    -- cover-grid C8, D4: a book opened from the library closes back to it. KOReader's open is
    -- stubbed at filemanagerutil.openFile; the test then does what an open that goes ahead does:
    -- the pre-callback (filemanagerutil.lua:500-502), the file manager closing for the reader
    -- (filemanager.lua:842-849), a real reader closed (readerui.lua:870-893) and a new file manager
    -- shown (readerui.lua:581-596), as prebuild_spec.lua drives the home's.
    describe("after a book opened from it closes", function()
        local Event = require("ui/event")
        local Geom = require("ui/geometry")
        local ffiutil = require("ffi/util")
        local Home, LibraryOrder, Looks, util, real_open, opened, progress, signals, listener
        local BOOK = harness.library .. "/frankenstein.epub"
        local ID = "file:" .. ffiutil.realpath(BOOK)
        local sub = fixture.folder("Sci-fi")

        before_each(function()
            Home = package.loaded["home"]
            LibraryOrder = package.loaded["library_order"]
            Looks = package.loaded["looks"]
            util = require("apps/filemanager/filemanagerutil")
            real_open = util.openFile
            opened = nil
            util.openFile = function(ui, file, pre)
                opened = { ui = ui, file = file, pre = pre }
            end
            -- Seven books and the real one in sub, by title: page 2 is Book 07 and Frankenstein.
            local books = fixture.books(7, sub.path)
            books[8] = { id = ID, path = BOOK, title = "Frankenstein", authors = {} }
            progress = { [ID] = { status = "new" } }
            fixture.install({ [ROOT] = { folders = { sub } }, [sub.path] = { books = books } }, progress)
            assert.is_true(LibraryOrder.choose(sub.path, "title", "all"))
            signals = {}
            listener = function(args)
                if args.screen == "library" then
                    signals[#signals + 1] = args
                end
            end
            UIManager.event_hook:register("KoPandaSettled", listener)
        end)

        after_each(function()
            util.openFile = real_open
            UIManager.event_hook:unregister("KoPandaSettled", listener)
        end)

        local function titles(library)
            local out = {}
            for i, tile in ipairs(library.tiles) do
                out[i] = tile.record and tile.record.title or tile.folder.name
            end
            return out
        end

        local function book_tile(library)
            for _, tile in ipairs(library.tiles) do
                if tile.record and tile.record.id == ID then
                    return tile
                end
            end
        end

        -- The library at sub's page 2 over a file manager, painted and settled; the file manager.
        local function at_page_two()
            local fm = harness.show_fm()
            harness.tick(2)
            Home.close()
            local library = Library.show{ dir = sub.path, page = 2 }
            harness.tick(2)
            assert.same({ "Book 07", "Frankenstein" }, titles(library))
            signals = {}
            return library, fm
        end

        -- A tap on the book's tile, the open asked of KOReader.
        local function tap_book(library)
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", fixture.centre(book_tile(library).rect))))
            assert.equals(BOOK, opened.file)
        end

        -- The open going ahead: KOReader's pre-callback, then the file manager closing for the reader.
        local function goes_ahead(fm)
            opened.pre()
            fm:onShowingReader()
        end

        local function read_and_close(book)
            local reader = harness.open_reader(book)
            harness.tick(2)
            reader:onClose()
        end

        it("shows it pre-built in one show at the same folder, sort, status and page, with the progress "
            .. "saved after the close", function()
                local library, fm = at_page_two()
                tap_book(library)
                goes_ahead(fm)
                assert.is_nil(Library.shown)
                read_and_close()
                local pending = Library.pending
                assert.is_not_nil(pending)
                assert.is_false(UIManager:isWidgetShown(pending))
                assert.is_false(Home.just_closed)
                assert.is_nil(book_tile(pending).widget.strip)
                -- The reader writes its sidecar after CloseDocument. The record read again is the
                -- listing's, so the title stays the spec's.
                progress[ID] = { status = "reading", percent = 0.4 }
                Books.get = function() return nil end
                local builds = spy.on(Library, "new")
                local new_fm = harness.show_fm()
                assert.equals(pending, harness.top())
                assert.equals(new_fm, harness.top(2))
                assert.equals(pending, Library.shown)
                assert.is_nil(Library.pending)
                harness.tick(4)
                Library.new:revert()
                assert.spy(builds).was_not_called()
                assert.equals(pending, harness.top())
                assert.is_nil(Home.shown)
                assert.same({ sub.path, 2 }, { pending.dir, pending.page })
                assert.same({ sort = "title", status = "all" }, LibraryOrder.choice(pending.dir))
                assert.same({ "Book 07", "Frankenstein" }, titles(pending))
                assert.is_not_nil(book_tile(pending).widget.strip)
                assert.equals(1, #signals)
                assert.is_true(signals[1].prebuilt)
                assert.is_number(signals[1].paint_ms)
            end)

        for _, case in ipairs({
            { "another size", function(pending)
                local size = require("device").screen:getSize()
                pending.dimen = Geom:new{ x = 0, y = 0, w = size.h, h = size.w }
            end },
            { "another variant", function(pending)
                pending.ctx.variant = Looks.variant() == "night" and "day" or "night"
            end },
        }) do
            it("drops one pre-built at " .. case[1] .. " and builds it afresh at the same page", function()
                local library, fm = at_page_two()
                tap_book(library)
                goes_ahead(fm)
                read_and_close()
                local pending = Library.pending
                case[2](pending)
                local freed = spy.on(pending, "free")
                harness.show_fm()
                harness.tick(2)
                local shown = Library.shown
                assert.is_not_nil(shown)
                assert.is_not.equals(pending, shown)
                assert.equals(shown, harness.top())
                assert.is_nil(Library.pending)
                assert.spy(freed).was_called()
                assert.same({ sub.path, 2 }, { shown.dir, shown.page })
                assert.same({ "Book 07", "Frankenstein" }, titles(shown))
            end)
        end

        it("after a failed open, with no book closed, shows the library afresh at the same page", function()
            local library, fm = at_page_two()
            tap_book(library)
            goes_ahead(fm)
            harness.show_fm()
            harness.tick(2)
            local shown = Library.shown
            assert.is_not_nil(shown)
            assert.equals(shown, harness.top())
            assert.is_nil(Home.shown)
            assert.same({ sub.path, 2 }, { shown.dir, shown.page })
            assert.equals(1, #signals)
            assert.is_false(signals[1].prebuilt)
        end)

        it("comes back after another book opened from inside the reader", function()
            local library, fm = at_page_two()
            tap_book(library)
            goes_ahead(fm)
            read_and_close()
            local pending = Library.pending
            local freed = spy.on(pending, "free")
            local switched = harness.open_reader("the-time-machine.epub")
            assert.is_nil(Library.pending)
            assert.spy(freed).was_called()
            harness.tick(2)
            switched:onClose()
            assert.is_not_nil(Library.pending)
            harness.show_fm()
            harness.tick(2)
            assert.equals(Library.shown, harness.top())
            assert.same({ sub.path, 2 }, { Library.shown.dir, Library.shown.page })
        end)

        it("records no return for a cancelled open, so a book closed later lands on the home", function()
            local library, fm = at_page_two()
            tap_book(library)
            assert.equals(library, harness.top())
            package.loaded["nav_bar"].run("home", "library")
            fm:onShowingReader()
            read_and_close()
            assert.is_nil(Library.pending)
            harness.show_fm()
            harness.tick(2)
            assert.is_nil(Library.shown)
            assert.equals(Home.shown, harness.top())
        end)

        it("takes the return once: a book then opened from the home closes to the home", function()
            local library, fm = at_page_two()
            tap_book(library)
            goes_ahead(fm)
            read_and_close()
            local new_fm = harness.show_fm()
            harness.tick(2)
            assert.equals(Library.shown, harness.top())
            package.loaded["nav_bar"].run("home", "library")
            assert.equals(Home.shown, harness.top())
            new_fm:onShowingReader()
            read_and_close()
            assert.is_nil(Library.pending)
            harness.show_fm()
            harness.tick(2)
            assert.is_nil(Library.shown)
            assert.equals(Home.shown, harness.top())
        end)

        -- An open KOReader refuses after the pre-callback ran, so the file manager never closes: a
        -- file gone since the listing (readerui.lua:621-626) or of no supported type
        -- (readerui.lua:671-674). The real openFile runs.
        for _, case in ipairs({
            { "a file of no supported type", "notes.kopanda-unknown", true },
            { "a file gone since the listing", "gone.epub", false },
        }) do
            it("drops the return of an open refused for " .. case[1] .. " once the library closes, so a "
                .. "book then opened from the home closes to the home", function()
                    local path = require("datastorage"):getDataDir() .. "/" .. case[2]
                    os.remove(path)
                    if case[3] then
                        local file = assert(io.open(path, "w"))
                        file:write("not a book")
                        file:close()
                    end
                    local id = "file:" .. path
                    local books = fixture.books(7, sub.path)
                    books[8] = { id = id, path = path, title = "Frankenstein", authors = {} }
                    fixture.install({ [ROOT] = { folders = { sub } }, [sub.path] = { books = books } })
                    assert.is_true(LibraryOrder.choose(sub.path, "title", "all"))
                    util.openFile = real_open
                    local library, fm = at_page_two()
                    local tile
                    for _, t in ipairs(library.tiles) do
                        if t.record and t.record.id == id then
                            tile = t
                        end
                    end
                    UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", fixture.centre(tile.rect))))
                    os.remove(path)
                    assert.is_not_nil(Library.return_to)
                    local refusal = harness.top()
                    assert.is_truthy(refusal.text and refusal.text:find(case[2], 1, true))
                    UIManager:close(refusal)
                    assert.equals(library, harness.top())
                    package.loaded["nav_bar"].run("home", "library")
                    assert.equals(Home.shown, harness.top())
                    fm:onShowingReader()
                    read_and_close()
                    assert.is_nil(Library.pending)
                    harness.show_fm()
                    harness.tick(2)
                    assert.is_nil(Library.shown)
                    assert.equals(Home.shown, harness.top())
                end)
        end

        it("leaves a book opened over the library from elsewhere, such as History, closing to the home", function()
            local _, fm = at_page_two()
            fm:onShowingReader()
            read_and_close()
            harness.show_fm()
            harness.tick(2)
            assert.is_nil(Library.shown)
            assert.equals(Home.shown, harness.top())
        end)

        it("keeps the return in memory only: after a restart the file manager shows the home", function()
            local library, fm = at_page_two()
            tap_book(library)
            goes_ahead(fm)
            harness.load()
            harness.show_fm()
            harness.tick(2)
            assert.is_nil(package.loaded["library"].shown)
            assert.equals(package.loaded["home"].shown, harness.top())
        end)
    end)
end)
