# Stats Additions Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task, under AGENTS.md's Subagents rules.

**Goal:** Grow the Stats window to three pages, with a week line, a When you read headline, a Device tile and a wall of the year's finished covers.

**Architecture:** Pure rules go in small functions the unit specs call directly: `Reading.week`, `Hours.headline`, `DeviceStats`, `FinishedBooks` and `Wall`. Tiles stay `InsightTile.compose` widgets registered in `widgets.lua`. `stats_screen.lua` keeps flowing rows by fit, and learns equal row heights and a wall that repeats its row once per page.

**Tech Stack:** Lua on KOReader's LuaJIT, Busted unit specs, emulator capture specs. No new dependency. No schema key.

**Design:** `docs/plans/2026-11-05-stats-additions-design.md`. Read it first; this plan doesn't repeat its reasons.

---

## Before starting

1. **Wait for sleep screen.** Both touch `main.lua`, `looks/base.lua` and `HOOKS.md`. Start only once `git status --short` is clean on `main`.
2. **Re-read every line number here** against the merged tree. They were read at `11eccdcf` with the sleep-screen work uncommitted.
3. **No Tiller.** This is ordinary work on `main`, TDD, nothing pushed without the owner's approval.
4. **One push.** Each push to `main` that changes the plugin cuts a release, so commit by task locally and push once, after the full `bin/check`.

**Running specs:** `bin/check spec/unit/<name>_spec.lua`. Its default output is already filtered, so pipe through `tail -15` to keep a transcript small.

**Agents:** Opus for code. Tasks 1–3 are small and independent, and can run in parallel or as one build pass. Task 6 reads a file the plugin didn't write, so it takes the full review (mutation checks on the five riskiest paths, then a re-check). Tasks 7–9 each take one review pass.

---

### Task 1: One name for each window

**Files:**
- Modify: `kopanda.koplugin/reading_stats.lua` (`HOUR_DAYS`, near line 86)
- Modify: `kopanda.koplugin/widgets/hours.lua` (the aside in `compose`, and the module comment)
- Modify: `kopanda.koplugin/widgets/records.lua` (the aside in `compose`)
- Test: `spec/unit/hours_widget_spec.lua`, `spec/unit/records_widget_spec.lua`, `spec/unit/reading_stats_spec.lua`

**Step 1: Update the specs first.** Change the expected asides to `"last 12 weeks"` and `"last 12 months"`. In `reading_stats_spec.lua`, move the hour window's edge test from 90 days to 84: a row 83 days back counts, one 84 days back doesn't.

**Step 2: Run them, expecting failure.**

Run: `bin/check spec/unit/hours_widget_spec.lua spec/unit/records_widget_spec.lua spec/unit/reading_stats_spec.lua | tail -15`
Expected: FAIL on the asides and the edge.

**Step 3: Implement.** `local HOUR_DAYS = 84`, then the two aside strings. `SESSION_DAYS` stays 365.

**Step 4: Run again.** Expected: PASS.

**Step 5: Commit.** `stats: name each window the same way throughout`

---

### Task 2: The week line

**Files:**
- Modify: `kopanda.koplugin/widgets/reading.lua`
- Modify: `kopanda.koplugin/looks/base.lua` (`insights.week_rule_gap`, and `type.insight_week`)
- Test: `spec/unit/reading_widget_spec.lua`

**Step 1: Write the failing tests** for `Reading.week(days, now)`. Build `days` as the seconds per day ending today, and fix `now` with `os.time{ year = 2026, month = 10, day = 14, hour = 12 }` (a Wednesday).

- Wednesday, this week's Monday and Tuesday at 960 s, last week at 540 s a day, today 0: `"16 min a day, up from 9 last week"`.
- The reverse: `"9 min a day, down from 16 last week"`.
- Equal in whole minutes though not in seconds (960 and 975 s): `"16 min a day, same as last week"`.
- Today at 1800 s lifts the average: `"20 min a day, up from 9 last week"`. Today at 60 s doesn't: `"16 min a day, up from 9 last week"`.
- A Monday with no reading today, last week at 540 s: `"9 min a day last week"`.
- A Monday with 720 s today: `"12 min a day, up from 9 last week"`.
- Nothing in either week: `"Nothing read this week or last"`.
- This week read, last week empty: `"16 min a day, nothing last week"`.
- An hour's average: `"1 h 5 min a day, up from 9 min last week"`.

