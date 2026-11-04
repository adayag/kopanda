# Stats window Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** A swipeable full-screen Stats window, opened from a nav bar tab that replaces Authors, with a new month-bars page, and the
home reduced to one page.

**Architecture:** A new `stats_screen.lua` extends `LibraryChrome.Window`, the base the book details and Series windows
use, and flows a table of tile rows onto pages by fit. Swipes, the pager and the nav bar come from that base. A new
`widgets/months.lua` adds the month bars. Deleting `layout.rows_2` then removes page 2 from the plugin, the specs and
the studio.

**Tech Stack:** Lua on KOReader's LuaJIT, Busted unit specs, emulator capture specs, TypeScript studio.

Design: `docs/plans/2026-11-03-stats-window-design.md`. About half a day. Roughly 300 lines added and 800 removed.

**Agents:** Two Opus builders in sequence: Tasks 1–4, then Tasks 5–6. One Opus reviewer, one pass over the whole
change, no mutation checks (nothing here handles outside files or the push path). Filter `bin/check` output so
KOReader's library-loading chatter and per-test lines stay out of the transcript.

**Tiller:** None. Work on `main`, by the owner's standing instruction.

**Commits:** Don't commit during the tasks. Each task lists the files for its commit, and the lead asks "Ready to
commit and push?" at the end. Check `git status` first and stage named files only.

---

## Task 1: Month bars

**Files:**
- Create: `kopanda.koplugin/widgets/months.lua`
- Modify: `kopanda.koplugin/insight_tile.lua` (takes `bars` from `hours.lua`), `kopanda.koplugin/widgets/hours.lua`,
  `kopanda.koplugin/widgets.lua`, `kopanda.koplugin/main.lua`, `kopanda.koplugin/looks/base.lua`
- Test: `spec/unit/months_widget_spec.lua` (model: `spec/unit/hours_widget_spec.lua`)

**Step 1: Write the failing tests**

For `Months.totals(days, now)`:

- 12 entries, oldest first, the last being now's month.
- Today on the 1st: yesterday counts in last month, today in this one.
- In January, the first entry is February of last year.
- A day older than the 12 months is dropped.
- A DST change day lands in its own month: run with `TZ` as the existing specs do, or pick a March date.

For the tile, by the `hours_widget_spec` pattern:

- The aside is `Helpers.duration` of the total: 1800 seconds reads `30 min`, never `0 h`.
- `Nothing read yet` with all zeros.
- `Reading stats are off` with `state = "off"` and a content height of 0.
- The busiest month paints at the full chart height. A month of one minute paints at the minimum bar.
- 12 near-equal months give exactly one high bar, the busiest. The hours tile keeps its 60 % rule.

**Step 2: Run them and see them fail**

Run: `bin/check spec/unit/months_widget_spec.lua`
Expected: FAIL, module not found.

**Step 3: Implement**

Move `bars`, `HIGH` and `MIN_BAR` from `hours.lua` into `insight_tile.lua` as
`InsightTile.bars(values, chart, high_share)`, with `high_share` defaulting to `HIGH`, and have `hours.lua` call it
with no third argument. Drop `hours.lua`'s `Math` require. Its spec stays green unchanged.

Add to the `insights` table in `looks/base.lua`:

```lua
        month_chart_height = 120,
        month_gap = 8, -- between month bars
```

Add `months = "widgets/months"` to `widgets.lua`, but not to any schema `widgets` list, and add
`require("widgets/months")` to `main.lua`, sorted, beside `widgets/launcher`.

