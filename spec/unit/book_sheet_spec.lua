-- The book sheet (sheets' C5), its read status sub-sheet (C6) and the featured-book picker (C7),
-- opened by a hold on the featured slot of a shown home over a real file manager. Books are
-- copies of the fixture library's EPUBs under KO_HOME, in KOReader's history (ReadHistory.hist,
-- realpaths) and with sidecars in the "dir" location, as featured_book_spec.lua writes them;
-- status writes and pins land in the real sidecars and settings file there.
describe("the book sheet", function()
    local harness = require("plugin_harness")
    local BookList = require("ui/widget/booklist")
    local DataStorage = require("datastorage")
    local DocSettings = require("docsettings")
    local Event = require("ui/event")
    local InfoMessage = require("ui/widget/infomessage")
    local ReadHistory = require("readhistory")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local time = require("ui/time")
    local util = require("util")
    local Screen = require("device").screen
    local Featured, FeaturedBook, FeaturedCover, Home, Settings, SettingsMenu, Sheet, State

    local NOTE = "Authors are coming with the library."

    -- Undo steps for the running test, run last first after it.
    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
    end

    -- Sets t[key] to value for the rest of the test.
    local function replace(t, key, value)
        local saved = t[key]
        t[key] = value
        cleanup(function()
            t[key] = saved
        end)
    end

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

    -- The file's bytes, or false when there is none.
    local function bytes(path)
        return lfs.attributes(path, "mode") == "file" and read(path)
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

    local books_root = os.getenv("KO_HOME") .. "/book-sheet-books"
    local books_dir, saved_hist, saved_location, loaded, preload

    -- A copy of a fixture EPUB under books_dir, by its realpath.
    local function book(name)
        local path = books_dir .. "/" .. name
        write(path, read(harness.library .. "/frankenstein.epub"))
        return path
    end

    -- The sidecar of file in the "dir" location (docsettings.lua:118-135).
    local function sidecar_path(file)
        return DocSettings:getSidecarDir(file, "dir") .. "/" .. DocSettings.getSidecarFilename(file)
    end

    -- Writes file's sidecar with the Lua source of its data table; returns its path.
    local function sidecar(file, lua)
        local path = sidecar_path(file)
        util.makePath((path:match("^(.*)/")))
        write(path, "return " .. lua)
        return path
    end

    local function sidecar_data(file)
        return dofile(sidecar_path(file))
    end

    -- KOReader's history, most recent first: each { file, time } entry selectable.
    local function history(entries)
        local hist = {}
        for i, entry in ipairs(entries) do
            hist[i] = { file = entry[1], time = entry[2] or os.time(), select_enabled = true }
        end
        ReadHistory.hist = hist
    end

    -- A file manager with its home up, the home's after_show run.
    local function fm_with_home()
        local fm = harness.show_fm()
        harness.tick(4)
        assert.equals(Home.shown, harness.top())
        return fm
    end

    local function featured_slot()
        for _, slot in ipairs(Home.shown.slots) do
            if slot.widget == "featured" then
                return slot
            end
        end
        error("no featured slot")
    end

    local function centre(rect)
        return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
    end

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    -- Holds the featured slot's centre; returns the sheet shown, or nil.
    local function hold_book()
        local x, y = centre(featured_slot().rect)
        send(harness.gesture("hold", x, y))
        return Sheet.shown
    end

    -- The shown sheet's laid-out row labelled label.
    local function place_of(label)
        for _, place in ipairs(Sheet.shown.rows) do
            if place.row.label == label then
                return place
            end
        end
        error("no row " .. label)
    end

    local function tap(label)
        local x, y = centre(place_of(label).rect)
        send(harness.gesture("tap", x, y))
    end

    -- The shown sheet's rows as given, each { label, tick }.
    local function rows()
        local out = {}
        for i, row in ipairs(Sheet.shown.spec.rows) do
            out[i] = { row.label, row.tick == true }
        end
        return out
    end

    -- Counts the shown home's refreshes, each still run.
    local function count_refreshes()
        local home = Home.shown
        local count = { n = 0 }
        local refresh = home.refresh
        home.refresh = function(self)
            count.n = count.n + 1
            return refresh(self)
        end
        return count
    end

    -- os.time() reads instant while fn runs; os.time with a table is the real one.
    local function at(instant, fn)
        local real = os.time
        os.time = function(t) -- luacheck: ignore 122
            if t == nil then
                return instant
            end
            return real(t)
        end
        local ok, err = pcall(fn)
        os.time = real -- luacheck: ignore 122
        assert(ok, err)
    end

    local function local_time(year, month, day, hour, min)
        return os.time{ year = year, month = month, day = day, hour = hour, min = min or 0 }
    end

    -- Spins until the monotonic clock moves past the instant it returns.
    local function moment()
        local t = time.monotonic()
        while time.monotonic() <= t do
        end
        return t
    end

    before_each(function()
        harness.load()
        Featured = require("widgets/featured")
        FeaturedBook = require("featured_book")
        FeaturedCover = require("featured_cover")
        Home = require("home")
        Settings = require("settings")
        SettingsMenu = require("settings_menu")
        Sheet = require("sheet")
        State = require("state")
        saved_location = G_reader_settings:readSetting("document_metadata_folder")
        G_reader_settings:saveSetting("document_metadata_folder", "dir")
        remove_tree(books_root)
        remove_tree(DataStorage:getDocSettingsDir())
        assert(lfs.mkdir(books_root))
        books_dir = ffiutil.realpath(books_root)
        saved_hist = ReadHistory.hist
        for file in pairs(BookList.book_info_cache) do
            BookList.book_info_cache[file] = nil
        end
        loaded, preload = package.loaded.bookinfomanager, package.preload.bookinfomanager
        package.loaded.bookinfomanager = nil
        package.preload.bookinfomanager = function()
            error("CoverBrowser is disabled in this spec")
        end
    end)

    after_each(function()
        for i = #cleanups, 1, -1 do
            cleanups[i]()
        end
        cleanups = {}
        harness.teardown()
        ReadHistory.hist = saved_hist
        for file in pairs(BookList.book_info_cache) do
            BookList.book_info_cache[file] = nil
        end
        package.loaded.bookinfomanager = loaded
        package.preload.bookinfomanager = preload
        G_reader_settings:saveSetting("document_metadata_folder", saved_location)
        remove_tree(books_root)
        remove_tree(DataStorage:getDocSettingsDir())
    end)

    describe("the sheet", function()
        local a

        before_each(function()
            a = book("a.epub")
        end)

        it("is the book's, headed with its title and author", function()
            sidecar(a, '{ percent_finished = 0.62, doc_props = { title = "Frankenstein", authors = "Mary Shelley" } }')
            history({ { a } })
            fm_with_home()
            assert.is_not_nil(hold_book())
            assert.equals(Sheet.shown, harness.top())
            assert.equals(Home.shown, harness.top(2))
            local spec = Sheet.shown.spec
            assert.equals("book", spec.name)
            assert.equals("book", spec.band)
            assert.equals("Frankenstein", spec.header.title)
            assert.equals("Mary Shelley", spec.header.author)
        end)

        describe("meta line", function()
            before_each(function()
                sidecar(a, "{ percent_finished = 0.62 }")
            end)

            local function chapter(text)
                assert.is_true(State.set("featured_chapter_file", a))
                assert.is_true(State.set("featured_chapter", text))
            end

            -- The meta of the sheet a hold opens at now, a's history entry at opened_at.
            local function meta(now, opened_at)
                history({ { a, opened_at } })
                fm_with_home()
                at(now, hold_book)
                return Sheet.shown.spec.header.meta
            end

            it("reads the percent, the chapter and opened today for an hour ago", function()
                chapter("Letter IV")
                local now = local_time(2026, 10, 15, 15)
                assert.equals("62% · Letter IV · opened today", meta(now, now - 3600))
            end)

            it("reads opened yesterday for the previous calendar day at 23:59 when now is 00:01", function()
                chapter("Letter IV")
                assert.equals("62% · Letter IV · opened yesterday",
                    meta(local_time(2026, 10, 15, 0, 1), local_time(2026, 10, 14, 23, 59)))
            end)

            -- 50 hours before, which is two days by hours.
            it("reads opened 3 days ago by calendar day, not by hours", function()
                assert.equals("62% · opened 3 days ago",
                    meta(local_time(2026, 10, 15, 1), local_time(2026, 10, 12, 23)))
            end)

            it("reads a time in the future as today", function()
                local now = local_time(2026, 10, 15, 15)
                assert.equals("62% · opened today", meta(now, now + 3 * 86400))
            end)

            it("leaves out the chapter when there is none", function()
                local now = local_time(2026, 10, 15, 15)
                assert.equals("62% · opened today", meta(now, now - 60))
            end)

            it("leaves out opened for a pinned book with no history entry", function()
                chapter("Letter IV")
                local other = book("other.epub")
                history({ { other } })
                assert.is_true(Settings.set("featured.pinned", a))
                fm_with_home()
                hold_book()
                assert.equals(a, featured_slot().built.book.file)
                assert.equals("62% · Letter IV", Sheet.shown.spec.header.meta)
            end)
        end)

        it("lists Open, Book details, Read status, More by this author, Feature a different book and "
            .. "This widget's settings with their icons", function()
            history({ { a } })
            fm_with_home()
            hold_book()
            local got = {}
            for i, row in ipairs(Sheet.shown.spec.rows) do
                got[i] = { row.label, row.icon }
            end
            assert.same({
                { "Open", "open_book" },
                { "Book details", "info" },
                { "Read status", "bookmark" },
                { "More by this author", "authors" },
                { "Feature a different book", "list" },
                { "This widget's settings", "settings" },
            }, got)
            assert.equals(6, #Sheet.shown.rows)
            local status, more = place_of("Read status").row, place_of("More by this author").row
            assert.equals("status", status.chip)
            assert.equals("›", more.detail)
            assert.is_nil(more.chip)
            for _, label in ipairs({ "Open", "Book details", "Feature a different book", "This widget's settings" }) do
                assert.is_nil(place_of(label).row.detail, label)
            end
        end)

        for _, case in ipairs({
            { "reading", '{ summary = { status = "reading" } }', "Reading ›" },
            { "abandoned", '{ summary = { status = "abandoned" } }', "On hold ›" },
            { "no sidecar", nil, "New ›" },
        }) do
            it("shows KOReader's label for the read status, " .. case[3] .. " for " .. case[1], function()
                if case[2] then
                    sidecar(a, case[2])
                end
                history({ { a } })
                fm_with_home()
                hold_book()
                assert.equals(case[3], place_of("Read status").row.detail)
            end)
        end

        it("opens the book through the file manager's openFile on Open, once", function()
            history({ { a } })
            local fm = fm_with_home()
            local opened = {}
            fm.openFile = function(_, file)
                opened[#opened + 1] = file
            end
            hold_book()
            tap("Open")
            assert.same({ a }, opened)
            assert.is_nil(Sheet.shown)
        end)

        it("shows KOReader's book details for the file on Book details, once", function()
            history({ { a } })
            local fm = fm_with_home()
            local shown = {}
            fm.bookinfo.show = function(_, file)
                shown[#shown + 1] = file
            end
            hold_book()
            tap("Book details")
            assert.same({ a }, shown)
            assert.is_nil(Sheet.shown)
        end)

        it("shows the authors note with no timeout on More by this author", function()
            history({ { a } })
            fm_with_home()
            local home = Home.shown
            hold_book()
            tap("More by this author")
            local note = harness.top()
            assert.equals(InfoMessage, getmetatable(note))
            assert.equals(NOTE, note.text)
            assert.is_nil(note.timeout)
            assert.equals(home, harness.top(2))
            assert.is_nil(Sheet.shown)
        end)

        it("opens the settings stub on This widget's settings, once", function()
            history({ { a } })
            fm_with_home()
            local opened = 0
            replace(SettingsMenu, "open", function()
                opened = opened + 1
            end)
            hold_book()
            tap("This widget's settings")
            assert.equals(1, opened)
            assert.is_nil(Sheet.shown)
        end)

        it("refreshes the home once and shows no sheet when the book's file went after the build", function()
            history({ { a } })
            fm_with_home()
            local home = Home.shown
            local refreshes = count_refreshes()
            assert(os.remove(a))
            hold_book()
            assert.equals(1, refreshes.n)
            assert.is_nil(Sheet.shown)
            assert.equals(home, harness.top())
        end)

        it("builds the header's cover with FeaturedCover at the token size, asking no extraction", function()
            history({ { a } })
            fm_with_home()
            local extractions = 0
            package.loaded.bookinfomanager = {
                getBookInfo = function()
                    return nil
                end,
                isCachedCoverInvalid = function()
                    return true
                end,
                extractInBackground = function()
                    extractions = extractions + 1
                    return true
                end,
                isExtractingInBackground = function()
                    return false
                end,
            }
            local builds = {}
            local build = FeaturedCover.build
            replace(FeaturedCover, "build", function(b, w, h, ctx)
                local cover = build(b, w, h, ctx)
                builds[#builds + 1] = { file = b and b.file, w = w, h = h, cover = cover }
                return cover
            end)
            hold_book()
            harness.tick(3)
            local tokens = Home.shown.ctx.look.sheet
            assert.equals(1, #builds)
            assert.equals(a, builds[1].file)
            assert.equals(Screen:scaleBySize(tokens.cover_w), builds[1].w)
            assert.equals(Screen:scaleBySize(tokens.cover_h), builds[1].h)
            assert.equals(builds[1].cover, Sheet.shown.spec.header.cover)
            assert.equals(0, extractions)
        end)

        describe("where paint_ms starts", function()
            local seen

            before_each(function()
                seen = {}
                local show = Sheet.show
                replace(Sheet, "show", function(spec, ctx, opts)
                    seen[spec.name] = opts and opts.started
                    return show(spec, ctx, opts)
                end)
            end)

            it("is the hold, before the header's cover is built", function()
                history({ { a } })
                fm_with_home()
                local entered
                local build = FeaturedCover.build
                replace(FeaturedCover, "build", function(...)
                    entered = entered or moment()
                    return build(...)
                end)
                hold_book()
                assert.is_number(seen.book)
                assert.is_number(entered)
                assert.truthy(seen.book <= entered)
            end)

            it("is the tap on Read status, before its sidecar is opened", function()
                sidecar(a, '{ summary = { status = "reading" } }')
                history({ { a } })
                fm_with_home()
                hold_book()
                local entered
                local get = BookList.getDocSettings
                replace(BookList, "getDocSettings", function(...)
                    entered = entered or moment()
                    return get(...)
                end)
                tap("Read status")
                assert.equals("status", Sheet.shown.spec.name)
                assert.is_number(seen.status)
                assert.is_number(entered)
                assert.truthy(seen.status <= entered)
            end)

            it("is the tap on Feature a different book, before the history is read", function()
                sidecar(a, '{ summary = { status = "reading" } }')
                history({ { a } })
                fm_with_home()
                hold_book()
                local entered
                local recent = FeaturedBook.recent
                replace(FeaturedBook, "recent", function(...)
                    entered = entered or moment()
                    return recent(...)
                end)
                tap("Feature a different book")
                assert.equals("picker", Sheet.shown.spec.name)
                assert.is_number(seen.picker)
                assert.is_number(entered)
                assert.truthy(seen.picker <= entered)
            end)
        end)
    end)

    describe("the read status sub-sheet", function()
        local a

        before_each(function()
            a = book("a.epub")
            history({ { a } })
        end)

        -- The book sheet, then its Read status row.
        local function open_status()
            fm_with_home()
            hold_book()
            tap("Read status")
            assert.equals("status", Sheet.shown.spec.name)
            assert.equals(Sheet.shown, harness.top())
        end

        it("lists Reading, On hold and Finished, the current status ticked, headed with the title", function()
            sidecar(a, '{ doc_props = { title = "Frankenstein" }, summary = { status = "abandoned" } }')
            open_status()
            local spec = Sheet.shown.spec
            assert.equals("book", spec.band)
            assert.equals("Read status", spec.header.heading)
            assert.equals("Frankenstein", spec.header.aside)
            assert.same({ { "Reading", false }, { "On hold", true }, { "Finished", false } }, rows())
            for _, row in ipairs(spec.rows) do
                assert.is_nil(row.icon, row.label)
            end
        end)

        it("writes Finished through KOReader's calls, closes and refreshes the home once", function()
            sidecar(a, '{ summary = { status = "reading" } }')
            open_status()
            local refreshes = count_refreshes()
            tap("Finished")
            local summary = sidecar_data(a).summary
            assert.equals("complete", summary.status)
            assert.truthy(tostring(summary.modified):match("^%d%d%d%d%-%d%d%-%d%d$"))
            assert.equals("complete", BookList.book_info_cache[a].status)
            assert.is_nil(Sheet.shown)
            assert.equals(Home.shown, harness.top())
            assert.equals(1, refreshes.n)
        end)

        it("writes nothing and closes on a tap on the ticked status", function()
            local path = sidecar(a, '{ summary = { status = "reading" } }')
            local before = read(path)
            open_status()
            local refreshes = count_refreshes()
            tap("Reading")
            assert.equals(before, read(path))
            assert.is_nil(Sheet.shown)
            assert.equals(0, refreshes.n)
        end)

        it("ticks nothing for a book with no sidecar, and creates one on a tap on On hold", function()
            assert.is_false(bytes(sidecar_path(a)))
            open_status()
            assert.same({ { "Reading", false }, { "On hold", false }, { "Finished", false } }, rows())
            tap("On hold")
            assert.equals("abandoned", sidecar_data(a).summary.status)
            assert.is_nil(Sheet.shown)
        end)

        it("keeps the sidecar's other summary fields through a status change", function()
            sidecar(a, '{ percent_finished = 0.4, summary = { status = "reading", note = "A note", rating = 4 } }')
            open_status()
            tap("Finished")
            local data = sidecar_data(a)
            assert.equals("complete", data.summary.status)
            assert.equals("A note", data.summary.note)
            assert.equals(4, data.summary.rating)
            assert.equals(0.4, data.percent_finished)
        end)
    end)

    describe("the picker", function()
        local files

        -- Eight books in the history, Book 1 the most recent, each titled and authored in its
        -- sidecar.
        before_each(function()
            files = {}
            local entries = {}
            for i = 1, 8 do
                files[i] = book("book" .. i .. ".epub")
                sidecar(files[i], string.format('{ doc_props = { title = "Book %d", authors = "Author %d" } }', i, i))
                entries[i] = { files[i], os.time() - i * 60 }
            end
            history(entries)
        end)

        -- The book sheet, then its Feature a different book row.
        local function open_picker()
            fm_with_home()
            hold_book()
            tap("Feature a different book")
            assert.equals("picker", Sheet.shown.spec.name)
            assert.equals(Sheet.shown, harness.top())
        end

        local function settings_bytes()
            return bytes(harness.settings_file)
        end

        local function pinned()
            Settings._reset()
            return Settings.get("featured.pinned")
        end

        it("lists The last one opened, then the six most recent books, the first ticked with no pin", function()
            open_picker()
            local spec = Sheet.shown.spec
            assert.equals("book", spec.band)
            assert.equals("Feature a book", spec.header.heading)
            assert.same({
                { "The last one opened", true },
                { "Book 1", false },
                { "Book 2", false },
                { "Book 3", false },
                { "Book 4", false },
                { "Book 5", false },
                { "Book 6", false },
            }, rows())
            for i = 1, 6 do
                assert.equals("Author " .. i, spec.rows[i + 1].detail)
            end
        end)

        it("pins a tapped book by its realpath, closes, refreshes once and runs the slot's after_show once", function()
            open_picker()
            local refreshes = count_refreshes()
            local shown = {}
            replace(Featured, "after_show", function(ctx, built)
                shown[#shown + 1] = { ctx = ctx, built = built }
            end)
            tap("Book 3")
            assert.equals(ffiutil.realpath(files[3]), pinned())
            assert.is_nil(Sheet.shown)
            assert.equals(1, refreshes.n)
            assert.equals(1, #shown)
            local slot = featured_slot()
            assert.equals(slot.built, shown[1].built)
            assert.equals(Home.shown.ctx, shown[1].ctx)
            assert.equals(files[3], slot.built.book.file)
        end)

        it("ticks the pinned book, and stores false on a tap on The last one opened", function()
            assert.is_true(Settings.set("featured.pinned", files[3]))
            open_picker()
            local got = rows()
            assert.same({ "The last one opened", false }, got[1])
            assert.same({ "Book 3", true }, got[4])
            for i, row in ipairs(got) do
                if i ~= 4 then
                    assert.is_false(row[2], row[1])
                end
            end
            tap("The last one opened")
            assert.is_false(pinned())
            assert.is_nil(Sheet.shown)
        end)

        it("adds a seventh, ticked row for a pinned book older than the six", function()
            assert.is_true(Settings.set("featured.pinned", files[8]))
            open_picker()
            assert.same({
                { "The last one opened", false },
                { "Book 1", false },
                { "Book 2", false },
                { "Book 3", false },
                { "Book 4", false },
                { "Book 5", false },
                { "Book 6", false },
                { "Book 8", true },
            }, rows())
            assert.equals("Author 8", Sheet.shown.spec.rows[8].detail)
        end)

        it("ticks The last one opened for a pin to a file that has gone", function()
            assert.is_true(Settings.set("featured.pinned", books_dir .. "/gone.epub"))
            open_picker()
            local got = rows()
            assert.equals(7, #got)
            assert.same({ "The last one opened", true }, got[1])
            for i = 2, 7 do
                assert.is_false(got[i][2], got[i][1])
            end
        end)

        it("leaves the settings file byte-identical on a tap on the ticked row", function()
            assert.is_true(Settings.set("featured.pinned", files[3]))
            local before = settings_bytes()
            open_picker()
            local refreshes = count_refreshes()
            tap("Book 3")
            assert.equals(before, settings_bytes())
            assert.is_nil(Sheet.shown)
            assert.equals(0, refreshes.n)
        end)

        it("leaves the settings file as it was, refreshes nothing and logs a refused write", function()
            open_picker()
            local before = settings_bytes()
            local refreshes = count_refreshes()
            local shown = 0
            replace(Featured, "after_show", function()
                shown = shown + 1
            end)
            replace(Settings, "set", function()
                return false, "refused on purpose"
            end)
            local errored = spy.on(logger, "err")
            cleanup(function()
                logger.err:revert()
            end)
            tap("Book 3")
            local logged = false
            for _, call in ipairs(errored.calls) do
                for _, arg in ipairs(call.vals) do
                    if tostring(arg):find("refused on purpose", 1, true) then
                        logged = true
                    end
                end
            end
            assert.is_true(logged)
            assert.equals(0, refreshes.n)
            assert.equals(0, shown)
            assert.equals(before, settings_bytes())
            assert.is_nil(Sheet.shown)
        end)
    end)
end)