**Step 2: Run, expecting failure.** `bin/check spec/unit/reading_widget_spec.lua | tail -15`. Expected: FAIL, `week` is nil.

**Step 3: Write the rule.**

```lua
-- The line comparing this week's daily average with last week's, for days (seconds per local day, today last) at
-- now. This week counts the days gone by, and today once it lifts their average.
function Reading.week(days, now)
    local today = days[#days]
    local monday = #days - row_of(now) + 1
    local past, past_days = 0, #days - monday
    for i = monday, #days - 1 do
        past = past + days[i]
    end
    local last = 0
    for i = monday - 7, monday - 1 do
        last = last + (days[i] or 0)
    end
    local seconds, counted = past, past_days
    if today > 0 and (past_days == 0 or today > past / past_days) then
        seconds, counted = past + today, past_days + 1
    end
    if seconds == 0 and last == 0 then
        return "Nothing read this week or last"
    end
    local was = last / 7
    if counted == 0 then
        return Helpers.duration(was) .. " a day last week"
    end
    local is = seconds / counted
    if last == 0 then
        return Helpers.duration(is) .. " a day, nothing last week"
    end
    local is_min, was_min = math.floor(is / 60 + 0.5), math.floor(was / 60 + 0.5)
    if is_min == was_min then
        return Helpers.duration(is) .. " a day, same as last week"
    end
    return Helpers.duration(is) .. " a day, " .. (is_min > was_min and "up" or "down") .. " from "
        .. Helpers.duration(was) .. " last week"
end
```

**Step 4: Run.** Expected: PASS.

**Step 5: Draw it.** Write the test first: `Reading.height` grows by the line and its rule, and the tile's `week` line is set to `Reading.week`'s text. In `compose`, add the line under `content_h` with a rule above it, using `Typeset.fitted` so a long line steps down instead of cutting. Free it in `free_lines`. Colour the rule `look.tile.outline_color`. Add the two tokens in `looks/base.lua` with the other `insights` tokens. `looks_spec.lua` checks token paths.

**Step 6: Run** `bin/check spec/unit/reading_widget_spec.lua spec/unit/looks_spec.lua | tail -15`. Expected: PASS.

**Step 7: Commit.** `stats: the week line in the Reading tile`

---

### Task 3: The When you read headline

**Files:**
- Modify: `kopanda.koplugin/widgets/hours.lua`
- Test: `spec/unit/hours_widget_spec.lua`

**Step 1: Write the failing tests** for `Hours.headline(hours)`, with `hours[i]` the seconds in hour `i - 1`.

- Most reading in hours 17–21: `{ part = "Evenings", share = 62, peak = 20 }`, with values chosen to give those numbers.
- The part edges, one test each side of each: hour 4 is Nights, 5 Mornings, 11 Mornings, 12 Afternoons, 16 Afternoons, 17 Evenings, 21 Evenings, 22 Nights.
- A tie between Mornings and Evenings gives Mornings.
- All zeros gives nil.
- `Hours.clock(20)` is `"20:00"` by default. With `twelve_hour_clock` on it is `"8 pm"`, and hours 0 and 12 read `"Midnight"` and `"Noon"`, as `Hours.captions` does.

**Step 2: Run, expecting failure.** `bin/check spec/unit/hours_widget_spec.lua | tail -15`

**Step 3: Write the rule.**

