# Quick settings sheet

## Summary

A sheet, not a bar (direction doc "Quick settings"): brightness and warmth as outlined bars with minus
and plus, then a grid of toggles and actions (Wi‑Fi, Night, Rotation lock, Sync books, Screenshot,
Sleep), the on state filled in ink. KOReader's own top menu keeps the top edge.

## Behavior

- Opens from a hold on the nav bar's Settings tab, on the home and over the file browser, and from a new
  KoPanda launcher target, "Quick settings", the owner can place on the home (Q-irxgmk, answered).
- Brightness and warmth read and write the device's frontlight through KOReader's own events, one native
  step per tap; holding minus goes to zero, holding plus to the top.
- Toggles reflect the real state on open and act at once, the sheet redrawing in place: Wi‑Fi, night mode
  (which repaints the home through `home/night-mode`), rotation lock. Sync books runs cwngsync's sync and is
  greyed without the plugin; Screenshot and Sleep close the sheet first.
- Drawn with the sheet component in both looks; goldens on the Colorsoft profile.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. cwngsync paths are
relative to `https://github.com/new-usemame/cwngsync.koplugin` at commit `df90d5e`
(`df90d5ec7ddbbeeaaa99417942af6ce346b89f7e`, plugin version 4.1.46, `cwngsync.koplugin/_meta.lua:8`,
`cwngsync.koplugin/main.lua:46`; the repository has no licence file: read, don't copy). Repo paths are on
`main` at `e6f2912`. Planned names from `nav-bar/nav-bar` (F-78e5ij), approved and not yet built, are cited to
its plan, `.tiller/epics/nav-bar/features/nav-bar/feature.md` ("nav-bar feature.md") and its task `bar`
(T-3648b1). The board is `.tiller/design/2026-10-13-kopanda-screens/QuickSettings.dc.html:<line>`
("QuickSettings"); sizes are board pixels, scaled by `Screen:scaleBySize` as the looks use them
(`layout.lua:4-6`, `:15-17`), about ×2.107 on the Colorsoft; font sizes go to `Font:getFace` unscaled
(`looks/editorial.lua:6-7`).

The Settings-tab hold lands in nav-bar's `nav_bar.lua`, so the edge is recorded: `bars/quick-settings`
depends on `nav-bar/nav-bar` as well as `home/sheets`.

### Decisions

Owner decisions (owner, 2026-10-16):

- **D1. Entry points:** a hold on the nav bar's Settings tab, on the home and over the file browser, and a
  KoPanda launcher target `quick_settings` the owner can place on the home or in a launcher folder. Not the
  home sheet. Nav-bar reserved the Settings hold for this sheet (nav-bar feature.md D3).
- **D2. Sync books** runs cwngsync's Dispatcher action `cwngsync_sync_now`, greyed when it isn't available.
  cwngsync (Calibre-Web NextGen sync) is installed on the Colorsoft (`.tiller/design/handoff-2026-10-08.md`
  §4). At `df90d5e` the plugin is named `cwngsync` (`cwngsync.koplugin/main.lua:43`,
  `cwngsync.koplugin/_meta.lua:5`), registers `cwngsync_sync_now`, event `CWNGSyncSyncNow`, `general = true`
  (`cwngsync.koplugin/main.lua:282-283`), and handles it with `onCWNGSyncSyncNow`, which runs its
  `syncEverythingNow` and returns true (`:310-313`). The grid always has six cells.
- **D3. Rotation lock** flips KOReader's `lock_rotation`, "Keep current rotation across views", as KOReader's
  own menu item does (`frontend/ui/elements/screen_rotation_menu_table.lua:64-77`, its callback
  `G_reader_settings:flipNilOrFalse("lock_rotation")` at `:73-75`). When set, the file browser keeps the
  current rotation (`frontend/apps/filemanager/filemanager.lua:63-69`) and the reader neither applies nor
  saves a book's rotation (`frontend/apps/reader/modules/readerview.lua:971`, `:1223`). Not the gyro lock,
  which only devices with a G-sensor have (`frontend/dispatcher.lua:114`; `frontend/device/devicelistener.lua:200`).
- **D4. Which cells keep the sheet open:** the brightness and warmth buttons, Wi‑Fi, Night and Rotation lock
  act and the sheet redraws in place; Screenshot, Sleep and Sync books close the sheet first. Screenshot
  captures the screen beneath: close, force a repaint, then shoot.
- **D5. Diner has no board.** Diner's sheet is derived from Diner's existing sheet vocabulary: the band
  header, 2 px outlined tiles, the on state an ink fill with paper text (Tokens, below). The owner judges the
  Diner golden.

Lead decisions, each overturnable at approval:

- **D6. The sheet component gains a generic body hook** (The body hook, below): areas whose taps and holds
  act without closing, an in-place redraw of the panel, areas that ask to close first, and refresh events.
  The bars and the grid live in a new `kopanda.koplugin/quick_settings.lua`. `sheet.lua` is 631 lines today,
  past AGENTS.md's 500-line signal; if the hook takes it past 700, the `sheet-body` task extracts the
  layout into its own module, by AGENTS.md's rule (plan at 500, decompose at 1000), and says so in its PR.
- **D7. Values in native steps,** as the board writes them (QuickSettings:42 "12", :53 "4", against its
  fills of 50 % and 17 %, :46, :57: the Kindle's 0–24 scales, `frontend/device/kindle/powerd.lua:8-11`). One
  native step per tap, as KOReader's own frontlight widget steps (`frontend/ui/widget/frontlightwidget.lua:153-170`,
  `:274-288`). Hold minus: brightness 0 (the light off), warmth its minimum. Hold plus: each its maximum.
- **D8. The battery aside** "Battery N%" as drawn (QuickSettings:37), on devices with a battery; the goldens
  stub the capacity.
- **D9. The launcher target** `quick_settings`, labelled "Quick settings", with a new registry icon: Lucide's
  `sliders-horizontal` (ISC, `icons/LICENSE-lucide.txt`) as `quick_settings`. The schema's allowed kopanda
  targets grow by one; no settings key is added and the schema version stays 1 (a widened value list of an
  existing key, `schema.lua:3-5`). `studio/src/schema.json` and `studio/src/catalog.json` are regenerated.
- **D10. Actions reach KOReader as KOReader's own menus reach it:** frontlight, warmth and night mode by
  broadcasting KOReader's events, Wi‑Fi by calling `NetworkMgr` as KOReader's Wi‑Fi menu item does, the
  rotation lock by its setting, and the close-first actions through the launcher's entries after the sheet
  has closed (Routing, below). No `kopanda_quick_settings` Dispatcher action for Gestures (YAGNI).
- **D11. A device without a frontlight hides both bars; one without warmth hides the warmth bar.** Cells
  for things the device can't do are greyed, as the launcher greys an entry (`launcher_entries.lua:59-80`).
- **D12. Text follows `text_size`,** as every sheet's does (`typeset.lua:24`, `layout.lua:280-283`).
- **D13. The Wi‑Fi cell shows the radio's real state,** `NetworkMgr:isWifiOn()`, with no "connecting" state
  and no timer; KOReader's own "Turning on Wi‑Fi…" note covers the wait
  (`frontend/ui/network/manager.lua:433-445`), and the cell is re-read on KOReader's network events.
- **D14. Diner's band is `band`,** the role Diner's nav bar fills with (nav-bar feature.md, Tokens:
  `nav.fill_color = band`): teal by day, the night teal at night and Diner's band grey on the Paperwhite
  (`looks/diner.lua:30`, `:48`, `:67`). The sheet rises from the Settings tab on that band, so it carries the
  bar's colour; pink is the book sheet's, mustard the home sheet's (`looks/diner.lua:124-125`). The folder
  sheet's `teal` is the same hue by day, and a folder sheet and this one are never shown together.
- **D15. Labels use a plain hyphen, "Wi-Fi",** in both looks, as the home sheet writes it: Diner's faces have
  no U+2011 (`home_sheet.lua:36-37`).

### What the sheet shows

The panel, top to bottom, inside the sheet's chrome in each look (`sheet.lua:335-360`):

1. **The header:** "Quick settings" in `sheet_heading`, and, when `Device:hasBattery()`, the aside
   "Battery N%" in `sheet_aside` at the header's right, N from `powerd:getCapacity()`
   (`frontend/device/generic/powerd.lua:254`), read at each layout. Diner's header takes the band (D14).
   These are the sheet's existing header tokens (Editorial's match the board, QuickSettings:35-37 against
   `looks/editorial.lua:125-127`, `:265-269`).
