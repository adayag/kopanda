-- The Authors window (series-and-authors C5): the list's header (D10's count, "Authors", "By
-- surname"), its letter groups in D13's order a page at a time, a group split by a page break
-- repeating its letter, "#" after Z and the pager gap; one author's header (the back control, D10's
-- count, the name), six tiles in three columns and two rows in D16's order with the Up next chip (D5,
-- D19). The cases it shares with the Series window (spec/shelf_screen_cases.lua) run here for the
-- Authors window, AUTHORS carrying what differs. Books.all and Books.progress are stubbed with
-- records under a root that exists nowhere (spec/shelf_fixture.lua).
describe("the Authors window", function()
    local cases = require("shelf_screen_cases")
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local text_of = require("library_fixture").text
    local Event = require("ui/event")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local AuthorsScreen, LibraryChrome, LibraryTiles, Looks

    before_each(function()
        harness.load()
        AuthorsScreen = package.loaded["authors_screen"]
        LibraryChrome = package.loaded["library_chrome"]
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
    end)

    after_each(function()
        harness.teardown()
    end)

    local function lower(text)
        return text and text:lower()
    end

    local each_look = cases.each_look
    local LIST = cases.LIST
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

    local function tile_ids(screen)
        local out = {}
        for i, tile in ipairs(screen.tiles) do
            out[i] = tile.record.id
        end
        return out
    end

    -- Sixty authors with a book each, and Ann A01's "Saga", thirteen books, the first five finished:
    -- each view runs to more than one page.
    local function sorted_shelf()
        local records, progress = shelf(60), {}
        for i, record in ipairs(fixture.series("Saga", 13, "Ann A01")) do
            records[#records + 1] = record
            if i <= 5 then
                progress[record.id] = { status = "complete", percent = 1 }
            end
        end
        return records, progress
    end

    local ANN = { kind = "author", name = "Ann A01" }

    local AUTHORS = {
        name = "Authors",
        id = "authors",
        module = "authors_screen",
        Module = "AuthorsScreen",
        show = fixture.show_authors,
        shelf = function(n)
            return shelf(n)
        end,
        first = "Ann A01",
        detail = ANN,
        a_one = "an author",
        -- The window this one's show closes.
        before = {
            name = "the Series window",
            module = "series_screen",
            show = function()
                return fixture.show()
            end,
        },
        -- A shelf of at least pages pages.
        paged = { n = 38, pages = 2 },
        nav = { says = "Authors lit, in the list and one author", lit = "authors", views = { LIST, ANN } },
        empty = { note = "no authors yet", lists = { "groups", "rows" } },
        relist = {
            fixture.book("New", { authors = { "Bo B02" } }),
            fixture.book("Newer", { authors = { "Cy C03" } }),
        },
        relisted = { "Ann A01", "Bo B02", "Cy C03" },
        -- Each view and the sorts one of its builds runs: the list the authors alone, one author the
        -- authors and the whole library's series (D16). The list reads no progress.
        sorted = {
            install = sorted_shelf,
            cases = {
                { "the list", LIST, { authors = 1, series = 0 } },
                { "one author", ANN, { authors = 1, series = 1 } },
            },
            turned = { view = ANN, items = tile_ids },
        },
    }

    describe("the window", function()
        cases.window(AUTHORS)

        it("reads the books once per show, no progress for the list, each book's once per show", function()
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
            calls.progress = {}
            screen:go({ kind = "author", name = "Bo B02" }, 1)
            screen:go({ kind = "author", name = "Ann A01" }, 1)
            assert.same({}, calls.progress)
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

        cases.list(AUTHORS)
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

        cases.one(AUTHORS)
    end)

    describe("paint", function()
        cases.paint(AUTHORS)
    end)

    describe("kept current", function()
        cases.kept_current(AUTHORS)
    end)

    describe("kept sorted", function()
        cases.kept_sorted(AUTHORS)

        -- The sorted shelf installed; returns the calls (fixture.install's) and the sorts counted.
        local function install()
            local calls = fixture.install(sorted_shelf())
            return calls, cases.count_sorts()
        end

        it("reads one author's progress again at refresh() and at a metadata change", function()
            local calls = install()
            local screen = fixture.show_authors(ANN)
            calls.progress = {}
            screen:refresh()
            assert.is_true(#calls.progress > 0)
            calls.progress = {}
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            harness.tick(2)
            assert.is_true(#calls.progress > 0)
        end)

        it("sorts no more going from the list to an author and back", function()
            local calls, sorts = install()
            local screen = fixture.show_authors(LIST, 2)
            screen:go(ANN, 2)
            assert.same({ authors = 1, series = 1 }, sorts)
            screen:back()
            screen:go(ANN, 1)
            assert.same({ authors = 1, series = 1 }, sorts)
            assert.equals(1, calls.all)
        end)
    end)

    describe("the settled signal", function()
        cases.settled(AUTHORS)
    end)
end)