```lua
-- The last twelve months' reading: one bar per calendar month from ReadingStats.insights' days, this month last,
-- each under its initial, in an insight tile with the hours read aside.
local Helpers = require("helpers")
local InsightTile = require("insight_tile")
local Looks = require("looks")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")

local COUNT = 12
local INITIALS = "JFMAMJJASOND"
local LABEL = "Last 12 months"

local Months = {
    id = "months",
    settings_prefix = "stats",
}

-- Each of the COUNT months ending at now's as { month, seconds }, oldest first, from days (seconds per local day,
-- today last). Noon, so a DST change never moves a day.
function Months.totals(days, now)
    local t = os.date("*t", now)
    local list, by_month = {}, {}
    for back = COUNT - 1, 0, -1 do
        local offset = t.month - back - 1
        local entry = { month = offset % 12 + 1, seconds = 0 }
        list[#list + 1] = entry
        by_month[(t.year + math.floor(offset / 12)) * 12 + entry.month] = entry
    end
    for i, seconds in ipairs(days) do
        local day = os.date("*t", os.time{ year = t.year, month = t.month, day = t.day - (#days - i), hour = 12 })
        local entry = by_month[day.year * 12 + day.month]
        if entry then
            entry.seconds = entry.seconds + seconds
        end
    end
    return list
end

local function compose(width, ctx)
    local look = ctx.look
    local tokens = look.insights
    local insights = ReadingStats.insights(ctx.now)
    if insights.state == "off" then
        return InsightTile.compose(width, ctx, LABEL, "Reading stats are off", 0, function() end)
    end

    local scale = Paint.scaler(ctx)
    local color = Looks.colorer(ctx)
    local fill, high = color(tokens.bar_fill_color), color(tokens.bar_high_color)
    local outline = scale(tokens.bar_outline_width)
    local outline_color = color(look.tile.outline_color)
    local chart = scale(tokens.month_chart_height)
    local gap, label_gap = scale(tokens.month_gap), scale(tokens.label_gap)
    local inner_w = InsightTile.inner_width(width, ctx)
    local bar_w = math.floor((inner_w - (COUNT - 1) * gap) / COUNT)
    local step = bar_w + gap

    local totals = Months.totals(insights.days, ctx.now)
    local values, total = {}, 0
    for i, entry in ipairs(totals) do
        values[i] = entry.seconds
        total = total + entry.seconds
    end
    -- A share of 1 marks only the busiest: most months of a steady year pass the hours tile's 60 %.
    local list = InsightTile.bars(values, chart, 1)

    local part = look.type.insight_caption
    local captions = {}
    for i, entry in ipairs(totals) do
        local line = Typeset.line(part, INITIALS:sub(entry.month, entry.month), step, ctx)
        captions[i] = { line = line, x = (i - 1) * step + math.floor((bar_w - line:getSize().w) / 2) }
    end
    local content_h = chart + label_gap + Typeset.line_height(part, ctx)

    local function paint(bb, x, y)
        for i, bar in ipairs(list) do
            if bar.h > 0 then
                local bx, by = x + (i - 1) * step, y + chart - bar.h
                Paint.fill(bb, bx, by, bar_w, bar.h, bar.high and high or fill)
                if outline > 0 then
                    Paint.border(bb, bx, by, bar_w, bar.h, outline, outline_color)
                end
            end
        end
        for _, caption in ipairs(captions) do
            caption.line:paintTo(bb, x + caption.x, y + chart + label_gap)
        end
    end

    local aside = total > 0 and Helpers.duration(total) or "Nothing read yet"
    local tile = InsightTile.compose(width, ctx, LABEL, aside, content_h, paint)
    tile.captions = captions
    local free_tile = tile.free
    function tile:free()
        for _, caption in ipairs(self.captions) do
            caption.line:free()
        end
        self.captions = {}
        free_tile(self)
    end
    return tile
end

Months.height, Months.build = Typeset.measured(compose)

return Months
```

**Step 4: Run them and see them pass**

Run: `bin/check spec/unit/months_widget_spec.lua spec/unit/hours_widget_spec.lua spec/unit/main_requires_spec.lua`
Expected: PASS.

**Files for the commit:** the files above.

---

## Task 2: The Stats window

**Files:**
- Create: `kopanda.koplugin/stats_screen.lua`
- Modify: `kopanda.koplugin/main.lua`, `kopanda.koplugin/nav_bar.lua`, `kopanda.koplugin/insight_tile.lua`
- Test: `spec/unit/stats_screen_spec.lua` (model: `spec/unit/subjects_screen_spec.lua` for the window, stub widgets as
  `home_pages_spec` stubbed them), `spec/unit/nav_bar_spec.lua`

**Step 1: Write the failing tests**

Stub `ReadingStats.insights` with a fixture, show the home through `harness.show_fm()`, and register stub tiles of
chosen heights for the flow cases.

Layout and flow:

