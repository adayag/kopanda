-- The book records (book-model C1, C2, C3): the library listing from KOReader's home folder with
-- the file browser's filters, one record per file from CoverBrowser, then the sidecar, then the
-- file name, and the read status and progress from the sidecar. Run on a scratch library under
-- the data directory with home_dir pointed at it and sidecars in the "dir" location, so nothing
-- lands beside a fixture. CoverBrowser is stubbed in package.loaded where a case needs a row, and
-- unrequirable otherwise. Nothing is written: not a sidecar, not a settings file, not CoverBrowser's
-- database.
describe("Books", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local DocSettings = require("docsettings")
    local FileChooser = require("ui/widget/filechooser")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local util = require("util")

    local lib = DataStorage:getDataDir() .. "/books-library"
    local elsewhere = DataStorage:getDataDir() .. "/books-elsewhere"
    local Books
    local saved_open, saved_find, saved_hidden, logged

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function read(path)
        local f = io.open(path, "rb")
        if not f then
            return nil
        end
        local text = f:read("*a")
        f:close()
        return text
    end

    -- A file standing for a book at lib's relative path rel.
    local function book(rel)
        local path = lib .. "/" .. rel
        write(path, "not really a book")
        return path
    end

    local function dir(rel)
        local path = lib .. "/" .. rel
        assert(lfs.mkdir(path))
        return path
    end

    local function sh(command)
        assert.equals(0, os.execute(command))
    end

    -- The sidecar of file in the "dir" location (docsettings.lua:118-135), holding lua.
    local function sidecar(file, lua)
        local sdr = DocSettings:getSidecarDir(file, "dir")
        util.makePath(sdr)
        local path = sdr .. "/" .. DocSettings.getSidecarFilename(file)
        write(path, "return " .. lua)
        return path
    end

    -- CoverBrowser's BookInfoManager stubbed: rows maps a path to its getBookInfo row. Records
    -- every getBookInfo call; every write method raises if called.
    local function coverbrowser(rows)
        local calls = { get = {}, writes = {} }
        local stub = {
            getBookInfo = function(self, file, get_cover)
                calls.get[#calls.get + 1] = { self = self, file = file, get_cover = get_cover }
                return rows[file]
            end,
        }
        for _, name in ipairs({ "extractInBackground", "extractBookInfo", "setBookInfoProperties",
                "deleteBookInfo" }) do
            stub[name] = function()
                calls.writes[#calls.writes + 1] = name
            end
        end
        package.loaded["bookinfomanager"] = stub
        return calls
    end

    local function id_of(path)
        return "file:" .. ffiutil.realpath(path)
    end

    local function paths(records)
        local out = {}
        for i, record in ipairs(records) do
            out[i] = record.path
        end
        return out
    end

    -- Whether any logged line (logger.err or logger.warn) contains text.
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

    local function remove_tree(path)
        if lfs.symlinkattributes(path, "mode") == "directory" then
            os.execute(string.format("chmod -R u+rwx %q", path))
            for entry in lfs.dir(path) do
                if entry ~= "." and entry ~= ".." then
                    remove_tree(path .. "/" .. entry)
                end
            end
        end
        os.remove(path)
    end

    local saved_err, saved_warn

    before_each(function()
        harness.load()
        Books = package.loaded["books"]
        Books.reset()
        saved_open = DocSettings.open
        saved_find = DocSettings.findSidecarFile
        saved_hidden = FileChooser.show_hidden
        FileChooser.show_hidden = false
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
        remove_tree(elsewhere)
        remove_tree(DataStorage:getDocSettingsDir())
        assert(lfs.mkdir(lib))
        G_reader_settings:saveSetting("home_dir", lib)
    end)

    after_each(function()
        logger.err, logger.warn = saved_err, saved_warn
        DocSettings.open = saved_open
        DocSettings.findSidecarFile = saved_find
        FileChooser.show_hidden = saved_hidden
        package.loaded["bookinfomanager"] = nil
        package.preload["bookinfomanager"] = nil
        G_reader_settings:delSetting("document_metadata_folder")
        G_reader_settings:delSetting("home_dir")
        Books.reset()
        remove_tree(lib)
        remove_tree(elsewhere)
        remove_tree(DataStorage:getDocSettingsDir())
        harness.teardown()
    end)

    describe("the listing", function()
        local a, B, c, d, e, alias

        before_each(function()
            a, B = book("a.epub"), book("B.epub")
            book(".dot.epub")
            book("._x.epub")
            book("notes.xyz")
            book("BookReader.sqlite.epub")
            dir("nested")
            c = book("nested/c.epub")
            dir("nested/deeper")
            d = book("nested/deeper/d.epub")
            dir(".hidden")
            book(".hidden/h.epub")
            dir("book.sdr")
            book("book.sdr/s.epub")
            dir("locked")
            book("locked/l.epub")
            sh(string.format("chmod 000 %q", lib .. "/locked"))
            -- A sub-folder linking back to the root, one linking outside it, and a second name
            -- for a.epub.
            sh(string.format("ln -s %q %q", lib, lib .. "/nested/back"))
            assert(lfs.mkdir(elsewhere))
            write(elsewhere .. "/e.epub", "not really a book")
            sh(string.format("ln -s %q %q", elsewhere, lib .. "/nested/link"))
            e = lib .. "/nested/link/e.epub"
            sh(string.format("ln -s %q %q", a, lib .. "/nested/alias.epub"))
            alias = lib .. "/nested/alias.epub"
        end)

        it("gives a folder's books and kept sub-folders in byte order, with the file browser's filters", function()
            local listed = Books.folder(lib)
            assert.same({ B, a }, paths(listed.books))
            assert.same({
                { name = "locked", path = lib .. "/locked" },
                { name = "nested", path = lib .. "/nested" },
            }, listed.folders)
            listed = Books.folder(lib .. "/nested")
            assert.same({ alias, c }, paths(listed.books))
            assert.same({
                { name = "back", path = lib .. "/nested/back" },
                { name = "deeper", path = lib .. "/nested/deeper" },
                { name = "link", path = lib .. "/nested/link" },
            }, listed.folders)
        end)

        it("lists dot names only with show_hidden on, read when called", function()
            FileChooser.show_hidden = true
            local listed = Books.folder(lib)
            assert.same({ lib .. "/.dot.epub", B, a }, paths(listed.books))
            assert.same({ ".hidden", "locked", "nested" }, {
                listed.folders[1].name, listed.folders[2].name, listed.folders[3].name })
            assert.equals(3, #listed.folders)
            FileChooser.show_hidden = false
            assert.same({ B, a }, paths(Books.folder(lib).books))
        end)

        it("walks every book under the home folder once, each folder and id once", function()
            local all = Books.all()
            assert.same({ B, a, c, d, e }, paths(all))
            local ids = {}
            for _, record in ipairs(all) do
                ids[#ids + 1] = record.id
            end
            assert.same({ id_of(B), id_of(a), id_of(c), id_of(d), id_of(elsewhere .. "/e.epub") }, ids)
        end)

        it("skips an unreadable folder, logged", function()
            assert.same({}, Books.folder(lib .. "/locked").books)
            assert.is_true(was_logged(lib .. "/locked"))
            logged = {}
            Books.all()
            assert.is_true(was_logged(lib .. "/locked"))
        end)

        it("lists nothing from a missing root, logged", function()
            local gone = lib .. "/gone"
            G_reader_settings:saveSetting("home_dir", gone)
            assert.same({}, Books.all())
            assert.is_true(was_logged(gone))
            assert.same({ books = {}, folders = {} }, Books.folder(gone))
        end)

        it("takes a listed book's title and authors from the sidecar when CoverBrowser gives none", function()
            sidecar(a, '{ doc_props = { title = "Frankenstein", authors = "Mary Shelley" } }')
            local function listed_a(records)
                for _, record in ipairs(records) do
                    if record.path == a then
                        return record
                    end
                end
            end
            for _, record in ipairs({ listed_a(Books.folder(lib).books), listed_a(Books.all()) }) do
                assert.equals("Frankenstein", record.title)
                assert.same({ "Mary Shelley" }, record.authors)
            end
            coverbrowser({ [a] = { title = "T" } })
            for _, record in ipairs({ listed_a(Books.folder(lib).books), listed_a(Books.all()) }) do
                assert.equals("T", record.title)
                assert.same({ "Mary Shelley" }, record.authors)
            end
        end)

        it("asks no extraction, opens no sidecar of a complete row, and writes nothing", function()
            local rows = {}
            for _, path in ipairs({ a, B, c, d, e }) do
                rows[path] = { title = "T", authors = "A", cover_fetched = "Y", has_cover = "Y" }
            end
            local calls = coverbrowser(rows)
            local side = sidecar(a, '{ doc_props = { title = "Sidecar" }, percent_finished = 0.5 }')
            local bytes, mtime = read(side), lfs.attributes(side, "modification")
            local settings_before = read(harness.settings_file)
            local opened = 0
            local light = DocSettings.openSettingsFile
            DocSettings.openSettingsFile = function(...)
                opened = opened + 1
                return light(...)
            end
            DocSettings.open = function()
                error("DocSettings:open was called")
            end
            local ok, err = pcall(function()
                Books.folder(lib)
                Books.all()
            end)
            DocSettings.openSettingsFile = light
            assert.is_true(ok, tostring(err))
            assert.equals(0, opened)
            assert.same({}, calls.writes)
            for _, call in ipairs(calls.get) do
                assert.is_false(call.get_cover)
            end
            Books.progress(Books.for_path(a))
            assert.same({}, calls.writes)
            assert.equals(bytes, read(side))
            assert.equals(mtime, lfs.attributes(side, "modification"))
            assert.equals(settings_before, read(harness.settings_file))
        end)
    end)

    describe("the record", function()
        local a

        before_each(function()
            a = book("a.epub")
        end)

        it("is the file's record by its realpath, from the file name with nothing else", function()
            assert.same({
                id = id_of(a),
                source = "file",
                path = a,
                title = "a",
                authors = {},
                cover = "none",
            }, Books.for_path(a))
            local dotted = book("Mr. Smith.v2.epub")
            assert.equals("Mr. Smith.v2", Books.for_path(dotted).title)
        end)

        it("takes the id of the target for a book reached through a linked folder", function()
            assert(lfs.mkdir(elsewhere))
            write(elsewhere .. "/e.epub", "not really a book")
            sh(string.format("ln -s %q %q", elsewhere, lib .. "/link"))
            local record = Books.for_path(lib .. "/link/e.epub")
            assert.equals(lib .. "/link/e.epub", record.path)
            assert.equals(id_of(elsewhere .. "/e.epub"), record.id)
        end)

        it("takes the title and authors from the sidecar without CoverBrowser", function()
            sidecar(a, '{ doc_props = { title = "Frankenstein", authors = "Mary Shelley\\nPercy Shelley" } }')
            local record = Books.for_path(a)
            assert.equals("Frankenstein", record.title)
            assert.same({ "Mary Shelley", "Percy Shelley" }, record.authors)
            assert.is_nil(record.series)
        end)

        it("takes CoverBrowser's fields first, with one getBookInfo call without a cover", function()
            sidecar(a, '{ doc_props = { title = "Sidecar title", authors = "Sidecar author" } }')
            local calls = coverbrowser({ [a] = {
                title = "Frankenstein", authors = "Mary Shelley", series = "Gothic", series_index = 1.5,
                cover_fetched = "Y", has_cover = "Y",
            } })
            local record = Books.for_path(a)
            assert.same({
                id = id_of(a), source = "file", path = a, title = "Frankenstein", authors = { "Mary Shelley" },
                series = "Gothic", series_index = 1.5, cover = "cached",
            }, record)
            assert.equals(1, #calls.get)
            assert.equals(package.loaded["bookinfomanager"], calls.get[1].self)
            assert.equals(a, calls.get[1].file)
            assert.is_false(calls.get[1].get_cover)
        end)

        it("fills each field CoverBrowser leaves empty from the sidecar, field by field", function()
            sidecar(a, '{ doc_props = { title = "Sidecar title", authors = "Sidecar author" } }')
            coverbrowser({ [a] = { title = "Frankenstein", authors = "" } })
            local record = Books.for_path(a)
            assert.equals("Frankenstein", record.title)
            assert.same({ "Sidecar author" }, record.authors)
            coverbrowser({ [a] = { title = "", authors = "Mary Shelley" } })
            record = Books.for_path(a)
            assert.equals("Sidecar title", record.title)
            assert.same({ "Mary Shelley" }, record.authors)
            coverbrowser({ [a] = { authors = " \n " } })
            assert.same({ "Sidecar author" }, Books.for_path(a).authors)
        end)

        it("splits authors on newlines, trimmed, white space squeezed, empty names dropped", function()
            coverbrowser({ [a] = { title = "T", authors = "A\n  B  \n\nC" } })
            assert.same({ "A", "B", "C" }, Books.for_path(a).authors)
            coverbrowser({ [a] = { title = "T", authors = "  Mary \t  Shelley \nPercy  Shelley" } })
            assert.same({ "Mary Shelley", "Percy Shelley" }, Books.for_path(a).authors)
        end)

        it("reads every cover state from the row", function()
            local function cover(row)
                coverbrowser({ [a] = row })
                return Books.for_path(a).cover
            end
            assert.equals("missing", cover(nil))
            assert.equals("missing", cover({ title = "T" }))
            assert.equals("none", cover({ unsupported = "no engine", cover_fetched = "Y", has_cover = "Y" }))
            assert.equals("none", cover({ ignore_cover = "Y", cover_fetched = "Y", has_cover = "Y" }))
            assert.equals("none", cover({ cover_fetched = "Y" }))
            assert.equals("cached", cover({ cover_fetched = "Y", has_cover = "Y" }))
            package.loaded["bookinfomanager"] = nil
            assert.is_false((pcall(require, "bookinfomanager")))
            assert.equals("none", Books.for_path(a).cover)
        end)

        it("logs a raising getBookInfo and still reads the sidecar", function()
            sidecar(a, '{ doc_props = { title = "Sidecar title", authors = "Sidecar author" } }')
            package.loaded["bookinfomanager"] = {
                getBookInfo = function()
                    error("CoverBrowser broke on purpose")
                end,
            }
            local record = Books.for_path(a)
            assert.equals("Sidecar title", record.title)
            assert.same({ "Sidecar author" }, record.authors)
            assert.equals("missing", record.cover)
            assert.is_true(was_logged("CoverBrowser broke on purpose"))
        end)

        it("logs a raising sidecar read and still reads CoverBrowser", function()
            coverbrowser({ [a] = { title = "Frankenstein", authors = "Mary Shelley", cover_fetched = "Y" } })
            DocSettings.findSidecarFile = function()
                error("sidecar broke on purpose")
            end
            local record = Books.for_path(a)
            assert.equals("Frankenstein", record.title)
            assert.same({ "Mary Shelley" }, record.authors)
            assert.is_true(was_logged("sidecar broke on purpose"))
        end)

        it("gives nil for a directory or a missing path", function()
            assert.is_nil(Books.for_path(dir("folder.epub")))
            assert.is_nil(Books.for_path(lib .. "/missing.epub"))
        end)

        it("finds a record by its id, a file's or a source's", function()
            Books.add_source({
                name = "remote",
                books = function()
                    return { { id = "remote:1", title = "Far away" } }
                end,
            })
            local record = Books.get(id_of(a))
            assert.equals(id_of(a), record.id)
            assert.equals("a", record.title)
            assert.equals("Far away", Books.get("remote:1").title)
            assert.is_nil(Books.get("remote:2"))
            assert.is_nil(Books.get("file:" .. lib .. "/missing.epub"))
            assert.is_nil(Books.get("elsewhere:1"))
        end)
    end)

    describe("progress", function()
        local a

        before_each(function()
            a = book("a.epub")
        end)

        local function progress()
            return Books.progress(Books.for_path(a))
        end

        it("is new with no sidecar", function()
            assert.same({ status = "new" }, progress())
        end)

        it("reads the summary's status, anything else as reading", function()
            for _, status in ipairs({ "reading", "abandoned", "complete" }) do
                sidecar(a, '{ summary = { status = "' .. status .. '" } }')
                assert.equals(status, progress().status)
            end
            sidecar(a, '{ summary = { status = "new" } }')
            assert.equals("reading", progress().status)
            sidecar(a, '{ summary = { status = "shelved" } }')
            assert.equals("reading", progress().status)
            sidecar(a, "{ percent_finished = 0.1 }")
            assert.equals("reading", progress().status)
        end)

        it("counts a sidecar that can't be read as opened", function()
            sidecar(a, "{{{ not lua")
            assert.same({ status = "reading" }, progress())
        end)

        it("clamps percent_finished to 0 to 1, nil when it isn't a number", function()
            sidecar(a, "{ percent_finished = 0.62 }")
            assert.equals(0.62, progress().percent)
            sidecar(a, "{ percent_finished = 1.5 }")
            assert.equals(1, progress().percent)
            sidecar(a, "{ percent_finished = -0.2 }")
            assert.equals(0, progress().percent)
            sidecar(a, '{ percent_finished = "half" }')
            assert.is_nil(progress().percent)
        end)

        it("reads the pages from page labels, doc_pages, then a non-zero stats.pages", function()
            sidecar(a, "{ pagemap_use_page_labels = true, pagemap_doc_pages = 300, doc_pages = 250 }")
            assert.equals(300, progress().pages)
            sidecar(a, "{ pagemap_use_page_labels = false, pagemap_doc_pages = 300, doc_pages = 250 }")
            assert.equals(250, progress().pages)
            sidecar(a, "{ doc_pages = 250, stats = { pages = 180 } }")
            assert.equals(250, progress().pages)
            sidecar(a, "{ stats = { pages = 180 } }")
            assert.equals(180, progress().pages)
            sidecar(a, "{ stats = { pages = 0 } }")
            assert.is_nil(progress().pages)
        end)

        it("gives the md5 and every field together", function()
            sidecar(a, '{ percent_finished = 0.5, doc_pages = 90, partial_md5_checksum = "abc",'
                .. ' summary = { status = "complete" } }')
            assert.same({ status = "complete", percent = 0.5, pages = 90, md5 = "abc" }, progress())
        end)

        it("reads the sidecar again on each call", function()
            local record = Books.for_path(a)
            sidecar(a, "{ percent_finished = 0.2 }")
            assert.equals(0.2, Books.progress(record).percent)
            sidecar(a, '{ percent_finished = 0.7, summary = { status = "complete" } }')
            local now = Books.progress(record)
            assert.equals(0.7, now.percent)
            assert.equals("complete", now.status)
        end)

        it("never calls DocSettings:open and leaves the sidecar as it was", function()
            local side = sidecar(a, "{ percent_finished = 0.5 }")
            local bytes, mtime = read(side), lfs.attributes(side, "modification")
            DocSettings.open = function()
                error("DocSettings:open was called")
            end
            assert.equals(0.5, progress().percent)
            assert.equals(bytes, read(side))
            assert.equals(mtime, lfs.attributes(side, "modification"))
        end)
    end)
end)
