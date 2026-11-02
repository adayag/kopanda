# Focused mode, release 1: implementation plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** With `focused.on` (default on), a top tap, a bottom tap or swipe, or a tap on the status bar in a book opens a
KoPanda panel (Home, Text size, Contrast, Light, Night, Bookmark, Go to), a hold on its header opens KOReader's full
reader menu, and KoPanda's settings gain an Updates section with Storefront.

**Architecture:** A pure model (`focused_panel.lua`: what the panel shows for a ReaderUI, and each control's action
through KOReader's own events) under a sheet body built like quick settings'. The ± controls share one drawing module
lifted from quick settings (`steppers.lua`). The reader hooks (`focused_hooks.lua`) wrap six ReaderMenu, ReaderConfig
and ReaderFooter handlers once per process. With the mode off, or on any failure, they call the original handler.

**Tech stack:** Lua on KOReader's LuaJIT. Busted unit specs under a fresh `KO_HOME`. Emulator scenario patches with
the capture driver.

**Design:** `docs/plans/2026-11-02-focused-mode-design.md`. Its decisions table is the spec. This plan doesn't
repeat it.

**Process:** TDD for every task: write the test, run it and see it fail, implement, see it pass. Nothing is committed
during the tasks. The lead runs `bin/check` once at the end and presents the release to the owner before any commit.
Read `bin/check` output through a filter that drops KOReader's library-loading chatter (`grep -v "ffi.load"`).
Gate per task: `bin/check --unit`, plus `bin/check spec/emulator/<name>_spec.lua` for the emulator specs a task
names.

---

### Task 1: A sheet over a book (the design's first risk)

**Files:**
- Create: `spec/emulator/scenarios/2-scenario-focused-panel.lua`
- Create: `spec/emulator/focused_panel_spec.lua`

The scenario copies `2-scenario-book-close.lua`'s shape: it opens the one book once the home is up, polls until
`ReaderUI.instance` has a document, and reports a "scenario" `KoPandaSettled` signal. Step 1: show a plain
`Sheet.show({ name = "probe", rows = { { label = "Close", run = function() end } } }, ctx, { beneath = NOOP })` over the
reader, with `NOOP = { close = function() end }` and ctx built as `QuickSettings.open` builds it
(`quick_settings.lua:429-445`). Wait for the sheet's own settled signal (screen "sheet"). Tap its row through
`UIManager:sendEvent` with a tap `Event` at the row's rect centre. Report `sheet_painted`, `sheet_closed`
(`Sheet.shown == nil`), `reader_shown` (`ReaderUI.instance` still on the stack) and any error.

**Test:** `focused_panel_spec.lua` runs it on the Colorsoft with a one-book library copied as `book_close_spec.lua`
copies it (lines 14-24) and asserts all three are true and `error` is nil. This proves the sheet paints over a book,
closes, and leaves the reader up. Later tasks grow this scenario and spec. If it fails, stop and report to the lead.
The design depends on it.

---

### Task 2: The `focused.on` setting

**Files:**
- Modify: `kopanda.koplugin/schema.lua` (a new key after `launcher.entries`)
- Modify: `spec/unit/schema_spec.lua` (its copy of the keys and the key count)
- Modify: `spec/unit/settings_spec.lua`
- Regenerate: `studio/src/schema.json` (`npm --prefix studio run schema`)

**Tests first:** in `settings_spec.lua`, `Settings.get("focused.on")` is `true` with nothing stored, and
`Settings.set("focused.on", false)` stores false and reads back false. Update `schema_spec.lua`'s expected key table and
count. Then add:

```lua
{
    -- KoPanda's panel in place of KOReader's reader menus, and the shell's doors into KOReader's screens closed.
    id = "focused.on",
    type = "boolean",
    default = true,
    label = "Focused mode",
    group = "focused",
},
```

Run `bin/check --unit`. Studio tests that count keys or groups fail here if any exist; update each to the new count,
none to skip the key.

---

### Task 3: A header-only hold in the sheet

**Files:**
- Modify: `kopanda.koplugin/sheet.lua` (spec doc comment, lines 2-14; `Sheet:onHoldSheet`, lines 316-331)
- Test: `spec/unit/sheet_spec.lua` (next to the holds at 314-353 and 1393-1420)

A new optional spec field `header_hold`. With it, `spec.hold` runs only for a hold inside `sheet.header_rect`. A hold
anywhere else on the panel, an area without a hold included, is consumed and runs nothing. Without it, behaviour is
unchanged: the folder sheet and every existing test keep passing.

**Tests first:**
1. With `header_hold = true` and a body with one area that has no hold: a hold on the header closes the sheet and
   runs `hold` once.
2. The same sheet: a hold in the area, and a hold on the panel below the header, run nothing and keep the sheet shown.
3. An area with its own hold still runs that hold, header_hold or not.

**Implementation:** in `onHoldSheet`, before the `elseif self.spec.hold` branch, when
`self.spec.header_hold and not (self.header_rect and self.header_rect:contains(ges.pos))`, do nothing. Add the field
to the doc comment: `header_hold   runs hold only for a hold on the header`.

---

### Task 4: Steppers, lifted from quick settings

**Files:**
- Create: `kopanda.koplugin/steppers.lua`
- Modify: `kopanda.koplugin/quick_settings.lua` (the `Body` widget, lines 240-258; the bars loop, lines 300-351)
- Test: `spec/unit/steppers_spec.lua`; the existing `quick_settings_*_spec.lua` and
  `spec/emulator/quick_settings_capture_spec.lua` must pass unchanged

A refactor that changes no behaviour. `Steppers.Body` is quick settings' `Body` (fills, then widgets at places).
`Steppers.draw(body, bctx, content_w, y, bars)` draws each bar as the loop does today (label and value on one line,
then − level +, then the section rule) and returns the new `y` and the areas, each
`{ id = bar.id .. "_minus" | "_plus", rect, tap, hold }`. A bar is
`{ id, label, value_text, greyed, level = { value, min, max } | nil, minus = { tap, hold }, plus = { tap, hold } }`.
With `level = nil`, the track isn't drawn: Text size has none. Quick settings builds its bars with this shape from
`BUTTONS` and `QuickSettings.state()` and calls `Steppers.draw`.

**Tests first** (`steppers_spec.lua`): two bars give four areas in order (minus, plus, minus, plus), each rect inside
`content_w`. A greyed bar's areas have no tap. `level = nil` draws no track fill: count the fills. Then refactor and
run every quick settings spec and `bin/check spec/emulator/quick_settings_capture_spec.lua`.

---

### Task 5: The panel's model

**Files:**
- Create: `kopanda.koplugin/focused_panel.lua` (model half: `FocusedPanel.state(ui)` and `FocusedPanel.actions(ui)`)
- Test: `spec/unit/focused_panel_spec.lua`, with a fake `ui` table: `document` (`info.has_pages`, `configurable`),
  `doc_props.display_title`, `toc`, `bookmark`, `font` and `handleEvent` recording events

`FocusedPanel.state(ui)` returns:
- `header`: `{ heading = title, aside = chapter, hint = "Hold here for all settings", label = "Page n of m · p%" }`.
  Time and battery are on the panel per the design; fold them into the label as `· 8:42 · 81%` when the device
  reports a battery. Use the field layout `sheet_layout.lua` already supports. Don't add header fields.
- `text_size`: `{ value = configurable.font_size }` for a rolling document, nil when `document.info.has_pages`
  (`dispatcher.lua:245`).
- `contrast`: `{ name, event, values, index }`. For a rolling document that's `font_gamma` / `SetFontGamma` /
  `{10, 15, 25, 30, 36, 43, 49, 56}` (`creoptions.lua:571-579`); for a paging one, `contrast` / `GammaUpdate` /
  `{0.8, 1.0, 1.5, 2.0, 4.0, 6.0, 10.0, 50.0}` (`koptoptions.lua:489-498`). `index` is the stored value's position,
  else the nearest value.
- `light`: `QuickSettings.state()`'s brightness and warmth readings, nil without a frontlight. Expose what quick
  settings already reads; don't read the device twice.
- `night`: `G_reader_settings:isTrue("night_mode")`.
- `bookmarked`: `ui.bookmark:isPageBookmarked()` (`readerbookmark.lua:403`).

`FocusedPanel.actions(ui)` returns functions, each sending KOReader's own event the way its own UI sends it:
- `text_minus` / `text_plus`: `ui:handleEvent(Event:new("DecreaseFontSize", 1))` / `IncreaseFontSize`. The number
  argument is the step (`readerfont.lua:377-380`, `:400-411`).
- `contrast_minus` / `contrast_plus`: clamp the index to the values; at an end, do nothing. Otherwise send
  `ConfigChange(name, value)`, then the option's event with the value, as `ConfigDialog:onConfigChoose` does
  (`configdialog.lua:981-1012`).
- `night`: `UIManager:broadcastEvent(Event:new("ToggleNightMode"))`, as quick settings does.
- `bookmark`: `ui:handleEvent(Event:new("ToggleBookmark"))` (`readerbookmark.lua:347`).
- `home`: what the reader menu's folder icon does (`readermenu.lua:68-72`): `ui:onClose()`, then
  `ui:showFileManager(file)`.
- `go_to`: `ui:handleEvent(Event:new("ShowToc"))` (`readertoc.lua:807`), until release 2.
- `admin`: `ShowConfigMenu` when `G_reader_settings:nilOrTrue("show_bottom_menu")`, then
  `ui.menu:onShowMenu()`, as `ReaderMenu:onTapShowMenu` does without the tab index (`readermenu.lua:495-503`).

**Tests first:** one test per bullet above. Rolling vs paging decides text_size and contrast. A − at the first
contrast value sends nothing. Each action sends exactly the events listed, in order. With no frontlight, light is nil.

---

### Task 6: The panel's body and opener

**Files:**
- Modify: `kopanda.koplugin/focused_panel.lua` (`FocusedPanel.body(bctx, content_w)` and `FocusedPanel.open(ui, opts)`)
- Modify: the look token tables only if the body needs tokens quick settings doesn't have. Prefer reusing
  `look.quick_settings` and `look.type.quick_*`, as the panel is drawn like quick settings.
- Test: `spec/unit/focused_panel_spec.lua`; grow `spec/emulator/focused_panel_spec.lua`

Layout, top to bottom, under the header: **Home**, a full-width row; then the steppers (Text size, Contrast,
Brightness, Warmth) through `Steppers.draw`; then three cells in one row, **Night**, **Bookmark** (label "Bookmark" or
"Remove bookmark", filled when bookmarked) and **Go to**, drawn as quick settings' grid cells. Home and the cells are
areas with `close_first = true`, except Night, which acts with the panel open, as in quick settings. The stepper
areas have taps and no holds. A hold on them must do nothing, which Task 3's `header_hold` guarantees.

`FocusedPanel.open(ui, opts)` builds ctx as `QuickSettings.open` does and calls
`Sheet.show({ name = "focused_panel", band = "quick_settings", header = …, body = FocusedPanel.body,
header_hold = true, hold = actions.admin, refresh_on = { "FontSizeChanged"?, … } }, ctx,
{ started = …, beneath = NOOP })`. For `refresh_on`, pick the events KOReader broadcasts after a font, gamma,
bookmark or night change, so the values redraw. Find them in `readerfont.lua`, `readerbookmark.lua` and
`devicelistener.lua` and cite them in a comment. If none fit, the stepper's tap redraws, since `act` already
redraws the sheet (`sheet.lua:269-280`).

**Tests first (unit):** areas in order: home, then each stepper's minus and plus, then night, bookmark, go_to. No text
stepper for a paging document. Home's and Go to's areas have `close_first`; Night's doesn't. Every area's rect sits
inside the body. **Emulator:** the scenario opens the panel through `FocusedPanel.open(ReaderUI.instance)` on the
Paperwhite 7th gen profile (`paperwhite7` in `spec/emulator/profiles.lua`) with `text_size = "extra_large"` and the
Editorial look. The spec asserts the sheet's `left_out` is 0: expose it on the settled signal's args, or read
`Sheet.shown`. After a tap on Text size's plus, it asserts the panel is still shown and `configurable.font_size`
grew by 1.

---

### Task 7: The reader hooks

**Files:**
- Create: `kopanda.koplugin/focused_hooks.lua`
- Modify: `kopanda.koplugin/main.lua` (`KoPanda:init`, beside `FmNav.install()`: `FocusedHooks.install()` when
  `not self.in_fm`)
- Modify: `kopanda.koplugin/HOOKS.md` (one entry per wrapped handler, with `file:line`)
- Test: `spec/unit/focused_hooks_spec.lua`; grow the emulator scenario and spec

`FocusedHooks.install()` runs once per process and wraps:

| Handler | Opens the panel when the mode is on and |
|---|---|
| `ReaderMenu.onTapShowMenu` (`readermenu.lua:495`) | `self.activation_menu ~= "swipe"` |
| `ReaderMenu.onSwipeShowMenu` (`:484`) | `self.activation_menu ~= "tap"` and `ges.direction == "south"` |
| `ReaderConfig.onTapShowConfigMenu` (`readerconfig.lua:154`) | `self.activation_menu ~= "swipe"` |
| `ReaderConfig.onSwipeShowConfigMenu` (`:161`) | `self.activation_menu ~= "tap"` and `ges.direction == "north"` |
| `ReaderFooter.TapFooter` (`readerfooter.lua:2517`) | always |
| `ReaderFooter.onHoldFooter` (`:2647`) | consumed: returns true, no panel, no menu |

When a condition fails, the wrap returns what the original returns for that case (nil), so other zones still get the
gesture. When the mode is off, it calls the original with the same arguments. When opening the panel raises, it logs
`KoPanda: the focused panel failed:` and calls the original, so KOReader's menu opens. Each wrap returns true when the
panel opened. Also send `HandledAsSwipe` after a swipe, as the originals do (`readermenu.lua:490`,
`readerconfig.lua:150`).

`Settings.get("focused.on")` is read on every gesture, not cached, so turning the mode off takes effect without a
restart.

**Tests first (unit, with stub ReaderMenu/ReaderConfig/ReaderFooter classes whose originals record calls and
`FocusedPanel.open` stubbed):**
1. Mode on: each of the five opening handlers opens the panel once and doesn't call the original.
2. Mode on, wrong direction or activation_menu: neither panel nor original action; returns nil.
3. Mode off: every handler calls its original with the same arguments, and the panel doesn't open.
4. Mode on, `FocusedPanel.open` raises: the original runs and the error is logged.
5. `onHoldFooter` with the mode on returns true and calls nothing. With it off, the original runs.
6. `install()` twice wraps once.

**Emulator:** the scenario sends a tap in `DTAP_ZONE_MENU` to the reader and asserts the panel shows and no
`TouchMenu` is on the stack. A hold on the panel's header asserts KOReader's menu container is shown. With
`focused.on = false` written before the run, the same tap shows KOReader's menu and no panel.

---

### Task 8: The Updates section

**Files:**
- Modify: `kopanda.koplugin/studio_menu.lua` (export `StudioMenu.check_for_update(plugin)`, the local at
  lines 189-240, unchanged in body)
- Modify: `kopanda.koplugin/settings_menu.lua` (append the section to the items `SettingsMenu.open` shows when no
  group is asked for)
- Test: `spec/unit/settings_menu_spec.lua`

The section appends two items after the schema rows, the first with a separator above it:
1. "Check for KoPanda update": calls `StudioMenu.check_for_update({ path = PLUGIN_DIR })`, with `PLUGIN_DIR` resolved
   as `fonts.lua:15` resolves its directory.
2. "Apps (Storefront)": `LauncherEntries.run{ kind = "plugin", plugin = "storefront", action = "storefront_open",
   label = "Storefront" }`, present only when `LauncherEntries.available` of that entry is true
   (`launcher_entries.lua:61-80`).

A group view (`SettingsMenu.open(group)`, a widget's settings) gets no Updates section.

**Tests first:** with Storefront's plugin loaded and its action registered (stub `PluginLoader:isPluginLoaded` and
`Dispatcher.getDisplayList` as `launcher_entries` specs do), the items end with the two rows. Without Storefront, only
the update row is there. A group view has neither. Tapping the update row calls `check_for_update` with a path ending
in `kopanda.koplugin`.

---

### Task 9: Finish

1. `HOOKS.md` has every new KOReader read and wrap with its `file:line`. `focused_panel.lua`, `focused_hooks.lua` and
   `steppers.lua` open with a one-to-three sentence comment naming their KOReader internals.
2. Run `bin/check` (the full gate, emulator included) once. Every failure is fixed or reported.
3. Render the panel on the emulator at the Paperwhite 7th gen size, Editorial and Diner, Medium and Extra large, and
   `open` the PNGs for the owner's eye.
4. Present the summary and a commit message to the owner. Don't commit.

## Agents

- **Builder 1 (Opus):** Tasks 1–4 in order. Task 1 first; if it fails, stop and report.
- **Builder 2 (Opus):** Tasks 5–8, after builder 1 reports green.
- **Reviewer (Opus):** one pass over the whole diff against the design and this plan, spec compliance and code
  quality, ending in a numbered fix list. Nothing here handles files from outside or the push path, so there are no
  mutation checks.
- **Fixer (Opus), if needed:** a fresh agent with the fix list and the diff.
- **The lead:** Task 9.
