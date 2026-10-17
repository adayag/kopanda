-- What a library folder shows, in what order, on which page, and what the library remembers
-- (cover-grid C1, C2; D3, D8, D9, D11), on hand-built listings: folders first by the title
-- order of their names; Recent by the history's time, never-opened books after by title; Title
-- ignoring one leading article; Author by the first author's surname key, then title, no author
-- last; Series by name, then index, no index after, no series last; the statuses; pages of six;
-- and the per-folder sort and status, the folder and page left, under the state file's
-- `library` key.
describe("LibraryOrder", function()
    local harness = require("plugin_harness")
    local LuaSettings = require("luasettings")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local LibraryOrder

    before_each(function()
        harness.load()
        LibraryOrder = require("library_order")
    end)

    after_each(function()
        harness.teardown()
    end)

    local function book(id, title, fields)
        local record = { id = id, source = "file", title = title, authors = {} }
        for k, v in pairs(fields or {}) do
            record[k] = v
        end
        return record
    end

    -- Chosen so each rule moves a book: an article title (o, l, t, w), two books by one surname
    -- whose first names order against their titles (a, l), a "Le Guin" between Herbert and
    -- Shelley (w, t, e), a series with a missing index (e), a series whose name starts with an
    -- article (d), and a book with no author (b).
    local function records()
        return {
            book("n", "Anathem", { authors = { "Neal Stephenson" } }),
            book("b", "Beowulf"),
            book("d", "Dune", { authors = { "Frank Herbert" }, series = "The Dune Chronicles", series_index = 1 }),
            book("o", "The Odyssey", { authors = { "Homer" } }),
            book("w", "A Wizard of Earthsea",
                { authors = { "Ursula K. Le Guin" }, series = "Earthsea", series_index = 1 }),
            book("t", "The Tombs of Atuan",
                { authors = { "Ursula K. Le Guin" }, series = "Earthsea", series_index = 2 }),
            book("e", "Tales from Earthsea", { authors = { "Ursula K. Le Guin" }, series = "Earthsea" }),
            book("a", "Adonais", { authors = { "Percy Bysshe Shelley" } }),
            book("l", "The Last Man", { authors = { "Mary Shelley" } }),
        }
    end

    -- Folders out of order, one named like a book and one with an article, so byte order,
    -- lowercase order and title order all differ.
    local function folders()
        return {
            { name = "atlas", path = "/lib/atlas" },
            { name = "Zines", path = "/lib/Zines" },
            { name = "The Annals", path = "/lib/The Annals" },
            { name = "Adonais", path = "/lib/Adonais" },
        }
    end

    local function listing()
        return { books = records(), folders = folders() }
    end

    local function progress(statuses)
        return function(record)
            return { status = statuses[record.id] or "new" }
        end
    end

    -- Each item as its id, or its folder's name.
    local function ids(items)
        local out = {}
        for i, item in ipairs(items) do
            out[i] = item.id or item.name
        end
        return out
    end

    local FOLDERS = { "Adonais", "The Annals", "atlas", "Zines" }

    local function after_folders(list)
        local out = {}
        for i, name in ipairs(FOLDERS) do
            out[i] = name
        end
        for _, id in ipairs(list) do
            out[#out + 1] = id
        end
        return out
    end

    local function view(sort, status, statuses, times)
        return ids(LibraryOrder.view(listing(), sort, status, progress(statuses or {}), times or {}))
    end

    describe("view", function()
        it("puts folders first by the title order of their names, under every sort", function()
            for _, sort in ipairs({ "recent", "title", "author", "series" }) do
                local got = view(sort, "all")
                assert.same(FOLDERS, { got[1], got[2], got[3], got[4] }, sort)
                assert.equals(13, #got, sort)
            end
        end)

        it("gives the listing's own tables", function()
            local list = listing()
            local items = LibraryOrder.view(list, "title", "all", progress({}), {})
            assert.equals(list.folders[4], items[1])
            assert.equals(list.books[8], items[5])
        end)

        it("sorts Title by lowercase title, one leading The, A or An ignored", function()
            assert.same(after_folders({ "a", "n", "b", "d", "l", "o", "e", "t", "w" }), view("title", "all"))
        end)

        it("drops an article only when a space follows it, and only one", function()
            local items = LibraryOrder.view({ books = {
                book("1", "Theory"),
                book("2", "Pride"),
                book("3", "An Ode"),
                book("4", "Antigone"),
                book("5", "Anathem"),
                book("6", "The The"),
                book("7", "the tempest"),
            }, folders = {} }, "title", "all", progress({}), {})
            -- Keys: theory, pride, ode, antigone, anathem, the, tempest.
            assert.same({ "5", "4", "3", "2", "7", "6", "1" }, ids(items))
        end)

        it("breaks title ties by id", function()
            local items = LibraryOrder.view({ books = {
                book("z", "Dune"),
                book("m", "dune"),
                book("q", "The Dune"),
            }, folders = {} }, "title", "all", progress({}), {})
            assert.same({ "m", "q", "z" }, ids(items))
        end)

        it("sorts Author by the first author's surname key, then title, no author last", function()
            assert.same(after_folders({ "d", "o", "e", "t", "w", "a", "l", "n", "b" }), view("author", "all"))
        end)

        it("keys Author by the first author alone and reads malformed authors as none", function()
            local items = LibraryOrder.view({ books = {
                book("x", "Xenia", { authors = { "Zora Zed", "Alan Aardvark" } }),
                book("y", "Yonder", { authors = { "Mona Middle" } }),
                book("q", "Quiet", { authors = "Alan Aardvark" }),
                book("p", "Plain", { authors = { 7 } }),
            }, folders = {} }, "author", "all", progress({}), {})
            assert.same({ "y", "x", "p", "q" }, ids(items))
        end)

        it("sorts Series by the series name's title order, then index with none after, no series last", function()
            assert.same(after_folders({ "d", "w", "t", "e", "a", "n", "b", "l", "o" }), view("series", "all"))
        end)

        it("keeps two series whose names key alike apart, and reads a NaN index as none", function()
            local items = LibraryOrder.view({ books = {
                book("1", "One", { series = "The Saga", series_index = 2 }),
                book("2", "Two", { series = "Saga", series_index = 1 }),
                book("3", "Three", { series = "The Saga", series_index = 1 }),
                book("4", "Four", { series = "Saga", series_index = 0 / 0 }),
                book("5", "Five", { series = "Saga", series_index = 3 }),
            }, folders = {} }, "series", "all", progress({}), {})
            assert.same({ "2", "5", "4", "3", "1" }, ids(items))
        end)

        it("sorts Recent by the history's time, newest first, never-opened books after by title", function()
            local times = { ["t"] = 300, ["a"] = 200, ["d"] = 100 }
            assert.same(after_folders({ "t", "a", "d", "n", "b", "l", "o", "e", "w" }),
                view("recent", "all", nil, times))
        end)

        it("breaks a tie in the history's time by title", function()
            local times = { ["w"] = 100, ["b"] = 100 }
            assert.same(after_folders({ "b", "w", "a", "n", "d", "l", "o", "e", "t" }),
                view("recent", "all", nil, times))
        end)

        local statuses = { a = "reading", l = "reading", t = "complete", d = "abandoned", w = "new" }

        it("shows under Reading only the books being read, folders kept", function()
            assert.same(after_folders({ "a", "l" }), view("title", "reading", statuses))
        end)

        it("shows under Finished only the complete books, folders kept", function()
            assert.same(after_folders({ "t" }), view("title", "finished", statuses))
        end)

        it("shows under All every book, new and on hold included", function()
            assert.same(after_folders({ "a", "n", "b", "d", "l", "o", "e", "t", "w" }),
                view("title", "all", statuses))
        end)

        it("reads each book's progress at most once per view", function()
            for _, status in ipairs({ "reading", "finished", "all" }) do
                local calls = {}
                LibraryOrder.view(listing(), "title", status, function(record)
                    calls[record.id] = (calls[record.id] or 0) + 1
                    return { status = statuses[record.id] or "new" }
                end, {})
                for id, count in pairs(calls) do
                    assert.equals(1, count, status .. " " .. id)
                end
            end
        end)

        it("reads a progress that is not a table as no status", function()
            local items = LibraryOrder.view(listing(), "title", "reading", function(record)
                return record.id == "a" and { status = "reading" } or nil
            end, {})
            assert.same(after_folders({ "a" }), ids(items))
        end)

        it("shows the folders alone when no book is under the status", function()
            assert.same(FOLDERS, view("title", "finished", {}))
        end)
    end)

    describe("history_times", function()
        local ReadHistory = require("readhistory")
        local root = os.getenv("KO_HOME") .. "/library-order-history"
        local saved

        local function touch(path)
            local f = assert(io.open(path, "w"))
            f:close()
        end

        before_each(function()
            saved = ReadHistory.hist
            lfs.mkdir(root)
            touch(root .. "/a.epub")
            touch(root .. "/b.epub")
        end)

        after_each(function()
            ReadHistory.hist = saved
            os.remove(root .. "/a.epub")
            os.remove(root .. "/b.epub")
            os.remove(root)
        end)

        it("maps each history file's realpath id to its newest time, skipping files gone", function()
            ReadHistory.hist = {
                { file = root .. "/b.epub", time = 300 },
                { file = root .. "/gone.epub", time = 250 },
                { file = root .. "/a.epub", time = 200 },
                { file = root .. "/b.epub", time = 100 },
            }
            local real = ffiutil.realpath(root)
            assert.same({
                ["file:" .. real .. "/b.epub"] = 300,
                ["file:" .. real .. "/a.epub"] = 200,
            }, LibraryOrder.history_times())
        end)

        it("gives ids that match the book records' ids", function()
            ReadHistory.hist = { { file = root .. "/a.epub", time = 200 } }
            local record = require("books").for_path(root .. "/a.epub")
            assert.equals(200, LibraryOrder.history_times()[record.id])
        end)

        it("skips entries with no file or no numeric time", function()
            ReadHistory.hist = {
                { time = 300 },
                { file = root .. "/b.epub" },
                { file = root .. "/a.epub", time = 200 },
            }
            local real = ffiutil.realpath(root)
            assert.same({ ["file:" .. real .. "/a.epub"] = 200 }, LibraryOrder.history_times())
        end)
    end)

    describe("page", function()
        local function numbers(n)
            local out = {}
            for i = 1, n do
                out[i] = i
            end
            return out
        end

        it("gives one empty page for no items", function()
            local items, count, n = LibraryOrder.page({}, 1)
            assert.same({}, items)
            assert.equals(1, count)
            assert.equals(1, n)
        end)

        it("gives one full page for six items", function()
            local items, count = LibraryOrder.page(numbers(6), 1)
            assert.same({ 1, 2, 3, 4, 5, 6 }, items)
            assert.equals(1, count)
        end)

        it("puts the seventh item on a second page", function()
            assert.same({ 1, 2, 3, 4, 5, 6 }, (LibraryOrder.page(numbers(7), 1)))
            local items, count = LibraryOrder.page(numbers(7), 2)
            assert.same({ 7 }, items)
            assert.equals(2, count)
        end)

        it("slices thirteen items into three pages", function()
            assert.same({ 7, 8, 9, 10, 11, 12 }, (LibraryOrder.page(numbers(13), 2)))
            local items, count = LibraryOrder.page(numbers(13), 3)
            assert.same({ 13 }, items)
            assert.equals(3, count)
        end)

        it("clamps a page past the end to the last and one before the first to the first", function()
            local items, count, n = LibraryOrder.page(numbers(13), 9)
            assert.same({ 13 }, items)
            assert.equals(3, count)
            assert.equals(3, n)
            items, count, n = LibraryOrder.page(numbers(13), 0)
            assert.same({ 1, 2, 3, 4, 5, 6 }, items)
            assert.equals(3, count)
            assert.equals(1, n)
            items, count, n = LibraryOrder.page(numbers(13), nil)
            assert.same({ 1, 2, 3, 4, 5, 6 }, items)
            assert.equals(3, count)
            assert.equals(1, n)
        end)
    end)

    describe("memory", function()
        local root = os.getenv("KO_HOME") .. "/library-order-memory"
        local one, two, link

        before_each(function()
            lfs.mkdir(root)
            one, two, link = root .. "/one", root .. "/two", root .. "/link"
            lfs.mkdir(one)
            lfs.mkdir(two)
            assert(lfs.link(one, link, true))
        end)

        after_each(function()
            os.remove(link)
            os.remove(one)
            os.remove(two)
            os.remove(root)
        end)

        local function stored()
            return LuaSettings:open(harness.state_file):readSetting("library")
        end

        local function reload()
            package.unload("state") -- luacheck: ignore 143
            package.unload("library_order") -- luacheck: ignore 143
            LibraryOrder = require("library_order")
        end

        it("reads Recent and All for a folder never picked, and no folder left", function()
            assert.same({ sort = "recent", status = "all" }, LibraryOrder.choice(one))
            assert.is_nil(LibraryOrder.left())
        end)

        it("stores a choice for that folder alone, by its realpath", function()
            assert.is_true(LibraryOrder.choose(one, "title", "reading"))
            assert.same({ sort = "title", status = "reading" }, LibraryOrder.choice(one))
            assert.same({ sort = "title", status = "reading" }, LibraryOrder.choice(link))
            assert.same({ sort = "recent", status = "all" }, LibraryOrder.choice(two))
            assert.same({ [ffiutil.realpath(one)] = { sort = "title", status = "reading" } }, stored().folders)
        end)

        it("keeps the other field when a choice leaves one out", function()
            assert.is_true(LibraryOrder.choose(one, "series", nil))
            assert.is_true(LibraryOrder.choose(one, nil, "finished"))
            assert.same({ sort = "series", status = "finished" }, LibraryOrder.choice(one))
        end)

        it("refuses a sort or status it does not know, storing nothing", function()
            local logged = spy.on(logger, "warn")
            finally(function()
                logged:revert()
            end)
            assert.is_false(LibraryOrder.choose(one, "sideways", "all"))
            assert.is_false(LibraryOrder.choose(one, "title", "unread"))
            assert.same({ sort = "recent", status = "all" }, LibraryOrder.choice(one))
            assert.is_nil(stored())
            assert.spy(logged).was_called()
        end)

        it("stores the folder and page left", function()
            assert.is_true(LibraryOrder.leave(two, 3))
            assert.same({ dir = two, page = 3 }, LibraryOrder.left())
            assert.same({ dir = two, page = 3 }, stored().at)
        end)

        it("reads the choices and the folder left back after the plugin reloads", function()
            assert.is_true(LibraryOrder.choose(one, "author", "finished"))
            assert.is_true(LibraryOrder.choose(two, "title", "all"))
            assert.is_true(LibraryOrder.leave(one, 2))
            reload()
            assert.same({ sort = "author", status = "finished" }, LibraryOrder.choice(one))
            assert.same({ sort = "title", status = "all" }, LibraryOrder.choice(two))
            assert.same({ dir = one, page = 2 }, LibraryOrder.left())
        end)

        it("keeps everything under the one state key library", function()
            assert.is_true(LibraryOrder.choose(one, "author", "finished"))
            assert.is_true(LibraryOrder.leave(one, 2))
            local data = dofile(harness.state_file)
            local keys = {}
            for key in pairs(data) do
                keys[#keys + 1] = key
            end
            assert.same({ "library" }, keys)
            assert.same({
                folders = { [ffiutil.realpath(one)] = { sort = "author", status = "finished" } },
                at = { dir = one, page = 2 },
            }, data.library)
        end)

        describe("a malformed value", function()
            local logged

            before_each(function()
                logged = spy.on(logger, "warn")
            end)

            after_each(function()
                logged:revert()
            end)

            local function store(value)
                lfs.mkdir(harness.state_dir)
                LuaSettings:open(harness.state_file):saveSetting("library", value):flush()
                reload()
            end

            it("reads a value that is not a table as the defaults, logged", function()
                store("sideways")
                assert.same({ sort = "recent", status = "all" }, LibraryOrder.choice(one))
                assert.is_nil(LibraryOrder.left())
                assert.spy(logged).was_called()
            end)

            it("reads a malformed folder entry or folder left as the defaults, logged", function()
                store({
                    folders = {
                        [ffiutil.realpath(one)] = { sort = "sideways", status = "reading" },
                        [ffiutil.realpath(two)] = "title",
                    },
                    at = { dir = 5, page = 2 },
                })
                assert.same({ sort = "recent", status = "reading" }, LibraryOrder.choice(one))
                assert.same({ sort = "recent", status = "all" }, LibraryOrder.choice(two))
                assert.is_nil(LibraryOrder.left())
                assert.spy(logged).was_called()
            end)

            it("reads a page left that is not a whole number from 1 as no folder left", function()
                for _, page in ipairs({ 0, 1.5, "2", 0 / 0 }) do
                    store({ at = { dir = one, page = page } })
                    assert.is_nil(LibraryOrder.left(), tostring(page))
                end
            end)

            it("is replaced by a well-formed value on the next choice", function()
                store({ folders = "nonsense", at = 7 })
                assert.is_true(LibraryOrder.choose(one, "title", "all"))
                assert.same({ folders = { [ffiutil.realpath(one)] = { sort = "title", status = "all" } } },
                    stored())
            end)
        end)
    end)
end)
