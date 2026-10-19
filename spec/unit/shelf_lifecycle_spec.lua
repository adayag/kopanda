-- The Series and Authors windows' covers (series-and-authors C7, D2, "Extraction"): after its first
-- paint each asks, once per show, for every record of the library at the library grid's cover box; an
-- arrival re-reads the arrived records and rebuilds the index, and repaints only when the page shown
-- changes (its items, their order or a cover on it); closing cancels the check. These are the
-- chrome's extraction helper's cases (LibraryChrome.request_records), which both windows share.
-- BookCovers.request and cancel are stubbed; Books.all and progress are the fixture's.
local harness = require("plugin_harness")
local fixture = require("shelf_fixture")
local UIManager = require("ui/uimanager")

local requests, cancels

-- Loads the plugin and stubs BookCovers.request, recording each request, and BookCovers.cancel,
-- counting the cancels.
local function load()
    harness.load()
    local BookCovers = package.loaded["book_covers"]
    requests, cancels = {}, 0
    BookCovers.request = function(records, specs, on_arrival, alive)
        requests[#requests + 1] = { records = records, specs = specs, on_arrival = on_arrival, alive = alive }
    end
    BookCovers.cancel = function()
        cancels = cancels + 1
    end
end

-- The window of module shown at view over a file manager whose home has closed, painted and
-- settled; the home's own cover request, made before, forgotten.
local function show_in(module, view)
    harness.show_fm()
    harness.tick(2)
    require("home").close()
    requests = {}
    local screen = require(module).show{ view = view }
    harness.tick(2)
    return screen
end

local function ids(records)
    local out = {}
    for i, record in ipairs(records) do
        out[i] = record.id
    end
    return out
end

-- Counts UIManager:setDirty calls for widget while fn runs.
local function dirties(widget, fn)
    local n = 0
    local set_dirty = UIManager.setDirty
    UIManager.setDirty = function(manager, w, ...)
        if w == widget then
            n = n + 1
        end
        return set_dirty(manager, w, ...)
    end
    local ok, err = pcall(fn)
    UIManager.setDirty = set_dirty
    assert.is_true(ok, tostring(err))
    return n
end

-- A copy of record with fields over it, as Books.get gives an arrival's re-read record.
local function changed(record, fields)
    local fresh = {}
    for k, v in pairs(record) do
        fresh[k] = v
    end
    for k, v in pairs(fields) do
        fresh[k] = v
    end
    return fresh
end

-- Books.get re-reads record as changed by fields, and nothing else; returns the copy and the ids
-- Books.get was asked for.
local function reread(record, fields)
    local fresh, got = changed(record, fields), {}
    package.loaded["books"].get = function(id)
        got[#got + 1] = id
        return id == fresh.id and fresh or nil
    end
    return fresh, got
end

local function titles(tiles)
    local out = {}
    for i, tile in ipairs(tiles) do
        out[i] = tile.record.title
    end
    return out
end

-- Each window and what its cases differ in: its shelf, the views shown, the change an arrival
-- brings and the words the header counts in.
local SHELVES = {
    {
        name = "Series",
        one = "series",
        module = "series_screen",
        -- Seven series of two books, more than one page, then a book in no series.
        shelf = function()
            local records = {}
            for i = 1, 7 do
                for _, record in ipairs(fixture.series(("Series %02d"):format(i), 2)) do
                    records[#records + 1] = record
                end
            end
            records[#records + 1] = fixture.book("Loose")
            return records
        end,
        detail = { kind = "series", name = "Series 01" },
        -- The shelf's last book joins a series that sorts first, and the list leads with it.
        joins = {
            fields = { series = "Aardvark Tales", series_index = 1 },
            first = "Aardvark Tales",
            check = function(screen, fresh)
                assert.equals(fresh, screen.rows[1].entry.books[1])
            end,
        },
        -- Series 03's two books share a page; the shelf's first book is another series'.
        one_page = {
            view = { kind = "series", name = "Series 03" },
            off = function(records)
                return { records[1] }
            end,
            on = function(records)
                return records[6]
            end,
        },
        -- Five series rows fill a page here, so the shelf's seven take two pages, the second with
        -- room: the loose book's new series lands off the page shown.
        list_count = {
            records = function(shelf)
                return shelf, shelf[#shelf]
            end,
            fields = { series = "Zebra Tales", series_index = 1 },
            pages = 2,
            before = "7 series",
            after = "8 series",
        },
        -- Three book rows fill a page here, so four books take two pages and a fifth fits the second.
        one_count = {
            records = function()
                local records = fixture.series("Long", 4)
                records[#records + 1] = fixture.book("Loose", { authors = { "Ann Author" } })
                return records, records[#records]
            end,
            view = { kind = "series", name = "Long" },
            shown = function(screen)
                return fixture.names(screen)
            end,
            first_page = { "Long 1", "Long 2", "Long 3" },
            fields = { series = "Long", series_index = 5 },
            before = "Ann Author, 4 books",
            after = "Ann Author, 5 books",
        },
    },
    {
        name = "Authors",
        one = "author",
        module = "authors_screen",
        -- Thirty authors of one book each, "Ann B01" to "Ann B30", more than one page; Bo Many's eight
        -- books, two pages of tiles; then a book with no author.
        shelf = function()
            local records = {}
            for i = 1, 30 do
                records[i] = fixture.book(("Book %02d"):format(i), { authors = { ("Ann B%02d"):format(i) } })
            end
            for i = 1, 8 do
                records[#records + 1] = fixture.book("Many " .. i, { authors = { "Bo Many" } })
            end
            records[#records + 1] = fixture.book("Anonymous")
            return records
        end,
        detail = { kind = "author", name = "Bo Many" },
        -- The shelf's anonymous book gains an author who sorts first, under the letter A.
        joins = {
            fields = { authors = { "Ada Aardvark" } },
            first = "Ada Aardvark",
            check = function(screen)
                assert.equals("A", screen.groups[1].letter)
            end,
        },
        -- Bo Many's six tiles on the first page; Many 8 on the second, and another author's book.
        one_page = {
            view = { kind = "author", name = "Bo Many" },
            off = function(records, screen)
                assert.equals(6, #screen.tiles)
                for _, record in ipairs(records) do
                    if record.title == "Many 8" then
                        return { record, records[1] }
                    end
                end
            end,
            on = function(_, screen)
                return screen.tiles[1].record
            end,
        },
        -- Twenty-five authors take more than a page; the anonymous book's new author sorts after them.
        list_count = {
            records = function()
                local records = {}
                for i = 1, 25 do
                    records[i] = fixture.book(("Book %02d"):format(i), { authors = { ("Ann B%02d"):format(i) } })
                end
                records[#records + 1] = fixture.book("Anonymous")
                return records, records[#records]
            end,
            fields = { authors = { "Ann B99" } },
            after = "^26 authors",
        },
        -- Bo Many's eight books take two pages of tiles; a ninth fits the second.
        one_count = {
            records = function()
                local records = {}
                for i = 1, 8 do
                    records[i] = fixture.book("Many " .. i, { authors = { "Bo Many" } })
                end
                records[#records + 1] = fixture.book("Zed")
                return records, records[#records]
            end,
            view = { kind = "author", name = "Bo Many" },
            shown = function(screen)
                return titles(screen.tiles)
            end,
            fields = { authors = { "Bo Many" } },
            after = "^9 books$",
        },
    },
}

local LIST = { kind = "list" }
local text_of = require("library_fixture").text

-- The header's aside as it reads, matched against a row's expected words: exactly, or as a
-- lowercase pattern when it starts with "^".
local function assert_aside(screen, expected)
    local aside = text_of(screen.header.aside)
    if expected:sub(1, 1) == "^" then
        assert.matches(expected, aside:lower())
    else
        assert.equals(expected, aside)
    end
end

for _, w in ipairs(SHELVES) do
    describe("the " .. w.name .. " window's lifecycle", function()
        local Window

        before_each(function()
            load()
            Window = package.loaded[w.module]
        end)

        after_each(function()
            harness.teardown()
        end)

        local function show(view)
            return show_in(w.module, view)
        end

        it("asks for every record at the library grid's cover box after the first paint, once per show", function()
            local records = w.shelf()
            fixture.install(records)
            harness.show_fm()
            harness.tick(2)
            require("home").close()
            requests = {}
            local screen = Window.show{}
            assert.same({}, requests)
            harness.tick(2)
            assert.equals(1, #requests)
            local box = package.loaded["library_tiles"].geometry(screen.dimen.w, screen.ctx)
            assert.same(ids(records), ids(requests[1].records))
            assert.same({ max_cover_w = box.cover_w, max_cover_h = box.cover_h }, requests[1].specs)
            assert.is_true(requests[1].alive())
            screen:go(LIST, 2)
            harness.tick(2)
            screen:go(w.detail, 1)
            harness.tick(2)
            assert.equals(1, #requests)
            Window.close()
            show()
            assert.equals(1, #requests, "a new show asks again")
        end)

        it("adds to the list the " .. w.one .. " an arrival gives a book, and repaints", function()
            local records = w.shelf()
            fixture.install(records)
            local screen = show()
            local book = records[#records]
            local fresh, got = reread(book, w.joins.fields)
            local n = dirties(screen, function()
                requests[1].on_arrival({ book })
            end)
            assert.same({ book.id }, got)
            assert.equals(w.joins.first, screen.rows[1].entry.name)
            w.joins.check(screen, fresh)
            assert.is_true(n > 0)
            -- The window keeps the re-read record for its next build.
            screen:go(LIST, 1)
            assert.equals(w.joins.first, screen.rows[1].entry.name)
        end)

        it("repaints one " .. w.one .. " for an arrival of a book on its page, and not for one off it", function()
            local records = w.shelf()
            fixture.install(records)
            local screen = show(w.one_page.view)
            local n = dirties(screen, function()
                requests[1].on_arrival(w.one_page.off(records, screen))
            end)
            assert.equals(0, n)
            n = dirties(screen, function()
                requests[1].on_arrival({ w.one_page.on(records, screen) })
            end)
            assert.is_true(n > 0)
        end)

        it("repaints the list for an arrival that changes only the header's count", function()
            local records, book = w.list_count.records(w.shelf())
            fixture.install(records)
            local screen = show()
            local pages, shown = screen.pages, fixture.names(screen)
            assert.is_true(pages > 1)
            if w.list_count.pages then
                assert.equals(w.list_count.pages, pages)
            end
            if w.list_count.before then
                assert_aside(screen, w.list_count.before)
            end
            reread(book, w.list_count.fields)
            local n = dirties(screen, function()
                requests[1].on_arrival({ book })
            end)
            assert.equals(pages, screen.pages)
            assert.same(shown, fixture.names(screen))
            assert.is_true(n > 0)
            assert_aside(screen, w.list_count.after)
        end)

        it("repaints one " .. w.one .. " for an arrival that changes only the header's count", function()
            local case = w.one_count
            local records, book = case.records()
            fixture.install(records)
            local screen = show(case.view)
            local shown = case.shown(screen)
            if case.first_page then
                assert.same(case.first_page, shown)
            end
            assert.equals(2, screen.pages)
            if case.before then
                assert_aside(screen, case.before)
            end
            reread(book, case.fields)
            local n = dirties(screen, function()
                requests[1].on_arrival({ book })
            end)
            assert.equals(2, screen.pages)
            assert.same(shown, case.shown(screen))
            assert.is_true(n > 0)
            assert_aside(screen, case.after)
        end)

        it("is no longer checked once the window closes", function()
            fixture.install(w.shelf())
            local screen = show()
            local alive = requests[1].alive
            local cancelled = cancels
            Window.close()
            assert.equals(cancelled + 1, cancels)
            assert.is_false(alive())
            assert.is_nil(Window.shown)
            assert.is_false(UIManager:isWidgetShown(screen))
            local n = dirties(screen, function()
                requests[1].on_arrival({ screen.records[1] })
            end)
            assert.equals(0, n)
        end)
    end)
end

describe("the Series window's lifecycle", function()
    before_each(function()
        load()
    end)

    after_each(function()
        harness.teardown()
    end)

    it("repaints for an arrival whose cover the page draws, and leaves it clean for one it doesn't", function()
        local records = SHELVES[1].shelf()
        fixture.install(records)
        local screen = show_in("series_screen")
        local shown = screen.rows[1].entry.books[1]
        local frame = screen[1]
        local n = dirties(screen, function()
            requests[1].on_arrival({ records[#records], records[#records - 2] })
        end)
        assert.equals(0, n, "an arrival off the page leaves the window clean")
        assert.equals(frame, screen[1])
        n = dirties(screen, function()
            requests[1].on_arrival({ shown })
        end)
        assert.is_true(n > 0, "an arrival on the page repaints it")
        assert.is_not.equals(frame, screen[1])
    end)

    it("repaints the list's under-way count for a series that starts off the page shown", function()
        local records = SHELVES[1].shelf()
        local progress = {}
        fixture.install(records, progress)
        local screen = show_in("series_screen", LIST)
        screen:go(LIST, 2)
        harness.tick(2)
        local before = fixture.names(screen)
        assert.same({ "Series 06", "Series 07" }, before)
        assert.equals("7 series", text_of(screen.header.aside))
        local started = records[5]
        assert.equals("Series 03", started.series)
        progress[started.id] = { status = "reading" }
        local n = dirties(screen, function()
            requests[1].on_arrival({ started })
        end)
        assert.same(before, fixture.names(screen))
        assert.equals(2, screen.pages)
        assert.is_true(n > 0)
        assert.equals("7 series, 1 under way", text_of(screen.header.aside))
    end)
end)

describe("the Authors window's lifecycle", function()
    before_each(function()
        load()
    end)

    after_each(function()
        harness.teardown()
    end)

    it("repaints the list for an arrival that changes an author's count on the page", function()
        local records = SHELVES[2].shelf()
        fixture.install(records)
        local screen = show_in("authors_screen")
        local anonymous = records[#records]
        reread(anonymous, { authors = { "Ann B01" } })
        assert.equals(1, screen.rows[1].entry.count)
        local n = dirties(screen, function()
            requests[1].on_arrival({ anonymous })
        end)
        assert.is_true(n > 0)
        assert.same({ "Ann B01", 2 }, { screen.rows[1].entry.name, screen.rows[1].entry.count })
    end)

    it("leaves the list clean for an arrival that changes no row", function()
        local records = SHELVES[2].shelf()
        fixture.install(records)
        local screen = show_in("authors_screen")
        local frame = screen[1]
        local n = dirties(screen, function()
            requests[1].on_arrival({ records[1], records[#records] })
        end)
        assert.equals(0, n)
        assert.equals(frame, screen[1])
    end)
end)

-- series-and-authors C8, D6, D7, D17, D18, D23: the ways into the two windows and the return after a
-- book opened from one closes. KOReader's open is stubbed at filemanagerutil.openFile; a case then
-- does what an open that goes ahead does: the pre-callback (filemanagerutil.lua:500-502), the file
-- manager closing for the reader (filemanager.lua:842-849), a real reader closed
-- (readerui.lua:870-893) and a new file manager shown (readerui.lua:581-596), as
-- library_lifecycle_spec.lua drives the library's and prebuild_spec.lua the home's.
describe("the Series and Authors windows' routing", function()
    local Event = require("ui/event")
    local ffiutil = require("ffi/util")
    local library_fixture = require("library_fixture")
    local AuthorsScreen, Home, LauncherEntries, Library, NavBar, SeriesScreen
    local util, real_open, opened, progress, records, signals, listener

    local BOOK = harness.library .. "/frankenstein.epub"
    local ID = "file:" .. ffiutil.realpath(BOOK)
    local NAMES = { kopanda_home = true, kopanda_library = true, kopanda_series = true, kopanda_authors = true }

    -- Each window, the view and page its real book (BOOK) shows at, the book's row or tile there,
    -- whether that draws progress, and a change of the library that takes the view away.
    local WINDOWS = {
        {
            name = "series",
            module = "series_screen",
            view = { kind = "series", name = "Gothic" },
            page = 3,
            item = function(screen)
                for _, row in ipairs(screen.rows) do
                    if row.record and row.record.id == ID then
                        return row
                    end
                end
            end,
            progressed = function(item)
                return item.widget.bar ~= nil
            end,
            rename = function()
                for i, record in ipairs(records) do
                    if record.series == "Gothic" then
                        records[i] = changed(record, { series = "Gothic Tales" })
                    end
                end
            end,
        },
        {
            name = "authors",
            module = "authors_screen",
            view = { kind = "author", name = "Mary Shelley" },
            page = 2,
            item = function(screen)
                for _, tile in ipairs(screen.tiles) do
                    if tile.record.id == ID then
                        return tile
                    end
                end
            end,
            progressed = function(item)
                return item.widget.strip ~= nil
            end,
            rename = function()
                for i, record in ipairs(records) do
                    if record.authors[1] == "Mary Shelley" then
                        records[i] = changed(record, { authors = { "Mary W. Shelley" } })
                    end
                end
            end,
        },
    }

    before_each(function()
        load()
        AuthorsScreen = package.loaded["authors_screen"]
        Home = package.loaded["home"]
        LauncherEntries = package.loaded["launcher_entries"]
        Library = package.loaded["library"]
        NavBar = package.loaded["nav_bar"]
        SeriesScreen = package.loaded["series_screen"]
        util = require("apps/filemanager/filemanagerutil")
        real_open = util.openFile
        opened = nil
        util.openFile = function(ui, file, pre)
            opened = { ui = ui, file = file, pre = pre }
        end
        -- Gothic: six spec books and the real one at index 7, all Mary Shelley's: one series' page 3
        -- and one author's page 2 hold it alone. Seven more series and thirty more authors give each
        -- list more than one page.
        records = fixture.series("Gothic", 6, "Mary Shelley")
        records[#records + 1] = { id = ID, path = BOOK, title = "Frankenstein", series = "Gothic", series_index = 7,
            authors = { "Mary Shelley" } }
        for i = 1, 7 do
            for _, record in ipairs(fixture.series(("Series %02d"):format(i), 2)) do
                records[#records + 1] = record
            end
        end
        for i = 1, 30 do
            records[#records + 1] = fixture.book(("Book %02d"):format(i), { authors = { ("Ann B%02d"):format(i) } })
        end
        progress = { [ID] = { status = "new" } }
        -- The library's root lists the real book too; the shelf fixture's progress is installed last.
        library_fixture.install({ [library_fixture.ROOT] = { books = { library_fixture.book("Alpha"),
            { id = ID, path = BOOK, title = "Frankenstein", authors = {} } } } })
        fixture.install(records, progress)
        signals = {}
        listener = function(args)
            signals[#signals + 1] = args
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
    end)

    after_each(function()
        util.openFile = real_open
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        library_fixture.restore()
        harness.teardown()
    end)

    -- KoPanda's windows on the stack, top first.
    local function kopanda_windows()
        local out = {}
        for _, widget in ipairs(harness.stack()) do
            if NAMES[widget.name] then
                out[#out + 1] = widget
            end
        end
        return out
    end

    -- The settled signals for screen since the last reset.
    local function settled(screen)
        local out = {}
        for _, args in ipairs(signals) do
            if args.screen == screen then
                out[#out + 1] = args
            end
        end
        return out
    end

    local function tap_on(rect)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", library_fixture.centre(rect))))
    end

    describe("entry points", function()
        local TARGETS = {
            { target = "series", module = "series_screen", other = "authors_screen" },
            { target = "authors", module = "authors_screen", other = "series_screen" },
        }
        local ORIGINS = {
            { "the home", function()
                assert.is_not_nil(Home.shown)
            end },
            { "the file browser", function()
                Home.close()
            end },
            { "the library", function()
                Home.close()
                assert.is_not_nil(Library.show{})
                harness.tick(2)
            end },
            { "the other window at its list's page 2", function(case)
                Home.close()
                local other = require(case.other).show{ view = LIST, page = 2 }
                assert.equals(2, other.page)
                harness.tick(2)
            end },
        }
        for _, case in ipairs(TARGETS) do
            for _, origin in ipairs(ORIGINS) do
                it("the " .. case.target .. " target from " .. origin[1] .. " leaves one KoPanda window up, at "
                    .. "its list's first page", function()
                        local fm = harness.show_fm()
                        harness.tick(2)
                        origin[2](case)
                        LauncherEntries.run({ kind = "kopanda", target = case.target }, {})
                        local shown = require(case.module).shown
                        assert.is_not_nil(shown)
                        assert.equals(shown, harness.top())
                        assert.equals(fm, harness.top(2))
                        assert.same({ shown }, kopanda_windows())
                        assert.same({ LIST, 1 }, { shown:view(), shown.page })
                        assert.is_nil(Home.shown)
                    end)
            end
        end

        it("the Authors tab on one author goes to the list's first page in place", function()
            local screen, fm = fixture.show_authors({ kind = "author", name = "Mary Shelley" }, 2)
            assert.equals(2, screen.page)
            local shows = spy.on(UIManager, "show")
            NavBar.run("authors", "authors")
            UIManager.show:revert()
            assert.spy(shows).was_not_called()
            assert.equals(screen, AuthorsScreen.shown)
            assert.equals(screen, harness.top())
            assert.equals(fm, harness.top(2))
            assert.same({ LIST, 1 }, { screen.showing, screen.page })
        end)

        it("the Library tab on the Series window shows the library in its place", function()
            local screen, fm = fixture.show()
            NavBar.run("library", "series")
            assert.is_nil(SeriesScreen.shown)
            assert.is_false(UIManager:isWidgetShown(screen))
            assert.is_not_nil(Library.shown)
            assert.equals(Library.shown, harness.top())
            assert.equals(fm, harness.top(2))
            assert.same({ Library.shown }, kopanda_windows())
        end)

        for _, w in ipairs(WINDOWS) do
            it("the Home tab closes the " .. w.name .. " window onto the home", function()
                local screen = (w.name == "series" and fixture.show or fixture.show_authors)()
                NavBar.run("home", w.name)
                assert.is_nil(require(w.module).shown)
                assert.is_false(UIManager:isWidgetShown(screen))
                assert.equals(Home.shown, harness.top())
                assert.same({ Home.shown }, kopanda_windows())
            end)

            it("the file manager's close takes the " .. w.name .. " window with it", function()
                local screen, fm = (w.name == "series" and fixture.show or fixture.show_authors)()
                fm:onClose()
                assert.is_nil(require(w.module).shown)
                assert.is_false(UIManager:isWidgetShown(screen))
                assert.same({}, kopanda_windows())
            end)
        end
    end)

    for _, w in ipairs(WINDOWS) do
        describe("after a book opened from the " .. w.name .. " window closes", function()
            local cls

            before_each(function()
                cls = package.loaded[w.module]
            end)

            -- The window at its book's view and page over a file manager, painted and settled; the
            -- file manager.
            local function at_book()
                local fm = harness.show_fm()
                harness.tick(2)
                Home.close()
                local screen = cls.show{ view = w.view, page = w.page }
                harness.tick(2)
                assert.same({ w.view, w.page }, { screen.showing, screen.page })
                assert.is_not_nil(w.item(screen))
                signals = {}
                return screen, fm
            end

            local function tap_book(screen)
                tap_on(w.item(screen).rect)
                assert.equals(BOOK, opened.file)
            end

            local function goes_ahead(fm)
                opened.pre()
                fm:onShowingReader()
            end

            local function read_and_close(book)
                local reader = harness.open_reader(book)
                harness.tick(2)
                reader:onClose()
            end

            -- The reader saves its sidecar after CloseDocument (readerui.lua:887, then :893 through
            -- UIManager:close's FlushSettings, uimanager.lua:298); a change to the fixture's progress
            -- between the close and the file manager's Show stands in for that save.
            it("builds nothing at the close and the window once at the file manager's Show, at the same view "
                .. "and page, with the progress saved after the close", function()
                    local screen, fm = at_book()
                    tap_book(screen)
                    goes_ahead(fm)
                    assert.is_nil(cls.shown)
                    local builds = spy.on(cls, "build")
                    read_and_close()
                    assert.spy(builds).was_not_called()
                    assert.is_false(Home.just_closed)
                    assert.is_nil(cls.shown)
                    progress[ID] = { status = "reading", percent = 0.4 }
                    local new_fm = harness.show_fm()
                    local shown = cls.shown
                    assert.is_not_nil(shown)
                    assert.equals(shown, harness.top())
                    assert.equals(new_fm, harness.top(2))
                    assert.spy(builds).was_called(1)
                    assert.is_nil(package.loaded["library_chrome"].return_to)
                    harness.tick(4)
                    cls.build:revert()
                    assert.spy(builds).was_called(1)
                    assert.equals(shown, harness.top())
                    assert.is_nil(Home.shown)
                    assert.same({ shown }, kopanda_windows())
                    assert.same({ w.view, w.page }, { shown.showing, shown.page })
                    assert.is_true(w.progressed(w.item(shown)))
                    assert.equals(1, #settled(w.name))
                end)

            -- reloadDocument and switchDocument set tearing_down before onClose (readerui.lua:952, :973).
            it("builds nothing at a close with the reader tearing down, and still returns to the window", function()
                local screen, fm = at_book()
                tap_book(screen)
                goes_ahead(fm)
                local reader = harness.open_reader()
                harness.tick(2)
                local builds = spy.on(cls, "build")
                reader.tearing_down = true
                reader:onClose(false)
                cls.build:revert()
                assert.spy(builds).was_not_called()
                assert.is_false(Home.just_closed)
                read_and_close()
                harness.show_fm()
                harness.tick(2)
                assert.equals(cls.shown, harness.top())
                assert.same({ w.view, w.page }, { cls.shown.showing, cls.shown.page })
            end)

            it("after a failed open, with no book closed, shows it afresh at the same view and page", function()
                local screen, fm = at_book()
                tap_book(screen)
                goes_ahead(fm)
                harness.show_fm()
                harness.tick(2)
                local shown = cls.shown
                assert.is_not_nil(shown)
                assert.equals(shown, harness.top())
                assert.is_nil(Home.shown)
                assert.is_nil(package.loaded["library_chrome"].return_to)
                assert.same({ w.view, w.page }, { shown.showing, shown.page })
                local got = settled(w.name)
                assert.equals(1, #got)
            end)

            it("clears the return it shows: a book then opened over the window from elsewhere closes to the "
                .. "home", function()
                    local screen, fm = at_book()
                    tap_book(screen)
                    goes_ahead(fm)
                    read_and_close()
                    local new_fm = harness.show_fm()
                    harness.tick(2)
                    assert.equals(cls.shown, harness.top())
                    new_fm:onShowingReader()
                    read_and_close()
                    harness.show_fm()
                    harness.tick(2)
                    assert.is_nil(cls.shown)
                    assert.equals(Home.shown, harness.top())
                end)

            it("shows the list at its first page when the view has gone by the close", function()
                local screen, fm = at_book()
                tap_book(screen)
                goes_ahead(fm)
                w.rename()
                read_and_close()
                harness.show_fm()
                harness.tick(2)
                local shown = cls.shown
                assert.is_not_nil(shown)
                assert.equals(shown, harness.top())
                assert.same({ LIST, 1 }, { shown.showing, shown.page })
            end)

            -- The window stays up after the cancelled tap, so the file manager's drop rule keeps any
            -- return the tap recorded: only the pre-callback may record one.
            it("records no return for a cancelled open, so a book opened later over the window closes to the "
                .. "home", function()
                    local screen, fm = at_book()
                    tap_book(screen)
                    assert.is_nil(package.loaded["library_chrome"].return_to)
                    assert.equals(screen, harness.top())
                    fm:onShowingReader()
                    read_and_close()
                    harness.show_fm()
                    harness.tick(2)
                    assert.is_nil(cls.shown)
                    assert.equals(Home.shown, harness.top())
                end)

            -- An open KOReader refuses after the pre-callback ran, so the file manager never closes
            -- (readerui.lua:621-626, :671-674): the return stands while the window is up.
            it("drops the return of a refused open once the window closes, so a book then opened from the "
                .. "home closes to the home", function()
                    local screen, fm = at_book()
                    tap_book(screen)
                    opened.pre()
                    assert.is_not_nil(package.loaded["library_chrome"].return_to)
                    assert.equals(screen, harness.top())
                    NavBar.run("home", w.name)
                    assert.equals(Home.shown, harness.top())
                    fm:onShowingReader()
                    read_and_close()
                    harness.show_fm()
                    harness.tick(2)
                    assert.is_nil(cls.shown)
                    assert.equals(Home.shown, harness.top())
                end)

            it("leaves a book opened over it from elsewhere, such as History, closing to the home", function()
                local _, fm = at_book()
                fm:onShowingReader()
                read_and_close()
                harness.show_fm()
                harness.tick(2)
                assert.is_nil(cls.shown)
                assert.equals(Home.shown, harness.top())
            end)

            it("keeps the return in memory only: after a restart the file manager shows the home", function()
                local screen, fm = at_book()
                tap_book(screen)
                goes_ahead(fm)
                load()
                harness.show_fm()
                harness.tick(2)
                assert.is_nil(package.loaded[w.module].shown)
                assert.equals(package.loaded["home"].shown, harness.top())
            end)

            it("takes the return once: a book then opened from the library closes to the library", function()
                local screen, fm = at_book()
                tap_book(screen)
                goes_ahead(fm)
                read_and_close()
                local new_fm = harness.show_fm()
                harness.tick(2)
                assert.equals(cls.shown, harness.top())
                NavBar.run("library", w.name)
                local library = Library.shown
                assert.is_not_nil(library)
                local tile
                for _, t in ipairs(library.tiles) do
                    if t.record and t.record.id == ID then
                        tile = t
                    end
                end
                tap_on(tile.rect)
                goes_ahead(new_fm)
                read_and_close()
                harness.show_fm()
                harness.tick(2)
                assert.equals(Library.shown, harness.top())
                assert.is_nil(cls.shown)
                assert.same({ Library.shown }, kopanda_windows())
            end)
        end)
    end
end)
