-- The library's gestures (cover-grid C7), in the feature's order: the nav bar's band; a tap on a
-- book, a folder, the title, a picker or a pager arrow; a west or east swipe, but not one in the top
-- or bottom edge band; the page keys; a hold; and everything else to the file manager's menu zones
-- and the zones on the file manager, the rest consumed. Library.hit names what lies under a point.
-- KOReader's touch lock filters the library's own zones.
describe("gestures on the library", function()
    local harness = require("plugin_harness")
    local fixture = require("library_fixture")
    local Device = require("device")
    local Event = require("ui/event")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local Key = require("device/key")
    local Screen = Device.screen
    local UIManager = require("ui/uimanager")
    local Library, NavBar

    local ROOT = fixture.ROOT
    local SUB = fixture.folder("Sci-fi")
    local REMOTE = fixture.remote("A Gentleman in Moscow")

    -- The root: one folder, eleven books and one not downloaded, three pages; the folder holds two
    -- books. The title order puts the one not downloaded last ("A " dropped), on page 3.
    local function install()
        local books = fixture.books(11)
        books[#books + 1] = REMOTE
        return fixture.install({
            [ROOT] = { books = books, folders = { SUB } },
            [SUB.path] = { books = fixture.books(2, SUB.path) },
        })
    end

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

    before_each(function()
        harness.load()
        Library = package.loaded["library"]
        NavBar = package.loaded["nav_bar"]
    end)

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        restores = {}
        InputContainer:setIgnoreTouchInput(false)
        fixture.restore()
        harness.teardown()
    end)

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
        send(harness.gesture("tap", fixture.centre(rect)))
    end

    -- The library's tile showing the item titled or named name.
    local function tile_of(library, name)
        for _, tile in ipairs(library.tiles) do
            local item = tile.record or tile.folder
            if item.title == name or item.name == name then
                return tile
            end
        end
    end

    -- A tap zone on the file manager over rect's ratios, as the Gestures plugin registers its corner
    -- taps (plugins/gestures.koplugin/main.lua:985-990, :1287-1288), and the gestures it got.
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

    describe("in the nav bar's band", function()
        it("runs the tapped tab first and runs nothing on a hold, both consumed", function()
            install()
            local library, fm = fixture.show()
            local got = bind(fm, "kopanda_spec_bar_corner", "tap", { ratio_x = 7 / 8, ratio_y = 7 / 8, ratio_w = 1 / 8,
                ratio_h = 1 / 8 })
            local runs = spy(NavBar, "run")
            local bar = library.nav
            local column = bar.columns[5]
            local x = bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2)
            local y = bar.dimen.y + math.floor(bar.dimen.h / 2)
            send(harness.gesture("tap", x, y))
            send(harness.gesture("hold", x, y))
            assert.same({ { "settings", "library" } }, runs)
            assert.same({}, got)
            assert.equals(library, harness.top())
        end)
    end)

    describe("a tap", function()
        it("on a downloaded book opens it through filemanagerutil.openFile, the return recorded first", function()
            install()
            local library, fm = fixture.show(ROOT, 2)
            local order = {}
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile", function(_, _, pre)
                order[#order + 1] = "open"
                pre()
            end)
            local returns = spy(Library, "on_open", function()
                order[#order + 1] = "return"
            end)
            local tile = library.tiles[1]
            assert.equals("book", tile.kind)
            tap_on(tile.rect)
            assert.equals(1, #opened)
            assert.equals(fm, opened[1][1])
            assert.equals(tile.record.path, opened[1][2])
            assert.same({ { ROOT, 2 } }, returns)
            assert.same({ "open", "return" }, order)
        end)

        it("on a book not downloaded does nothing and is consumed", function()
            install()
            local library, fm = fixture.show(ROOT, 3)
            local tile = tile_of(library, REMOTE.title)
            assert.is_not_nil(tile)
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
            local got = bind(fm, "kopanda_spec_full_tap", "tap", FULL)
            tap_on(tile.rect)
            assert.same({}, opened)
            assert.same({}, got)
            assert.equals(library, harness.top())
            assert.same({ ROOT, 3 }, { library.dir, library.page })
        end)

        it("on a folder shows that folder, and on the title inside it goes up one folder", function()
            install()
            local library = fixture.show()
            tap_on(tile_of(library, "Sci-fi").rect)
            assert.same({ SUB.path, 1 }, { library.dir, library.page })
            assert.equals("Sci-fi", fixture.text(library.header.title))
            assert.equals(2, #library.tiles)
            tap_on(library.header.title_rect)
            assert.same({ ROOT, 1 }, { library.dir, library.page })
            assert.equals(library, harness.top())
            assert.equals(library, Library.shown)
        end)

        -- Books.folder gives a folder that went since it was listed empty lists (books.lua:202-206).
        it("on the title of a folder that went shows its note and still goes up", function()
            install()
            local gone = fixture.folder("Gone")
            fixture.install({ [ROOT] = { folders = { SUB, gone } } })
            local library = fixture.show()
            tap_on(tile_of(library, "Gone").rect)
            assert.same({ gone.path, 1 }, { library.dir, library.page })
            assert.is_not_nil(library.note)
            tap_on(library.header.title_rect)
            assert.same({ ROOT, 1 }, { library.dir, library.page })
            assert.equals(2, #library.tiles)
        end)

        it("on a folder shows it at the page it was left at", function()
            install()
            local sub_books = fixture.books(8, SUB.path)
            fixture.install({ [ROOT] = { folders = { SUB } }, [SUB.path] = { books = sub_books } })
            assert.is_true(package.loaded["library_order"].leave(SUB.path, 2))
            local library = fixture.show()
            tap_on(tile_of(library, "Sci-fi").rect)
            assert.same({ SUB.path, 2 }, { library.dir, library.page })
        end)

        it("on a picker calls Library.on_picker with its kind", function()
            install()
            local library = fixture.show()
            local picked = spy(Library, "on_picker")
            tap_on(library.header.sort.rect)
            tap_on(library.header.status.rect)
            assert.same({ { "sort" }, { "status" } }, picked)
            assert.equals(library, harness.top())
        end)

        it("on a live pager arrow turns the page, and on a dead one does nothing", function()
            install()
            local library = fixture.show()
            tap_on(library.pager.prev.rect)
            assert.equals(1, library.page)
            tap_on(library.pager.next.rect)
            assert.equals(2, library.page)
            tap_on(library.pager.next.rect)
            assert.equals(3, library.page)
            tap_on(library.pager.next.rect)
            assert.equals(3, library.page)
            tap_on(library.pager.prev.rect)
            assert.equals(2, library.page)
            assert.equals(library, harness.top())
        end)

        it("at the top centre outside the pickers opens the file manager's menu", function()
            install()
            local library, fm = fixture.show()
            send(harness.gesture("tap", Screen:getWidth() / 2, 2))
            assert.is_not_nil(fm.menu.menu_container)
            assert.equals(fm.menu.menu_container, harness.top())
            assert.equals(library, harness.top(2))
        end)

        it("it doesn't take reaches a corner zone on the file manager, and one in the bar doesn't", function()
            install()
            local library, fm = fixture.show()
            local corner = { ratio_x = 7 / 8, ratio_y = 7 / 8, ratio_w = 1 / 8, ratio_h = 1 / 8 }
            local got = bind(fm, "kopanda_spec_corner", "tap", corner)
            local size = Screen:getSize()
            local above_bar = library.nav.dimen.y - 2
            assert.truthy(above_bar >= size.h * 7 / 8)
            assert.equals("empty", Library.hit(size.w - 2, above_bar).kind)
            local ges = harness.gesture("tap", size.w - 2, above_bar)
            send(ges)
            assert.same({ ges }, got)
            -- In the bar, the Settings tab runs instead.
            local runs = spy(NavBar, "run")
            send(harness.gesture("tap", size.w - 2, size.h - 2))
            assert.equals(1, #got)
            assert.equals(1, #runs)
        end)
    end)

    describe("a swipe", function()
        it("west and east page the library without wrapping", function()
            install()
            local library = fixture.show()
            local size = Screen:getSize()
            local x, y = size.w / 2, size.h / 2
            send(swipe(x, y, "east"))
            assert.equals(1, library.page)
            send(swipe(x, y, "west"))
            assert.equals(2, library.page)
            send(swipe(x, y, "west"))
            send(swipe(x, y, "west"))
            assert.equals(3, library.page)
            send(swipe(x, y, "east"))
            assert.equals(2, library.page)
        end)

        it("west in the bottom edge band or east in the top one reaches the file manager instead", function()
            install()
            local library, fm = fixture.show()
            local got = bind(fm, "kopanda_spec_edge_swipe", "swipe", FULL)
            local size = Screen:getSize()
            local bottom = swipe(size.w / 2, size.h * 15 / 16 + 5, "west")
            local top = swipe(size.w / 2, 3, "east")
            send(bottom)
            send(top)
            assert.equals(1, library.page)
            assert.same({ bottom, top }, got)
        end)
    end)

    describe("the page keys", function()
        local function press(name)
            UIManager:sendEvent(Event:new("KeyPress", Key:new(name, {})))
        end

        it("page forward and back with keys", function()
            assert.is_true(Device:hasKeys())
            install()
            local library = fixture.show()
            press("RPgFwd")
            assert.equals(2, library.page)
            press("LPgFwd")
            assert.equals(3, library.page)
            press("RPgFwd")
            assert.equals(3, library.page)
            press("RPgBack")
            assert.equals(2, library.page)
        end)

        it("are not registered without keys", function()
            spy(Device, "hasKeys", function()
                return false
            end)
            install()
            local library = fixture.show()
            assert.is_nil(library.key_events.NextPage)
            assert.is_nil(library.key_events.PrevPage)
        end)
    end)

    describe("a hold", function()
        it("runs nothing, reaches no zone on the file manager and is consumed", function()
            install()
            local library, fm = fixture.show()
            local got = bind(fm, "kopanda_spec_hold", "hold", FULL)
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
            local picked = spy(Library, "on_picker")
            send(harness.gesture("hold", fixture.centre(library.tiles[2].rect)))
            send(harness.gesture("hold", fixture.centre(library.header.sort.rect)))
            assert.same({}, got)
            assert.same({}, opened)
            assert.same({}, picked)
            assert.same({ ROOT, 1 }, { library.dir, library.page })
            assert.equals(library, harness.top())
        end)
    end)

    describe("Library.hit", function()
        it("names the book, the folder or empty space under a point", function()
            install()
            local library = fixture.show()
            local folder, book = library.tiles[1], library.tiles[2]
            local hit = Library.hit(fixture.centre(folder.rect))
            assert.same({ "folder", SUB }, { hit.kind, hit.folder })
            hit = Library.hit(book.rect.x, book.rect.y)
            assert.same({ "book", book.record }, { hit.kind, hit.record })
            hit = Library.hit(book.rect.x + book.rect.w - 1, book.rect.y + book.rect.h - 1)
            assert.equals("book", hit.kind)
            -- The column gap between the two tiles.
            assert.same({ kind = "empty" }, Library.hit(folder.rect.x + folder.rect.w, folder.rect.y + 5))
            assert.same({ kind = "empty" }, Library.hit(book.rect.x + book.rect.w, book.rect.y))
        end)
    end)

    describe("under KOReader's touch lock", function()
        it("a tap does nothing", function()
            install()
            local library = fixture.show()
            local opened = spy(require("apps/filemanager/filemanagerutil"), "openFile")
            local runs = spy(NavBar, "run")
            InputContainer:setIgnoreTouchInput(true)
            tap_on(library.tiles[2].rect)
            tap_on(library.pager.next.rect)
            tap_on(tile_of(library, "Sci-fi").rect)
            local bar = library.nav
            send(harness.gesture("tap", bar.dimen.x + bar.dimen.w - 5, bar.dimen.y + 5))
            local size = Screen:getSize()
            send(swipe(size.w / 2, size.h / 2, "west"))
            assert.same({}, opened)
            assert.same({}, runs)
            assert.same({ ROOT, 1 }, { library.dir, library.page })
            assert.equals(library, harness.top())
        end)
    end)
end)