```lua
-- The parts of the day in tie-break order, each its hours as { from, to } inclusive.
local PARTS = {
    { name = "Mornings", { 5, 11 } },
    { name = "Afternoons", { 12, 16 } },
    { name = "Evenings", { 17, 21 } },
    { name = "Nights", { 22, 23 }, { 0, 4 } },
}

-- The busiest part of the day in hours (seconds per hour of day, hour 0 first): { part, share, peak }, share a whole
-- percent of all the reading and peak the busiest hour; nil with no reading.
function Hours.headline(hours)
    local total, peak = 0, 0
    for i, seconds in ipairs(hours) do
        total = total + seconds
        if seconds > hours[peak + 1] then
            peak = i - 1
        end
    end
    if total == 0 then
        return nil
    end
    local best, best_seconds
    for _, part in ipairs(PARTS) do
        local sum = 0
        for _, span in ipairs(part) do
            for hour = span[1], span[2] do
                sum = sum + hours[hour + 1]
            end
        end
        if not best or sum > best_seconds then
            best, best_seconds = part.name, sum
        end
    end
    return { part = best, share = math.floor(best_seconds * 100 / total + 0.5), peak = peak }
end

function Hours.clock(hour)
    if not G_reader_settings:isTrue("twelve_hour_clock") then
        return string.format("%02d:00", hour)
    end
    if hour == 0 or hour == 12 then
        return hour == 0 and "Midnight" or "Noon"
    end
    return hour % 12 .. (hour < 12 and " am" or " pm")
end
```

**Step 4: Run.** Expected: PASS.

**Step 5: Draw it.** Test first: with reading, the tile grows by one value line and one caption line and holds "Evenings" and "62% of your reading, peak 20:00". With no reading the height is today's. Set the value in `look.type.insight_value` through `Typeset.fitted`, and the caption in `look.type.insight_caption`, above the bars. Keep the existing `captions` paint offsets relative to the new chart top. Free both lines in the tile's `free`.

**Step 6: Run** the spec. Expected: PASS.

**Step 7: Commit.** `stats: a headline on When you read`

---

### Task 4: Tiles in a row share a height

**Files:**
- Modify: `kopanda.koplugin/insight_tile.lua` (`compose`, line 97)
- Modify: `kopanda.koplugin/stats_screen.lua` (`flow` and `add_row`)
- Test: `spec/unit/insight_tile_spec.lua`, `spec/unit/stats_screen_spec.lua`

**Step 1: Write the failing tests.**

- `InsightTile.compose` under `ctx.row_h` taller than its content comes out exactly `row_h` tall. Under a shorter `row_h`, or none, it keeps its own height.
- In `stats_screen_spec`, a two-tile row of different heights builds both tiles at the taller height. A one-tile row is unchanged.

**Step 2: Run, expecting failure.** `bin/check spec/unit/insight_tile_spec.lua spec/unit/stats_screen_spec.lua | tail -15`

**Step 3: Implement.**

- In `InsightTile.compose`, once `extra_h`, `label_h` and `gap` are known: `content_h = math.max(content_h, (ctx.row_h or 0) - extra_h - label_h - gap)`. Paint stays top-aligned.
- In `flow`, keep the height: `row.h = h`.
- In `add_row`, build under a copy of `ctx` with `row_h = row.h` when `#row > 1`.

`Typeset.measured` keeps by `ctx` identity, so the copy builds the tile a second time. That is expected, and Task 9's paint budget judges it. Don't add a cache before it fails.

**Step 4: Run.** Expected: PASS.

**Step 5: Commit.** `stats: tiles in a row share a height`

---

### Task 5: The Device tile, storage and memory

**Files:**
- Create: `kopanda.koplugin/device_stats.lua`
- Create: `kopanda.koplugin/widgets/device.lua`
- Modify: `kopanda.koplugin/widgets.lua` (`modules`)
- Modify: `kopanda.koplugin/main.lua` (`require("widgets/device")` near line 105, `require("device_stats")` with the top requires)
- Test: create `spec/unit/device_stats_spec.lua`, `spec/unit/device_widget_spec.lua`

**Step 1: Check the assumptions.** `util.diskUsage` calls `ffiUtil.df` (`base/ffi/util.lua:114`). Confirm in the emulator that it returns numbers on macOS, and that `/proc/self/status` is missing there.

**Step 2: Write the failing tests.**

- `DeviceStats.rss(text)` reads `"VmRSS:\t   98304 kB\n"` as `98304 * 1024`, and gives nil for text without the line, and for nil.
- `Device.cells(readings)` for `{ storage = 11800000000, memory = 96000000 }` is `{ { value = "11.8 GB", caption = "storage free" }, { value = "96.0 MB", caption = "KOReader memory" } }`.
- A nil reading drops its cell. No readings at all gives an empty list, and the tile then shows the aside `"Nothing to report"`.

**Step 3: Run, expecting failure.** `bin/check spec/unit/device_stats_spec.lua spec/unit/device_widget_spec.lua | tail -15`

