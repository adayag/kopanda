-- Reading stats from KOReader's Statistics database (C7): the three numbers read from fixture
-- databases under a fixed TZ, the off and empty states, the wording per look, the fit to the
-- column, stats.show, and the pre-built home reading its numbers again when it is shown.
-- Every lj-sqlite3 use stays in this file, and the binding is required once here: it
-- ffi.cdef()s on load (spec/emulator/driver.lua:87-88).
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
        "PRAGMA user_version = 20221111;",
    }

    -- Local time in the spec's TZ.
    local function at(year, month, day, hour, min)
        return os.time{ year = year, month = month, day = day, hour = hour or 12, min = min or 0 }
    end

    -- Tuesday 13 October 2026, 20:42 in Chicago.
    local NOW = at(2026, 10, 13, 20, 42)

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
        for i, row in ipairs(rows) do
            stmt:reset():bind(row[1], i, row[2], row[3], 300):step()
        end
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

        it("reads reading only 401 days ago as no streak and empty", function()
            make_db({ on_day(-401, 3600) })
            local stats = ReadingStats.read(NOW)
            assert.equals(0, stats.streak)
            assert.equals("empty", stats.state)
        end)

        it("counts distinct books read since the first of the local month", function()
            make_db({
                { 1, at(2026, 10, 1, 0, 0), 600 },
                { 2, at(2026, 10, 5), 600 },
                { 1, at(2026, 10, 9), 600 },
                { 3, at(2026, 10, 13), 600 },
                { 4, at(2026, 9, 30, 23, 59), 600 },
            })
            local stats = ReadingStats.read(NOW)
            assert.equals(3, stats.books_month)
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
    end)
end)
