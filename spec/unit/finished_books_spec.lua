-- The year's finished books: a book's finish day from its summary's date corrected by the Statistics reading days, and
-- the list walked from KOReader's history, with readhistory, Books and ReadingStats stubbed.
describe("finished books", function()
    local harness = require("plugin_harness")
    local logger = require("logger")
    local Books, FinishedBooks, ReadingStats
    local real_with_progress, real_details, real_days, real_history
    local books, days, errored

    local NOW = os.time{ year = 2026, month = 10, day = 13, hour = 12 }
    local NEW_YEAR = os.time{ year = 2026, month = 1, day = 1, hour = 0 }

    -- A history entry for name, opened seconds after New Year.
    local function opened(name, after)
        return { file = "/books/" .. name, time = NEW_YEAR + (after or 1000) }
    end

    -- A book at name in the stubbed Books: status, the summary's date, and its md5, its name.
    local function book(name, status, modified, title)
        books["/books/" .. name] = { status = status, modified = modified, title = title or name, md5 = name }
    end

    local function titles(list)
        local names = {}
        for i, entry in ipairs(list) do
            names[i] = entry.record.title
        end
        return names
    end

    before_each(function()
        harness.load()
        Books = package.loaded["books"]
        ReadingStats = package.loaded["reading_stats"]
        FinishedBooks = package.loaded["finished_books"]
        books, days = {}, {}
        real_with_progress, real_details, real_days = Books.with_progress, Books.details, ReadingStats.reading_days
        Books.with_progress = function(path)
            local found = books[path]
            if not found then
                return nil
            end
            if found.raises then
                error("kopanda-test: " .. path)
            end
            return { path = path, title = found.title }, { status = found.status, md5 = found.md5 }
        end
        Books.details = function(record)
            return { modified = books[record.path].modified }
        end
        ReadingStats.reading_days = function()
            return days
        end
        real_history = require("readhistory").hist
        errored = spy.on(logger, "err")
    end)

    after_each(function()
        logger.err:revert()
        require("readhistory").hist = real_history
        Books.with_progress, Books.details = real_with_progress, real_details
        ReadingStats.reading_days = real_days
        harness.teardown()
    end)

    local function history(entries)
        require("readhistory").hist = entries
    end

    describe("finish_day", function()
        it("takes a stamp on a reading day as that day", function()
            assert.equals("2026-03-10", FinishedBooks.finish_day("2026-03-10", { "2026-03-01", "2026-03-10" }))
        end)

        it("takes the last reading day for a rating saved after the finish", function()
            assert.equals("2026-01-20", FinishedBooks.finish_day("2026-03-10", { "2026-01-02", "2026-01-20" }))
        end)

        it("ignores a reading day after the stamp", function()
            assert.equals("2026-03-10", FinishedBooks.finish_day("2026-03-10", { "2026-03-10", "2026-03-20" }))
        end)

        it("takes the stamp with no reading days", function()
            assert.equals("2026-03-10", FinishedBooks.finish_day("2026-03-10", {}))
            assert.equals("2026-03-10", FinishedBooks.finish_day("2026-03-10", nil))
        end)

        it("takes the stamp with no reading day on or before it", function()
            assert.equals("2026-03-10", FinishedBooks.finish_day("2026-03-10", { "2026-03-11" }))
        end)
    end)

    describe("list", function()
        it("lists a complete book finished this year, each with its record and day, and no reading one", function()
            book("a.epub", "complete", "2026-02-01")
            book("b.epub", "reading", "2026-02-02")
            history({ opened("b.epub"), opened("a.epub") })
            local list = FinishedBooks.list(NOW)
            assert.equals(1, #list)
            assert.equals("/books/a.epub", list[1].record.path)
            assert.equals("2026-02-01", list[1].day)
        end)

        it("skips a dim entry, its file gone", function()
            book("a.epub", "complete", "2026-02-01")
            local entry = opened("a.epub")
            entry.dim = true
            history({ entry })
            assert.same({}, FinishedBooks.list(NOW))
        end)

        it("stops at an entry opened before the year", function()
            book("a.epub", "complete", "2026-02-01")
            book("b.epub", "complete", "2026-02-02")
            history({ opened("b.epub", 0), opened("a.epub", -1), opened("b.epub", -2) })
            local read = {}
            local with_progress = Books.with_progress
            Books.with_progress = function(path)
                read[#read + 1] = path
                return with_progress(path)
            end
            assert.same({ "b.epub" }, titles(FinishedBooks.list(NOW)))
            assert.same({ "/books/b.epub" }, read)
        end)

        it("skips an entry with no time and lists those after it", function()
            book("a.epub", "complete", "2026-02-01")
            book("b.epub", "complete", "2026-02-02")
            book("c.epub", "complete", "2026-02-03")
            local undated = opened("b.epub")
            undated.time = nil
            history({ opened("a.epub"), undated, opened("c.epub") })
            assert.same({ "a.epub", "c.epub" }, titles(FinishedBooks.list(NOW)))
        end)

        it("lists a file seen twice once", function()
            book("a.epub", "complete", "2026-02-01")
            history({ opened("a.epub", 2000), opened("a.epub", 1000) })
            assert.equals(1, #FinishedBooks.list(NOW))
        end)

        it("drops a finish on 30 December rated on 2 January as last year's", function()
            book("a.epub", "complete", "2026-01-02")
            days["a.epub"] = { "2025-12-29", "2025-12-30" }
            history({ opened("a.epub") })
            assert.same({}, FinishedBooks.list(NOW))
        end)

        it("drops a finish stamped last year", function()
            book("a.epub", "complete", "2025-12-31")
            history({ opened("a.epub") })
            assert.same({}, FinishedBooks.list(NOW))
        end)

        it("keeps a finish on 1 January", function()
            book("a.epub", "complete", "2026-01-01")
            history({ opened("a.epub") })
            assert.equals(1, #FinishedBooks.list(NOW))
        end)

        it("orders by finish, oldest first, then title", function()
            book("c.epub", "complete", "2026-03-01", "Zed")
            book("b.epub", "complete", "2026-02-01", "Beta")
            book("a.epub", "complete", "2026-02-01", "Alpha")
            history({ opened("c.epub"), opened("b.epub"), opened("a.epub") })
            assert.same({ "Alpha", "Beta", "Zed" }, titles(FinishedBooks.list(NOW)))
        end)

        it("corrects the date by the reading days of the book's md5", function()
            book("a.epub", "complete", "2026-03-10")
            days["a.epub"] = { "2026-01-20" }
            history({ opened("a.epub") })
            assert.equals("2026-01-20", FinishedBooks.list(NOW)[1].day)
        end)

        it("skips a book whose summary has no date, or a date that isn't one", function()
            book("a.epub", "complete", nil)
            book("b.epub", "complete", "20260201")
            book("c.epub", "complete", "2026-xx-01")
            book("d.epub", "complete", "2026-02-01")
            history({ opened("a.epub"), opened("b.epub"), opened("c.epub"), opened("d.epub") })
            assert.same({ "d.epub" }, titles(FinishedBooks.list(NOW)))
        end)

        it("logs and skips a failing record, and lists the rest", function()
            book("a.epub", "complete", "2026-02-01")
            book("b.epub", "complete", "2026-02-02")
            books["/books/b.epub"].raises = true
            history({ opened("b.epub"), opened("a.epub") })
            assert.same({ "a.epub" }, titles(FinishedBooks.list(NOW)))
            assert.spy(errored).was.called()
        end)

        it("never raises, reading as nothing when the walk itself fails", function()
            ReadingStats.reading_days = function()
                error("kopanda-test: days")
            end
            assert.same({}, FinishedBooks.list(NOW))
            assert.spy(errored).was.called()
        end)
    end)
end)
