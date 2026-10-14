# The home's own gestures, and forwarding the rest to the file manager

## Approach

The home's full gesture routing, and, if the emulator shows it is needed, the wrapper that lets
dispatched actions reach the file manager's modules while the home is on top. KOReader citations are
at `e1fe1ac`, relative to `~/Projects/kodev/koreader/`; ennUI at `ae26fc4` and SimpleUI 2.7.5 (MIT) in the
emulator's `plugins/simpleui.koplugin`, both read, nothing copied.

1. **Why forwarding is needed.** `UIManager:sendEvent` offers an event to the topmost widget, then
   only to `active_widgets` and `is_always_active` widgets down the stack
   (`frontend/ui/uimanager.lua:962-1034`). With the home on top the file manager's handlers, its menu's
   top-zone zones (`frontend/apps/filemanager/filemanagermenu.lua:71-124`, registered on the menu module,
   `:76`) and the Gestures plugin's zones (registered on the file manager, `plugins/gestures.koplugin/main.lua:1287-1288`)
   never see a gesture. The file manager's one active widget, the screenshot module
   (`frontend/apps/filemanager/filemanager.lua:400-403`), still does if the home returns false.
2. **`Home:onGesture(ges)`** replaces the placeholder body from `home-lifecycle`, still in `pcall` (error:
   log, close the home, return true). With `fm = package.loaded["apps/filemanager/filemanager"].instance`,
   in order, each step returning true when it consumes:
   1. *Settings:* `ges.ges == "swipe"`, `direction == "north"`, starting inside `DSWIPE_ZONE_BOTTOM_EDGE`
      and outside `DSWIPE_ZONE_LEFT_EDGE` and `DSWIPE_ZONE_RIGHT_EDGE` (`defaults.lua:72-75`, read with
      `G_defaults:readSetting` as `filemanagermenu.lua:74-75` reads its zones): `settings_menu.open()`.
      The side bands are left out because Gestures binds frontlight and warmth to swipes up the left and
      right edges by default (`plugins/gestures.koplugin/defaults.lua:14-17`); Gestures has no
      bottom-edge-up binding (`defaults.lua:20-21`).
   2. *The file manager's menu:* `InputContainer.onGesture(fm.menu, ges)`
      (`frontend/ui/widget/container/inputcontainer.lua:266-285`) runs FileManagerMenu's own zones, so a
      tap or a south swipe in the top zone opens the menu with KOReader's own rules (`activate_menu`, read
      once in `FileManagerMenu:init`, `filemanagermenu.lua:51`; the edge-tab choice, `:1083-1114`). ennUI
      calls the menu's handlers with its own zone maths instead (`ennui_home.lua:597-618`).
   3. *Nothing to page:* a one-finger `swipe` west or east starting outside `DSWIPE_ZONE_TOP_EDGE` and
      `DSWIPE_ZONE_BOTTOM_EDGE` is consumed. Passed on, it would page the hidden file chooser through the
      file manager's full-screen swipe zone (`filemanager.lua:81-98`, `:474-482`), whose handler returns
      nothing, so later zones run too. Gestures binds one-finger west and east swipes only in the top and
      bottom edge bands (`plugins/gestures.koplugin/main.lua:1168-1195`).
   4. *The file manager's zones:* `InputContainer.onGesture(fm, ges)`: the zones registered on the file
      manager itself, every Gestures-plugin zone among them; corners, edges, multiswipes and two-finger
      gestures resolve exactly as in the file browser. ennUI's fallback is the same call
      (`ennui_home.lua:653-665`).
   5. *The placeholder's tap:* a `tap` nothing above consumed closes the home.
   Otherwise return false. With no `fm` (never expected while the home is up), steps 2 and 4 are skipped.