**Step 4: Implement.**

```lua
-- The device's own numbers for the Device tile: free storage on the library's disk and the memory KOReader uses.
-- Every read is guarded and gives nil when the device can't say. Reads frontend/util.lua:925 and
-- /proc/self/status, which only Linux has.
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local logger = require("logger")
local util = require("util")

local DeviceStats = {}

function DeviceStats.rss(text)
    local kb = type(text) == "string" and text:match("VmRSS:%s+(%d+)%s+kB")
    return kb and tonumber(kb) * 1024 or nil
end

function DeviceStats.memory()
    local f = io.open("/proc/self/status", "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return DeviceStats.rss(text)
end

function DeviceStats.storage()
    local ok, usage = pcall(function()
        return util.diskUsage(filemanagerutil.getHomeFolder())
    end)
    if not ok then
        logger.err("KoPanda: could not read the storage:", usage)
        return nil
    end
    return usage.available
end

return DeviceStats
```

Build `widgets/device.lua` on `widgets/records.lua`: label `"Device"`, aside `"when you opened Stats"`, one row of `Device.cells` in equal columns, each value over its caption, sized with `Typeset.fitted`. Sizes through `util.getFriendlySize`. Register `device = "widgets/device"`.

**Step 5: Run.** Expected: PASS.

**Step 6: Commit.** `stats: a Device tile with storage and memory`

---

### Task 6: Battery with time left (full review)

**Files:**
- Modify: `kopanda.koplugin/device_stats.lua`
- Modify: `kopanda.koplugin/widgets/device.lua`
- Test: `spec/unit/device_stats_spec.lua`, `spec/unit/device_widget_spec.lua`
- Fixture: create `spec/fixtures/battery_stats.lua`, in the plugin's shape (`plugins/batterystat.koplugin/main.lua:138-147`), from a real file written by the emulator's plugin

**Step 1: Check the assumptions.** Read `frontend/luasettings.lua`: `LuaSettings:open` on a missing file must not create it, and on a malformed one must not raise. Read `frontend/ui/time.lua` for `time.to_s`. `discharging.time` is in `fts`, since `Usage:append` adds `boottime_or_realtime_coarse` stamps (`main.lua:51-55`). If any of this is wrong, stop and tell the lead.

**Step 2: Write the failing tests** for `DeviceStats.time_left(percent, totals)`, returning seconds.

- 74 percent, `discharging` 37 percent over 10 hours: `20 * 3600`.
- Exactly one hour on record: a number. One second less: nil.
- `percentage` 0, `time` 0, a missing `discharging`, a `discharging` that isn't a table, a non-number in either field, NaN, a negative: nil each.

And for `DeviceStats.left_text(seconds)`:

- `90000` (1 day 1 hour): `"about 1 day left"`. `259200`: `"about 3 days left"`.
- `7200`: `"about 2 hours left"`. `3600`: `"about 1 hour left"`. `1800`: `"under an hour left"`.

And in the widget spec:

- `Device.cells` with `{ battery = 74, left = 259200, storage = 1, memory = 1 }` opens with `{ value = "74%", caption = "about 3 days left" }`.
- With `left` nil the caption is `"battery"`.
- With `charging` the caption is `"battery"`, whatever `left` says.
- With `battery` nil the cell drops.

**Step 3: Run, expecting failure.**

**Step 4: Implement.**

```lua
local MIN_RECORD = 3600

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- The seconds left at percent, at the rate in totals (battery_stats.lua's table), as Usage:remainingTime works it
-- out (plugins/batterystat.koplugin/main.lua:69-73); nil on under MIN_RECORD of discharging or a malformed table.
function DeviceStats.time_left(percent, totals)
    local discharging = type(totals) == "table" and totals.discharging
    if type(discharging) ~= "table" or not finite(discharging.percentage) or not finite(discharging.time) then
        return nil
    end
    local seconds = time.to_s(discharging.time)
    if discharging.percentage <= 0 or seconds < MIN_RECORD then
        return nil
    end
    return percent * seconds / discharging.percentage
end

function DeviceStats.left_text(seconds)
    if seconds >= 86400 then
        local days = math.floor(seconds / 86400)
        return "about " .. days .. (days == 1 and " day" or " days") .. " left"
    end
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        return "about " .. hours .. (hours == 1 and " hour" or " hours") .. " left"
    end
    return "under an hour left"
end

-- KOReader's Battery statistics totals, read and never written, or nil when they can't be read.
function DeviceStats.battery_totals()
    local ok, settings = pcall(LuaSettings.open, LuaSettings, DataStorage:getSettingsDir() .. "/battery_stats.lua")
    if not ok then
        logger.err("KoPanda: could not read the battery statistics:", settings)
        return nil
    end
    return settings.data
end
```

