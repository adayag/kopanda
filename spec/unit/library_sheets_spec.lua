-- The hold's dispatch (context-menu C7, "Holds", D3, D16): LibrarySheets.hold opens the book sheet
-- for a book held on the library, on one series and on one author, over that window as the screen
-- beneath, its paint_ms from the hold, and opens nothing for a series row, an author row or empty
-- space on the Series and Authors windows. The held books are files under KO_HOME, so the sheet's
-- check that the file is still there passes. The folder sheet (C5, "The folder sheet", D6, D11,
-- D12) opens for a folder tile on the library alone, and the empty-space sheet (C6, "The empty-space
-- sheet", D9, D10, D15) for any other hold there, its Refresh covers against the real CoverBrowser.
-- luacheck: read globals load_plugin

-- As books_coverbrowser_spec.lua: KOReader's sqlite binding can be loaded once per process, and
-- Refresh covers' case loads the real CoverBrowser, which requires it.
expose("KOReader's sqlite binding, loaded once for the process", function()
    require("lua-ljsqlite3/init")
end)

describe("LibrarySheets.hold", function()
    local harness = require("plugin_harness")
    local library_fixture = require("library_fixture")
    local shelf_fixture = require("shelf_fixture")
    local ConfirmBox = require("ui/widget/confirmbox")
    local Event = require("ui/event")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")
    local centre = library_fixture.centre
    local LibrarySheets, Sheet

    local dir = os.getenv("KO_HOME") .. "/library-sheets-books"
    local settled, listener

    -- A file under dir named name, copied from the fixture library's EPUB.
    local function file(name)
        local path = dir .. "/" .. name
        local from = assert(io.open(harness.library .. "/frankenstein.epub", "rb"))
        local to = assert(io.open(path, "wb"))
        to:write(from:read("*a"))
        from:close()
        to:close()
        return path
    end

    before_each(function()
        harness.load()
        LibrarySheets = package.loaded["library_sheets"]
        Sheet = package.loaded["sheet"]
        if not lfs.attributes(dir, "mode") then
            assert(lfs.mkdir(dir))
        end
        settled = {}
        listener = function(args)
            if args.screen == "sheet" then
                settled[#settled + 1] = args
            end
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
    end)

    after_each(function()
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        library_fixture.restore()
        harness.teardown()
    end)

    -- A stamp 200 ms before now, so a paint_ms that runs from it is at least 200.
    local function earlier()
        return { wall = time.monotonic() - time.ms(200), cpu = os.clock() }
    end

    -- Holds hit on window with the stamp of earlier(), then asserts the book sheet of record is shown
    -- over window, its paint_ms from that stamp and its settled signal named book.
    local function assert_book_sheet(window, hit, record)
        local started = earlier()
        LibrarySheets.hold(window, hit, started)
        local sheet = Sheet.shown
        assert.is_not_nil(sheet)
        assert.equals("book", sheet.spec.name)
        assert.equals(record.title, sheet.spec.header.title)
        assert.equals(window, sheet.beneath)
        assert.equals(started, sheet.started)
        assert.equals(sheet, harness.top())
        assert.equals(window, harness.top(2))
        harness.tick(3)
        assert.equals(1, #settled)
        assert.equals("book", settled[1].name)
        assert.truthy(settled[1].paint_ms >= 200, settled[1].paint_ms)
    end

    it("opens the book sheet over the library for a book held there", function()
        local path = file("library.epub")
        local record = { id = "file:" .. path, path = path, title = "Held Book", authors = { "Ann Author" } }
        library_fixture.install({ [library_fixture.ROOT] = { books = { record } } })
        local library = library_fixture.show()
        local Library = package.loaded["library"]
        local hit = Library.hit(centre(library.tiles[1].rect))
        assert.equals("book", hit.kind)
        assert_book_sheet(library, hit, record)
    end)

    describe("on the Series window", function()
        local record

        before_each(function()
            local books = shelf_fixture.series("Moons", 2)
            record = books[1]
            record.path = file("series.epub")
            shelf_fixture.install(books)
        end)

        it("opens the book sheet over one series for a book held there", function()
            local screen = shelf_fixture.show({ kind = "series", name = "Moons" })
            local SeriesScreen = package.loaded["series_screen"]
            local hit = SeriesScreen.hit(centre(screen.rows[1].rect))
            assert.same({ kind = "book", record = record }, hit)
            assert_book_sheet(screen, hit, record)
        end)

        it("opens nothing for a series row, empty space or no hit", function()
            local screen = shelf_fixture.show()
            local SeriesScreen = package.loaded["series_screen"]
            local series = SeriesScreen.hit(centre(screen.rows[1].rect))
            assert.equals("series", series.kind)
            local open_record = spy.on(package.loaded["book_sheet"], "open_record")
            for _, hit in ipairs({ series, { kind = "empty" } }) do
                LibrarySheets.hold(screen, hit, earlier())
                assert.is_nil(Sheet.shown)
                assert.equals(screen, harness.top())
            end
            LibrarySheets.hold(screen, nil, earlier())
            assert.is_nil(Sheet.shown)
            assert.spy(open_record).was_not_called()
            harness.tick(3)
            assert.same({}, settled)
        end)

        -- D3: the folder sheet is the library's; a folder hit here opens nothing.
        it("opens nothing for a folder hit", function()
            local screen = shelf_fixture.show()
            LibrarySheets.hold(screen, { kind = "folder", folder = { name = "Moons", path = "/moons" } }, earlier())
            assert.is_nil(Sheet.shown)
            assert.equals(screen, harness.top())
        end)
    end)

    describe("on the Authors window", function()
        local record

        before_each(function()
            record = shelf_fixture.book("Held", { authors = { "Ann Author" } })
            record.path = file("authors.epub")
            shelf_fixture.install({ record })
        end)

        it("opens the book sheet over one author for a book held there", function()
            local screen = shelf_fixture.show_authors({ kind = "author", name = "Ann Author" })
            local AuthorsScreen = package.loaded["authors_screen"]
            local hit = AuthorsScreen.hit(centre(screen.tiles[1].rect))
            assert.same({ kind = "book", record = record }, hit)
            assert_book_sheet(screen, hit, record)
        end)

        it("opens nothing for an author row or empty space", function()
            local screen = shelf_fixture.show_authors()
            local AuthorsScreen = package.loaded["authors_screen"]
            local author = AuthorsScreen.hit(centre(screen.rows[1].rect))
            assert.equals("author", author.kind)
            local open_record = spy.on(package.loaded["book_sheet"], "open_record")
            for _, hit in ipairs({ author, { kind = "empty" } }) do
                LibrarySheets.hold(screen, hit, earlier())
                assert.is_nil(Sheet.shown)
                assert.equals(screen, harness.top())
            end
            assert.spy(open_record).was_not_called()
            harness.tick(3)
            assert.same({}, settled)
        end)

        it("opens nothing for a folder hit", function()
            local screen = shelf_fixture.show_authors()
            LibrarySheets.hold(screen, { kind = "folder", folder = { name = "Ann", path = "/ann" } }, earlier())
            assert.is_nil(Sheet.shown)
            assert.equals(screen, harness.top())
        end)
    end)

    describe("the folder sheet on the library", function()
        local ROOT = library_fixture.ROOT
        local Library, LibraryOrder, Looks

        before_each(function()
            Library = package.loaded["library"]
            LibraryOrder = package.loaded["library_order"]
            Looks = package.loaded["looks"]
        end)

        -- Holds the library's tile i, a folder's; returns the sheet shown.
        local function hold_folder(library, i)
            local hit = Library.hit(centre(library.tiles[i].rect))
            assert.equals("folder", hit.kind)
            LibrarySheets.hold(library, hit, earlier())
            return Sheet.shown
        end

        local function place_of(label)
            for _, place in ipairs(Sheet.shown.rows) do
                if place.row.label == label then
                    return place
                end
            end
            error("no row " .. label)
        end

        local function tap(label)
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", centre(place_of(label).rect))))
        end

        local function shown(class)
            for _, widget in ipairs(harness.stack()) do
                if getmetatable(widget) == class then
                    return widget
                end
            end
        end

        -- A sub-folder of the root holding eight books, with the root's eight books after it.
        local function sub_and_books()
            local sub = library_fixture.folder("Hugo winners")
            library_fixture.install({
                [ROOT] = { folders = { sub }, books = library_fixture.books(8) },
                [sub.path] = { books = library_fixture.books(8, sub.path) },
            })
            return sub
        end

        it("heads with the folder's name and the meta of its books, reading and finished each when not zero", function()
            -- Folders whose names keep this order: no books; one; 14 with 3 reading and 6 finished;
            -- 14 with 6 finished; 14 with 3 reading.
            local cases = {
                { name = "Alpha", books = 0, meta = "No books" },
                { name = "Bravo", books = 1, meta = "1 book" },
                { name = "Charlie", books = 14, reading = 3, finished = 6, meta = "14 books · 3 reading · 6 finished" },
                { name = "Delta", books = 14, finished = 6, meta = "14 books · 6 finished" },
                { name = "Echo", books = 14, reading = 3, meta = "14 books · 3 reading" },
            }
            local listings, progress, folders = {}, {}, {}
            for i, case in ipairs(cases) do
                local folder = library_fixture.folder(case.name)
                folders[i] = folder
                local books = library_fixture.books(case.books, folder.path)
                for j, book in ipairs(books) do
                    if j <= (case.reading or 0) then
                        progress[book.id] = { status = "reading", percent = 0.4 }
                    elseif j <= (case.reading or 0) + (case.finished or 0) then
                        progress[book.id] = { status = "complete" }
                    end
                end
                listings[folder.path] = { books = books }
            end
            listings[ROOT] = { folders = folders }
            library_fixture.install(listings, progress)
            local library = library_fixture.show()
            for i, case in ipairs(cases) do
                local sheet = hold_folder(library, i)
                assert.is_not_nil(sheet, case.name)
                assert.equals("library_folder", sheet.spec.name)
                assert.equals("library_folder", sheet.spec.band)
                assert.equals(case.name, sheet.spec.header.title)
                assert.is_nil(sheet.spec.header.author)
                assert.equals(case.meta, sheet.spec.header.meta, case.name)
                assert.equals(library, sheet.beneath)
                assert.equals(sheet, harness.top())
                assert.equals(library, harness.top(2))
                local rows = {}
                for j, row in ipairs(sheet.spec.rows) do
                    rows[j] = { row.icon, row.label, row.sublabel }
                end
                assert.same({
                    { "folder_open", "Open" },
                    { "library", "Set as library root", "The Library tab opens here" },
                    { "eye_off", "Hide", "Still on the Kindle, gone from the grid" },
                }, rows)
                harness.tick(3)
                assert.equals(i, #settled)
                assert.equals("library_folder", settled[i].name)
                assert.truthy(settled[i].paint_ms >= 200, settled[i].paint_ms)
                Sheet.close()
            end
        end)

        it("draws the folder icon in its box tinted in the look's ink, by day and by night", function()
            local Icons = package.loaded["icons"]
            local TintedIcon = package.loaded["tinted_icon"]
            sub_and_books()
            local library = library_fixture.show()
            local function scale(px)
                return Screen:scaleBySize(px)
            end
            for _, id in ipairs({ "diner", "editorial" }) do
                for _, variant in ipairs({ "day", "night" }) do
                    local where = id .. " " .. variant
                    local look = Looks.get(id)
                    local palette = Looks.palette(look, variant)
                    local tokens = look.sheet.folder_box
                    library.ctx = { look = look, variant = variant, screen = Screen }
                    local box = hold_folder(library, 1).spec.header.cover
                    assert.same({ scale(60), scale(60) }, { box:getSize().w, box:getSize().h }, where)
                    assert.equals(Looks.color(palette.paper), box.fill_color, where)
                    assert.equals(scale(tokens.outline_width), box.outline, where)
                    assert.equals(Looks.color(palette[tokens.outline_color]), box.outline_color, where)
                    local icon = box[1]
                    assert.equals(TintedIcon, getmetatable(icon), where)
                    assert.equals(Icons.path("folder"), icon.file, where)
                    assert.equals(scale(34), icon.size, where)
                    assert.equals(Looks.color(palette.ink), icon.color, where)
                    local at = math.floor((scale(60) - scale(34)) / 2)
                    assert.same({ x = at, y = at }, box.places[1], where)
                    Sheet.close()
                end
            end
            assert.is_not.equals(Looks.color(Looks.palette(Looks.get("diner"), "day").ink),
                Looks.color(Looks.palette(Looks.get("diner"), "night").ink))
        end)

        it("opens the folder at its remembered page on Open", function()
            local sub = sub_and_books()
            assert.is_true(LibraryOrder.leave(sub.path, 2))
            local library = library_fixture.show()
            hold_folder(library, 1)
            tap("Open")
            assert.is_nil(Sheet.shown)
            assert.same({ sub.path, 2 }, { library.dir, library.page })
            assert.equals(library, harness.top())
        end)

        it("asks to set the folder as HOME; OK sets home_dir, the next paint showing it at page 1, left", function()
            local sub = sub_and_books()
            local library = library_fixture.show()
            hold_folder(library, 1)
            tap("Set as library root")
            local box = shown(ConfirmBox)
            assert.is_not_nil(box)
            assert.equals(box, harness.top())
            assert.truthy(box.text:find("as HOME folder?", 1, true), box.text)
            assert.truthy(box.text:find(sub.path, 1, true), box.text)
            assert.equals("Set as HOME", box.ok_text)
            assert.same({ ROOT, 1 }, { library.dir, library.page })
            -- As its OK button does (frontend/ui/widget/confirmbox.lua:115-121).
            box.ok_callback()
            UIManager:close(box)
            harness.tick(2)
            assert.equals(sub.path, G_reader_settings:readSetting("home_dir"))
            assert.same({ sub.path, 1 }, { library.dir, library.page })
            assert.same({ dir = sub.path, page = 1 }, LibraryOrder.left())
            assert.equals(library, harness.top())
        end)

        it("changes nothing when the HOME confirm is cancelled", function()
            sub_and_books()
            local library = library_fixture.show()
            local frame = library[1]
            local left = LibraryOrder.left()
            hold_folder(library, 1)
            tap("Set as library root")
            local box = shown(ConfirmBox)
            assert.is_not_nil(box)
            -- As its Cancel button does (frontend/ui/widget/confirmbox.lua:108-114).
            box.cancel_callback()
            UIManager:close(box)
            harness.tick(2)
            assert.equals(ROOT, G_reader_settings:readSetting("home_dir"))
            assert.same({ ROOT, 1 }, { library.dir, library.page })
            assert.equals(frame, library[1])
            assert.same(left, LibraryOrder.left())
            assert.equals(library, harness.top())
        end)

        it("hides the folder and re-lists the library at its page without its tile", function()
            local sub = sub_and_books()
            local library = library_fixture.show()
            assert.equals("Book 05", library.tiles[6].record.title)
            hold_folder(library, 1)
            tap("Hide")
            assert.is_nil(Sheet.shown)
            assert.is_true(LibraryOrder.is_hidden(sub.path))
            assert.same({ ROOT, 1 }, { library.dir, library.page })
            assert.equals(6, #library.tiles)
            for i, tile in ipairs(library.tiles) do
                assert.equals("book", tile.kind)
                assert.equals(("Book %02d"):format(i), tile.record.title)
            end
            assert.equals(library, harness.top())
        end)

        -- Seven sub-folders, so the seventh's tile opens page 2 (six tiles a page), with n books
        -- (Book 01, ...) after them.
        local function seven_folders(n)
            local folders = {}
            for i, name in ipairs({ "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf" }) do
                folders[i] = library_fixture.folder(name)
            end
            library_fixture.install({ [ROOT] = { folders = folders, books = library_fixture.books(n) } })
            return folders[7]
        end

        it("hides a folder held on page 2 and keeps the library on page 2 without its tile", function()
            local golf = seven_folders(3)
            local library = library_fixture.show(ROOT, 2)
            assert.equals(2, library.page)
            assert.equals("Golf", library.tiles[1].folder.name)
            hold_folder(library, 1)
            tap("Hide")
            assert.is_nil(Sheet.shown)
            assert.is_true(LibraryOrder.is_hidden(golf.path))
            assert.same({ ROOT, 2 }, { library.dir, library.page })
            assert.equals(3, #library.tiles)
            for i, tile in ipairs(library.tiles) do
                assert.equals("book", tile.kind)
                assert.equals(("Book %02d"):format(i), tile.record.title)
            end
            assert.equals(library, harness.top())
        end)

        it("clamps to the last page when hiding empties page 2", function()
            local golf = seven_folders(0)
            local library = library_fixture.show(ROOT, 2)
            assert.equals(1, #library.tiles)
            assert.equals("Golf", library.tiles[1].folder.name)
            hold_folder(library, 1)
            tap("Hide")
            assert.is_true(LibraryOrder.is_hidden(golf.path))
            assert.same({ ROOT, 1 }, { library.dir, library.page })
            assert.equals(6, #library.tiles)
            for _, tile in ipairs(library.tiles) do
                assert.is_not.equals("Golf", tile.folder.name)
            end
            assert.equals(library, harness.top())
        end)

        -- With the kept listing (TW-cypagc): the Hide lists the folder once, and the listing it keeps
        -- leaves the folder out on every page turned to after, without listing again.
        it("hides a folder after page turns that did not list, and no turn after brings it back", function()
            local folders = {}
            for i, name in ipairs({ "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf" }) do
                folders[i] = library_fixture.folder(name)
            end
            local calls = library_fixture.install({ [ROOT] = { folders = folders, books = library_fixture.books(3) } })
            local library = library_fixture.show(ROOT, 1)
            library:turn(1)
            library:turn(-1)
            local listed = #calls
            assert.equals("Alpha", library.tiles[1].folder.name)
            hold_folder(library, 1)
            tap("Hide")
            assert.equals(listed + 1, #calls)
            local names = {}
            for page = 1, 2 do
                if page == 2 then
                    library:turn(1)
                end
                for _, tile in ipairs(library.tiles) do
                    names[#names + 1] = tile.folder and tile.folder.name or tile.record.title
                end
            end
            library:turn(-1)
            assert.equals("Bravo", library.tiles[1].folder.name)
            assert.same({ "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Book 01", "Book 02", "Book 03" },
                names)
            assert.equals(listed + 1, #calls)
        end)
    end)
    describe("the empty-space sheet on the library", function()
        local ROOT = library_fixture.ROOT
        local BookCovers, Library, LibraryOrder, Settings

        before_each(function()
            BookCovers = package.loaded["book_covers"]
            Library = package.loaded["library"]
            LibraryOrder = package.loaded["library_order"]
            Settings = package.loaded["settings"]
        end)

        -- Holds the library at (x, y), which must be empty space, with the stamp of earlier();
        -- returns the sheet shown.
        local function hold_empty(library, x, y)
            local hit = Library.hit(x, y)
            assert.same({ kind = "empty" }, hit)
            LibrarySheets.hold(library, hit, earlier())
            return Sheet.shown
        end

        -- A point of empty space on the library: below the last row of tiles, above the pager.
        local function grid_space(library)
            local last = library.tiles[#library.tiles].rect
            return last.x + math.floor(last.w / 2), math.floor((last.y + last.h + library.pager.prev.rect.y) / 2)
        end

        local function rows_of(sheet)
            local rows = {}
            for i, row in ipairs(sheet.spec.rows) do
                rows[i] = { row.icon, row.label, row.detail, row.chip, row.sublabel }
            end
            return rows
        end

        local function place_of(label)
            for _, place in ipairs(Sheet.shown.rows) do
                if place.row.label == label then
                    return place
                end
            end
            error("no row " .. label)
        end

        local function tap(label)
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", centre(place_of(label).rect))))
        end

        -- With CoverBrowser disabled, as book_covers_spec.lua stubs it, restored in finally.
        local function without_coverbrowser()
            local loaded, preload = package.loaded.bookinfomanager, package.preload.bookinfomanager
            package.loaded.bookinfomanager = nil
            package.preload.bookinfomanager = function() error("CoverBrowser is disabled") end
            finally(function()
                package.loaded.bookinfomanager = loaded
                package.preload.bookinfomanager = preload
            end)
        end

        it("heads with this folder above Library at the root and the folder's name below it, and the header's count "
            .. "in each look", function()
            local sub = library_fixture.folder("Hugo winners")
            local progress = {}
            local sub_books = library_fixture.books(5, sub.path)
            for i = 1, 3 do
                progress[sub_books[i].id] = { status = "reading", percent = 0.2 }
            end
            library_fixture.install({
                [ROOT] = { folders = { sub }, books = library_fixture.books(8) },
                [sub.path] = { books = sub_books },
            }, progress)
            assert.is_true(LibraryOrder.choose(sub.path, nil, "reading"))
            local counts = {
                diner = { root = "8 books on the shelf", sub = "3 books on the shelf" },
                editorial = { root = "8 books", sub = "3 books" },
            }
            local library = library_fixture.show()
            for _, id in ipairs({ "diner", "editorial" }) do
                assert.is_true(Settings.set("look", id))
                library:go(ROOT, 1)
                harness.tick(2)
                settled = {}
                -- The grid's space, the header and the pager (D15).
                local points = { { grid_space(library) }, { 5, 5 }, { centre(library.pager.prev.rect) } }
                for i, point in ipairs(points) do
                    local sheet = hold_empty(library, point[1], point[2])
                    assert.is_not_nil(sheet, id .. " " .. i)
                    assert.equals("library_empty", sheet.spec.name)
                    assert.equals("library_empty", sheet.spec.band)
                    assert.same({ aside = "this folder", aside_above = true, heading = "Library",
                        label = counts[id].root }, sheet.spec.header, id .. " " .. i)
                    assert.equals(library, sheet.beneath)
                    assert.equals(sheet, harness.top())
                    assert.equals(library, harness.top(2))
                    harness.tick(3)
                    assert.equals(i, #settled, id .. " " .. i)
                    assert.equals("library_empty", settled[i].name)
                    assert.truthy(settled[i].paint_ms >= 200, settled[i].paint_ms)
                    Sheet.close()
                end
                library:open_folder(sub)
                harness.tick(2)
                local sheet = hold_empty(library, 5, 5)
                assert.same({ aside = "this folder", aside_above = true, heading = "Hugo winners",
                    label = counts[id].sub }, sheet.spec.header, id)
                Sheet.close()
            end
        end)

        it("carries the folder's sort and show and opens the pickers' sheets", function()
            library_fixture.install({ [ROOT] = { books = library_fixture.books(3) } })
            assert.is_true(LibraryOrder.choose(ROOT, "title", "finished"))
            without_coverbrowser()
            local library = library_fixture.show()
            local sheet = hold_empty(library, 5, 5)
            assert.same({
                { "sort", "Sort", "Title ›", "sort" },
                { "filter", "Show", "Finished ›", "show" },
                { "refresh", "Refresh covers", nil, nil, "Re-reads covers for this folder" },
            }, rows_of(sheet))
            for _, case in ipairs({ { "Sort", "sort" }, { "Show", "status" } }) do
                settled = {}
                hold_empty(library, 5, 5)
                tap(case[1])
                assert.is_not_nil(Sheet.shown, case[1])
                assert.equals(case[2], Sheet.shown.spec.name)
                assert.equals(Library, Sheet.shown.beneath)
                assert.equals(library, harness.top(2))
                harness.tick(3)
                assert.equals(case[2], settled[#settled].name)
                Sheet.close()
            end
            LibraryOrder.choose(ROOT, "author", "all")
            library:refresh()
            assert.same({ "Author ›", "All ›" }, { rows_of(hold_empty(library, 5, 5))[1][3],
                rows_of(Sheet.shown)[2][3] })
        end)

        it("greys Refresh covers with CoverBrowser disabled, a tap running nothing", function()
            library_fixture.install({ [ROOT] = { books = library_fixture.books(3) } })
            without_coverbrowser()
            local forget = spy.on(BookCovers, "forget")
            local library = library_fixture.show()
            local frame = library[1]
            local sheet = hold_empty(library, 5, 5)
            local row = sheet.spec.rows[3]
            assert.equals("Refresh covers", row.label)
            assert.is_true(row.muted)
            assert.is_nil(row.run)
            tap("Refresh covers")
            assert.is_nil(Sheet.shown)
            assert.equals(frame, library[1])
            assert.equals(library, harness.top())
            assert.spy(forget).was_not_called()
        end)

        describe("Refresh covers against the real CoverBrowser", function()
            local BookList = require("ui/widget/booklist")
            local SPECS = { max_cover_w = 150, max_cover_h = 225 }
            local bim, paths

            before_each(function()
                package.loaded["bookinfomanager"] = nil
                package.preload["bookinfomanager"] = nil
                -- As books_coverbrowser_spec.lua loads it: through PluginLoader:_load, once
                -- harness.load() has reset enabled_plugins.
                load_plugin("coverbrowser.koplugin")
                bim = assert(package.loaded["bookinfomanager"], "CoverBrowser did not load bookinfomanager")
                BookCovers = package.loaded["book_covers"]
                BookCovers.reset()
                if not lfs.attributes(dir .. "/sub", "mode") then
                    assert(lfs.mkdir(dir .. "/sub"))
                end
                paths = { a = file("refresh-a.epub"), b = file("refresh-b.epub"), c = file("sub/refresh-c.epub") }
                for _, path in pairs(paths) do
                    bim:extractBookInfo(path, SPECS)
                    BookList.book_info_cache[path] = { been_opened = false }
                end
            end)

            after_each(function()
                for _, path in pairs(paths) do
                    bim:deleteBookInfo(path)
                    BookList.resetBookInfoCache(path)
                end
                BookCovers.reset()
                package.loaded["bookinfomanager"] = nil
            end)

            it("deletes the folder's rows, re-lists and asks for every book of the folder in one request", function()
                local function record(path)
                    return { id = "file:" .. path, path = path, title = path:match("([^/]+)%.epub$"), authors = {} }
                end
                -- Two books with rows, a path-less one and six more with files of no row, so the
                -- folder's books with a file run past the first page (a folder and five books).
                local sub = library_fixture.folder("sub", dir)
                local books = { record(paths.a), record(paths.b), library_fixture.remote("Far Away") }
                for _, book in ipairs(library_fixture.books(6, dir)) do
                    books[#books + 1] = book
                end
                library_fixture.install({
                    [dir] = { folders = { sub }, books = books },
                    [sub.path] = { books = { record(paths.c) } },
                })
                G_reader_settings:saveSetting("home_dir", dir)
                local extracted = {}
                local extract = bim.extractInBackground
                bim.extractInBackground = function(_, files)
                    extracted[#extracted + 1] = files
                    return true
                end
                finally(function()
                    bim.extractInBackground = extract
                end)
                local library = library_fixture.show(dir)
                harness.tick(3)
                for _, path in pairs(paths) do
                    assert.is_not_nil(bim:getBookInfo(path, false), path)
                end
                local frame = library[1]
                extracted = {}
                hold_empty(library, 5, 5)
                tap("Refresh covers")
                assert.is_nil(Sheet.shown)
                assert.is_nil(bim:getBookInfo(paths.a, false))
                assert.is_nil(bim:getBookInfo(paths.b, false))
                assert.is_not_nil(bim:getBookInfo(paths.c, false))
                assert.is_nil(BookList.book_info_cache[paths.a])
                assert.is_nil(BookList.book_info_cache[paths.b])
                assert.is_not_nil(BookList.book_info_cache[paths.c])
                assert.are_not.equal(frame, library[1])
                assert.same({ dir, 1 }, { library.dir, library.page })
                assert.same({}, extracted)
                assert.equals(2, library.pages)
                harness.tick(3)
                local specs = { max_cover_w = library.box.cover_w, max_cover_h = library.box.cover_h }
                local wanted = {}
                for _, book in ipairs(books) do
                    if book.path then
                        wanted[#wanted + 1] = { filepath = book.path, cover_specs = specs }
                    end
                end
                assert.equals(8, #wanted)
                assert.same({ wanted }, extracted)
                assert.equals(library, harness.top())
            end)
        end)

        describe("Hidden folders", function()
            -- Seven folders, so the seventh is on page 2 (six tiles a page), with three books after
            -- them; the root's listing. The listing holds them in reverse (The Golf first), so only the
            -- grid's own order puts them in title order.
            local NAMES = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "The Golf" }

            local function seven_folders()
                local folders, listed = {}, {}
                for i, name in ipairs(NAMES) do
                    folders[i] = library_fixture.folder(name)
                    listed[#NAMES + 1 - i] = folders[i]
                end
                library_fixture.install({ [ROOT] = { folders = listed, books = library_fixture.books(3) } })
                return folders
            end

            it("shows no Hidden folders row with none of this folder's hidden", function()
                seven_folders()
                -- Hidden, but not a sub-folder of this one.
                LibraryOrder.hide(ROOT .. "/elsewhere/Alpha")
                local library = library_fixture.show()
                local sheet = hold_empty(library, 5, 5)
                for _, row in ipairs(sheet.spec.rows) do
                    assert.is_not.equals("Hidden folders", row.label)
                end
                assert.equals(3, #sheet.spec.rows)
            end)

            it("lists the hidden sub-folders in the grid's folder order, a tap unhiding one at the library's page",
                function()
                local folders = seven_folders()
                for _, i in ipairs({ 7, 3, 2 }) do
                    assert.is_true(LibraryOrder.hide(folders[i].path))
                end
                local library = library_fixture.show(ROOT, 1)
                for _, tile in ipairs(library.tiles) do
                    assert.is_false(tile.kind == "folder" and tile.folder.name == "Charlie")
                end
                local sheet = hold_empty(library, 5, 5)
                local rows = sheet.spec.rows
                assert.equals(4, #rows)
                assert.same({ "eye_off", "Hidden folders", "›" }, { rows[4].icon, rows[4].label, rows[4].detail })
                settled = {}
                tap("Hidden folders")
                sheet = Sheet.shown
                assert.is_not_nil(sheet)
                assert.equals("library_hidden", sheet.spec.name)
                assert.equals("library_empty", sheet.spec.band)
                assert.is_true(sheet.spec.flush)
                assert.same({ aside = "tap one to show it again", aside_above = true, heading = "Hidden folders",
                    label = "Library" }, sheet.spec.header)
                local labels = {}
                for i, row in ipairs(sheet.spec.rows) do
                    assert.is_nil(row.icon)
                    labels[i] = row.label
                end
                assert.same({ "Bravo", "Charlie", "The Golf" }, labels)
                assert.equals(library, sheet.beneath)
                assert.equals(library, harness.top(2))
                harness.tick(3)
                assert.equals(1, #settled)
                assert.equals("library_hidden", settled[1].name)
                -- Charlie's tile comes back on page 1, the library still there.
                tap("Charlie")
                assert.is_nil(Sheet.shown)
                assert.is_false(LibraryOrder.is_hidden(folders[3].path))
                assert.is_true(LibraryOrder.is_hidden(folders[2].path))
                assert.same({ ROOT, 1 }, { library.dir, library.page })
                local names = {}
                for i, tile in ipairs(library.tiles) do
                    names[i] = tile.folder and tile.folder.name or tile.record.title
                end
                assert.same({ "Alpha", "Charlie", "Delta", "Echo", "Foxtrot", "Book 01" }, names)
                assert.equals(library, harness.top())
            end)

            it("keeps the library at its page when a tap unhides a folder", function()
                local folders = seven_folders()
                assert.is_true(LibraryOrder.hide(folders[1].path))
                local library = library_fixture.show(ROOT, 2)
                assert.equals(2, library.page)
                hold_empty(library, 5, 5)
                tap("Hidden folders")
                tap("Alpha")
                assert.same({ ROOT, 2 }, { library.dir, library.page })
                assert.equals("The Golf", library.tiles[1].folder.name)
                assert.equals(4, #library.tiles)
            end)
        end)
    end)
end)