2. **Brightness**, when `Device:hasFrontlight()`: a label row, "Brightness" at the left and the value at the
   right; under it a control row, the minus button, the level bar, the plus button (QuickSettings:40-49).
   The value is `powerd:frontlightIntensity()`, native, 0 when the light is off
   (`frontend/device/generic/powerd.lua:126-133`); the bar's fill is value ÷ `powerd.fl_max`.
3. **Warmth**, when `Device:hasNaturalLight()`: the same, "Warmth", the value
   `powerd:toNativeWarmth(powerd:frontlightWarmth())` (`powerd.lua:169-175`, `:233-235`), the fill
   (value − `fl_warmth_min`) ÷ (`fl_warmth_max` − `fl_warmth_min`) (QuickSettings:51-60).
4. **The grid:** three columns, two rows, in the board's order (QuickSettings:62-87): Wi‑Fi, Night,
   Rotation lock; Sync books, Screenshot, Sleep. Each cell is an outlined tile, its icon over its label.

| Cell | Label | Icon | On (ink fill) when | Greyed when |
|---|---|---|---|---|
| Wi‑Fi | "Wi-Fi on" / "Wi-Fi off" | `wifi` / `wifi_off` | `NetworkMgr:isWifiOn()` | the launcher's Wi‑Fi entry can't run here (`toggle_wifi` unregistered: `condition = Device:hasWifiToggle()`, `frontend/dispatcher.lua:124`) |
| Night | "Night on" / "Night off" | `moon` | `G_reader_settings:isTrue("night_mode")` | never |
| Rotation lock | "Rotation lock" | `rotation_lock` | `G_reader_settings:isTrue("lock_rotation")` | never |
| Sync books | "Sync books" | `sync` | never | the entry `{ kind = "plugin", plugin = "cwngsync", action = "cwngsync_sync_now", label = "Sync books" }` can't run |
| Screenshot | "Screenshot" | `screenshot` | never | never |
| Sleep | "Sleep" | `power` | never | the entry `{ kind = "action", action = "suspend", label = "Sleep" }` can't run (`condition = Device:canSuspend()`, `frontend/dispatcher.lua:94`) |

