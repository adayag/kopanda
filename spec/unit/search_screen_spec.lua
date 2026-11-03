-- The library search: the results window on the chrome (the back control over the count and the quoted query, the
-- matches as six tiles a page, "No books match", back to the folder the search started from, a book's open
-- returning there) and the "Search library" dialog that shows it. Books.all and Books.progress are stubbed with
-- records under a root that exists nowhere (spec/shelf_fixture.lua). The shared Series and Authors cases
-- (spec/shelf_screen_cases.lua) read list rows and a { kind } view this window doesn't have, so the ones that apply
-- are written here for its tiles and its query.
describe("the search window", function()
    local cases = require("shelf_screen_cases")
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local text_of = require("library_fixture").text
    local Blitbuffer = require("ffi/blitbuffer")
    local Event = require("ui/event")
    local InputDialog = require("ui/widget/inputdialog")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Library, LibraryChrome, LibraryTiles, Looks, NavBar, SearchScreen

    local restores = {}
    local function replace(t, key, value)
        local old = t[key]
        restores[#restores + 1] = function()
            t[key] = old
        end
        t[key] = value
    end

    before_each(function()
        harness.load()
        Library = package.loaded["library"]
        LibraryChrome = package.loaded["library_chrome"]
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
        NavBar = package.loaded["nav_bar"]
        SearchScreen = package.loaded["search_screen"]
    end)

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        restores = {}
        harness.teardown()
    end)

    local each_look = cases.each_look
    local FROM = { dir = fixture.ROOT .. "/fantasy", page = 2 }

    local function lower(text)
        return text and text:lower()
    end

    -- Eight books by Neil Gaiman with a file, Sandman by him without one, and Mort by Terry Pratchett.
    local function gaiman()
        local function by(title)
            return fixture.book(title, { authors = { "Neil Gaiman" } })
        end
        return {
            by("Stardust"), by("Neverwhere"), by("The Graveyard Book"), by("Coraline"),
            fixture.book("Mort", { authors = { "Terry Pratchett" }, series = "Discworld" }),
            by("Norse Mythology"), by("Anansi Boys"), by("Good Omens"), by("American Gods"),
            fixture.remote("Sandman", { authors = { "Neil Gaiman" } }),
        }
    end

    -- A file manager with the home closed and the search for query from FROM shown at page, painted and settled.
    local function show(query, page)
        local fm = harness.show_fm()
        harness.tick(2)
        require("home").close()
        local screen = SearchScreen.show{ query = query, from = FROM, page = page }
        assert.is_not_nil(screen)
        harness.tick(2)
        assert.equals(screen, harness.top())
        return screen, fm
    end

    local function titles(screen)
        local out = {}
        for i, tile in ipairs(screen.tiles) do
            out[i] = tile.record.title
        end
        return out
    end

    local function tile_of(screen, title)
        for _, tile in ipairs(screen.tiles) do
            if tile.record.title == title then
                return tile
            end
        end
    end

    local function centre(rect)
        return { x = rect.x + math.floor(rect.w / 2), y = rect.y + math.floor(rect.h / 2) }
    end

    describe("the window", function()
        it("shows full-screen over the file manager as SearchScreen.shown, and closes", function()
            fixture.install(gaiman())
            local screen, fm = show("gaiman")
            assert.equals("kopanda_search", screen.name)
            assert.equals("search", screen.screen)
            assert.is_true(screen.covers_fullscreen)
            assert.equals(screen, SearchScreen.shown)
            assert.same({ query = "gaiman" }, screen:view())
            assert.equals(FROM, screen.from)
            assert.equals(fm, harness.top(2))
            SearchScreen.close()
            assert.is_nil(SearchScreen.shown)
            assert.equals(fm, harness.top())
        end)

        it("closes the window shown before it, one window at a time", function()
            fixture.install(gaiman())
            local before = fixture.show_authors()
            local screen = SearchScreen.show{ query = "gaiman", from = FROM }
            assert.is_nil(package.loaded["authors_screen"].shown)
            assert.is_false(UIManager:isWidgetShown(before))
            assert.equals(screen, harness.top())
        end)

        it("reads the books once per show and a drawn match's progress once, none again turning back", function()
            local records = gaiman()
            local calls = fixture.install(records)
            local screen = show("gaiman")
            assert.equals(1, calls.all)
            local seen = {}
            for _, id in ipairs(calls.progress) do
                assert.is_nil(seen[id], id .. " read twice")
                seen[id] = true
            end
            -- Coraline is on page 1, Stardust on page 2.
            assert.is_true(seen[records[4].id])
            assert.is_nil(seen[records[1].id])
            screen:turn(1)
            assert.equals(records[1].id, calls.progress[#calls.progress])
            calls.progress = {}
            screen:turn(-1)
            screen:turn(1)
            assert.equals(1, calls.all)
            assert.same({}, calls.progress)
        end)

        it("is the plugin's showSearch", function()
            fixture.install(gaiman())
            local _, fm = show("gaiman")
            SearchScreen.close()
            fm.kopanda:showSearch{ query = "omens", from = FROM }
            assert.is_not_nil(SearchScreen.shown)
            assert.equals("omens", SearchScreen.shown.query)
            assert.equals(FROM, SearchScreen.shown.from)
        end)
    end)

    describe("the header", function()
        it("puts the back control to the library over the count and the quoted query, the detail header's height",
            function()
            fixture.install(gaiman())
            each_look(function(id)
                local screen = show("Gaiman")
                local header = screen.header
                assert.equals("9 books", lower(text_of(header.aside)), id)
                assert.equals("“Gaiman”", text_of(header.title), id)
                assert.equals("library", lower(text_of(header.back_label)), id)
                assert.equals(LibraryChrome.detail_header_height(screen.ctx), header.rect.h, id)
                local band = screen.ctx.look.library.header.fill_color
                local palette = Looks.palette(screen.ctx.look, screen.ctx.variant)
                assert.same(band and Looks.color(palette[band]) or nil, screen[1][1].fill_color, id)
                harness.teardown()
            end)
        end)

        it("counts one book and no books", function()
            fixture.install(gaiman())
            local screen = show("mort")
            assert.equals("1 book", lower(text_of(screen.header.aside)))
            SearchScreen.close()
            screen = SearchScreen.show{ query = "zzz", from = FROM }
            assert.equals("no books", lower(text_of(screen.header.aside)))
        end)
    end)

    describe("the tiles", function()
        it("lays the matches six a page in three columns and two rows in title order", function()
            fixture.install(gaiman())
            each_look(function(id)
                local screen = show("gaiman")
                local ctx = screen.ctx
                local grid = ctx.look.library.grid
                local header_h = LibraryChrome.detail_header_height(ctx)
                local box = LibraryTiles.geometry(Screen:getWidth(), ctx, {
                    cover_h = ctx.look.shelf.author_grid.cover_h,
                    room = LibraryTiles.room(Screen:getHeight(), ctx, header_h),
                })
                local top = header_h + Screen:scaleBySize(grid.padding_top)
                assert.same({ "American Gods", "Anansi Boys", "Coraline", "Good Omens", "The Graveyard Book",
                    "Neverwhere" }, titles(screen), id)
                for i, tile in ipairs(screen.tiles) do
                    local column, row = (i - 1) % 3 + 1, math.floor((i - 1) / 3)
                    assert.same({ box.columns[column].x, top + row * (box.height + Screen:scaleBySize(grid.row_gap)),
                        box.cover_w, box.height }, { tile.rect.x, tile.rect.y, tile.rect.w, tile.rect.h }, id)
                    assert.equals(box.height, tile.widget:getSize().h, id)
                    assert.is_nil(tile.widget.chip, id)
                end
                assert.equals(2, screen.pages, id)
                screen:go(screen:view(), 2)
                assert.same({ "Norse Mythology", "Sandman", "Stardust" }, titles(screen), id)
                assert.is_true(screen.tiles[3].rect.y + screen.tiles[3].rect.h <= screen.pager.prev.rect.y, id)
                assert.is_nil(screen.note, id)
                harness.teardown()
            end)
        end)

        it("shows a page past the end as the last", function()
            fixture.install(gaiman())
            local screen = show("gaiman", 9)
            assert.same({ 2, 2 }, { screen.page, screen.pages })
        end)

        it("centres No books match between the grid's top and the pager, on page 1 of 1, with no match", function()
            fixture.install(gaiman())
            each_look(function(id)
                local screen = show("zzz")
                assert.equals("no books match", lower(text_of(screen.note)), id)
                assert.same({}, screen.tiles, id)
                assert.same({ 1, 1 }, { screen.page, screen.pages }, id)
                assert.same({ false, false }, { screen.pager.prev.live, screen.pager.next.live }, id)
                local frame = screen[1]
                local place
                for i, child in ipairs(frame) do
                    if child == screen.note then
                        place = frame.places[i]
                    end
                end
                local size = screen.note:getSize()
                local top = LibraryChrome.detail_header_height(screen.ctx)
                    + Screen:scaleBySize(screen.ctx.look.library.grid.padding_top)
                local below = screen.pager.prev.rect.y
                assert.same({ math.floor((Screen:getWidth() - size.w) / 2),
                    top + math.floor((below - top - size.h) / 2) }, { place.x, place.y }, id)
                harness.teardown()
            end)
        end)

        it("carries the nav bar at the bottom with Library lit", function()
            fixture.install(gaiman())
            each_look(function(id)
                local screen = show("gaiman")
                local nav = screen.nav
                assert.equals("library", nav.where, id)
                assert.equals("library", nav.active and NavBar.TABS[nav.active].id, id)
                local bar_y = Screen:getHeight() - NavBar.height(screen.ctx.look, Screen)
                assert.same({ 0, bar_y, Screen:getWidth() }, { nav.dimen.x, nav.dimen.y, nav.dimen.w }, id)
                harness.teardown()
            end)
        end)

        it("keys a page by the query, the page and the books it draws", function()
            fixture.install(gaiman())
            local screen = show("gaiman")
            local keys, drawn = screen:page_keys({ query = "gaiman" }, 1)
            assert.same(screen.keys, keys)
            local ids = {}
            for i, tile in ipairs(screen.tiles) do
                ids[tile.record.id] = true
                assert.equals(tile.record.id, keys[i + 1])
            end
            assert.same(ids, drawn)
            assert.equals(7, #keys)
            -- "neil" matches the same books: the query alone tells the keys apart.
            assert.is_not.same(keys, (screen:page_keys({ query = "neil" }, 1)))
            assert.is_not.same(keys, (screen:page_keys({ query = "gaiman" }, 2)))
        end)
    end)

    describe("taps and holds", function()
        it("opens a book with a file through the chrome's open, and nothing for one without, the tap the window's",
            function()
            fixture.install(gaiman())
            local opened = {}
            replace(LibraryChrome.Window, "open", function(_, record)
                opened[#opened + 1] = record.title
            end)
            local screen = show("gaiman")
            assert.is_true(screen:tap(centre(tile_of(screen, "Coraline").rect)))
            assert.same({ "Coraline" }, opened)
            screen:go(screen:view(), 2)
            assert.is_true(screen:tap(centre(tile_of(screen, "Sandman").rect)))
            assert.same({ "Coraline" }, opened)
        end)

        it("records the folder and page the search started from as the open's return", function()
            fixture.install(gaiman())
            local screen = show("gaiman")
            local util = require("apps/filemanager/filemanagerutil")
            local opened
            replace(util, "openFile", function(_, file, pre)
                opened = file
                pre()
            end)
            screen:tap(centre(tile_of(screen, "Coraline").rect))
            assert.equals(tile_of(screen, "Coraline").record.path, opened)
            assert.same(FROM, Library.return_to)
            assert.is_nil(LibraryChrome.return_to)
        end)

        -- An open that goes ahead (filemanagerutil.lua:500-502's pre-callback, then the file manager closing for
        -- the reader, filemanager.lua:842-849), a real reader read and closed and a new file manager shown
        -- (readerui.lua:581-596), as shelf_lifecycle_spec.lua drives the Series and Authors windows'.
        it("returns to the library at the folder and page the search started from after the book closes", function()
            fixture.install(gaiman())
            local fm = harness.show_fm()
            harness.tick(2)
            require("home").close()
            local from = { dir = harness.library, page = 1 }
            local screen = SearchScreen.show{ query = "gaiman", from = from }
            harness.tick(2)
            local util = require("apps/filemanager/filemanagerutil")
            local pre
            replace(util, "openFile", function(_, _, callback)
                pre = callback
            end)
            screen:tap(centre(tile_of(screen, "Coraline").rect))
            pre()
            fm:onShowingReader()
            assert.is_nil(SearchScreen.shown)
            local reader = harness.open_reader()
            harness.tick(2)
            reader:onClose()
            harness.show_fm()
            assert.is_not_nil(Library.shown)
            assert.equals(Library.shown, harness.top())
            assert.same({ from.dir, from.page }, { Library.shown.dir, Library.shown.page })
            assert.is_nil(SearchScreen.shown)
            assert.is_nil(Library.return_to)
        end)

        it("drops the return of an open that never closed the file manager once the window has closed", function()
            fixture.install(gaiman())
            local screen, fm = show("gaiman")
            local util = require("apps/filemanager/filemanagerutil")
            local pre
            replace(util, "openFile", function(_, _, callback)
                pre = callback
            end)
            screen:tap(centre(tile_of(screen, "Coraline").rect))
            pre()
            assert.same(FROM, Library.return_to)
            SearchScreen.close()
            fm:onClose()
            assert.is_nil(Library.return_to)
        end)

        it("shows the library at the folder and page the search started from on back", function()
            fixture.install(gaiman())
            local asked
            replace(Library, "show", function(opts)
                asked = opts
            end)
            local screen = show("gaiman")
            assert.is_true(screen:tap(centre(screen.header.back_rect)))
            assert.same({ dir = FROM.dir, page = FROM.page }, asked)
        end)

        it("closes onto the library at that folder on back", function()
            fixture.install(gaiman())
            harness.show_fm()
            harness.tick(2)
            require("home").close()
            local screen = SearchScreen.show{ query = "gaiman", from = { dir = harness.library } }
            screen:back()
            assert.is_nil(SearchScreen.shown)
            assert.is_false(UIManager:isWidgetShown(screen))
            assert.is_not_nil(Library.shown)
            assert.equals(harness.library, Library.shown.dir)
            assert.equals(Library.shown, harness.top())
        end)

        it("closes onto the home on the nav bar's Home tab, the one KoPanda window up", function()
            fixture.install(gaiman())
            local screen = show("gaiman")
            local bar = screen.nav
            local column = bar.columns[1]
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap",
                bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
                bar.dimen.y + math.floor(bar.dimen.h / 2))))
            local Home = package.loaded["home"]
            assert.is_nil(SearchScreen.shown)
            assert.is_false(UIManager:isWidgetShown(screen))
            assert.is_not_nil(Home.shown)
            assert.equals(Home.shown, harness.top())
            local windows = {}
            for _, widget in ipairs(harness.stack()) do
                if widget.name and widget.name:find("^kopanda_") then
                    windows[#windows + 1] = widget
                end
            end
            assert.same({ Home.shown }, windows)
        end)

        it("gives quick settings opened by a top tap the Library beneath, as its Settings tab does, so a failure "
            .. "closes neither the home nor the search", function()
            fixture.install(gaiman())
            local screen = show("gaiman")
            local Home = package.loaded["home"]
            local Sheet = package.loaded["sheet"]
            local home_closes = {}
            local home_close = Home.close
            replace(Home, "close", function(...)
                home_closes[#home_closes + 1] = true
                return home_close(...)
            end)
            replace(package.loaded["quick_settings"], "body", function()
                error("kopanda-test: quick settings failed")
            end)
            local bar = screen.nav
            local column = bar.columns[5]
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap",
                bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
                bar.dimen.y + math.floor(bar.dimen.h / 2))))
            assert.is_nil(Sheet.shown)
            assert.same({}, home_closes)
            assert.equals(screen, harness.top())
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", Screen:getWidth() - 2, 2)))
            assert.is_nil(Sheet.shown)
            assert.same({}, home_closes)
            assert.equals(screen, harness.top())
        end)

        it("answers book on a tile and empty elsewhere, nil with no search shown", function()
            fixture.install(gaiman())
            local screen = show("gaiman")
            local tile = tile_of(screen, "Coraline")
            local at = centre(tile.rect)
            assert.same({ kind = "book", record = tile.record }, SearchScreen.hit(at.x, at.y))
            local header = centre(screen.header.rect)
            assert.same({ kind = "empty" }, SearchScreen.hit(header.x, header.y))
            SearchScreen.close()
            assert.is_nil(SearchScreen.hit(at.x, at.y))
        end)
    end)

    describe("kept current", function()
        it("reads the books again at refresh() and on the metadata events", function()
            local records = gaiman()
            local calls = fixture.install(records)
            local screen = show("gaiman")
            assert.equals("9 books", lower(text_of(screen.header.aside)))
            records[#records + 1] = fixture.book("Smoke and Mirrors", { authors = { "Neil Gaiman" } })
            screen:refresh()
            assert.equals(2, calls.all)
            assert.equals("10 books", lower(text_of(screen.header.aside)))
            records[#records + 1] = fixture.book("Fragile Things", { authors = { "Neil Gaiman" } })
            UIManager:broadcastEvent(Event:new("InvalidateMetadataCache"))
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            harness.tick(2)
            assert.equals(3, calls.all)
            assert.equals("11 books", lower(text_of(screen.header.aside)))
            assert.equals(screen, harness.top())
        end)

        it("matches again on a cover arrival that re-reads a book into a match", function()
            local arrivals
            replace(package.loaded["book_covers"], "request", function(_, _, on_arrival)
                arrivals = on_arrival
            end)
            local records = { fixture.book("Coraline", { authors = { "Neil Gaiman" } }),
                fixture.book("Smoke and Mirrors") }
            fixture.install(records)
            local screen = show("gaiman")
            harness.tick(2)
            assert.is_function(arrivals)
            assert.same({ "Coraline" }, titles(screen))
            assert.equals("1 book", lower(text_of(screen.header.aside)))
            records[2] = fixture.book("Smoke and Mirrors", { authors = { "Neil Gaiman" } })
            arrivals({ records[2] })
            assert.same({ "Coraline", "Smoke and Mirrors" }, titles(screen))
            assert.equals("2 books", lower(text_of(screen.header.aside)))
        end)

        it("rebuilds before painting when the variant changed since its build", function()
            fixture.install(gaiman())
            local screen = show("gaiman")
            local frame = screen[1]
            replace(Looks, "variant", function()
                return "night"
            end)
            local bb = Blitbuffer.new(screen.dimen.w, screen.dimen.h, Blitbuffer.TYPE_BBRGB32)
            screen:paintTo(bb, 0, 0)
            bb:free()
            assert.equals("night", screen.ctx.variant)
            assert.is_not.equals(frame, screen[1])
            assert.equals("gaiman", screen.query)
        end)
    end)

    describe("the settled signal", function()
        local listener

        after_each(function()
            if listener then
                UIManager.event_hook:unregister("KoPandaSettled", listener)
                listener = nil
            end
        end)

        it("is sent once per show after its first paint, with screen search and a numeric paint_ms", function()
            local signals = {}
            listener = function(args)
                if args.screen == "search" then
                    assert.is_number(args.paint_ms)
                    signals[#signals + 1] = args
                end
            end
            UIManager.event_hook:register("KoPandaSettled", listener)
            fixture.install(gaiman())
            local screen = show("gaiman")
            assert.equals(1, #signals)
            screen:turn(1)
            harness.tick(3)
            assert.equals(1, #signals)
            SearchScreen.close()
            SearchScreen.show{ query = "omens", from = FROM }
            harness.tick(3)
            assert.equals(2, #signals)
        end)
    end)

    describe("the dialog", function()
        -- The dialog SearchScreen.ask(FROM) shows over a file manager with the home closed, checked to have
        -- shown the keyboard (headless, the keyboard never reports itself visible, so the call is what's checked).
        local function ask()
            fixture.install(gaiman())
            harness.show_fm()
            harness.tick(2)
            require("home").close()
            local keyboard_for = {}
            local show_keyboard = InputDialog.onShowKeyboard
            replace(InputDialog, "onShowKeyboard", function(self, ...)
                keyboard_for[#keyboard_for + 1] = self
                return show_keyboard(self, ...)
            end)
            SearchScreen.ask(FROM)
            local dialog = harness.top()
            assert.equals(InputDialog, getmetatable(dialog))
            assert.equals("Search library", dialog.title)
            assert.same({ dialog }, keyboard_for)
            return dialog
        end

        local function press(dialog, text)
            for _, button in ipairs(dialog.buttons[1]) do
                if button.text == text then
                    return button.callback()
                end
            end
            error("no button " .. text)
        end

        it("offers Cancel as its close and Search on Enter", function()
            local dialog = ask()
            local cancel, search = dialog.buttons[1][1], dialog.buttons[1][2]
            assert.same({ "Cancel", "close" }, { cancel.text, cancel.id })
            assert.same({ "Search", true }, { search.text, search.is_enter_default })
        end)

        it("closes and shows nothing on Cancel", function()
            local dialog = ask()
            press(dialog, "Cancel")
            assert.is_false(UIManager:isWidgetShown(dialog))
            assert.is_nil(SearchScreen.shown)
        end)

        it("closes and shows nothing on Search with a blank query", function()
            local dialog = ask()
            dialog:setInputText("  \t ")
            press(dialog, "Search")
            assert.is_false(UIManager:isWidgetShown(dialog))
            assert.is_nil(SearchScreen.shown)
        end)

        it("closes and shows the results for the trimmed query from where it was asked", function()
            local dialog = ask()
            dialog:setInputText("  the grave  ")
            press(dialog, "Search")
            assert.is_false(UIManager:isWidgetShown(dialog))
            local screen = SearchScreen.shown
            assert.is_not_nil(screen)
            assert.equals("the grave", screen.query)
            assert.equals(FROM, screen.from)
            assert.equals(screen, harness.top())
            assert.same({ "The Graveyard Book" }, titles(screen))
        end)

        it("logs and closes the dialog when the show raises", function()
            local dialog = ask()
            local errors = {}
            replace(logger, "err", function(...)
                errors[#errors + 1] = table.concat({ tostring(select(1, ...)), tostring(select(2, ...)) }, " ")
            end)
            replace(SearchScreen, "show", function()
                error("kopanda-test: the show failed")
            end)
            dialog:setInputText("gaiman")
            assert.has_no.errors(function()
                press(dialog, "Search")
            end)
            assert.is_false(UIManager:isWidgetShown(dialog))
            assert.equals(1, #errors)
            assert.truthy(errors[1]:find("the library search failed", 1, true))
        end)

        it("logs and closes the dialog when showing the keyboard raises", function()
            fixture.install(gaiman())
            harness.show_fm()
            harness.tick(2)
            require("home").close()
            local errors = 0
            replace(logger, "err", function()
                errors = errors + 1
            end)
            replace(InputDialog, "onShowKeyboard", function()
                error("kopanda-test: the keyboard failed")
            end)
            assert.has_no.errors(function()
                SearchScreen.ask(FROM)
            end)
            for _, widget in ipairs(harness.stack()) do
                assert.is_not.equals(InputDialog, getmetatable(widget))
            end
            assert.equals(1, errors)
        end)
    end)
end)
