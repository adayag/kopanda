-- The library's sort and status pickers (cover-grid C10, "The pickers"): a tap on a picker in the
-- header opens its sheet over the library, the current choice selected; a tap on a row stores the
-- choice for this folder alone, closes the sheet and shows the folder's first page under it; a
-- sheet's failure closes the library, not the home; the sheet goes with the library.
describe("the library's pickers", function()
    local harness = require("plugin_harness")
    local fixture = require("library_fixture")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Home, Library, LibraryOrder, Settings, Sheet, State

    local ROOT = fixture.ROOT
    local SUB = fixture.folder("Sci-fi")

    -- The root: the folder and eight books whose authors run against their titles (Book 01 by
    -- "Author Y", Book 08 by "Author R"), two pages; Book 03 finished, Book 05 reading.
    local function install()
        local books = fixture.books(8)
        for i, book in ipairs(books) do
            book.authors = { "Author " .. string.char(string.byte("Z") - i) }
        end
        fixture.install({
            [ROOT] = { books = books, folders = { SUB } },
            [SUB.path] = { books = fixture.books(2, SUB.path) },
        }, {
            [books[3].id] = { status = "complete" },
            [books[5].id] = { status = "reading", percent = 40 },
        })
    end

    local settled, listener

    before_each(function()
        harness.load()
        Home = package.loaded["home"]
        Library = package.loaded["library"]
        LibraryOrder = package.loaded["library_order"]
        Settings = package.loaded["settings"]
        Sheet = package.loaded["sheet"]
        State = package.loaded["state"]
        settled = {}
        listener = function(args)
            if args.screen == "sheet" then
                settled[#settled + 1] = args
            end
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
        install()
    end)

    after_each(function()
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        fixture.restore()
        harness.teardown()
    end)

    local function tap(x, y)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", x, y)))
    end

    local function tap_on(rect)
        tap(fixture.centre(rect))
    end

    -- The shown sheet's row labelled label.
    local function row_of(label)
        for _, place in ipairs(Sheet.shown.rows) do
            if place.row.label == label then
                return place
            end
        end
    end

    -- The shown sheet's rows as { label, sublabel, selected }.
    local function rows()
        local out = {}
        for i, place in ipairs(Sheet.shown.rows) do
            out[i] = { place.row.label, place.row.sublabel, place.row.selected == true }
        end
        return out
    end

    -- The names and titles the library's page shows, in order.
    local function page_items(library)
        local out = {}
        for i, tile in ipairs(library.tiles) do
            out[i] = tile.folder and tile.folder.name or tile.record.title
        end
        return out
    end

    local function sheets_on_stack()
        local count = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_sheet" then
                count = count + 1
            end
        end
        return count
    end

    it("open the sort sheet and the status sheet over the library, each settling once", function()
        local library = fixture.show()
        tap_on(library.header.sort.rect)
        assert.equals("sort", Sheet.shown.spec.name)
        assert.equals(Sheet.shown, harness.top())
        assert.equals(library, harness.top(2))
        harness.tick(3)
        Sheet.close()
        tap_on(library.header.status.rect)
        assert.equals("status", Sheet.shown.spec.name)
        harness.tick(3)
        assert.same({ "sort", "status" }, { settled[1].name, settled[2].name })
        assert.equals(2, #settled)
        assert.is_number(settled[1].paint_ms)
    end)

    it("head the sort sheet with the aside above Sort and Library at its right, four rows, the current selected",
        function()
            assert.is_true(LibraryOrder.choose(ROOT, "author"))
            local library = fixture.show()
            tap_on(library.header.sort.rect)
            local header = Sheet.shown.spec.header
            assert.same({ "Sort", "for this folder", true, "Library" },
                { header.heading, header.aside, header.aside_above, header.label })
            assert.same({
                { "Recent", "Last opened first", false },
                { "Title", "A to Z, ignoring “The” and “A”", false },
                { "Author", "By surname", true },
                { "Series", "Series together, in series order", false },
            }, rows())
            assert.is_true(Sheet.shown.spec.flush)
        end)

    it("head the status sheet with Show, three rows, All selected for a folder never picked", function()
        local library = fixture.show()
        tap_on(library.header.status.rect)
        local header = Sheet.shown.spec.header
        assert.same({ "Show", "for this folder", true, "Library" },
            { header.heading, header.aside, header.aside_above, header.label })
        assert.same({
            { "Reading", "Books under way", false },
            { "Finished", "Read to the end", false },
            { "All", "Every book in this folder", true },
        }, rows())
    end)

    it("store a tapped sort for this folder alone, close the sheet and show page 1 in the new order", function()
        assert.is_true(LibraryOrder.choose(ROOT, "author"))
        local library = fixture.show(ROOT, 2)
        assert.equals(2, library.page)
        tap_on(library.header.sort.rect)
        tap_on(row_of("Title").rect)
        harness.tick(2)
        assert.is_nil(Sheet.shown)
        assert.equals(0, sheets_on_stack())
        assert.equals(library, harness.top())
        assert.same({ ROOT, 1 }, { library.dir, library.page })
        assert.same({ "Sci-fi", "Book 01", "Book 02", "Book 03", "Book 04", "Book 05" }, page_items(library))
        assert.equals("title", fixture.text(library.header.sort.label):lower())
        local stored = State.get("library").folders
        assert.same({ sort = "title", status = "all" }, stored[ROOT])
        assert.is_nil(stored[SUB.path])
        assert.same({ sort = "recent", status = "all" }, LibraryOrder.choice(SUB.path))
    end)

    it("store a tapped status and show only those books from page 1", function()
        local library = fixture.show(ROOT, 2)
        tap_on(library.header.status.rect)
        tap_on(row_of("Finished").rect)
        assert.same({ ROOT, 1 }, { library.dir, library.page })
        assert.same({ "Sci-fi", "Book 03" }, page_items(library))
        assert.same({ sort = "recent", status = "finished" }, State.get("library").folders[ROOT])
    end)

    it("on the row already selected store nothing new, close the sheet and show page 1", function()
        assert.is_true(LibraryOrder.choose(ROOT, "author"))
        local before = State.get("library")
        local library = fixture.show(ROOT, 2)
        tap_on(library.header.sort.rect)
        local writes, set = 0, State.set
        State.set = function(...)
            writes = writes + 1
            return set(...)
        end
        tap_on(row_of("Author").rect)
        State.set = set
        assert.equals(0, writes)
        assert.is_nil(Sheet.shown)
        assert.same({ ROOT, 1 }, { library.dir, library.page })
        assert.same(before, State.get("library"))
    end)

    it("close the library, not the home, when a row fails, and log it", function()
        local errored = spy.on(logger, "err")
        finally(function()
            logger.err:revert()
        end)
        local library, fm = fixture.show()
        LibraryOrder.choose = function()
            error("kopanda-test: choose failed")
        end
        tap_on(library.header.sort.rect)
        tap_on(row_of("Title").rect)
        assert.is_nil(Library.shown)
        assert.is_nil(Home.shown)
        assert.equals(0, sheets_on_stack())
        assert.equals(fm, harness.top())
        local logged = false
        for _, call in ipairs(errored.calls) do
            for _, arg in ipairs(call.vals) do
                logged = logged or tostring(arg):find("kopanda-test: choose failed", 1, true) ~= nil
            end
        end
        assert.is_true(logged)
    end)

    it("close with the library when the file manager closes", function()
        local library, fm = fixture.show()
        tap_on(library.header.sort.rect)
        assert.is_not_nil(Sheet.shown)
        fm:onClose()
        harness.tick(2)
        assert.is_nil(Sheet.shown)
        assert.is_nil(Library.shown)
        assert.equals(0, sheets_on_stack())
    end)

    -- Editorial draws its pickers with no padding (GridA.dc.html:25), so each one's tap target
    -- reaches into the header's bottom padding and halfway across the gap between them.
    it("open a picker's sheet on a tap in the header's padding under it, in Editorial", function()
        assert.is_true(Settings.set("look", "editorial"))
        local library = fixture.show()
        local tokens = library.ctx.look.library.header
        local pad = library.ctx.screen:scaleBySize(tokens.padding.bottom)
        local gap = library.ctx.screen:scaleBySize(tokens.picker_gap)
        for kind, x in pairs({ sort = library.header.sort.rect.x - math.floor(gap / 2) + 1,
                status = library.header.status.rect.x + library.header.status.rect.w + math.floor(gap / 2) - 1 }) do
            local rect = library.header[kind].rect
            tap(x, rect.y + rect.h + pad - 1)
            assert.equals(kind, Sheet.shown and Sheet.shown.spec.name, kind)
            Sheet.close()
        end
        tap(library.header.sort.rect.x, library.header.sort.rect.y - pad - 1)
        assert.is_nil(Sheet.shown)
    end)
end)