- "Can't run" is `LauncherEntries.available` (`launcher_entries.lua:59-80`): a plugin entry needs
  `PluginLoader:isPluginLoaded(name)` (`frontend/pluginloader.lua:567-569`) and its action listed by
  `Dispatcher.getDisplayList`, which lists an id only when registered and its condition holds
  (`frontend/dispatcher.lua:866-890`). That is the honest check for cwngsync: the plugin loaded and its
  action registered.
- A greyed cell draws its icon and label in `muted` and is never filled, as a greyed launcher entry
  (`launcher_entries.lua:82-109`).
- The labels' state words are the board's (QuickSettings:65, :69); Rotation lock has none (:73), its state
  is its fill.

### Taps and holds

| Where | Tap | Hold |
|---|---|---|
| Brightness minus | one native step down, to 0 | 0: the light off |
| Brightness plus | one native step up, to `fl_max` | `fl_max` |
| Warmth minus | one native step down, to `fl_warmth_min` | `fl_warmth_min` |
| Warmth plus | one native step up, to `fl_warmth_max` | `fl_warmth_max` |
| Wi‑Fi | KOReader's Wi‑Fi toggle (Routing) | nothing |
| Night | toggles night mode | nothing |
| Rotation lock | flips `lock_rotation` | nothing |
| Sync books | closes the sheet, then runs the entry | nothing |
| Screenshot | closes the sheet, repaints, then runs `screenshot` | nothing |
| Sleep | closes the sheet, then runs the entry | nothing |
| A greyed cell | closes the sheet and runs its launcher entry, which shows the launcher's note saying why (`launcher_entries.lua:141-151`, `:171-179`) | nothing |
| Elsewhere in the panel (labels, bars, header) | consumed, nothing | consumed, nothing |
| Outside the panel | closes the sheet (`sheet.lua:588-590`) | as the sheet does today |

- A step from the light off goes from 0, so plus turns the light on at step 1, as KOReader's Kindle powerd
  turns it on from its minimum (`frontend/device/kindle/powerd.lua:57-63`).
- After each stay-open action the sheet re-reads every value and state and redraws the panel in place with
  one `"ui"` refresh, as `FrontLightWidget:update` does (`frontend/ui/widget/frontlightwidget.lua:430-437`).
- Back and the Back key close it, as every sheet (`sheet.lua:621-629`).

### Routing: how each action reaches KOReader

`UIManager:sendEvent` offers an event to the topmost window and its active widgets, then, below it, only to
each window's active widgets and to windows flagged `is_always_active` (`frontend/ui/uimanager.lua:962-1035`);
`broadcastEvent` offers it to every window, whatever a handler returns (`:1042-1061`). The file manager's
`DeviceListener` and `NetworkListener` are ordinary modules in it (`frontend/apps/filemanager/filemanager.lua:414-415`,
`:379-389`), and its Screenshoter is the one module it registers as an active widget (`:385-388`, `:400-403`; plugin
instances are registered without, `:424`). KoPanda's dispatch bridge marks the file manager always active only while the home is shown
(`dispatch_bridge.lua:19-31`), so with the sheet over the bare file browser a dispatched event other than
Screenshot would be lost while the sheet is on top. Hence:

