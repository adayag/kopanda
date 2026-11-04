# Home cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A four-slot launcher that doesn't repeat the nav bar, a fixed home that keeps the quote, swapped swipes, launcher
slots that open any plugin's menu item, and a smaller settings menu.

**Architecture:** The home's rows become one table, `Layout.rows`, in place of the `layout.rows` setting, and layout
editing leaves the device and the studio. `Layout.arrange` drops the quote before anything else. The swipes change in
`home_gestures.lua` and `library_chrome.lua`. A new launcher kind, `plugin_menu`, reaches a plugin through
`addToMainMenu`.

**Tech Stack:** Lua on KOReader's LuaJIT with Busted; TypeScript, React and Vitest in `studio/`.

Design: `docs/plans/2026-11-03-home-cleanup-design.md`. About a day and a half, most of it moving specs.

---

## Before starting

- The stats window shipped in `bf402bb0`. Line numbers here were read from the tree of 2026-11-03 with that work
  uncommitted, so confirm each before editing.
- Work on `main`. Run every `bin/check` through a filter that drops KOReader's library-loading chatter and per-test
  lines. Each task's gate is `bin/check --unit`, plus the emulator specs it names. The lead runs the full `bin/check`
  once, in Task 9.
- Each task commits with `git add <specific files>`, with no AI attribution, after the owner's approval.
- Test seam: `Layout.rows` is a module field a spec may replace, as `Quote.sources` is today. A spec that replaces it
  keeps the original in `before_each` and restores it in `after_each`.
- Regenerating: `npm --prefix studio run schema` writes `studio/src/schema.json`.
  `KOPANDA_UPDATE_GOLDENS=1 npm --prefix studio test -- test/core/settings-written.test.ts` rewrites
  `spec/fixtures/studio/settings_written.lua`.

---

## Task 1: Swap the swipes

**Files:**
- Modify: `kopanda.koplugin/home_gestures.lua`, `kopanda.koplugin/library_chrome.lua`, `kopanda.koplugin/HOOKS.md`
- Test: `spec/unit/gesture_routing_spec.lua`, `spec/unit/library_gestures_spec.lua`, `spec/unit/shelf_gestures_spec.lua`,
  `spec/unit/goto_screen_spec.lua`, `spec/home_gestures.lua`, `spec/emulator/focused_home_spec.lua`,
  `spec/emulator/scenarios/2-scenario-focused-home.lua`

**Step 1: Write the failing tests**

- On the home, a swipe north from the bottom edge band, outside the side bands, opens quick settings, not
  `SettingsMenu.open`.
- With Focused on, a tap and a south swipe in the top menu zones open `SettingsMenu.open` with no group, on the home
  and on a chrome window.
- On a chrome window with a nav bar, a north swipe from the bottom edge band opens quick settings with the bar's `where`.
- On a chrome window with no nav bar, such as book status, it opens with the window's `screen`.
- In the reader, on `GotoScreen`, the same swipe does nothing: quick settings has its own door there, and this step
  needs a file manager, as the top edge does (`goto_screen_spec:399-400`).
- A north swipe that starts mid-screen, or inside a side band, does nothing new on either.
- With Focused off, the top zones still reach KOReader's menu.
- A hold in the top zones still calls `menu:onShowMenu`.
- `focused_home_spec`: the "top" step reports the settings menu on top. `SettingsMenu.open` emits no settled signal
  (`settings_menu.lua:51-70`), so rework the scenario to report the top widget after the tap instead of waiting for
  the sheet's signal.

**Step 2: Run them to verify they fail**

Run: `bin/check spec/unit/gesture_routing_spec.lua spec/unit/library_gestures_spec.lua spec/unit/goto_screen_spec.lua`
Expected: FAIL, with the sheet and the menu swapped.

**Step 3: Implement**

In `home_gestures.lua`, add the shared step, keeping `is_swipe_up_from_bottom` local:

```lua
-- The bottom-edge step, shared by the home and the chrome windows: with a file manager up, a swipe up from the
-- bottom edge opens the quick-settings sheet over where (a nav bar's where). Whether one consumed ges.
function HomeGestures.bottom_swipe(ges, where)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if not (FileManager and FileManager.instance) or not is_swipe_up_from_bottom(ges) then
        return false
    end
    NavBar.open_quick_settings(where, "the bottom edge")
    return true
end
```

Rename the zone's step from `"settings"` to `"quick"`, and in `route`:

```lua
    if own_step == "quick" and HomeGestures.bottom_swipe(ges, "home") then
        return true
    end
```

In `focused_top`, replace the `NavBar.open_quick_settings(where, "the top edge")` branch:

```lua
        SettingsMenu.open()
        return true
```

`where` then has no reader: remove the parameter, its two callers' argument and the words in its comment.

In `Window:routeGesture` (`library_chrome.lua`), before the page swipe step:

```lua
    if own_step == "swipe" and HomeGestures.bottom_swipe(ges, self.nav and self.nav.where or self.screen) then
        return true
    end
```

Update both modules' comments, and `HOOKS.md` at `:193` and `:518`.

