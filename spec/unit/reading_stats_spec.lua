-- Reading stats from KOReader's Statistics database: a book's speed and history and the last year's reading, read from
-- fixture databases under a fixed TZ, the off and empty states, and the memo of the reads. The lj-sqlite3 binding
-- ffi.cdef()s on load (spec/emulator/driver.lua:87-88), so a Busted process loads it once:
-- books_coverbrowser_spec.lua's expose block requires it and keeps it loaded, and runs before this file in
-- bin/check's sorted files.
describe("reading stats", function()
    local harness = require("plugin_harness")
    local ffi = require("ffi")
    require("ffi/posix_h")
    local SQ3 = require("lua-ljsqlite3/init")
    local DataStorage = require("datastorage")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    pcall(ffi.cdef, "void tzset(void);")

    local db_path = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    local ReadingStats, errored

    -- The plugin's own DDL (plugins/statistics.koplugin/main.lua:405-419, :462-480) and schema
    -- version (:35).
    local DDL = {
        [[CREATE TABLE IF NOT EXISTS book
            (
                id integer PRIMARY KEY autoincrement,
                title text,
                authors text,
                notes      integer,
                last_open  integer,
                highlights integer,
                pages      integer,
                series text,
                language text,
                md5 text,
                total_read_time  integer,
                total_read_pages integer
            );]],
        [[CREATE TABLE IF NOT EXISTS page_stat_data
            (
                id_book     integer,
                page        integer NOT NULL DEFAULT 0,
                start_time  integer NOT NULL DEFAULT 0,
                duration    integer NOT NULL DEFAULT 0,
                total_pages integer NOT NULL DEFAULT 0,
                UNIQUE (id_book, page, start_time),
                FOREIGN KEY(id_book) REFERENCES book(id)
            );]],
        "CREATE INDEX IF NOT EXISTS page_stat_data_start_time ON page_stat_data(start_time);",
        -- The numbers table and page_stat view (main.lua:422-451).
        "CREATE TABLE IF NOT EXISTS numbers (number INTEGER PRIMARY KEY);",
        [[WITH RECURSIVE counter AS
            (
                SELECT 1 as N UNION ALL
                SELECT N + 1 FROM counter WHERE N < 1000
            )
            INSERT INTO numbers SELECT N AS number FROM counter;]],
        [[CREATE VIEW IF NOT EXISTS page_stat AS
            SELECT id_book, first_page + idx - 1 AS page, start_time,
                duration / (last_page - first_page + 1) AS duration
            FROM (
                SELECT id_book, page, total_pages, pages, start_time, duration,
                    ((page - 1) * pages) / total_pages + 1 AS first_page,
                    max(((page - 1) * pages) / total_pages + 1, (page * pages) / total_pages) AS last_page,
                    idx
                FROM page_stat_data
                JOIN book ON book.id = id_book
                JOIN (SELECT number as idx FROM numbers) AS N ON idx <= (last_page - first_page + 1)
            );]],
        "PRAGMA user_version = 20221111;",
    }

    -- Local time in the spec's TZ.
    local function at(year, month, day, hour, min)
        return os.time{ year = year, month = month, day = day, hour = hour or 12, min = min or 0 }
    end

    -- Tuesday 13 October 2026, 20:42 in Chicago, set once the spec's TZ is.
    local NOW

    -- A Statistics database at db_path holding rows { id_book, start_time, duration }, each on
    -- its own page, in the journal mode the plugin picks on the emulator and current Kindles
    -- (main.lua:455-460), or journal (DELETE, TRUNCATE) when given.
    local function make_db(rows, journal)
        os.remove(db_path)
        os.remove(db_path .. "-wal")
        os.remove(db_path .. "-shm")
        local conn = SQ3.open(db_path)
        conn:exec("PRAGMA journal_mode=" .. (journal or "WAL") .. ";")
        for _, sql in ipairs(DDL) do
            conn:exec(sql)
        end
        local books = {}
        for _, row in ipairs(rows) do
            books[row[1]] = true
        end
        for id in pairs(books) do
            conn:exec(string.format("INSERT INTO book (id, title) VALUES (%d, 'Book %d');", id, id))
        end
        local stmt = conn:prepare("INSERT INTO page_stat_data VALUES (?, ?, ?, ?, ?);")
        conn:exec("BEGIN;")
        for i, row in ipairs(rows) do
            stmt:reset():bind(row[1], i, row[2], row[3], 300):step()
        end
        conn:exec("COMMIT;")
        stmt:close()
        conn:close()
    end

    -- One row of duration seconds for book 1 on the local day offset days from NOW's, at noon.
    local function on_day(offset, duration, book)
        local t = os.date("*t", NOW)
        return { book or 1, at(t.year, t.month, t.day + offset, 12), duration or 600 }
    end

    local function remove_db()
        os.remove(db_path)
        os.remove(db_path .. "-wal")
        os.remove(db_path .. "-shm")
    end

    -- A Statistics database at db_path holding books { id, md5, pages, last_open, total_read_time } and page
    -- rows { id_book, page, start_time, duration, total_pages }, in WAL mode or journal when given.
    local function make_books_db(books, rows, journal)
        remove_db()
        local conn = SQ3.open(db_path)
        conn:exec("PRAGMA journal_mode=" .. (journal or "WAL") .. ";")
        for _, sql in ipairs(DDL) do
            conn:exec(sql)
        end
        local book_stmt = conn:prepare("INSERT INTO book (id, title, md5, pages, last_open, total_read_time) "
            .. "VALUES (?, ?, ?, ?, ?, ?);")
        for _, book in ipairs(books) do
            book_stmt:reset():bind(book[1], "Book " .. book[1], book[2], book[3], book[4], book[5]):step()
        end
        book_stmt:close()
        local stmt = conn:prepare("INSERT INTO page_stat_data VALUES (?, ?, ?, ?, ?);")
        for _, row in ipairs(rows) do
            stmt:reset():bind(row[1], row[2], row[3], row[4], row[5]):step()
        end
        stmt:close()
        conn:close()
    end

    local function logged_error()
        for _, call in ipairs(errored.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find("KoPanda", 1, true) then
                    return true
                end
            end
        end
        return false
    end

    local saved_tz

    setup(function()
        saved_tz = os.getenv("TZ")
        ffi.C.setenv("TZ", "America/Chicago", 1)
        ffi.C.tzset()
        NOW = at(2026, 10, 13, 20, 42)
    end)

    teardown(function()
        if saved_tz then
            ffi.C.setenv("TZ", saved_tz, 1)
        else
            ffi.C.unsetenv("TZ")
        end
        ffi.C.tzset()
    end)

    before_each(function()
        harness.load()
        ReadingStats = package.loaded["reading_stats"]
        errored = spy.on(logger, "err")
        remove_db()
    end)

    after_each(function()
        logger.err:revert()
        G_reader_settings:delSetting("plugins_disabled")
        G_reader_settings:delSetting("statistics")
        remove_db()
        harness.teardown()
    end)

    it("runs at 20:42 on 13 October 2026 in Chicago", function()
        assert.equals("2026-10-13 20:42 CDT", os.date("%Y-%m-%d %H:%M %Z", NOW))
    end)

    describe("seconds_per_page", function()
        it("reads the most recently opened book row of an md5, with its pages", function()
            make_books_db({
                { 1, "abc", 50, 100 },
                { 2, "abc", 80, 200 },
                { 3, "def", 80, 300 },
            }, {
                { 1, 1, 1000, 10, 50 },
                { 2, 1, 2000, 30, 80 },
                { 2, 2, 2100, 50, 80 },
                { 3, 1, 3000, 90, 80 },
            })
            local rate, pages = ReadingStats.seconds_per_page("abc")
            assert.equals(40, rate)
            assert.equals(80, pages)
        end)

        it("caps each page's summed time at max_sec, 120 when the settings hold none", function()
            -- Page 1 is read twice, 200 s and 100 s: 300 s in all, over either cap.
            make_books_db({ { 1, "abc", 100, 100 } }, {
                { 1, 1, 1000, 200, 100 },
                { 1, 1, 5000, 100, 100 },
                { 1, 2, 1300, 20, 100 },
            })
            local rate, pages = ReadingStats.seconds_per_page("abc")
            assert.equals((120 + 20) / 2, rate)
            assert.equals(100, pages)
            assert.is_nil(G_reader_settings:readSetting("statistics"))
            G_reader_settings:saveSetting("statistics", { max_sec = 60 })
            assert.equals((60 + 20) / 2, (ReadingStats.seconds_per_page("abc")))
            G_reader_settings:saveSetting("statistics", { min_sec = 5 })
            assert.equals((120 + 20) / 2, (ReadingStats.seconds_per_page("abc")))
        end)

        it("gives nil for an unknown md5", function()
            make_books_db({ { 1, "abc", 100, 100 } }, { { 1, 1, 1000, 20, 100 } })
            assert.is_nil(ReadingStats.seconds_per_page("zzz"))
        end)

        it("gives nil for a book with no page times", function()
            make_books_db({ { 1, "abc", 100, 100 }, { 2, "def", 100, 200 } }, { { 2, 1, 1000, 20, 100 } })
            assert.is_nil(ReadingStats.seconds_per_page("abc"))
        end)

        it("gives nil for a missing file without creating it or logging an error", function()
            assert.is_nil(ReadingStats.seconds_per_page("abc"))
            assert.is_nil(lfs.attributes(db_path, "mode"))
            assert.is_false(logged_error())
        end)

        it("gives nil with the plugin disabled or not recording", function()
            make_books_db({ { 1, "abc", 100, 100 } }, { { 1, 1, 1000, 20, 100 } })
            assert.equals(20, (ReadingStats.seconds_per_page("abc")))
            G_reader_settings:saveSetting("plugins_disabled", { statistics = true })
            assert.is_nil(ReadingStats.seconds_per_page("abc"))
            G_reader_settings:delSetting("plugins_disabled")
            G_reader_settings:saveSetting("statistics", { is_enabled = false })
            assert.is_nil(ReadingStats.seconds_per_page("abc"))
        end)

        it("gives nil for a corrupt file, and logs it", function()
            local f = assert(io.open(db_path, "wb"))
            f:write(string.rep("not a database ", 100))
            f:close()
            assert.is_nil(ReadingStats.seconds_per_page("abc"))
            assert.is_true(logged_error())
        end)

        it("opens the database read-only and closes it", function()
            make_books_db({ { 1, "abc", 100, 100 } }, { { 1, 1, 1000, 20, 100 } })
            local real_open = SQ3.open
            local calls, conn = {}, nil
            SQ3.open = function(...)
                calls[#calls + 1] = { ... }
                conn = real_open(...)
                return conn
            end
            local ok, err = pcall(ReadingStats.seconds_per_page, "abc")
            SQ3.open = real_open
            assert(ok, err)
            assert.same({ { db_path, "ro" } }, calls)
            -- The binding's own flag, set only once sqlite3_close succeeds (lua-ljsqlite3/init.lua:352-364).
            assert.is_true(conn._closed)
        end)

        it("closes the database after a failed read", function()
            local f = assert(io.open(db_path, "wb"))
            f:write(string.rep("not a database ", 100))
            f:close()
            local real_open = SQ3.open
            local conn
            SQ3.open = function(...)
                conn = real_open(...)
                return conn
            end
            local ok, err = pcall(ReadingStats.seconds_per_page, "abc")
            SQ3.open = real_open
            assert(ok, err)
            assert.is_true(conn._closed)
        end)

        it("leaves both settings unset when it reads them", function()
            make_books_db({ { 1, "abc", 100, 100 } }, { { 1, 1, 1000, 20, 100 } })
            ReadingStats.seconds_per_page("abc")
            assert.is_nil(G_reader_settings:readSetting("plugins_disabled"))
            assert.is_nil(G_reader_settings:readSetting("statistics"))
        end)
    end)

    describe("book_history", function()
        it("reads the most recently opened book row of an md5: its time, its days, its first page and last open",
            function()
                local first = at(2026, 10, 3, 9, 15)
                make_books_db({
                    { 1, "abc", 100, at(2026, 9, 1), 60 },
                    { 2, "abc", 100, at(2026, 10, 12, 21), 27600 },
                }, {
                    { 1, 1, at(2026, 9, 1), 60, 100 },
                    { 2, 1, first, 60, 100 },
                    { 2, 2, at(2026, 10, 3, 10), 60, 100 },
                    { 2, 3, at(2026, 10, 5, 22), 60, 100 },
                    { 2, 4, at(2026, 10, 12, 20), 60, 100 },
                })
                assert.same({ seconds = 27600, days = 3, first = first, last = at(2026, 10, 12, 21) },
                    ReadingStats.book_history("abc"))
            end)

        it("counts two local days for two reads either side of local midnight", function()
            make_books_db({ { 1, "abc", 100, at(2026, 10, 13, 1), 120 } }, {
                { 1, 1, at(2026, 10, 12, 23, 50), 60, 100 },
                { 1, 2, at(2026, 10, 13, 0, 10), 60, 100 },
            })
            assert.equals(2, ReadingStats.book_history("abc").days)
        end)

        it("reads a book row with no page times as no days, no first and a time of 0 where it holds none",
            function()
                make_books_db({ { 1, "abc", 100, at(2026, 10, 12) } }, {})
                assert.same({ seconds = 0, days = 0, last = at(2026, 10, 12) }, ReadingStats.book_history("abc"))
            end)

        it("gives nil for an unknown md5", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, 1000, 20, 100 } })
            assert.is_nil(ReadingStats.book_history("zzz"))
        end)

        it("gives nil for a missing file without creating it or logging an error", function()
            assert.is_nil(ReadingStats.book_history("abc"))
            assert.is_nil(lfs.attributes(db_path, "mode"))
            assert.is_false(logged_error())
        end)

        it("gives nil with the plugin disabled or not recording", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, 1000, 20, 100 } })
            assert.equals(60, ReadingStats.book_history("abc").seconds)
            G_reader_settings:saveSetting("plugins_disabled", { statistics = true })
            assert.is_nil(ReadingStats.book_history("abc"))
            G_reader_settings:delSetting("plugins_disabled")
            G_reader_settings:saveSetting("statistics", { is_enabled = false })
            assert.is_nil(ReadingStats.book_history("abc"))
        end)

        it("gives nil for a corrupt file, and logs it", function()
            local f = assert(io.open(db_path, "wb"))
            f:write(string.rep("not a database ", 100))
            f:close()
            assert.is_nil(ReadingStats.book_history("abc"))
            assert.is_true(logged_error())
        end)

        it("gives nil for a locked database, and logs it", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, 1000, 20, 100 } }, "DELETE")
            local locker = SQ3.open(db_path)
            locker:exec("BEGIN EXCLUSIVE;")
            local ok, history = pcall(ReadingStats.book_history, "abc")
            locker:exec("ROLLBACK;")
            locker:close()
            assert(ok, history)
            assert.is_nil(history)
            assert.is_true(logged_error())
        end)

        it("gives nil, and logs it, when the read itself raises", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, 1000, 20, 100 } })
            local real_open = SQ3.open
            SQ3.open = function()
                error("boom")
            end
            local ok, history = pcall(ReadingStats.book_history, "abc")
            SQ3.open = real_open
            assert(ok, history)
            assert.is_nil(history)
            assert.is_true(logged_error())
        end)

        it("opens the database read-only and closes it", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, 1000, 20, 100 } })
            local real_open = SQ3.open
            local calls, conn = {}, nil
            SQ3.open = function(...)
                calls[#calls + 1] = { ... }
                conn = real_open(...)
                return conn
            end
            local ok, err = pcall(ReadingStats.book_history, "abc")
            SQ3.open = real_open
            assert(ok, err)
            assert.same({ { db_path, "ro" } }, calls)
            assert.is_true(conn._closed)
        end)
    end)

    describe("reading_days", function()
        it("gives each md5's reading days from 1 January of last year, sorted, one entry per day", function()
            make_books_db({
                { 1, "abc", 100, 100, 60 },
                { 2, "def", 100, 100, 60 },
            }, {
                { 1, 1, at(2026, 2, 1), 60, 100 },
                { 1, 2, at(2026, 1, 3, 9), 60, 100 },
                { 1, 3, at(2026, 1, 3, 21), 60, 100 },
                { 2, 1, at(2025, 1, 1, 0, 0), 60, 100 },
                { 2, 2, at(2024, 12, 31, 23, 59), 60, 100 },
            })
            assert.same({
                abc = { "2026-01-03", "2026-02-01" },
                def = { "2025-01-01" },
            }, ReadingStats.reading_days(NOW))
        end)

        it("leaves out a book row with no md5", function()
            make_books_db({ { 1, nil, 100, 100, 60 } }, { { 1, 1, at(2026, 2, 1), 60, 100 } })
            assert.same({}, ReadingStats.reading_days(NOW))
        end)

        it("gives nothing with no database, without creating it or logging an error", function()
            assert.same({}, ReadingStats.reading_days(NOW))
            assert.is_nil(lfs.attributes(db_path, "mode"))
            assert.is_false(logged_error())
        end)

        it("gives nothing with the plugin not recording", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, at(2026, 2, 1), 60, 100 } })
            G_reader_settings:saveSetting("statistics", { is_enabled = false })
            assert.same({}, ReadingStats.reading_days(NOW))
        end)

        it("gives nothing for a file that isn't a database, logged", function()
            local f = assert(io.open(db_path, "w"))
            f:write("not a database, but long enough to be read as a header by sqlite3 at all")
            f:close()
            assert.same({}, ReadingStats.reading_days(NOW))
            assert.is_true(logged_error())
        end)
    end)

    describe("the memo", function()
        local real_open, opened
        local real_time = os.time

        -- Stops os.time() at t; os.time with a date table still converts it.
        local function freeze(t)
            os.time = function(date) -- luacheck: ignore 122
                if date == nil then
                    return t
                end
                return real_time(date)
            end
        end

        -- Dates the file at path seconds_ago in the past.
        local function date_back(path, seconds_ago)
            local t = os.time() - seconds_ago
            assert(lfs.touch(path, t, t))
        end

        -- Dates the database and its WAL file, when there is one, a minute back: files written
        -- before the current second.
        local function settle()
            date_back(db_path, 60)
            if lfs.attributes(db_path .. "-wal", "mode") then
                date_back(db_path .. "-wal", 60)
            end
        end

        -- Counts the read-only opens, which are ReadingStats's.
        before_each(function()
            real_open = SQ3.open
            opened = 0
            SQ3.open = function(path, mode)
                if mode == "ro" then
                    opened = opened + 1
                end
                return real_open(path, mode)
            end
        end)

        after_each(function()
            SQ3.open = real_open
            os.time = real_time -- luacheck: ignore 122
        end)

        it("reads a book's history again when the database or its WAL file changes", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, 1000, 20, 100 } })
            -- A connection Statistics holds open, its last write still in the WAL file.
            local writer = real_open(db_path)
            writer:exec("UPDATE book SET total_read_time = 90 WHERE id = 1;")
            assert.equals("file", lfs.attributes(db_path .. "-wal", "mode"))
            settle()
            assert.equals(90, ReadingStats.book_history("abc").seconds)
            ReadingStats.book_history("abc")
            assert.equals(1, opened)

            date_back(db_path .. "-wal", 30)
            ReadingStats.book_history("abc")
            assert.equals(2, opened)
            date_back(db_path, 30)
            ReadingStats.book_history("abc")
            assert.equals(3, opened)
            writer:close()
        end)

        it("reads again a database dated this second or later", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, {})
            date_back(db_path, -5)
            ReadingStats.book_history("abc")
            ReadingStats.book_history("abc")
            assert.equals(2, opened)
        end)

        -- FAT dates files in two-second steps, rounded down, so in an odd second T a write dated
        -- T-1 can follow another dated T-1 that left the size as it was.
        it("reads again a database dated within the last two seconds", function()
            local now = real_time()
            now = now - now % 2 + 1
            freeze(now)
            make_books_db({ { 1, "abc", 100, 100, 60 } }, {})
            for _, dated in ipairs{ now - 1, now } do
                assert(lfs.touch(db_path, dated, dated))
                opened = 0
                ReadingStats.book_history("abc")
                ReadingStats.book_history("abc")
                assert.equals(2, opened)
            end
        end)

        it("keeps the read of a database dated two seconds back", function()
            local now = real_time()
            now = now - now % 2 + 1
            freeze(now)
            make_books_db({ { 1, "abc", 100, 100, 60 } }, {})
            assert(lfs.touch(db_path, now - 2, now - 2))
            ReadingStats.book_history("abc")
            ReadingStats.book_history("abc")
            assert.equals(1, opened)
        end)

        it("reads a book's rate again only when the files, the md5 or max_sec change", function()
            make_books_db({ { 1, "abc", 100, 100 }, { 2, "def", 100, 200 } },
                { { 1, 1, 1000, 20, 100 }, { 2, 1, 1000, 40, 100 } })
            settle()
            assert.equals(20, (ReadingStats.seconds_per_page("abc")))
            assert.equals(20, (ReadingStats.seconds_per_page("abc")))
            assert.equals(1, opened)
            assert.is_nil(ReadingStats.seconds_per_page("zzz"))
            assert.is_nil(ReadingStats.seconds_per_page("zzz"))
            assert.equals(2, opened)
            assert.equals(40, (ReadingStats.seconds_per_page("def")))
            assert.equals(3, opened)
            G_reader_settings:saveSetting("statistics", { max_sec = 10 })
            assert.equals(10, (ReadingStats.seconds_per_page("def")))
            assert.equals(4, opened)
            date_back(db_path, 30)
            assert.equals(10, (ReadingStats.seconds_per_page("def")))
            assert.equals(5, opened)
        end)

        it("reads the reading days again only when the files or the year change, and every time unsettled", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, at(2026, 2, 1), 60, 100 } })
            settle()
            assert.same({ "2026-02-01" }, ReadingStats.reading_days(NOW).abc)
            ReadingStats.reading_days(NOW + 86400)
            assert.equals(1, opened)
            ReadingStats.reading_days(at(2027, 1, 2))
            assert.equals(2, opened)
            date_back(db_path, 30)
            ReadingStats.reading_days(at(2027, 1, 2))
            assert.equals(3, opened)
            date_back(db_path, 0)
            ReadingStats.reading_days(at(2027, 1, 2))
            ReadingStats.reading_days(at(2027, 1, 2))
            assert.equals(5, opened)
        end)

        it("keeps no failed read of the reading days", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, at(2026, 2, 1), 60, 100 } })
            settle()
            local counting = SQ3.open
            SQ3.open = function(path, mode)
                if mode == "ro" then
                    SQ3.open = counting
                    error("kopanda-test: open")
                end
                return counting(path, mode)
            end
            assert.same({}, ReadingStats.reading_days(NOW))
            assert.same({ "2026-02-01" }, ReadingStats.reading_days(NOW).abc)
        end)

        it("gives no reading days once Statistics stops recording, whatever the memo holds", function()
            make_books_db({ { 1, "abc", 100, 100, 60 } }, { { 1, 1, at(2026, 2, 1), 60, 100 } })
            settle()
            assert.same({ "2026-02-01" }, ReadingStats.reading_days(NOW).abc)
            G_reader_settings:saveSetting("statistics", { is_enabled = false })
            assert.same({}, ReadingStats.reading_days(NOW))
            assert.equals(1, opened)
        end)

        it("reads a book's history again only when the files or the md5 change, and every time unsettled", function()
            make_books_db({ { 1, "abc", 100, 100, 60 }, { 2, "def", 100, 200, 90 } },
                { { 1, 1, 1000, 20, 100 }, { 2, 1, 1000, 40, 100 } })
            settle()
            assert.equals(60, ReadingStats.book_history("abc").seconds)
            assert.equals(60, ReadingStats.book_history("abc").seconds)
            assert.equals(1, opened)
            assert.is_nil(ReadingStats.book_history("zzz"))
            assert.is_nil(ReadingStats.book_history("zzz"))
            assert.equals(2, opened)
            assert.equals(90, ReadingStats.book_history("def").seconds)
            assert.equals(3, opened)
            date_back(db_path, 30)
            assert.equals(90, ReadingStats.book_history("def").seconds)
            assert.equals(4, opened)
            date_back(db_path, 0)
            ReadingStats.book_history("def")
            ReadingStats.book_history("def")
            assert.equals(6, opened)
        end)
    end)

    describe("insights", function()
        local function total(list)
            local sum = 0
            for _, s in ipairs(list) do
                sum = sum + s
            end
            return sum
        end

        it("reads a year of days, oldest first, today last", function()
            make_db({ on_day(0, 600), on_day(-1, 900), on_day(-370, 60), on_day(-371, 60) })
            local got = ReadingStats.insights(NOW)
            assert.equals("ok", got.state)
            assert.equals(ReadingStats.INSIGHT_DAYS, #got.days)
            assert.equals(600, got.days[#got.days])
            assert.equals(900, got.days[#got.days - 1])
            -- 370 days ago is the first day kept; 371 days ago is out.
            assert.equals(60, got.days[1])
            assert.equals(600 + 900 + 60, total(got.days))
        end)

        it("groups the days by local date", function()
            local t = os.date("*t", NOW)
            -- 01:30 and 04:50 the next day in UTC.
            make_db({
                { 1, at(t.year, t.month, t.day, 20, 30), 600 },
                { 1, at(t.year, t.month, t.day - 1, 23, 50), 300 },
            })
            local days = ReadingStats.insights(NOW).days
            assert.equals(600, days[#days])
            assert.equals(300, days[#days - 1])
        end)

        it("sums each hour of the day over the last 84 days", function()
            local t = os.date("*t", NOW)
            make_db({
                { 1, at(t.year, t.month, t.day, 7, 10), 600 },
                { 1, at(t.year, t.month, t.day - 1, 7, 50), 300 },
                { 1, at(t.year, t.month, t.day - 83, 22, 0), 120 },
                { 1, at(t.year, t.month, t.day - 84, 22, 0), 120 },
            })
            local hours = ReadingStats.insights(NOW).hours
            assert.equals(24, #hours)
            -- Hour h is index h + 1.
            assert.equals(600 + 300, hours[8])
            assert.equals(120, hours[23])
            assert.equals(600 + 300 + 120, total(hours))
        end)

        it("starts the 84 days on a calendar date across a change of the clocks", function()
            -- Chicago's clocks went forward on 8 March 2026, so 83 days back from 15 March is 83 days less an hour.
            local at_ = at(2026, 3, 15, 12)
            local t = os.date("*t", at_)
            make_db({
                { 1, at(t.year, t.month, t.day - 83, 0, 30), 300 },
                { 1, at(t.year, t.month, t.day - 84, 23, 30), 120 },
            })
            assert.equals(300, total(ReadingStats.insights(at_).hours))
        end)

        it("folds page rows into sessions split by a gap over 30 minutes, over the last 365 days", function()
            local t = os.date("*t", NOW)
            local base = at(t.year, t.month, t.day, 7, 0)
            make_db({
                { 1, base, 60 }, { 1, base + 60, 60 }, { 1, base + 120, 60 },
                -- Ends at base + 180; a gap of exactly 1800 s keeps the session: 240 s over 4 pages.
                { 1, base + 180 + 1800, 60 },
                -- Ends at base + 2040; a gap of 1801 s starts a session: 600 s over 1 page.
                { 1, base + 2040 + 1801, 600 },
                -- 364 days ago is the first day kept: 60 s over 1 page. 365 days ago is out.
                { 1, at(t.year, t.month, t.day - 364, 7, 0), 60 },
                { 1, at(t.year, t.month, t.day - 365, 7, 0), 60 },
            })
            local s = ReadingStats.insights(NOW).sessions
            assert.equals(3, s.count)
            assert.equals(600, s.longest)
            -- (240 + 600 + 60) / 3
            assert.equals(300, s.average)
            -- 6 pages over 900 s: 6 * 3600 / 900
            assert.equals(24, s.pages_per_hour)
        end)

        it("keeps a session's end at its latest row's end when rows overlap", function()
            local t = os.date("*t", NOW)
            local base = at(t.year, t.month, t.day, 7, 0)
            -- The second row ends inside the first, at base + 600; the third starts 1700 s after that.
            make_db({ { 1, base, 600 }, { 1, base + 60, 60 }, { 1, base + 2300, 60 } })
            local s = ReadingStats.insights(NOW).sessions
            assert.equals(1, s.count)
            assert.equals(720, s.longest)
        end)

        it("rounds the average and the pages an hour to the nearest whole number", function()
            local t = os.date("*t", NOW)
            local base = at(t.year, t.month, t.day, 7, 0)
            make_db({ { 1, base, 100 }, { 1, base + 4000, 101 } })
            local s = ReadingStats.insights(NOW).sessions
            assert.equals(2, s.count)
            -- 201 / 2 = 100.5
            assert.equals(101, s.average)
            -- 2 * 3600 / 201 = 35.8
            assert.equals(36, s.pages_per_hour)
        end)

        it("reads as off, and as empty with no database or nothing read in the year", function()
            local function assert_empty(got)
                assert.equals("empty", got.state)
                assert.equals(ReadingStats.INSIGHT_DAYS, #got.days)
                assert.equals(0, total(got.days))
                assert.equals(24, #got.hours)
                assert.equals(0, total(got.hours))
                assert.is_nil(got.sessions)
            end
            assert_empty(ReadingStats.insights(NOW))
            assert.is_nil(lfs.attributes(db_path, "mode"))
            assert.is_false(logged_error())

            make_db({ on_day(-371) })
            assert_empty(ReadingStats.insights(NOW))

            make_db({ on_day(0) })
            G_reader_settings:saveSetting("statistics", { is_enabled = false })
            assert.same({ state = "off" }, ReadingStats.insights(NOW))
            G_reader_settings:delSetting("statistics")
            G_reader_settings:saveSetting("plugins_disabled", { statistics = true })
            assert.same({ state = "off" }, ReadingStats.insights(NOW))
        end)

        it("reads a corrupt file as empty, not as the last history read, and logs it", function()
            make_db({ on_day(0) })
            assert.equals("ok", ReadingStats.insights(NOW).state)
            local f = assert(io.open(db_path, "wb"))
            f:write(string.rep("not a database ", 100))
            f:close()
            -- The file is unsettled, so NOW itself would return the memo.
            assert.equals("empty", ReadingStats.insights(NOW + 1).state)
            assert.is_true(logged_error())
        end)

        describe("read once", function()
            local real_open, opened

            -- Dates the database a minute back: a file written before the current second.
            local function settle(seconds_ago)
                local t = os.time() - (seconds_ago or 60)
                assert(lfs.touch(db_path, t, t))
            end

            before_each(function()
                real_open = SQ3.open
                opened = 0
                SQ3.open = function(path, mode)
                    if mode == "ro" then
                        opened = opened + 1
                    end
                    return real_open(path, mode)
                end
            end)

            after_each(function()
                SQ3.open = real_open
            end)

            it("reads the database once per stamp and date", function()
                make_db({ on_day(0), on_day(-1) }, "DELETE")
                settle()
                local first = ReadingStats.insights(NOW)
                assert.same(first, ReadingStats.insights(NOW))
                assert.equals(1, opened)

                settle(30)
                assert.same(first, ReadingStats.insights(NOW))
                assert.equals(2, opened)

                local t = os.date("*t", NOW)
                local tomorrow = ReadingStats.insights(at(t.year, t.month, t.day + 1, 0, 5))
                assert.equals(3, opened)
                assert.equals(0, tomorrow.days[#tomorrow.days])
                assert.equals(600, tomorrow.days[#tomorrow.days - 1])
            end)

            it("reads the database once per now while the files were written within the last second", function()
                make_db({ on_day(0), on_day(-1) })
                local first = ReadingStats.insights(NOW)
                assert.same(first, ReadingStats.insights(NOW))
                assert.equals(1, opened)

                ReadingStats.insights(NOW + 1)
                assert.equals(2, opened)
            end)

            it("reads a busy database as the last insights read, or empty with none, and logs it", function()
                make_db({ on_day(0), on_day(-1) }, "DELETE")
                local locker = real_open(db_path)
                locker:exec("BEGIN EXCLUSIVE;")
                local first = ReadingStats.insights(NOW)
                locker:exec("ROLLBACK;")
                assert.equals("empty", first.state)
                assert.is_true(logged_error())

                settle()
                local before = ReadingStats.insights(NOW)
                assert.equals("ok", before.state)
                settle(30)
                locker:exec("BEGIN EXCLUSIVE;")
                local busy = ReadingStats.insights(NOW)
                locker:exec("ROLLBACK;")
                locker:close()
                assert.equals(3, opened)
                assert.same(before, busy)
            end)
        end)
    end)
end)
