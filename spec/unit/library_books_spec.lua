-- The library's books while the library is open: the first of Series, Authors, Subjects and the search to open walks
-- the library once and the others reuse it; leaving the library, a re-list, the metadata events, a download, a new
-- root, a KOReader screen from the bar and a cover extraction walk again. Books.all is stubbed with records under a
-- root that exists nowhere (spec/shelf_fixture.lua), and CoverBrowser's bookinfomanager where a case needs one.
describe("the library's books", function()
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    local ReadHistory = require("readhistory")
    local NavBar, SeriesScreen, SubjectsScreen, SearchScreen, history

    before_each(function()
        harness.load()
        -- No featured book, whose cover request would count among the extractions.
        history, ReadHistory.hist = ReadHistory.hist, {}
        NavBar = package.loaded["nav_bar"]
        SeriesScreen = package.loaded["series_screen"]
        SubjectsScreen = package.loaded["subjects_screen"]
        SearchScreen = package.loaded["search_screen"]
    end)

    after_each(function()
        ReadHistory.hist = history
        harness.teardown()
    end)

    local FROM = { dir = fixture.ROOT, page = 1 }

    -- Two books of Saga by Ann Author about Fantasy, and Loose by Bea Writer, not downloaded (cover missing).
    local function library()
        local records = fixture.series("Saga", 2)
        for _, record in ipairs(records) do
            record.subjects, record.cover = { "Fantasy" }, "cached"
        end
        records[3] = fixture.book("Loose", { authors = { "Bea Writer" }, subjects = { "Fantasy" }, cover = "cached" })
        return records
    end

    -- The window shown after NavBar.run(id, where), painted.
    local function tab(id, where)
        NavBar.run(id, where)
        harness.tick(2)
        local top = harness.top()
        if id ~= "home" then
            assert.equals(id, top.screen)
        end
        return top
    end

    local function search()
        local screen = SearchScreen.show{ query = "saga", from = FROM }
        harness.tick(2)
        return screen
    end

    local function title_of(screen, id)
        for _, record in ipairs(screen.records) do
            if record.id == id then
                return record.title
            end
        end
    end

    -- records[1] retitled, as the disk would now list it.
    local function retitle(records, title)
        local record = {}
        for k, v in pairs(records[1]) do
            record[k] = v
        end
        record.title = title
        records[1] = record
        return record
    end

    -- CoverBrowser's bookinfomanager over rows ({ [path] = row }), restored after the case: extractInBackground puts
    -- each file's row from lands in rows, and isExtractingInBackground answers running.
    local function coverbrowser(rows)
        local bim = { rows = rows, lands = {}, running = false, extracted = 0 }
        function bim.getBookInfo(_, file)
            return bim.rows[file]
        end
        function bim.isCachedCoverInvalid(info, specs)
            return not info.cover_w or info.cover_w < specs.max_cover_w or info.cover_h < specs.max_cover_h
        end
        function bim.deleteBookInfo(_, file)
            bim.rows[file] = nil
        end
        function bim.extractInBackground(_, files)
            bim.extracted = bim.extracted + 1
            for _, entry in ipairs(files) do
                bim.rows[entry.filepath] = bim.lands[entry.filepath] or bim.rows[entry.filepath]
            end
            return true
        end
        function bim.isExtractingInBackground()
            return bim.running
        end
        local loaded = package.loaded.bookinfomanager
        package.loaded.bookinfomanager = bim
        finally(function()
            package.loaded.bookinfomanager = loaded
            package.loaded["book_covers"].reset()
        end)
        return bim
    end

    -- A row whose cover fits any box, and one too small for any.
    local function big()
        return { cover_fetched = true, has_cover = true, cover_w = 4000, cover_h = 6000 }
    end
    local function small()
        return { cover_fetched = true, has_cover = true, cover_w = 1, cover_h = 1 }
    end

    -- Every record's row, big.
    local function cached(records)
        local rows = {}
        for _, record in ipairs(records) do
            rows[record.path] = big()
        end
        return rows
    end

    it("walks once across Series, Authors, Subjects and the search", function()
        local calls = fixture.install(library())
        fixture.show()
        tab("authors", "series")
        tab("subjects", "authors")
        tab("series", "subjects")
        local screen = search()
        assert.equals(screen, SearchScreen.shown)
        assert.equals(1, calls.all)
        assert.equals(3, #screen.records)
    end)

    it("walks again after the library is left for the home", function()
        local calls = fixture.install(library())
        fixture.show_subjects()
        tab("home", "subjects")
        assert.is_nil(SubjectsScreen.shown)
        assert.is_true(package.loaded["home"].shown ~= nil)
        tab("series", "home")
        assert.equals(2, calls.all)
    end)

    it("walks again after the file manager closes under it, as a book's open closes it", function()
        local calls = fixture.install(library())
        local _, fm = fixture.show()
        fm:onClose()
        harness.tick(2)
        assert.is_nil(SeriesScreen.shown)
        fixture.show_authors()
        assert.equals(2, calls.all)
    end)

    for _, event in ipairs({ "BookMetadataChanged", "InvalidateMetadataCache" }) do
        it("walks again after " .. event .. ", the next window showing the change", function()
            local records = library()
            local calls = fixture.install(records)
            local series = fixture.show()
            local changed = retitle(records, "Saga Renamed")
            UIManager:broadcastEvent(Event:new(event))
            harness.tick(2)
            assert.equals(2, calls.all)
            assert.equals("Saga Renamed", title_of(series, changed.id))
            local authors = tab("authors", "series")
            assert.equals(2, calls.all)
            assert.equals("Saga Renamed", title_of(authors, changed.id))
            -- Dropped at the event itself, not only at the re-list its tick runs.
            retitle(records, "Saga Again")
            UIManager:broadcastEvent(Event:new(event))
            local subjects = SubjectsScreen.show{}
            assert.equals("Saga Again", title_of(subjects, changed.id))
            assert.equals(3, calls.all)
        end)
    end

    it("walks again after a download on the window shown, the next window showing the book", function()
        local records = library()
        local calls = fixture.install(records)
        local series = fixture.show()
        local changed = retitle(records, "Saga Downloaded")
        series:downloaded(records[3])
        assert.equals(2, calls.all)
        assert.equals("Saga Downloaded", title_of(series, changed.id))
        local subjects = tab("subjects", "series")
        assert.equals(2, calls.all)
        assert.equals("Saga Downloaded", title_of(subjects, changed.id))
    end)

    it("walks again after a download that finishes once its window has gone", function()
        local records = library()
        local calls = fixture.install(records)
        local series = fixture.show()
        tab("authors", "series")
        local changed = retitle(records, "Saga Downloaded")
        series:downloaded(records[3])
        local subjects = tab("subjects", "authors")
        assert.equals(2, calls.all)
        assert.equals("Saga Downloaded", title_of(subjects, changed.id))
    end)

    it("walks again after a download on the library's own window", function()
        local records = library()
        local calls = fixture.install(records)
        fixture.show()
        local Library = package.loaded["library"]
        tab("library", "series")
        local changed = retitle(records, "Saga Downloaded")
        Library.shown:downloaded(records[3])
        harness.tick(2)
        local authors = tab("authors", "library")
        assert.equals(2, calls.all)
        assert.equals("Saga Downloaded", title_of(authors, changed.id))
    end)

    it("walks again after a refresh, and the next window reuses that walk", function()
        local records = library()
        local calls = fixture.install(records)
        local series = fixture.show()
        local changed = retitle(records, "Saga Deleted")
        series:refresh()
        assert.equals(2, calls.all)
        local authors = tab("authors", "series")
        assert.equals(2, calls.all)
        assert.equals("Saga Deleted", title_of(authors, changed.id))
    end)

    it("walks again after a book's status page's cover extraction, its row landed with no arrival", function()
        local records = library()
        local calls = fixture.install(records)
        local rows = cached(records)
        local bim = coverbrowser(rows)
        fixture.show()
        assert.equals(0, bim.extracted)
        -- Cached at a box the status page's is bigger than, so the page asks for a bigger cover; the book has none
        -- bigger, so its row lands and nothing arrives.
        rows[records[1].path] = small()
        local changed = retitle(records, "Saga Indexed")
        bim.lands[changed.path] = small()
        local status = package.loaded["book_status_screen"].show{ record = records[1],
            opener = { screen = "series", view = { kind = "list" }, page = 1 } }
        harness.tick(2)
        assert.equals(1, bim.extracted)
        status:back()
        harness.tick(2)
        local series = harness.top()
        assert.equals("series", series.screen)
        assert.equals(2, calls.all)
        assert.equals("Saga Indexed", title_of(series, changed.id))
    end)

    it("walks again after the Library's cover extraction, the next window showing the row it landed", function()
        local records = library()
        local calls = fixture.install(records)
        local bim = coverbrowser(cached(records))
        fixture.show()
        local Library = package.loaded["library"]
        local library_window = tab("library", "series")
        -- Its row dropped, as Refresh covers drops it, and indexed again by the Library.
        package.loaded["book_covers"].forget({ records[1].path })
        local changed = retitle(records, "Saga Indexed")
        bim.lands[changed.path] = big()
        package.loaded["library_covers"].request(library_window, function()
            return Library.shown == library_window
        end, { records[1] })
        harness.tick(2)
        assert.equals(1, bim.extracted)
        local series = tab("series", "library")
        assert.equals(2, calls.all)
        assert.equals("Saga Indexed", title_of(series, changed.id))
    end)

    it("walks again when the library's root changed", function()
        local calls = fixture.install(library())
        fixture.show()
        local home_dir = G_reader_settings:readSetting("home_dir")
        G_reader_settings:saveSetting("home_dir", fixture.ROOT .. "/elsewhere")
        local ok, err = pcall(tab, "authors", "series")
        G_reader_settings:saveSetting("home_dir", home_dir)
        assert(ok, err)
        assert.equals(2, calls.all)
    end)

    it("walks again at the next window after the window's own cover extraction, and not after", function()
        local records = library()
        records[1].cover = "missing"
        local calls = fixture.install(records)
        local bim = coverbrowser({})
        local changed = retitle(records, "Saga Indexed")
        changed.cover = "cached"
        bim.lands[changed.path] = big()
        local series = fixture.show()
        harness.tick(2)
        assert.equals(1, bim.extracted)
        assert.equals("Saga Indexed", title_of(series, changed.id))
        local authors = tab("authors", "series")
        assert.equals(2, calls.all)
        assert.equals("Saga Indexed", title_of(authors, changed.id))
        tab("subjects", "authors")
        assert.equals(1, bim.extracted)
        assert.equals(2, calls.all)
    end)

    it("walks again after a walk taken while an extraction ran, its rows landing with no arrival", function()
        local records = library()
        local calls = fixture.install(records)
        local bim = coverbrowser({})
        bim.running = true
        fixture.show()
        assert.equals(1, bim.extracted)
        tab("authors", "series")
        assert.equals(2, calls.all)
        assert.equals(1, bim.extracted)
        -- The rows land with no cover, so no check counts them as arrived, and the extraction ends.
        local changed = retitle(records, "Saga Indexed")
        for _, record in ipairs(records) do
            bim.rows[record.path] = { cover_fetched = true, has_cover = false }
        end
        bim.running = false
        local subjects = tab("subjects", "authors")
        assert.equals(3, calls.all)
        assert.equals("Saga Indexed", title_of(subjects, changed.id))
        tab("series", "subjects")
        assert.equals(3, calls.all)
    end)

    it("walks again after History from the bar, whose Delete tells nothing", function()
        local calls = fixture.install(library())
        fixture.show()
        local entries = package.loaded["launcher_entries"]
        local run = entries.run
        local opened = {}
        entries.run = function(entry, ...)
            if entry.kind == "koreader" then
                opened[#opened + 1] = entry.target
                return
            end
            return run(entry, ...)
        end
        local ok, err = pcall(function()
            NavBar.run("history", "series")
            assert.same({ "history" }, opened)
            tab("authors", "series")
        end)
        entries.run = run
        assert(ok, err)
        assert.equals(2, calls.all)
    end)

    it("walks again after a show that raised midway, and after the real close that follows", function()
        local calls = fixture.install(library())
        fixture.show()
        local AuthorsScreen = package.loaded["authors_screen"]
        local build = AuthorsScreen.build
        AuthorsScreen.build = function()
            error("build broke on purpose")
        end
        local ok, shown = pcall(AuthorsScreen.show, {})
        AuthorsScreen.build = build
        assert(ok, shown)
        assert.is_nil(shown)
        harness.tick(2)
        fixture.show_authors()
        assert.equals(2, calls.all)
        AuthorsScreen.close()
        harness.tick(2)
        fixture.show()
        assert.equals(3, calls.all)
    end)

    it("gives each window a list of its own, so one's order is not another's", function()
        local records = library()
        fixture.install(records)
        local series = fixture.show()
        table.sort(series.records, function(a, b)
            return a.title > b.title
        end)
        table.remove(series.records)
        local authors = tab("authors", "series")
        local ids = {}
        for i, record in ipairs(authors.records) do
            ids[i] = record.id
        end
        assert.same({ records[1].id, records[2].id, records[3].id }, ids)
    end)
end)