**Step 4: Run the tests to verify they pass**

Run: `bin/check spec/unit/gesture_routing_spec.lua spec/unit/hold_routing_spec.lua spec/unit/library_gestures_spec.lua spec/unit/shelf_gestures_spec.lua spec/unit/goto_screen_spec.lua spec/emulator/focused_home_spec.lua`
Expected: PASS

**Step 5: Gate and commit**

Run: `bin/check --unit`

```bash
git commit -m "gestures: swipe up opens quick settings and swipe down full settings, on the home and every chrome window"
```

---

## Task 2: Four launcher slots

**Files:**
- Modify: `kopanda.koplugin/schema.lua`, `kopanda.koplugin/looks/base.lua:545`, `kopanda.koplugin/layout.lua`,
  `kopanda.koplugin/nav_bar.lua`, `kopanda.koplugin/widgets/launcher.lua`, `kopanda.koplugin/launcher_manage.lua:353`,
  `studio/src/ui/launcher/AddEntry.tsx:116`, `studio/src/schema.json`, `spec/fixtures/studio/settings_written.lua`
- Test: `spec/unit/launcher_widget_spec.lua`, `spec/unit/schema_spec.lua`, `spec/unit/launcher_entries_spec.lua`,
  `spec/unit/entry_picker_spec.lua`, `spec/unit/settings_spec.lua`, `spec/unit/entries_edit_spec.lua:51, :126, :141`,
  `spec/unit/launcher_manage_spec.lua:128, :273`, `spec/unit/layout_spec.lua:647-655, :692, :781`,
  `spec/fixtures/studio/validator_cases.lua:183-210`, `spec/fixtures/studio/entries_edit_cases.lua:154, :199, :220`,
  `spec/emulator/scenarios/2-scenario-screens.lua:26-33`, `spec/emulator/scenarios/2-scenario-home-fixture.lua:15, :110`,
  `studio/test/core/settings-written.test.ts:38-54`, `studio/test/ui/launcher-editor.test.tsx:104, :114, :128, :304, :337, :403, :412`

**Step 1: Write the failing tests**

- Schema: `max_entries` is 4; the default reads Series, Authors, Subjects, Favorites.
- Settings: a stored list of five reads as the default; a stored list of four reads as stored.
- Launcher widget: four entries sit in one row in Diner and Frosted, and in two rows of two in Editorial.
- Launcher widget: at Extra large a label is set at Large's size, and at Large at its own.
- Launcher widget: it measures above 0 in Diner and in Frosted.
- Launcher widget: in Frosted at Extra large, a tile holds its content: the icon's bottom doesn't pass the label's top.
- Launcher widget: in Diner at Small, where the content is well under `tile_height`, the tile stays `tile_height`.
- Launcher management and the studio's Add screen: the note names the fifth entry.

**Step 2: Run them to verify they fail**

Run: `bin/check spec/unit/launcher_widget_spec.lua spec/unit/schema_spec.lua spec/unit/launcher_manage_spec.lua`
Expected: FAIL

**Step 3: Implement**

`schema.lua`, in `launcher.entries`:

```lua
            max_entries = 4,
            default = {
                { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" },
                { kind = "kopanda", target = "subjects" },
                { kind = "koreader", target = "favorites" },
            },
```

`looks/base.lua`, in `launcher`: `columns = 4`. Editorial keeps its own `columns = 2`.

`launcher_manage.lua:353` and `AddEntry.tsx:116`: "The fifth entry and beyond go into a folder."

Move `label_size` from `nav_bar.lua:45-47` to `layout.lua` as `Layout.label_size(text_size)` and call it from
`NavBar`. In `widgets/launcher.lua`, set labels through a shallow copy of `ctx` with
`text_size = Layout.label_size(ctx.text_size)`, built once in `make` and passed to `text_block`. Icons keep `ctx`.

In `make`, grow a tile to hold what's in it. `tokens.icon_gap` is false in a box look (`looks/base.lua`: the icon above
the label), and the box branch places the icon at `outline + pad_y` and the text so it ends `outline + pad_y` above
the tile's foot:

```lua
    if box then
        entry_h = math.max(scale(tokens.tile_height), 2 * (outline + pad_y) + icon_px + block_h)
```

**Step 4: Move the data**

- `settings-written.test.ts`: cut the data set to four top-level entries that differ from the default, moving kinds
  into its folder so each stays covered. Edit it by hand; regenerating alone can't.
- `validator_cases.lua`: the default at four, and the over-limit case at five.
- `entries_edit_cases.lua`, `entries_edit_spec`, `launcher_manage_spec` and its board, `layout_spec`'s `CONTENT.empty`:
  four entries, with the same point.
- `launcher_entries_spec:145, :202-204`, `entry_picker_spec:177-195`, `launcher_widget_spec`'s `VIEWS` and `LABELS`:
  the new default.
- `2-scenario-screens.lua`, which errors on a refused list, and `2-scenario-home-fixture.lua`: four entries, keeping a
  "plugin missing" entry in the empty capture.

Regenerate `schema.json` and the fixture.

**Step 5: Run the tests to verify they pass**

