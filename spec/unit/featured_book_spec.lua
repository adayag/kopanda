-- The featured book from KOReader's own records (C3): which file, from the pin or the reading
-- history; its title, authors, progress, status and pages from CoverBrowser and the sidecar; its
-- time left from the Statistics reading speed; its chapter from KoPanda's state. Nothing is
-- written: not the settings file, not a sidecar, not the history.
describe("FeaturedBook", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local DocSettings = require("docsettings")
    local QuickStart = require("ui/quickstart")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local util = require("util")

    local books_dir = DataStorage:getDataDir() .. "/featured-books"
    local FeaturedBook, Settings, State, ReadingStats
    local saved_history, saved_quickstart, saved_open, saved_rate, warned

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function read(path)
        local f = assert(io.open(path, "rb"))
        local text = f:read("*a")
        f:close()
        return text
    end

    -- A real file standing for a book, under books_dir.
    local function book(name)
        local path = books_dir .. "/" .. name
        write(path, "not really an epub")
        return path
    end

    -- Reading history holding entries, most recent first, in place of KOReader's.
    local function history(entries)
        package.loaded["readhistory"] = { hist = entries }
    end

    -- The sidecar of file, in the "dir" location (docsettings.lua:118-135), written with the Lua
    -- source of its data table. Returns its path.
    local function sidecar(file, lua)
        local dir = DocSettings:getSidecarDir(file, "dir")
        util.makePath(dir)
        local path = dir .. "/" .. DocSettings.getSidecarFilename(file)
        write(path, "return " .. lua)
        return path
    end

    -- CoverBrowser's BookInfoManager stubbed to answer getBookInfo with info, recording calls.
    local function coverbrowser(info)
        local calls = {}
        package.loaded["bookinfomanager"] = {
            getBookInfo = function(self, file, get_cover)
                calls[#calls + 1] = { self = self, file = file, get_cover = get_cover }
                return info
            end,
        }
        return calls
    end

    -- How many warnings named text.
    local function warnings_naming(text)
        local count = 0
        for _, call in ipairs(warned.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    count = count + 1
                    break
                end
            end
        end
        return count
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

    before_each(function()
        harness.load()
        warned = spy.on(logger, "warn")
        FeaturedBook = package.loaded["featured_book"]
        Settings = package.loaded["settings"]
        State = package.loaded["state"]
        ReadingStats = package.loaded["reading_stats"]
        FeaturedBook.reset()
        saved_history = package.loaded["readhistory"]
        saved_quickstart = QuickStart.quickstart_filename
        saved_open = DocSettings.open
        saved_rate = ReadingStats.seconds_per_page
        -- CoverBrowser unrequirable unless a case stubs it.
        package.loaded["bookinfomanager"] = nil
        package.preload["bookinfomanager"] = function()
            error("CoverBrowser is disabled in this spec")
        end
        G_reader_settings:saveSetting("document_metadata_folder", "dir")
        remove_tree(books_dir)
        remove_tree(DataStorage:getDocSettingsDir())
        lfs.mkdir(books_dir)
        history({})
    end)

    after_each(function()
        logger.warn:revert()
        package.loaded["readhistory"] = saved_history
        QuickStart.quickstart_filename = saved_quickstart
        DocSettings.open = saved_open
        ReadingStats.seconds_per_page = saved_rate
        package.loaded["bookinfomanager"] = nil
        package.preload["bookinfomanager"] = nil
        G_reader_settings:delSetting("document_metadata_folder")
        remove_tree(books_dir)
        remove_tree(DataStorage:getDocSettingsDir())
        harness.teardown()
    end)

    describe("which file", function()
        it("features the pinned book over the history", function()
            local a, b = book("a.epub"), book("b.epub")
            history({ { file = a, select_enabled = true } })
            assert.is_true(Settings.set("featured.pinned", b))
            assert.equals(b, FeaturedBook.current().file)
        end)

        it("falls back to the history from a pin that is gone, logging it once and writing nothing", function()
            local a = book("a.epub")
            local gone = books_dir .. "/gone.epub"
            history({ { file = a, select_enabled = true } })
            assert.is_true(Settings.set("featured.pinned", gone))
            local before = read(harness.settings_file)
            assert.equals(a, FeaturedBook.current().file)
            assert.equals(a, FeaturedBook.current().file)
            assert.equals(before, read(harness.settings_file))
            Settings._reset()
            assert.equals(gone, Settings.get("featured.pinned"))
            assert.equals(1, warnings_naming(gone))
        end)

        it("walks the history past a vanished file, a deselected entry and the QuickStart guide", function()
            local deselected, guide, wanted = book("deselected.epub"), book("quickstart.html"), book("wanted.epub")
            QuickStart.quickstart_filename = guide
            history({
                { file = books_dir .. "/vanished.epub", select_enabled = true },
                { file = deselected, select_enabled = false },
                { file = guide, select_enabled = true },
                { file = wanted, select_enabled = true },
                { file = book("older.epub"), select_enabled = true },
            })
            assert.equals(wanted, FeaturedBook.current().file)
        end)

        it("skips a directory where a book was", function()
            local dir = books_dir .. "/a-folder.epub"
            lfs.mkdir(dir)
            local b = book("b.epub")
            history({ { file = dir, select_enabled = true }, { file = b, select_enabled = true } })
            assert.equals(b, FeaturedBook.current().file)
        end)

        it("gives nil with an empty history, or one with no file left, and no pin", function()
            assert.is_nil(FeaturedBook.current())
            history({ { file = books_dir .. "/vanished.epub", select_enabled = true } })
            assert.is_nil(FeaturedBook.current())
        end)

        it("gives nil, logged, when the history can't be read", function()
            package.loaded["readhistory"] = setmetatable({}, {
                __index = function()
                    error("history broke on purpose")
                end,
            })
            local errored = spy.on(logger, "err")
            local ok, result = pcall(FeaturedBook.current)
            logger.err:revert()
            assert.is_true(ok, tostring(result))
            assert.is_nil(result)
            assert.spy(errored).was_called()
        end)
    end)

    describe("from the sidecar", function()
        local a

        before_each(function()
            a = book("a.epub")
            history({ { file = a, select_enabled = true } })
        end)

        it("reads a book with no sidecar from its file name, at 0 and reading", function()
            local featured = FeaturedBook.current()
            assert.equals(a, featured.file)
            assert.equals("a", featured.title)
            assert.is_nil(featured.authors)
            assert.equals(0, featured.percent)
            assert.equals("reading", featured.status)
            assert.is_nil(featured.pages)
            assert.is_nil(featured.seconds_left)
            assert.is_nil(featured.chapter)
        end)

        it("keeps a file name's inner dots and drops only its extension", function()
            local dotted = book("Mr. Smith.v2.epub")
            history({ { file = dotted, select_enabled = true } })
            assert.equals("Mr. Smith.v2", FeaturedBook.current().title)
        end)

        it("reads percent_finished, clamped to 0 to 1", function()
            sidecar(a, "{ percent_finished = 0.62 }")
            assert.equals(0.62, FeaturedBook.current().percent)
            sidecar(a, "{ percent_finished = 1.5 }")
            assert.equals(1, FeaturedBook.current().percent)
            sidecar(a, "{ percent_finished = -0.2 }")
            assert.equals(0, FeaturedBook.current().percent)
        end)

        it("takes pagemap_doc_pages only with pagemap_use_page_labels on", function()
            sidecar(a, "{ pagemap_use_page_labels = true, pagemap_doc_pages = 300, doc_pages = 250 }")
            assert.equals(300, FeaturedBook.current().pages)
            sidecar(a, "{ pagemap_use_page_labels = false, pagemap_doc_pages = 300, doc_pages = 250 }")
            assert.equals(250, FeaturedBook.current().pages)
        end)

        it("takes doc_pages alone", function()
            sidecar(a, "{ doc_pages = 250 }")
            assert.equals(250, FeaturedBook.current().pages)
        end)

        it("takes stats.pages when it isn't 0", function()
            sidecar(a, "{ stats = { pages = 180 } }")
            assert.equals(180, FeaturedBook.current().pages)
            sidecar(a, "{ stats = { pages = 0 } }")
            assert.is_nil(FeaturedBook.current().pages)
        end)

        it("reads summary.status, missing or unknown as reading", function()
            sidecar(a, '{ summary = { status = "complete" } }')
            assert.equals("complete", FeaturedBook.current().status)
            sidecar(a, '{ summary = { status = "abandoned" } }')
            assert.equals("abandoned", FeaturedBook.current().status)
            sidecar(a, "{ summary = {} }")
            assert.equals("reading", FeaturedBook.current().status)
            sidecar(a, '{ summary = { status = "shelved" } }')
            assert.equals("reading", FeaturedBook.current().status)
        end)

        it("takes the title and authors from doc_props without CoverBrowser", function()
            sidecar(a, '{ doc_props = { title = "Frankenstein", authors = "Mary Shelley" } }')
            local featured = FeaturedBook.current()
            assert.equals("Frankenstein", featured.title)
            assert.equals("Mary Shelley", featured.authors)
        end)

        it("takes the title and authors from CoverBrowser first, newlines joined, without a cover", function()
            sidecar(a, '{ doc_props = { title = "Sidecar title", authors = "Sidecar author" } }')
            local calls = coverbrowser({ title = "Frankenstein", authors = "Mary Shelley\nPercy Shelley" })
            local featured = FeaturedBook.current()
            assert.equals("Frankenstein", featured.title)
            assert.equals("Mary Shelley, Percy Shelley", featured.authors)
            assert.equals(1, #calls)
            assert.equals(package.loaded["bookinfomanager"], calls[1].self)
            assert.equals(a, calls[1].file)
            assert.is_false(calls[1].get_cover)
        end)

        it("falls back to doc_props for a book CoverBrowser hasn't indexed", function()
            sidecar(a, '{ doc_props = { title = "Frankenstein", authors = "Mary Shelley" } }')
            coverbrowser(nil)
            local featured = FeaturedBook.current()
            assert.equals("Frankenstein", featured.title)
            assert.equals("Mary Shelley", featured.authors)
        end)

        it("falls back to doc_props when CoverBrowser can't be required", function()
            sidecar(a, '{ doc_props = { title = "Frankenstein", authors = "Mary Shelley" } }')
            assert.is_false((pcall(require, "bookinfomanager")))
            local featured = FeaturedBook.current()
            assert.equals("Frankenstein", featured.title)
            assert.equals("Mary Shelley", featured.authors)
        end)

        it("reads a corrupt sidecar as no sidecar", function()
            sidecar(a, "{{{ not lua")
            local featured = FeaturedBook.current()
            assert.equals("a", featured.title)
            assert.equals(0, featured.percent)
        end)
    end)

    describe("never writes", function()
        it("leaves the sidecar, history and settings file as they were, never calling DocSettings:open", function()
            local a = book("a.epub")
            local entries = { { file = a, select_enabled = true, time = 1 } }
            history(entries)
            assert.is_true(Settings.set("featured.pinned", books_dir .. "/gone.epub"))
            local settings_before = read(harness.settings_file)
            local path = sidecar(a, '{ percent_finished = 0.5, doc_pages = 10, summary = { status = "reading" } }')
            local bytes, mtime = read(path), lfs.attributes(path, "modification")
            DocSettings.open = function()
                error("DocSettings:open was called")
            end
            local featured = FeaturedBook.current()
            assert.equals(0.5, featured.percent)
            assert.equals(bytes, read(path))
            assert.equals(mtime, lfs.attributes(path, "modification"))
            assert.same({ { file = a, select_enabled = true, time = 1 } }, entries)
            assert.equals(settings_before, read(harness.settings_file))
        end)
    end)

    describe("seconds left", function()
        local a

        before_each(function()
            a = book("a.epub")
            history({ { file = a, select_enabled = true } })
        end)

        it("is the Statistics pages left at the book's rate", function()
            sidecar(a, '{ percent_finished = 0.62, partial_md5_checksum = "abc", doc_pages = 90 }')
            local asked = {}
            ReadingStats.seconds_per_page = function(md5)
                asked[#asked + 1] = md5
                return 2, 100
            end
            local featured = FeaturedBook.current()
            assert.equals(76, featured.seconds_left)
            assert.equals(90, featured.pages)
            assert.same({ "abc" }, asked)
        end)

        -- 62.6 of 100 pages read rounds to 63, leaving 37 pages; flooring would leave 38.
        it("rounds the pages read to the nearest page", function()
            sidecar(a, '{ percent_finished = 0.626, partial_md5_checksum = "abc" }')
            ReadingStats.seconds_per_page = function()
                return 2, 100
            end
            assert.equals(74, FeaturedBook.current().seconds_left)
        end)

        it("is nil with no rate", function()
            sidecar(a, '{ percent_finished = 0.62, partial_md5_checksum = "abc" }')
            ReadingStats.seconds_per_page = function()
                return nil
            end
            assert.is_nil(FeaturedBook.current().seconds_left)
        end)

        it("is nil, and no rate is asked, with no md5 or no percent", function()
            local asked = 0
            ReadingStats.seconds_per_page = function()
                asked = asked + 1
                return 2, 100
            end
            sidecar(a, "{ percent_finished = 0.62 }")
            assert.is_nil(FeaturedBook.current().seconds_left)
            sidecar(a, '{ partial_md5_checksum = "abc" }')
            assert.is_nil(FeaturedBook.current().seconds_left)
            assert.equals(0, asked)
        end)
    end)

    -- The picker's books (sheets' C7): the recent history entries the featured book would take,
    -- each read as current() reads its title and authors, raising nothing and writing nothing.
    describe("recent and describe", function()
        local DS = require("docsettings")
        local saved_find

        before_each(function()
            saved_find = DS.findSidecarFile
        end)

        after_each(function()
            DS.findSidecarFile = saved_find
        end)

        -- Every logger.err call's arguments joined, for the running case.
        local function errors_during(fn)
            local errored = spy.on(logger, "err")
            local ok, err = pcall(fn)
            logger.err:revert()
            assert(ok, err)
            local out = {}
            for _, call in ipairs(errored.calls) do
                local parts = {}
                for _, arg in ipairs(call.vals) do
                    parts[#parts + 1] = tostring(arg)
                end
                out[#out + 1] = table.concat(parts, " ")
            end
            return out
        end

        local function any_naming(lines, text)
            for _, line in ipairs(lines) do
                if line:find(text, 1, true) then
                    return true
                end
            end
            return false
        end

        it("gives the first six history books that remain, most recent first, from their sidecars", function()
            local guide = book("quickstart.html")
            QuickStart.quickstart_filename = guide
            local files, sidecars = {}, {}
            for i = 1, 7 do
                files[i] = book("book" .. i .. ".epub")
                sidecars[i] = sidecar(files[i], string.format(
                    '{ doc_props = { title = "Title %d", authors = "Author %d\\nOther %d" } }', i, i, i))
            end
            -- Ten entries: three the filter drops, then seven books, the seventh past the six.
            local entries = {
                { file = files[1], select_enabled = true, time = 10 },
                { file = books_dir .. "/gone.epub", select_enabled = true, time = 9 },
                { file = files[2], select_enabled = true, time = 8 },
                { file = book("unselectable.epub"), select_enabled = false, time = 7 },
                { file = guide, select_enabled = true, time = 6 },
                { file = files[3], select_enabled = true, time = 5 },
                { file = files[4], select_enabled = true, time = 4 },
                { file = files[5], select_enabled = true, time = 3 },
                { file = files[6], select_enabled = true, time = 2 },
                { file = files[7], select_enabled = true, time = 1 },
            }
            history(entries)
            local history_file = DataStorage:getDataDir() .. "/history.lua"
            local history_before = lfs.attributes(history_file, "mode") and read(history_file)
            local copy = util.tableDeepCopy(entries)
            local bytes = {}
            for i, path in ipairs(sidecars) do
                bytes[i] = read(path)
            end
            local recent = FeaturedBook.recent(6)
            local want = {}
            for i = 1, 6 do
                want[i] = { file = files[i], title = "Title " .. i, authors = "Author " .. i .. ", Other " .. i }
            end
            assert.same(want, recent)
            assert.same(copy, entries)
            for i, path in ipairs(sidecars) do
                assert.equals(bytes[i], read(path))
            end
            assert.equals(history_before, lfs.attributes(history_file, "mode") and read(history_file))
        end)

        it("gives fewer than n when the history holds fewer, and none from an empty one", function()
            local a = book("a.epub")
            history({ { file = a, select_enabled = true } })
            assert.same({ { file = a, title = "a" } }, FeaturedBook.recent(6))
            history({})
            assert.same({}, FeaturedBook.recent(6))
        end)

        it("describes a file with no sidecar by its file name, with no authors", function()
            local a = book("A Book.epub")
            assert.same({ file = a, title = "A Book" }, FeaturedBook.describe(a))
        end)

        it("describes a book whose sidecar read raises by CoverBrowser's title, logged, and keeps it", function()
            local a = book("a.epub")
            sidecar(a, '{ doc_props = { title = "Sidecar title" } }')
            DS.findSidecarFile = function()
                error("sidecar broke on purpose")
            end
            coverbrowser({ title = "CoverBrowser title", authors = "Mary Shelley" })
            history({ { file = a, select_enabled = true } })
            local described, recent
            local logged = errors_during(function()
                described = FeaturedBook.describe(a)
                recent = FeaturedBook.recent(6)
            end)
            assert.same({ file = a, title = "CoverBrowser title", authors = "Mary Shelley" }, described)
            assert.same({ described }, recent)
            assert.is_true(any_naming(logged, "sidecar broke on purpose"))
        end)

        it("describes it by its file name with CoverBrowser unrequirable", function()
            local a = book("a.epub")
            sidecar(a, '{ doc_props = { title = "Sidecar title" } }')
            DS.findSidecarFile = function()
                error("sidecar broke on purpose")
            end
            assert.is_false((pcall(require, "bookinfomanager")))
            local described
            local logged = errors_during(function()
                described = FeaturedBook.describe(a)
            end)
            assert.same({ file = a, title = "a" }, described)
            assert.is_true(any_naming(logged, "sidecar broke on purpose"))
        end)

        it("skips only the entry whose describe raises, logged", function()
            local a, b, c = book("a.epub"), book("b.epub"), book("c.epub")
            history({
                { file = a, select_enabled = true },
                { file = b, select_enabled = true },
                { file = c, select_enabled = true },
            })
            local describe = FeaturedBook.describe
            FeaturedBook.describe = function(file)
                if file == b then
                    error("describe broke on purpose")
                end
                return describe(file)
            end
            local recent
            local logged = errors_during(function()
                recent = FeaturedBook.recent(6)
            end)
            FeaturedBook.describe = describe
            assert.same({ { file = a, title = "a" }, { file = c, title = "c" } }, recent)
            assert.is_true(any_naming(logged, "describe broke on purpose"))
        end)

        it("gives none, logged, when the history can't be read", function()
            package.loaded["readhistory"] = setmetatable({}, {
                __index = function()
                    error("history broke on purpose")
                end,
            })
            local recent
            local logged = errors_during(function()
                recent = FeaturedBook.recent(6)
            end)
            assert.same({}, recent)
            assert.is_true(any_naming(logged, "history broke on purpose"))
        end)
    end)

    describe("chapter", function()
        local a

        before_each(function()
            a = book("a.epub")
            history({ { file = ffiutil.realpath(a), select_enabled = true } })
        end)

        it("is the recorded TOC title when the recorded file is the featured book", function()
            assert.is_true(State.set("featured_chapter_file", a))
            assert.is_true(State.set("featured_chapter", "Letter IV"))
            assert.equals("Letter IV", FeaturedBook.current().chapter)
        end)

        it("matches the featured book through a symlink to it", function()
            local link = books_dir .. "/link.epub"
            assert.equals(0, os.execute(string.format("ln -s %q %q", a, link)))
            assert.is_true(State.set("featured_chapter_file", link))
            assert.is_true(State.set("featured_chapter", "Letter IV"))
            assert.equals("Letter IV", FeaturedBook.current().chapter)
        end)

        it("is absent for another file or an empty title", function()
            assert.is_true(State.set("featured_chapter_file", book("b.epub")))
            assert.is_true(State.set("featured_chapter", "Letter IV"))
            assert.is_nil(FeaturedBook.current().chapter)
            assert.is_true(State.set("featured_chapter_file", a))
            assert.is_true(State.set("featured_chapter", ""))
            assert.is_nil(FeaturedBook.current().chapter)
        end)
    end)
end)
