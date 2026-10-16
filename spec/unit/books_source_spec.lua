-- A source of path-less books (book-model C4): its records listed at the library root after the
-- local books and in no sub-folder, found by id, never by path, and their progress from the
-- source or new. A source that raises is logged and leaves the local books listed; a record
-- without an id or title is dropped and logged. The source is a table this spec registers and
-- removes. CoverBrowser is unrequirable throughout.
describe("Books with a source", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")

    local lib = DataStorage:getDataDir() .. "/books-source-library"
    local Books
    local logged, saved_err, saved_warn
    local local_a, local_b, nested_c

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function remove_tree(path)
        if lfs.attributes(path, "mode") == "directory" then
            for entry in lfs.dir(path) do
                if entry ~= "." and entry ~= ".." then
                    remove_tree(path .. "/" .. entry)
                end
            end
        end
        os.remove(path)
    end

    local function was_logged(text)
        for _, call in ipairs(logged) do
            for _, arg in ipairs(call) do
                if tostring(arg):find(text, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    local function ids(records)
        local out = {}
        for i, record in ipairs(records) do
            out[i] = record.id
        end
        return out
    end

    local function file_id(path)
        return "file:" .. ffiutil.realpath(path)
    end

    -- A source named "remote" giving books, with progress if given.
    local function remote(books, progress)
        local source = {
            name = "remote",
            books = function()
                return books
            end,
            cover = function()
                return nil
            end,
            progress = progress,
        }
        Books.add_source(source)
        return source
    end

    local DUNE = {
        id = "remote:dune", title = "Dune", authors = { "Frank Herbert" }, series = "Dune", series_index = 1,
        cover = "cached", url = "https://example.invalid/dune",
    }
    local EMMA = { id = "remote:emma", title = "Emma", authors = { "Jane Austen" } }

    before_each(function()
        harness.load()
        Books = package.loaded["books"]
        Books.reset()
        logged = {}
        saved_err, saved_warn = logger.err, logger.warn
        logger.err = function(...)
            logged[#logged + 1] = { ... }
        end
        logger.warn = logger.err
        package.loaded["bookinfomanager"] = nil
        package.preload["bookinfomanager"] = function()
            error("CoverBrowser is disabled in this spec")
        end
        G_reader_settings:saveSetting("document_metadata_folder", "dir")
        remove_tree(lib)
        assert(lfs.mkdir(lib))
        assert(lfs.mkdir(lib .. "/nested"))
        local_a, local_b, nested_c = lib .. "/a.epub", lib .. "/b.epub", lib .. "/nested/c.epub"
        for _, path in ipairs({ local_a, local_b, nested_c }) do
            write(path, "not really a book")
        end
        G_reader_settings:saveSetting("home_dir", lib)
    end)

    after_each(function()
        logger.err, logger.warn = saved_err, saved_warn
        package.loaded["bookinfomanager"] = nil
        package.preload["bookinfomanager"] = nil
        G_reader_settings:delSetting("document_metadata_folder")
        G_reader_settings:delSetting("home_dir")
        Books.reset()
        remove_tree(lib)
        harness.teardown()
    end)

    describe("the listing", function()
        it("lists the source's books after the local books in all() and the root's folder only", function()
            remote({ DUNE, EMMA })
            local local_ids = { file_id(local_a), file_id(local_b), file_id(nested_c) }
            assert.same({ local_ids[1], local_ids[2], local_ids[3], "remote:dune", "remote:emma" }, ids(Books.all()))
            assert.same({ local_ids[1], local_ids[2], "remote:dune", "remote:emma" }, ids(Books.folder(lib).books))
            assert.same({ local_ids[3] }, ids(Books.folder(lib .. "/nested").books))
        end)

        it("gives a source's record its source and no path, its cover cached or none", function()
            remote({ DUNE, EMMA })
            local all = Books.all()
            local dune, emma = all[4], all[5]
            assert.same({
                id = "remote:dune", source = "remote", title = "Dune", authors = { "Frank Herbert" },
                series = "Dune", series_index = 1, cover = "cached", url = "https://example.invalid/dune",
            }, dune)
            assert.same({ id = "remote:emma", source = "remote", title = "Emma", authors = { "Jane Austen" },
                cover = "none" }, emma)
        end)

        it("gives a source's record without authors none, and drops a path it supplies", function()
            remote({ { id = "remote:x", title = "X", path = "/tmp/x.epub" } })
            local all = Books.all()
            assert.same({ id = "remote:x", source = "remote", title = "X", authors = {}, cover = "none" }, all[4])
        end)

        it("lists the source's books alone from a missing root", function()
            remote({ DUNE })
            remove_tree(lib)
            assert.same({ "remote:dune" }, ids(Books.all()))
            assert.same({ "remote:dune" }, ids(Books.folder(lib).books))
        end)

        it("drops a record without an id or a title, logged", function()
            remote({
                { title = "No id" },
                { id = "remote:untitled" },
                { id = "remote:blank", title = "" },
                "not a record",
                DUNE,
            })
            local all = Books.all()
            assert.same({ file_id(local_a), file_id(local_b), file_id(nested_c), "remote:dune" }, ids(all))
            assert.is_true(was_logged("No id"))
            assert.is_true(was_logged("remote:untitled"))
            assert.is_true(was_logged("remote:blank"))
        end)

        it("logs a source whose books() raises and lists the local books", function()
            Books.add_source({
                name = "broken",
                books = function()
                    error("source broke on purpose")
                end,
            })
            remote({ EMMA })
            assert.same({ file_id(local_a), file_id(local_b), file_id(nested_c), "remote:emma" }, ids(Books.all()))
            assert.is_true(was_logged("source broke on purpose"))
            logged = {}
            assert.same({ file_id(local_a), file_id(local_b), "remote:emma" }, ids(Books.folder(lib).books))
            assert.is_true(was_logged("source broke on purpose"))
        end)

        it("lists each id once across sources", function()
            remote({ DUNE, DUNE })
            local all = Books.all()
            assert.same({ file_id(local_a), file_id(local_b), file_id(nested_c), "remote:dune" }, ids(all))
        end)
    end)

    describe("one book", function()
        it("finds a source's book by its id and never by a path", function()
            remote({ DUNE, EMMA })
            assert.equals("Emma", Books.get("remote:emma").title)
            assert.equals("remote", Books.get("remote:emma").source)
            assert.is_nil(Books.get("remote:none"))
            assert.is_nil(Books.for_path("remote:emma"))
            assert.is_nil(Books.for_path("dune"))
        end)

        it("gives nil, logged, for an id of a source that raises", function()
            Books.add_source({
                name = "broken",
                books = function()
                    error("source broke on purpose")
                end,
            })
            assert.is_nil(Books.get("broken:1"))
            assert.is_true(was_logged("source broke on purpose"))
        end)
    end)

    describe("progress", function()
        it("is the source's progress", function()
            local asked = {}
            remote({ DUNE }, function(record)
                asked[#asked + 1] = record.id
                return { status = "reading", percent = 0.3 }
            end)
            assert.same({ status = "reading", percent = 0.3 }, Books.progress(Books.get("remote:dune")))
            assert.same({ "remote:dune" }, asked)
        end)

        it("is new from a source with no progress", function()
            remote({ DUNE })
            assert.same({ status = "new" }, Books.progress(Books.get("remote:dune")))
        end)

        it("is new, logged, from a source whose progress raises", function()
            remote({ DUNE }, function()
                error("progress broke on purpose")
            end)
            assert.same({ status = "new" }, Books.progress(Books.get("remote:dune")))
            assert.is_true(was_logged("progress broke on purpose"))
        end)
    end)

    describe("covers", function()
        local UIManager = require("ui/uimanager")

        -- A bookinfomanager stub that records every call, with a row for no file.
        local function recording_manager()
            local bim = { calls = {} }
            function bim:getBookInfo(file, get_cover)
                bim.calls[#bim.calls + 1] = { "getBookInfo", file, get_cover }
            end
            function bim:extractInBackground(files)
                bim.calls[#bim.calls + 1] = { "extractInBackground", files }
                return true
            end
            function bim.isExtractingInBackground()
                return false
            end
            function bim.isCachedCoverInvalid()
                return true
            end
            return bim
        end

        it("draws a source's book with the bitmap its cover gives for the box", function()
            local bb = { free = function() end }
            local asked = {}
            Books.add_source({
                name = "remote",
                books = function() return { DUNE } end,
                cover = function(record, w, h)
                    asked[#asked + 1] = { record.id, w, h }
                    return bb
                end,
            })
            local BookCovers = package.loaded["book_covers"]
            assert.equals(bb, BookCovers.read(Books.get("remote:dune"), 150, 225))
            assert.same({ { "remote:dune", 150, 225 } }, asked)
        end)

        it("gives nil for a source with no cover", function()
            Books.add_source({ name = "remote", books = function() return { DUNE } end })
            local BookCovers = package.loaded["book_covers"]
            assert.is_nil(BookCovers.read(Books.get("remote:dune"), 150, 225))
        end)

        it("gives nil, logged, for a source whose cover raises", function()
            remote({ DUNE }).cover = function()
                error("cover broke on purpose")
            end
            local BookCovers = package.loaded["book_covers"]
            assert.is_nil(BookCovers.read(Books.get("remote:dune"), 150, 225))
            assert.is_true(was_logged("cover broke on purpose"))
        end)

        it("never asks CoverBrowser about a source's book, read or requested", function()
            local bim = recording_manager()
            package.loaded["bookinfomanager"] = bim
            local schedule_in = UIManager.scheduleIn
            local scheduled = 0
            UIManager.scheduleIn = function()
                scheduled = scheduled + 1
            end
            finally(function()
                UIManager.scheduleIn = schedule_in
            end)
            remote({ DUNE, EMMA })
            local BookCovers = package.loaded["book_covers"]
            BookCovers.reset()
            BookCovers.read(Books.get("remote:dune"), 150, 225)
            BookCovers.request({ Books.get("remote:dune"), Books.get("remote:emma") }, { max_cover_w = 150,
                max_cover_h = 225 }, function() end, function() return true end)
            assert.same({}, bim.calls)
            assert.equals(0, scheduled)
        end)
    end)
end)