Run: `npm --prefix studio run check`, then `bin/check spec/unit/launcher_widget_spec.lua spec/unit/schema_spec.lua spec/unit/launcher_entries_spec.lua spec/unit/entry_picker_spec.lua spec/unit/entries_edit_spec.lua spec/unit/launcher_manage_spec.lua spec/unit/layout_spec.lua spec/unit/studio_validators_spec.lua spec/unit/studio_entries_edit_spec.lua spec/unit/studio_settings_file_spec.lua spec/emulator/screens_capture_spec.lua spec/emulator/home_capture_spec.lua`
Expected: PASS

**Step 6: Look at it, gate and commit**

Run `bin/preview` in all three looks at each text size, on both screen sizes. Check the fourth tile, which takes no
accent colour (`widgets/launcher.lua`, `i <= 3`), and name what you see to the owner. Then `bin/check --unit`.

```bash
git commit -m "launcher: four slots of what the nav bar doesn't hold, one row in Diner and Frosted, labels a size down at Extra large"
```

---

## Task 3: The quote drops first

Adds the rows table and the rule. Nothing reads the table yet: the switch comes in Task 4, with the specs that store
`layout.rows`.

**Files:**
- Modify: `kopanda.koplugin/layout.lua`
- Test: `spec/unit/layout_spec.lua`

**Step 1: Write the failing tests**

With stub heights through `Layout.arrange`:

- Where all four rows fit, nothing drops.
- One pixel too tall, the quote's row drops, the launcher stays, and the rows below the quote move up.
- Too tall even without the quote, the quote and then the last row drop.
- Rows 1 and 2 alone overflow: `dropped` lists each row once, and each drop is logged once.
- `arranged.heights` still holds the quote's measured height after it drops.

Update `layout_spec`'s `{3}` expectations (`:316`, the landscape case), which become `{2}` where the stub's quote is
row 2.

**Step 2: Run them to verify they fail**

Run: `bin/check spec/unit/layout_spec.lua`
Expected: FAIL

**Step 3: Implement**

In `layout.lua`:

```lua
-- The home's rows, top to bottom; each row's slots, left to right, take its width by share.
Layout.rows = {
    { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
    { { widget = "featured", share = 1 } },
    { { widget = "quote", share = 1 } },
    { { widget = "launcher", share = 1 } },
}
```

In `arrange`, placement works on its own copy of the heights, so `arranged.heights` stays as measured. The quote leaves
only when something would drop:

```lua
    local first_gap = header.rule_color and 0 or nil
    local spans = { unpack(heights) }
    local function fit(placement)
        return placement(spans, above, home.margin, home.row_gap, home.free_space, footer_height(home), first_gap)
    end
    local ys, dropped = fit(place)
    local quote_row
    if #dropped > 0 then
        for i, row in ipairs(measured) do
            if row.slots[1] and row.slots[1].widget == "quote" then
                quote_row = i
                measured[i] = { slots = {}, h = 0, content_top = 0, content_h = 0 }
                spans[i] = 0
            end
        end
    end
    ys, dropped = fit(placer)
    -- The quote's row sits among the kept rows, so it comes before any row still dropped.
    if quote_row and not (dropped[1] and dropped[1] <= quote_row) then
        table.insert(dropped, 1, quote_row)
        if placer == Layout.place then
            logger.warn("KoPanda: the quote doesn't fit the screen and is left out")
        end
    end
```

A row of height 0 takes no gap (`place`, the `if h > 0` branch). Update the comment above `arrange`.

**Step 4: Run the tests to verify they pass**

Run: `bin/check spec/unit/layout_spec.lua`
Expected: PASS

**Step 5: Gate and commit**

Run: `bin/check --unit`

```bash
git commit -m "layout: the home's rows as one table, and the quote goes before any other row on a screen too short for them"
```

---

## Task 4: Remove layout editing, on the device and in the studio

The home's switch to `Layout.rows`, the `rows` type leaving `schema.json`, and the specs that store rows all change
together, so the plugin and the studio share one commit and the gate stays green.

**Files:**
- Delete: `kopanda.koplugin/edit_layout.lua`, `kopanda.koplugin/rows_edit.lua`, `kopanda.koplugin/icons/layout.svg`,
  the `layout` svg under `icons/phosphor-bold/` if there is one, `bin/layout-fit`, `bin/layout-fit.lua`,
  `spec/unit/edit_layout_spec.lua`, `spec/unit/rows_edit_spec.lua`, `spec/unit/studio_rows_edit_spec.lua`,
  `spec/unit/layout_fit_spec.lua`, `spec/fixtures/studio/rows_edit_cases.lua`, `studio/src/core/rows-edit.ts`,
  `studio/src/ui/layout/LayoutEditor.tsx`, `studio/src/ui/settings/controls/RowsControl.tsx`,
  `studio/src/server/layout-fit.ts`, `studio/src/server/routes/layout-fit.ts`, `studio/test/core/rows-edit.test.ts`,
  `studio/test/ui/layout-editor.test.tsx`, `studio/test/server/layout-fit.test.ts`, `studio/test/fixtures/layout-fit/`
