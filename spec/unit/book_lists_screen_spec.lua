-- The History and Favorites window on the chrome: the title header with the count at the right and no back control,
-- each list's tiles a page at a time and its empty note, a book's open returning to the list, and the book sheet's
-- rows for each list. Books.all and Books.progress are stubbed with records under a root that exists nowhere
-- (spec/shelf_fixture.lua), and KOReader's two lists hold those records' paths; a hold's sheet needs a real file.
describe("the book list window", function()
    local cases = require("shelf_screen_cases")
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local text_of = require("library_fixture").text
    local Event = require("ui/event")
    local ReadCollection = require("readcollection")
    local ReadHistory = require("readhistory")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local Screen = require("device").screen
    local BookListsScreen, LibraryChrome, LibraryTiles, NavBar, ScreenRoutes, Sheet

    local HISTORY = { list = "history" }
    local FAVORITES = { list = "favorites" }
    local each_look = cases.each_look
    local real_dir = os.getenv("KO_HOME") .. "/book-list-window-books"

    local restores = {}
    local function replace(t, key, value)
        local old = t[key]
        restores[#restores + 1] = function()
            t[key] = old
        end
        t[key] = value
    end

    before_each(function()
        harness.load()
        BookListsScreen = package.loaded["book_lists_screen"]
        LibraryChrome = package.loaded["library_chrome"]
        LibraryTiles = package.loaded["library_tiles"]
        NavBar = package.loaded["nav_bar"]
        ScreenRoutes = package.loaded["screen_routes"]
        Sheet = package.loaded["sheet"]
        replace(ReadHistory, "hist", {})
        replace(ReadCollection, "coll", { favorites = {} })
    end)

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        restores = {}
        harness.teardown()
    end)

    local function lower(text)
        return text and text:lower()
    end

    -- count books in the library, in History newest first and in Favorites in order, titled "Book 1" to "Book n".
    local function books(count)
        local records = {}
        for i = 1, count do
            records[i] = fixture.book("Book " .. i)
            ReadHistory.hist[i] = { file = records[i].path, time = count - i }
            ReadCollection.coll.favorites[records[i].path] = { file = records[i].path, order = i }
        end
        return records
    end

    -- A file manager with the home closed and the window shown at view and page, painted and settled.
    local function show(view, page)
        local fm = harness.show_fm()
        harness.tick(2)
        require("home").close()
        local screen = BookListsScreen.show{ view = view, page = page }
        assert.is_not_nil(screen)
        harness.tick(2)
        assert.equals(screen, harness.top())
        return screen, fm
    end

    local function titles(screen)
        local out = {}
        for i, tile in ipairs(screen.tiles) do
            out[i] = tile.record.title
        end
        return out
    end

    local function tile_of(screen, title)
        for _, tile in ipairs(screen.tiles) do
            if tile.record.title == title then
                return tile
            end
        end
    end

    local function centre(rect)
        return { x = rect.x + math.floor(rect.w / 2), y = rect.y + math.floor(rect.h / 2) }
    end

    local function hold(screen, title)
        local at = centre(tile_of(screen, title).rect)
        return screen:onGesture(harness.gesture("hold", at.x, at.y))
    end

    local function labels()
        local out = {}
        for i, row in ipairs(Sheet.shown.spec.rows) do
            out[i] = row.label
        end
        return out
    end

    local function row_of(label)
        for _, row in ipairs(Sheet.shown.spec.rows) do
            if row.label == label then
                return row
            end
        end
    end

    -- A record with a real file, titled title, in History and in Favorites, its file's own record to the sheet.
    local function real_book(title)
        if lfs.attributes(real_dir, "mode") ~= "directory" then
            assert(lfs.mkdir(real_dir))
        end
        local path = real_dir .. "/" .. title .. ".epub"
        local f = assert(io.open(path, "wb"))
        f:write("not a real book")
        f:close()
        path = ffiutil.realpath(path)
        local record = fixture.book(title, { path = path, id = "file:" .. path })
        ReadHistory.hist[#ReadHistory.hist + 1] = { file = path, time = 1 }
        ReadCollection.coll.favorites[path] = { file = path, order = 1 }
        return record
    end

    describe("the window", function()
        it("shows full-screen over the file manager as BookListsScreen.shown, and closes", function()
            fixture.install(books(2))
            local screen, fm = show(HISTORY)
            assert.equals("kopanda_book_list", screen.name)
            assert.equals("book_list", screen.screen)
            assert.is_true(screen.covers_fullscreen)
            assert.equals(screen, BookListsScreen.shown)
            assert.same(HISTORY, screen:view())
            assert.equals(fm, harness.top(2))
            BookListsScreen.close()
            assert.is_nil(BookListsScreen.shown)
            assert.equals(fm, harness.top())
        end)

        it("shows History with no view given", function()
            fixture.install(books(1))
            harness.show_fm()
            harness.tick(2)
            assert.same(HISTORY, BookListsScreen.show{}:view())
        end)

        it("is the plugin's showBookList, which returns the window, or nil when it failed", function()
            fixture.install(books(1))
            local _, fm = show(HISTORY)
            BookListsScreen.close()
            local screen = fm.kopanda:showBookList{ view = FAVORITES }
            assert.equals(BookListsScreen.shown, screen)
            assert.same(FAVORITES, screen:view())
            BookListsScreen.close()
            replace(LibraryChrome, "books", function()
                error("no library on purpose")
            end)
            assert.is_nil(fm.kopanda:showBookList{ view = HISTORY })
            assert.is_nil(BookListsScreen.shown)
        end)
    end)

    describe("the header", function()
        it("sets the list's title with its count at the right and no back control, the title form's height",
            function()
            fixture.install(books(3))
            each_look(function(id)
                for view, title in pairs({ [HISTORY] = "History", [FAVORITES] = "Favorites" }) do
                    local screen = show(view)
                    local header = screen.header
                    assert.equals(lower(title), lower(text_of(header.title)), id)
                    assert.equals("3 books", lower(text_of(screen.count)), id)
                    assert.is_nil(header.aside, id)
                    assert.is_nil(header.back_rect, id)
                    assert.is_nil(header.title_rect, id)
                    assert.equals(LibraryTiles.header_height(screen.ctx), header.rect.h, id)
                    assert.is_true(header.right[1].x + header.right[1].w > Screen:getWidth() / 2, id)
                    harness.teardown()
                end
            end)
        end)

        it("does nothing on a tap on the title", function()
            fixture.install(books(1))
            local screen = show(HISTORY)
            assert.is_false(screen:tap(centre(screen.header.rect)))
            assert.equals(screen, BookListsScreen.shown)
        end)

        it("counts one book", function()
            fixture.install(books(1))
            assert.equals("1 book", lower(text_of(show(FAVORITES).count)))
        end)
    end)

    describe("the tiles", function()
        it("keeps History's order, a page at a time", function()
            local records = books(8)
            fixture.install(records)
            local screen = show(HISTORY)
            assert.same({ "Book 1", "Book 2", "Book 3", "Book 4", "Book 5", "Book 6" }, titles(screen))
            assert.same({ 1, 2 }, { screen.page, screen.pages })
            screen:turn(1)
            assert.same({ "Book 7", "Book 8" }, titles(screen))
            assert.is_nil(screen.note)
        end)

        it("keeps Favorites' order, which needn't be History's", function()
            local records = books(3)
            fixture.install(records)
            ReadCollection.coll.favorites[records[1].path].order = 3
            ReadCollection.coll.favorites[records[3].path].order = 1
            assert.same({ "Book 3", "Book 2", "Book 1" }, titles(show(FAVORITES)))
        end)

        it("shows Favorites by file name under a KOReader sort, which leaves the items no order", function()
            local records = books(3)
            fixture.install(records)
            replace(ReadCollection.coll_settings.favorites, "collate", "title")
            for i, record in ipairs(records) do
                local item = ReadCollection.coll.favorites[record.path]
                item.order, item.text = nil, (4 - i) .. ".epub"
            end
            assert.same({ "Book 3", "Book 2", "Book 1" }, titles(show(FAVORITES)))
        end)

        it("shows a page past the end as the last", function()
            fixture.install(books(8))
            local screen = show(HISTORY, 9)
            assert.same({ 2, 2 }, { screen.page, screen.pages })
        end)

        it("leaves out a deleted file's entry", function()
            local records = books(2)
            fixture.install(records)
            ReadHistory.hist[1].dim = true
            assert.same({ "Book 2" }, titles(show(HISTORY)))
        end)

        it("centres each list's own empty note on page 1 of 1", function()
            fixture.install({})
            each_look(function(id)
                for view, note in pairs({ [HISTORY] = "no books read yet", [FAVORITES] = "no favorites yet" }) do
                    local screen = show(view)
                    assert.equals(note, lower(text_of(screen.note)), id)
                    assert.same({}, screen.tiles, id)
                    assert.same({ 1, 1 }, { screen.page, screen.pages }, id)
                    assert.equals("no books", lower(text_of(screen.count)), id)
                    local frame, place = screen[1], nil
                    for i, child in ipairs(frame) do
                        if child == screen.note then
                            place = frame.places[i]
                        end
                    end
                    local size = screen.note:getSize()
                    local top = LibraryTiles.header_height(screen.ctx)
                        + Screen:scaleBySize(screen.ctx.look.library.grid.padding_top)
                    local below = screen.pager.prev.rect.y
                    assert.same({ math.floor((Screen:getWidth() - size.w) / 2),
                        top + math.floor((below - top - size.h) / 2) }, { place.x, place.y }, id)
                    harness.teardown()
                end
            end)
        end)

        it("carries the nav bar, History lit on History and no tab on Favorites", function()
            fixture.install(books(1))
            local screen = show(HISTORY)
            assert.equals("history", screen.nav.where)
            assert.equals("history", NavBar.TABS[screen.nav.active].id)
            screen = BookListsScreen.show{ view = FAVORITES }
            assert.equals("favorites", screen.nav.where)
            assert.is_nil(screen.nav.active)
        end)

        it("keys a page by the list, its count and the books it draws", function()
            local records = books(2)
            fixture.install(records)
            local screen = show(HISTORY)
            assert.same({ true, true }, { screen.drawn[records[1].id], screen.drawn[records[2].id] })
            assert.equals(screen.keys[2], records[1].id)
            local favorites = BookListsScreen.show{ view = FAVORITES }
            assert.is_not.equals(screen.keys[1], favorites.keys[1])
        end)
    end)

    describe("taps", function()
        it("opens a book with a file through the chrome's open", function()
            fixture.install(books(2))
            local opened = {}
            replace(LibraryChrome.Window, "open", function(_, record)
                opened[#opened + 1] = record.title
            end)
            local screen = show(FAVORITES)
            assert.is_true(screen:tap(centre(tile_of(screen, "Book 2").rect)))
            assert.same({ "Book 2" }, opened)
        end)

        it("records the list and page as the open's return", function()
            fixture.install(books(8))
            local screen = show(FAVORITES, 2)
            local util = require("apps/filemanager/filemanagerutil")
            replace(util, "openFile", function(_, _, pre)
                pre()
            end)
            screen:tap(centre(tile_of(screen, "Book 7").rect))
            assert.same({ screen = "book_list", view = FAVORITES, page = 2 }, LibraryChrome.return_to)
            LibraryChrome.return_to = nil
        end)

        -- As shelf_lifecycle_spec.lua drives the Series and Authors windows' open and close.
        it("returns to the list at its page after the book closes, reading the list afresh", function()
            fixture.install(books(8))
            local screen, fm = show(FAVORITES, 2)
            local util = require("apps/filemanager/filemanagerutil")
            local pre
            replace(util, "openFile", function(_, _, callback)
                pre = callback
            end)
            screen:tap(centre(tile_of(screen, "Book 7").rect))
            pre()
            fm:onShowingReader()
            assert.is_nil(BookListsScreen.shown)
            local reader = harness.open_reader()
            harness.tick(2)
            reader:onClose()
            harness.show_fm()
            local back = BookListsScreen.shown
            assert.is_not_nil(back)
            assert.equals(back, harness.top())
            assert.same({ FAVORITES, 2 }, { back:view(), back.page })
            assert.is_nil(LibraryChrome.return_to)
        end)

        it("drops the return of an open that never closed the file manager once the window has closed", function()
            fixture.install(books(2))
            local screen, fm = show(HISTORY)
            replace(require("apps/filemanager/filemanagerutil"), "openFile", function(_, _, pre)
                pre()
            end)
            screen:tap(centre(tile_of(screen, "Book 1").rect))
            assert.is_not_nil(LibraryChrome.return_to)
            BookListsScreen.close()
            fm:onClose()
            assert.is_nil(LibraryChrome.return_to)
        end)

        it("shows the list again at its view and page as a book status page's opener", function()
            fixture.install(books(8))
            local _, fm = show(HISTORY, 2)
            BookListsScreen.close()
            ScreenRoutes.show_opener(fm.kopanda, { screen = "book_list", view = FAVORITES, page = 2 })
            local back = BookListsScreen.shown
            assert.same({ FAVORITES, 2 }, { back:view(), back.page })
        end)
    end)

    describe("holds", function()
        it("answers book on a tile and empty elsewhere, nil with no window shown", function()
            fixture.install(books(1))
            local screen = show(HISTORY)
            local tile = tile_of(screen, "Book 1")
            local at = centre(tile.rect)
            assert.same({ kind = "book", record = tile.record }, BookListsScreen.hit(at.x, at.y))
            local header = centre(screen.header.rect)
            assert.same({ kind = "empty" }, BookListsScreen.hit(header.x, header.y))
            BookListsScreen.close()
            assert.is_nil(BookListsScreen.hit(at.x, at.y))
        end)

        it("opens nothing on empty space", function()
            fixture.install(books(1))
            local screen = show(HISTORY)
            local header = centre(screen.header.rect)
            screen:onGesture(harness.gesture("hold", header.x, header.y))
            assert.is_nil(Sheet.shown)
        end)

        it("opens the book sheet over History with Remove from history last", function()
            fixture.install({ real_book("Held") })
            local screen = show(HISTORY)
            hold(screen, "Held")
            assert.is_not_nil(Sheet.shown)
            local rows = labels()
            assert.equals("Remove from history", rows[#rows])
            assert.is_not_nil(row_of("In Favorites"))
        end)

        it("offers no Remove from history over Favorites", function()
            fixture.install({ real_book("Held") })
            local screen = show(FAVORITES)
            hold(screen, "Held")
            assert.is_not_nil(Sheet.shown)
            assert.is_nil(row_of("Remove from history"))
        end)

        it("removes the book from History on Remove from history, the window re-listed", function()
            local held, other = real_book("Held"), real_book("Other")
            fixture.install({ held, other })
            local removed = {}
            replace(ReadHistory, "removeItemByPath", function(self, path)
                removed[#removed + 1] = path
                table.remove(self.hist, 1)
            end)
            local screen = show(HISTORY)
            hold(screen, "Held")
            row_of("Remove from history").run()
            assert.same({ held.path }, removed)
            assert.same({ "Other" }, titles(screen))
            assert.equals("1 book", lower(text_of(screen.count)))
        end)

        it("takes the book off Favorites on its toggle, the window re-listed", function()
            local held, other = real_book("Held"), real_book("Other")
            ReadCollection.coll.favorites[other.path].order = 2
            fixture.install({ held, other })
            local screen = show(FAVORITES)
            hold(screen, "Held")
            row_of("In Favorites").run()
            assert.same({ "Other" }, titles(screen))
            assert.equals("1 book", lower(text_of(screen.count)))
        end)
    end)

    describe("kept current", function()
        it("reads the library once per show and a drawn book's progress once", function()
            local records = books(8)
            local calls = fixture.install(records)
            local screen = show(HISTORY)
            assert.equals(1, calls.all)
            assert.equals(6, #calls.progress)
            screen:turn(1)
            calls.progress = {}
            screen:turn(-1)
            screen:turn(1)
            assert.equals(1, calls.all)
            assert.same({}, calls.progress)
        end)

        it("asks for the covers of the list's books, none of the library's others", function()
            local records = books(1)
            records[2] = fixture.book("Not in the list")
            fixture.install(records)
            local asked = {}
            replace(package.loaded["book_covers"], "request", function(list)
                for i, record in ipairs(list) do
                    asked[i] = record.title
                end
            end)
            show(HISTORY)
            assert.same({ "Book 1" }, asked)
        end)

        it("reads the list again at refresh() and on the metadata events", function()
            local records = books(2)
            fixture.install(records)
            local screen = show(HISTORY)
            assert.equals("2 books", lower(text_of(screen.count)))
            table.remove(ReadHistory.hist, 1)
            screen:refresh()
            assert.equals("1 book", lower(text_of(screen.count)))
            table.remove(ReadHistory.hist, 1)
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            harness.tick(2)
            assert.equals("no books", lower(text_of(screen.count)))
            assert.equals(screen, harness.top())
        end)

        it("keeps the page as it was when a re-read fails", function()
            fixture.install(books(2))
            local screen = show(HISTORY)
            replace(package.loaded["book_lists"], "records", function()
                error("no list on purpose")
            end)
            screen:refresh()
            assert.same({ "Book 1", "Book 2" }, titles(screen))
        end)
    end)

    describe("the settled signal", function()
        it("is sent once per show after its first paint, with screen book_list and a numeric paint_ms", function()
            local signals = 0
            local function listener(args)
                if args.screen == "book_list" then
                    assert.is_number(args.paint_ms)
                    signals = signals + 1
                end
            end
            UIManager.event_hook:register("KoPandaSettled", listener)
            restores[#restores + 1] = function()
                UIManager.event_hook:unregister("KoPandaSettled", listener)
            end
            fixture.install(books(8))
            local screen = show(HISTORY)
            assert.equals(1, signals)
            screen:turn(1)
            harness.tick(3)
            assert.equals(1, signals)
        end)
    end)
end)