- **Brightness:** `UIManager:broadcastEvent(Event:new("SetFlIntensity", n))`, reaching the file manager's
  `DeviceListener:onSetFlIntensity`, which turns the light off at `n <= 0`, else `setIntensity(n)`, then
  `updateResumeFrontlightState()` (`frontend/device/devicelistener.lua:116-125`). The sheet clamps `n` to
  `[0, fl_max]` itself.
- **Warmth:** `broadcastEvent(Event:new("SetFlWarmth", n))`, `n` native, reaching `onSetFlWarmth`
  (`devicelistener.lua:156-165`), which clamps only to 0–100 before converting from native, so the sheet
  clamps `n` to `[fl_warmth_min, fl_warmth_max]` itself. Both handlers exist only when the device has a
  frontlight (`devicelistener.lua:58`), the same condition that shows the bars.
- **Night:** `broadcastEvent(Event:new("ToggleNightMode"))`, as KOReader's night mode menu item does
  (`frontend/ui/elements/common_settings_menu_table.lua:266-271`); `DeviceListener:onToggleNightMode`
  toggles, marks every window dirty "full" and saves `night_mode` (`devicelistener.lua:14-27`). The home and
  the sheet rebuild in the night palette at their next paint (`home.lua:282-291`, `sheet.lua:544-553`;
  `HOOKS.md:397-433`); nothing else is needed.
- **Wi‑Fi:** as KOReader's Wi‑Fi menu item (`frontend/ui/network/manager.lua:899-922`): `queryNetworkState()`
  (`:651`); fully connected → `toggleWifiOff(cb, true)` (`:447-457`); on but not connected →
  `promptWifi(cb, false, true)` (`:490`); else `toggleWifiOn(cb, false, true)` (`:433-445`). `cb` redraws the
  sheet when it is still shown. The sheet also redraws on `NetworkConnected` and `NetworkDisconnected`
  (`:109`, `:408`), as the home does (`home.lua:112-125`), returning nothing; the events are broadcast, so
  the home hears them too (`uimanager.lua:1042-1061`). A failed connection broadcasts nothing (`:44-63`, comment `:56`); the cell shows whatever
  `isWifiOn()` reads at the redraw (D13).
- **Rotation lock:** `G_reader_settings:flipNilOrFalse("lock_rotation")` (D3), then the redraw.
- **Close-first actions:** the sheet closes, which takes it off the window stack at once
  (`frontend/ui/uimanager.lua:290-313`), so the window beneath is on top: over the file browser the file
  manager, whose modules and plugin instances (`filemanager.lua:384`, `:418-429`) receive the event; over the
  home the home, under which the dispatch bridge carries it to the file manager (`dispatch_bridge.lua:33-58`).
  Then `LauncherEntries.run(entry)` runs it, availability checked again (`launcher_entries.lua:158-190`):
  - **Sync books:** `cwngsync_sync_now` → `CWNGSyncSyncNow` → cwngsync's handler (D2).
  - **Sleep:** `suspend` → `RequestSuspend` (`frontend/dispatcher.lua:94`) → `DeviceListener:onRequestSuspend`
    → `UIManager:suspend()` (`devicelistener.lua:458-460`, `uimanager.lua:1679-1686`), as the home sheet's
    Sleep row (`home_sheet.lua:16`, `:86`).
  - **Screenshot:** after the close, `UIManager:forceRePaint()` (`uimanager.lua:1404-1406`) paints the screen
    beneath, which the close marked dirty; then `screenshot` → `Screenshot` (`frontend/dispatcher.lua:86`) →
    `Screenshoter:onScreenshot`, which shoots the framebuffer as it is (`frontend/ui/widget/screenshoter.lua:50-70`,
    `Screen:shot` at `:63`). Without the repaint the shot would still hold the sheet: a close only marks
    dirty, and tasks run before the next repaint.

### The body hook (`sheet.lua`)

A sheet spec may carry `body` instead of `rows` (a spec with both is refused: logged and shown with rows
only), and an optional `refresh_on`:

- `body(bctx, content_w)` → `{ widget, areas }`, called at every layout (the first, a night rebuild, a
  redraw). `bctx` is the sheet's build ctx, the variant included (`sheet.lua:96-100`); `widget` paints the
  body (`getSize`, `paintTo`, `free`) and is placed under the header at the content's left, freed with the
  panel; `areas` is a list of `{ rect, tap, hold, close_first }`, `rect` relative to the body's top-left,
  moved to the screen with the rest (`sheet.lua:362-379`).
