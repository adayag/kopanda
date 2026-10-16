# The panel's controls: light and warmth steps, toggles, close-first actions and their routing

## Approach

Every area of the panel acts, by the routes KOReader's own menus take, over the home and over the bare file
browser, and the sheet follows the radio on KOReader's network events. Starts after
`bars/quick-settings/panel`. Repo lines on `main` at `e6f2912`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`; cwngsync at `df90d5e` of
`https://github.com/new-usemame/cwngsync.koplugin`. The feature's "Taps and holds", "Routing" and "Failure
behaviour" are the spec.

1. **Steps**, in `quick_settings.lua`, each reading the power device fresh at the tap:
   - `set_brightness(n)`: `n` clamped to `[0, powerd.fl_max]`, then
     `UIManager:broadcastEvent(Event:new("SetFlIntensity", n))` (`frontend/device/devicelistener.lua:116-125`).
     Minus tap `frontlightIntensity() − 1`, plus tap `+ 1` (from 0 when off, so plus turns it on at 1); minus
     hold 0, plus hold `fl_max`.
   - `set_warmth(n)`: `n` clamped to `[fl_warmth_min, fl_warmth_max]`, then
     `broadcastEvent(Event:new("SetFlWarmth", n))` (`:156-165`), `n` native. Minus/plus tap ∓1 from
     `toNativeWarmth(frontlightWarmth())`; holds the bounds.
2. **Toggles** (stay open): Night, `broadcastEvent(Event:new("ToggleNightMode"))`
   (`frontend/ui/elements/common_settings_menu_table.lua:266-271`); Rotation lock,
   `G_reader_settings:flipNilOrFalse("lock_rotation")` (`frontend/ui/elements/screen_rotation_menu_table.lua:73-75`);
   Wi‑Fi, KOReader's menu logic (`frontend/ui/network/manager.lua:899-915`): `NetworkMgr:queryNetworkState()`,
   then `toggleWifiOff(cb, true)` when `is_wifi_on and is_connected`, `promptWifi(cb, false, true)` when on and
   not connected, else `toggleWifiOn(cb, false, true)`, `cb` being `Sheet.redraw` in `pcall`.
3. **Close-first** areas (`close_first = true`): Sync books runs `LauncherEntries.run{ kind = "plugin", plugin =
   "cwngsync", action = "cwngsync_sync_now", label = "Sync books" }`; Sleep runs `LauncherEntries.run{ kind = "action", action =
   "suspend", label = "Sleep" }` (the home sheet's entry, `home_sheet.lua:16`); Screenshot runs `UIManager:forceRePaint()`
   (`frontend/ui/uimanager.lua:1404-1406`), then `LauncherEntries.run{ kind = "action", action = "screenshot", label = "Screenshot" }`.
   A greyed cell's area is close-first too and runs its own entry, so `LauncherEntries.run` shows the
   launcher's note (`launcher_entries.lua:171-179`); for Wi‑Fi that entry is the launcher's
   `{ kind = "koreader", target = "wifi" }`. `LauncherEntries.run` re-checks availability, so a plugin gone
   since the sheet opened also gives its note.
4. **Refresh events:** the spec's `refresh_on = { "NetworkConnected", "NetworkDisconnected" }` (the sheet-body
   hook), as the home redraws on them (`home.lua:112-125`).
5. **Holds** only on the four buttons; cells have no `hold`.
6. **`HOOKS.md`**, the section "The quick-settings sheet": the events and their handlers
   (`devicelistener.lua:14-27`, `:58`, `:116-125`, `:156-165`, `:458-460`; `common_settings_menu_table.lua:266-271`),
   the power device's setters and their normalising (`frontend/device/generic/powerd.lua:144-167`, `:210-252`,
   `:318-323`; `frontend/device/kindle/powerd.lua:57-76`, `:124-178`), `NetworkMgr`'s toggles, query, prompt
   and events (`manager.lua:44-63`, `:74`, `:109`, `:408`, `:413`, `:433-457`, `:490`, `:651`, `:899-922`) and
   the emulator's fake (`frontend/device/sdl/device.lua:478-500`), `lock_rotation`
   (`screen_rotation_menu_table.lua:64-77`; `frontend/apps/filemanager/filemanager.lua:63-69`;
   `frontend/apps/reader/modules/readerview.lua:971`, `:1223`), `sendEvent`/`broadcastEvent`/`close`/
   `forceRePaint` and why each route is taken (`uimanager.lua:290-313`, `:962-1035`, `:1042-1061`,
   `:1404-1406`), the file manager's modules and always-active Screenshoter (`filemanager.lua:379-389`,
   `:400-403`, `:414-415`, `:418-429`), the Screenshoter's shot (`frontend/ui/widget/screenshoter.lua:50-70`),
   `screenshot` and `suspend` (`frontend/dispatcher.lua:86`, `:94`; `uimanager.lua:1679-1686`), and cwngsync's
   name, action and handler at `df90d5e` (`cwngsync.koplugin/main.lua:43`, `:282-283`, `:310-313`).