In `widgets/device.lua`, add a `readings()` that takes `QuickSettings.battery()`, `Device:getPowerDevice():isCharging()` under `pcall`, and `DeviceStats.time_left`. Battery is the first cell.

**Step 5: Run.** Expected: PASS.

**Step 6: Add the HOOKS.md entry.** A section "Battery statistics, `settings/battery_stats.lua`", citing `plugins/batterystat.koplugin/main.lua:17`, `:44-47`, `:51-55`, `:69-73`, `:138-147`, `quick_settings.lua:47`, and noting KoPanda never writes it.

**Step 7: Run** `bin/check spec/unit/device_stats_spec.lua spec/unit/device_widget_spec.lua spec/unit/hooks_doc_spec.lua | tail -15`. Expected: PASS.

**Step 8: Full review, then commit.** `stats: battery time left on the Device tile`

---

### Task 7: The year's finished books

**Files:**
- Modify: `kopanda.koplugin/reading_stats.lua` (add `reading_days`)
- Create: `kopanda.koplugin/finished_books.lua`
- Modify: `kopanda.koplugin/main.lua`
- Modify: `kopanda.koplugin/HOOKS.md`
- Test: `spec/unit/reading_stats_spec.lua`, create `spec/unit/finished_books_spec.lua`

**Step 1: Write the failing tests.**

In `reading_stats_spec.lua`, on its fixture database: `ReadingStats.reading_days(now)` gives `{ [md5] = { "2026-01-03", "2026-02-01" } }`, sorted, one entry per day, from 1 January of last year on, a row before that left out. Off, no database and a failed read give `{}`. It is memoized on the stamp as `insights` is.

In `finished_books_spec.lua`, for the pure `FinishedBooks.finish_day(stamped, days)`:

- A stamp on a reading day: that day.
- A rating saved 2026-03-10 on a book last read 2026-01-20: `"2026-01-20"`.
- A later reading day after the stamp is ignored: `"2026-03-10"` with days `{ "2026-03-10", "2026-03-20" }`.
- No reading days: the stamp.
- No day on or before the stamp: the stamp.

For `FinishedBooks.list(now)`, with `readhistory`, `Books` and `ReadingStats` stubbed:

- A complete book finished this year is listed, a reading one isn't.
- `dim` entries are skipped.
- An entry opened before 1 January stops the walk (the history is newest first).
- A file seen twice lists once.
- A finish on 30 December with a rating on 2 January drops out as last year's.
- The order is oldest finish first, then title.
- A failing record is logged and skipped. The whole read never raises, and returns `{}` on failure.

**Step 2: Run, expecting failure.** `bin/check spec/unit/reading_stats_spec.lua spec/unit/finished_books_spec.lua | tail -15`

**Step 3: Implement `ReadingStats.reading_days`** on the pattern of `book_history`, with `memo.days` keyed on the stamp and the year:

```lua
local function days_query(conn, now)
    local t = os.date("*t", now)
    local stmt = conn:prepare("SELECT book.md5, strftime('%Y-%m-%d', start_time, 'unixepoch', 'localtime')"
        .. " FROM page_stat_data JOIN book ON book.id = id_book WHERE start_time >= ?"
        .. " GROUP BY 1, 2 ORDER BY 1, 2")
    local days = {}
    local row = stmt:bind(os.time{ year = t.year - 1, month = 1, day = 1, hour = 0 }):step()
    while row do
        local md5 = row[1]
        if md5 then
            days[md5] = days[md5] or {}
            table.insert(days[md5], row[2])
        end
        row = stmt:step()
    end
    stmt:close()
    return days
end
```

It starts a year back so a rating saved in January can still find a December finish.