- **A tap in an area with `tap`:** with `close_first`, the sheet closes, then `tap()` runs; without, `tap()`
  runs with the sheet open, then the sheet redraws. **A hold in an area with `hold`:** the same with
  `hold()`. A tap or hold elsewhere in the panel: consumed, nothing run, unless the spec has `hold`, which
  keeps its meaning today (`sheet.lua:601-611`). Outside the panel: as today.
- **Redraw:** re-lays the sheet out in its variant and asks for one `"ui"` refresh of the union of the old
  and new panel rectangles (with shadow), so a panel that changed height leaves nothing stale. A sheet no
  longer shown does nothing. `Sheet.redraw()` redraws the shown sheet, for callbacks that come later (the
  Wi‑Fi `cb`).
- **`refresh_on`:** a list of event names; on each, the sheet redraws and returns nothing. A broadcast event
  reaches every window whatever a handler returns (`frontend/ui/uimanager.lua:1042-1061`), so the windows
  beneath still hear it.
- **Failures:** an area's own `tap` or `hold` raising is logged and the sheet stays and redraws, so one
  broken control leaves the rest working. A raising `body` (at any layout) or redraw is a sheet failure, as
  today: logged, the sheet and the home closed (`sheet.lua:479-483`), leaving the file browser.
- The rows path, the header and the chrome are unchanged, so the home, book and folder sheets look and act
  as before.

A body taller than the screen less the inset can't be cut as rows are (`sheet.lua:266-292`): the panel then
sits at the screen's top and the sheet logs it once. The quick-settings panel is about 420 board px
(≈ 885 device px of 1680 on the Colorsoft), so it fits; a unit case holds that at every text size.

### The panel (`quick_settings.lua`)

`QuickSettings.open(opts)` builds its own ctx, as the home's rows do (`home_rows.lua:84-91`) but with no home:
`{ look = Looks.active(), variant = Looks.variant(), text_size = Settings.get("text_size"), now = os.time(),
screen = Screen }`, and shows `{ name = "quick_settings", band = "quick_settings", header, body,
refresh_on = { "NetworkConnected", "NetworkDisconnected" } }` through `Sheet.show(spec, ctx, opts)`
(`sheet.lua:507-521`), `opts.started` the opener's `time.monotonic()`. It needs no home, so it opens over the
home and over the bare file browser alike; a sheet failure's `Home.close()` is a no-op with no home
(`home.lua:226-230`).

