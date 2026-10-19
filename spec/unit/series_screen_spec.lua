-- The Series window: the list's header and rows a page at a time with the pager gap; one series' header and its rows
-- in series order with the next unread marked. The cases it shares with the Authors window
-- (spec/shelf_screen_cases.lua) run here, SERIES carrying what differs. Books.all and Books.progress are stubbed with
-- records under a root that exists nowhere (spec/shelf_fixture.lua).
describe("the Series window", function()
    local cases = require("shelf_screen_cases")
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local text_of = require("library_fixture").text
    local Screen = require("device").screen
    local LibraryChrome, LibraryTiles, SeriesScreen

    before_each(function()
        harness.load()
        LibraryChrome = package.loaded["library_chrome"]
        LibraryTiles = package.loaded["library_tiles"]
        SeriesScreen = package.loaded["series_screen"]
    end)

    after_each(function()
        harness.teardown()
    end)

    local function lower(text)
        return text and text:lower()
    end

    local each_look = cases.each_look
    local LIST = cases.LIST

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

    local SERIES = {
        name = "Series",
        id = "series",
        module = "series_screen",
        Module = "SeriesScreen",
        show = fixture.show,
        -- n series of two books, the first under_way of them under way.
        shelf = function(n, under_way)
            return shelf(n, under_way or 0)
        end,
        first = "Series 01",
        detail = { kind = "series", name = "Series 01" },
        a_one = "a series",
        -- The window this one's show closes.
        before = {
            name = "the library",
            module = "library",
            show = function()
                harness.show_fm()
                harness.tick(2)
                return package.loaded["library"].show{}
            end,
        },
        -- A shelf of at least pages pages.
        paged = { n = 14, pages = 3 },
        nav = { says = "no tab lit", views = { LIST } },
        empty = { aside = "no series", note = "no books in a series yet", lists = { "rows" } },
        relist = {
            fixture.book("New", { series = "Series 02", series_index = 1 }),
            fixture.book("Newer", { series = "Series 03", series_index = 1 }),
        },
        relisted = { "Series 01", "Series 02", "Series 03" },
        -- Thirty series, three under way, and "Long", twenty books, half of them finished: each view
        -- runs to more than one page, sorts the series alone and reads progress again at a refresh.
        sorted = {
            install = function()
                local records, progress = shelf(30, 3)
                for i, record in ipairs(fixture.series("Long", 20)) do
                    records[#records + 1] = record
                    if i <= 10 then
                        progress[record.id] = { status = "complete", percent = 1 }
                    end
                end
                return records, progress
            end,
            cases = {
                { "the list", LIST, { authors = 0, series = 1 }, reads = true },
                { "one series", { kind = "series", name = "Long" }, { authors = 0, series = 1 }, reads = true },
            },
            turned = { view = LIST, items = fixture.names },
        },
    }

    describe("the window", function()
        cases.window(SERIES)

        it("reads the books and each series book's progress once per show, not again in one series", function()
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
            assert.same({}, calls.progress)
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

        cases.list(SERIES)
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
                -- The abandoned Obelisk Gate is skipped.
                assert.same({ false, false, true, false }, marked, id)
                harness.teardown()
            end)
        end)

        cases.one(SERIES)
    end)

    describe("paint", function()
        cases.paint(SERIES)

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
        cases.kept_current(SERIES)
    end)

    describe("kept sorted", function()
        cases.kept_sorted(SERIES)
    end)

    describe("the settled signal", function()
        cases.settled(SERIES)
    end)
end)
