-- The Subjects window: the list's header and rows by count a page at a time; one subject's header and six tiles a page
-- in title order; its taps, back, hit, the return after a book opened from it closes and the nav bar's Home and
-- Library tabs. The cases it shares with the Series and Authors windows (spec/shelf_screen_cases.lua) run here,
-- SUBJECTS carrying what differs. Books.all and Books.progress are stubbed with records under a root that exists
-- nowhere (spec/shelf_fixture.lua).
describe("the Subjects window", function()
    local cases = require("shelf_screen_cases")
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local library_fixture = require("library_fixture")
    local text_of, centre = library_fixture.text, library_fixture.centre
    local Event = require("ui/event")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local LibraryChrome, LibraryTiles, Looks, SubjectsScreen
    local util, real_open

    before_each(function()
        harness.load()
        LibraryChrome = package.loaded["library_chrome"]
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
        SubjectsScreen = package.loaded["subjects_screen"]
        util = require("apps/filemanager/filemanagerutil")
        real_open = util.openFile
    end)

    after_each(function()
        util.openFile = real_open
        harness.teardown()
    end)

    local function lower(text)
        return text and text:lower()
    end

    local each_look = cases.each_look
    local LIST = cases.LIST

    -- n subjects of one book each, "Subject 01" to "Subject n", on "Book 01" to "Book n".
    local function shelf(n)
        local records = {}
        for i = 1, n do
            records[i] = fixture.book(("Book %02d"):format(i), { subjects = { ("Subject %02d"):format(i) } })
        end
        return records
    end

    local function titles(screen)
        local out = {}
        for i, tile in ipairs(screen.tiles) do
            out[i] = tile.record.title
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

    local BIG = { kind = "subject", name = "Big" }

    local SUBJECTS = {
        name = "Subjects",
        id = "subjects",
        module = "subjects_screen",
        Module = "SubjectsScreen",
        show = fixture.show_subjects,
        shelf = function(n)
            return shelf(n)
        end,
        first = "Subject 01",
        detail = { kind = "subject", name = "Subject 01" },
        a_one = "a subject",
        -- The window this one's show closes.
        before = {
            name = "the Authors window",
            module = "authors_screen",
            show = function()
                return fixture.show_authors()
            end,
        },
        -- A shelf of at least pages pages.
        paged = { n = 14, pages = 3 },
        nav = { says = "no tab lit, in the list and one subject", views = { LIST, { kind = "subject",
            name = "Subject 01" } } },
        empty = { aside = "no subjects", note = "no subjects yet", lists = { "rows", "tiles" } },
        relist = {
            fixture.book("New", { subjects = { "Subject 02" } }),
            fixture.book("Newer", { subjects = { "Subject 03" } }),
        },
        relisted = { "Subject 01", "Subject 02", "Subject 03" },
        -- Thirty subjects of one book and Big's thirteen books: each view runs to more than one page. The list
        -- reads no progress; one subject reads each page's tiles' as it draws them.
        sorted = {
            install = function()
                local records = shelf(30)
                for i = 1, 13 do
                    records[#records + 1] = fixture.book(("Big %02d"):format(i), { subjects = { "Big" } })
                end
                return records
            end,
            sorts = { "subjects", "authors", "series" },
            cases = {
                { "the list", LIST, { subjects = 1, authors = 0, series = 0 } },
                { "one subject", BIG, { subjects = 1, authors = 0, series = 0 }, reads = true, reads_per_page = true },
            },
            turned = { view = BIG, items = tile_ids },
        },
    }

    describe("the window", function()
        cases.window(SUBJECTS)
    end)

    describe("the list", function()
        it("counts the subjects over Subjects and Most books first, on the subjects band, in each look", function()
            local wanted = { "no subjects", "1 subject", "14 subjects" }
            each_look(function(id)
                for i, n in ipairs({ 0, 1, 14 }) do
                    fixture.install(shelf(n))
                    local screen = fixture.show_subjects()
                    local header = screen.header
                    assert.equals(wanted[i], lower(text_of(header.aside)), id .. " case " .. i)
                    assert.equals("subjects", lower(text_of(header.title)), id)
                    assert.equals("most books first", lower(text_of(header.label)), id)
                    assert.is_nil(header.back_rect, id)
                    assert.equals(LibraryTiles.header_height(screen.ctx), header.rect.h, id)
                    local band = screen.ctx.look.shelf.subjects_fill_color
                    local palette = Looks.palette(screen.ctx.look, screen.ctx.variant)
                    assert.same(band and Looks.color(palette[band]) or nil, screen[1][1].fill_color, id)
                    harness.teardown()
                end
            end)
        end)

        it("lays the rows by count then name a page at a time, each with its book count and no chip", function()
            local records = {}
            local function tag(subject, n)
                for i = 1, n do
                    records[#records + 1] = fixture.book(subject .. " " .. i, { subjects = { subject } })
                end
            end
            tag("Zen", 2)
            tag("Art", 1)
            tag("Self-help", 3)
            tag("Cookery", 5)
            tag("Biography", 1)
            tag("Fitness", 3)
            tag("Travel", 2)
            -- A book under two subjects counts in both.
            records[#records + 1] = fixture.book("Both", { subjects = { "Travel", "Art" } })
            fixture.install(records)
            local wanted = { "Cookery 5 books", "Fitness 3 books", "Self-help 3 books", "Travel 3 books",
                "Art 2 books", "Zen 2 books", "Biography 1 book" }
            each_look(function(id)
                local screen = fixture.show_subjects()
                local tokens = screen.ctx.look.shelf
                local per_page = #screen.rows
                assert.is_true(screen.pages >= 2, id)
                local got = {}
                for page = 1, screen.pages do
                    screen:go(LIST, page)
                    if page < screen.pages then
                        assert.equals(per_page, #screen.rows, id .. " page " .. page)
                    end
                    local x = Screen:scaleBySize(tokens.list.side)
                    local y = screen.header.rect.h + Screen:scaleBySize(tokens.list.padding_top)
                    for _, row in ipairs(screen.rows) do
                        got[#got + 1] = row.entry.name .. " " .. lower(text_of(row.widget.sub))
                        assert.is_nil(row.widget.chip, id .. " " .. row.entry.name)
                        assert.same({ x, y, Screen:getWidth() - 2 * x }, { row.rect.x, row.rect.y, row.rect.w }, id)
                        assert.equals(row.widget:getSize().h, row.rect.h, id)
                        y = y + row.rect.h + Screen:scaleBySize(tokens.list.row_gap)
                    end
                    assert.is_true(y - Screen:scaleBySize(tokens.list.row_gap) <= screen.pager.prev.rect.y,
                        id .. ": the rows end above the pager")
                end
                assert.same(wanted, got, id)
                harness.teardown()
            end)
        end)

        cases.list(SUBJECTS)
    end)

    describe("one subject", function()
        local COOKERY = { kind = "subject", name = "Cookery" }

        -- Eight cookbooks shelved out of title order, one not downloaded, one also under Baking; and a
        -- book under Baking alone.
        local function cookery()
            local function cook(title, fields)
                fields = fields or {}
                fields.subjects = fields.subjects or { "Cookery" }
                return fields.remote and fixture.remote(title, fields) or fixture.book(title, fields)
            end
            return {
                cook("Salt Fat Acid Heat"),
                cook("Jerusalem"),
                cook("Ottolenghi Simple", { remote = true }),
                cook("Bread", { subjects = { "Baking", "Cookery" } }),
                cook("Zuni Cafe"),
                cook("Plenty"),
                cook("Dessert Person"),
                cook("Mastering the Art"),
                fixture.book("Flour", { subjects = { "Baking" } }),
            }
        end

        local function tile_of(screen, title)
            for _, tile in ipairs(screen.tiles) do
                if tile.record.title == title then
                    return tile
                end
            end
        end

        it("heads the subject with the back control over its book count and the name, the detail header's height",
            function()
            fixture.install(cookery())
            each_look(function(id)
                local screen = fixture.show_subjects(COOKERY)
                local header = screen.header
                assert.same(COOKERY, screen.showing, id)
                assert.equals("8 books", lower(text_of(header.aside)), id)
                assert.equals("cookery", lower(text_of(header.title)), id)
                assert.equals("subjects", lower(text_of(header.back_label)), id)
                assert.equals(LibraryChrome.detail_header_height(screen.ctx), header.rect.h, id)
                local band = screen.ctx.look.shelf.subjects_fill_color
                local palette = Looks.palette(screen.ctx.look, screen.ctx.variant)
                assert.same(band and Looks.color(palette[band]) or nil, screen[1][1].fill_color, id)
                harness.teardown()
            end)
            fixture.install(cookery())
            local screen = fixture.show_subjects({ kind = "subject", name = "Flour" })
            assert.same(LIST, screen.showing, "a name no subject has")
            screen:go({ kind = "subject", name = "Baking" }, 1)
            assert.equals("2 books", lower(text_of(screen.header.aside)))
        end)

        it("lays six tiles a page in three columns and two rows in the library's title order, no chip", function()
            fixture.install(cookery())
            each_look(function(id)
                local screen = fixture.show_subjects(COOKERY)
                local ctx = screen.ctx
                local grid = ctx.look.library.grid
                local header_h = LibraryChrome.detail_header_height(ctx)
                local box = LibraryTiles.geometry(Screen:getWidth(), ctx, {
                    cover_h = ctx.look.shelf.author_grid.cover_h,
                    room = LibraryTiles.room(Screen:getHeight(), ctx, header_h),
                })
                local top = header_h + Screen:scaleBySize(grid.padding_top)
                assert.same({ "Bread", "Dessert Person", "Jerusalem", "Mastering the Art", "Ottolenghi Simple",
                    "Plenty" }, titles(screen), id)
                for i, tile in ipairs(screen.tiles) do
                    local column, row = (i - 1) % 3 + 1, math.floor((i - 1) / 3)
                    assert.same({ box.columns[column].x, top + row * (box.height + Screen:scaleBySize(grid.row_gap)),
                        box.cover_w, box.height }, { tile.rect.x, tile.rect.y, tile.rect.w, tile.rect.h }, id)
                    assert.equals(box.height, tile.widget:getSize().h, id)
                    assert.is_nil(tile.widget.chip, id .. " " .. tile.record.title)
                end
                assert.equals(2, screen.pages, id)
                screen:go(COOKERY, 2)
                assert.same({ "Salt Fat Acid Heat", "Zuni Cafe" }, titles(screen), id)
                assert.is_true(screen.tiles[2].rect.y + screen.tiles[2].rect.h <= screen.pager.prev.rect.y, id)
                harness.teardown()
            end)
        end)

        it("opens a downloaded book on a tap, recording the return to the subject's page, and nothing without a file",
            function()
            fixture.install(cookery())
            local screen, fm = fixture.show_subjects(COOKERY, 2)
            local opened = {}
            util.openFile = function(ui, file, pre)
                opened[#opened + 1] = { ui = ui, file = file }
                pre()
            end
            local zuni = tile_of(screen, "Zuni Cafe")
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", centre(zuni.rect))))
            assert.equals(1, #opened)
            assert.same({ fm, zuni.record.path }, { opened[1].ui, opened[1].file })
            assert.same({ screen = "subjects", view = COOKERY, page = 2 }, LibraryChrome.return_to)
            LibraryChrome.return_to = nil
            screen:go(COOKERY, 1)
            local remote = tile_of(screen, "Ottolenghi Simple")
            assert.is_nil(remote.record.path)
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", centre(remote.rect))))
            assert.equals(1, #opened)
            assert.is_nil(LibraryChrome.return_to)
            assert.same(COOKERY, screen.showing)
            assert.equals(screen, harness.top())
        end)

        it("goes back to the list at the page holding the subject", function()
            local records = shelf(14)
            for _, record in ipairs(cookery()) do
                record.subjects = { "Subject 13" }
                records[#records + 1] = record
            end
            fixture.install(records)
            local screen = fixture.show_subjects()
            local first = screen.rows[1]
            assert.equals("Subject 13", first.entry.name)
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", centre(first.rect))))
            assert.same({ { kind = "subject", name = "Subject 13" }, 1 }, { screen.showing, screen.page })
            screen:go({ kind = "subject", name = "Subject 14" }, 1)
            screen:back()
            assert.same(LIST, screen.showing)
            assert.is_true(screen.page > 1)
            assert.equals("Subject 14", screen.rows[#screen.rows].entry.name)
        end)

        it("falls back to the list's first page when a refresh finds the subject gone", function()
            local records = cookery()
            fixture.install(records)
            local screen = fixture.show_subjects(COOKERY, 2)
            for _, record in ipairs(records) do
                record.subjects = { "Baking" }
            end
            screen:refresh()
            assert.same({ LIST, 1 }, { screen.showing, screen.page })
            assert.same({ "Baking" }, fixture.names(screen))
        end)

        cases.one(SUBJECTS)
    end)

    describe("hit", function()
        it("names the subject, the book or empty space under a point, and nil with none shown", function()
            local records = shelf(3)
            records[#records + 1] = fixture.remote("Untold", { subjects = { "Subject 01" } })
            fixture.install(records)
            assert.is_nil(SubjectsScreen.hit(10, 10))
            local screen = fixture.show_subjects()
            local row = screen.rows[1]
            assert.same({ kind = "subject", entry = row.entry }, SubjectsScreen.hit(row.rect.x, row.rect.y))
            assert.equals("subject",
                SubjectsScreen.hit(row.rect.x + row.rect.w - 1, row.rect.y + row.rect.h - 1).kind)
            local last = screen.rows[#screen.rows]
            assert.same({ kind = "empty" }, SubjectsScreen.hit(last.rect.x, last.rect.y + last.rect.h))
            assert.same({ kind = "empty" }, SubjectsScreen.hit(centre(screen.header.rect)))
            screen:go({ kind = "subject", name = "Subject 01" }, 1)
            local tile = screen.tiles[2]
            assert.equals("Untold", tile.record.title)
            assert.same({ kind = "book", record = tile.record }, SubjectsScreen.hit(centre(tile.rect)))
            assert.same({ kind = "empty" }, SubjectsScreen.hit(tile.rect.x + tile.rect.w, tile.rect.y))
            SubjectsScreen.close()
            assert.is_nil(SubjectsScreen.hit(10, 10))
        end)
    end)

    describe("the nav bar", function()
        it("closes the window onto the home on the Home tab", function()
            fixture.install(shelf(3))
            local screen = fixture.show_subjects()
            package.loaded["nav_bar"].run("home", "subjects")
            assert.is_nil(SubjectsScreen.shown)
            assert.is_false(UIManager:isWidgetShown(screen))
            local Home = package.loaded["home"]
            assert.is_not_nil(Home.shown)
            assert.equals(Home.shown, harness.top())
        end)

        it("shows the library in the window's place on the Library tab", function()
            fixture.install(shelf(3))
            local screen, fm = fixture.show_subjects()
            package.loaded["nav_bar"].run("library", "subjects")
            assert.is_nil(SubjectsScreen.shown)
            assert.is_false(UIManager:isWidgetShown(screen))
            local Library = package.loaded["library"]
            assert.is_not_nil(Library.shown)
            assert.equals(Library.shown, harness.top())
            assert.equals(fm, harness.top(2))
        end)
    end)

    -- A real book closes back to the window, as the Series and Authors windows' do (shelf_lifecycle_spec.lua): the
    -- open is stubbed at filemanagerutil.openFile and a case does what an open that goes ahead does.
    describe("after a book opened from the window closes", function()
        local ffiutil = require("ffi/util")
        local BOOK = harness.library .. "/frankenstein.epub"
        local ID = "file:" .. ffiutil.realpath(BOOK)
        local GOTHIC = { kind = "subject", name = "Gothic" }
        local opened

        -- Six spec books titled before it and the real book under Gothic: page 2 holds the real one alone.
        before_each(function()
            local records = {}
            for i = 1, 6 do
                records[i] = fixture.book("Dark " .. i, { subjects = { "Gothic" } })
            end
            records[7] = { id = ID, path = BOOK, title = "Frankenstein", authors = {}, subjects = { "Gothic" } }
            fixture.install(records)
            opened = nil
            util.openFile = function(ui, file, pre)
                opened = { ui = ui, file = file, pre = pre }
            end
        end)

        local function read_and_close()
            local reader = harness.open_reader()
            harness.tick(2)
            reader:onClose()
        end

        -- The window at Gothic's page 2 with its book tapped and the open gone ahead; the file manager.
        local function tapped()
            local screen, fm = fixture.show_subjects(GOTHIC, 2)
            assert.equals(ID, screen.tiles[1].record.id)
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", centre(screen.tiles[1].rect))))
            assert.equals(BOOK, opened.file)
            opened.pre()
            return screen, fm
        end

        it("shows the window again at the subject's page, the return taken", function()
            local _, fm = tapped()
            fm:onShowingReader()
            assert.is_nil(SubjectsScreen.shown)
            read_and_close()
            local new_fm = harness.show_fm()
            local shown = SubjectsScreen.shown
            assert.is_not_nil(shown)
            assert.equals(shown, harness.top())
            assert.equals(new_fm, harness.top(2))
            assert.is_nil(LibraryChrome.return_to)
            assert.same({ GOTHIC, 2 }, { shown.showing, shown.page })
        end)

        it("drops the return once the window has closed, so a book then opened closes to the home", function()
            local _, fm = tapped()
            assert.is_not_nil(LibraryChrome.return_to)
            package.loaded["nav_bar"].run("home", "subjects")
            fm:onShowingReader()
            read_and_close()
            harness.show_fm()
            harness.tick(2)
            assert.is_nil(SubjectsScreen.shown)
            assert.equals(package.loaded["home"].shown, harness.top())
        end)
    end)

    describe("paint", function()
        cases.paint(SUBJECTS)
    end)

    describe("kept current", function()
        cases.kept_current(SUBJECTS)
    end)

    describe("kept sorted", function()
        cases.kept_sorted(SUBJECTS)
    end)

    describe("the settled signal", function()
        cases.settled(SUBJECTS)
    end)
end)