## Surfaces

`kopanda.koplugin/quick_settings.lua`, `kopanda.koplugin/HOOKS.md`. Specs:
`spec/unit/quick_settings_controls_spec.lua` (new), `spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `quick_settings_controls_spec.lua` (C5, C6), in the harness, every stub restored where it is made; taps and
  holds sent as `Gesture` events at an area's centre (`harness.gesture`):
  - **Kindle scales:** the power device's `fl_max` and `fl_warmth_max` set to 24 and `warmth_scale` to
    100/24 (a class field set by `new`, `frontend/device/generic/powerd.lua:38`), intensity 12, warmth 4
    native. Plus → 13, minus → 11, the value line follows and the sheet stays shown; from 24 plus stays 24;
    from 0 minus stays 0 and the light stays off; plus from off → on at 1; hold minus → off; hold plus → 24.
    Warmth likewise between 0 and 24, holds to the bounds. A spy on `DeviceListener.onSetFlIntensity` and
    `onSetFlWarmth` sees each call, proving the broadcast reached the file manager's listener.
  - **Night:** a tap flips `Screen.night_mode` and `night_mode`, and after a tick the sheet's variant is
    `night`; a second tap flips back. (Restored with the existing night cases' stubs, `spec/unit/sheet_spec.lua:711-833`.)
  - **Rotation lock:** a tap flips `lock_rotation` both ways and the cell's fill follows.
  - **Wi‑Fi:** with `emulator_fake_wifi_connected` true, a tap turns it false (the fake flips synchronously,
    `frontend/device/sdl/device.lua:489-496`), the cell reads "Wi-Fi off" after the redraw; after
    `harness.tick` past `scheduleIn(2)` the `NetworkDisconnected` broadcasts redraw it again (the fake and
    `disableWifi`'s callback each broadcast it, `frontend/device/sdl/device.lua:480-484`,
    `frontend/ui/network/manager.lua:407-411`, so assert at least one redraw, not exactly one) and still
    reach a spy on the home's handler; a second tap turns it on. `NetworkMgr` queries stubbed only as far as
    the emulator lacks them.
  - **Close-first:** Sync books with a stand-in module named `cwngsync` registered on the file manager
    (`fm:registerModule`, `filemanager.lua:379-389`, with an `onCWNGSyncSyncNow` spy), its name in
    `PluginLoader.loaded_plugins` and `cwngsync_sync_now` registered (`frontend/dispatcher.lua:665-685`, removed
    after): the spy runs once and the sheet is off the stack when it does. Sleep: `UIManager.suspend` stubbed,
    called once, the sheet closed first. Screenshot: `Screen.shot` stubbed to record whether a sheet is on the
    stack and whether `forceRePaint` has run since the close (a spy): none, and it has.
  - **Greyed:** with no `cwngsync`, a tap on Sync books closes the sheet and shows an `InfoMessage` reading
    "Sync books: the cwngsync plugin isn't loaded." — the launcher's wording for a plugin entry labelled
    "Sync books" (`launcher_entries.lua:144-145`).
  - **Raising action:** `NetworkMgr.queryNetworkState` stubbed to raise: logged, the sheet still shown.
  - **Over the bare file browser (C6):** each case above that reaches KOReader is repeated with
    `harness.show_fm()` and no home shown (`Home.shown` nil), and once over the home.
- `failsafe_spec.lua` (C10): a raising `QuickSettings.open` called the way a launcher tap calls it is logged
  and closes the home onto the file browser, which is on top and handling input (`launcher_entries.lua:153-157`,
  `home.lua:338-346`); a quick-settings sheet whose `body` raises at its first paint is closed and
  logged, the file manager on top over the bare file browser.
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C11) pass.

## Edge cases

- Steps past the bounds send nothing new: `setIntensity` returns early on an unchanged value
  (`frontend/device/generic/powerd.lua:218`), `setWarmth` likewise (`:244`).
- `onSetFlWarmth` clamps only to 0–100 before `fromNativeWarmth` (`devicelistener.lua:156-165`); the sheet's
  own clamp to the native bounds is what keeps warmth on the Kindle's 0–24.
- On the Kindle, `toggleWifiOn` may show KOReader's network list over the sheet
  (`frontend/device/kindle/device.lua:424-447`); the sheet stays beneath it and redraws on the callback.
- A failed connection broadcasts nothing (`manager.lua:56`): the cell shows `isWifiOn()` at the last redraw,
  which is the radio's real state (D13). Open fact F2 is the owner's to record on the device.
- The DeviceListener's frontlight handlers exist only on a device with a frontlight (`devicelistener.lua:58`);
  the bars aren't shown without one, so no broadcast goes unheard.
- Night over the bare file browser: the broadcast reaches the file manager's listener, whose full repaint
  rebuilds the sheet at its next paint (`sheet.lua:544-553`).
- No timers: the only waits are KOReader's own (the Wi‑Fi fake's `scheduleIn`, the network callback).
