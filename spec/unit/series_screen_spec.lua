-- The Series window (series-and-authors C4): the list's header (D10's count, "Series", "Under way
-- first"), its rows in D12's order a page at a time, the pager and its dead arrows, no tab lit; one
-- series' header (the back control, D10's aside, the name), its rows in series order with the next
-- unread marked; the empty note and a gone series (D23); the rebuild on a variant or size change;
-- the re-listing on the metadata events; and the settled signal. Books.all and Books.progress are
-- stubbed with records under a root that exists nowhere (spec/shelf_fixture.lua).
describe("the Series window", function()
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local text_of = require("library_fixture").text
    local Blitbuffer = require("ffi/blitbuffer")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local LibraryChrome, LibraryTiles, Looks, NavBar, SeriesScreen, Settings, settled_listener

    before_each(function()
        harness.load()
        LibraryChrome = package.loaded["library_chrome"]
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
        NavBar = package.loaded["nav_bar"]
        SeriesScreen = package.loaded["series_screen"]
        Settings = package.loaded["settings"]
    end)

    after_each(function()
        if settled_listener then
            UIManager.event_hook:unregister("KoPandaSettled", settled_listener)
            settled_listener = nil
        end
        harness.teardown()
    end)

    local function lower(text)
        return text and text:lower()
    end

    local function each_look(fn)
        for _, id in ipairs({ "diner", "editorial" }) do
            assert.is_true(Settings.set("look", id))
            fn(id)
        end
    end

    local LIST = { kind = "list" }

    -- n series of two books each, named "Series 01" to "Series n", the first under_way of them under
    -- way (their first book complete); returns the records and the progress.
    local function shelf(n, under_way)
        local records, progress = {}, {}
        for i = 1, n do
            local books = fixture.series(("Series %02d"):format(i), 2)
            if i <= under_way then
                progress[books[1].id] = { status = "complete", percent = 1 }
            end
            for _, record in ipairs(books) do
                records[#records + 1] = record
            end
        end
        return records, progress
    end

    describe("the window", function()
        it("shows full-screen over the file manager as SeriesScreen.shown, and closes", function()
            fixture.install(shelf(2, 0))
            local screen, fm = fixture.show()
            assert.equals("kopanda_series", screen.name)
            assert.is_true(screen.covers_fullscreen)
            assert.equals(screen, SeriesScreen.shown)
            assert.equals(fm, harness.top(2))
            SeriesScreen.close()
            assert.is_nil(SeriesScreen.shown)
            assert.equals(fm, harness.top())
        end)

        it("closes the library before showing, one window at a time", function()
            fixture.install(shelf(2, 0))
            harness.show_fm()
            harness.tick(2)
            local Library = package.loaded["library"]
            local library = Library.show{}
            assert.is_not_nil(library)
            local screen = SeriesScreen.show{}
            assert.is_nil(Library.shown)
            assert.is_false(UIManager:isWidgetShown(library))
            assert.equals(screen, harness.top())
        end)

        it("reads the books once per show and each series book's progress once per build", function()
            local records, progress = shelf(3, 1)
            records[#records + 1] = fixture.book("Loose")
            local calls = fixture.install(records, progress)
            local screen = fixture.show()
            assert.equals(1, calls.all)
            assert.equals(6, #calls.progress)
            local seen = {}
            for _, id in ipairs(calls.progress) do
                assert.is_nil(seen[id], id .. " read twice")
                seen[id] = true
            end
            assert.is_nil(seen[records[#records].id], "a book in no series is not read")
            calls.progress = {}
            screen:go({ kind = "series", name = "Series 01" }, 1)
            assert.equals(1, calls.all)
            assert.equals(6, #calls.progress)
        end)
    end)

    describe("the list", function()
        it("counts the series and those under way in each look's words, over Series and Under way first",
            function()
            local wanted = {
                diner = { "no series", "1 series", "12 series", "12 series, 3 under way" },
                editorial = { "no series", "1 series", "12 series", "12 series · 3 under way" },
            }
            each_look(function(id)
                for i, case in ipairs({ { 0, 0 }, { 1, 0 }, { 12, 0 }, { 12, 3 } }) do
                    fixture.install(shelf(case[1], case[2]))
                    local screen = fixture.show()
                    local header = screen.header
                    assert.equals(wanted[id][i], lower(text_of(header.aside)), id .. " case " .. i)
                    assert.equals("series", lower(text_of(header.title)), id)
                    assert.equals("under way first", lower(text_of(header.label)), id)
                    assert.is_nil(header.back_rect, id)
                    assert.equals(LibraryTiles.header_height(screen.ctx), header.rect.h, id)
                    harness.teardown()
                end
            end)
        end)

        it("lays the rows in D12's order a page at a time, as many as fit, the rest on the next page", function()
            local records, progress = {}, {}
            local function add(name, status)
                local books = fixture.series(name, 2)
                if status then
                    progress[books[1].id] = { status = status, percent = 0.5 }
                    if status == "complete" then
                        progress[books[2].id] = { status = "complete", percent = 1 }
                    end
                end
                for _, record in ipairs(books) do
                    records[#records + 1] = record
                end
            end
            add("Zeta")
            add("The Murderbot Diaries", "complete")
            add("Wayfarers", "reading")
            add("A Song of Ice")
            add("The Expanse", "reading")
            add("Discworld")
            add("Earthsea", "reading")
            fixture.install(records, progress)
            local wanted = { "Earthsea", "The Expanse", "Wayfarers", "Discworld", "The Murderbot Diaries",
                "A Song of Ice", "Zeta" }
            each_look(function(id)
                local screen = fixture.show()
                local shelf_tokens = screen.ctx.look.shelf
                local per_page = #screen.rows
                assert.is_true(screen.pages >= 2, id)
                local got = {}
                for page = 1, screen.pages do
                    screen:go(LIST, page)
                    if page < screen.pages then
                        assert.equals(per_page, #screen.rows, id .. " page " .. page)
                    end
                    local x = Screen:scaleBySize(shelf_tokens.list.side)
                    local y = screen.header.rect.h + Screen:scaleBySize(shelf_tokens.list.padding_top)
                    for _, row in ipairs(screen.rows) do
                        got[#got + 1] = row.entry.name
                        assert.same({ x, y, Screen:getWidth() - 2 * x }, { row.rect.x, row.rect.y, row.rect.w }, id)
                        assert.equals(row.widget:getSize().h, row.rect.h, id)
                        y = y + row.rect.h + Screen:scaleBySize(shelf_tokens.list.row_gap)
                    end
                    assert.is_true(y - Screen:scaleBySize(shelf_tokens.list.row_gap) <= screen.pager.prev.rect.y,
                        id .. ": the rows end above the pager")
                end
                assert.same(wanted, got, id)
                harness.teardown()
            end)
        end)

        it("labels the pager in each look's words, the first page's previous and the last's next dead", function()
            fixture.install(shelf(14, 0))
            local wanted = { diner = "page %d of %d", editorial = "%d / %d" }
            each_look(function(id)
                local screen = fixture.show()
                local pages = screen.pages
                assert.is_true(pages >= 3, id)
                for page = 1, pages do
                    screen:go(LIST, page)
                    assert.equals(wanted[id]:format(page, pages), lower(text_of(screen.pager.label)), id)
                    assert.same({ page > 1, page < pages }, { screen.pager.prev.live, screen.pager.next.live }, id)
                end
                screen:go(LIST, 99)
                assert.equals(pages, screen.page, id .. ": a page past the end is the last")
                harness.teardown()
            end)
        end)

        it("carries the nav bar at the bottom with no tab lit", function()
            fixture.install(shelf(2, 0))
            each_look(function(id)
                local screen = fixture.show()
                local nav = screen.nav
                assert.equals("series", nav.where, id)
                assert.is_nil(nav.active, id)
                assert.same({ 0, Screen:getHeight() - NavBar.height(screen.ctx.look, Screen), Screen:getWidth() },
                    { nav.dimen.x, nav.dimen.y, nav.dimen.w }, id)
                harness.teardown()
            end)
        end)

        it("shows the empty note and page 1 of 1 with no series", function()
            fixture.install({ fixture.book("Loose"), fixture.remote("Remote") })
            each_look(function(id)
                local screen = fixture.show()
                assert.equals("no series", lower(text_of(screen.header.aside)), id)
                assert.equals("no books in a series yet", lower(text_of(screen.note)), id)
                assert.same({}, screen.rows, id)
                assert.same({ 1, 1 }, { screen.page, screen.pages }, id)
                assert.same({ false, false }, { screen.pager.prev.live, screen.pager.next.live }, id)
                harness.teardown()
            end)
            fixture.install(shelf(1, 0))
            local screen = fixture.show()
            assert.is_nil(screen.note)
        end)
    end)

    describe("one series", function()
        local function broken_earth()
            local books = {
                fixture.book("The Stone Sky", { series = "The Broken Earth", series_index = 3,
                    authors = { "N. K. Jemisin" } }),
                fixture.book("The Fifth Season", { series = "The Broken Earth", series_index = 1,
                    authors = { "N. K. Jemisin" } }),
                fixture.book("The Obelisk Gate", { series = "The Broken Earth", series_index = 2,
                    authors = { "N. K. Jemisin" } }),
            }
            return books, { [books[2].id] = { status = "complete", percent = 1 },
                [books[3].id] = { status = "abandoned", percent = 0.2 } }
        end

        it("heads the series with the back control over D10's aside and the name, the detail header's height",
            function()
            local wanted = { diner = "n. k. jemisin, 3 books", editorial = "n. k. jemisin · 3 books" }
            fixture.install(broken_earth())
            each_look(function(id)
                local screen = fixture.show({ kind = "series", name = "The Broken Earth" })
                local header = screen.header
                assert.same({ kind = "series", name = "The Broken Earth" }, screen.showing, id)
                assert.equals(wanted[id], lower(text_of(header.aside)), id)
                assert.equals("the broken earth", lower(text_of(header.title)), id)
                assert.equals("series", lower(text_of(header.back_label)), id)
                assert.equals(LibraryChrome.detail_header_height(screen.ctx), header.rect.h, id)
                local back, aside_y = header.back_rect, nil
                for i, child in ipairs(screen[1][1]) do
                    if child == header.aside then
                        aside_y = screen[1][1].places[i].y
                    end
                end
                local detail = screen.ctx.look.shelf.detail
                assert.equals(Screen:scaleBySize(detail.padding.top), back.y, id)
                assert.equals(Screen:scaleBySize(detail.padding.side), back.x, id)
                assert.equals(back.y + back.h + Screen:scaleBySize(detail.back_gap), aside_y, id)
                harness.teardown()
            end)
        end)

        it("words the aside with others, with no author and for one book", function()
            local mixed = {
                fixture.book("One", { series = "Mixed", series_index = 1, authors = { "Ann Author" } }),
                fixture.book("Two", { series = "Mixed", series_index = 2, authors = { "Bea Writer" } }),
                fixture.book("Solo", { series = "Single", series_index = 1 }),
            }
            fixture.install(mixed)
            local screen = fixture.show({ kind = "series", name = "Mixed" })
            assert.equals("ann author and others, 2 books", lower(text_of(screen.header.aside)))
            screen:go({ kind = "series", name = "Single" }, 1)
            assert.equals("1 book", lower(text_of(screen.header.aside)))
        end)

        it("lists the books in series order with the next unread marked", function()
            local books, progress = broken_earth()
            books[#books + 1] = fixture.remote("Untold", { series = "The Broken Earth" })
            fixture.install(books, progress)
            each_look(function(id)
                local screen = fixture.show({ kind = "series", name = "The Broken Earth" })
                local got, marked = {}, {}
                for page = 1, screen.pages do
                    screen:go({ kind = "series", name = "The Broken Earth" }, page)
                    for _, row in ipairs(screen.rows) do
                        got[#got + 1] = row.record.title
                        marked[#marked + 1] = row.widget.marked
                    end
                end
                assert.same({ "The Fifth Season", "The Obelisk Gate", "The Stone Sky", "Untold" }, got, id)
                -- The abandoned Obelisk Gate is skipped (D3).
                assert.same({ false, false, true, false }, marked, id)
                harness.teardown()
            end)
        end)

        it("shows the list at page 1 for a series no entry has any more", function()
            fixture.install(shelf(14, 0))
            local screen = fixture.show({ kind = "series", name = "Gone" }, 3)
            assert.same(LIST, screen.showing)
            assert.equals(1, screen.page)
            assert.equals("series", lower(text_of(screen.header.title)))
            assert.equals("Series 01", screen.rows[1].entry.name)
        end)
    end)

    describe("paint", function()
        it("rebuilds before painting when the variant changed since its build", function()
            fixture.install(shelf(2, 1))
            local screen = fixture.show()
            local frame = screen[1]
            Looks.variant = function()
                return "night"
            end
            local bb = Blitbuffer.new(screen.dimen.w, screen.dimen.h, Blitbuffer.TYPE_BBRGB32)
            screen:paintTo(bb, 0, 0)
            bb:free()
            assert.equals("night", screen.ctx.variant)
            assert.is_not.equals(frame, screen[1])
            assert.equals(screen, SeriesScreen.shown)
        end)

        it("rebuilds before painting when the screen's size changed since its build", function()
            fixture.install(shelf(2, 1))
            local screen = fixture.show({ kind = "series", name = "Series 01" })
            local frame = screen[1]
            local get_size = Screen.getSize
            Screen.getSize = function()
                return Geom:new{ x = 0, y = 0, w = 800, h = 600 }
            end
            local ok, err = pcall(function()
                local bb = Blitbuffer.new(800, 600, Blitbuffer.TYPE_BBRGB32)
                screen:paintTo(bb, 0, 0)
                bb:free()
            end)
            Screen.getSize = get_size
            assert.is_true(ok, tostring(err))
            assert.same({ 800, 600 }, { screen.dimen.w, screen.dimen.h })
            assert.equals(800, screen.nav.dimen.w)
            assert.is_not.equals(frame, screen[1])
            assert.same({ kind = "series", name = "Series 01" }, screen.showing)
        end)

        -- Each list's page ends shelf.list.pager_gap above the pager at the Colorsoft, its last row's
        -- shadow inside the gap (feature "The fit"): five series rows, and three of one series' books with
        -- the marked one, its deeper shadow, last.
        it("keeps the pager gap below the last row and its shadow at the Colorsoft, in both looks", function()
            local records, progress = shelf(6, 0)
            local long = fixture.series("Long", 6)
            progress[long[1].id] = { status = "complete", percent = 1 }
            progress[long[2].id] = { status = "complete", percent = 1 }
            for _, record in ipairs(long) do
                records[#records + 1] = record
            end
            fixture.install(records, progress)
            harness.at_colorsoft(function()
                each_look(function(id)
                    local screen = SeriesScreen.show{}
                    local gap = Screen:scaleBySize(screen.ctx.look.shelf.list.pager_gap)
                    for _, case in ipairs({ { LIST, 5 }, { { kind = "series", name = "Long" }, 3 } }) do
                        screen:go(case[1], 1)
                        local where = id .. " " .. case[1].kind
                        assert.equals(case[2], #screen.rows, where)
                        local last = screen.rows[#screen.rows]
                        local foot = last.rect.y + last.rect.h + last.widget.shadow_y
                        assert.is_true(foot + gap <= screen.pager.prev.rect.y,
                            ("%s: the last row's foot %d, %d px above the pager at %d"):format(where, foot,
                                screen.pager.prev.rect.y - foot, screen.pager.prev.rect.y))
                    end
                    assert.is_true(screen.rows[3].widget.marked, id .. ": the marked book is the page's last")
                    SeriesScreen.close()
                end)
            end)
        end)

        -- Whatever room a page leaves, each list keeps the gap: on screens from 1500 to 1800 px high, a
        -- full first page's last row and its shadow end shelf.list.pager_gap above the pager.
        it("keeps the pager gap on a full page at every screen height, in both looks", function()
            local records, progress = shelf(12, 0)
            local long = fixture.series("Long", 12)
            progress[long[1].id] = { status = "complete", percent = 1 }
            for _, record in ipairs(long) do
                records[#records + 1] = record
            end
            fixture.install(records, progress)
            each_look(function(id)
                for h = 1500, 1800, 5 do
                    harness.at_screen(1264, h, function()
                        local screen = SeriesScreen.show{}
                        local gap = Screen:scaleBySize(screen.ctx.look.shelf.list.pager_gap)
                        for _, view in ipairs({ LIST, { kind = "series", name = "Long" } }) do
                            screen:go(view, 1)
                            assert.is_true(screen.pages >= 2, id)
                            local last = screen.rows[#screen.rows]
                            local foot = last.rect.y + last.rect.h + last.widget.shadow_y
                            assert.is_true(foot + gap <= screen.pager.prev.rect.y,
                                ("%s %s at %d px: %d px above the pager"):format(id, view.kind, h,
                                    screen.pager.prev.rect.y - foot))
                        end
                        SeriesScreen.close()
                    end)
                end
            end)
        end)

        -- The marked book's shadow, deeper than a row's, stays inside the gap when it ends the page: on
        -- screens from 1500 to 1800 px high, the books before page 1's last complete, so the last is the
        -- marked one.
        it("keeps the pager gap when the marked book ends a full page at every screen height, in both looks",
            function()
            local long = fixture.series("Long", 12)
            local view = { kind = "series", name = "Long" }
            each_look(function(id)
                for h = 1500, 1800 do
                    harness.at_screen(1264, h, function()
                        fixture.install(long)
                        local screen = SeriesScreen.show{ view = view }
                        local n = #screen.rows
                        SeriesScreen.close()
                        local progress = {}
                        for i = 1, n - 1 do
                            progress[long[i].id] = { status = "complete", percent = 1 }
                        end
                        fixture.install(long, progress)
                        screen = SeriesScreen.show{ view = view }
                        local where = ("%s at %d px"):format(id, h)
                        assert.equals(n, #screen.rows, where)
                        local last = screen.rows[n]
                        assert.is_true(last.widget.marked, where .. ": the marked book is the page's last")
                        local gap = Screen:scaleBySize(screen.ctx.look.shelf.list.pager_gap)
                        local foot = last.rect.y + last.rect.h + last.widget.shadow_y
                        assert.is_true(foot + gap <= screen.pager.prev.rect.y,
                            ("%s: %d px above the pager"):format(where, screen.pager.prev.rect.y - foot))
                        SeriesScreen.close()
                    end)
                end
            end)
        end)
    end)

    describe("kept current", function()
        it("re-lists the books on BookMetadataChanged and on InvalidateMetadataCache", function()
            local records = shelf(1, 0)
            fixture.install(records)
            local screen = fixture.show()
            assert.equals(1, #screen.rows)
            records[#records + 1] = fixture.book("New", { series = "Series 02", series_index = 1 })
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            assert.same({ "Series 01", "Series 02" }, fixture.names(screen))
            records[#records + 1] = fixture.book("Newer", { series = "Series 03", series_index = 1 })
            UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", records[#records].path))
            assert.same({ "Series 01", "Series 02", "Series 03" }, fixture.names(screen))
            assert.equals(screen, harness.top())
        end)
    end)

    describe("the settled signal", function()
        it("is sent once per show after its first paint, with screen series and a numeric paint_ms", function()
            local signals = {}
            settled_listener = function(args)
                signals[#signals + 1] = args
            end
            UIManager.event_hook:register("KoPandaSettled", settled_listener)
            fixture.install(shelf(14, 0))
            local screen = fixture.show()
            local function count()
                local n = 0
                for _, args in ipairs(signals) do
                    if args.screen == "series" then
                        n = n + 1
                        assert.is_number(args.paint_ms)
                    end
                end
                return n
            end
            assert.equals(1, count())
            screen:go(LIST, 2)
            harness.tick(3)
            assert.equals(1, count())
            SeriesScreen.close()
            SeriesScreen.show{}
            harness.tick(3)
            assert.equals(2, count())
        end)
    end)
end)