- `fm.kopanda:showStats{}`: the home has closed and `LibraryChrome.shown` is a `stats` window at page 1.
- Rows draw in order, and a two-tile row places two half-width tiles side by side with the gap between them.
- The header names the page by its first row: "Now" on page 1, and with stub heights that push the hours row to a
  page of its own, "Habits" there.
- The month row starts its own page even when stub heights would let it fit, named "Over time".
- For each look at the Colorsoft's and Paperwhite's sizes with populated tiles at Medium, page 1 holds 3 rows and page
  2 is "Over time". This guards the gaps.
- At Extra large, hours and records each take a full-width row. At Medium they share one.
- Tiles get the stored text size, here `large`, while the nav bar and pager keep the shell's nil.
- `BookMetadataChanged` causes no `setDirty`.
- A row that ends exactly at the room stays on the page. One a pixel taller starts the next page.
- A row taller than a whole page sits alone on its page, and the rows around it still draw.
- `self.pages` follows the flow, and a second window at another text size gets its own flow.
- Rotation (a new screen size) flows the rows again and keeps the page clamped.

Turning, from the base, so one test each:

- A west swipe turns to the next page and an east swipe back.
- A west swipe on the last page: no rebuild, no `setDirty`.

Freshness:

- Every build reads `os.time()`: stub it forward a day, turn the page, and the tiles get the new `now`.
- `Event:new("Resume")` rebuilds at the page shown with the new `now`, and flows again.

Robustness:

- A tile whose `height` raises, and one whose `build` raises, each leave a blank slot, logged by id, and the rest of
  the page draws. A tile that failed to measure isn't drawn.
- A tap or a hold on a tile runs nothing and opens no sheet.

Box (`spec/unit/insight_tile_spec.lua`):

- In Frosted with `ctx.boxed`, a tile draws a box with the plate's keyline colour, width and radius. Without it, as on
  the home, the tile stays plain. Diner and Editorial are unchanged either way.

Nav bar (`nav_bar_spec`):

- The tabs read Home, Library, Stats, History, Settings, each with a registry icon (`:103-113`).
- The bar on `stats` lights Stats. The Authors window lights none (`:679-681`).
- The Stats tab from the home, the file browser and a library window shows the Stats window; on the Stats window on
  page 2, it goes to page 1 with no new window.
- The Home tab closes the window and goes home, by the Series case.
- Rewrite the Authors tab cases at `:492`, `:538-552`, `:571-587` and `spec/unit/fm_nav_spec.lua:254` for Stats. The
  Authors screen's own specs stay.

**Step 2: Run them and see them fail**

Run: `bin/check spec/unit/stats_screen_spec.lua spec/unit/nav_bar_spec.lua`
Expected: FAIL, module not found.

**Step 3: Implement**

`nav_bar.lua`: in `NavBar.TABS`, `{ id = "stats", label = "Stats", icon = "stats" }` replaces the Authors entry. Add
`stats = "stats_screen"` to `WINDOWS`, add `"stats"` to `NavBar.run`'s comment, and add `stats_screen` to the module
comment's call-time list. Update the module comment's tab list. In `ACTIVE`, remove `authors` and add
`stats = "stats"`, with its comment saying the Stats window lights Stats and the Series, Subjects and Authors windows
light none. In `NavBar.run`, before the `history` branch:

```lua
        elseif id == "stats" then
            -- On the Stats window, its first page; from anywhere else, the window shown through the plugin.
            local StatsScreen = require("stats_screen")
            if StatsScreen.shown then
                StatsScreen.shown:go(StatsScreen.shown:view(), 1)
            else
                package.loaded["apps/filemanager/filemanager"].instance.kopanda:showStats{}
            end
```

`insight_tile.lua`, in `chrome_of`: a tile with `ctx.boxed` draws its box on a look with plates, in the plate's keyline.

```lua
    local on_plate = Typeset.on_plate(ctx)
    if on_plate and not ctx.boxed then
        return { plain = true }, 0, padding, width, 2 * padding
    end
    if look.tile.box then
        local shadow = look.shadow.tile
        local outline = scale(on_plate and look.plate.keyline or look.stroke.outline)
        local radius = on_plate and scale(look.plate.radius) or nil
        local chrome = {
            outline = outline,
            outline_color = color(on_plate and look.plate.keyline_color or look.tile.outline_color),
            fill_color = color(look.tile.fill_color),
            radius = radius,
            fill_radius = radius,
            shadow_color = color(shadow.color),
            shadow_x = shadow.color and scale(shadow.x) or 0,
            shadow_y = shadow.color and scale(shadow.y) or 0,
        }
```

