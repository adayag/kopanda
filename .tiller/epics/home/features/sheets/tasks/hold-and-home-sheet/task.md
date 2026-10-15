# Hold routing on the home and the home sheet

## Approach

The hold step in the home's gesture order, the widget contract's optional `hold`, and the sheet a hold
on empty space opens. Paths into KOReader are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`;
repo lines are on `main` at `f2ef10b`. This task starts after `night-mode` and the tweak `split-home-lua`
(TW-l2ibo3) have merged, and after `home/sheets/sheet`.

1. **Open fact first: where do the home's gesture functions live after TW-l2ibo3?** At `f2ef10b` they are
   all in `home.lua`: `own_zones` (`:67-92`), `tappableSlotAt` (`:315-321`), `routeGesture` (`:504-534`),
   `onGesture` (`:538-546`) and `onCloseWidget` (`:479-487`). The split moves code with no behaviour
   change (`.tiller/tweaks/split-home-lua/tweak.md`).
   - Find them with `grep -rn "kopanda_home_tap\|routeGesture\|tappableSlotAt" kopanda.koplugin/`.
   - The candidates: (a) still in `home.lua`; (b) moved together to one new module; (c) split across
     modules, such as the zones in one and the order in another.
   - Make each change below where its function now lives, and record which candidate held in the PR.
     Re-cite those functions in `HOOKS.md` at their new lines if the split didn't.
   - If the tweak hasn't merged when this task starts, stop and ask the owner rather than split
     `home.lua` here.
2. **The hold zone.** In `own_zones`, a third zone `{ id = "kopanda_home_hold", ges = "hold",
   screen_zone = FULL_SCREEN, handler = … }` whose handler sets `home.own_step = "hold"` and returns true.
   It has no menu-zone test: the file manager's menu zones are tap and swipe only
   (`frontend/apps/filemanager/filemanagermenu.lua:76-113`).
3. **The hold step** in `routeGesture`, after the file manager's zones (`InputContainer.onGesture(fm, ges)`)
   and beside the tap step. It takes `local started = time.monotonic()` on entry, the point the home
   sheet's `paint_ms` runs from (the feature's "The settled signal"):
   - `local slot = self:slotAt(ges.pos)`: a new method giving the first slot whose `rect` contains the
     position, whatever its module, as `tappableSlotAt` does without the `tap` test (`home.lua:315-321`).
   - With a slot whose `module.hold` exists: `if slot.module.hold(self.ctx, ges, slot.built) ~= false
     then return true end`, then fall to the home sheet.
   - With a slot whose module exists but has no `hold`: `SettingsMenu.open()`, return true.
   - Otherwise, no slot or a blank slot with no module: the home sheet,
     `require("home_sheet").open(self.ctx, { started = started })`, return true. A `false` from a
     widget's `hold` falls here with the same `started`.

   `home_sheet` is required at call time: it requires `launcher_entries`, which requires `home`
   (`launcher_entries.lua:5`). `sheet` itself can be required at load, since `sheet.lua` reaches `home`
   only at call time. Every other step is unchanged and keeps its order.
4. **The home closing closes its sheet.** `onCloseWidget` calls `Sheet.close()` inside its existing
   `pcall` pattern (`home.lua:479-487`), logged on failure. A home that KOReader closes by itself, a book
   opening from elsewhere for example, takes its sheet with it.
5. **The contract** (`widgets.lua:1-15`): the comment gains `hold(ctx, ges, built)?`. It is what a hold
   inside the slot does, given the gesture and the slot's built widget. A hold that returns `false` opens
   the home's sheet, and a widget without `hold` opens its settings. No widget gets a `hold` in this task;
   `book-sheet` adds the featured one.
6. **`Weather.age(reading, now)`** in `weather.lua`, by the feature's thresholds:
   - nil: "never fetched";
   - `now - fetched_at < 60`, negatives included: "just now";
   - `< 3600`: "%d min ago" (floored minutes);
   - `< 48 * 3600`: "%d h ago";
   - otherwise "%d d ago".

   `Weather.line` (`weather.lua:158-179`) is left as it is.
7. **`kopanda.koplugin/home_sheet.lua`**, `HomeSheet.open(ctx, opts)`, builds the spec and calls
   `Sheet.show(spec, ctx, opts)`, passing the hold step's `opts.started` through, with `name = "home"`, `band = "home"`, header `{ heading = "Home",
   aside = "KoPanda" }`, and the rows of the feature's table:
   - **Edit layout:** icon `layout`; `run` shows
     `InfoMessage:new{ text = "Edit layout comes with the settings menus." }`, no timeout
     (`frontend/ui/widget/infomessage.lua:53`, `:283-290`).
   - **Open the file browser:** icon `folder`; `run` is `Home.close()`.
   - **Refresh weather:** icon `sun`; detail `Weather.age(Weather.reading(), os.time())`, plain; `run` is
     `Weather.tap(ctx.home)` (`weather.lua:220-236`).
   - **Wi‑Fi:** `local entry = { kind = "koreader", target = "wifi" }` and
     `local view = LauncherEntries.resolve(entry)` (`launcher_entries.lua:82-107`):
     - icon `view.icon`;
     - detail "On" for `ready`, "Off" for `off`, with `chip = "state"`;
     - `unavailable`: `muted`, with the detail `view.suffix`;
     - `run` is `LauncherEntries.run(entry, ctx)`. The label is "Wi‑Fi" as the boards write it
       (HoldHome:57); the faces' coverage of U+2011 is checked in the edge cases.
   - **KoPanda settings:** icon `settings`; `run` is `SettingsMenu.open()`.
   - **Sleep:** `local entry = { kind = "action", action = "suspend", label = "Sleep", icon = "moon" }`,
     resolved the same way. `unavailable` is greyed with "not available". `run` is
     `LauncherEntries.run(entry, ctx)`, which dispatches `suspend` (`frontend/dispatcher.lua:94`) through
     the bridge (`dispatch_bridge.lua:36-58`).

   The age is read when the sheet opens, from `os.time()` rather than `ctx.now` (the home's build time,
   `home.lua:181` at `f2ef10b`), so a home built an hour ago shows the true age.
8. **`main.lua`** requires `home_sheet` (`main.lua:22-46`).
9. **HOOKS.md:**
   - the `hold` gesture and its interval (`frontend/device/gesturedetector.lua:63`, `:1276-1287`);
   - Gestures' four hold-corner zones (`plugins/gestures.koplugin/main.lua:971-998`, `:1124-1139`,
     `:1287-1305`), `overrides_hold_corner` (`:1044`), and their unbound fall-through and
     `ignore_hold_corners` (`:245`, `:1316-1320`);
   - the default `hold_top_right_corner = { refresh_content = true }`
     (`plugins/gestures.koplugin/defaults.lua:11`), `refresh_content` (`dispatcher.lua:162`) and
     `FileManager.onRefreshContent` (`frontend/apps/filemanager/filemanager.lua:857-862`);
   - the dispatcher's `suspend`, `DeviceListener:onRequestSuspend` (`frontend/device/devicelistener.lua:458-460`;
     `filemanager.lua:414`) and `UIManager:suspend` (`frontend/ui/uimanager.lua:1679-1686`), with the
     emulator's simulation (`frontend/device/sdl/device.lua:165`, `:417-428`, `:462-468`) and the Kindle's
     `canSuspend` (`frontend/device/kindle/device.lua:402`).

## Surfaces

`kopanda.koplugin/home.lua`, or the module TW-l2ibo3 moved its gesture functions to (step 1);
`widgets.lua` (comment), `weather.lua`, `home_sheet.lua` (new), `main.lua`, `HOOKS.md`. Specs:
`spec/unit/gesture_routing_spec.lua`, `spec/unit/home_sheet_spec.lua` (new), `spec/unit/weather_spec.lua`,
`spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `gesture_routing_spec.lua` (C3), with `harness.gesture("hold", x, y)` (`spec/plugin_harness.lua:138-142`)
  on a home over a real file manager. Stub widget modules are registered for the slots as
  `home_layout_spec.lua` does for taps.
  - A hold at a point outside every slot's `rect` shows a sheet named `home` on top, the home beneath it.
  - A hold inside a slot whose module has `hold` calls it once with the home's ctx, the gesture and the
    slot's built widget, and shows no sheet when it returns nil. When it returns `false`, the home sheet
    shows.
  - A hold inside a slot whose module has no `hold` calls `SettingsMenu.open` once and shows no sheet.
  - A hold zone registered on the file manager at the top-right corner whose handler returns true (as
    Gestures' bound `refresh_content` does) wins: its handler runs once and no sheet or stub shows. One
    whose handler returns nil (unbound) lets the hold through to the home's step.
  - With KOReader's touch lock on (`UIManager:setIgnoreTouchInput(true)`, as the existing case at `:367`
    does), a hold opens nothing.
  - A `hold_release` at the same point after the home sheet shows changes nothing.
  - Closing the home while its sheet is shown leaves neither on the stack.
  - **Where `paint_ms` starts:** with `Sheet.show` spied, a hold on empty space passes `opts.started`, a
    number no later than the `time.monotonic()` recorded on entry to `HomeSheet.open` (spied), and so
    does a hold whose widget's `hold` returns `false`.
  - Every existing case passes unchanged (C11).