- Modify: `kopanda.koplugin/schema.lua`, `settings.lua`, `menu.lua`, `home_sheet.lua`, `home_rows.lua`, `home.lua`,
  `main.lua`, `layout.lua`, `editor.lua`, `widgets.lua`, `icons.lua`, `looks/base.lua`, `HOOKS.md`,
  `studio/src/schema.json`, `studio/src/schema.ts:43-51`, `studio/src/catalog.json`, `studio/src/core/validators.ts`,
  `studio/src/ui/App.tsx:30`, `studio/src/ui/ProfileList.tsx:12`, `studio/src/ui/ProfileScreen.tsx`,
  `studio/src/ui/api.ts`, `studio/src/ui/styles.css:309+`, `studio/src/ui/settings/SettingsForm.tsx`,
  `studio/src/server/app.ts`, `studio/src/server/routes/profiles.ts`, `studio/src/server/settings-file.ts`
- Test: every spec listed in Step 4

**Step 1: Write the failing tests**

- `HomeRows.build` builds `Layout.rows` with a different `layout.rows` stored in the settings file.
- `Settings.get("layout.rows")` is refused as an unknown key, and `Settings.set` of it is refused.
- A stored `layout.rows` leaves the other settings readable.
- `spec/unit/home_sheet_spec.lua`: the sheet has no Edit layout row.
- `spec/unit/menu_spec.lua`: no row has a `layout.rows` key.
- `studio/test/server/settings.test.ts`: a settings file holding `layout.rows` still loads, and the studio's form shows
  no layout control.

**Step 2: Run them to verify they fail**

Run: `bin/check spec/unit/home_layout_spec.lua spec/unit/settings_spec.lua spec/unit/home_sheet_spec.lua spec/unit/menu_spec.lua`
Expected: FAIL

**Step 3: Remove from the plugin**

- `home_rows.lua:124`: `Layout.arrange(Layout.rows, ctx)`, and its opening comment.
- `schema.lua`: the `layout.rows` key.
- `settings.lua`: `Settings.validators.rows`, `is_slot`, and the `defaults_by_text_size` handling in `Settings.get`.
- `menu.lua`: `BUILDERS.rows`, and the comment at `:77`. `open_screen` stays for `launcher`.
- `home_sheet.lua`: `EditLayout`, `PaintClock` if unused, the Edit layout row, and its opening comment.
- `main.lua`: `require("edit_layout")`, `require("rows_edit")`.
- `layout.lua`: `Layout.overflow`, `Layout.fits`, and the `placer` parameter, so `arrange` calls `Layout.place` once
  and logs the quote unconditionally. `Layout.arrange` keeps its name. Nothing but `edit_layout` and `bin/layout-fit`
  reads the two in the plugin.
- `icons.lua`: the `layout` icon at `:59`, and "edit layout" out of the `used_in` lists of `close`, `chevron_up` and
  `chevron_down`. `spec/unit/icons_spec.lua:88`, then `npm run catalog` in `studio/`.
- `editor.lua`, `home.lua:1`, `widgets.lua:1`, `looks/base.lua`: mentions of edit layout, and any `editor` token only
  `edit_layout.lua` read. Grep each `look.editor.*` token: `launcher_manage.lua` reads most.
- `HOOKS.md`: the Edit layout sections (`:1222` and the note at `:1778`).

**Step 4: Move the specs**

Replace `Settings.set("layout.rows", rows)` with `Layout.rows = rows`, under the seam in Before starting, in:
`spec/home_gestures.lua:47`, `gesture_routing_spec:630`, `failsafe_spec:437`, `home_layout_spec:104`,
`home_plates_spec:114`, `launcher_widget_spec:672, :697, :718, :745`, `prebuild_spec:62, :121`.

Replace schema lookups of the default with `Layout.rows` in: `layout_spec:675, :734`, `failsafe_spec:267, :586`,
`date_clock_spec:225`, `home_layout_spec:148`, `quote_spec:26`. `settings_spec`'s rows cases go with the validator, and
`schema_spec:84-95, :234-245` with the key.

Point `layout_spec`'s every-quote-every-day test at `Layout.rows`, at every text size. It then also demands the fixed
home on 1236×1648 and on the empty content in every look, sizes this plan hasn't measured, so read its failures before
changing any token. In `layout_spec`, replace `Layout.fits` and `Layout.overflow` with `#Layout.arrange(...).dropped`,
keeping each case's point; the "logging nothing" case goes with the unlogged path.

Remove edit layout from `editor_spec`, `failsafe_spec`, `sheet_spec`, `paint_clock_spec`,
`spec/emulator/screens_capture_spec.lua` and `spec/emulator/scenarios/2-scenario-screens.lua`. Remove the `rows` cases
from `spec/fixtures/studio/validator_cases.lua`.

**Step 5: Remove from the studio**

Delete the files above, then remove from the Modify list every import and use `tsc` names. `tsc` won't catch the CSS,
`App.tsx`'s route or string-keyed tests, so also update `styles.css:309+`, `studio/test/ui/settings-form.test.tsx:205-225`,
`studio/test/server/settings.test.ts:108-137`, `studio/test/ui/preview.test.tsx:203` and
`studio/test/core/settings-written.test.ts:18-31`. Regenerate `schema.json` and the fixture.

