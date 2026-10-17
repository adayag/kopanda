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

describe("the Series window's lifecycle", function()
    local text_of = require("library_fixture").text
    local Books, LibraryTiles, SeriesScreen

    local LIST = { kind = "list" }

    before_each(function()
        load()
        Books = package.loaded["books"]
        LibraryTiles = package.loaded["library_tiles"]
        SeriesScreen = package.loaded["series_screen"]
    end)

    after_each(function()
        harness.teardown()
    end)

    local function show(view)
        return show_in("series_screen", view)
    end

    -- Seven series of two books, more than one page, then a book in no series.
    local function shelf()
        local records = {}
        for i = 1, 7 do
            for _, record in ipairs(fixture.series(("Series %02d"):format(i), 2)) do
                records[#records + 1] = record
            end
        end
        records[#records + 1] = fixture.book("Loose")
        return records
    end

    it("asks for every record at the library grid's cover box after the first paint, once per show", function()
        local records = shelf()
        fixture.install(records)
        harness.show_fm()
        harness.tick(2)
        require("home").close()
        requests = {}
        local screen = SeriesScreen.show{}
        assert.same({}, requests)
        harness.tick(2)
        assert.equals(1, #requests)
        local box = LibraryTiles.geometry(screen.dimen.w, screen.ctx)
        assert.same(ids(records), ids(requests[1].records))
        assert.same({ max_cover_w = box.cover_w, max_cover_h = box.cover_h }, requests[1].specs)
        assert.is_true(requests[1].alive())
        screen:go(LIST, 2)
        harness.tick(2)
        screen:go({ kind = "series", name = "Series 01" }, 1)
        harness.tick(2)
        assert.equals(1, #requests)
        SeriesScreen.close()
        show()
        assert.equals(1, #requests, "a new show asks again")
    end)

    it("rebuilds the list with a series an arrival gives a book, and repaints", function()
        local records = shelf()
        fixture.install(records)
        local screen = show()
        local loose = records[#records]
        local fresh = {}
        for k, v in pairs(loose) do
            fresh[k] = v
        end
        fresh.series, fresh.series_index = "Aardvark Tales", 1
        local got = {}
        Books.get = function(id)
            got[#got + 1] = id
            return id == fresh.id and fresh or nil
        end
        local n = dirties(screen, function()
            requests[1].on_arrival({ loose })
        end)
        assert.same({ loose.id }, got)
        assert.equals("Aardvark Tales", screen.rows[1].entry.name)
        assert.equals(fresh, screen.rows[1].entry.books[1])
        assert.is_true(n > 0)
        -- The window keeps the re-read record for its next build.
        screen:go(LIST, 1)
        assert.equals("Aardvark Tales", screen.rows[1].entry.name)
    end)

    it("repaints for an arrival whose cover the page draws, and leaves it clean for one it doesn't", function()
        local records = shelf()
        fixture.install(records)
        local screen = show()
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

    it("repaints one series for an arrival of one of its books", function()
        local records = shelf()
        fixture.install(records)
        local screen = show({ kind = "series", name = "Series 03" })
        local n = dirties(screen, function()
            requests[1].on_arrival({ records[1] })
        end)
        assert.equals(0, n)
        n = dirties(screen, function()
            requests[1].on_arrival({ records[6] })
        end)
        assert.is_true(n > 0)
    end)

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

    -- Five series rows fill a page here, so shelf()'s seven take two pages, the second with room.
    it("repaints the list's count for a series an arrival adds off the page shown", function()
        local records = shelf()
        fixture.install(records)
        local screen = show()
        local before = fixture.names(screen)
        assert.equals(2, screen.pages)
        assert.equals("7 series", text_of(screen.header.aside))
        local loose = records[#records]
        records[#records] = changed(loose, { series = "Zebra Tales", series_index = 1 })
        local n = dirties(screen, function()
            requests[1].on_arrival({ loose })
        end)
        assert.same(before, fixture.names(screen))
        assert.equals(2, screen.pages)
        assert.is_true(n > 0)
        assert.equals("8 series", text_of(screen.header.aside))
    end)

    it("repaints the list's under-way count for a series that starts off the page shown", function()
        local records = shelf()
        local progress = {}
        fixture.install(records, progress)
        local screen = show(LIST)
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

    -- Three book rows fill a page here, so four books take two pages and a fifth fits the second.
    it("repaints one series' count for a book an arrival adds off the page shown", function()
        local records = fixture.series("Long", 4)
        records[#records + 1] = fixture.book("Loose", { authors = { "Ann Author" } })
        fixture.install(records)
        local screen = show({ kind = "series", name = "Long" })
        local before = fixture.names(screen)
        assert.same({ "Long 1", "Long 2", "Long 3" }, before)
        assert.equals(2, screen.pages)
        assert.equals("Ann Author, 4 books", text_of(screen.header.aside))
        local loose = records[#records]
        records[#records] = changed(loose, { series = "Long", series_index = 5 })
        local n = dirties(screen, function()
            requests[1].on_arrival({ loose })
        end)
        assert.same(before, fixture.names(screen))
        assert.equals(2, screen.pages)
        assert.is_true(n > 0)
        assert.equals("Ann Author, 5 books", text_of(screen.header.aside))
    end)

    it("is no longer checked once the window closes", function()
        fixture.install(shelf())
        local screen = show()
        local alive = requests[1].alive
        local cancelled = cancels
        SeriesScreen.close()
        assert.equals(cancelled + 1, cancels)
        assert.is_false(alive())
        assert.is_nil(SeriesScreen.shown)
        assert.is_false(UIManager:isWidgetShown(screen))
        local n = dirties(screen, function()
            requests[1].on_arrival({ screen.records[1] })
        end)
        assert.equals(0, n)
    end)
end)

describe("the Authors window's lifecycle", function()
    local AuthorsScreen, Books, LibraryTiles
    local text_of = require("library_fixture").text

    local LIST = { kind = "list" }

    before_each(function()
        load()
        AuthorsScreen = package.loaded["authors_screen"]
        Books = package.loaded["books"]
        LibraryTiles = package.loaded["library_tiles"]
    end)

    after_each(function()
        harness.teardown()
    end)

    local function show(view)
        return show_in("authors_screen", view)
    end

    -- Thirty authors of one book each, "Ann B01" to "Ann B30", more than one page; Bo Many's eight
    -- books, two pages of tiles; then a book with no author.
    local function shelf()
        local records = {}
        for i = 1, 30 do
            records[i] = fixture.book(("Book %02d"):format(i), { authors = { ("Ann B%02d"):format(i) } })
        end
        for i = 1, 8 do
            records[#records + 1] = fixture.book("Many " .. i, { authors = { "Bo Many" } })
        end
        records[#records + 1] = fixture.book("Anonymous")
        return records
    end

    it("asks for every record at the library grid's cover box after the first paint, once per show", function()
        local records = shelf()
        fixture.install(records)
        harness.show_fm()
        harness.tick(2)
        require("home").close()
        requests = {}
        local screen = AuthorsScreen.show{}
        assert.same({}, requests)
        harness.tick(2)
        assert.equals(1, #requests)
        local box = LibraryTiles.geometry(screen.dimen.w, screen.ctx)
        assert.same(ids(records), ids(requests[1].records))
        assert.same({ max_cover_w = box.cover_w, max_cover_h = box.cover_h }, requests[1].specs)
        assert.is_true(requests[1].alive())
        screen:go(LIST, 2)
        harness.tick(2)
        screen:go({ kind = "author", name = "Bo Many" }, 1)
        harness.tick(2)
        assert.equals(1, #requests)
        AuthorsScreen.close()
        show()
        assert.equals(1, #requests, "a new show asks again")
    end)

    it("adds to the list the author an arrival gives a book, and repaints", function()
        local records = shelf()
        fixture.install(records)
        local screen = show()
        local anonymous = records[#records]
        local fresh = {}
        for k, v in pairs(anonymous) do
            fresh[k] = v
        end
        fresh.authors = { "Ada Aardvark" }
        local got = {}
        Books.get = function(id)
            got[#got + 1] = id
            return id == fresh.id and fresh or nil
        end
        local n = dirties(screen, function()
            requests[1].on_arrival({ anonymous })
        end)
        assert.same({ anonymous.id }, got)
        assert.equals("Ada Aardvark", screen.rows[1].entry.name)
        assert.equals("A", screen.groups[1].letter)
        assert.is_true(n > 0)
        screen:go(LIST, 1)
        assert.equals("Ada Aardvark", screen.rows[1].entry.name)
    end)

    it("repaints the list for an arrival that changes an author's count on the page", function()
        local records = shelf()
        fixture.install(records)
        local screen = show()
        local anonymous = records[#records]
        local fresh = {}
        for k, v in pairs(anonymous) do
            fresh[k] = v
        end
        fresh.authors = { "Ann B01" }
        Books.get = function(id)
            return id == fresh.id and fresh or nil
        end
        assert.equals(1, screen.rows[1].entry.count)
        local n = dirties(screen, function()
            requests[1].on_arrival({ anonymous })
        end)
        assert.is_true(n > 0)
        assert.same({ "Ann B01", 2 }, { screen.rows[1].entry.name, screen.rows[1].entry.count })
    end)

    it("leaves the list clean for an arrival that changes no row", function()
        local records = shelf()
        fixture.install(records)
        local screen = show()
        local frame = screen[1]
        local n = dirties(screen, function()
            requests[1].on_arrival({ records[1], records[#records] })
        end)
        assert.equals(0, n)
        assert.equals(frame, screen[1])
    end)

    it("repaints one author for an arrival of a book on its page, and not for one off it", function()
        local records = shelf()
        fixture.install(records)
        local screen = show({ kind = "author", name = "Bo Many" })
        local on_page, off_page = screen.tiles[1].record, nil
        for _, record in ipairs(records) do
            if record.title == "Many 8" then
                off_page = record
            end
        end
        assert.equals(6, #screen.tiles)
        local n = dirties(screen, function()
            requests[1].on_arrival({ off_page, records[1] })
        end)
        assert.equals(0, n)
        n = dirties(screen, function()
            requests[1].on_arrival({ on_page })
        end)
        assert.is_true(n > 0)
    end)

    -- A copy of record with fields over it, as Books.get re-reads it after an arrival.
    local function reread(record, fields)
        local fresh = {}
        for k, v in pairs(record) do
            fresh[k] = v
        end
        for k, v in pairs(fields) do
            fresh[k] = v
        end
        Books.get = function(id)
            return id == fresh.id and fresh or nil
        end
    end

    local function names(rows)
        local out = {}
        for i, row in ipairs(rows) do
            out[i] = row.entry.name
        end
        return out
    end

    local function titles(tiles)
        local out = {}
        for i, tile in ipairs(tiles) do
            out[i] = tile.record.title
        end
        return out
    end

    it("repaints the list for an arrival that changes only the header's count", function()
        local records = {}
        for i = 1, 25 do
            records[i] = fixture.book(("Book %02d"):format(i), { authors = { ("Ann B%02d"):format(i) } })
        end
        local anonymous = fixture.book("Anonymous")
        records[#records + 1] = anonymous
        fixture.install(records)
        local screen = show()
        local pages, shown = screen.pages, names(screen.rows)
        assert.is_true(pages > 1)
        reread(anonymous, { authors = { "Ann B99" } })
        local n = dirties(screen, function()
            requests[1].on_arrival({ anonymous })
        end)
        assert.equals(pages, screen.pages)
        assert.same(shown, names(screen.rows))
        assert.is_true(n > 0)
        assert.matches("^26 authors", text_of(screen.header.aside):lower())
    end)

    it("repaints one author for an arrival that changes only the header's count", function()
        local records = {}
        for i = 1, 8 do
            records[i] = fixture.book("Many " .. i, { authors = { "Bo Many" } })
        end
        local zed = fixture.book("Zed")
        records[#records + 1] = zed
        fixture.install(records)
        local screen = show({ kind = "author", name = "Bo Many" })
        local shown = titles(screen.tiles)
        assert.equals(2, screen.pages)
        reread(zed, { authors = { "Bo Many" } })
        local n = dirties(screen, function()
            requests[1].on_arrival({ zed })
        end)
        assert.equals(2, screen.pages)
        assert.same(shown, titles(screen.tiles))
        assert.is_true(n > 0)
        assert.equals("9 books", text_of(screen.header.aside):lower())
    end)

    it("is no longer checked once the window closes", function()
        fixture.install(shelf())
        local screen = show()
        local alive = requests[1].alive
        local cancelled = cancels
        AuthorsScreen.close()
        assert.equals(cancelled + 1, cancels)
        assert.is_false(alive())
        assert.is_nil(AuthorsScreen.shown)
        assert.is_false(UIManager:isWidgetShown(screen))
        local n = dirties(screen, function()
            requests[1].on_arrival({ screen.records[1] })
        end)
        assert.equals(0, n)
    end)
end)
