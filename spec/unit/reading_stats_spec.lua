-- Reading stats from KOReader's Statistics database (C7): the three numbers read from fixture
-- databases under a fixed TZ, the off and empty states, the wording per look, the fit to the
-- column, stats.show, and the pre-built home reading its numbers again when it is shown.
-- The lj-sqlite3 binding ffi.cdef()s on load (spec/emulator/driver.lua:87-88), so a Busted process
-- loads it once: spec/unit/books_coverbrowser_spec.lua's expose block requires it and keeps it
-- loaded, and runs before this file in bin/check's sorted files; the require here gets that one.
describe("reading stats", function()
    local harness = require("plugin_harness")
    local ffi = require("ffi")
    require("ffi/posix_h")
    local SQ3 = require("lua-ljsqlite3/init")
    local DataStorage = require("datastorage")
    local Screen = require("device").screen
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local util = require("util")
    pcall(ffi.cdef, "void tzset(void);")

    local db_path = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    local ReadingStats, Stats, Settings, Looks, Fonts, Typeset, errored

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

    -- A Statistics database at db_path holding books { id, md5, pages, last_open } and page
    -- rows { id_book, page, start_time, duration, total_pages }, in WAL mode or journal when given.
    local function make_books_db(books, rows, journal)
        remove_db()
        local conn = SQ3.open(db_path)
        conn:exec("PRAGMA journal_mode=" .. (journal or "WAL") .. ";")
        for _, sql in ipairs(DDL) do
            conn:exec(sql)
        end
        local book_stmt = conn:prepare("INSERT INTO book (id, title, md5, pages, last_open) VALUES (?, ?, ?, ?, ?);")
        for _, book in ipairs(books) do
            book_stmt:reset():bind(book[1], "Book " .. book[1], book[2], book[3], book[4]):step()
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

    -- The text of widget when it is a line typeset.lua set tracked (a group of one-character
    -- TextWidgets with spans between), nil otherwise.
    local function tracked_text(widget)
        local chars = {}
        for _, child in ipairs(widget) do
            if child.text then
                if #util.splitToChars(child.text) ~= 1 then
                    return nil
                end
                chars[#chars + 1] = child.text
            elseif #child > 0 then
                return nil
            end
        end
        if #chars > 0 then
            return table.concat(chars)
        end
    end

    -- Every line of text drawn in widget, in drawing order.
    local function texts(widget, out)
        out = out or {}
        if type(widget) ~= "table" then
            return out
        end
        local tracked = tracked_text(widget)
        if widget.text or tracked then
            out[#out + 1] = widget.text or tracked
            return out
        end
        for _, child in ipairs(widget) do
            texts(child, out)
        end
        return out
    end

    -- The first TextWidget in widget.
    local function first_text_widget(widget)
        if widget.text then
            return widget
        end
        for _, child in ipairs(widget) do
            local found = first_text_widget(child)
            if found then
                return found
            end
        end
    end

    local function ctx_for(look_id, now)
        return {
            look = Looks.get(look_id),
            variant = "day",
            text_size = "medium",
            now = now or NOW,
            screen = Screen,
        }
    end

    -- The width text takes set uncut in the look's stats type.
    local function measure(look_id, text)
        local widget = Typeset.line(Looks.get(look_id).type.stats, text, math.huge, ctx_for(look_id))
        local w = widget:getSize().w
        widget:free()
        return w
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
        Stats = package.loaded["widgets/stats"]
        Settings = package.loaded["settings"]
        Looks = package.loaded["looks"]
        Fonts = package.loaded["fonts"]
        Typeset = package.loaded["typeset"]
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

    describe("read", function()
        it("runs at 20:42 on 13 October 2026 in Chicago", function()
            assert.equals("2026-10-13 20:42 CDT", os.date("%Y-%m-%d %H:%M %Z", NOW))
        end)

        it("floors today's summed durations over 60, leaving out yesterday", function()
            local t = os.date("*t", NOW)
            make_db({
                { 1, at(t.year, t.month, t.day, 0, 0), 600 },
                { 2, at(t.year, t.month, t.day, 9), 780 },
                { 1, at(t.year, t.month, t.day, 20), 59 },
                { 1, at(t.year, t.month, t.day - 1, 23, 59), 3000 },
            })
            local stats = ReadingStats.read(NOW)
            assert.equals("ok", stats.state)
            assert.equals(23, stats.minutes_today)
        end)

        it("counts a streak of consecutive local days ending today", function()
            make_db({ on_day(0), on_day(-1), on_day(-2), on_day(-3), on_day(-5) })
            assert.equals(4, ReadingStats.read(NOW).streak)
        end)

        it("keeps the streak the next morning before any reading", function()
            make_db({ on_day(0), on_day(-1), on_day(-2), on_day(-3), on_day(-5) })
            local t = os.date("*t", NOW)
            local stats = ReadingStats.read(at(t.year, t.month, t.day + 1, 7))
            assert.equals("ok", stats.state)
            assert.equals(4, stats.streak)
            assert.equals(0, stats.minutes_today)
        end)

        it("resets the streak after a gap two days ago", function()
            make_db({ on_day(0), on_day(-1), on_day(-3), on_day(-4) })
            assert.equals(2, ReadingStats.read(NOW).streak)
        end)

        it("counts a streak across local midnight by local days, not 24-hour spans", function()
            local t = os.date("*t", NOW)
            make_db({
                { 1, at(t.year, t.month, t.day, 0, 1), 600 },
                { 1, at(t.year, t.month, t.day - 1, 23, 58), 600 },
            })
            assert.equals(2, ReadingStats.read(NOW).streak)
        end)

        it("counts a streak by local days across the end of daylight saving time", function()
            -- Chicago falls back at 02:00 on Sunday 1 November 2026: that day has 25 hours.
            make_db({
                { 1, at(2026, 10, 31, 0, 30), 600 },
                { 1, at(2026, 11, 1, 0, 30), 600 },
                { 1, at(2026, 11, 2, 9), 600 },
            })
            assert.equals(3, ReadingStats.read(at(2026, 11, 2, 20, 42)).streak)
        end)

        it("counts a streak by local days across the start of daylight saving time", function()
            -- Chicago springs forward at 02:00 on Sunday 8 March 2026: that day has 23 hours.
            make_db({
                { 1, at(2026, 3, 7, 23, 30), 600 },
                { 1, at(2026, 3, 8, 23, 30), 600 },
                { 1, at(2026, 3, 9, 0, 30), 600 },
            })
            assert.equals(3, ReadingStats.read(at(2026, 3, 9, 20, 42)).streak)
        end)

        it("reads a streak of 450 days as 400, from today or from yesterday", function()
            local rows = {}
            for offset = -450, -1 do
                rows[#rows + 1] = on_day(offset)
            end
            make_db(rows)
            assert.equals(400, ReadingStats.read(NOW).streak)
            rows[#rows + 1] = on_day(0)
            make_db(rows)
            assert.equals(400, ReadingStats.read(NOW).streak)
        end)

        -- About a year of heavy reading: 100 page turns a day for 400 days. The streak is read
        -- twice per book close (pre-build and show), inside the home's share of the budget (C13).
        it("reads a year of page turns quickly", function()
            local t = os.date("*t", NOW)
            local rows = {}
            for offset = 0, 399 do
                for turn = 1, 100 do
                    rows[#rows + 1] = { 1 + turn % 7, at(t.year, t.month, t.day - offset, 8, 0) + turn * 30, 30 }
                end
            end
            make_db(rows)
            assert.equals(400, ReadingStats.read(NOW).streak)
            local best = math.huge
            for _ = 1, 3 do
                local started = os.clock()
                ReadingStats.read(NOW)
                best = math.min(best, os.clock() - started)
            end
            assert.truthy(best < 0.010, string.format("%.2f ms", best * 1000))
        end)

        it("reads reading only 401 days ago as no streak and empty", function()
            make_db({ on_day(-401, 3600) })
            local stats = ReadingStats.read(NOW)
            assert.equals(0, stats.streak)
            assert.equals("empty", stats.state)
        end)

        it("counts distinct books read since the first of the local month", function()
            make_db({
                { 5, at(2026, 10, 1, 0, 0), 600 },
                { 1, at(2026, 10, 5), 600 },
                { 2, at(2026, 10, 9), 600 },
                { 1, at(2026, 10, 11), 600 },
                { 3, at(2026, 10, 13), 600 },
                { 4, at(2026, 9, 30, 23, 59), 600 },
            })
            local stats = ReadingStats.read(NOW)
            assert.equals(4, stats.books_month)
            assert.equals("October", stats.month_name)
        end)

        it("reads a missing file as empty without creating it or logging an error", function()
            local stats = ReadingStats.read(NOW)
            assert.equals("empty", stats.state)
            assert.is_nil(lfs.attributes(db_path, "mode"))
            assert.is_false(logged_error())
        end)

        it("is off when statistics is in plugins_disabled", function()
            make_db({ on_day(0) })
            G_reader_settings:saveSetting("plugins_disabled", { statistics = true })
            assert.equals("off", ReadingStats.read(NOW).state)
        end)

        it("is off when the plugin's own settings say is_enabled false", function()
            make_db({ on_day(0) })
            G_reader_settings:saveSetting("statistics", { is_enabled = false, min_sec = 5 })
            assert.equals("off", ReadingStats.read(NOW).state)
            G_reader_settings:saveSetting("statistics", { is_enabled = true })
            assert.equals("ok", ReadingStats.read(NOW).state)
        end)

        it("leaves both settings unset when it reads them", function()
            make_db({ on_day(0) })
            ReadingStats.read(NOW)
            assert.is_nil(G_reader_settings:readSetting("plugins_disabled"))
            assert.is_nil(G_reader_settings:readSetting("statistics"))
        end)

        it("reads a corrupt file as empty, not as the last numbers read, and logs it", function()
            make_db({ on_day(0) })
            assert.equals("ok", ReadingStats.read(NOW).state)
            remove_db()
            local f = assert(io.open(db_path, "wb"))
            f:write(string.rep("not a database ", 100))
            f:close()
            local stats = ReadingStats.read(NOW)
            assert.equals("empty", stats.state)
            assert.is_true(logged_error())
        end)

        it("reads a busy database as the previous numbers, or empty with none, and logs it", function()
            make_db({ on_day(0), on_day(-1) }, "DELETE")
            local locker = SQ3.open(db_path)
            locker:exec("BEGIN EXCLUSIVE;")
            local first = ReadingStats.read(NOW)
            locker:exec("ROLLBACK;")
            assert.equals("empty", first.state)
            assert.is_true(logged_error())

            local before = ReadingStats.read(NOW)
            assert.equals(2, before.streak)
            locker:exec("BEGIN EXCLUSIVE;")
            local busy = ReadingStats.read(NOW)
            locker:exec("ROLLBACK;")
            locker:close()
            assert.equals("ok", busy.state)
            assert.equals(2, busy.streak)
            assert.equals(before.minutes_today, busy.minutes_today)
        end)

        it("opens the database read-only", function()
            make_db({ on_day(0) })
            local open = spy.on(SQ3, "open")
            ReadingStats.read(NOW)
            SQ3.open:revert()
            assert.spy(open).was.called_with(db_path, "ro")
        end)

        it("closes the database after a good read and after a failed one", function()
            -- The connection ReadingStats.read opens, and the read.
            local function read_capturing()
                local real_open = SQ3.open
                local conn
                SQ3.open = function(...)
                    conn = real_open(...)
                    return conn
                end
                local ok, stats = pcall(ReadingStats.read, NOW)
                SQ3.open = real_open
                assert(ok, stats)
                return conn, stats
            end
            make_db({ on_day(0) })
            local good, stats = read_capturing()
            assert.equals("ok", stats.state)
            -- The binding's own flag, set only once sqlite3_close succeeds (lua-ljsqlite3/init.lua:352-364).
            assert.is_true(good._closed)

            remove_db()
            local f = assert(io.open(db_path, "wb"))
            f:write(string.rep("not a database ", 100))
            f:close()
            local corrupt
            corrupt, stats = read_capturing()
            assert.equals("empty", stats.state)
            assert.is_true(corrupt._closed)
        end)
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
            assert.is_true(conn._closed)
        end)

        it("leaves both settings unset when it reads them", function()
            make_books_db({ { 1, "abc", 100, 100 } }, { { 1, 1, 1000, 20, 100 } })
            ReadingStats.seconds_per_page("abc")
            assert.is_nil(G_reader_settings:readSetting("plugins_disabled"))
            assert.is_nil(G_reader_settings:readSetting("statistics"))
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

        -- A page_stat_data row { id_book, page, start_time, duration, total_pages } written as
        -- Statistics writes, its connection closed after.
        local function insert(row)
            local conn = real_open(db_path)
            conn:exec(string.format("INSERT INTO page_stat_data VALUES (%d, %d, %d, %d, %d);", unpack(row)))
            conn:close()
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

        it("reads the numbers again only when the database or its WAL file changes, or the date", function()
            make_db({ on_day(0), on_day(-1) })
            -- A connection Statistics holds open, its last write still in the WAL file.
            local writer = real_open(db_path)
            local t = os.date("*t", NOW)
            writer:exec(string.format("INSERT INTO page_stat_data VALUES (1, 99, %d, 780, 300);",
                at(t.year, t.month, t.day, 9)))
            assert.equals("file", lfs.attributes(db_path .. "-wal", "mode"))
            settle()
            local first = ReadingStats.read(NOW)
            assert.equals(23, first.minutes_today)
            assert.same(first, ReadingStats.read(NOW))
            assert.equals(1, opened)

            date_back(db_path .. "-wal", 30)
            assert.same(first, ReadingStats.read(NOW))
            assert.equals(2, opened)
            date_back(db_path, 30)
            ReadingStats.read(NOW)
            assert.equals(3, opened)

            local after_midnight = at(t.year, t.month, t.day + 1, 0, 5)
            local next_day = ReadingStats.read(after_midnight)
            assert.equals(4, opened)
            assert.equals(0, next_day.minutes_today)
            assert.equals(2, next_day.streak)
            assert.same(next_day, ReadingStats.read(after_midnight))
            assert.equals(4, opened)
            writer:close()
        end)

        it("reads again a database dated this second or later", function()
            make_db({ on_day(0) })
            date_back(db_path, -5)
            ReadingStats.read(NOW)
            ReadingStats.read(NOW)
            assert.equals(2, opened)
        end)

        -- FAT dates files in two-second steps, rounded down, so in an odd second T a write dated
        -- T-1 can follow another dated T-1 that left the size as it was.
        it("reads again a database dated within the last two seconds", function()
            local now = real_time()
            now = now - now % 2 + 1
            freeze(now)
            make_db({ on_day(0) })
            for _, dated in ipairs{ now - 1, now } do
                assert(lfs.touch(db_path, dated, dated))
                opened = 0
                ReadingStats.read(NOW)
                ReadingStats.read(NOW)
                assert.equals(2, opened)
            end
        end)

        it("keeps the read of a database dated two seconds back", function()
            local now = real_time()
            now = now - now % 2 + 1
            freeze(now)
            make_db({ on_day(0) })
            assert(lfs.touch(db_path, now - 2, now - 2))
            ReadingStats.read(NOW)
            ReadingStats.read(NOW)
            assert.equals(1, opened)
        end)

        it("reads a busy database as the last numbers read, untouched or touched", function()
            make_db({ on_day(0), on_day(-1) }, "DELETE")
            settle()
            local before = ReadingStats.read(NOW)
            assert.equals("ok", before.state)
            local locker = real_open(db_path)
            locker:exec("BEGIN EXCLUSIVE;")
            local untouched = ReadingStats.read(NOW)
            local opened_untouched = opened
            date_back(db_path, 30)
            local touched = ReadingStats.read(NOW)
            locker:exec("ROLLBACK;")
            locker:close()
            assert.equals(1, opened_untouched)
            assert.same(before, untouched)
            assert.equals(2, opened)
            assert.same(before, touched)
            assert.is_true(logged_error())
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

        it("opens the database once when the numbers and the rate both miss", function()
            local start = on_day(0)[2]
            make_books_db({ { 1, "abc", 100, 100 } }, { { 1, 1, start, 600, 100 } })
            settle()
            assert.equals(10, ReadingStats.read(NOW).minutes_today)
            assert.equals(120, (ReadingStats.seconds_per_page("abc")))
            assert.equals(2, opened)

            insert({ 1, 2, start + 60, 60, 100 })
            date_back(db_path, 30)
            assert.equals(11, ReadingStats.read(NOW).minutes_today)
            assert.equals(3, opened)
            assert.equals((120 + 60) / 2, (ReadingStats.seconds_per_page("abc")))
            assert.equals(3, opened)

            insert({ 1, 3, start + 120, 120, 100 })
            date_back(db_path, 20)
            assert.equals((120 + 60 + 120) / 3, (ReadingStats.seconds_per_page("abc")))
            assert.equals(4, opened)
            assert.equals(13, ReadingStats.read(NOW).minutes_today)
            assert.equals(4, opened)
        end)

        it("keeps today's numbers as a busy database's when a book's rate reads them again", function()
            local t = os.date("*t", NOW)
            local yesterday = at(t.year, t.month, t.day - 1, 20, 42)
            local start = on_day(0)[2]
            make_books_db({ { 1, "abc", 100, 100 } }, { { 1, 1, on_day(-1)[2], 600, 100 } }, "DELETE")
            settle()
            assert.equals(10, ReadingStats.read(yesterday).minutes_today)
            -- Today's read lands while Statistics' last write is dated too recently to keep.
            insert({ 1, 2, start, 1200, 100 })
            date_back(db_path, -5)
            assert.equals(20, ReadingStats.read(NOW).minutes_today)

            insert({ 1, 3, start + 60, 60, 100 })
            date_back(db_path, 30)
            assert.equals((120 + 120 + 60) / 3, (ReadingStats.seconds_per_page("abc")))

            local locker = real_open(db_path)
            locker:exec("BEGIN EXCLUSIVE;")
            date_back(db_path, 20)
            local busy = ReadingStats.read(NOW)
            locker:exec("ROLLBACK;")
            locker:close()
            assert.equals(21, busy.minutes_today)
            assert.equals(2, busy.streak)
        end)
    end)

    describe("the widget", function()
        local WIDE = 4000

        it("words the numbers per look, in the look's case", function()
            make_db({
                on_day(0, 1380), on_day(-1), on_day(-2), on_day(-3),
                on_day(-1, 600, 2), on_day(-2, 600, 3),
            })
            assert.same({ "STREAK 4 DAYS", "23 MIN TODAY", "3 BOOKS IN OCTOBER" },
                texts(Stats.build(WIDE, ctx_for("editorial"))))
            assert.same({ "4-DAY STREAK · 23 MIN TODAY · 3 BOOKS IN OCTOBER" },
                texts(Stats.build(WIDE, ctx_for("diner"))))
        end)

        it("uses the singular for one day and one book", function()
            make_db({ on_day(0, 1380) })
            assert.same({ "STREAK 1 DAY", "23 MIN TODAY", "1 BOOK IN OCTOBER" },
                texts(Stats.build(WIDE, ctx_for("editorial"))))
            assert.same({ "1-DAY STREAK · 23 MIN TODAY · 1 BOOK IN OCTOBER" },
                texts(Stats.build(WIDE, ctx_for("diner"))))
        end)

        it("words nothing read, and no database, as the empty state", function()
            assert.same({ "NO STREAK YET", "0 MIN TODAY", "READ SOMETHING AND THIS FILLS IN" },
                texts(Stats.build(WIDE, ctx_for("editorial"))))
            assert.same({ "NO STREAK YET · 0 MIN TODAY · READ SOMETHING AND THIS FILLS IN" },
                texts(Stats.build(WIDE, ctx_for("diner"))))
        end)

        it("says the stats are off in one part", function()
            G_reader_settings:saveSetting("plugins_disabled", { statistics = true })
            assert.same({ "READING STATS ARE OFF" }, texts(Stats.build(WIDE, ctx_for("editorial"))))
            assert.same({ "READING STATS ARE OFF" }, texts(Stats.build(WIDE, ctx_for("diner"))))
        end)

        it("draws in the look's stats face, size and colour", function()
            make_db({ on_day(0) })
            for _, id in ipairs({ "editorial", "diner" }) do
                local look = Looks.get(id)
                local token = look.type.stats
                local text = first_text_widget(Stats.build(WIDE, ctx_for(id)))
                assert.equals(Fonts.path(look.faces[token.face].file), text.face.realname, id)
                assert.equals(token.size, text.face.orig_size, id)
                assert.equals(Looks.color(look.palettes.day[token.color]), text.fgcolor, id)
            end
        end)

        it("is exactly the column wide, whatever it draws", function()
            make_db({ on_day(0, 1380) })
            for _, id in ipairs({ "editorial", "diner" }) do
                for _, width in ipairs({ 80, 300, WIDE }) do
                    assert.equals(width, Stats.build(width, ctx_for(id)):getSize().w, id .. " at " .. width)
                end
            end
        end)

        it("drops Diner's parts from the end to fit the column", function()
            make_db({ on_day(0, 1380), on_day(-1), on_day(-2), on_day(-3) })
            local full = measure("diner", "4-DAY STREAK · 23 MIN TODAY · 1 BOOK IN OCTOBER")
            local two = measure("diner", "4-DAY STREAK · 23 MIN TODAY")
            assert.same({ "4-DAY STREAK · 23 MIN TODAY · 1 BOOK IN OCTOBER" },
                texts(Stats.build(full, ctx_for("diner"))))
            assert.same({ "4-DAY STREAK · 23 MIN TODAY" }, texts(Stats.build(full - 1, ctx_for("diner"))))
            assert.same({ "4-DAY STREAK" }, texts(Stats.build(two - 1, ctx_for("diner"))))
        end)

        it("drops Editorial's parts from the end to fit the column", function()
            make_db({ on_day(0, 1380), on_day(-1), on_day(-2), on_day(-3) })
            local w1 = measure("editorial", "STREAK 4 DAYS")
            local w2 = measure("editorial", "23 MIN TODAY")
            local w3 = measure("editorial", "1 BOOK IN OCTOBER")
            assert.same({ "STREAK 4 DAYS", "23 MIN TODAY" },
                texts(Stats.build(w1 + w2 + w3, ctx_for("editorial"))))
            assert.same({ "STREAK 4 DAYS" }, texts(Stats.build(w1 + 1, ctx_for("editorial"))))
        end)

        it("keeps the first part, ending in an ellipsis, when it alone is too wide", function()
            make_db({ on_day(0, 1380), on_day(-1), on_day(-2), on_day(-3) })
            for _, id in ipairs({ "editorial", "diner" }) do
                local built = Stats.build(40, ctx_for(id))
                local text = first_text_widget(built)
                assert.equals(1, #texts(built), id)
                assert.truthy(text:getSize().w <= 40, id)
                assert.is_true(text:isTruncated(), id)
            end
        end)

        it("has its line's height when shown, and height 0 and nothing drawn when stats.show is false", function()
            make_db({ on_day(0) })
            local ctx = ctx_for("diner")
            local h = Stats.height(300, ctx)
            assert.truthy(h > 0)
            assert.equals(h, Stats.build(300, ctx):getSize().h)
            assert.is_true(Settings.set("stats.show", false))
            assert.equals(0, Stats.height(300, ctx))
            local built = Stats.build(300, ctx)
            assert.equals(300, built:getSize().w)
            assert.equals(0, built:getSize().h)
            assert.same({}, texts(built))
        end)
    end)

    describe("the pre-built home", function()
        it("reads the numbers again when it is shown, after the book's session is flushed", function()
            local Home = package.loaded["home"]
            assert.is_true(Settings.set("layout.rows", { { { widget = "stats", share = 1 } } }))
            local now = os.time()
            make_db({ { 1, now, 600 } })
            Home.prebuild()
            local slot
            for _, s in ipairs(Home.pending.slots) do
                if s.widget == "stats" then
                    slot = s
                end
            end
            assert.same({ "1-DAY STREAK · 10 MIN TODAY · 1 BOOK IN " .. os.date("%B", now):upper() },
                texts(slot.built))
            -- What Statistics writes on the same CloseDocument, after KoPanda's pre-build.
            local conn = SQ3.open(db_path)
            conn:exec(string.format("INSERT INTO page_stat_data VALUES (1, 99, %d, 780, 300);", now))
            conn:close()
            local home = Home.take_pending()
            assert.same({ "1-DAY STREAK · 23 MIN TODAY · 1 BOOK IN " .. os.date("%B", now):upper() },
                texts(slot.built))
            assert.equals(home.slots[1].built, slot.built)
            home:free()
        end)

        it("is still handed over, its stats as built, when reading them again raises", function()
            local Home = package.loaded["home"]
            assert.is_true(Settings.set("layout.rows", { { { widget = "stats", share = 1 } } }))
            local now = os.time()
            make_db({ { 1, now, 600 } })
            Home.prebuild()
            local pending = Home.pending
            local slot = pending.slots[1]
            assert.equals("stats", slot.widget)
            local built, line = slot.built, slot.built[1]
            local before = texts(built)
            local conn = SQ3.open(db_path)
            conn:exec(string.format("INSERT INTO page_stat_data VALUES (1, 99, %d, 780, 300);", now))
            conn:close()
            local refresh = Stats.refresh
            Stats.refresh = function()
                error("refresh failed on purpose")
            end
            local ok, home = pcall(Home.take_pending)
            Stats.refresh = refresh
            assert.is_true(ok, tostring(home))
            assert.equals(pending, home)
            assert.is_nil(Home.pending)
            assert.equals(built, home.slots[1].built)
            assert.equals(line, built[1])
            assert.same(before, texts(built))
            assert.is_true(logged_error())
            home:free()
        end)
    end)
end)
