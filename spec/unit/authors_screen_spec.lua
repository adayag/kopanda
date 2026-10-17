-- The Authors window (series-and-authors C5): the list's header (D10's count, "Authors", "By
-- surname"), its letter groups in D13's order a page at a time, a group split by a page break
-- repeating its letter, "#" after Z, the pager, Authors lit; one author's header (the back control,
-- D10's count, the name), six tiles in three columns and two rows in D16's order with the Up next
-- chip (D5, D19); the empty note and a gone author (D23); the rebuild on a variant or size change;
-- the re-listing on the metadata events; and the settled signal. Books.all and Books.progress are
-- stubbed with records under a root that exists nowhere (spec/shelf_fixture.lua).
describe("the Authors window", function()
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local text_of = require("library_fixture").text
    local Blitbuffer = require("ffi/blitbuffer")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local AuthorsScreen, LibraryChrome, LibraryTiles, Looks, NavBar, Settings, settled_listener

    before_each(function()
        harness.load()
        AuthorsScreen = package.loaded["authors_screen"]
        LibraryChrome = package.loaded["library_chrome"]
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
        NavBar = package.loaded["nav_bar"]
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
    local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    -- n authors with one book each, "Ann A01" to "Ann <letter>n", their surnames' letters cycling
    -- from A, or all under letter when given.
    local function shelf(n, letter)
        local records = {}
        for i = 1, n do
            local l = letter or LETTERS:sub((i - 1) % 26 + 1, (i - 1) % 26 + 1)
            records[i] = fixture.book(("Book %02d"):format(i), { authors = { ("Ann %s%02d"):format(l, i) } })
        end
        return records
    end

    -- The letters of the page's groups, each with "+" when it repeats, and its authors' names and
    -- counts, in order.
    local function page_of_groups(screen)
        local out = {}
        for _, group in ipairs(screen.groups) do
            local names = {}
            for i, row in ipairs(group.widget.rows) do
                names[i] = row.entry.name .. " " .. row.entry.count
            end
            out[#out + 1] = { group.letter .. (group.repeats and "+" or ""), names }
        end
        return out
    end

    -- Every page's groups, in order.
    local function all_groups(screen)
        local out = {}
        for page = 1, screen.pages do
            screen:go(LIST, page)
            for _, group in ipairs(page_of_groups(screen)) do
                out[#out + 1] = group
            end
        end
        return out
    end

    describe("the window", function()
        it("shows full-screen over the file manager as AuthorsScreen.shown, and closes", function()
            fixture.install(shelf(2))
            local screen, fm = fixture.show_authors()
            assert.equals("kopanda_authors", screen.name)
            assert.equals("authors", screen.screen)
            assert.is_true(screen.covers_fullscreen)
            assert.equals(screen, AuthorsScreen.shown)
            assert.equals(fm, harness.top(2))
            AuthorsScreen.close()
            assert.is_nil(AuthorsScreen.shown)
            assert.equals(fm, harness.top())
        end)

        it("closes the Series window before showing, one window at a time", function()
            fixture.install(shelf(2))
            local series = fixture.show()
            local screen = AuthorsScreen.show{}
            assert.is_nil(package.loaded["series_screen"].shown)
            assert.is_false(UIManager:isWidgetShown(series))
            assert.equals(screen, harness.top())
        end)

        it("reads the books once per show, no progress for the list, each book's once per author build", function()
            local records = shelf(3)
            records[#records + 1] = fixture.book("Saga 1",
                { series = "Saga", series_index = 1, authors = { "Ann A01" } })
            records[#records + 1] = fixture.book("Other 1",
                { series = "Other", series_index = 1, authors = { "Bo B02" } })
            records[#records + 1] = fixture.book("Nobody's")
            local calls = fixture.install(records)
            local screen = fixture.show_authors()
            assert.equals(1, calls.all)
            assert.same({}, calls.progress)
            screen:go({ kind = "author", name = "Ann A01" }, 1)
            assert.equals(1, calls.all)
            local seen = {}
            for _, id in ipairs(calls.progress) do
                assert.is_nil(seen[id], id .. " read twice")
                seen[id] = true
            end
            -- The author's books, and the whole library's series books for the up-next marks (D16).
            assert.is_true(seen[records[1].id])
            assert.is_true(seen[records[4].id])
            assert.is_true(seen[records[5].id])
            assert.is_nil(seen[records[6].id], "a book of no author's series and not this author's is not read")
        end)
    end)

    describe("the list", function()
        it("counts the authors in each look's words over Authors and By surname, on the authors band", function()
            local wanted = {
                diner = { "no authors on the shelf", "1 author on the shelf", "38 authors on the shelf" },
                editorial = { "no authors", "1 author", "38 authors" },
            }
            each_look(function(id)
                for i, n in ipairs({ 0, 1, 38 }) do
                    fixture.install(shelf(n))
                    local screen = fixture.show_authors()
                    local header = screen.header
                    assert.equals(wanted[id][i], lower(text_of(header.aside)), id .. " case " .. i)
                    assert.equals("authors", lower(text_of(header.title)), id)
                    assert.equals("by surname", lower(text_of(header.label)), id)
                    assert.is_nil(header.back_rect, id)
                    assert.equals(LibraryTiles.header_height(screen.ctx), header.rect.h, id)
                    local band = screen.ctx.look.shelf.authors_fill_color
                    local palette = Looks.palette(screen.ctx.look, screen.ctx.variant)
                    assert.same(band and Looks.color(palette[band]) or nil, screen[1][1].fill_color, id)
                    harness.teardown()
                end
            end)
        end)

        it("lays the letter groups in D13's order with each author's count, # after Z", function()
            local records = {
                fixture.book("Earthsea", { authors = { "Ursula K. Le Guin" } }),
                fixture.book("Wayfarers", { authors = { "Becky Chambers" } }),
                fixture.book("Record", { authors = { "Becky Chambers" } }),
                fixture.book("Piranesi", { authors = { "Susanna Clarke" } }),
                fixture.book("Teaching", { authors = { "bell hooks" } }),
                fixture.book("Feminism", { authors = { "Bell Hooks" } }),
                fixture.book("Season", { authors = { "N. K. Jemisin" } }),
                fixture.book("Shadow", { authors = { "Carlos Zafón" } }),
                fixture.book("Fjord", { authors = { "Prince Ølsen" } }),
                fixture.book("Together", { authors = { "Susanna Clarke", "N. K. Jemisin" } }),
                fixture.book("Anonymous"),
            }
            fixture.install(records)
            each_look(function(id)
                local screen = fixture.show_authors()
                local groups, letters, names = all_groups(screen), {}, {}
                for _, group in ipairs(groups) do
                    letters[#letters + 1] = group[1]:gsub("%+$", "")
                    for _, name in ipairs(group[2]) do
                        names[#names + 1] = name
                    end
                end
                local merged = {}
                for _, letter in ipairs(letters) do
                    if merged[#merged] ~= letter then
                        merged[#merged + 1] = letter
                    end
                end
                assert.same({ "C", "H", "J", "L", "Z", "#" }, merged, id)
                assert.same({ "Becky Chambers 2", "Susanna Clarke 2", "Bell Hooks 1", "bell hooks 1",
                    "N. K. Jemisin 2", "Ursula K. Le Guin 1", "Carlos Zafón 1", "Prince Ølsen 1" }, names, id)
                harness.teardown()
            end)
        end)

        it("places the groups from the list's side, a page at a time, the rows' rects their bands", function()
            fixture.install(shelf(38))
            each_look(function(id)
                local screen = fixture.show_authors()
                local shelf_tokens = screen.ctx.look.shelf
                local x = Screen:scaleBySize(shelf_tokens.list.side)
                local w = Screen:getWidth() - 2 * x
                assert.is_true(screen.pages >= 2, id)
                local seen = 0
                for page = 1, screen.pages do
                    screen:go(LIST, page)
                    local y = screen.header.rect.h + Screen:scaleBySize(shelf_tokens.groups.padding_top)
                    for _, group in ipairs(screen.groups) do
                        assert.same({ x, y, w }, { group.rect.x, group.rect.y, group.rect.w }, id)
                        assert.equals(group.widget:getSize().h, group.rect.h, id)
                        seen = seen + #group.widget.rows
                        y = y + group.rect.h + Screen:scaleBySize(shelf_tokens.groups.gap)
                    end
                    assert.is_true(y - Screen:scaleBySize(shelf_tokens.groups.gap) <= screen.pager.prev.rect.y,
                        id .. ": the groups end above the pager")
                    for _, row in ipairs(screen.rows) do
                        local group = row.group
                        assert.same({ group.rect.x, group.rect.y + row.band.y, group.rect.w, row.band.h },
                            { row.rect.x, row.rect.y, row.rect.w, row.rect.h }, id)
                    end
                end
                assert.equals(38, seen, id)
                harness.teardown()
            end)
        end)

        -- The list's page ends shelf.list.pager_gap above the pager at the Colorsoft, its last group's
        -- shadow inside the gap, with AuthorsC's seven rows in five groups on it (feature "The fit").
        it("keeps the pager gap below the last group and its shadow at the Colorsoft, in both looks", function()
            local records = {}
            for _, run in ipairs({ { "C", 2 }, { "H", 1 }, { "J", 2 }, { "L", 1 }, { "M", 1 }, { "P", 3 },
                    { "S", 2 }, { "T", 2 }, { "W", 3 } }) do
                for i = 1, run[2] do
                    records[#records + 1] = fixture.book(("Book %s%d"):format(run[1], i),
                        { authors = { ("Ann %s%02d"):format(run[1], i) } })
                end
            end
            fixture.install(records)
            harness.at_colorsoft(function()
                each_look(function(id)
                    local screen = AuthorsScreen.show{}
                    assert.is_true(screen.pages >= 2, id)
                    assert.is_true(#screen.rows >= 7, id .. ": " .. #screen.rows .. " rows")
                    local gap = Screen:scaleBySize(screen.ctx.look.shelf.list.pager_gap)
                    local last = screen.groups[#screen.groups]
                    local foot = last.rect.y + last.rect.h + last.widget.shadow_y
                    assert.is_true(foot + gap <= screen.pager.prev.rect.y,
                        ("%s: the last group's foot %d, %d px above the pager at %d"):format(id, foot,
                            screen.pager.prev.rect.y - foot, screen.pager.prev.rect.y))
                    AuthorsScreen.close()
                end)
            end)
        end)

        -- Whatever room a page leaves, the list keeps the gap: on screens from 1500 to 1800 px high, a
        -- full first page's last group and its shadow end shelf.list.pager_gap above the pager.
        it("keeps the pager gap on a full page at every screen height, in both looks", function()
            fixture.install(shelf(38))
            each_look(function(id)
                for h = 1500, 1800, 5 do
                    harness.at_screen(1264, h, function()
                        local screen = AuthorsScreen.show{}
                        assert.is_true(screen.pages >= 2, id)
                        local gap = Screen:scaleBySize(screen.ctx.look.shelf.list.pager_gap)
                        local last = screen.groups[#screen.groups]
                        local foot = last.rect.y + last.rect.h + last.widget.shadow_y
                        assert.is_true(foot + gap <= screen.pager.prev.rect.y,
                            ("%s at %d px: %d px above the pager"):format(id, h, screen.pager.prev.rect.y - foot))
                        AuthorsScreen.close()
                    end)
                end
            end)
        end)

        it("starts a page with a group's letter again when a page break splits it", function()
            fixture.install(shelf(30, "A"))
            local screen = fixture.show_authors()
            assert.is_true(screen.pages >= 2)
            local first = page_of_groups(screen)
            assert.equals(1, #first)
            assert.equals("A", first[1][1])
            screen:go(LIST, 2)
            local second = page_of_groups(screen)
            assert.equals("A+", second[1][1])
            assert.equals("A", text_of(screen.groups[1].widget.letter))
            assert.is_true(screen.groups[1].widget.repeats)
        end)

        it("labels the pager in each look's words, the first page's previous and the last's next dead", function()
            fixture.install(shelf(38))
            local wanted = { diner = "page %d of %d", editorial = "%d / %d" }
            each_look(function(id)
                local screen = fixture.show_authors()
                local pages = screen.pages
                assert.is_true(pages >= 2, id)
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

        it("carries the nav bar at the bottom with Authors lit, in the list and one author", function()
            fixture.install(shelf(2))
            each_look(function(id)
                local screen = fixture.show_authors()
                for _, view in ipairs({ LIST, { kind = "author", name = "Ann A01" } }) do
                    screen:go(view, 1)
                    local nav = screen.nav
                    assert.equals("authors", nav.where, id)
                    assert.equals("authors", NavBar.TABS[nav.active].id, id)
                    assert.same({ 0, Screen:getHeight() - NavBar.height(screen.ctx.look, Screen), Screen:getWidth() },
                        { nav.dimen.x, nav.dimen.y, nav.dimen.w }, id)
                end
                harness.teardown()
            end)
        end)

        it("shows the empty note and page 1 of 1 with no authors", function()
            fixture.install({ fixture.book("Anonymous"), fixture.remote("Remote") })
            each_look(function(id)
                local screen = fixture.show_authors()
                assert.equals("no authors yet", lower(text_of(screen.note)), id)
                assert.same({}, screen.groups, id)
                assert.same({}, screen.rows, id)
                assert.same({ 1, 1 }, { screen.page, screen.pages }, id)
                assert.same({ false, false }, { screen.pager.prev.live, screen.pager.next.live }, id)
                harness.teardown()
            end)
            fixture.install(shelf(1))
            local screen = fixture.show_authors()
            assert.is_nil(screen.note)
        end)
    end)

    describe("one author", function()
        local JEMISIN = "N. K. Jemisin"

        -- Nine books by N. K. Jemisin: The Broken Earth 1 to 3 (shelved out of order), Dreamblood 1
        -- (not downloaded) and 2, and four in no series; and a book by someone else.
        local function jemisin()
            local function by(title, fields)
                fields = fields or {}
                fields.authors = fields.authors or { JEMISIN }
                return fields.remote and fixture.remote(title, fields) or fixture.book(title, fields)
            end
            local books = {
                by("The Stone Sky", { series = "The Broken Earth", series_index = 3 }),
                by("Dreamblood 2", { series = "Dreamblood", series_index = 2 }),
                by("Zulu Stories"),
                by("The Fifth Season", { series = "The Broken Earth", series_index = 1 }),
                by("Emergency Skin"),
                by("The Killing Moon", { series = "Dreamblood", series_index = 1, remote = true }),
                by("How Long"),
                by("The Obelisk Gate", { series = "The Broken Earth", series_index = 2 }),
                by("Inheritance"),
                fixture.book("Elsewhere", { authors = { "Ann Author" } }),
            }
            return books
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

        it("heads the author with the back control over D10's count and the name, the detail header's height",
            function()
            local books = jemisin()
            local progress = {}
            for _, i in ipairs({ 1, 3, 4, 8 }) do
                progress[books[i].id] = { status = "complete", percent = 1 }
            end
            fixture.install(books, progress)
            local wanted = { diner = "9 books, 4 finished", editorial = "9 books · 4 finished" }
            each_look(function(id)
                local screen = fixture.show_authors({ kind = "author", name = JEMISIN })
                local header = screen.header
                assert.same({ kind = "author", name = JEMISIN }, screen.showing, id)
                assert.equals(wanted[id], lower(text_of(header.aside)), id)
                assert.equals(lower(JEMISIN), lower(text_of(header.title)), id)
                assert.equals("authors", lower(text_of(header.back_label)), id)
                assert.equals(LibraryChrome.detail_header_height(screen.ctx), header.rect.h, id)
                harness.teardown()
            end)
        end)

        it("counts the books alone with none finished, and one book", function()
            fixture.install(jemisin())
            local screen = fixture.show_authors({ kind = "author", name = JEMISIN })
            assert.equals("9 books", lower(text_of(screen.header.aside)))
            screen:go({ kind = "author", name = "Ann Author" }, 1)
            assert.equals("1 book", lower(text_of(screen.header.aside)))
        end)

        it("lays six tiles a page in three columns and two rows in D16's order", function()
            fixture.install(jemisin())
            each_look(function(id)
                local screen = fixture.show_authors({ kind = "author", name = JEMISIN })
                local ctx = screen.ctx
                local grid = ctx.look.library.grid
                local box = LibraryTiles.geometry(Screen:getWidth(), ctx, ctx.look.shelf.author_grid.cover_h)
                local top = LibraryChrome.detail_header_height(ctx) + Screen:scaleBySize(grid.padding_top)
                assert.same({ "The Fifth Season", "The Obelisk Gate", "The Stone Sky", "The Killing Moon",
                    "Dreamblood 2", "Emergency Skin" }, titles(screen), id)
                for i, tile in ipairs(screen.tiles) do
                    local column, row = (i - 1) % 3 + 1, math.floor((i - 1) / 3)
                    assert.same({ box.columns[column].x, top + row * (box.height + Screen:scaleBySize(grid.row_gap)),
                        box.cover_w, box.height }, { tile.rect.x, tile.rect.y, tile.rect.w, tile.rect.h }, id)
                    assert.equals(box.height, tile.widget:getSize().h, id)
                end
                assert.equals(2, screen.pages, id)
                screen:go({ kind = "author", name = JEMISIN }, 2)
                assert.same({ "How Long", "Inheritance", "Zulu Stories" }, titles(screen), id)
                assert.is_true(screen.tiles[3].rect.y + screen.tiles[3].rect.h <= screen.pager.prev.rect.y, id)
                harness.teardown()
            end)
        end)

        it("chips each series' next unread Up next, a path-less one keeping its badge", function()
            local books = jemisin()
            -- The Fifth Season complete: The Obelisk Gate is next; The Killing Moon is Dreamblood's.
            fixture.install(books, { [books[4].id] = { status = "complete", percent = 1 } })
            each_look(function(id)
                local screen = fixture.show_authors({ kind = "author", name = JEMISIN })
                local gate, moon = tile_of(screen, "The Obelisk Gate"), tile_of(screen, "The Killing Moon")
                assert.is_true(gate.up_next, id)
                assert.equals("up next", lower(text_of(gate.widget.chip[1])), id)
                assert.is_nil(gate.widget.badge, id)
                assert.is_true(moon.up_next, id)
                assert.equals("up next", lower(text_of(moon.widget.chip[1])), id)
                assert.is_table(moon.widget.badge, id)
                for _, title in ipairs({ "The Fifth Season", "The Stone Sky", "Dreamblood 2", "Emergency Skin" }) do
                    local tile = tile_of(screen, title)
                    assert.is_false(tile.up_next, id .. " " .. title)
                    assert.is_nil(tile.widget.chip, id .. " " .. title)
                end
                harness.teardown()
            end)
        end)

        it("marks none of the author's books when their series' next unread is a co-author's", function()
            local books = {
                fixture.book("Duet 1", { series = "Duet", series_index = 1, authors = { "Bo Other" } }),
                fixture.book("Duet 2", { series = "Duet", series_index = 2, authors = { JEMISIN } }),
            }
            fixture.install(books)
            local screen = fixture.show_authors({ kind = "author", name = JEMISIN })
            assert.same({ "Duet 2" }, titles(screen))
            assert.is_false(screen.tiles[1].up_next)
            assert.is_nil(screen.tiles[1].widget.chip)
        end)

        it("shows the list at page 1 for an author no entry has any more", function()
            fixture.install(shelf(38))
            local screen = fixture.show_authors({ kind = "author", name = "Gone" }, 2)
            assert.same(LIST, screen.showing)
            assert.equals(1, screen.page)
            assert.equals("authors", lower(text_of(screen.header.title)))
            assert.equals("Ann A01", screen.rows[1].entry.name)
        end)
    end)

    describe("paint", function()
        it("rebuilds before painting when the variant changed since its build", function()
            fixture.install(shelf(3))
            local screen = fixture.show_authors()
            local frame = screen[1]
            Looks.variant = function()
                return "night"
            end
            local bb = Blitbuffer.new(screen.dimen.w, screen.dimen.h, Blitbuffer.TYPE_BBRGB32)
            screen:paintTo(bb, 0, 0)
            bb:free()
            assert.equals("night", screen.ctx.variant)
            assert.is_not.equals(frame, screen[1])
            assert.equals(screen, AuthorsScreen.shown)
        end)

        it("rebuilds before painting when the screen's size changed since its build", function()
            fixture.install(shelf(3))
            local screen = fixture.show_authors({ kind = "author", name = "Ann A01" })
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
            assert.same({ kind = "author", name = "Ann A01" }, screen.showing)
        end)
    end)

    describe("kept current", function()
        it("re-lists the books on BookMetadataChanged and on InvalidateMetadataCache", function()
            local records = shelf(1)
            fixture.install(records)
            local screen = fixture.show_authors()
            local function names()
                local out = {}
                for i, row in ipairs(screen.rows) do
                    out[i] = row.entry.name
                end
                return out
            end
            assert.same({ "Ann A01" }, names())
            records[#records + 1] = fixture.book("New", { authors = { "Bo B02" } })
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            assert.same({ "Ann A01", "Bo B02" }, names())
            records[#records + 1] = fixture.book("Newer", { authors = { "Cy C03" } })
            UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", records[#records].path))
            assert.same({ "Ann A01", "Bo B02", "Cy C03" }, names())
            assert.equals(screen, harness.top())
        end)
    end)

    describe("the settled signal", function()
        it("is sent once per show after its first paint, with screen authors and a numeric paint_ms", function()
            local signals = {}
            settled_listener = function(args)
                signals[#signals + 1] = args
            end
            UIManager.event_hook:register("KoPandaSettled", settled_listener)
            fixture.install(shelf(38))
            local screen = fixture.show_authors()
            local function count()
                local n = 0
                for _, args in ipairs(signals) do
                    if args.screen == "authors" then
                        n = n + 1
                        assert.is_number(args.paint_ms)
                    end
                end
                return n
            end
            assert.equals(1, count())
            screen:go(LIST, 2)
            harness.tick(3)
            screen:go({ kind = "author", name = "Ann A01" }, 1)
            harness.tick(3)
            assert.equals(1, count())
            AuthorsScreen.close()
            AuthorsScreen.show{}
            harness.tick(3)
            assert.equals(2, count())
        end)
    end)
end)
