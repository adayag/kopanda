# KOReader surfaces KoPanda touches

Every KOReader internal the plugin or its test harness reads or patches, with the `file:line`
it was read from at KOReader commit `e1fe1ac` (the pinned emulator build). Paths are relative
to `~/Projects/kodev/koreader/`; `base/` is koreader-base, `plugins/` the bundled plugins.
Upgrading KOReader walks this list.

## Capture harness (`spec/emulator/`)

### `UIManager.event_hook`

- `frontend/ui/uimanager.lua:53`; `frontend/ui/hook_container.lua:34-41` (`register`),
  `:88-98` (`execute`).
- A `HookContainer`. The capture patch registers a `KoPandaSettled` listener and the plugin
  under test executes it with `{ screen, paint_ms }`.

### `Screen:shot(path)`

- `base/ffi/framebuffer.lua:566-581`.
- Writes the framebuffer as a PNG and returns `ok, err`; `Screen` is `require("device").screen`.

### `UIManager:quit(exit_code)`

- `frontend/ui/uimanager.lua:892-898`; `:1657-1672` (`run` returns it); `reader.lua:305-328`
  (`os.exit`).
- The patch quits with no code after a save and with 3 at the settle cap; the code becomes the
  process exit status, which the driver reports as the settle cap.

### `UIManager:scheduleIn`, `nextTick`, `tickAfterNext`

- `frontend/ui/uimanager.lua:413-418`, `:431-433`, `:447-456`; `_checkTasks` `:1081-1106`;
  `handleInput` `:1537-1561`.
- Tasks run only from the UI loop, so the patch's watchdog cannot fire while KOReader hangs:
  the driver's kill covers that.
- `tickAfterNext` re-queues its action through `nextTick` at `time.now()`; the action lands
  past the next `_repaint` only when `time.now()` has advanced past the `_now` that
  `_checkTasks` sampled at `:1082`, since a task due at `_now` runs in the same pass
  (`:1088-1097`).
- `time.now` is `time.monotonic_coarse` (`frontend/ui/time.lua:300`), which on macOS is
  `CLOCK_MONOTONIC` at µs resolution (`:185-199`). The probe's capture was painted in 10 of
  10 runs.

### The `Show` event reaching plugin instances

- `frontend/ui/uimanager.lua:259` (`UIManager:show` sends `Show`).
- `frontend/ui/widget/container/widgetcontainer.lua:80-107` (propagation to array children,
  a true return stops it).
- `frontend/apps/filemanager/filemanager.lua:384` (`registerModule` inserts as array child),
  `:418-429` (plugins instantiated in `FileManager:init`), `:1312-1331` (`showFiles` calls
  `UIManager:show`).
- A `WidgetContainer` plugin with `is_doc_only = false` gets `onShow` on the file manager's
  first show. `FileManager` defines no `onShow` of its own.

### `PluginLoader:loadPlugins()`

- `frontend/pluginloader.lua:273-291`.
- Memoised (`:274`); returns the enabled modules, each with `.name` (`:249`). The patch lists
  their names in the sidecar.

### `plugins_disabled`

- `frontend/pluginloader.lua:175`, `:210-215`.
- A table keyed by plugin folder name without `.koplugin`; a disabled plugin's `_meta.lua` is
  loaded instead of `main.lua`.

### `extra_plugin_paths`

- `frontend/pluginloader.lua:177-199`.
- Present: only the listed paths join `plugins/`. Absent: `<KO_HOME>/plugins/` is added and
  the key written. The scratch profile leaves it absent.

### `color_rendering`

- `reader.lua:195-203` (first-run notice when absent on a colour screen), `:206-223` (blocking
  ConfirmBox when true on a grey screen); `frontend/device/generic/device.lua:264-270`.
- Written as the profile's `color`: true on colorsoft, false on paperwhite.

### `EMULATE_BW_SCREEN`

- `base/ffi/framebuffer_SDL3.lua:21-24`.
- Non-empty makes `Device:hasColorScreen()` false; the patch records that value as the
  sidecar's `color`.

### `EMULATE_BB_TYPE`

- `base/ffi/framebuffer_SDL3.lua:69`, `:85`.
- Cleared so the framebuffer is `BBRGB32`.

### `EMULATE_READER_W/H/DPI`, `EMULATE_READER_FORCE_PORTRAIT`

- `base/ffi/SDL3.lua:118-119`; `frontend/device/sdl/device.lua:188-191` (presence is what
  counts).
- Screen size per profile, portrait locked.

### SIGTERM handling

- `base/ffi/SDL3.lua:719-723`.
- SDL3 turns SIGTERM into `SDL_EVENT_QUIT`, which the input loop translates to an Alt+F4 key
  event; a hung emulator never services it, so the driver's killer follows SIGTERM with
  SIGKILL 5 s later.

### `KO_HOME`

- `datastorage.lua:19-20` (data dir), `:60` (`settings/`), `:79` (`patches/`), `:97-123`
  (subdirectories created, not `patches/`); `reader.lua:40` (`settings.reader.lua`).
- The scratch profile. The driver creates `patches/`, `plugins/` and `settings/` itself.

### Userpatches

- `frontend/userpatch.lua:13` (`late` is prefix `2`), `:38` (read from `<KO_HOME>/patches`),
  `:73` (name match), `:89-99` (a failing patch shows an InfoMessage); applied at
  `reader.lua:190` before `showFiles` at `:250`.
- `2-kopanda-capture.lua` registers its listener before any plugin code runs.

### `logger`

- `frontend/logger.lua:71-90`.
- `logger.info` writes `<date> INFO  ...` to stdout; every capture line starts with
  `KOPANDA_SHOT:`.

### The directory argument

- `reader.lua:145-151`, `:248-251`; `:257-261` (quickstart guide only without one).
- Opens the file manager on the library and skips the quickstart guide.

### coverbrowser's cache database

- `plugins/coverbrowser.koplugin/main.lua:88-98` (`BookInfoManager:getSetting` and `saveSetting`
  at startup; on a seeded profile `getSetting`, `bookinfomanager.lua:278`, opens the connection from
  `loadSettings` at `:264`; on an unseeded one `saveSetting` from `main.lua:91` opens it at `:297`;
  either way `:201-206` runs `createDB` on the first open).
- `plugins/coverbrowser.koplugin/bookinfomanager.lua:22` (`BOOKINFO_DB_VERSION = 20201210`),
  `:134` (`settings/bookinfo_cache.sqlite3`), `:166-195` (`createDB`: schema is a no-op on an
  existing file, a lower `user_version` shows "Book info cache database updated." for 3 s).
- The driver seeds the file with the current `user_version`, through the emulator's luajit
  and `common/lua-ljsqlite3/init.lua`.

### `rapidjson`

- `common/rapidjson.so`.
- `encode` in the patch, `decode` in the driver.
