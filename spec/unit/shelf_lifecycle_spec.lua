-- The Series window's covers (series-and-authors C7, D2, "Extraction"): after its first paint it asks,
-- once per show, for every record of the library at the library grid's cover box; an arrival re-reads
-- the arrived records and rebuilds the index, and repaints only when the page shown changes (its
-- items, their order or a cover on it); closing cancels the check. These are the chrome's extraction
-- helper's cases (LibraryChrome.request_records), which the Authors window shares. BookCovers.request
-- and cancel are stubbed; Books.all and progress are the fixture's.
describe("the Series window's lifecycle", function()
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local UIManager = require("ui/uimanager")
    local BookCovers, Books, LibraryTiles, SeriesScreen

    local LIST = { kind = "list" }

    local requests, cancels

    before_each(function()
        harness.load()
        BookCovers = package.loaded["book_covers"]
        Books = package.loaded["books"]
        LibraryTiles = package.loaded["library_tiles"]
        SeriesScreen = package.loaded["series_screen"]
        requests, cancels = {}, 0
        BookCovers.request = function(records, specs, on_arrival, alive)
            requests[#requests + 1] = { records = records, specs = specs, on_arrival = on_arrival, alive = alive }
        end
        BookCovers.cancel = function()
            cancels = cancels + 1
        end
    end)

    after_each(function()
        harness.teardown()
    end)

    -- The window shown over a file manager whose home has closed, painted and settled; the home's own
    -- cover request, made before, forgotten.
    local function show(view)
        harness.show_fm()
        harness.tick(2)
        require("home").close()
        requests = {}
        local screen = SeriesScreen.show{ view = view }
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