- `home_sheet_spec.lua` (C4), on a shown home over a real file manager:
  - **Order:** the six rows' labels and icons in the feature's order; the header "Home" with the aside
    "KoPanda"; the sheet's `name` and `band` are `home`.
  - **Edit layout** shows an `InfoMessage` with the draft text and a nil `timeout`, schedules nothing, and
    leaves the home shown.
  - **Open the file browser** closes the sheet and the home, leaving the file manager on top.
  - **Refresh weather** calls `Weather.tap` once with the home (spied). With a cache written as
    `weather_spec.lua` writes one, fetched 20 minutes before `os.time()`, the row's detail is
    "20 min ago". With none, it is "never fetched".
  - **Wi‑Fi:**
    - with `emulator_fake_wifi_connected` false (`spec/plugin_harness.lua:71`), the detail is "Off" and the
      icon `wifi_off`; with it true, "On" and `wifi`;
    - the row's chip is `state`;
    - a tap calls `NetworkListener:onToggleWifi` once, spied on `fm.networklistener`;
    - with `Dispatcher.getDisplayList` stubbed to list nothing, the row is muted with "not available" and a
      tap shows that note and dispatches nothing.
  - **KoPanda settings** calls `SettingsMenu.open` once.
  - **Sleep:** a tap sends `RequestSuspend` once to `fm.devicelistener` (its `onRequestSuspend` spied, so
    the harness doesn't suspend). With `Dispatcher.getDisplayList` listing nothing, the row is muted with
    "not available".
  - **Never writes:** after every case the settings file is byte-identical (or absent).
- `weather_spec.lua` (C4), `Weather.age`: nil gives "never fetched"; 0 s, 59 s and −30 s "just now";
  60 s "1 min ago"; 59 min "59 min ago"; 1 h "1 h ago"; 47 h "47 h ago"; 48 h "2 d ago"; 9 d "9 d ago".
- `failsafe_spec.lua` (C13): a slot whose `hold` raises: logged, no home and no sheet on the stack, the
  file manager on top.
- `hooks_doc_spec.lua` (C14) passes with the new requires: `home_sheet.lua`'s KOReader modules
  (`ui/uimanager`, `ui/widget/infomessage`) and the hold step's `ui/time` are named in `HOOKS.md`
  already, and any other one they gain is added; `home_sheet` collides with no KOReader module path.

## Edge cases

- A hold in the top menu zone over the date or clock: the menu zones don't take holds, so it reaches the
  hold step and opens the settings stub. The top-right corner (`defaults.lua:67`: x from 1106, y under
  210 on the Colorsoft) overlaps the right end of both looks' clock, about its last digit. With
  Gestures' default binding a hold there refreshes the file chooser instead; a hold on the rest of the
  clock opens the settings stub. The Notes flag it for the owner.
- A slot with a module whose build failed is blank (`home.lua:207-216` at `f2ef10b`) but still has its
  module, so a hold there opens the settings stub, not the home sheet. A slot with no module (an unknown
  widget id) is empty space.
- Two holds in a row: the second lands on the open sheet, which ignores holds.
- `Weather.tap` while offline calls `NetworkMgr:runWhenOnline` (`frontend/ui/network/manager.lua:698-709`),
  whose `beforeWifiAction` may ask to turn Wi‑Fi on (`:605-617`), as `Weather.tap`'s comment cites them
  (`weather.lua:215-217`). The sheet has closed first, so that prompt is over the home.
- Sleep in the emulator shows the screensaver (`sdl/device.lua:462-468`). On wake, `Resume` rebuilds the
  home (`home.lua:263-267` at `f2ef10b`). No sheet is open then, since the row closed it.
- The label "Wi‑Fi" uses U+2011, the boards' non-breaking hyphen. The launcher chose a plain hyphen for
  its label, because a look's faces might lack U+2011 (`launcher/feature.md` Notes). Check the four sheet
  faces for the glyph with `Fonts.face` and a `TextWidget` width. If any lacks it, use "Wi-Fi", as the
  launcher does, and say so in the PR.