**Step 4: Implement `finished_books.lua`.**

```lua
-- The current year's finished books: KOReader's history (frontend/readhistory.lua:25-35, newest first) walked to the
-- year's start, each book's status and summary date from its sidecar through Books, and the date corrected by the
-- Statistics reading days, since any save of a summary rewrites it (filemanagerutil.lua:111).
local Books = require("books")
local ReadingStats = require("reading_stats")
local logger = require("logger")

local FinishedBooks = {}

-- The last of days (sorted "YYYY-MM-DD") on or before stamped, or stamped with none.
function FinishedBooks.finish_day(stamped, days)
    local day
    for _, candidate in ipairs(days or {}) do
        if candidate > stamped then
            break
        end
        day = candidate
    end
    return day or stamped
end

local function collect(now)
    local year = os.date("%Y", now)
    local start = os.time{ year = tonumber(year), month = 1, day = 1, hour = 0 }
    local days = ReadingStats.reading_days(now)
    local list, seen = {}, {}
    for _, entry in ipairs(require("readhistory").hist) do
        if entry.time < start then
            break
        end
        if not entry.dim and not seen[entry.file] then
            seen[entry.file] = true
            local record, progress = Books.with_progress(entry.file)
            local stamped = record and progress and progress.status == "complete" and Books.details(record).modified
            if stamped then
                local day = FinishedBooks.finish_day(stamped, days[progress.md5])
                if day:sub(1, 4) == year then
                    list[#list + 1] = { record = record, day = day }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.day ~= b.day then
            return a.day < b.day
        end
        return (a.record.title or "") < (b.record.title or "")
    end)
    return list
end

-- The books finished in now's year, oldest first, each { record, day }. Never raises.
function FinishedBooks.list(now)
    local ok, list = pcall(collect, now)
    if not ok then
        logger.err("KoPanda: could not list the finished books:", list)
        return {}
    end
    return list
end

return FinishedBooks
```

`Books.details` reads the sidecar's `modified` (`books.lua:327-342`). Check its return for a file book before relying on it. "A failing record is skipped" may need a `pcall` per entry.

**Step 5: Add the HOOKS.md entry** for `ReadHistory.hist`, `summary.modified` and its writers.

**Step 6: Run.** Expected: PASS.

**Step 7: Commit.** `stats: list the year's finished books`

---

### Task 8: The wall tile

**Files:**
- Create: `kopanda.koplugin/widgets/wall.lua`
- Modify: `kopanda.koplugin/widgets.lua`, `kopanda.koplugin/main.lua`
- Modify: `kopanda.koplugin/looks/base.lua` (`insights.wall_columns = 7`, `wall_columns_extra_large = 5`, `wall_gap = 8`)
- Test: create `spec/unit/wall_widget_spec.lua`

**Step 1: Write the failing tests.**

- `Wall.months(books)` gives a label for the first book of each month and "" for the rest: `{ "JAN", "", "FEB" }`.
- `Wall.grid(inner_w, room_h, columns, gap, month_h)` gives `{ columns, rows, cover_w, cover_h }`, the cover 10:7, at a room one pixel under and exactly at N rows.
- `Wall.split(books, per_page)` at 0, 1, exactly `per_page` and `per_page + 1` books gives 1, 1, 1 and 2 pages. The first cover on a later page always takes its month's label.
- `Wall.page_count(width, ctx)` matches `Wall.split` for `ctx.room`.
- The tile with no books reads "Nothing finished yet this year" and has no covers.
- The tile's aside is `Helpers.books_text(n)` across all pages, and `ctx.wall_page` picks the page.
- Freeing the tile frees each cover widget.

**Step 2: Run, expecting failure.** `bin/check spec/unit/wall_widget_spec.lua | tail -15`

**Step 3: Implement the pure parts, then `compose`.**

- Label `"Finished"`.
- Each cover is `FeaturedCover.framed(record, w, h, ctx, ...)`. Read its signature at `featured_cover.lua:198-246` and take the library's frame as `LibraryTiles`' `book` does at `library_tiles.lua:121`, so a missing cover shows the same placeholder.
- Month labels in `look.type.insight_caption`.
- The widget is `Wall = { id = "wall" }` with `Typeset.measured(compose)`. `FinishedBooks.list(ctx.now)` is read once per build.

