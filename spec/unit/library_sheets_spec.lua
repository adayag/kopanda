-- The hold's dispatch (context-menu C7, "Holds", D3, D16): LibrarySheets.hold opens the book sheet
-- for a book held on the library, on one series and on one author, over that window as the screen
-- beneath, its paint_ms from the hold, and opens nothing for a series row, an author row or empty
-- space on the Series and Authors windows. The held books are files under KO_HOME, so the sheet's
-- check that the file is still there passes.
describe("LibrarySheets.hold", function()
    local harness = require("plugin_harness")
    local library_fixture = require("library_fixture")
    local shelf_fixture = require("shelf_fixture")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")
    local centre = library_fixture.centre
    local LibrarySheets, Sheet

    local dir = os.getenv("KO_HOME") .. "/library-sheets-books"
    local settled, listener

    -- A file under dir named name, copied from the fixture library's EPUB.
    local function file(name)
        local path = dir .. "/" .. name
        local from = assert(io.open(harness.library .. "/frankenstein.epub", "rb"))
        local to = assert(io.open(path, "wb"))
        to:write(from:read("*a"))
        from:close()
        to:close()
        return path
    end

    before_each(function()
        harness.load()
        LibrarySheets = package.loaded["library_sheets"]
        Sheet = package.loaded["sheet"]
        if not lfs.attributes(dir, "mode") then
            assert(lfs.mkdir(dir))
        end
        settled = {}
        listener = function(args)
            if args.screen == "sheet" then
                settled[#settled + 1] = args
            end
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
    end)

    after_each(function()
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        library_fixture.restore()
        harness.teardown()
    end)

    -- A stamp 200 ms before now, so a paint_ms that runs from it is at least 200.
    local function earlier()
        return { wall = time.monotonic() - time.ms(200), cpu = os.clock() }
    end

    -- Holds hit on window with the stamp of earlier(), then asserts the book sheet of record is shown
    -- over window, its paint_ms from that stamp and its settled signal named book.
    local function assert_book_sheet(window, hit, record)
        local started = earlier()
        LibrarySheets.hold(window, hit, started)
        local sheet = Sheet.shown
        assert.is_not_nil(sheet)
        assert.equals("book", sheet.spec.name)
        assert.equals(record.title, sheet.spec.header.title)
        assert.equals(window, sheet.beneath)
        assert.equals(started, sheet.started)
        assert.equals(sheet, harness.top())
        assert.equals(window, harness.top(2))
        harness.tick(3)
        assert.equals(1, #settled)
        assert.equals("book", settled[1].name)
        assert.truthy(settled[1].paint_ms >= 200, settled[1].paint_ms)
    end

    it("opens the book sheet over the library for a book held there", function()
        local path = file("library.epub")
        local record = { id = "file:" .. path, path = path, title = "Held Book", authors = { "Ann Author" } }
        library_fixture.install({ [library_fixture.ROOT] = { books = { record } } })
        local library = library_fixture.show()
        local Library = package.loaded["library"]
        local hit = Library.hit(centre(library.tiles[1].rect))
        assert.equals("book", hit.kind)
        assert_book_sheet(library, hit, record)
    end)

    describe("on the Series window", function()
        local record

        before_each(function()
            local books = shelf_fixture.series("Moons", 2)
            record = books[1]
            record.path = file("series.epub")
            shelf_fixture.install(books)
        end)

        it("opens the book sheet over one series for a book held there", function()
            local screen = shelf_fixture.show({ kind = "series", name = "Moons" })
            local SeriesScreen = package.loaded["series_screen"]
            local hit = SeriesScreen.hit(centre(screen.rows[1].rect))
            assert.same({ kind = "book", record = record }, hit)
            assert_book_sheet(screen, hit, record)
        end)

        it("opens nothing for a series row, empty space or no hit", function()
            local screen = shelf_fixture.show()
            local SeriesScreen = package.loaded["series_screen"]
            local series = SeriesScreen.hit(centre(screen.rows[1].rect))
            assert.equals("series", series.kind)
            local open_record = spy.on(package.loaded["book_sheet"], "open_record")
            for _, hit in ipairs({ series, { kind = "empty" } }) do
                LibrarySheets.hold(screen, hit, earlier())
                assert.is_nil(Sheet.shown)
                assert.equals(screen, harness.top())
            end
            LibrarySheets.hold(screen, nil, earlier())
            assert.is_nil(Sheet.shown)
            assert.spy(open_record).was_not_called()
            harness.tick(3)
            assert.same({}, settled)
        end)
    end)

    describe("on the Authors window", function()
        local record

        before_each(function()
            record = shelf_fixture.book("Held", { authors = { "Ann Author" } })
            record.path = file("authors.epub")
            shelf_fixture.install({ record })
        end)

        it("opens the book sheet over one author for a book held there", function()
            local screen = shelf_fixture.show_authors({ kind = "author", name = "Ann Author" })
            local AuthorsScreen = package.loaded["authors_screen"]
            local hit = AuthorsScreen.hit(centre(screen.tiles[1].rect))
            assert.same({ kind = "book", record = record }, hit)
            assert_book_sheet(screen, hit, record)
        end)

        it("opens nothing for an author row or empty space", function()
            local screen = shelf_fixture.show_authors()
            local AuthorsScreen = package.loaded["authors_screen"]
            local author = AuthorsScreen.hit(centre(screen.rows[1].rect))
            assert.equals("author", author.kind)
            local open_record = spy.on(package.loaded["book_sheet"], "open_record")
            for _, hit in ipairs({ author, { kind = "empty" } }) do
                LibrarySheets.hold(screen, hit, earlier())
                assert.is_nil(Sheet.shown)
                assert.equals(screen, harness.top())
            end
            assert.spy(open_record).was_not_called()
            harness.tick(3)
            assert.same({}, settled)
        end)
    end)
end)
