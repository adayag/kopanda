# Insights page: implementation plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A second home page, reached by a west swipe and left by an east swipe, laid out from a new `layout.rows_2` key, with five new widgets drawn from KOReader's Statistics database: this month's reading beside a 12-week chart, the reading streak, the finish-by forecast for the featured book, a when-you-read hour chart and the year's session records.

**Architecture:** The home keeps one page built at a time: `Home.page` picks the key `HomeRows.build` lays out, and a page swipe rebuilds and repaints. `layout.rows_2` is a second key of the existing `rows` type, so the device editor, the studio form and `bin/layout-fit` keep working once each takes the key as a parameter. The five widgets share one tile chrome (`insight_tile.lua`) and one read of the database (`ReadingStats.insights`), memoised like the existing stats. New look tokens live in `looks/base.lua` with Diner's overrides; every other look takes the base's.

**Tech Stack:** Lua on KOReader's LuaJIT, Busted unit specs under `spec/unit/` run by `bin/check <spec>`, emulator captures under `spec/emulator/`; the studio in TypeScript (React, Vitest) under `studio/`.

Mock: https://claude.ai/artifact/5FFKoy34eaGHcNM8NJqL5D (artboard "Page 2 · Insights"). The owner approved all five tiles and option 1 (a second key) on 2026-10-22.

Read first: `kopanda.koplugin/home.lua` (whole), `home_rows.lua:100-193` (`build`), `home_gestures.lua:36-45` and `:140-167` (`is_page_swipe`, `route`), `layout.lua:160-290` (`arrange`), `widgets/quote.lua:120-200` (tile chrome, the pattern to share), `widgets/stats.lua` (a widget that reads `reading_stats`), `reading_stats.lua` (whole), `looks/base.lua:276-400` (`home`, `type`), `looks/diner.lua`, `rows_edit.lua:1-45`, `edit_layout.lua:120-145` and `:440-463`, `spec/unit/reading_stats_spec.lua:1-150` (the fixture database), `spec/unit/home_layout_spec.lua:1-150` (stub widgets, `show_home`), `spec/unit/quote_spec.lua:1-70` (`ctx_for`, `on_screen`), `spec/emulator/scenarios/2-scenario-night-toggle.lua` (a scenario patch), `spec/emulator/home_capture_spec.lua:1-80`.

Verified facts (this repo, 2026-10-22):

