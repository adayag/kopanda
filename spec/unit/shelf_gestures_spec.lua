-- The Series and Authors windows' gestures (series-and-authors C6, D9, D11, D17), in the chrome's
-- order: the nav bar's band; a tap on a series or author row, a book row or tile, the back control
-- or a pager arrow; "Under way first" and "By surname" inert, so their taps reach the file manager's
-- menu zones; a west or east swipe, but not one in the top or bottom edge band; the page keys; a
-- hold consumed; and everything else to the zones on the file manager. SeriesScreen.hit and
-- AuthorsScreen.hit name what lies under a point. KOReader's touch lock filters the windows' own
-- zones.
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

-- context-menu C7: the calls LibrarySheets.hold, the hold's dispatch, gets.
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

describe("gestures on the Series window", function()
    local NavBar, SeriesScreen

    local LIST = { kind = "list" }
    local REMOTE = fixture.remote("Untold", { series = "Series 01", series_index = 3 })

    -- Fourteen series of two books, "Series 01" to "Series 14", three pages or more; Series 01 has a
    -- third book not downloaded.
    local function install()
        local records = {}
        for i = 1, 14 do
            for _, record in ipairs(fixture.series(("Series %02d"):format(i), 2)) do
                records[#records + 1] = record
            end
        end
        records[#records + 1] = REMOTE
        return fixture.install(records)
    end

    before_each(function()
        harness.load()
        NavBar = package.loaded["nav_bar"]
        SeriesScreen = package.loaded["series_screen"]
    end)

    after_each(reset)

    local function row_of(screen, name)
        for _, row in ipairs(screen.rows) do
            if (row.entry and row.entry.name or row.record.title) == name then
                return row
            end
        end
    end

    it("in the nav bar's band runs the tapped tab first, with where series", function()
        install()
        local screen, fm = fixture.show()
        local got = bind(fm, "kopanda_spec_bar_tap", "tap", FULL)
        local runs = spy(NavBar, "run")
        local bar = screen.nav
        local column = bar.columns[5]
        send(harness.gesture("tap", bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
            bar.dimen.y + math.floor(bar.dimen.h / 2)))
        assert.same({ { "settings", "series" } }, runs)
        assert.same({}, got)
        assert.equals(screen, harness.top())
    end)

    describe("a tap", function()
        it("on a series row shows that series at its first page", function()
            install()
            local screen = fixture.show()
            tap_on(row_of(screen, "Series 01").rect)
            assert.same({ kind = "series", name = "Series 01" }, screen.showing)
            assert.equals(1, screen.page)
            assert.same({ "Series 01 1", "Series 01 2", "Untold" }, fixture.names(screen))
            assert.equals(screen, SeriesScreen.shown)
        end)

        it("on the back control returns to the list at the page holding the series", function()
            install()
            local screen = fixture.show(LIST, 2)
            local row = screen.rows[2]
            local name = row.entry.name
            tap_on(row.rect)
            assert.same({ kind = "series", name = name }, screen.showing)
            tap_on(screen.header.back_rect)
            assert.same(LIST, screen.showing)
            assert.equals(2, screen.page)
            assert.is_not_nil(row_of(screen, name))
        end)

        it("on a downloaded book opens it through filemanagerutil.openFile, on_open run first", function()
            install()
            local screen, fm = fixture.show({ kind = "series", name = "Series 01" })
            local order = {}
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile", function(_, _, pre)
                order[#order + 1] = "open"
                pre()
            end)
            local returns = spy(SeriesScreen, "on_open", function()
                order[#order + 1] = "return"
            end)
            local row = row_of(screen, "Series 01 2")
            tap_on(row.rect)
            assert.equals(1, #opened)
            assert.equals(fm, opened[1][1])
            assert.equals(row.record.path, opened[1][2])
            assert.same({ { { kind = "series", name = "Series 01" }, 1 } }, returns)
            assert.same({ "open", "return" }, order)
        end)

        it("on a book not downloaded does nothing and is consumed", function()
            install()
            local screen, fm = fixture.show({ kind = "series", name = "Series 01" })
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
            local got = bind(fm, "kopanda_spec_full_tap", "tap", FULL)
            tap_on(row_of(screen, "Untold").rect)
            assert.same({}, opened)
            assert.same({}, got)
            assert.same({ kind = "series", name = "Series 01" }, screen.showing)
            assert.equals(screen, harness.top())
        end)

        it("on Under way first is the header's empty space and opens the file manager's menu", function()
            install()
            local screen, fm = fixture.show()
            tap_on(screen.header.right[1])
            assert.same(LIST, screen.showing)
            assert.is_not_nil(fm.menu.menu_container)
            assert.equals(fm.menu.menu_container, harness.top())
            assert.equals(screen, harness.top(2))
        end)

        it("on a live pager arrow turns the page, and on a dead one does nothing", function()
            install()
            local screen = fixture.show()
            local pages = screen.pages
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
        end)

        it("it doesn't take reaches a corner zone on the file manager, and one in the bar doesn't", function()
            install()
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
        it("west and east page the list without wrapping", function()
            install()
            local screen = fixture.show()
            local size = Screen:getSize()
            local x, y = size.w / 2, size.h / 2
            send(swipe(x, y, "east"))
            assert.equals(1, screen.page)
            send(swipe(x, y, "west"))
            assert.equals(2, screen.page)
            send(swipe(x, y, "east"))
            assert.equals(1, screen.page)
        end)

        it("west in the bottom edge band or east in the top one reaches the file manager instead", function()
            install()
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

    it("pages forward and back with the page keys", function()
        assert.is_true(Device:hasKeys())
        install()
        local screen = fixture.show()
        UIManager:sendEvent(Event:new("KeyPress", Key:new("RPgFwd", {})))
        assert.equals(2, screen.page)
        UIManager:sendEvent(Event:new("KeyPress", Key:new("RPgBack", {})))
        assert.equals(1, screen.page)
        UIManager:sendEvent(Event:new("KeyPress", Key:new("RPgBack", {})))
        assert.equals(1, screen.page)
    end)

    -- The fixture's books are no files, so a held book's sheet re-lists instead.
    it("runs no open on a hold, and consumes it", function()
        install()
        local screen = fixture.show()
        send(harness.gesture("hold", centre(screen.rows[1].rect)))
        assert.same(LIST, screen.showing)
        screen:go({ kind = "series", name = "Series 01" }, 1)
        local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
        send(harness.gesture("hold", centre(screen.rows[1].rect)))
        send(harness.gesture("hold", centre(screen.header.back_rect)))
        assert.same({}, opened)
        assert.same({ kind = "series", name = "Series 01" }, screen.showing)
        assert.equals(screen, harness.top())
    end)

    it("hands the window and what lies under a hold to the dispatch", function()
        install()
        local screen = fixture.show()
        local held = dispatched()
        send(harness.gesture("hold", centre(screen.rows[1].rect)))
        screen:go({ kind = "series", name = "Series 01" }, 1)
        send(harness.gesture("hold", centre(screen.rows[1].rect)))
        assert.equals(2, #held)
        assert.equals(screen, held[1][1])
        assert.same({ "series", "Series 01" }, { held[1][2].kind, held[1][2].entry.name })
        assert.equals(screen, held[2][1])
        assert.same({ kind = "book", record = screen.rows[1].record }, held[2][2])
        assert.equals(screen.rows[1].record, held[2][2].record)
    end)

    it("runs no dispatch on a hold in the nav bar's band", function()
        install()
        local screen = fixture.show()
        local held = dispatched()
        hold_bar(screen)
        assert.same({}, held)
        assert.equals(screen, harness.top())
    end)

    it("lets a hold zone on the file manager that consumes the hold win over the dispatch", function()
        install()
        local screen, fm = fixture.show({ kind = "series", name = "Series 01" })
        local got = bind(fm, "kopanda_spec_hold", "hold", FULL)
        local held = dispatched()
        send(harness.gesture("hold", centre(screen.rows[1].rect)))
        assert.equals(1, #got)
        assert.same({}, held)
        assert.equals(screen, harness.top())
    end)

    it("SeriesScreen.hit names the series, the book or empty space under a point, and nil with none shown",
        function()
        install()
        assert.is_nil(SeriesScreen.hit(10, 10))
        local screen = fixture.show()
        local row = screen.rows[1]
        assert.same({ kind = "series", entry = row.entry }, SeriesScreen.hit(row.rect.x, row.rect.y))
        assert.equals("series", SeriesScreen.hit(row.rect.x + row.rect.w - 1, row.rect.y + row.rect.h - 1).kind)
        assert.same({ kind = "empty" }, SeriesScreen.hit(row.rect.x, row.rect.y + row.rect.h))
        assert.same({ kind = "empty" }, SeriesScreen.hit(centre(screen.header.rect)))
        screen:go({ kind = "series", name = "Series 01" }, 1)
        row = row_of(screen, "Untold")
        assert.same({ kind = "book", record = row.record }, SeriesScreen.hit(centre(row.rect)))
    end)

    it("does nothing on a tap under KOReader's touch lock", function()
        install()
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

describe("gestures on the Authors window", function()
    local AuthorsScreen, NavBar

    local LIST = { kind = "list" }
    local GRID = { kind = "author", name = "Jo Grid" }
    local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    -- Thirty authors of one book each, "Ann A01" to "Ann D30" by their letters, two pages or more;
    -- and Jo Grid's seven books, the first not downloaded (in a series, so first in D16's order).
    local function install()
        local records = {}
        for i = 1, 30 do
            local letter = LETTERS:sub((i - 1) % 26 + 1, (i - 1) % 26 + 1)
            records[i] = fixture.book(("Book %02d"):format(i), { authors = { ("Ann %s%02d"):format(letter, i) } })
        end
        records[#records + 1] = fixture.remote("Untold",
            { series = "Alpha", series_index = 1, authors = { "Jo Grid" } })
        for i = 1, 6 do
            records[#records + 1] = fixture.book("Grid " .. i, { authors = { "Jo Grid" } })
        end
        return fixture.install(records)
    end

    before_each(function()
        harness.load()
        AuthorsScreen = package.loaded["authors_screen"]
        NavBar = package.loaded["nav_bar"]
    end)

    after_each(reset)

    local function row_of(screen, name)
        for _, row in ipairs(screen.rows) do
            if row.entry.name == name then
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

    it("in the nav bar's band runs the tapped tab first, with where authors", function()
        install()
        local screen, fm = fixture.show_authors()
        local got = bind(fm, "kopanda_spec_bar_tap", "tap", FULL)
        local runs = spy(NavBar, "run")
        local bar = screen.nav
        local column = bar.columns[5]
        send(harness.gesture("tap", bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
            bar.dimen.y + math.floor(bar.dimen.h / 2)))
        assert.same({ { "settings", "authors" } }, runs)
        assert.same({}, got)
        assert.equals(screen, harness.top())
    end)

    describe("a tap", function()
        it("on an author row shows that author at their first page", function()
            install()
            local screen = fixture.show_authors()
            tap_on(row_of(screen, "Ann A01").rect)
            assert.same({ kind = "author", name = "Ann A01" }, screen.showing)
            assert.equals(1, screen.page)
            assert.equals("Book 01", screen.tiles[1].record.title)
            assert.equals(screen, AuthorsScreen.shown)
        end)

        it("on the back control returns to the list at the page holding the author", function()
            install()
            local screen = fixture.show_authors(LIST, 2)
            local row = screen.rows[2]
            local name = row.entry.name
            tap_on(row.rect)
            assert.same({ kind = "author", name = name }, screen.showing)
            tap_on(screen.header.back_rect)
            assert.same(LIST, screen.showing)
            assert.equals(2, screen.page)
            assert.is_not_nil(row_of(screen, name))
        end)

        it("on a downloaded book's tile opens it through filemanagerutil.openFile, on_open run first", function()
            install()
            local screen, fm = fixture.show_authors(GRID)
            local order = {}
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile", function(_, _, pre)
                order[#order + 1] = "open"
                pre()
            end)
            local returns = spy(AuthorsScreen, "on_open", function()
                order[#order + 1] = "return"
            end)
            local tile = tile_of(screen, "Grid 2")
            tap_on(tile.rect)
            assert.equals(1, #opened)
            assert.equals(fm, opened[1][1])
            assert.equals(tile.record.path, opened[1][2])
            assert.same({ { GRID, 1 } }, returns)
            assert.same({ "open", "return" }, order)
        end)

        it("on a book not downloaded does nothing and is consumed", function()
            install()
            local screen, fm = fixture.show_authors(GRID)
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
            local got = bind(fm, "kopanda_spec_full_tap", "tap", FULL)
            tap_on(tile_of(screen, "Untold").rect)
            assert.same({}, opened)
            assert.same({}, got)
            assert.same(GRID, screen.showing)
            assert.equals(screen, harness.top())
        end)

        it("on By surname is the header's empty space and opens the file manager's menu", function()
            install()
            local screen, fm = fixture.show_authors()
            tap_on(screen.header.right[1])
            assert.same(LIST, screen.showing)
            assert.is_not_nil(fm.menu.menu_container)
            assert.equals(fm.menu.menu_container, harness.top())
            assert.equals(screen, harness.top(2))
        end)

        it("on a live pager arrow turns the page, in the list and one author, and on a dead one does nothing",
            function()
            install()
            local screen = fixture.show_authors()
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
            screen:go(GRID, 1)
            assert.equals(2, screen.pages)
            tap_on(screen.pager.next.rect)
            assert.same({ GRID, 2 }, { screen.showing, screen.page })
            tap_on(screen.pager.next.rect)
            assert.equals(2, screen.page)
            tap_on(screen.pager.prev.rect)
            assert.equals(1, screen.page)
        end)
    end)

    it("pages the list with a west or east swipe, without wrapping, and with the page keys", function()
        install()
        local screen = fixture.show_authors()
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
    end)

    -- The fixture's books are no files, so a held book's sheet re-lists instead.
    it("runs no open on a hold, and consumes it", function()
        install()
        local screen = fixture.show_authors()
        send(harness.gesture("hold", centre(screen.rows[1].rect)))
        assert.same(LIST, screen.showing)
        screen:go(GRID, 1)
        local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
        send(harness.gesture("hold", centre(tile_of(screen, "Grid 1").rect)))
        send(harness.gesture("hold", centre(screen.header.back_rect)))
        assert.same({}, opened)
        assert.same(GRID, screen.showing)
        assert.equals(screen, harness.top())
    end)

    it("hands the window and what lies under a hold to the dispatch", function()
        install()
        local screen = fixture.show_authors()
        local held = dispatched()
        send(harness.gesture("hold", centre(screen.rows[1].rect)))
        screen:go(GRID, 1)
        local tile = tile_of(screen, "Grid 2")
        send(harness.gesture("hold", centre(tile.rect)))
        assert.equals(2, #held)
        assert.equals(screen, held[1][1])
        assert.equals("author", held[1][2].kind)
        assert.equals(screen, held[2][1])
        assert.same({ kind = "book", record = tile.record }, held[2][2])
        assert.equals(tile.record, held[2][2].record)
    end)

    it("runs no dispatch on a hold in the nav bar's band", function()
        install()
        local screen = fixture.show_authors()
        local held = dispatched()
        hold_bar(screen)
        assert.same({}, held)
        assert.equals(screen, harness.top())
    end)

    it("lets a hold zone on the file manager that consumes the hold win over the dispatch", function()
        install()
        local screen, fm = fixture.show_authors(GRID)
        local got = bind(fm, "kopanda_spec_hold", "hold", FULL)
        local held = dispatched()
        send(harness.gesture("hold", centre(tile_of(screen, "Grid 2").rect)))
        assert.equals(1, #got)
        assert.same({}, held)
        assert.equals(screen, harness.top())
    end)

    it("AuthorsScreen.hit names the author, the book or empty space under a point, and nil with none shown",
        function()
        install()
        assert.is_nil(AuthorsScreen.hit(10, 10))
        local screen = fixture.show_authors()
        local row = screen.rows[1]
        assert.same({ kind = "author", entry = row.entry }, AuthorsScreen.hit(row.rect.x, row.rect.y))
        assert.equals("author", AuthorsScreen.hit(row.rect.x + row.rect.w - 1, row.rect.y + row.rect.h - 1).kind)
        local last = screen.rows[#screen.rows]
        assert.same({ kind = "empty" }, AuthorsScreen.hit(last.rect.x, last.rect.y + last.rect.h))
        assert.same({ kind = "empty" }, AuthorsScreen.hit(centre(screen.header.rect)))
        screen:go(GRID, 1)
        local tile = tile_of(screen, "Untold")
        assert.same({ kind = "book", record = tile.record }, AuthorsScreen.hit(centre(tile.rect)))
        assert.same({ kind = "empty" }, AuthorsScreen.hit(tile.rect.x + tile.rect.w, tile.rect.y))
    end)
end)
