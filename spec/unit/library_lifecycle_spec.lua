-- The library's covers (cover-grid C9): after a page's first paint it asks for that page's covers at
-- the cover box's size, an arrival rebuilds only the arrived tiles from their re-read records without
-- re-sorting, a new page replaces the request, and closing the library cancels the check.
-- BookCovers.request and cancel are stubbed; Books.folder, progress and get are the fixture's.
describe("the library's lifecycle", function()
    local harness = require("plugin_harness")
    local fixture = require("library_fixture")
    local UIManager = require("ui/uimanager")
    local BookCovers, Books, Library

    local ROOT = fixture.ROOT

    local requests, cancels

    before_each(function()
        harness.load()
        Library = package.loaded["library"]
        BookCovers = package.loaded["book_covers"]
        Books = package.loaded["books"]
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

        it("are asked again for a new page, the last request dropped first", function()
            local books = fixture.books(14)
            fixture.install({ [ROOT] = { books = books } })
            local library = show()
            assert.equals(1, #requests)
            local cancelled = cancels
            library:go(ROOT, 2)
            assert.equals(cancelled + 1, cancels)
            harness.tick(2)
            assert.equals(2, #requests)
            assert.same(page_ids(library), ids(requests[2].records))
            assert.same({ books[7].id }, { requests[2].records[1].id })
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
end)