The rest of that branch stays. Update the module comment's "nothing on a plate" to name `ctx.boxed`.

`stats_screen.lua`:

```lua
-- The Stats window: rows of insight tiles on the chrome (library_chrome.lua), flowed onto pages by fit and turned by a
-- swipe or the pager, read-only, with the nav bar. Tiles take the stored text size and a box of their own; the chrome
-- stays at the shell's size. A tile that fails to measure or build is logged and its slot stays blank. Reads the stats
-- again on wake, as the home does (home.lua:113).
local LibraryChrome = require("library_chrome")
local LibraryTiles = require("library_tiles")
local Settings = require("settings")
local Widgets = require("widgets")
local logger = require("logger")
local Screen = require("device").screen

local StatsScreen = LibraryChrome.Window:extend{
    name = "kopanda_stats",
    screen = "stats",
}

-- Each row's widget ids, left to right, sharing the row's width; its name, which names a page it starts; page, for a
-- row that always starts one; and stack, for a row whose tiles run full width at the sizes in STACKED.
local ROWS = {
    { name = "Now", "reading" },
    { name = "Now", "streak", "forecast" },
    { name = "Habits", stack = true, "hours", "records" },
    { name = "Over time", page = true, "months" },
}
-- Text sizes at which a stack row's tiles run full width, their labels cut off side by side.
local STACKED = { extra_large = true }
local VIEW = { kind = "stats" }

local function scale(px)
    return Screen:scaleBySize(px)
end

-- ROWS at text_size: a stack row's tiles each a row of their own under its name, when text_size stacks.
local function rows_at(text_size)
    if not STACKED[text_size] then
        return ROWS
    end
    local rows = {}
    for _, row in ipairs(ROWS) do
        if row.stack then
            for _, id in ipairs(row) do
                rows[#rows + 1] = { name = row.name, id }
            end
        else
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function tile_width(row, width, gaps)
    return math.floor((width - (#row - 1) * gaps.column) / #row)
end

-- The row's height, the ids that failed to measure added to failed.
local function row_height(row, width, gaps, ctx, failed)
    local h = 0
    for _, id in ipairs(row) do
        local ok, tile_h = pcall(function()
            return Widgets.get(id).height(tile_width(row, width, gaps), ctx)
        end)
        if ok then
            h = math.max(h, tile_h)
        else
            failed[id] = true
            logger.err("KoPanda: the Stats tile", id, "failed to measure:", tile_h)
        end
    end
    return h
end

-- The rows on pages room tall: a row marked page, or one that would run past the room, starts the next page.
local function flow(rows, room, width, gaps, ctx)
    local pages, failed, y = { {} }, {}, 0
    for _, row in ipairs(rows) do
        local h = row_height(row, width, gaps, ctx, failed)
        if #pages[#pages] > 0 and (row.page or y + h > room) then
            pages[#pages + 1] = {}
            y = 0
        end
        local page = pages[#pages]
        page[#page + 1] = row
        y = y + h + gaps.row
    end
    return pages, failed
end

local function add_row(row, frame, x, y, width, gaps, ctx, failed)
    local w = tile_width(row, width, gaps)
    local bottom = y
    for i, id in ipairs(row) do
        if not failed[id] then
            local ok, tile = pcall(function()
                return Widgets.get(id).build(w, ctx)
            end)
            if ok and tile then
                LibraryChrome.add(frame, tile, x + (i - 1) * (w + gaps.column), y)
                bottom = math.max(bottom, y + tile:getSize().h)
            else
                logger.err("KoPanda: the Stats tile", id, "failed to build:", tile)
            end
        end
    end
    return bottom
end

local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local text_size = Settings.get("text_size")
    local tile_ctx = { look = look, variant = ctx.variant, screen = ctx.screen, text_size = text_size,
        now = os.time(), boxed = true }
    local header_h = LibraryTiles.header_height(ctx)
    local x = scale(look.shelf.list.side)
    local width = w - 2 * x
    local top = header_h + scale(look.library.grid.padding_top)
    local gaps = { row = scale(look.home.row_gap), column = scale(look.home.column_gap) }
    local key = table.concat({ w, h, tostring(text_size), tostring(look) }, " ")
    if not (self.kept and self.kept.key == key) then
        local pages, failed = flow(rows_at(text_size), LibraryTiles.room(h, ctx, header_h), width, gaps, tile_ctx)
        self.kept = { key = key, pages = pages, failed = failed }
    end
    local pages = self.kept.pages
    built.pages = #pages
    built.page = math.max(1, math.min(built.page or 1, #pages))
    local page = pages[built.page]

    local header_box
    header_box, built.header = LibraryChrome.header(ctx, w, {
        height = header_h,
        band = look.library.header.fill_color,
        right = {},
        aside = { part = look.type.library_count, text = page[1].name },
        title = { part = look.type.library_title, text = "Stats" },
    })
    LibraryChrome.add(frame, header_box, 0, 0)

    local y = top
    for _, row in ipairs(page) do
        y = add_row(row, frame, x, y, width, gaps, tile_ctx, self.kept.failed) + gaps.row
    end
    LibraryChrome.foot(built, frame, "stats")
end

function StatsScreen:view()
    return VIEW
end

function StatsScreen:build(_, page)
    return LibraryChrome.build({ page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- Read-only: nothing on a page acts on a tap but the chrome's pager.
function StatsScreen.action_at()
    return nil
end

-- Nothing here changes with a book's metadata, which the chrome's events would otherwise repaint.
function StatsScreen:refresh() end

-- Broadcast to every window on wake (frontend/device/generic/device.lua:1125). Returns nothing, so the event reaches
-- the other windows.
function StatsScreen:onResume()
    self.kept = nil
    self:go(self:view(), self.page)
end

-- opts: page and started (LibraryChrome.show's). Returns the window shown, or nil.
function StatsScreen.show(opts)
    return LibraryChrome.show(StatsScreen, opts, { page = opts.page })
end

function StatsScreen.close()
    if StatsScreen.shown then
        LibraryChrome.close()
    end
end

return StatsScreen
```