**Step 6: Run the tests to verify they pass**

Run: `npm --prefix studio run check`, then `bin/check spec/unit/layout_spec.lua spec/unit/settings_spec.lua spec/unit/menu_spec.lua spec/unit/home_layout_spec.lua spec/unit/icons_spec.lua spec/unit/studio_catalog_spec.lua spec/unit/studio_settings_file_spec.lua`
Expected: PASS

**Step 7: Gate and commit**

Run: `bin/check --unit`, `bin/check spec/emulator/screens_capture_spec.lua spec/emulator/home_capture_spec.lua spec/emulator/paint_budget_spec.lua`.
Then run `grep -rniE "edit.?layout|rows.?edit|layout.fit|layout\.rows|Layout\.(fits|overflow)" kopanda.koplugin spec studio/src studio/test bin AGENTS.md README.md`;
only the `layout.rows` tests of Step 1, and the docs Task 9 changes, may remain.

```bash
git commit -m "layout: remove layout editing from the device and the studio; the home draws Layout.rows"
```

---

## Task 5: Remove Quote source, Show reading stats and the stats line

`widgets/weather.lua` stays, reduced: the header draws through it (`widgets/date.lua:12, :56`, `widgets/clock.lua:13, :38`).

**Files:**
- Delete: `kopanda.koplugin/widgets/stats.lua`
- Modify: `kopanda.koplugin/schema.lua`, `widgets.lua`, `widgets/quote.lua`, `widgets/weather.lua`, `reading_stats.lua`,
  `main.lua`, `looks/*.lua`, `icons.lua`, `studio/src/schema.json`, `spec/fixtures/studio/settings_written.lua`
- Test: `spec/unit/quote_spec.lua`, `spec/unit/hold_routing_spec.lua`, `spec/unit/menu_spec.lua`,
  `spec/unit/schema_spec.lua`, `spec/unit/book_sheet_spec.lua:1371, :1407`, `spec/unit/prebuild_spec.lua`,
  `spec/unit/reading_stats_spec.lua:244, :1213-1219`, `spec/unit/settings_spec.lua:430-456`,
  `spec/unit/weather_spec.lua:710-756`, `spec/unit/date_clock_spec.lua:318`,
  `spec/unit/gesture_routing_spec.lua:100-113, :630-634`, `spec/unit/home_plates_spec.lua:114-120`,
  `spec/unit/studio_settings_file_spec.lua:54, :62`, `spec/home_gestures.lua:43-49`,
  `spec/fixtures/studio/validator_cases.lua:26-36`, `studio/test/schema.test.ts:19, :30`,
  `studio/test/ui/settings-form.test.tsx:165, :260-268`, `studio/test/server/settings.test.ts:323-328`,
  `studio/test/core/settings-written.test.ts:8, :36-37, :72-79`

**Step 1: Write the failing tests**

- `quote_spec`: the widget draws the day's entry with no setting; a spec's own list through `Quote.entries` is drawn.
- `hold_routing_spec`: a hold on the quote opens the home's sheet and no settings menu.
- `schema_spec`: no `quote.source`, no `stats.show`.
- `Widgets.get("weather")` and `Widgets.get("stats")` are nil, and the header still draws the weather line.

**Step 2: Run them to verify they fail**

Run: `bin/check spec/unit/quote_spec.lua spec/unit/hold_routing_spec.lua spec/unit/schema_spec.lua spec/unit/date_clock_spec.lua`
Expected: FAIL

**Step 3: Implement**

`widgets/quote.lua`, removing its `local Settings` require:

```lua
local Quote = {
    id = "quote",
}

-- The entry list; a spec puts a list of its own here.
Quote.entries = require("quotes")

-- A hold opens the home's sheet: the quote has no settings.
function Quote.hold()
    return false
end
```

Replace `entries()`'s uses with `Quote.entries`.

`widgets/weather.lua`: keep `WeatherWidget.line` and `header_line`. Remove `id`, `settings_prefix`, `make`, `height`,
`build`, `tap` and whatever only they require, and reword its opening comment: the header's weather line. `main.lua`
keeps `require("widgets/weather")`.

`reading_stats.lua`: remove `ReadingStats.read` and what only it reads. `widgets/stats.lua:123` is its one caller.

