-- BookLists, the read of KOReader's History and Favorites and the writes to them: the order each keeps, what each
-- leaves out, and the mapping of paths onto the library's records. Real files under KO_HOME, in KOReader's own
-- ReadHistory and ReadCollection, so a write is read back as KOReader reads it.
describe("BookLists", function()
    local harness = require("plugin_harness")
    local ReadCollection = require("readcollection")
    local ReadHistory = require("readhistory")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local BookLists, Books

    local dir = os.getenv("KO_HOME") .. "/book-lists-books"
    local saved_hist, saved_coll

    local function book(name)
        local path = dir .. "/" .. name
        local f = assert(io.open(path, "wb"))
        f:write("not a real book")
        f:close()
        return ffiutil.realpath(path)
    end

    before_each(function()
        harness.load()
        BookLists = package.loaded["book_lists"]
        Books = package.loaded["books"]
        if lfs.attributes(dir, "mode") ~= "directory" then
            assert(lfs.mkdir(dir))
        end
        saved_hist, saved_coll = ReadHistory.hist, ReadCollection.coll
        ReadHistory.hist = {}
        ReadCollection.coll = { favorites = {} }
    end)

    after_each(function()
        ReadHistory.hist, ReadCollection.coll = saved_hist, saved_coll
        harness.teardown()
    end)

    describe("history", function()
        it("lists the paths newest first, as KOReader keeps them, skipping a deleted file's dim entry", function()
            ReadHistory.hist = {
                { file = "/books/newest.epub", time = 3 },
                { file = "/books/deleted.epub", time = 2, dim = true },
                { file = "/books/oldest.epub", time = 1 },
            }
            assert.same({ "/books/newest.epub", "/books/oldest.epub" }, BookLists.history())
        end)

        it("is empty with no history", function()
            assert.same({}, BookLists.history())
        end)
    end)

    describe("favorites", function()
        it("lists the paths in KOReader's collection order, not the order they were added in", function()
            ReadCollection.coll.favorites = {
                ["/books/third.epub"] = { file = "/books/third.epub", order = 3 },
                ["/books/first.epub"] = { file = "/books/first.epub", order = 1 },
                ["/books/second.epub"] = { file = "/books/second.epub", order = 2 },
            }
            assert.same({ "/books/first.epub", "/books/second.epub", "/books/third.epub" }, BookLists.favorites())
        end)

        it("is empty with no favorites", function()
            assert.same({}, BookLists.favorites())
        end)

        it("lists the paths by file name under a KOReader sort, which leaves the items no order", function()
            finally(function()
                ReadCollection.coll_settings.favorites.collate = nil
            end)
            ReadCollection.coll_settings.favorites.collate = "title"
            ReadCollection.coll.favorites = {
                ["/books/z/b.epub"] = { file = "/books/z/b.epub", text = "b.epub" },
                ["/books/y/c.epub"] = { file = "/books/y/c.epub", text = "c.epub" },
                ["/books/x/a.epub"] = { file = "/books/x/a.epub", text = "a.epub" },
            }
            assert.same({ "/books/x/a.epub", "/books/z/b.epub", "/books/y/c.epub" }, BookLists.favorites())
        end)
    end)

    describe("records", function()
        it("keeps the paths' order, taking each from the library by path", function()
            local a = { id = "file:/books/a.epub", path = "/books/a.epub" }
            local b = { id = "file:/books/b.epub", path = "/books/b.epub" }
            local reads = spy.on(Books, "for_path")
            local records = BookLists.records({ "/books/b.epub", "/books/a.epub" }, { a, b })
            assert.equals(b, records[1])
            assert.equals(a, records[2])
            assert.equals(2, #records)
            assert.spy(reads).was_not_called()
            Books.for_path:revert()
        end)

        it("falls back to the file's own record for a path outside the library", function()
            local outside = book("outside.epub")
            local a = { id = "file:/books/a.epub", path = "/books/a.epub" }
            local records = BookLists.records({ outside, "/books/a.epub" }, { a })
            assert.equals(2, #records)
            assert.equals(outside, records[1].path)
            assert.equals(a, records[2])
        end)

        it("takes a book from a library reached through a symlink, whose paths aren't the realpaths listed", function()
            local file = book("through-link.epub")
            local link = os.getenv("KO_HOME") .. "/book-lists-link"
            os.remove(link)
            assert.equals(0, os.execute(string.format("ln -s %q %q", dir, link)))
            local record = Books.for_path(link .. "/through-link.epub")
            assert.is_not.equals(file, record.path)
            local reads = spy.on(Books, "for_path")
            local records = BookLists.records({ file }, { record })
            assert.equals(record, records[1])
            assert.spy(reads).was_not_called()
            Books.for_path:revert()
        end)

        it("drops a path with no record, and skips a library record with no path", function()
            local remote = { id = "shelf:b", title = "No file" }
            assert.same({}, BookLists.records({ dir .. "/gone.epub" }, { remote }))
        end)
    end)

    describe("a favorite", function()
        it("is added and written, read back as KOReader reads the file", function()
            local file = book("favorite.epub")
            assert.is_false(BookLists.is_favorite(file))
            BookLists.add_favorite(file)
            assert.is_true(BookLists.is_favorite(file))
            assert.same({ file }, BookLists.favorites())
            local written = dofile(require("datastorage"):getSettingsDir() .. "/collection.lua")
            assert.equals(file, written.favorites[1].file)
        end)

        it("is found through a symlink to it", function()
            local file = book("linked.epub")
            local link = dir .. "/link.epub"
            os.remove(link)
            assert.equals(0, os.execute(string.format("ln -s %q %q", file, link)))
            BookLists.add_favorite(link)
            assert.is_true(BookLists.is_favorite(file))
            assert.is_true(BookLists.is_favorite(link))
        end)

        it("is removed and written", function()
            local file = book("removed.epub")
            BookLists.add_favorite(file)
            BookLists.remove_favorite(file)
            assert.is_false(BookLists.is_favorite(file))
            assert.same({}, BookLists.favorites())
            local written = dofile(require("datastorage"):getSettingsDir() .. "/collection.lua")
            assert.is_nil(written.favorites[1])
        end)

        it("toggles in, then out", function()
            local file = book("toggled.epub")
            BookLists.toggle_favorite(file)
            assert.is_true(BookLists.is_favorite(file))
            BookLists.toggle_favorite(file)
            assert.is_false(BookLists.is_favorite(file))
        end)
    end)

    describe("remove_from_history", function()
        it("removes the entry of the file's realpath, reached through a symlink", function()
            local file = book("read.epub")
            local link = dir .. "/read-link.epub"
            os.remove(link)
            assert.equals(0, os.execute(string.format("ln -s %q %q", file, link)))
            ReadHistory.hist = { { file = file, time = 2 }, { file = "/books/other.epub", time = 1 } }
            BookLists.remove_from_history(link)
            assert.same({ "/books/other.epub" }, BookLists.history())
        end)
    end)
end)