The swipe's `self.page` comes from the base's `FIELDS`, and a build at a page past the end is clamped above.

`main.lua`: add `local StatsScreen = require("stats_screen")` beside `SeriesScreen`, then beside `showSubjects`:

```lua
-- The Stats window with opts (StatsScreen.show's), as show_shelf.
function KoPanda:showStats(opts)
    show_shelf(StatsScreen, opts)
end
```

**Step 4: Run them and see them pass**

Run: `bin/check spec/unit/stats_screen_spec.lua spec/unit/nav_bar_spec.lua spec/unit/main_requires_spec.lua`
Expected: PASS.

**Files for the commit:** the files above.

---

## Task 3: The icon

**Files:**
- Create: `kopanda.koplugin/icons/stats.svg`, `kopanda.koplugin/icons/phosphor-bold/stats.svg`
- Modify: `kopanda.koplugin/icons.lua`, `kopanda.koplugin/icons/SOURCES.md`, `studio/src/catalog.json`
- Test: `spec/unit/icons_spec.lua`

**Step 1: Write the failing test**

- `icons_spec`: add `stats` to the registered list at `:90`, and check `stats` is used in `nav` and `authors` no longer
  is.

**Step 2: Run it and see it fail**

Run: `bin/check spec/unit/icons_spec.lua`
Expected: FAIL.

**Step 3: Implement**

`icons.lua`, after `subjects`, with `"nav"` dropped from the `authors` entry's `used_in`:

```lua
    { id = "stats", label = "Stats", used_in = { "nav" }, file = "icons/stats.svg" },
```

Icons: Lucide `chart-column` recoloured to `stroke="#000000"`, stroke width 2; Phosphor `chart-bar-bold` with the
root's `fill="#000000"`, its `SOURCES.md` row carrying the SHA-256 of the file as shipped.

Regenerate:

```bash
npm --prefix studio run catalog
```

The launcher, `schema.lua` and `studio/src/schema.json` don't change in this task.

**Step 4: Run it and see it pass**

Run: `bin/check spec/unit/icons_spec.lua spec/unit/studio_catalog_spec.lua`
Expected: PASS.

**Files for the commit:** the files above.

