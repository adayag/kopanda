-- The library's kept listing (TW-cypagc): the folder's listing, its history times and its progress
-- memo are kept from the build that listed the folder, so a page turn only slices them and a picker
-- choice only filters and sorts them again, while a show, a folder change and refresh() list the
-- folder again. Run on a scratch library under the data directory, the real Books.folder over it,
-- CoverBrowser stubbed with a row per file that counts the reads without a cover, and the cover
-- request stubbed.
describe("the library's kept listing", function()
    local Blitbuffer = require("ffi/blitbuffer")
    local harness = require("plugin_harness")
    local fixture = require("library_fixture")
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local ReadHistory = require("readhistory")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local Books, Library, LibraryCovers, LibraryOrder, LibraryView, Looks, Sheet

    local lib = DataStorage:getDataDir() .. "/library-listing"
    local other = DataStorage:getDataDir() .. "/library-listing-other"

    local loaded_bim, saved_hist
    local listed, rows_read, files

    local function touch(path)
        local f = assert(io.open(path, "wb"))
        f:write("not really a book")
        f:close()
    end

    -- n empty files book-01.epub … in dir; row_for gives each its title and an author whose order
    -- runs against the titles.
    local function fill(dir, n)
        lfs.mkdir(dir)
        for i = 1, n do
            local path = ("%s/book-%02d.epub"):format(dir, i)
            touch(path)
            files[#files + 1] = path
        end
    end

    local function row_for(path)
        local i = tonumber(path:match("book%-(%d+)%.epub$"))
        return { title = ("Book %02d"):format(i), authors = "Author " .. string.char(string.byte("Z") - i) }
    end

    before_each(function()
        harness.load()
        Books = package.loaded["books"]
        Library = package.loaded["library"]
        LibraryCovers = package.loaded["library_covers"]
        LibraryOrder = package.loaded["library_order"]
        LibraryView = package.loaded["library_view"]
        Looks = package.loaded["looks"]
        Sheet = package.loaded["sheet"]
        local BookCovers = package.loaded["book_covers"]
        BookCovers.request = function() end
        BookCovers.cancel = function() end
        files = {}
        fill(lib, 13)
        fill(other, 4)
        listed, rows_read = {}, 0
        loaded_bim = package.loaded["bookinfomanager"]
        package.loaded["bookinfomanager"] = {
            getBookInfo = function(_, file, get_cover)
                if get_cover == false then
                    rows_read = rows_read + 1
                end
                return row_for(file)
            end,
        }
        local folder = Books.folder
        Books.folder = function(dir)
            listed[#listed + 1] = dir
            return folder(dir)
        end
        saved_hist = ReadHistory.hist
        ReadHistory.hist = {}
    end)

    after_each(function()
        fixture.restore()
        harness.teardown()
        package.loaded["bookinfomanager"] = loaded_bim
        ReadHistory.hist = saved_hist
        for _, path in ipairs(files) do
            os.remove(path)
        end
        os.remove(lib)
        os.remove(other)
    end)

    -- The library shown at dir and page, painted and settled, the counts zeroed after its show.
    local function show(dir, page)
        local library = fixture.show(dir or lib, page)
        listed, rows_read = {}, 0
        return library
    end

    local function counts()
        return { listed = #listed, rows_read = rows_read }
    end

    local function tile_ids(library)
        local out = {}
        for i, tile in ipairs(library.tiles) do
            out[i] = tile.record.id
        end
        return out
    end

    local function tap_on(rect)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", fixture.centre(rect))))
    end

    local function row_of(label)
        for _, place in ipairs(Sheet.shown.rows) do
            if place.row.label == label then
                return place
            end
        end
    end

    it("lists the folder on a show and not on a page turn either way", function()
        local library = fixture.show(lib)
        assert.same({ lib }, listed)
        assert.equals(13, rows_read)
        listed, rows_read = {}, 0
        library:turn(1)
        assert.equals(2, library.page)
        assert.same({ listed = 0, rows_read = 0 }, counts())
        library:turn(1)
        assert.equals(3, library.page)
        library:turn(-1)
        assert.equals(2, library.page)
        assert.same({ listed = 0, rows_read = 0 }, counts())
    end)

    it("lists once on a folder change and once on refresh()", function()
        local library = show()
        library:go(other, 1)
        assert.equals(other, library.dir)
        assert.same({ listed = 1, rows_read = 4 }, counts())
        listed, rows_read = {}, 0
        library:refresh()
        assert.same({ listed = 1, rows_read = 4 }, counts())
        listed, rows_read = {}, 0
        library:go(lib, 1)
        assert.same({ listed = 1, rows_read = 13 }, counts())
    end)

    it("filters and sorts the kept listing again on a picker choice, without listing it", function()
        local library = show()
        library:turn(1)
        tap_on(library.header.sort.rect)
        tap_on(row_of("Author").rect)
        assert.same({ lib, 1 }, { library.dir, library.page })
        assert.same({ listed = 0, rows_read = 0 }, counts())
        -- Book 13 is by "Author M", the first surname; Book 01 by "Author Y".
        assert.equals("Book 13", library.tiles[1].record.title)
        tap_on(library.header.sort.rect)
        tap_on(row_of("Title").rect)
        assert.same({ listed = 0, rows_read = 0 }, counts())
        assert.equals("Book 01", library.tiles[1].record.title)
    end)

    it("shows on page 2 by a turn the tiles a library built at page 2 shows", function()
        local library = show()
        library:turn(1)
        local direct = LibraryView.build(lib, 2)
        finally(function()
            direct.frame:free()
        end)
        assert.same({ direct.page, direct.pages }, { library.page, library.pages })
        assert.equals(6, #library.tiles)
        assert.same(tile_ids(direct), tile_ids(library))
    end)

    it("opens a rebuilt file book's sidecar once for its record and its progress", function()
        local DocSettings = require("docsettings")
        local library = show()
        local record = library.tiles[1].record
        local sdr = DocSettings:getSidecarDir(record.path, "doc")
        local side = sdr .. "/" .. DocSettings.getSidecarFilename(record.path)
        lfs.mkdir(sdr)
        local f = assert(io.open(side, "wb"))
        f:write('return { doc_props = { title = "Sidecar" }, percent_finished = 0.4 }')
        f:close()
        local open, opened = DocSettings.openSettingsFile, 0
        DocSettings.openSettingsFile = function(...)
            opened = opened + 1
            return open(...)
        end
        finally(function()
            DocSettings.openSettingsFile = open
            os.remove(side)
            os.remove(sdr)
        end)
        Books.reset()
        assert.equals(1, LibraryCovers.rebuild_tiles(library, { [record.id] = true }, "the spec's rebuild"))
        assert.equals(1, opened)
        assert.equals("Book 01", library.tiles[1].record.title)
        assert.equals(0.4, library.kept.seen[library.tiles[1].record].percent)
    end)

    it("sorts with a tile's record read again on the next build, without listing", function()
        local library = show()
        local first = library.tiles[1].record
        assert.equals("Book 01", first.title)
        local fresh = {}
        for k, v in pairs(first) do
            fresh[k] = v
        end
        fresh.title = "Zebra Stripes"
        Books.with_progress = function(path)
            if path == fresh.path then
                return fresh, { status = "new" }
            end
        end
        assert.equals(1, LibraryCovers.rebuild_tiles(library, { [fresh.id] = true }, "the spec's rebuild"))
        assert.equals("Zebra Stripes", library.tiles[1].record.title)
        -- No history: the recent order falls back to the titles, so the next build moves the
        -- renamed book to the end, as a fresh listing would.
        library:turn(1)
        library:turn(-1)
        assert.equals("Book 02", library.tiles[1].record.title)
        library:turn(1)
        library:turn(1)
        assert.same({ "Zebra Stripes" }, { library.tiles[1].record.title })
        assert.same({ listed = 0, rows_read = 0 }, counts())
    end)

    it("reads the closed book's progress again when a library pre-built at another page turns to it", function()
        -- The fixture's listing in place of the scratch one: 13 books all reading, under the reading
        -- status in title order; Book 01 closes finished after the library was pre-built at page 2.
        local books = fixture.books(13)
        local progress = {}
        for _, book in ipairs(books) do
            progress[book.id] = { status = "reading", percent = 0.5 }
        end
        fixture.install({ [fixture.ROOT] = { books = books } }, progress)
        assert.is_true(LibraryOrder.choose(fixture.ROOT, "title", "reading"))
        harness.show_fm()
        harness.tick(2)
        require("home").close()
        local LibraryChrome = package.loaded["library_chrome"]
        LibraryChrome.prebuild(Library, { dir = fixture.ROOT, page = 2 }, books[1].path)
        progress[books[1].id] = { status = "complete" }
        local library = Library.show{ widget = LibraryChrome.take_pending() }
        harness.tick(2)
        assert.equals(2, library.page)
        library:turn(-1)
        assert.equals("Book 02", library.tiles[1].record.title)
    end)

    it("keeps the progress a rebuilt tile read when its record can't be read again", function()
        local books = fixture.books(13)
        local progress = {}
        for _, book in ipairs(books) do
            progress[book.id] = { status = "reading", percent = 0.5 }
        end
        fixture.install({ [fixture.ROOT] = { books = books } }, progress)
        assert.is_true(LibraryOrder.choose(fixture.ROOT, "title", "reading"))
        local library = show(fixture.ROOT)
        local record = library.tiles[1].record
        local read, reads = Books.progress, 0
        Books.progress = function(book)
            if book == record then
                reads = reads + 1
            end
            return read(book)
        end
        Books.with_progress = function()
            return nil
        end
        assert.equals(1, LibraryCovers.rebuild_tiles(library, { [record.id] = true }, "the spec's rebuild"))
        reads = 0
        library:turn(1)
        assert.equals(2, library.page)
        assert.equals(0, reads)
    end)

    it("repaints in the other variant from the kept listing, without listing", function()
        local library = show()
        local variant = library.ctx.variant
        local other_variant = variant == "night" and "day" or "night"
        Looks.variant = function()
            return other_variant
        end
        local bb = Blitbuffer.new(library.dimen.w, library.dimen.h, Blitbuffer.TYPE_BBRGB32)
        library:paintTo(bb, 0, 0)
        bb:free()
        assert.equals(other_variant, library.ctx.variant)
        assert.same({ listed = 0, rows_read = 0 }, counts())
    end)

    it("realpaths each history entry once per listing, not on a turn", function()
        local hist, entries = {}, {}
        for i = 1, 50 do
            local file = ("%s/history-%02d.epub"):format(lib, i)
            hist[file] = true
            entries[i] = { file = file, time = 1000 - i }
        end
        ReadHistory.hist = entries
        local realpath = ffiutil.realpath
        local calls = 0
        ffiutil.realpath = function(path, ...)
            if hist[path] then
                calls = calls + 1
            end
            return realpath(path, ...)
        end
        finally(function()
            ffiutil.realpath = realpath
        end)
        local library = show()
        library:turn(1)
        assert.equals(50, calls)
        library:turn(1)
        assert.equals(50, calls)
    end)
end)
