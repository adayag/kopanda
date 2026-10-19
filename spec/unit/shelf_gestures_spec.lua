-- The Series and Authors windows' gestures, in the chrome's order: the nav bar's band; a tap on a series or author row,
-- a book row or tile, the back control or a pager arrow; "Under way first" and "By surname" inert, so their taps reach
-- the file manager's menu zones; a west or east swipe, but not one in the top or bottom edge band; the page keys; a
-- hold consumed; and everything else to the zones on the file manager. SeriesScreen.hit and AuthorsScreen.hit name
-- what lies under a point. KOReader's touch lock filters the windows' own zones.
local harness = require("plugin_harness")
local fixture = require("shelf_fixture")
local centre = require("library_fixture").centre
local Device = require("device")
local Event = require("ui/event")
local InputContainer = require("ui/widget/container/inputcontainer")
local Key = require("device/key")
local Screen = Device.screen
local UIManager = require("ui/uimanager")

local restores = {}

-- Replaces t[name] with a recorder of each call's arguments that then runs body, if any.
local function spy(t, name, body)
    local calls, original = {}, rawget(t, name)
    restores[#restores + 1] = function()
        t[name] = original
    end
    t[name] = function(...)
        calls[#calls + 1] = { ... }
        if body then
            return body(...)
        end
    end
    return calls
end

local function send(ges)
    UIManager:sendEvent(Event:new("Gesture", ges))
end

local function swipe(x, y, direction)
    local ges = harness.gesture("swipe", x, y)
    ges.direction = direction
    ges.distance = Screen:scaleBySize(300)
    return ges
end

local function tap_on(rect)
    send(harness.gesture("tap", centre(rect)))
end

-- A zone on the file manager over rect's ratios, as the Gestures plugin registers its corner taps
-- (plugins/gestures.koplugin/main.lua:985-990, :1287-1288), and the gestures it got.
local function bind(fm, id, ges, zone)
    local got = {}
    fm:registerTouchZones{ {
        id = id,
        ges = ges,
        screen_zone = zone,
        handler = function(g)
            got[#got + 1] = g
            return true
        end,
        overrides = ges == "swipe" and { "filemanager_swipe" } or nil,
    } }
    return got
end

local FULL = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 }

-- The calls LibrarySheets.hold, the hold's dispatch, gets.
local function dispatched()
    return spy(package.loaded["library_sheets"], "hold")
end

-- A hold on the Home column of screen's nav bar.
local function hold_bar(screen)
    local bar = screen.nav
    local column = bar.columns[1]
    send(harness.gesture("hold", bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
        bar.dimen.y + math.floor(bar.dimen.h / 2)))
end

-- Undoes the spies and the touch lock, and empties the UI.
local function reset()
    for i = #restores, 1, -1 do
        restores[i]()
    end
    restores = {}
    InputContainer:setIgnoreTouchInput(false)
    harness.teardown()
end

local LIST = { kind = "list" }
local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

-- The row of the window's page whose series or author is name, or whose book is titled name.
local function row_of(screen, name)
    for _, row in ipairs(screen.rows) do
        if (row.entry and row.entry.name or row.record.title) == name then
            return row
        end
    end
end

local function tile_of(screen, title)
    for _, tile in ipairs(screen.tiles) do
        if tile.record.title == title then
            return tile
        end
    end
end

-- Each window and what its gestures' cases differ in: its shelf, the words of the cases' names, its
-- one-entry view and how a book is found on it.
local SHELVES = {
    {
        name = "Series",
        module = "series_screen",
        Module = "SeriesScreen",
        show = fixture.show,
        -- Fourteen series of two books, "Series 01" to "Series 14", three pages or more; Series 01 has
        -- a third book not downloaded.
        install = function()
            local records = {}
            for i = 1, 14 do
                for _, record in ipairs(fixture.series(("Series %02d"):format(i), 2)) do
                    records[#records + 1] = record
                end
            end
            records[#records + 1] = fixture.remote("Untold", { series = "Series 01", series_index = 3 })
            return fixture.install(records)
        end,
        where = "series",
        one = "series",
        a_row = "a series row",
        its = "its",
        label = "Under way first",
        a_book = "a downloaded book",
        detail = { kind = "series", name = "Series 01" },
        -- The detail view's first page after a tap on the list's first row.
        first_page = function(screen)
            assert.same({ "Series 01 1", "Series 01 2", "Untold" }, fixture.names(screen))
        end,
        books = { "Series 01 1", "Series 01 2" },
        -- The book a hold in the detail view lands on: the first row, the marked next-unread one.
        held = "Series 01 1",
        book_of = row_of,
        -- The list's row whose foot has empty space below it.
        below = function(screen)
            return screen.rows[1]
        end,
    },
    {
        name = "Authors",
        module = "authors_screen",
        Module = "AuthorsScreen",
        show = fixture.show_authors,
        -- Thirty authors of one book each, named Ann with a letter and a number, two pages or more; and Jo Grid's seven
        -- books, the first not downloaded (in a series, so first in its order).
        install = function()
            local records = {}
            for i = 1, 30 do
                local letter = LETTERS:sub((i - 1) % 26 + 1, (i - 1) % 26 + 1)
                records[i] = fixture.book(("Book %02d"):format(i),
                    { authors = { ("Ann %s%02d"):format(letter, i) } })
            end
            records[#records + 1] = fixture.remote("Untold",
                { series = "Alpha", series_index = 1, authors = { "Jo Grid" } })
            for i = 1, 6 do
                records[#records + 1] = fixture.book("Grid " .. i, { authors = { "Jo Grid" } })
            end
            return fixture.install(records)
        end,
        where = "authors",
        one = "author",
        a_row = "an author row",
        its = "their",
        label = "By surname",
        a_book = "a downloaded book's tile",
        detail = { kind = "author", name = "Jo Grid" },
        first_page = function(screen)
            assert.equals("Book 01", screen.tiles[1].record.title)
        end,
        books = { "Grid 1", "Grid 2" },
        held = "Grid 2",
        book_of = tile_of,
        -- Two pages of tiles in the detail view, whose pager turns too.
        detail_pages = 2,
        below = function(screen)
            return screen.rows[#screen.rows]
        end,
    },
}

for _, w in ipairs(SHELVES) do
    describe("gestures on the " .. w.name .. " window", function()
        local NavBar, Window

        before_each(function()
            harness.load()
            NavBar = package.loaded["nav_bar"]
            Window = package.loaded[w.module]
        end)

        after_each(reset)

        it("in the nav bar's band runs the tapped tab first, with where " .. w.where, function()
            w.install()
            local screen, fm = w.show()
            local got = bind(fm, "kopanda_spec_bar_tap", "tap", FULL)
            local runs = spy(NavBar, "run")
            local bar = screen.nav
            local column = bar.columns[5]
            send(harness.gesture("tap", bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
                bar.dimen.y + math.floor(bar.dimen.h / 2)))
            assert.same({ { "settings", w.where } }, runs)
            assert.same({}, got)
            assert.equals(screen, harness.top())
        end)

        describe("a tap", function()
            it("on " .. w.a_row .. " shows that " .. w.one .. " at " .. w.its .. " first page", function()
                w.install()
                local screen = w.show()
                local first = screen.rows[1].entry.name
                tap_on(screen.rows[1].rect)
                assert.same({ kind = w.one, name = first }, screen.showing)
                assert.equals(1, screen.page)
                w.first_page(screen)
                assert.equals(screen, Window.shown)
            end)

            it("on the back control returns to the list at the page holding the " .. w.one, function()
                w.install()
                local screen = w.show(LIST, 2)
                local row = screen.rows[2]
                local name = row.entry.name
                tap_on(row.rect)
                assert.same({ kind = w.one, name = name }, screen.showing)
                tap_on(screen.header.back_rect)
                assert.same(LIST, screen.showing)
                assert.equals(2, screen.page)
                assert.is_not_nil(row_of(screen, name))
            end)

            it("on " .. w.a_book .. " opens it through filemanagerutil.openFile, on_open run first", function()
                w.install()
                local screen, fm = w.show(w.detail)
                local order = {}
                local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile", function(_, _, pre)
                    order[#order + 1] = "open"
                    pre()
                end)
                local returns = spy(Window, "on_open", function()
                    order[#order + 1] = "return"
                end)
                local book = w.book_of(screen, w.books[2])
                tap_on(book.rect)
                assert.equals(1, #opened)
                assert.equals(fm, opened[1][1])
                assert.equals(book.record.path, opened[1][2])
                assert.same({ { w.detail, 1 } }, returns)
                assert.same({ "open", "return" }, order)
            end)

            it("on a book not downloaded does nothing and is consumed", function()
                w.install()
                local screen, fm = w.show(w.detail)
                local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
                local got = bind(fm, "kopanda_spec_full_tap", "tap", FULL)
                tap_on(w.book_of(screen, "Untold").rect)
                assert.same({}, opened)
                assert.same({}, got)
                assert.same(w.detail, screen.showing)
                assert.equals(screen, harness.top())
            end)

            it("on " .. w.label .. " is the header's empty space and opens the file manager's menu", function()
                w.install()
                local screen, fm = w.show()
                tap_on(screen.header.right[1])
                assert.same(LIST, screen.showing)
                assert.is_not_nil(fm.menu.menu_container)
                assert.equals(fm.menu.menu_container, harness.top())
                assert.equals(screen, harness.top(2))
            end)

            it("on a live pager arrow turns the page" .. (w.detail_pages and ", in the list and one " .. w.one or "")
                .. ", and on a dead one does nothing", function()
                w.install()
                local screen = w.show()
                local pages = screen.pages
                assert.is_true(pages >= 2)
                tap_on(screen.pager.prev.rect)
                assert.equals(1, screen.page)
                for page = 2, pages do
                    tap_on(screen.pager.next.rect)
                    assert.equals(page, screen.page)
                end
                tap_on(screen.pager.next.rect)
                assert.equals(pages, screen.page)
                tap_on(screen.pager.prev.rect)
                assert.equals(pages - 1, screen.page)
                if w.detail_pages then
                    screen:go(w.detail, 1)
                    assert.equals(w.detail_pages, screen.pages)
                    tap_on(screen.pager.next.rect)
                    assert.same({ w.detail, 2 }, { screen.showing, screen.page })
                    tap_on(screen.pager.next.rect)
                    assert.equals(2, screen.page)
                    tap_on(screen.pager.prev.rect)
                    assert.equals(1, screen.page)
                end
            end)
        end)

        it("pages the list with a west or east swipe, without wrapping, and with the page keys", function()
            assert.is_true(Device:hasKeys())
            w.install()
            local screen = w.show()
            local size = Screen:getSize()
            local x, y = size.w / 2, size.h / 2
            send(swipe(x, y, "east"))
            assert.equals(1, screen.page)
            send(swipe(x, y, "west"))
            assert.equals(2, screen.page)
            send(swipe(x, y, "east"))
            assert.equals(1, screen.page)
            UIManager:sendEvent(Event:new("KeyPress", Key:new("RPgFwd", {})))
            assert.equals(2, screen.page)
            UIManager:sendEvent(Event:new("KeyPress", Key:new("RPgBack", {})))
            assert.equals(1, screen.page)
            UIManager:sendEvent(Event:new("KeyPress", Key:new("RPgBack", {})))
            assert.equals(1, screen.page)
        end)

        -- The fixture's books are no files, so a held book's sheet re-lists instead.
        it("runs no open on a hold, and consumes it", function()
            w.install()
            local screen = w.show()
            send(harness.gesture("hold", centre(screen.rows[1].rect)))
            assert.same(LIST, screen.showing)
            screen:go(w.detail, 1)
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
            send(harness.gesture("hold", centre(w.book_of(screen, w.books[1]).rect)))
            send(harness.gesture("hold", centre(screen.header.back_rect)))
            assert.same({}, opened)
            assert.same(w.detail, screen.showing)
            assert.equals(screen, harness.top())
        end)

        it("hands the window and what lies under a hold to the dispatch", function()
            w.install()
            local screen = w.show()
            local held = dispatched()
            local first = screen.rows[1].entry.name
            send(harness.gesture("hold", centre(screen.rows[1].rect)))
            screen:go(w.detail, 1)
            local book = w.book_of(screen, w.held)
            send(harness.gesture("hold", centre(book.rect)))
            assert.equals(2, #held)
            assert.equals(screen, held[1][1])
            assert.same({ w.one, first }, { held[1][2].kind, held[1][2].entry.name })
            assert.equals(screen, held[2][1])
            assert.same({ kind = "book", record = book.record }, held[2][2])
            assert.equals(book.record, held[2][2].record)
        end)

        it("runs no dispatch on a hold in the nav bar's band", function()
            w.install()
            local screen = w.show()
            local held = dispatched()
            hold_bar(screen)
            assert.same({}, held)
            assert.equals(screen, harness.top())
        end)

        it("lets a hold zone on the file manager that consumes the hold win over the dispatch", function()
            w.install()
            local screen, fm = w.show(w.detail)
            local got = bind(fm, "kopanda_spec_hold", "hold", FULL)
            local held = dispatched()
            send(harness.gesture("hold", centre(w.book_of(screen, w.held).rect)))
            assert.equals(1, #got)
            assert.same({}, held)
            assert.equals(screen, harness.top())
        end)

        it(w.Module .. ".hit names the " .. w.one .. ", the book or empty space under a point, and nil with none "
            .. "shown", function()
            w.install()
            assert.is_nil(Window.hit(10, 10))
            local screen = w.show()
            local row = screen.rows[1]
            assert.same({ kind = w.one, entry = row.entry }, Window.hit(row.rect.x, row.rect.y))
            assert.equals(w.one, Window.hit(row.rect.x + row.rect.w - 1, row.rect.y + row.rect.h - 1).kind)
            local below = w.below(screen)
            assert.same({ kind = "empty" }, Window.hit(below.rect.x, below.rect.y + below.rect.h))
            assert.same({ kind = "empty" }, Window.hit(centre(screen.header.rect)))
            screen:go(w.detail, 1)
            local book = w.book_of(screen, "Untold")
            assert.same({ kind = "book", record = book.record }, Window.hit(centre(book.rect)))
            assert.same({ kind = "empty" }, Window.hit(book.rect.x + book.rect.w, book.rect.y))
        end)
    end)
end

describe("gestures on the Series window", function()
    local NavBar, SeriesScreen

    before_each(function()
        harness.load()
        NavBar = package.loaded["nav_bar"]
        SeriesScreen = package.loaded["series_screen"]
    end)

    after_each(reset)

    describe("a tap", function()
        it("it doesn't take reaches a corner zone on the file manager, and one in the bar doesn't", function()
            SHELVES[1].install()
            local screen, fm = fixture.show()
            local got = bind(fm, "kopanda_spec_corner", "tap",
                { ratio_x = 7 / 8, ratio_y = 7 / 8, ratio_w = 1 / 8, ratio_h = 1 / 8 })
            local size = Screen:getSize()
            local above_bar = screen.nav.dimen.y - 2
            assert.truthy(above_bar >= size.h * 7 / 8)
            assert.same({ kind = "empty" }, SeriesScreen.hit(size.w - 2, above_bar))
            local ges = harness.gesture("tap", size.w - 2, above_bar)
            send(ges)
            assert.same({ ges }, got)
            local runs = spy(NavBar, "run")
            send(harness.gesture("tap", size.w - 2, size.h - 2))
            assert.equals(1, #got)
            assert.equals(1, #runs)
        end)
    end)

    describe("a swipe", function()
        it("west in the bottom edge band or east in the top one reaches the file manager instead", function()
            SHELVES[1].install()
            local screen, fm = fixture.show()
            local got = bind(fm, "kopanda_spec_edge_swipe", "swipe", FULL)
            local size = Screen:getSize()
            local bottom = swipe(size.w / 2, size.h * 15 / 16 + 5, "west")
            local top = swipe(size.w / 2, 3, "east")
            send(bottom)
            send(top)
            assert.equals(1, screen.page)
            assert.same({ bottom, top }, got)
        end)
    end)

    it("does nothing on a tap under KOReader's touch lock", function()
        SHELVES[1].install()
        local screen = fixture.show()
        local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
        local runs = spy(NavBar, "run")
        InputContainer:setIgnoreTouchInput(true)
        tap_on(screen.rows[1].rect)
        tap_on(screen.pager.next.rect)
        local bar = screen.nav
        send(harness.gesture("tap", bar.dimen.x + bar.dimen.w - 5, bar.dimen.y + 5))
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h / 2, "west"))
        assert.same({}, opened)
        assert.same({}, runs)
        assert.same({ LIST, 1 }, { screen.showing, screen.page })
        assert.equals(screen, harness.top())
    end)
end)