---

## Task 4: Emulator capture

**Files:**
- Create: `spec/emulator/stats_screen_capture_spec.lua`, `spec/emulator/scenarios/2-scenario-stats-screen.lua`
- Modify: `spec/emulator/paint_budget_spec.lua`, `kopanda.koplugin/HOOKS.md` (the capture-scenario table)

**Step 1: Write the spec**

Model both on `quick_settings_capture_spec.lua` and `2-scenario-quick-settings.lua`, with the populated home
fixture. The scenario calls `require("apps/filemanager/filemanager").instance.kopanda:showStats{}` once the home
settles. Capture with `shot_screen = "stats"`.

The scenario also reports `LibraryChrome.shown.pages` on a `scenario` signal, since the settled signal carries only
`screen` and `paint_ms`, and stubs `ReadingStats.insights` with a full year of steady reading when
`KOPANDA_STATS_YEAR` is set. The fixture alone holds two months, too few to judge the bars.

Runs:

- `colorsoft`: one shot saved, 2 pages, and the log has no "failed to build" or "failed to measure".
- `paperwhite`: the same.
- `colorsoft` with a `settings_file` setting `text_size = "extra_large"`: the same checks, and more than 2 pages.
- `paperwhite` with `text_size = "large"`: the same checks, more than 1 page is fine. Keep the PNG: if labels are cut
  off side by side at Large too, add `large = true` to `STACKED`.

Add `stats` to `spec/emulator/paint_budget_spec.lua`, by the book status case, since this window's first build
measures every row.

Set `KOPANDA_CAPTURE_DIR` to keep the PNGs for the manual check. To capture page 2, send a west swipe as
`2-scenario-library_status.lua`'s `page2` step does, with `KOPANDA_STATS_YEAR` set.

**Step 2: Run it**

Run: `bin/check spec/emulator/stats_screen_capture_spec.lua spec/emulator/paint_budget_spec.lua`
Expected: PASS.

**Step 3: Show the owner**

`open` each PNG, in Diner, then Editorial and Frosted with `KOPANDA_HOME_LOOK`. The month chart height is a token value for
the owner to judge.

**Files for the commit:** the files above.

---

## Task 5: Remove page 2 from the plugin

**Files:**
- Modify: `kopanda.koplugin/schema.lua`, `home.lua`, `home_rows.lua`, `home_gestures.lua`, `home_sheet.lua`,
  `edit_layout.lua`, `rows_edit.lua` (comment only)
- Delete: `spec/unit/home_pages_spec.lua`, `spec/emulator/home_page_spec.lua`,
  `spec/emulator/scenarios/2-scenario-home-page.lua`
- Test: `spec/unit/gesture_routing_spec.lua`, `spec/unit/settings_spec.lua`, and the specs listed in Step 3

**Step 1: Write the failing tests**

- `gesture_routing_spec:286`: replace the test. A west or east swipe mid-screen leaves the file chooser's page, is
  consumed, doesn't rebuild the home (stub `Home.build` or count builds) and opens nothing.
- `settings_spec`: a settings file holding `["layout.rows_2"]` opens, reads `layout.rows` normally, and a
  `Settings.set` on another key succeeds.
- `home_sheet_spec`: the rows have no Edit page 2.

**Step 2: Run them and see them fail**

Run: `bin/check spec/unit/gesture_routing_spec.lua spec/unit/home_sheet_spec.lua`
Expected: FAIL. The `settings_spec` case passes already and stays as the guard for stored files.

**Step 3: Implement**

- `schema.lua`: delete the `layout.rows_2` entry.
- `home_rows.lua`: delete `HomeRows.keys`, and read `Settings.get("layout.rows")` at `:127`.
- `home.lua`: delete `self.page = 1`, `Home:turn` and the module comment's page sentences.
- `home_gestures.lua`: `if own_step == "page" then return true end`, drop the `BD` require, and update the module
  and `route` comments. Keep the `kopanda_home_page` zone and `is_page_swipe`: the zone is what stops a swipe paging
  the hidden file chooser, and `library_chrome.lua:805` uses the function.
- `home_sheet.lua`: delete the Edit page 2 row and its mention in the module comment.
- `edit_layout.lua`: delete `opts.key`, set `state.key = "layout.rows"` once, title `"Edit layout"`, and fix the
  module comment.