**Step 4: Run.** Expected: PASS.

**Step 5: Commit.** `stats: a wall of the year's finished covers`

---

### Task 9: Three pages

**Files:**
- Modify: `kopanda.koplugin/stats_screen.lua`
- Modify: `spec/unit/stats_screen_spec.lua`, `spec/emulator/stats_screen_capture_spec.lua`, `spec/emulator/scenarios/2-scenario-stats-screen.lua`
- Modify: `spec/emulator/paint_budget_spec.lua`

**Step 1: Update the specs.**

Unit:
- Reading, Streak with Finish by, and Device share page 1 at a Colorsoft room.
- Hours with Sessions starts page 2, named "Habits", with the month bars on the same page.
- The wall always starts a page named "This year".
- With a small room, Device stays with Habits.
- At Extra large, hours and records still stack.
- Two wall pages give two "This year" pages, with `wall_page` 1 and 2.

Emulator: "fits three pages on the Colorsoft" and on the Paperwhite. Add `KOPANDA_STATS_FINISHED` to the scenario, stubbing `FinishedBooks.list` with the fixture's three books repeated to 30, and a capture on the wall page at `turns = 2`.

**Step 2: Run, expecting failure.** `bin/check spec/unit/stats_screen_spec.lua spec/emulator/stats_screen_capture_spec.lua | tail -15`

**Step 3: Implement.**

```lua
local ROWS = {
    { name = "Now", "reading" },
    { name = "Now", "streak", "forecast" },
    { name = "Now", "device" },
    { name = "Habits", stack = true, "hours", "records" },
    { name = "Habits", "months" },
    { name = "This year", page = true, wall = true, "wall" },
}
```

- In `fill`, set `tile_ctx.room` to `LibraryTiles.room(h, ctx, header_h)`.
- Expand the row marked `wall` into `Wall.page_count(width, tile_ctx)` rows, each `page = true`, under a `ctx` copy with `wall_page = i`. Keep that copy on the row, so `row_height` and `add_row` pass the same table and `Typeset.measured` builds once.
- Override `Window:request_covers` (`library_chrome.lua:324`). On a wall page, ask `BookCovers.request` for that page's records, and on arrival set `self.kept = nil` and call `self:go(self:view(), self.page)` while this window is shown. `book_status_screen.lua:400` is the model.

**Step 4: Run** both specs. Expected: PASS.

**Step 5: Add the wall to the paint budget.** In `paint_budget_spec.lua`, capture the wall page with 30 covers. The budget is 250 ms (`paint_budget.lua:12`).

Run: `bin/check spec/emulator/paint_budget_spec.lua | tail -15`
Expected: PASS. If the wall misses it, stop and tell the lead. Don't raise the budget. Likely fixes are drawing the covers from one cached page bitmap, or building Task 4's tiles once.

**Step 6: Commit.** `stats: three pages, Now, Habits and This year`

---

### Task 10: Finish

**Files:**
- Modify: `AGENTS.md` (the reference plugins line: `Reading Log (AGPL-3.0: read, don't copy)`)
- Modify: `docs/plans/2026-11-05-stats-additions-design.md` (anything that changed in the build)

**Step 1: Look at it.** Run `KOPANDA_CAPTURE_DIR=<scratchpad dir> bin/check spec/emulator/stats_screen_capture_spec.lua`, then `open` each PNG for the owner. Check Editorial and Frosted too: Frosted's tiles draw a box in the plate's keyline, and the new tiles must match.

**Step 2: Check every text size.** Colorsoft and Paperwhite at Medium, Large and Extra large. Nothing cut off, no lone Device page, and the wall's rows fit.

**Step 3: Full gate.** Run `bin/check | tail -20`. Expected: PASS.

**Step 4: Ask the owner.** Show the summary and the commits, and ask "Ready to commit and push?" One push cuts one release.

**Step 5: The Kindle check, the owner's.**
- Battery statistics screen against the tile's time left, the one assumption the emulator can't settle.
- Memory and storage read sensibly.
- The wall's speed on the real panel, with real covers.
- The finish dates of a few known books.

**Step 6: Update memory** with the feature's status and anything left unchecked.