`schema.lua`: remove both keys. `widgets.lua`: remove `stats` and `weather`. `main.lua`: remove
`require("widgets/stats")`. Remove tokens only these read, such as `type.weather` if `line`'s callers don't pass it
(`spec/unit/looks_spec.lua` shows a path that's gone), and update `icons.lua`'s `used_in` where it names them.

Move the specs that use `stats` or `weather` as a sample widget to another widget, keeping each case's point, including
`store_weather_row` in `spec/home_gestures.lua`, which the gesture and hold routing specs share. Move `weather_spec`'s
widget cases to the header line. Remove `reading_stats_spec`'s stats widget and `ReadingStats.read` cases. Regenerate
`schema.json` and the fixture.

**Step 4: Run the tests to verify they pass**

Run: `npm --prefix studio run check`, then `bin/check spec/unit/quote_spec.lua spec/unit/hold_routing_spec.lua spec/unit/schema_spec.lua spec/unit/looks_spec.lua spec/unit/menu_spec.lua spec/unit/reading_stats_spec.lua spec/unit/weather_spec.lua spec/unit/main_requires_spec.lua`
Expected: PASS

**Step 5: Gate and commit**

Run: `bin/check --unit`

```bash
git commit -m "settings: remove Quote source and Show reading stats, and the home's stats line"
```

---

## Task 6: Settings menu rows

**Files:**
- Modify: `kopanda.koplugin/menu.lua`, `kopanda.koplugin/settings_menu.lua`, `kopanda.koplugin/HOOKS.md`
- Test: `spec/unit/menu_spec.lua:316-359`, `spec/unit/settings_menu_spec.lua`

**Step 1: Write the failing tests**

- Wallpaper's row shows in Frosted and not in Diner or Editorial. `menu_spec:316-359` needs a Frosted look set.
- The settings menu's last section reads Check for KoPanda update, KOReader menu, then Apps when Storefront is there.
- Tapping KOReader menu calls the file manager's `menu:onShowMenu` after the settings menu closes.
- With no file manager, the KOReader menu row is left out.
- `SettingsMenu.open("featured")`, a group, has no KOReader menu row.

**Step 2: Run them to verify they fail**

Run: `bin/check spec/unit/menu_spec.lua spec/unit/settings_menu_spec.lua`
Expected: FAIL

**Step 3: Implement**

`menu.lua`, in `SchemaMenu.items`, leave the wallpaper out where the look draws none. `Looks` is required at call
time if it reaches this module:

```lua
-- Whether entry has a row in the active look: the wallpaper's only where the look draws one (looks/base.lua:124).
local function shown(entry)
    return entry.id ~= "wallpaper.file" or require("looks").active().wallpaper.enabled
end
```

`settings_menu.lua`, in `updates`, after the Check for KoPanda update row:

```lua
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if FileManager and FileManager.instance and FileManager.instance.menu then
        items[#items + 1] = {
            text = "KOReader menu",
            callback = Guards.after_menu("Settings › KOReader menu", function()
                FileManager.instance.menu:onShowMenu()
            end),
        }
    end
```

Add `onShowMenu`'s use here to `HOOKS.md`.

**Step 4: Run the tests to verify they pass**

Run: `bin/check spec/unit/menu_spec.lua spec/unit/settings_menu_spec.lua`
Expected: PASS

**Step 5: Gate and commit**

Run: `bin/check --unit`

```bash
git commit -m "settings menu: Wallpaper only in a look that draws one, and a row for KOReader's full menu"
```

---

## Task 7: Tools › KoPanda without the Studio submenu

The split: `release_source.lua:6`, `push_notice.lua` and the refused path (`main.lua:491-496`) keep `push_apply`,
`push_bundle` and `push_pull`, and share nothing deleted here. `PushPull.pull`'s address path stays, because
`push_spec` uses it. `PushPull.fetch_profiles` and `Guards.enabled_shell_names` lose their only production callers,
so they go.

**Files:**
- Create: `kopanda.koplugin/update_menu.lua`, `spec/unit/update_menu_spec.lua`
- Delete: `kopanda.koplugin/studio_menu.lua`, `spec/unit/studio_menu_spec.lua`
- Modify: `kopanda.koplugin/main.lua:26, :488-496, :556`, `kopanda.koplugin/settings_menu.lua`,
  `kopanda.koplugin/push_pull.lua:159`, `kopanda.koplugin/guards.lua:58`, `kopanda.koplugin/HOOKS.md:245-248, :313-344, :381, :431, :710, :1215`
- Test: `spec/unit/settings_menu_spec.lua`, `spec/unit/push_pull_spec.lua:703`, `spec/unit/guards_spec.lua:213-236`,
  `spec/emulator/scenarios/2-scenario-push-pull.lua:49`

**Step 1: Write the failing tests**

Create `update_menu_spec.lua` from `studio_menu_spec.lua`: keep every Check for update case (`:423-544`) and drop the
Address, Profile and Pull cases. Add:

- `Tools › KoPanda` holds Check for update and Swatches, and no Studio row, normally and when `self.refused`.
- Check for update from Tools runs `check_for_update` with the plugin's path.
- The settings menu's row still runs it.

**Step 2: Run them to verify they fail**

Run: `bin/check spec/unit/update_menu_spec.lua`
Expected: FAIL, with no `update_menu` module.

**Step 3: Implement**

Create `update_menu.lua` with `pull_behind_note`, the restart offer and `check_for_update` moved from `studio_menu.lua`,
naming its Restart guard "Tools › KoPanda › Check for update › Restart", plus:

```lua
local CHECK = "Tools › KoPanda › Check for update"

-- The Check for update row for the plugin instance plugin, whose path is its folder
-- (frontend/pluginloader.lua:248).
function UpdateMenu.item(plugin)
    return {
        text = "Check for update",
        callback = Guards.after_menu(CHECK, function()
            UpdateMenu.check_for_update(plugin, CHECK)
        end),
    }
end
```

Open it with a comment naming what it is. Delete `edit_address`, `choose_profile`, `pull` and the `studio_address` and
`studio_profile` constants with `studio_menu.lua`. In `main.lua`, swap the require and the `studio` local, and reword
the comment at `:488`: the row sits in both menus, so a device where KoPanda refused to start can still take a release.
Swap `StudioMenu` in `settings_menu.lua`.

Remove `PushPull.fetch_profiles` and its `push_pull_spec` cases. Remove `Guards.enabled_shell_names` and its
`guards_spec` cases, and have `2-scenario-push-pull.lua:49` pass its own list. Update `HOOKS.md` at the lines above.

Leave `studio/src/server/routes/push.ts` and `studio/src/ui/PushStatus.tsx:64` alone: deleting the studio is out of
scope. Tell the owner both are now unreached from the device, and that with Pull gone, nothing disables another shell
on a device where KoPanda was refused.

**Step 4: Run the tests to verify they pass**

Run: `bin/check spec/unit/update_menu_spec.lua spec/unit/settings_menu_spec.lua spec/unit/main_requires_spec.lua spec/unit/push_pull_spec.lua spec/unit/push_spec.lua spec/unit/guards_spec.lua`
Expected: PASS

**Step 5: Gate and commit**

Run: `bin/check --unit`

```bash
git commit -m "tools menu: Check for update directly under KoPanda, and the Studio submenu gone"
```

---

## Task 8: Launcher slots for plugin menu items

**Files:**
- Modify: `kopanda.koplugin/launcher_entries.lua`, `settings.lua:85`, `schema.lua`, `entries_edit.lua:85-91`,
  `entry_picker.lua`, `HOOKS.md`, `studio/src/schema.ts:12-34`, `studio/src/core/validators.ts:35`,
  `studio/src/core/entries-edit.ts:95, :120`, `spec/fixtures/studio/settings_written.lua`
- Test: `spec/unit/launcher_entries_spec.lua`, `spec/unit/entry_picker_spec.lua`, `spec/unit/settings_spec.lua`,
  `spec/unit/entries_edit_spec.lua`, `spec/unit/launcher_manage_spec.lua`, `spec/fixtures/studio/validator_cases.lua`,
  `spec/fixtures/studio/entries_edit_cases.lua`, `studio/test/core/entries-edit.test.ts`,
  `studio/test/core/settings-written.test.ts`

**Step 1: Write the failing tests**

Use a stub plugin on `FileManager.instance`, under a name `isPluginLoaded` answers for, whose `addToMainMenu` adds a
`stub` item with a `text` and a `callback`.

- `{ kind = "plugin_menu", plugin = "stub", item = "stub", label = "Stub", icon = "action" }` validates, and a missing
  field doesn't, on both sides, through `validator_cases.lua`.
- It resolves to ready, with its own label and icon.
- A plugin that isn't loaded resolves to unavailable, "plugin missing", and a tap shows the existing note.
- `resolve` doesn't call `addToMainMenu`, so a home build runs no plugin code.
- A tap runs the callback.
- A tap on an item that's gone, or one with no callback, shows a note. A callback that raises is logged and shows a
  note, and the home stays up.
- `EntriesEdit.kind_line` reads "Plugin · stub", and launcher management opens, shows and removes the entry.
- The studio's `EntryRow` shows its label and icon.
- Picker: choosing a plugin lists its callback items by text and an action row; choosing an item asks for a label and
  hands `on_entry` the entry; an item with only a submenu, or with `keep_menu_open`, isn't offered; a plugin with no
  `addToMainMenu`, or one whose `addToMainMenu` raises, goes straight to the action tree.
- The settings round trip keeps a `plugin_menu` entry.

**Step 2: Run them to verify they fail**

Run: `bin/check spec/unit/launcher_entries_spec.lua spec/unit/entry_picker_spec.lua spec/unit/entries_edit_spec.lua`
Expected: FAIL

**Step 3: Implement the entry**

`settings.lua`, in `ENTRY_FIELDS`:

```lua
    plugin_menu = { "kind", "plugin", "item", "label", "icon" },
```

`entries_edit.lua`, in `KINDS`:

```lua
    plugin_menu = { name = "Plugin", detail = "plugin" },
```

`launcher_entries.lua`, moving `file_manager` above `LauncherEntries.available`:

```lua
-- The plugin's instance on the file manager (frontend/apps/filemanager/filemanager.lua:424), or nil.
local function plugin_instance(name)
    local fm = file_manager()
    local plugin = fm and require("pluginloader"):isPluginLoaded(name) and fm[name]
    return plugin and plugin.addToMainMenu and plugin or nil
end

-- The plugin's main-menu items, as FileManagerMenu builds them (filemanagermenu.lua:851-852), or nil.
function LauncherEntries.menu_items(name)
    local plugin = plugin_instance(name)
    if not plugin then
        return nil
    end
    local items = {}
    plugin:addToMainMenu(items)
    return items
end
```

In `available`:

```lua
    elseif kind == "plugin_menu" then
        if not plugin_instance(entry.plugin) then
            return false, "plugin missing"
        end
```

In `run`, after the availability check:

```lua
    if kind == "plugin_menu" then
        local ok, err = pcall(function()
            local item = LauncherEntries.menu_items(entry.plugin)[entry.item]
            assert(item and item.callback, "no such menu item")
            item.callback()
        end)
        if not ok then
            logger.err("KoPanda: the launcher could not open", entry.plugin, err)
            Helpers.note(T("%1 couldn't open.", label_of(entry)))
        end
        return
    end
```

`schema.lua`: name the kind in `launcher.entries`' comment. `HOOKS.md`: add `registerModule`'s name and
`addToMainMenu`, with their `file:line`.

**Step 4: Implement the picker**

In `entry_picker.lua`'s `plugin` picker, the row's `run` becomes:

```lua
                    run = function()
                        local items = menu_rows(pick, name)
                        if #items == 0 then
                            action_row(pick, name)
                            return
                        end
                        items[#items + 1] = { label = "Other action", run = function()
                            action_row(pick, name)
                        end }
                        sheet(pick, ctx, plugin.fullname or name, items)
                    end,
```

with `action_row` holding today's `action_tree` call. `menu_rows` reads `LauncherEntries.menu_items` through its own
`pcall`, not `guard`, which returns nothing: a failure is logged and gives `{}`. It lists each item with a `callback`,
no `keep_menu_open` and a string `text`, or a `text_func` read through `pcall`, sorted by text. Each row calls
`ask_label` with the item's text, then:

```lua
pick.on_entry({ kind = "plugin_menu", plugin = name, item = id, label = label, icon = "action" })
```

`launcher_entries` is required at call time, as the other pickers do.

**Step 5: Implement the studio side**

`studio/src/schema.ts`, beside `Plugin`, and added to `FolderEntry`'s union:

```ts
const PluginMenu = z.strictObject({
  kind: z.literal("plugin_menu"),
  plugin: z.string(),
  item: z.string(),
  label: z.string(),
  icon: z.string(),
});
```

`validators.ts:35`:

```ts
  ["plugin_menu", ["kind", "plugin", "item", "label", "icon"]],
```

`entries-edit.ts`: `kindLine` gets `Plugin · ${entry.plugin}` for the kind, and the own-label check and `hasIcon` take
it. Add a `plugin_menu` entry to `settings-written.test.ts`'s data set and regenerate the fixture.

**Step 6: Run the tests to verify they pass**

Run: `npm --prefix studio run check`, then `bin/check spec/unit/launcher_entries_spec.lua spec/unit/entry_picker_spec.lua spec/unit/entries_edit_spec.lua spec/unit/launcher_manage_spec.lua spec/unit/studio_validators_spec.lua spec/unit/studio_entries_edit_spec.lua spec/unit/studio_settings_file_spec.lua`
Expected: PASS

**Step 7: Gate and commit**

Run: `bin/check --unit`

```bash
git commit -m "launcher: a slot can open any plugin's main-menu item, for plugins with no Dispatcher action"
```

---

## Task 9: Docs and the full gate

**Files:**
- Modify: `AGENTS.md`, `README.md`, `kopanda.koplugin/HOOKS.md`

**Step 1: Update the docs**

- `AGENTS.md`: remove the `bin/layout-fit` command. The Deployed line names Tools › KoPanda › Check for update and says
  releases are the only way the plugin reaches the device, not the studio. The home's convention line (`:48`) says its
  rows are `Layout.rows`. The Runtime state line drops `studio_address` and `studio_profile`.
- `README.md`: remove `layout-fit` at `:16`, name the new path at `:21`, stop saying the studio pushes at `:14`, and
  remove the Address, Profile and Pull instructions at `:37`.
- `HOOKS.md`: `Tools › KoPanda › Studio › Check for update` at `:380` becomes the new path.

Then run `grep -n "Studio ›\|Pull\|layout-fit\|layout\.rows" README.md AGENTS.md kopanda.koplugin/HOOKS.md` and read
every line it returns.

**Step 2: Run the full gate**

Run: `bin/check`
Expected: every stage passes, the paint budget included. `paint_budget_spec` never sets a text size, so the Extra large
home has no budget: add one case for it, as this is the home the work changed most.

**Step 3: Show the owner**

- Open `bin/preview` renders for each look at Extra large with the longest quote. A render reads the plugin's own
  quote list, so copy the tree to the scratchpad and cut `quotes.lua` to that entry there. Don't edit it in place.
- Ask the owner to install Rakuyomi on the Kindle, add it to a slot and tap it. The emulator can't prove this.

**Step 4: Commit**

```bash
git add AGENTS.md README.md kopanda.koplugin/HOOKS.md spec/emulator/paint_budget_spec.lua
git commit -m "docs: the fixed home, the new update path and no layout-fit"
```

**Step 5: Stop for the owner**

Pushing to `main` cuts a release. Ask before pushing.