3. **Dispatched actions.** A forwarded Gestures action runs `Dispatcher:execute` (`gestures main.lua:1327`)
   → `UIManager:sendEvent` (`frontend/dispatcher.lua:1549`, `:1586`), offered to the home first. By
   reading, an event a file-manager module handles (`ShowHist`, `filemanagerhistory.lua:59`) is then
   lost: the home doesn't handle it, and the file manager is neither in an `active_widgets` list nor
   `is_always_active` (`uimanager.lua:988`, `:1006-1031`). Open fact, settled by the emulator spec below,
   written and run before any wrapper exists:
   - **lost** (the spec fails on `history_shown`): add `kopanda.koplugin/dispatch_bridge.lua`, which
     wraps `Dispatcher.execute` once per process, unless refused. With no home shown it calls the original
     straight through. With a home shown and a live file manager it sets `fm.is_always_active = true` for
     the call (`sendEvent` then offers the event the home didn't consume to the file manager,
     `uimanager.lua:1021-1027`; KOReader's comment there names "widgets that ... listen to Dispatcher
     events"), calls the original in `pcall`, restores the flag's previous value, and re-raises an error
     with `error(err, 0)` so behaviour is unchanged for a failing action. If the flag proves not enough
     (the spec still fails), the fallback is SimpleUI's: move the home to the bottom of
     `UIManager._window_stack` for the call and back after (`plugins/simpleui.koplugin/infra/sui_patches.lua:5501-5553`,
     MIT: reimplemented, or lifted with its notice); tell the two apart by the same spec.
   - **not lost** (the spec passes as written): no wrapper; the spec stays as the guard and `HOOKS.md`
     records why none is needed.
4. **`HOOKS.md`**: `sendEvent` routing, `InputContainer.onGesture` and touch zones, FileManagerMenu's
   zones and handlers, the file manager's swipe zone, Gestures zones on `self.ui` and its settings file,
   the `DSWIPE_*` defaults, the screenshot active widget, `Dispatcher.execute` and, if used,
   `is_always_active` (or the window stack).

## Surfaces

- `kopanda.koplugin/home.lua` (gesture routing)
- `kopanda.koplugin/dispatch_bridge.lua` (new, only if the emulator spec shows events lost),
  `kopanda.koplugin/main.lua` (installs it)
- `kopanda.koplugin/HOOKS.md`
- `spec/unit/gesture_routing_spec.lua`, `spec/emulator/gesture_forward_spec.lua`,
  `spec/emulator/scenarios/2-scenario-gesture-forward.lua` (new); `spec/unit/failsafe_spec.lua` (cases
  added)

## Tests

Written first, each run and seen failing before its implementation.

- `spec/unit/gesture_routing_spec.lua` (contract C9), with `spec/plugin_harness.lua`, synthetic
  gestures `{ ges, pos = Geom:new{ x, y, w = 0, h = 0 }, direction, distance, time = time.now() }`
  (the fields `GestureRange:match` and the zone handlers read, `frontend/ui/gesturerange.lua:21-51`)
  sent with `UIManager:sendEvent(Event:new("Gesture", ges))`:
  - a north swipe starting mid-width in the bottom eighth opens the settings stub's `InfoMessage`; the
    same starting in the bottom-left corner (inside the left edge band) does not;
  - a tap at the top centre opens the file manager's menu (`fm.menu.menu_container` set, the menu on
    top of the home); a south swipe starting there does too; with `activate_menu = "swipe"` set before
    `showFiles` the tap does not (`filemanagermenu.lua:1102-1107`);
  - a west swipe mid-screen is consumed and `fm.file_chooser.page` is unchanged; the home stays up;
  - a zone the spec registers on the file manager (`fm:registerTouchZones`, `inputcontainer.lua:144-181`)
    for a two-finger tap receives that gesture through the home;
  - a mid-screen tap still closes the home (placeholder);
  - the same bottom-edge north swipe sent with no home up (the file browser on top) opens no settings,
    and in a reader on a fixture EPUB opens no settings either.
- `spec/emulator/gesture_forward_spec.lua` (contract C10), colorsoft, `patches = { <gesture-forward
  scenario> }`, `shot_screen = "scenario"`, with `spec/emulator/scenarios/2-scenario-gesture-forward.lua`:
  - at patch time it writes `<KO_HOME>/settings/gestures.lua` binding `tap_right_bottom_corner` in
    `gesture_fm` to `{ history = true }` (the Gestures settings file and layout,
    `plugins/gestures.koplugin/main.lua:32`, `:227-249`; the `history` action, `frontend/dispatcher.lua:68`);
    patches run before plugins load (`reader.lua:190`);
  - on the first `home` signal it sends a synthetic tap at the bottom-right corner, waits two ticks, and
    emits `KoPandaSettled{ screen = "scenario", history_shown = <FileManager.instance.history.booklist_menu
    is shown>, home_shown = <the home still on the stack> }` (`filemanagerhistory.lua:59-61` keeps the
    list as `booklist_menu`);
  - the spec asserts `history_shown == true` and `home_shown == true`. Run first without any wrapper: the
    result settles the open fact in step 3 and is recorded in the PR.
- `spec/unit/failsafe_spec.lua` (C14): with the wrapper installed, an action that errors inside
  `Dispatcher.execute` re-raises the same error and leaves `fm.is_always_active` as it was; a forwarded
  gesture whose zone handler errors closes the home and leaves the file manager on top.

## Edge cases

- Whether the corner tap's zone wins over the placeholder's tap: step 4 runs before step 5, so a
  bound corner consumes the tap; an unbound corner tap closes the placeholder.
- A forwarded gesture whose action shows a widget (the history list) puts it above the home; closing it
  returns to the home, not the file browser.
- `InputContainer.onGesture(fm.menu, ...)` relies on the menu module's zones being registered, which
  happens on the file manager's `SetDimensions` (`filemanagermenu.lua:1120-1129`, emitted from
  `FileManager:init`, `filemanager.lua:433`); a home shown before that cannot exist, since it is shown
  after `Show`.
- Rotation re-registers the menu's zones (`filemanagermenu.lua:1120-1129`); the home reads the `DSWIPE`
  ratios against `Screen` at gesture time, so no re-registration is needed on its side.
- Non-touch input (keys) is not routed here; the Colorsoft is touch-only and keys keep KOReader's own
  handling.
- If the wrapper is installed, a refused shell never installs it; it is installed once per process
  whatever the number of file managers.