- `rows_edit.lua`: fix the two comments that name `layout.rows_2`.
- `menu.lua:268`: stop passing the dead `key`.
- `looks/frosted.lua:92`: fix the comment that says "page 2".
- `HOOKS.md:2375`: remove the deleted scenario's row.

Delete the `layout.rows_2` cases, keeping what they prove about `layout.rows`:

- `spec/unit/settings_spec.lua:249-265, :384-416, :472, :569`
- `spec/unit/edit_layout_spec.lua:727-787`
- `spec/unit/menu_spec.lua:115, :551-564`
- `spec/unit/home_sheet_spec.lua:132-188`
- `spec/unit/rows_edit_spec.lua:216-249`
- `spec/unit/schema_spec.lua:40` (the key count), `:97, :198, :221, :267`: a removed key shifts every hard-coded
  `keys[N]`, so look keys up by id here and at `launcher_entries_spec:204`
- `spec/unit/layout_spec.lua:721` (a whole page 2 test), `:791`
- `spec/unit/gesture_routing_spec.lua:1-3`, the header comment
- `spec/fixtures/studio/validator_cases.lua:117-130`
- `spec/fixtures/studio/settings_written.lua:86`, regenerated in Task 6

Don't change `schema.version`.

**Step 4: Run them**

Run: `bin/check --unit` filtered to its summary lines. The studio's tests fail until Task 6, which is expected, so
judge this step by `bin/check` on the named Lua specs above, then move on.

**Files for the commit:** combined with Task 6, since the gate only passes with both.

---

## Task 6: Remove page 2 from the studio and docs

**Files:**
- Modify: `studio/src/ui/App.tsx`, `studio/src/ui/ProfileScreen.tsx`, `studio/src/ui/settings/controls/RowsControl.tsx`,
  `studio/src/ui/layout/LayoutEditor.tsx`, `studio/src/core/rows-edit.ts` (comments), `studio/src/schema.json`,
  `AGENTS.md`
- Test: `studio/test/core/rows-edit.test.ts`, `studio/test/core/settings-written.test.ts`,
  `studio/test/server/layout-fit.test.ts`, `studio/test/server/settings.test.ts`, `studio/test/ui/layout-editor.test.tsx`,
  `studio/test/ui/settings-form.test.tsx`

**Step 1: Regenerate and see the studio fail**

```bash
npm --prefix studio run schema
npm --prefix studio run check
```

Expected: FAIL on `entryFor("layout.rows_2")` and the tests above.

**Step 2: Implement**

- `ProfileScreen.tsx`: remove the `"layout-2"` view, `PAGES` becomes the one layout entry, and simplify the branch
  at `:124`.
- `App.tsx:23, :30`: drop `layout-2` from the route and its comment.
- `RowsControl.tsx`: remove `layout.rows_2` from `VIEWS`.
- `LayoutEditor.tsx`, `rows-edit.ts`: fix the comments. The `key` parameters stay (see the design's Out of scope).
- Delete the page 2 tests, and in `settings-written.test.ts:35` drop the key.
- A stored `layout.rows_2` in the studio's file reader: add a `settings.test.ts` case that a file holding it still
  loads.

```bash
KOPANDA_UPDATE_GOLDENS=1 npm --prefix studio test -- test/core/settings-written.test.ts
```

`AGENTS.md:48`, replacing the two-pages line:

```markdown
- The home is one page, `layout.rows`; a west or east swipe on it does nothing. The Stats window (`stats_screen.lua`, the nav bar's Stats tab) flows rows of insight tiles onto pages turned by a swipe. `bin/preview` and the studio's preview pane render the home.
```

**Step 3: Run the gates**

Run: `bin/check --unit`
Expected: PASS. Then the lead runs `bin/check` once, the full gate, including the emulator layer.

**Files for the commit:** every file in Tasks 5 and 6.

---

## Manual check (owner)

1. In the emulator, open Stats from the nav bar in Diner, Editorial and Frosted.
2. Swipe through the pages, and check both ends do nothing.
3. Judge the month bars and spacing.
4. Tap the Home tab and confirm the home comes back. Confirm Authors still opens from the launcher.
5. Swipe west on the home and confirm nothing happens.