- Widgets are `{ id, settings_prefix, height(width, ctx), build(width, ctx), baseline?, tap?, hold?, after_show?, stale? }` found by `widgets.lua`'s `modules` table; `main.lua:88-95` requires each. `spec/unit/main_requires_spec.lua` requires every file under the plugin.
- `ctx` is `{ look, variant, text_size, now, screen, home, plate }` (`home_rows.lua:108-119`). Lengths in look tokens are board pixels, scaled by `Paint.scaler(ctx)`; font sizes by `Layout.font_size` inside `Typeset`. The unit harness screen is 600 px wide at scale 1 (`spec/plugin_harness.lua:144-149`); `harness.at_colorsoft(fn)` and `at_paperwhite(fn)` run `fn` at device scale.
- `Typeset.line(part, text, max_width, ctx)` sets one line in a `look.type` part; `Typeset.line_height(part, ctx)`; `Typeset.measured(make)` gives a widget's `height, build, baseline` from one `make(width, ctx)` returning `widget, baseline`.
- A tile's chrome: `look.tile.box` (false in Editorial, which rules instead), `look.tile.fill_color`, `look.tile.outline_color`, `look.stroke.outline`, `look.shadow.tile` (`quote.lua:150-176`); `Paint.backing`, `Paint.outline`, `Paint.fill`, `Paint.Fill`.
- Colour roles every look defines: `paper`, `ink`, `muted`, `text`, `shadow`, `cover`, `on_cover`. Diner adds `teal`, `pink`, `mustard`, `on_accent`; Editorial adds `hairline`, `hairline_light`. `looks_spec.lua:128-145` requires every look to hold every base token path and a look file to set only base paths; `:253` requires every `type` entry to name a face with a file, a size, case, tracking, line height and a colour role (so a base `type` part cannot name `accent`, whose base file is false; Diner's may).
- `Settings.validators.rows` (`settings.lua:148-168`) holds a widget to once per key's value, each widget in `entry.widgets`, 1 to `entry.max_columns` slots a row. `schema_spec.lua:37-150` lists every key verbatim and asserts "the ten keys".
- The statistics database (`plugins/statistics.koplugin/main.lua:27`, DDL `:405-419`): `page_stat_data(id_book, page, start_time, duration, total_pages)`. `reading_stats.lua` opens it read-only through `with_db`, memoises by the files' `stamp`, treats a busy database as the last read, and `lua-ljsqlite3` is required once per Busted process (loaded by `books_coverbrowser_spec.lua`, which sorts before every spec named below).
- SQLite's `strftime(fmt, start_time, 'unixepoch', 'localtime')` groups by local calendar day or hour with the C library's zone, the same zone `os.date` uses (SQLite's date functions documentation; not a KOReader internal, so no HOOKS.md line, but the `page_stat_data` columns used are already cited at `HOOKS.md:934-980`).
- The capture patch shoots the first `KoPandaSettled` signal whose `screen` is `KOPANDA_SHOT_SCREEN` (`spec/emulator/patches/2-kopanda-capture.lua:19-21`, `:61-72`), whoever sends it; a scenario patch reports `screen = "scenario"`. `driver.capture{ patches = {...}, shot_screen = "scenario", env = {...} }`; patches apply in natural-sort order, so `2-scenario-home-fixture.lua` runs before `2-scenario-home-page.lua`.
- The fixture statistics (`2-scenario-home-fixture.lua:296-335`): 23 min today over two books, reads on the 10th to 12th, the 8th, one row on 28 September, and the featured book's ten 90 s pages on 2025-01-01 (2 h 6 min left at 62 %).
- `HomeGestures.forward` consumes a mid-screen west or east swipe (`home_gestures.lua:124-126`), tested by `spec/unit/gesture_routing_spec.lua:174-186`; the home's `route` runs `forward` before the hold and tap steps.
- The studio: `studio/src/core/rows-edit.ts:18-21` binds the editor to `layout.rows` at module load; `LayoutEditor.tsx:93` reads `settings.values[entry.id]`; `App.tsx:26-31` routes `#/profiles/<id>/layout`; `RowsControl.tsx` links to `${profileHref}/layout`; `api.ts:checkFit` posts `{ rows }` to `/:id/layout-fit`, whose route (`server/routes/layout-fit.ts:22-36`) compares against `values["layout.rows"]`; `bin/layout-fit` validates against the `layout.rows` entry's widgets (`bin/layout-fit.lua:36`, `:56`), so the two keys must list the same widgets.
- `studio/src/schema.json` is regenerated by `npm run schema` in `studio/` and checked by `spec/unit/studio_schema_spec.lua`; the round-trip fixture by `KOPANDA_UPDATE_GOLDENS=1 npm --prefix studio test -- test/core/settings-written.test.ts`, then `bin/check spec/unit/studio_settings_file_spec.lua`.

Running specs: `bin/check spec/unit/<name>_spec.lua` (several paths allowed). Read the output through a filter that keeps the summary and failures only, for example `bin/check spec/unit/x_spec.lua 2>&1 | grep -E "FAILED|PASSED|tests from|Error|error|expected|assert" | head -60`. `bin/check --lint` is luacheck alone; `bin/check --unit` the full unit gate (needs `studio/node_modules`); emulator specs by name.

Rules: TDD, every test written and seen failing before its code. Comments say what the code can't; a module opens with one to three sentences. No `git add -A`. Don't commit: the lead presents each task's diff. Minimal change; mention anything outside scope instead of fixing it.

---

## Design in one place

**The page.** `Home.page` is 1 or 2. `HomeRows.keys = { "layout.rows", "layout.rows_2" }`; `HomeRows.build(home)` lays out `Settings.get(HomeRows.keys[home.page])`. A west swipe mid-screen turns to page 2, an east swipe back; a swipe past either end is consumed and does nothing. A refresh, a night-mode repaint and a Resume keep the page; a new `Home.show` starts on page 1. Every page gets the look's header band on its row 1 and the nav bar beneath, as today. No page indicator.

**The key.** `layout.rows_2`, type `rows`, label "Page 2", group `home`, `max_columns` 3, the same `widgets` list as `layout.rows` (the seven plus the five new ids), default:

```lua
{ { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
{ { widget = "reading", share = 1 } },
{ { widget = "streak", share = 1 }, { widget = "forecast", share = 1 } },
{ { widget = "hours", share = 1 }, { widget = "records", share = 1 } },
```

A widget may sit on both pages; uniqueness stays per key. (The weather and stats row was dropped from the default on 2026-10-22: at device scale the four rows fill the page in every look at the large text size, with Toybox's own `insights` overrides.)

**The data.** `ReadingStats.insights(now)` returns `{ state, days, hours, sessions }`: `state` as `read` gives it; `days` a list of `ReadingStats.INSIGHT_DAYS` (371, 53 weeks) seconds per local day, oldest first, the last being today; `hours` 24 seconds per hour of day over the last 90 days; `sessions` `{ count, longest, average, pages_per_hour }` over the last 365 days or nil with none. A session is a run of page rows each starting within `SESSION_GAP` (1800 s) of the previous row's end. Memoised like `read`, one database open per build.

**The tiles.** `insight_tile.lua` draws the chrome the quote draws (box with outline and tile shadow, or rules in a look without a box) around a label line (`type.insight_label`, with an optional right-aligned aside in `type.insight_caption`) and a content widget. Each of the five widgets composes its content inside it.

**Tokens** (board pixels; colours are palette roles), added to `looks/base.lua`:

```lua
type.insight_label   = { face = "strong", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "ink" }
type.insight_caption = { face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0, color = "muted" }
type.insight_value   = { face = "display", size = 30, uppercase = false, tracking = -0.02, line_height = -0.1, color = "ink" }
type.insight_note    = { face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "muted" }
insights = {
    padding = 14,            -- inside the chrome
    label_gap = 10,          -- under the label line
    gap = 1,                 -- between hour bars
    today_outline_width = 2,
    chart_height = 70,
    chart_area_color = "muted", chart_line_color = "ink", chart_line_width = 3,
    today_ring = 10, today_ring_color = "ink",
    reading_column = 0.36,   -- the reading tile's figures' share of its width
    streak_scale = 2,        -- the streak's count at this many times insight_value's size
    dot = 14, dot_gap = 8, dot_fill_color = "ink", dot_empty_color = "muted",
    bar_fill_color = "muted",
    bar_high_color = "ink",  -- an hour at or above 60 % of the busiest
    bar_outline_width = 0,
    value_gap = 2,           -- between a record's value and its caption
    record_gap = 10,         -- between the two record rows
}
```

Diner overrides: `type.insight_label.face = "display"`, `type.insight_note.face = "accent"` (size 18), `chart_area_color = "teal"`, `dot_fill_color = "ink"`, `today_ring_color = "mustard"`, `bar_fill_color = "teal"`, `bar_outline_width = 1`.

**Thresholds** are fixed: 60 % of the busiest hour for a high bar, 14 days for the forecast's pace (at least 5 min a day), 30 minutes for a session gap. No setting.

---

### Task 1: the `layout.rows_2` key

**Files:**
- Modify: `kopanda.koplugin/schema.lua:46-66`
- Modify: `spec/unit/schema_spec.lua:37` (the verbatim key list; its count)
- Modify: `studio/src/schema.json` (regenerated), `studio/test/core/settings-written.test.ts:14-30`, `spec/fixtures/studio/settings_written.lua` (regenerated)
- Test: `spec/unit/schema_spec.lua`, `spec/unit/settings_spec.lua`, `spec/unit/studio_schema_spec.lua`, `spec/unit/studio_settings_file_spec.lua`

**Step 1: Write the failing test.** In `schema_spec.lua`'s verbatim list, after the `layout.rows` entry, add the new entry exactly as the design gives it, and add the five ids to both entries' `widgets` lists:

```lua
widgets = { "date", "clock", "weather", "quote", "stats", "featured", "launcher",
    "reading", "streak", "forecast", "hours", "records" },
```

Rename the test "is version 1 with the eleven keys of the Keys tables, in order". In `settings_spec.lua` add one case: `Settings.get("layout.rows_2")` returns the schema default with no file, and a value naming `date` on both keys reads back from both.

**Step 2: Run** `bin/check spec/unit/schema_spec.lua spec/unit/settings_spec.lua`. Expected: FAIL, the key list differs.

**Step 3: Edit `schema.lua`**: extend `layout.rows`'s `widgets`, then add after it:

```lua
{
    -- The second page's rows, reached by a west swipe; the same shape as layout.rows.
    id = "layout.rows_2",
    type = "rows",
    widgets = { "date", "clock", "weather", "quote", "stats", "featured", "launcher",
        "reading", "streak", "forecast", "hours", "records" },
    max_columns = 3,
    default = {
        { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
        { { widget = "reading", share = 1 } },
        { { widget = "streak", share = 1 }, { widget = "forecast", share = 1 } },
        { { widget = "hours", share = 1 }, { widget = "records", share = 1 } },
    },
    label = "Page 2",
    group = "home",
},
```

**Step 4: Run** the two specs. Expected: PASS.

**Step 5: Regenerate the studio's inputs.** `npm --prefix studio run schema`. In `settings-written.test.ts` add after the `layout.rows` entry a `layout.rows_2` value off its default, for example `[[{ widget: "heatmap", share: 1 }], [{ widget: "hours", share: 2 }, { widget: "records", share: 1 }]]`. Then `KOPANDA_UPDATE_GOLDENS=1 npm --prefix studio test -- test/core/settings-written.test.ts`.

**Step 6: Run** `bin/check spec/unit/studio_schema_spec.lua spec/unit/studio_settings_file_spec.lua spec/unit/schema_json_spec.lua` and `npm --prefix studio run check`. Expected: PASS. (The studio's validators take the widgets from the entry, so nothing else changes.)

---

### Task 2: the insight tokens

**Files:**
- Modify: `kopanda.koplugin/looks/base.lua` (`type` and a new `insights` table), `kopanda.koplugin/looks/diner.lua`
- Test: `spec/unit/looks_spec.lua`

**Step 1: Write the failing test.** Add to `looks_spec.lua`, beside the type checks:

```lua
it("gives every look the insight parts and tokens, Diner's levels in its accents", function()
    for _, id in ipairs(Looks.ids()) do
        local look = Looks.get(id)
        for _, part in ipairs({ "insight_label", "insight_caption", "insight_value", "insight_note" }) do
            assert.is_table(look.type[part], id .. " " .. part)
        end
        local i = look.insights
        assert.is_number(i.padding)
        assert.is_number(i.calendar_cell)
        assert.is_number(i.chart_height)
        for _, role in ipairs({ "level_1_color", "level_2_color", "level_3_color", "read_fill_color", "bar_fill_color" }) do
            assert.is_string(i[role], id .. " " .. role)
        end
    end
    local diner = Looks.get("diner")
    assert.same({ "mustard", "teal", "ink" },
        { diner.insights.level_1_color, diner.insights.level_2_color, diner.insights.level_3_color })
end)
```

**Step 2: Run** `bin/check spec/unit/looks_spec.lua`. Expected: FAIL on `insight_label`.

**Step 3: Add the tokens** from the design to `base.lua` (the four `type` parts in the `type` table, `insights` as a new top-level table after `home`) and Diner's overrides to `diner.lua`. The base's `type` parts name `strong`, `text` and `display` only.

**Step 4: Run** the spec. Expected: PASS, including the existing path checks.

---

### Task 3: `ReadingStats.insights`

**Files:**
- Modify: `kopanda.koplugin/reading_stats.lua`
- Test: `spec/unit/reading_stats_spec.lua` (its `make_db`, `on_day`, `NOW` helpers)

**Step 1: Write the failing tests.** In a new `describe("insights", ...)` inside the spec, using the file's helpers (rows are `{ id_book, start_time, duration }`, each on its own page):

```lua
it("reads a year of days, oldest first, today last", function()
    make_db({ on_day(0, 600), on_day(-1, 900), on_day(-370, 60), on_day(-371, 60) })
    local got = ReadingStats.insights(NOW)
    assert.equals("ok", got.state)
    assert.equals(ReadingStats.INSIGHT_DAYS, #got.days)
    assert.equals(600, got.days[#got.days])
    assert.equals(900, got.days[#got.days - 1])
    assert.equals(60, got.days[1])      -- 370 days ago is the first day kept
    local sum = 0
    for _, s in ipairs(got.days) do sum = sum + s end
    assert.equals(1560, sum)            -- 371 days ago is out
end)

it("sums each hour of the day over the last 90 days", function()
    local t = os.date("*t", NOW)
    make_db({
        { 1, at(t.year, t.month, t.day, 7, 10), 600 },
        { 1, at(t.year, t.month, t.day - 1, 7, 50), 300 },
        { 1, at(t.year, t.month, t.day - 89, 22, 0), 120 },
        { 1, at(t.year, t.month, t.day - 90, 22, 0), 120 },
    })
    local hours = ReadingStats.insights(NOW).hours
    assert.equals(24, #hours)
    assert.equals(900, hours[8])        -- 07:00 is index 8
    assert.equals(120, hours[23])
end)

it("folds page rows into sessions split by a gap over 30 minutes", function()
    local t = os.date("*t", NOW)
    local base = at(t.year, t.month, t.day, 7, 0)
    make_db({
        { 1, base, 60 }, { 1, base + 60, 60 }, { 1, base + 120, 60 },         -- one 3 min session, 3 pages
        { 1, base + 120 + 60 + 1801, 600 },                                   -- a gap of 1801 s: a new session
        { 1, base + 86400 * 364, 60 }, { 1, base + 86400 * 365, 60 },         -- the last is 365 days out
    })
    local s = ReadingStats.insights(NOW).sessions
    assert.equals(3, s.count)
    assert.equals(600, s.longest)
    assert.equals(280, s.average)       -- (180 + 600 + 60) / 3
    assert.equals(21, s.pages_per_hour) -- 5 pages over 840 s, rounded
end)

it("reads as off, and as empty with no database or nothing read", function()
    remove_db()
    assert.equals("empty", ReadingStats.insights(NOW).state)
    assert.is_nil(ReadingStats.insights(NOW).sessions)
    assert.equals(0, ReadingStats.insights(NOW).days[1])
    -- off: set G_reader_settings statistics.is_enabled false as the existing "off" case does
end)

it("reads the database once per stamp and date", function()
    -- as the existing memo cases do: make_db, read twice, assert one SQ3.open through a spy
end)
```

Pick `pages_per_hour`'s expected value by hand from the rows you write; the 365-day boundary row and today's rows are the point. Beware `on_day(-370)` lands at noon; `at()` is the file's helper.

**Step 2: Run** `bin/check spec/unit/reading_stats_spec.lua`. Expected: FAIL, `insights` is nil.

**Step 3: Implement** in `reading_stats.lua`, beside `query`:

```lua
ReadingStats.INSIGHT_DAYS = 371
local HOUR_DAYS = 90
local SESSION_DAYS = 365
local SESSION_GAP = 1800

-- Seconds per local day for the INSIGHT_DAYS days ending today, oldest first; per hour of the day over the last
-- HOUR_DAYS days; and the sessions of the last SESSION_DAYS days: runs of page rows each starting within
-- SESSION_GAP of the previous row's end. SQLite groups by the C library's local zone, the one os.date uses.
local function insight_query(conn, now)
    local t = os.date("*t", now)
    local days, index = {}, {}
    for i = 1, ReadingStats.INSIGHT_DAYS do
        days[i] = 0
        index[os.date("%Y-%m-%d", day_start(t, ReadingStats.INSIGHT_DAYS - i) + 43200)] = i
    end
    local stmt = conn:prepare("SELECT strftime('%Y-%m-%d', start_time, 'unixepoch', 'localtime'), sum(duration)"
        .. " FROM page_stat_data WHERE start_time >= ? GROUP BY 1")
    local row = stmt:bind(day_start(t, ReadingStats.INSIGHT_DAYS - 1)):step()
    while row do
        local i = index[row[1]]
        if i then
            days[i] = tonumber(row[2]) or 0
        end
        row = stmt:step()
    end
    stmt:close()

    local hours = {}
    for i = 1, 24 do
        hours[i] = 0
    end
    stmt = conn:prepare("SELECT strftime('%H', start_time, 'unixepoch', 'localtime'), sum(duration)"
        .. " FROM page_stat_data WHERE start_time >= ? GROUP BY 1")
    row = stmt:bind(day_start(t, HOUR_DAYS - 1)):step()
    while row do
        hours[tonumber(row[1]) + 1] = tonumber(row[2]) or 0
        row = stmt:step()
    end
    stmt:close()

    local sessions, current, pages, total = {}, nil, 0, 0
    stmt = conn:prepare("SELECT start_time, duration FROM page_stat_data WHERE start_time >= ? ORDER BY start_time")
    row = stmt:bind(day_start(t, SESSION_DAYS - 1)):step()
    while row do
        local start, duration = tonumber(row[1]), tonumber(row[2]) or 0
        if not current or start - current.ends > SESSION_GAP then
            current = { seconds = 0, ends = start }
            sessions[#sessions + 1] = current
        end
        current.seconds = current.seconds + duration
        current.ends = start + duration
        pages, total = pages + 1, total + duration
        row = stmt:step()
    end
    stmt:close()
    local summary
    if #sessions > 0 then
        local longest = 0
        for _, s in ipairs(sessions) do
            longest = math.max(longest, s.seconds)
        end
        summary = {
            count = #sessions,
            longest = longest,
            average = math.floor(total / #sessions + 0.5),
            pages_per_hour = total > 0 and math.floor(pages * 3600 / total + 0.5) or 0,
        }
    end
    return { state = "ok", days = days, hours = hours, sessions = summary }
end
```

`ReadingStats.insights(now)` mirrors `ReadingStats.read`: off → `{ state = "off" }`; no file → empty (`days` and `hours` of zeros, `sessions` nil, `state = "empty"`); memo `memo.insights = { key, date, value }` honoured when `key` and `date` match; a busy read returns the last insights read, else empty; everything inside a `pcall` that logs and returns empty. Write an `empty_insights()` helper. Keep `day_start`'s calendar arithmetic.

**Step 4: Run** the spec. Expected: PASS. Then `bin/check --lint`.

---

### Task 4: the shared tile, `insight_tile.lua`

**Files:**
- Create: `kopanda.koplugin/insight_tile.lua`
- Modify: `kopanda.koplugin/main.lua` (require it beside `home_rows`)
- Test: `spec/unit/insight_tile_spec.lua`

**API:**

```lua
-- InsightTile.compose(width, ctx, label, aside, content_h, paint) -> widget, inner
--   label: the tile's label text; aside: a right-aligned caption or nil.
--   content_h: the content's height in device pixels, given by the widget.
--   paint(bb, x, y, inner_w, content_h, ctx): draws the content at its top-left.
-- Returns the widget (height = chrome + label line + label_gap + content_h) and inner = { w, label_h },
-- so a widget can measure its content against inner.w first: InsightTile.inner_width(width, ctx).
```

The chrome copies `quote.lua:150-176` exactly (box with outline and shadow when `look.tile.box`, rules in `look.tile.rule_color` otherwise, plain on a plate). The label is `Typeset.line(look.type.insight_label, ...)`, the aside `Typeset.line(look.type.insight_caption, ...)` set right-aligned on the same line, cut first when they overlap. The content paints through a `Widget` subclass whose `paintTo` calls `paint`. Free the lines on `free`.

**Step 1: Write the failing tests** (model: `quote_spec.lua`'s `ctx_for`):

```lua
it("is the chrome, a label line, the gap and the content tall", function()
    local ctx = ctx_for("diner")
    local scale = Paint.scaler(ctx)
    local painted
    local tile = InsightTile.compose(520, ctx, "Reading this year", nil, 100, function(_, _, _, w, h)
        painted = { w = w, h = h }
    end)
    local outline, pad = scale(ctx.look.stroke.outline), scale(ctx.look.insights.padding)
    local label_h = Typeset.line_height(ctx.look.type.insight_label, ctx)
    assert.equals(2 * (outline + pad) + scale(ctx.look.shadow.tile.y) + label_h + scale(ctx.look.insights.label_gap) + 100,
        tile:getSize().h)
    tile:paintTo(Blitbuffer.new(520, tile:getSize().h, Blitbuffer.TYPE_BBRGB32), 0, 0)
    assert.equals(InsightTile.inner_width(520, ctx), painted.w)
    assert.equals(100, painted.h)
end)

it("draws rules, not a box, in a look without a tile box", function()
    -- Editorial: height = 2 * (rule + pad) + label + gap + content, no shadow
end)

it("cuts the label before the aside when both don't fit", function() ... end)
```

**Step 2: Run** `bin/check spec/unit/insight_tile_spec.lua`. Expected: FAIL, module not found.

**Step 3: Implement.** Then **Step 4: Run**, PASS; `bin/check spec/unit/main_requires_spec.lua`.

---

### Task 5: the reading widget

**Files:** `widgets/reading.lua`, registry, `main.lua`; test `spec/unit/reading_widget_spec.lua`.

**Shape.** Full width. Label "Reading"; aside "hours a week, last 12 weeks". Left, in `reading_column` of the width: this month's time read ("this month") over its days read ("days read"), values in `insight_value` shrunk together to fit. Right, `padding` away: an area chart of the last 12 Monday-to-Sunday weeks scaled to the busiest, this week ringed, month abbreviations under the first week of each new month. Off: the label line alone.

---

### Task 6: the streak widget

**Files:** `widgets/streak.lua`, registry, `main.lua`; test `spec/unit/streak_widget_spec.lua`.

**Shape.** Half width. Label "Streak"; aside "best N", the longest run of days read in `days`. The current run (to today, or to yesterday before today's reading) in `insight_value` at `streak_scale` times its size, "days in a row" beside it; under it this week's seven dots, a day read filled, today ringed, "this week" to their right.

---

### Task 7: the forecast widget

**Files:** `widgets/forecast.lua`, registry, `main.lua`; test `spec/unit/forecast_widget_spec.lua`.

**Shape.** Reads `FeaturedBook.current()` and `ReadingStats.insights(ctx.now)`. Label "Finish by". With a book and `seconds_left`: a value line (`insight_value`) with "Today", "Tomorrow" or the weekday name (`datetime.shortDayOfWeekToLongTranslation[os.date("%a", finish)]`); a note line (`insight_note`) "<day> <Month>, at this pace"; then the book's title in `featured_title`'s part cut to the width, and a caption (`featured_caption`) "<time left> left · <per day> a day". `per_day = max(300, sum of the last 14 of days / 14)`; `days_out = max(0, ceil(seconds_left / per_day) - 1)`; `finish = day_start(today) + days_out days + 12 h` (through the calendar, as `reading_stats.lua`'s `day_start`: expose `ReadingStats.day_offset(now, days)` for it). Time left formatted as `widgets/featured.lua:99` formats it (reuse `Featured.time_left` by exporting it). Without a book: value "No book", note "Open one and this fills in". With a book but no pace (`seconds_left` nil) or insights off: value "No pace yet", note "Read a few pages first". No progress bar (the mock's is the featured widget's; keep this tile text-only). Hold: none.

Tests: 2 h 6 min left at 38 min a day (14 days summing 31920 s) from Tuesday 13 Oct 2026 20:42 → `days_out = ceil(7560 / 2280) - 1 = 3`, "Friday", "16 October, at this pace"; 600 s left → "Today"; the no-book and no-pace lines; height = value + note + title + caption lines and gaps.

---

### Task 8: the hours widget

**Files:** `widgets/hours.lua`, registry, `main.lua`; test `spec/unit/hours_widget_spec.lua`.

**Shape.** Label "When you read", aside "last 90 days". Content: 24 bars, width `floor((inner_w - 23 * gap) / 24)`, chart `scale(chart_height)` tall, a bar's height `round(chart * seconds / busiest)`, at least 2 px when seconds > 0, in `bar_fill_color`, or `bar_high_color` at or above 60 % of the busiest; with `bar_outline_width > 0` an outline in `look.tile.outline_color` (Diner). Under the bars, `label_gap` then four captions at the x of hours 0, 6, 12 and 18: "Midnight", "6 am", "Noon", "6 pm" (or "06:00", "12:00", "18:00" when `G_reader_settings:isTrue("twelve_hour_clock")` is false; read it as `widgets/clock.lua` does). Nothing read: the bars are empty and the aside reads "Nothing read yet". Height = chart + label_gap + caption line.

Tests: a fixture with 900 s at hour 7 and 1500 s at hour 21 gives a 21:00 bar of full chart height in `bar_high_color` and the 7:00 bar at `round(chart * 0.6)` in `bar_high_color`, a 300 s hour in `bar_fill_color`; heights; the clock captions in both formats.

---

### Task 9: the records widget

**Files:** `widgets/records.lua`, registry, `main.lua`; test `spec/unit/records_widget_spec.lua`.

**Shape.** Label "Sessions", aside "last year". Content: a 2×2 grid (two columns of `floor((inner_w - column_gap) / 2)` with the look's `home.column_gap`), each cell a value line (`insight_value`) over a caption (`insight_caption`) with `value_gap` between, rows `record_gap` apart: `count` / "sessions"; longest as "1 h 48 min" (`Featured.time_left` formatting) / "longest"; average the same / "average"; `pages_per_hour` / "pages an hour". With no sessions: the values read "0", "0 min", "0 min", "0". Height = 2 rows of (value + gap + caption) + record_gap.

Tests: the fixture `{ count = 312, longest = 6480, average = 1440, pages_per_hour = 41 }` renders "312", "1 h 48 min", "24 min", "41"; nil sessions render the zeros; height formula.

---

### Task 10: the page turn

**Files:**
- Modify: `kopanda.koplugin/home_rows.lua` (`HomeRows.keys`, `build` reads the page's key), `kopanda.koplugin/home.lua` (`Home.page`, `Home:turn`), `kopanda.koplugin/home_gestures.lua` (the turn step)
- Test: `spec/unit/home_pages_spec.lua` (new), `spec/unit/gesture_routing_spec.lua:174-186` (reword), `spec/unit/layout_spec.lua` (the page-2 default fits both profiles)

**Step 1: Write the failing tests.** `home_pages_spec.lua`, modelled on `home_layout_spec.lua` (stub every widget id of both keys with heights that fit):

```lua
it("starts on page 1 and builds page 2's rows on a west swipe", function()
    local _, home = show_home()
    assert.equals(1, home.page)
    send(swipe(size.w / 2, size.h / 2, "west"))
    harness.tick()
    assert.equals(2, home.page)
    assert.truthy(slot_of(home, "heatmap"))
    assert.is_nil(slot_of(home, "launcher"))
end)
it("returns to page 1 on an east swipe and stays at either end", ...)
it("keeps the page through a refresh and a Resume", ...)
it("starts a new home on page 1", ...)  -- close, show again
it("closes the home when page 2 fails to build", ...)  -- a stub whose build raises is blank, not a close: assert the blank; a HomeRows.build raise closes
it("leaves the swipe to the file chooser's zones in the edge bands", ...)  -- unchanged behaviour
```

Add to `layout_spec.lua`: "fits the page-2 default on the Colorsoft and the Paperwhite at every text size in every look" using the real widgets with `ReadingStats.insights` stubbed to a populated fixture (the existing "default fits" case for `layout.rows` is the model; find it with `grep -n "fits" spec/unit/layout_spec.lua`).

Reword `gesture_routing_spec.lua:174`: "turns the page on a west or east swipe mid-screen, leaving the file chooser's page".

**Step 2: Run.** Expected: FAIL, `home.page` nil.

**Step 3: Implement.**

`home_rows.lua`:
```lua
-- The layout keys by page.
HomeRows.keys = { "layout.rows", "layout.rows_2" }
...
local arranged = Layout.arrange(Settings.get(HomeRows.keys[home.page or 1]), ctx)
```

`home.lua`:
```lua
function Home:init()
    self.page = 1
    ...
end

-- Turns delta pages (−1 or 1) within HomeRows.keys, rebuilding and repainting; at either end nothing changes.
-- A failed rebuild closes the home, as refresh does.
function Home:turn(delta)
    local page = math.max(1, math.min(#HomeRows.keys, self.page + delta))
    if page == self.page then
        return
    end
    self.page = page
    local ok, err = pcall(function()
        rebuild(self)
        UIManager:setDirty(self, "ui")
    end)
    if not ok then
        logger.err("KoPanda: could not turn the home's page:", err)
        close_home(self)
    end
end
```

`home_gestures.lua`, in `route` before `forward`:
```lua
if HomeGestures.is_page_swipe(ges) then
    home:turn(ges.direction == "west" and 1 or -1)
    return true
end
```
Update `route`'s comment and the module comment (the forward step still consumes the swipe for the library).

**Step 4: Run** the three specs and `spec/unit/home_layout_spec.lua`, `spec/unit/home_lifecycle_spec.lua`. Expected: PASS.

---

### Task 11: the device editors

**Files:**
- Modify: `kopanda.koplugin/rows_edit.lua` (an entry per key; the five labels), `kopanda.koplugin/edit_layout.lua` (`opts.key`, the title, `Settings.set(state.key, ...)`, `RowsEdit.reset(state.key)`), `kopanda.koplugin/home_sheet.lua` (an "Edit page 2" row after "Edit layout")
- Test: `spec/unit/rows_edit_spec.lua`, `spec/unit/edit_layout_spec.lua`, `spec/unit/home_sheet_spec.lua`

`RowsEdit` keeps its operations pure; `RowsEdit.entry(key)` returns the schema entry; `reset(key)` and `unused(rows, key)` take the key (default `"layout.rows"`). The five labels landed in Task 1 (both `rows_edit.lua` and the studio's `rows-edit.ts`), with the shared fixtures. Also: the settings menu's "Page 2" row (`menu.lua:266-267`, `BUILDERS.rows`) must open the editor on its own key, not `layout.rows`; test it in `spec/unit/menu_spec.lua`. `EditLayout.open{ key = "layout.rows_2" }` titles the screen "Edit page 2" (page 1 keeps "Edit layout"), reads and writes that key, and resets to its default. The home sheet's new row opens it. Tests: a reset of `layout.rows_2` is its default; opening with the key shows its rows and writes to it; the sheet row exists and opens the editor on the key.

---

### Task 12: the studio

**Files:**
- Modify: `studio/src/core/rows-edit.ts` (`entryFor(id)`, `entry` kept as `entryFor("layout.rows")`; `LABELS`), `studio/src/ui/layout/LayoutEditor.tsx` (an `entry` prop), `studio/src/ui/ProfileScreen.tsx` (`ProfileView` gains `"layout-2"`), `studio/src/ui/App.tsx:26-31` (the route), `studio/src/ui/settings/controls/RowsControl.tsx` (href from the entry: `layout.rows` → `/layout`, `layout.rows_2` → `/layout-2`), `studio/src/ui/api.ts` (`checkFit(id, rows, key)`), `studio/src/server/routes/layout-fit.ts` (`key` in the body, one of the schema's `rows` keys, else 400; `current: values[key]`)
- Test: `studio/test/core/rows-edit.test.ts`, `studio/test/ui/layout-editor.test.tsx`, `studio/test/ui/settings-form.test.tsx`, `studio/test/server/layout-fit.test.ts`

Each test first: the form shows "Page 2 · 4 rows" linking to `/layout-2`; the editor at `/layout-2` shows page 2's rows and writes `layout.rows_2`; the fit route with `key: "layout.rows_2"` compares against that key and refuses an unknown key with 400; `checkFit` sends the key. Run `npm --prefix studio run check`.

---

### Task 13: the emulator capture

**Files:**
- Create: `spec/emulator/scenarios/2-scenario-home-page.lua`, `spec/emulator/home_page_spec.lua`
- Test: `bin/check spec/emulator/home_page_spec.lua`

The scenario, modelled on `2-scenario-night-toggle.lua`: on the first `home` settled signal, `nextTick` sends `Event:new("Gesture", { ges = "swipe", direction = "west", pos = Geom:new{ x = w / 2, y = h / 2, w = 0, h = 0 }, time = time.now() })` through `UIManager:sendEvent`, then `tickAfterNext` reports `{ screen = "scenario", page = Home.shown and Home.shown.page }`. The spec captures Diner by day on the Colorsoft and by day on the Paperwhite with `patches = { fixture, scenario }`, `shot_screen = "scenario"`, the fixture's `env`, and `out_dir = os.getenv("KOPANDA_CAPTURE_DIR")` when set so the owner can look; asserts `page == 2`, the PNG's size, one `KOPANDA_SHOT: saved`, no "doesn't fit the screen" line, and that the paper pixel at the left margin is the palette's. Add a row to `HOOKS.md`'s harness table for the scenario (the `Gesture` event shape it sends, `frontend/ui/gesturerange.lua:21-51`; `UIManager:sendEvent`, cite its line in `frontend/ui/uimanager.lua`).

Then the owner's manual check: `KOPANDA_CAPTURE_DIR=/tmp/kopanda-page2 bin/check spec/emulator/home_page_spec.lua && open /tmp/kopanda-page2/*.png`.

---

### Task 14: docs and the full gate

- `AGENTS.md`: nothing in Commands changes. Under Conventions, after the runtime-state bullet, add one line: "The home has two pages, `layout.rows` and `layout.rows_2`, one built at a time; a widget may sit on both."
- `kopanda.koplugin/HOOKS.md`: the scenario row (Task 13); `page_stat_data` columns are already cited.
- Out of scope, to mention to the owner: `bin/preview` and the studio's preview pane render page 1 only; the lean-down 2 plan's spec wave may want `spec/unit/layout_spec.lua`'s new fit case folded in.
- The lead runs `bin/check` whole before the merge.

---

## Order and parallelism

Tasks 1 and 2 first (every later task reads the schema and tokens), then 3 and 4 in parallel, then 5 to 9 in parallel (each one agent, each self-reviewed: they are under 150 lines outside the push and bundle paths), then 10, then 11 and 12 in parallel, then 13, then 14. Tasks 3, 4 and 10 take a reviewer each: 3 reads a file the plugin didn't write; 4 and 10 are shared by every tile and every gesture.