- **The body's layout,** inside `content_w` less `2 × padding_x`: each bar section is `section_padding.top`,
  the label row, `section_gap`, the control row (the minus button, `control_gap`, the bar, `control_gap`, the
  plus button, the bar taking the rest, vertically centred on the buttons), `section_padding.bottom`, then a
  `section_rule` across the content width. The grid follows after `grid_padding.top`: three columns from
  `Layout.columns(width, { { share = 1 }, { share = 1 }, { share = 1 } }, grid_gap)` (`layout.lua:22-42`, each
  slot's `share` at `:27`, `:33`), rows `grid_gap` apart, each cell
  `cell_padding.top`, the icon centred, `cell_gap`, the label centred, `cell_padding.bottom`; a row's cells
  share the tallest one's height; then `grid_padding.bottom`. A label wider than its cell is cut by
  `Typeset.line`'s `max_width` (`typeset.lua:49`).
- **Glyphs:** the buttons' minus and plus are U+2212 "−" and "+" in `quick_button`, or the registry icons
  `minus` and `plus` at that part's line height; open fact F1 settles which.
- **Drawing:** fills and outlines through `Paint.fill` and `Paint.border` (`paint.lua:10-32`), icons through
  `TintedIcon` in the cell's text colour, lines through `Typeset.line`, colours from `Looks.palette(look,
  variant)` through `Looks.color` (`looks.lua:63-89`); the module never names the palettes, which
  `night_mode_spec.lua`'s scan keeps true (`spec/unit/night_mode_spec.lua:70`). An on cell is filled
  `on_fill_color` and its icon and label take `on_text_color`.
- **State** is read at each layout, every read guarded: a read that raises is logged and that control shows
  as greyed (a bar: its value "–", no fill, buttons inert).

### Tokens

A `quick_settings` block and three type parts in both looks with identical paths, and the sheet's
`quick_settings_band_color`, each value's comment naming its board line or its source, by `looks_spec.lua`'s
rules (`spec/unit/looks_spec.lua:83-125`, `:185-233`). Every colour names an existing palette role; none is
added. Diner's values with no board come from Diner's own sheet, progress bar and chip tokens, as cited.

| Token | Editorial (QuickSettings) | Diner (no board) |
|---|---|---|
| `sheet.quick_settings_band_color` | false (Editorial has no band) | `band` (D14) |
| `quick_settings.padding_x` | 0 (:34; the sheet's 40 side padding holds it) | 20 (Diner's sheet has none; its rows' `row_padding.x`, `looks/diner.lua:137`) |
| `quick_settings.first_section_padding.top`, `.bottom` | 18, 16 (:40) | 15, 15 (`sheet.row_padding.y`, `looks/diner.lua:137`) |
| `quick_settings.section_padding.top`, `.bottom` | 16, 16 (:51) | 15, 15 (the same) |
| `quick_settings.section_gap` | 10 (:40) | 10 (Editorial's) |
| `quick_settings.section_rule_width`, `section_rule_color` | 1, `hairline` (:40, :51) | 2, `outline` (the sheet's row rule, `looks/diner.lua:140-141`) |
| `quick_settings.control_gap` | 12 (:44) | 12 (Editorial's) |
| `quick_settings.button_w`, `button_h` | 44, 36 (:45) | 44, 36 (Editorial's) |
| `quick_settings.button_outline_width`, `button_outline_color` | 1, `ink` (:45) | 2, `outline` (the chip's 2 px outline, `looks/diner.lua:146`) |
| `quick_settings.button_fill_color` | false (:45, transparent) | `paper` (the sheet's fill, `looks/diner.lua:117`) |
| `quick_settings.level_h` | 10 (:46) | 14 (the progress bar, `looks/diner.lua:106`) |
| `quick_settings.level_outline_width`, `level_outline_color` | 1, `ink` (:46) | 2, `outline` (the progress bar, `looks/diner.lua:109-110`) |
| `quick_settings.level_fill_color`, `level_track_color` | `ink`, false (:46) | `mustard`, `paper` (the progress bar, `looks/diner.lua:107-108`) |
| `quick_settings.grid_gap` | 10 (:62) | 10 (Editorial's) |
| `quick_settings.grid_padding.top`, `.bottom` | 18, 0 (:62; the sheet's 28 bottom padding follows) | 15, 20 (`row_padding.y`; Diner's sheet has no bottom padding, so the side padding's 20) |
| `quick_settings.cell_padding.top`, `.bottom` | 14, 12 (:63) | 14, 12 (Editorial's) |
| `quick_settings.cell_gap`, `cell_icon_size` | 8, 24 (:63-64) | 8, 24 (Editorial's) |
| `quick_settings.cell_outline_width`, `cell_outline_color` | 1, `ink` (:63) | 2, `outline` (the owner's "2 px outlined tiles", D5) |
| `quick_settings.cell_fill_color` | false (:67, transparent) | `paper` |
| `quick_settings.on_fill_color`, `on_text_color` | `ink`, `paper` (:63) | `ink`, `paper` (D5; `.tiller/design/2026-10-13-kopanda-ui-direction.md:31`) |

| Part | Editorial | Diner |
|---|---|---|
| `type.quick_label` (a bar's label and value) | `text` 11, uppercase, 0.12, 0, `muted` (:41) | `strong` 12, uppercase, 0.08, 0, `muted` (as `sheet_detail`, `looks/diner.lua:299-301`) |
| `type.quick_button` (minus, plus) | `text` 18, not uppercase, 0, 0, `ink` (:45, the inherited Plex 400) | `strong` 18, not uppercase, 0, 0, `ink` (the row face, `looks/diner.lua:297`) |
| `type.quick_cell` (a cell's label) | `strong` 11, uppercase, 0.1, 0, `ink` (:63 asks 600; Plex Medium, 500, is the heaviest Plex Editorial ships, `looks/editorial.lua:14`) | `display` 11, uppercase, 0.08, 0, `ink` (as `sheet_chip`, `looks/diner.lua:303-305`) |

- Diner's on state, ink with paper text, inverts correctly at night (Diner's night ink is cream and its
  paper dark, `looks/diner.lua:39-40`) and in grey (`:58-59`).
- The icon strokes are the registry's 2, not the board's 1.6 (QuickSettings:64; `spec/unit/icons_spec.lua:95`),
  a planned difference as nav-bar's.

### The launcher target

- `LauncherEntries.KOPANDA.quick_settings = { label = "Quick settings", icon = "quick_settings" }`
  (`launcher_entries.lua:18-23`), and `KOPANDA_RUN.quick_settings` opens the sheet with
  `{ started = time.monotonic() }`, requiring `quick_settings` at call time, since it requires
  `launcher_entries` (as `folder_sheet` is, `:164-170`). Run from the home's launcher it opens over the home;
  from a launcher folder's sheet, over the home after that sheet closes (`sheet.lua:578-586`).
- `schema.lua`'s `launcher.entries.targets.kopanda` becomes `{ "library", "series", "authors", "settings",
  "quick_settings" }` (`schema.lua:104-107`); the default six don't change (`:108-115`), so the owner places it
  by swapping an entry out or into a folder, on the device through the entry picker, which lists the schema's
  targets (`entry_picker.lua:97-104`), or in the studio, whose validator and add-entry list read the schema
  (`studio/src/core/validators.ts:52`, `studio/src/ui/launcher/AddEntry.tsx:124`).
- The registry gains `{ id = "quick_settings", label = "Quick settings", used_in = { "launcher" }, file =
  "icons/quick_settings.svg" }`, Lucide's `sliders-horizontal`, stroke 2 and black like its siblings
  (`spec/unit/icons_spec.lua:88-130`). `wifi_off` gains `"quick settings"` in `used_in` (`icons.lua:25`); `power` and the other cells' icons
  already carry it (`icons.lua:23`, `:33-34`, `:41-42`, `:49-51`). The swatch,
  which draws every registry icon (`swatch.lua:265-293`), gains a cell, so its two goldens are regenerated on
  purpose; `bin/catalog-json` lists the registry and `LauncherEntries.KOPANDA` (`bin/catalog-json.lua:100-126`),
  so `studio/src/catalog.json` is regenerated with `npm run catalog`, and `studio/src/schema.json` with
  `npm run schema`. The studio's icon picker counts by the catalog (`studio/test/ui/launcher-editor.test.tsx:226`).

### The Settings-tab hold

Nav-bar routes every tap and hold in its bar through `bar:handle(ges)`, a hold inside consumed with nothing
run (nav-bar task `bar`, its lines 38-39), on the home through `HomeGestures.route` and in the file browser
through the bar's own `ges_events` (nav-bar feature.md, "The home" and "Events in the file browser"). This
feature changes that one branch: a hold in the Settings column opens the sheet,
`QuickSettings.open{ started = time.monotonic() }`, in `pcall`, an error logged and the hold still consumed; a
hold on any other tab, or in the side padding, stays consumed and runs nothing. On the home the sheet opens
over the home; in the file browser, over it with no home.

### Failure behaviour

Every path fails safe, so KOReader's file browser stays usable:

- **`QuickSettings.open` raising** before the show: nothing shown. From the nav bar, logged by its `pcall`,
  the hold consumed and the screen beneath as it was. From a launcher tap, the error reaches the home's
  gesture `pcall`, which logs it and closes the home onto the file browser, as any raising launcher run
  (`launcher_entries.lua:153-157`, `home.lua:338-346`).
- **The sheet failing** to show, lay out or paint: the sheet's own path, logged, the sheet and the home
  closed (`sheet.lua:479-483`, `:558-573`), leaving the file browser.
- **A control's action raising:** logged; the sheet stays and redraws (The body hook).
- **A state read raising:** logged; that control greyed.
- **A close-first action raising** after the close: logged by the area's guard; the screen beneath as it was.

### HOOKS.md

A section for the sheet: the powerd reads and their scales (`frontend/device/generic/powerd.lua:7-11`,
`:36-39`, `:126-133`, `:169-175`, `:210-252`, `:254`; `frontend/device/kindle/powerd.lua:8-11`, `:57-63`;
`frontend/device/sdl/powerd.lua:4-12`), the events broadcast and their handlers (`devicelistener.lua:14-27`,
`:58`, `:116-125`, `:156-165`, `:458-460`; `common_settings_menu_table.lua:266-271`), `NetworkMgr`'s toggles,
query and events (`frontend/ui/network/manager.lua:44-63`, `:109`, `:182-189`, `:408`, `:433-457`, `:490`,
`:651`, `:899-922`) and the emulator's fake (`frontend/device/sdl/device.lua:478-500`), `lock_rotation`
(`screen_rotation_menu_table.lua:64-77`; `filemanager.lua:63-69`; `readerview.lua:971`, `:1223`), the
`night_mode` and `lock_rotation` settings keys, `sendEvent`, `broadcastEvent`, `close` and `forceRePaint`
(`uimanager.lua:290-313`, `:962-1035`, `:1042-1061`, `:1404-1406`), the Screenshoter (`screenshoter.lua:50-70`;
`filemanager.lua:400-403`), the file manager's modules and plugin instances (`filemanager.lua:379-389`,
`:414-415`, `:418-429`), `suspend` (`dispatcher.lua:94`; `uimanager.lua:1679-1686`), the plugin check
(`pluginloader.lua:567-569`; `dispatcher.lua:866-890`) and cwngsync's action at `df90d5e` (D2).
`spec/unit/hooks_doc_spec.lua:86-102` checks every entry cites a `file:line` and every required module and
`G_reader_settings` key is named.

### Goldens and budget

- New: `quick-settings-diner-colorsoft` and `quick-settings-editorial-colorsoft`, the sheet opened over the
  populated home once it settles, shot on `KoPandaSettled{ screen = "sheet", name = "quick_settings" }`
  (`sheet.lua:487-502`). The emulator is honest about its own state: brightness and warmth read 50 of 100
  (`frontend/device/sdl/powerd.lua:4-12`), so both bars are half full, not the board's 12 and 4 of 24; Wi‑Fi on
  (the fake's default, `sdl/device.lua:497-499`); Night and Rotation lock off; Sync books greyed (no cwngsync
  in the emulator). The battery reads a stubbed 84 %, since the emulator reports the Mac's battery
  (`sdl/powerd.lua:28-33`).
- Regenerated on purpose: the two swatch goldens (the new icon).
- Unchanged: the home, night, sheet, editor screen, probe and file-browser goldens.
- No night or Paperwhite golden: night is the same paint with `Looks.palette(look, "night")`, grey the same
  with `"grey"`, both sampled by unit paint cases, as title-bar argued for its bar.
- **Budget:** each capture's `paint_ms`, from the open to the first paint, is at most 250 ms, the sheets'
  budget (`spec/emulator/sheet_golden_spec.lua:15-18`).

### Open facts

- **F1, the minus and plus glyphs** (task `panel`): do "−" (U+2212) and "+" render in Editorial's `text` and
  Diner's `strong` faces as `Typeset` sets them, by the face or KOReader's fallback fonts
  (`frontend/ui/font.lua:106-136`)? Candidates: (a) both render in both looks; (b) one is missing in a look.
  How to tell: in the harness at the Colorsoft, paint `Typeset.line(part, glyph, ...)` and the same part with
  U+0378, a code point Unicode leaves unassigned, and compare the bitmaps; identical means the missing-glyph
  box. Not U+E000: the fallback `nerdfonts/symbols.ttf` (`frontend/ui/font.lua:114`) maps U+E000–U+E00A.
  KOReader's own frontlight buttons set "−" and "＋" (U+FF0B) (`frontend/ui/widget/frontlightwidget.lua:154`,
  `:163`). For (a) the
  buttons draw the text; for (b) they draw the registry icons `minus` and `plus` (Lucide, stroke 2), tinted in
  the part's colour at its line height, in both looks so they match.
- **F2, the Kindle's Wi‑Fi timing** (the owner's device check): does `isWifiOn()` read the new state when
  `toggleWifiOn` returns, or only by `NetworkConnected`? Either way the cell is right after the event; the
  check records whether it lags one redraw. No code depends on it.
- **F3, the Colorsoft SE's device class** (the owner's device check): KOReader's `KindleColorSoft` has a
  frontlight and natural light (`frontend/device/kindle/device.lua:1208-1220`), and an unknown model raises
  (`:2225`), so the SE runs as some known class. The check confirms both bars show; if warmth is missing, that
  is KOReader's class for the SE, reported, not worked around.

## Notes

The draft's spike, which device calls set brightness and warmth on the Colorsoft and whether the
Paperwhite's warm light uses the same, is settled: both Kindles go through `KindlePowerD`'s lipc calls on 0–24
scales (`frontend/device/kindle/powerd.lua:8-11`, `:124-178`; `KindlePaperWhite5`, `KindlePaperWhite5SE` and
`KindleColorSoft`, `frontend/device/kindle/device.lua:1103-1131`, `:1208-1220`, each building its `powerd` from
`device/kindle/powerd`, `:1764-1766`, `:2025-2027`), and KoPanda reaches them only through
`DeviceListener`.

For the owner, each a default the lead chose that you can overturn at approval:

- **Diner's band is the nav bar's teal** (D14), not a fourth colour.
- **Hold plus goes to the maximum** (D7), symmetric with hold minus.
- **The bars hide** on a device without the light (D11); cells grey.
- **A tap on a greyed cell closes the sheet and shows why,** as the launcher does.
- **No Gestures action** for the sheet (D10).
- **The sheet follows text size** (D12).
