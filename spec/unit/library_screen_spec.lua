-- The library window (cover-grid C6): its header (the count in each look's words under the status,
-- the title or the back mark and the folder's name, the pickers' labels), the page's tiles in three
-- columns and two rows, the pager and its dead arrows, the empty note, the nav bar with Library
-- active, its rebuild on a variant or size change, its re-listing on the metadata events, and its
-- settled signal. Books.folder and Books.progress are stubbed with listings under a root that exists
-- nowhere (spec/library_fixture.lua).
describe("the library window", function()
    local harness = require("plugin_harness")
    local fixture = require("library_fixture")
    local Blitbuffer = require("ffi/blitbuffer")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local Library, LibraryOrder, LibraryTiles, Looks, NavBar, Settings, Typeset, settled_listener

    local ROOT = fixture.ROOT

    before_each(function()
        harness.load()
        Library = package.loaded["library"]
        LibraryOrder = package.loaded["library_order"]
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
        NavBar = package.loaded["nav_bar"]
        Settings = package.loaded["settings"]
        Typeset = package.loaded["typeset"]
    end)

    after_each(function()
        if settled_listener then
            UIManager.event_hook:unregister("KoPandaSettled", settled_listener)
            settled_listener = nil
        end
        fixture.restore()
        harness.teardown()
    end)

    local function scale(px)
        return Screen:scaleBySize(px)
    end

    local function lower(text)
        return text and text:lower()
    end

    local function each_look(fn)
        for _, id in ipairs({ "diner", "editorial" }) do
            assert.is_true(Settings.set("look", id))
            fn(id)
        end
    end

    local function line_h(part, ctx)
        local line = Typeset.line(part, "Library", Screen:getWidth(), ctx)
        local h = line:getSize().h
        line:free()
        return h
    end

    describe("the window", function()
        it("shows full-screen over the file manager as Library.shown", function()
            fixture.install({ [ROOT] = { books = fixture.books(2) } })
            local library, fm = fixture.show()
            assert.equals("kopanda_library", library.name)
            assert.is_true(library.covers_fullscreen)
            assert.equals(library, Library.shown)
            assert.equals(fm, harness.top(2))
            assert.same(Screen:getSize(), library.dimen)
            Library.close()
            assert.is_nil(Library.shown)
            assert.equals(fm, harness.top())
        end)

        it("closes a library already shown before showing another, storing where the first was left", function()
            local sub = fixture.folder("Sci-fi")
            fixture.install({ [ROOT] = { folders = { sub } }, [sub.path] = { books = fixture.books(8, sub.path) } })
            local first = fixture.show()
            first:go(sub.path, 2)
            local second = Library.show{ dir = ROOT }
            local libraries = 0
            for _, widget in ipairs(harness.stack()) do
                if widget.name == "kopanda_library" then
                    libraries = libraries + 1
                end
            end
            assert.equals(1, libraries)
            assert.is_false(UIManager:isWidgetShown(first))
            assert.equals(second, Library.shown)
            assert.is_true(UIManager:isWidgetShown(second))
            assert.same({ dir = sub.path, page = 2 }, LibraryOrder.left())
        end)
    end)

    describe("the header", function()
        it("counts the folder's books under the status in each look's words, folders not counted", function()
            local reading = fixture.books(6)
            local progress = {
                [reading[2].id] = { status = "reading", percent = 0.2 },
                [reading[5].id] = { status = "reading", percent = 0.7 },
            }
            local wanted = {
                diner = { "no books on the shelf", "1 book on the shelf", "6 books on the shelf",
                    "2 books on the shelf" },
                editorial = { "no books", "1 book", "6 books", "2 books" },
            }
            each_look(function(id)
                local cases = {
                    { books = {}, folders = { fixture.folder("Empty") } },
                    { books = fixture.books(1), folders = { fixture.folder("Sci-fi") } },
                    { books = reading, folders = { fixture.folder("Sci-fi") } },
                }
                for i, listing in ipairs(cases) do
                    fixture.install({ [ROOT] = listing }, progress)
                    local library = fixture.show()
                    assert.equals(wanted[id][i], lower(fixture.text(library.header.count)), id .. " case " .. i)
                    harness.teardown()
                end
                fixture.install({ [ROOT] = cases[3] }, progress)
                assert.is_true(LibraryOrder.choose(ROOT, nil, "reading"))
                local library = fixture.show()
                assert.equals(wanted[id][4], lower(fixture.text(library.header.count)), id .. " under Reading")
                assert.is_true(LibraryOrder.choose(ROOT, nil, "all"))
                harness.teardown()
            end)
        end)

        it("titles the root Library with no back mark and a sub-folder by its name after the back mark", function()
            local sub = fixture.folder("Sci-fi")
            fixture.install({ [ROOT] = { folders = { sub } }, [sub.path] = { books = fixture.books(2, sub.path) } })
            each_look(function(id)
                local library = fixture.show()
                assert.equals("Library", fixture.text(library.header.title), id)
                assert.is_nil(library.header.back, id)
                library:go(sub.path, 1)
                assert.equals("Sci-fi", fixture.text(library.header.title), id)
                assert.is_not_nil(library.header.back, id)
                local back, title = library.header.back_place, library.header.title_place
                assert.is_true(back.x < title.x, id .. ": the mark comes before the name")
                harness.teardown()
            end)
        end)

        it("labels the pickers with the folder's sort and status", function()
            fixture.install({ [ROOT] = { books = fixture.books(2) } })
            local library = fixture.show()
            local function labels_of(shown)
                return { lower(fixture.text(shown.header.sort.label)), lower(fixture.text(shown.header.status.label)) }
            end
            assert.same({ "recent", "all" }, labels_of(library))
            Library.close()
            local labels = {
                recent = "recent", title = "title", author = "author", series = "series",
                reading = "reading", finished = "finished", all = "all",
            }
            for _, choice in ipairs({ { "title", "reading" }, { "author", "finished" }, { "series", "all" } }) do
                assert.is_true(LibraryOrder.choose(ROOT, choice[1], choice[2]))
                library = Library.show{ dir = ROOT }
                assert.same({ labels[choice[1]], labels[choice[2]] }, labels_of(library))
                Library.close()
            end
        end)

        -- LibraryTiles.header_height counts a picker as its label line and the title as its line, so
        -- each mark drawn beside one is no taller than it.
        it("sizes the pickers' marks and the back mark to their lines, the header the fit's height", function()
            local sub = fixture.folder("Sci-fi")
            fixture.install({ [ROOT] = { folders = { sub } } })
            each_look(function(id)
                local library = fixture.show(sub.path)
                local ctx, header = library.ctx, library.header
                local picker_h = line_h(ctx.look.type.library_picker, ctx)
                assert.equals(picker_h, header.sort.mark.size, id)
                assert.equals(picker_h, header.status.mark.size, id)
                assert.equals(line_h(ctx.look.type.library_title, ctx), header.back.size, id)
                assert.equals(LibraryTiles.header_height(ctx), header.rect.h, id)
                harness.teardown()
            end)
        end)
    end)

    describe("the page", function()
        it("lays six items, folders first, in three columns and two rows at the geometry's boxes", function()
            local listing = { books = fixture.books(5), folders = { fixture.folder("Sci-fi") } }
            each_look(function(id)
                fixture.install({ [ROOT] = listing })
                local library = fixture.show()
                local box, grid = library.box, library.ctx.look.library.grid
                local top = library.header.rect.h + scale(grid.padding_top)
                assert.equals(6, #library.tiles, id)
                assert.same({ "folder", "book", "book", "book", "book", "book" }, (function()
                    local kinds = {}
                    for i, tile in ipairs(library.tiles) do
                        kinds[i] = tile.kind
                    end
                    return kinds
                end)(), id)
                assert.equals("Sci-fi", library.tiles[1].folder.name, id)
                assert.equals("Book 01", library.tiles[2].record.title, id)
                for i, tile in ipairs(library.tiles) do
                    local column, row = (i - 1) % 3 + 1, math.floor((i - 1) / 3)
                    assert.same(Geom:new{
                        x = box.columns[column].x,
                        y = top + row * (box.height + scale(grid.row_gap)),
                        w = box.cover_w,
                        h = box.height,
                    }, tile.rect, id .. " tile " .. i)
                end
                harness.teardown()
            end)
        end)

        it("shows the empty note in each status's words and page 1 of 1 for a folder with nothing to show", function()
            local listing = { books = fixture.books(2) }
            fixture.install({ [ROOT] = listing }, {})
            local wanted = {
                all = "no books here",
                finished = "no finished books here",
                reading = "no books being read here",
            }
            for _, status in ipairs({ "finished", "reading" }) do
                assert.is_true(LibraryOrder.choose(ROOT, nil, status))
                local library = Library.show{ dir = ROOT }
                assert.equals(wanted[status], lower(fixture.text(library.note)), status)
                assert.same({}, library.tiles, status)
                assert.same({ 1, 1 }, { library.page, library.pages }, status)
                assert.is_false(library.pager.prev.live, status)
                assert.is_false(library.pager.next.live, status)
                Library.close()
            end
            fixture.install({ [ROOT] = {} })
            assert.is_true(LibraryOrder.choose(ROOT, nil, "all"))
            local library = Library.show{ dir = ROOT }
            assert.equals(wanted.all, lower(fixture.text(library.note)))
            Library.close()
            fixture.install({ [ROOT] = listing })
            library = Library.show{ dir = ROOT }
            assert.is_nil(library.note)
        end)
    end)

    describe("the pager", function()
        it("labels the page in each look's words, the first page's previous and the last's next dead", function()
            fixture.install({ [ROOT] = { books = fixture.books(14) } })
            local wanted = {
                diner = { "page 1 of 3", "page 2 of 3", "page 3 of 3" },
                editorial = { "1 / 3", "2 / 3", "3 / 3" },
            }
            each_look(function(id)
                local library = fixture.show()
                for page, live in ipairs({ { false, true }, { true, true }, { true, false } }) do
                    library:go(ROOT, page)
                    assert.equals(page, library.page, id)
                    assert.equals(3, library.pages, id)
                    assert.equals(wanted[id][page], lower(fixture.text(library.pager.label)), id .. " page " .. page)
                    assert.same(live, { library.pager.prev.live, library.pager.next.live }, id .. " page " .. page)
                end
                library:go(ROOT, 9)
                assert.equals(3, library.page, id .. ": a page past the end is the last")
                assert.equals(2, #library.tiles, id)
                harness.teardown()
            end)
        end)

        it("sits centred above the nav bar", function()
            fixture.install({ [ROOT] = { books = fixture.books(8) } })
            each_look(function(id)
                local library = fixture.show()
                local prev, next = library.pager.prev.rect, library.pager.next.rect
                local pager = library.ctx.look.library.pager
                local height = LibraryTiles.pager_height(library.ctx)
                local band = height - scale(pager.bottom)
                assert.equals(library.nav.dimen.y - height + math.floor((band - prev.h) / 2), prev.y, id)
                assert.equals(prev.y, next.y, id)
                assert.is_true(math.abs(Screen:getWidth() - (next.x + next.w) - prev.x) <= 1, id)
                assert.same({ scale(pager.button_w), scale(pager.button_h) }, { prev.w, prev.h }, id)
                harness.teardown()
            end)
        end)
    end)

    describe("the nav bar", function()
        it("sits at the bottom across the width with Library active", function()
            fixture.install({ [ROOT] = { books = fixture.books(2) } })
            each_look(function(id)
                local library = fixture.show()
                local nav = library.nav
                assert.equals("library", nav.where, id)
                assert.equals("library", NavBar.TABS[nav.active].id, id)
                assert.same({ 0, Screen:getHeight() - NavBar.height(library.ctx.look, Screen), Screen:getWidth() },
                    { nav.dimen.x, nav.dimen.y, nav.dimen.w }, id)
                harness.teardown()
            end)
        end)
    end)

    describe("paint", function()
        local function pixel(bb, x, y)
            local c = bb:getPixel(x, y):getColorRGB32()
            return { c:getR(), c:getG(), c:getB() }
        end

        local function rgb(hex)
            local c = Looks.color(hex)
            return { c:getR(), c:getG(), c:getB() }
        end

        local function near(a, b, tolerance)
            return math.abs(a[1] - b[1]) <= tolerance and math.abs(a[2] - b[2]) <= tolerance
                and math.abs(a[3] - b[3]) <= tolerance
        end

        -- The library's frame painted on a white buffer of the screen's size.
        local function painted(library)
            local bb = Blitbuffer.new(library.dimen.w, library.dimen.h, Blitbuffer.TYPE_BBRGB32)
            bb:fill(Blitbuffer.COLOR_WHITE)
            library[1]:paintTo(bb, 0, 0)
            return bb
        end

        -- The pixels within rect, inset by inset on each side, near role's colour in the library's
        -- palette.
        local function count(library, bb, rect, inset, name)
            local wanted = rgb(Looks.palette(library.ctx.look, library.ctx.variant)[name])
            local n = 0
            for y = rect.y + inset, rect.y + rect.h - inset - 1 do
                for x = rect.x + inset, rect.x + rect.w - inset - 1 do
                    if near(wanted, pixel(bb, x, y), 8) then
                        n = n + 1
                    end
                end
            end
            return n
        end

        -- The status chip sits on pink and the next arrow on mustard, so by night their marks stay
        -- on_accent, dark (looks/diner.lua:53), while the sort chip's label on paper is the light ink.
        it("keeps Diner's status picker and next arrow dark on their fills by night", function()
            Looks.variant = function()
                return "night"
            end
            fixture.install({ [ROOT] = { books = fixture.books(8) } })
            local library = fixture.show()
            assert.equals("night", library.ctx.variant)
            local bb = painted(library)
            local inset = scale(2)
            local status, sort, next = library.header.status.rect, library.header.sort.rect, library.pager.next.rect
            assert.is_true(count(library, bb, status, inset, "on_accent") > 0, "the status chip's label")
            assert.equals(0, count(library, bb, status, inset, "ink"), "the status chip's light pixels")
            assert.is_true(count(library, bb, sort, inset, "ink") > 0, "the sort chip's label")
            assert.is_true(count(library, bb, next, inset, "on_accent") > 0, "the next arrow")
            assert.equals(0, count(library, bb, next, inset, "ink"), "the next box's light pixels")
            bb:free()
        end)

        -- toybox.md: the pickers 2 px ink pills on paper, their corners the page's.
        it("draws Toybox's pickers as ink pills on paper", function()
            fixture.install({ [ROOT] = { books = fixture.books(2) } })
            assert.is_true(Settings.set("look", "toybox"))
            local library = fixture.show()
            local bb = painted(library)
            local palette = Looks.palette(library.ctx.look, library.ctx.variant)
            for _, name in ipairs({ "sort", "status" }) do
                local rect = library.header[name].rect
                local mid = rect.y + math.floor(rect.h / 2)
                assert.is_true(near(rgb(palette.outline), pixel(bb, rect.x, mid), 8), name .. " round its left end")
                assert.is_true(near(rgb(palette.outline), pixel(bb, rect.x + math.floor(rect.w / 2), rect.y), 8),
                    name .. " along its top")
                assert.is_true(near(rgb(palette.paper), pixel(bb, rect.x, rect.y), 8), name .. "'s corner is round")
            end
            bb:free()
        end)

        it("draws a dead arrow in Editorial's hairline and leaves it out of Diner's box", function()
            fixture.install({ [ROOT] = { books = fixture.books(8) } })
            assert.is_true(Settings.set("look", "editorial"))
            local library = fixture.show()
            local bb = painted(library)
            local prev, next = library.pager.prev.rect, library.pager.next.rect
            assert.is_true(count(library, bb, prev, 0, "hairline") > 0, "Editorial's dead arrow")
            assert.equals(0, count(library, bb, prev, 0, "ink"), "Editorial's dead arrow in ink")
            assert.is_true(count(library, bb, next, 0, "ink") > 0, "Editorial's live arrow")
            bb:free()
            harness.teardown()
            assert.is_true(Settings.set("look", "diner"))
            library = fixture.show()
            bb = painted(library)
            prev = library.pager.prev.rect
            local inset = scale(2)
            local inner = (prev.w - 2 * inset) * (prev.h - 2 * inset)
            assert.equals(inner, count(library, bb, prev, inset, "paper"), "Diner's dead box holds only paper")
            bb:free()
        end)

        it("rebuilds before painting when the variant changed since its build", function()
            fixture.install({ [ROOT] = { books = fixture.books(2) } })
            local library = fixture.show()
            local frame = library[1]
            assert.equals("day", library.ctx.variant)
            Looks.variant = function()
                return "night"
            end
            local bb = Blitbuffer.new(library.dimen.w, library.dimen.h, Blitbuffer.TYPE_BBRGB32)
            library:paintTo(bb, 0, 0)
            bb:free()
            assert.equals("night", library.ctx.variant)
            assert.is_not.equals(frame, library[1])
            assert.equals(library, Library.shown)
        end)

        it("rebuilds before painting when the screen's size changed since its build", function()
            fixture.install({ [ROOT] = { books = fixture.books(2) } })
            local library = fixture.show()
            local frame = library[1]
            local get_size = Screen.getSize
            Screen.getSize = function()
                return Geom:new{ x = 0, y = 0, w = 800, h = 600 }
            end
            local ok, err = pcall(function()
                local bb = Blitbuffer.new(800, 600, Blitbuffer.TYPE_BBRGB32)
                library:paintTo(bb, 0, 0)
                bb:free()
            end)
            Screen.getSize = get_size
            assert.is_true(ok, tostring(err))
            assert.same({ 800, 600 }, { library.dimen.w, library.dimen.h })
            assert.equals(800, library.nav.dimen.w)
            assert.is_not.equals(frame, library[1])
            assert.equals(library, Library.shown)
        end)
    end)

    describe("kept current", function()
        it("re-lists the folder on BookMetadataChanged and on InvalidateMetadataCache", function()
            local listing = { books = fixture.books(2) }
            fixture.install({ [ROOT] = listing })
            local library = fixture.show()
            assert.equals(2, #library.tiles)
            listing.books[3] = fixture.book("Book 03")
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            harness.tick()
            assert.equals(3, #library.tiles)
            assert.equals("Book 03", library.tiles[3].record.title)
            listing.books[4] = fixture.book("Book 04")
            UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", listing.books[4].path))
            harness.tick()
            assert.equals(4, #library.tiles)
            assert.equals(library, harness.top())
        end)

        -- LibraryView.build counted from after the show; a metadata change's events, as the book-info
        -- editor broadcasts them (filemanagerbookinfo.lua:276-280, :556-557), sent to the shown
        -- library, then between(library) if given, then the UI loop run twice.
        local function builds_after(events, between)
            fixture.install({ [ROOT] = { books = fixture.books(2) } })
            local library = fixture.show()
            local LibraryView = package.loaded["library_view"]
            local build = LibraryView.build
            local builds = 0
            LibraryView.build = function(...)
                builds = builds + 1
                return build(...)
            end
            local ok, err = pcall(function()
                for _, event in ipairs(events) do
                    UIManager:broadcastEvent(Event:new(event))
                end
                if between then
                    between(library)
                end
                harness.tick(2)
            end)
            LibraryView.build = build
            assert.is_true(ok, tostring(err))
            return builds
        end

        it("rebuilds once for one change's InvalidateMetadataCache and BookMetadataChanged", function()
            assert.equals(1, builds_after({ "InvalidateMetadataCache", "BookMetadataChanged" }))
        end)

        it("rebuilds once when the summary changed too", function()
            assert.equals(1, builds_after({ "InvalidateMetadataCache", "BookMetadataChanged", "BookMetadataChanged" }))
        end)

        it("rebuilds once for a lone BookMetadataChanged", function()
            assert.equals(1, builds_after({ "BookMetadataChanged" }))
        end)

        it("does not rebuild a library closed between the events and the tick", function()
            assert.equals(0, builds_after({ "InvalidateMetadataCache", "BookMetadataChanged" }, function()
                Library.close()
            end))
            assert.is_nil(Library.shown)
        end)
    end)

    -- context-menu C1, D1 ("Hidden folders"): on a real folder, so Books.folder and Books.all read the disk.
    describe("hidden folders", function()
        local lfs = require("libs/libkoreader-lfs")
        local dir = os.getenv("KO_HOME") .. "/library-hidden"
        local made = {}

        local function copy(path)
            local from = assert(io.open(harness.library .. "/frankenstein.epub", "rb"))
            local to = assert(io.open(path, "wb"))
            to:write(from:read("*a"))
            from:close()
            to:close()
            table.insert(made, 1, path)
        end

        local function mkdir(path)
            assert(lfs.mkdir(path))
            table.insert(made, 1, path)
        end

        before_each(function()
            made = {}
            mkdir(dir)
            mkdir(dir .. "/Hidden")
            mkdir(dir .. "/Shown")
            copy(dir .. "/top.epub")
            copy(dir .. "/Hidden/inside.epub")
            G_reader_settings:saveSetting("home_dir", dir)
        end)

        after_each(function()
            for _, path in ipairs(made) do
                os.remove(path)
            end
        end)

        it("drops a hidden sub-folder's tile, the count kept, while Books.folder and Books.all list it", function()
            local library = fixture.show(dir)
            local count = fixture.text(library.header.count)
            assert.same({ "Hidden", "Shown" }, { library.tiles[1].folder.name, library.tiles[2].folder.name })
            assert.equals(3, #library.tiles)
            assert.is_true(LibraryOrder.hide(dir .. "/Hidden"))
            library:refresh()
            assert.equals(2, #library.tiles)
            assert.equals("Shown", library.tiles[1].folder.name)
            assert.equals("book", library.tiles[2].kind)
            assert.equals(count, fixture.text(library.header.count))
            local Books = package.loaded["books"]
            local names = {}
            for i, folder in ipairs(Books.folder(dir).folders) do
                names[i] = folder.name
            end
            assert.same({ "Hidden", "Shown" }, names)
            local inside = false
            for _, record in ipairs(Books.all()) do
                inside = inside or (record.path or ""):match("/Hidden/inside%.epub$") ~= nil
            end
            assert.is_true(inside, "Books.all lists the hidden folder's book")
            assert.is_true(LibraryOrder.unhide(dir .. "/Hidden"))
            library:refresh()
            assert.equals(3, #library.tiles)
        end)
    end)

    -- context-menu C1, C5, D6: KOReader's home folder changed under the shown library (Set as library
    -- root's OK, whose ConfirmBox close marks the library dirty, frontend/ui/uimanager.lua:349-353).
    describe("the root", function()
        local sub

        before_each(function()
            sub = fixture.folder("Sci-fi")
            fixture.install({
                [ROOT] = { books = fixture.books(8), folders = { sub } },
                [sub.path] = { books = fixture.books(8, sub.path) },
            })
        end)

        it("shows the new root at page 1 on the next paint after home_dir changes, recorded as left", function()
            local library = fixture.show(ROOT, 2)
            assert.equals(2, library.page)
            G_reader_settings:saveSetting("home_dir", sub.path)
            UIManager:setDirty(library, "ui")
            harness.tick(2)
            assert.same({ sub.path, 1 }, { library.dir, library.page })
            assert.equals("Library", fixture.text(library.header.title))
            assert.is_nil(library.header.back)
            assert.same({ dir = sub.path, page = 1 }, LibraryOrder.left())
            assert.equals(library, Library.shown)
            assert.equals(library, harness.top())
        end)

        it("does not rebuild on a paint with the root unchanged", function()
            local library = fixture.show(ROOT, 2)
            local frame = library[1]
            local left = LibraryOrder.left()
            UIManager:setDirty(library, "ui")
            harness.tick(2)
            assert.equals(frame, library[1])
            assert.same({ ROOT, 2 }, { library.dir, library.page })
            assert.same(left, LibraryOrder.left())
        end)

        it("leaves where it was left unchanged when the new root fails to build", function()
            local library = fixture.show(ROOT, 2)
            local frame = library[1]
            local left = LibraryOrder.left()
            local LibraryView = package.loaded["library_view"]
            local build = LibraryView.build
            LibraryView.build = function(dir, page)
                if dir == sub.path then
                    error("kopanda-test: the new root failed to build")
                end
                return build(dir, page)
            end
            G_reader_settings:saveSetting("home_dir", sub.path)
            UIManager:setDirty(library, "ui")
            harness.tick(2)
            assert.equals(frame, library[1])
            assert.same({ ROOT, 2 }, { library.dir, library.page })
            assert.same(left, LibraryOrder.left())
        end)
    end)

    describe("the settled signal", function()
        it("is sent once per show after its first paint, with screen library and a numeric paint_ms", function()
            local signals = {}
            settled_listener = function(args)
                signals[#signals + 1] = args
            end
            UIManager.event_hook:register("KoPandaSettled", settled_listener)
            fixture.install({ [ROOT] = { books = fixture.books(8) } })
            local library = fixture.show()
            local function libraries()
                local n = 0
                for _, args in ipairs(signals) do
                    if args.screen == "library" then
                        n = n + 1
                        assert.is_number(args.paint_ms)
                    end
                end
                return n
            end
            assert.equals(1, libraries())
            library:go(ROOT, 2)
            harness.tick(3)
            assert.equals(1, libraries())
            Library.close()
            Library.show{ dir = ROOT }
            harness.tick(3)
            assert.equals(2, libraries())
        end)
    end)
end)
