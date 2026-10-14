# KOReader surfaces KoPanda touches

Every KOReader internal the plugin or its test harness reads or patches, with the `file:line`
it was read from at KOReader commit `e1fe1ac` (the pinned emulator build). Paths are relative
to `~/Projects/kodev/koreader/`; `base/` is koreader-base, `plugins/` the bundled plugins.
Upgrading KOReader walks this list.

## Plugin (`kopanda.koplugin/`)

### The `Show` event and plugin instances

- `frontend/apps/filemanager/filemanager.lua:418-429` (an instance per file manager, with
  `{ ui = self }`), `:379-389` (`registerModule` makes it an array child);
  `frontend/apps/reader/readerui.lua:464-478` (an instance per reader, every plugin).
- `onShow` in a file-manager instance is how the plugin learns the file browser is up; the
  propagation is the harness entry "The `Show` event reaching plugin instances" below.
  `onShow` returns nothing, since a true return stops `Show` reaching later modules
  (`frontend/ui/widget/container/widgetcontainer.lua:80-89`).

### `self.ui.document`, the reader test

- `frontend/apps/filemanager/filemanager.lua:418-429` (no `document`);
  `frontend/apps/reader/readerui.lua:464-478` (`document` passed).
- An instance is in the file manager when `self.ui.document == nil`; only there does it show
  or close a home.

### `package.path` during plugin load

- `frontend/pluginloader.lua:242` (plugin root prepended while `main.lua` is `dofile`d),
  `:269` (restored), `:283-286` (every enabled plugin's root appended afterwards).
- `main.lua` requires every KoPanda module at load time so a module name resolves to
  KoPanda's file, not another plugin's. `package.loaded` is one table per process, so
  `spec/unit/hooks_doc_spec.lua` checks that no KoPanda module path is also one in
  `frontend/`, `common/` or a bundled plugin.

### The handler sandbox

- `frontend/pluginloader.lua:117-164` (`HandlerSandbox`, logs and returns false on error),
  `:263` (applied to every `on*` function of the plugin module), `:479-488`
  (`createPluginInstance` pcalls `new`).
- Covers the plugin's own `onShow` and `onCloseWidget`. Nothing else KoPanda runs is
  protected by KOReader, so `init`, the deferred show and every home handler catch their own
  errors.

### `FileManager.instance`

- `frontend/apps/filemanager/filemanager.lua:447` (set at the end of `init`), `:839` (cleared
  in `onCloseWidget`).
- Read through `package.loaded` as `apps/filemanager/filemanager` when the deferred show runs,
  since the file manager can close between `Show` and that tick.

### `CloseWidget` on file-manager close

- `frontend/ui/uimanager.lua:300` (`UIManager:close` sends it);
  `frontend/apps/filemanager/filemanager.lua:819-826` (`onClose`, on quit), `:842-849`
  (`onShowingReader`, when a book opens).
- Reaches the plugin instance as an array child; the instance closes the home, which would
  otherwise keep KOReader from quitting.

### `CloseDocument`, the pre-build on book close

- `frontend/apps/reader/readerui.lua:870-900` (`onClose`), `:887` (sends `CloseDocument` to the
  reader's modules, the plugin instance among them), `:893` (closes the reader); the file
  browser follows from `ReaderUI:onHome` `:935-940`, `showFileManager` `:581-596` and the
  reader menu's file-browser tab `frontend/apps/reader/modules/readermenu.lua:65-74`.
- A reader instance's `onCloseDocument` builds the home into `Home.pending` (not shown) and
  returns nothing, so the event reaches later modules. The next file-manager `Show` puts the
  pending home up synchronously, before the UI loop's next `_repaint`
  (`frontend/ui/uimanager.lua:1537-1564`: `_checkTasks` at `:1543`, `_repaint` at `:1563`). A
  deferred show would lose when the close runs inside a scheduled task (KOReader's end-of-book
  file-browser action, `frontend/apps/reader/modules/readerstatus.lua:144-148`): `nextTick`
  schedules at a fresh `time.now()` (`uimanager.lua:416`), later than the `_now` that
  `_checkTasks` compares against (`:1082`, `:1090`), so the file browser would be painted first.

### `CloseDocument` with no file browser after: reload, switch, exit

- `frontend/apps/reader/readerui.lua:959` (`reloadDocument`), `:979` (`switchDocument`);
  `frontend/apps/reader/modules/readermenu.lua:386-393` (`exitOrRestart`).
- The pre-build happens there too and is wasted. A reader instance's `init` (the new reader of a
  reload or switch, `readerui.lua:464-478`) drops and frees the pending home; exit drops it with
  the process.

### `setRotationMode` in `showFiles`

- `frontend/apps/filemanager/filemanager.lua:1322` (`showFiles` resets the rotation before
  building the file manager), `:63-69` (`setRotationMode`).
- The screen can have another size at show than at close, so a pending home whose `dimen`
  differs from `Screen:getSize()` is dropped (`free()`,
  `frontend/ui/widget/container/widgetcontainer.lua:110-117`) and a fresh one built.

### `covers_fullscreen` in `UIManager:_repaint`

- `frontend/ui/uimanager.lua:1305-1316`.
- `_repaint` skips `paintTo` on every widget beneath the topmost `covers_fullscreen` one, so
  nothing of the file browser is painted under the home.

### `UIManager:nextTick` and `tickAfterNext`

- `frontend/ui/uimanager.lua:431-433`, `:447-456`.
- With no pending home the show runs from `nextTick`, landing over what `reader.lua:291-300`
  shows synchronously after `showFiles` (a pending home is shown at once, see `CloseDocument`
  above); the settled signal runs from `tickAfterNext`, past the next repaint (the
  harness entry for `scheduleIn`, `nextTick` and `tickAfterNext` has the details). A failed
  paint closes the home from `nextTick`.

### `UIManager:show`, `close` and `isWidgetShown`

- `frontend/ui/uimanager.lua:229` (`show`, which sends `Show` at `:259`), `:290-360`
  (`close`, which sends `CloseWidget` at `:300`), `:881-888` (`isWidgetShown`).
- The home is shown and closed with `"full"`; a home that reached the stack before failing
  is taken off it.

### `UIManager.event_hook`, the settled signal

- `frontend/ui/uimanager.lua:53`; `frontend/ui/hook_container.lua:88-98` (`execute`, which
  runs nothing with no listener).
- After the home's first paint the plugin executes `KoPandaSettled` with `{ screen, paint_ms,
  prebuilt }`, once per home; the capture harness entry below is the listener.

### `G_defaults` keys `DTAP_ZONE_MENU` and `DTAP_ZONE_MENU_EXT`

- `defaults.lua:59-60`; read through `G_defaults:readSetting` as
  `frontend/apps/filemanager/filemanagermenu.lua:74-75` reads them.
- KOReader's top menu zones, as screen ratios. A tap inside them leaves the placeholder up.

### `PluginLoader:loadPlugins()` and plugin names, the coexistence check

- `pluginloader`: `frontend/pluginloader.lua:273-292` (`loadPlugins`, memoised at `:274`, the
  enabled list sorted by path at `:289`); `:210` and `:249` (a module's `.name` is its folder
  name without `.koplugin`); `:256-259` (a `name` in `_meta.lua` is ignored).
- The list is complete before any plugin instance exists: the file manager and the reader call
  `loadPlugins` before making instances (`frontend/apps/filemanager/filemanager.lua:418`,
  `frontend/apps/reader/readerui.lua:464`). Not `loaded_plugins`, which fills as instances are
  made (`frontend/pluginloader.lua:479-482`).
- `guards.lua` lowercases each name and refuses the shell for `simpleui`, `bookshelf` and
  `ennui` (a git clone of ennUI is `ennUI.koplugin`). An error reading the list refuses nothing.

### `InfoMessage`, the refusal and boot-guard notices

- `ui/widget/infomessage`: `frontend/ui/widget/infomessage.lua:47` (the class), `:52-53`
  (`text`, `timeout`), `:263-292` (`onShow` schedules the close when `timeout` is set).
- Shown from `UIManager:nextTick`. The refusal message has no timeout and is raised once per
  process from a file-manager instance. The boot guard's notice has a timeout of 8 s. The
  settings stub (`settings_menu.lua`) shows one with no timeout.

### The runtime state file, `settings/kopanda/state.lua`

- `datastorage`: `datastorage.lua:16-20` (`getDataDir`, `KO_HOME` when set), `:60`
  (`getSettingsDir`).
- `luasettings`: `frontend/luasettings.lua:21-48` (`open`: a missing or corrupt file reads as an
  empty table, after trying `.old`), `:89` (`readSetting`), `:102` (`saveSetting`), `:252-268`
  (`backup`: renames the file to `.old` when it is older than 60 s), `:270-275` (`flush`, which
  ignores the write's result).
- `frontend/util.lua:1124-1143` (`util.writeToFile`: `io.open` on the path, so a missing
  directory fails, and the failure is only returned).
- `libs/libkoreader-lfs`: KOReader's LuaFileSystem build (`base/thirdparty/koreader-lfs/CMakeLists.txt:19`);
  `lfs.mkdir` and `lfs.attributes`, as `frontend/util.lua:875` uses them.
- `state.lua` makes `settings/kopanda/` before each write and checks it is a directory, since
  `flush` would fail there silently, and after the write reads the file back with `dofile` (the
  format `writeToFile` writes with `lua_dofile_ready`, `frontend/util.lua:1125-1128`) to catch a
  read-only file or folder or a full disk. The boot guard's `boot_pending` lives here, not in the
  schema.

### `InputContainer` gesture and paint dispatch

- `frontend/ui/widget/container/inputcontainer.lua:52` (`InputContainer`), `:73-99`
  (`paintTo`), `:266-285` (`onGesture`); `frontend/ui/uimanager.lua:962-1034` (`sendEvent`
  gives the topmost widget the gesture first).
- The home overrides `onGesture` and `paintTo`, each calling through a `pcall`: KOReader does
  not sandbox the home, so an error there would reach the UI loop.

### Main menu registration, both apps

- `frontend/apps/filemanager/filemanagermenu.lua:1136-1143` and
  `frontend/apps/reader/modules/readermenu.lua:560` (`registerToMainMenu`);
  `frontend/apps/filemanager/filemanagermenu.lua:851-856` and
  `frontend/apps/reader/modules/readermenu.lua:341` (each registered widget's `addToMainMenu` is
  pcalled with the `menu_items` table); the pattern of `plugins/hello.koplugin/main.lua:23-30`.
- An instance that isn't refused registers from `init`; `self.ui.menu` exists by then, since
  both apps register their menu module before making plugin instances
  (`frontend/apps/filemanager/filemanager.lua:404`, :418-429;
  `frontend/apps/reader/readerui.lua:176`, :464-478).

### The cached menu order, `ui/elements/filemanager_menu_order`

- `frontend/apps/filemanager/filemanagermenu.lua:858-862` (`setUpdateItemTable` sorts the menu
  against the require-cached table); `frontend/ui/plugin/insert_menu.lua:1-19` (cached for
  inserts like this one); `frontend/ui/elements/filemanager_menu_order.lua:4-11`
  (`KOMenu:menu_buttons`).
- `menu_entries.lua` inserts `kopanda_home` at index 2 of `KOMenu:menu_buttons` when absent and
  sets `kopanda_home = {}` in the table, the empty order entry the reader's file-browser tab
  has (`frontend/ui/elements/reader_menu_order.lua:228`). Bookshelf inserts its tab the same way
  (`plugins/bookshelf.koplugin/main.lua:605-618` in the emulator's install; AGPL, read only).

### `ui/menusorter`: the user's order file and orphans

- `frontend/ui/menusorter.lua:22-32` (`MenuSorter:readMSSettings`, which `dofile`s
  `settings/filemanager_menu_order.lua`), `:34-43` (`mergeAndSort` copies the user's top-level
  entries into the cached order, `:37-39`), `:60` and `:70-72` (an id with no order entry
  becomes a plain item), `:139-146` (a top-level item without `sub_item_table` is dropped),
  `:161-185` (orphans go to the end of their `sorting_hint` menu, or into tab 1 without one).
- With a user list in that file, the tab is added only when the list names `kopanda_home`,
  and the user's list is left alone. The file is read at every menu build.
- `frontend/ui/elements/filemanager_menu_order.lua:122-136` and
  `frontend/ui/elements/reader_menu_order.lua:176-191`: Tools ends with "More tools", so the
  KoPanda entry, with `sorting_hint = "tools"` and text, lands after it.

### `filemanagermenu_tab_index`

- `frontend/apps/filemanager/filemanagermenu.lua:1021` and `:1087` (read), `:1051-1052`
  (saved on close); `:1007-1009` and `:1084-1086` (both readers build the item table first,
  which runs `addToMainMenu`); `:1083-1100` (`_getTabIndexFromLocation`, far-left and
  far-right tabs).
- On the first insert in a profile a saved index of 2 or more is incremented, once, after
  `menu_tab_shifted` is stored in `settings/kopanda/state.lua`. Not with a user's own order.

### `TouchMenu` tab callbacks and `remember`

- `frontend/ui/widget/touchmenu.lua:776-792` (`switchMenuTab` runs a tab's `callback`, then
  shows its empty item table, which returns early at `:671-673`), `:452-464` and `:777-779`
  (`remember = false`: the index is not kept, and a saved index on that tab opens tab 1);
  `:913-926` (an item's callback runs before the menu closes).
- The Home tab is `{ icon = "home", remember = false, callback }`, the shape of `plus_menu`
  (`frontend/apps/filemanager/filemanagermenu.lua:838-849`) and the reader's file-browser tab
  (`frontend/apps/reader/modules/readermenu.lua:65-74`), with the icon
  `resources/icons/mdlight/home.svg`. Its callback closes the menu with
  `FileManagerMenu:onCloseFileManagerMenu` (`frontend/apps/filemanager/filemanagermenu.lua:1049-1056`)
  and goes home. The Tools items act from `UIManager:nextTick`. Each callback catches its own
  errors.

### `dispatcher`: the KoPanda: home action

- `frontend/dispatcher.lua:665-671` (`registerAction`, a no-op when the name exists), `:8-32`
  (fields; `general = true` as the built-in actions at `:65-85` have), `:585-586` and `:645`
  (`DispatcherRegisterActions` is broadcast once, from `Dispatcher:init`, which Gestures calls
  from its `init`, `plugins/gestures.koplugin/main.lua:219`), `:751-756` (`getNameFromItem`),
  `:1586` (a `none` action is sent with `UIManager:sendEvent`).
- `kopanda_home` sends `KoPandaHome`; it is registered from `init` and from
  `onDispatcherRegisterActions`, never by a refused instance. `UIManager:sendEvent` offers the
  event to the topmost widget first (`frontend/ui/uimanager.lua:962-1034`, `:988`), so a home
  that is up consumes it.

### `ReaderUI:onHome`

- `frontend/apps/reader/readerui.lua:935-940`.
- In the reader, the action and Tools › KoPanda › Home close the book and show the file
  manager, whose `Show` brings the home.

### Widget and support modules

- `ui/widget/container/widgetcontainer`: `frontend/ui/widget/container/widgetcontainer.lua:19`
  (the plugin's base class).
- `ui/widget/container/inputcontainer`: `frontend/ui/widget/container/inputcontainer.lua:52`
  (the home's base class).
- `ui/widget/container/framecontainer`: `frontend/ui/widget/container/framecontainer.lua:27`
  (`width`, `height`, `background`), `:104` (`paintTo`).
- `ui/widget/container/centercontainer`: `frontend/ui/widget/container/centercontainer.lua:7`.
- `ui/widget/verticalgroup`: `frontend/ui/widget/verticalgroup.lua:8`.
- `ui/widget/verticalspan`: `frontend/ui/widget/verticalspan.lua:6`.
- `ui/widget/textwidget`: `frontend/ui/widget/textwidget.lua:27` (`text`, `face`).
- `ui/font`: `frontend/ui/font.lua:269-276` (`getFace` scales the size by
  `Screen:scaleBySize` itself).
- `ui/geometry`: `frontend/ui/geometry.lua:37` (`Geom:new`), `:255-266` (`contains`).
- `ffi/blitbuffer`: `base/ffi/blitbuffer.lua:2717` (`COLOR_WHITE`).
- `ui/uimanager`: the entries above.
- `ui/time`: `frontend/ui/time.lua:149` (`to_ms`), `:249` (`monotonic`).
- `device`: `frontend/device/generic/device.lua:332` (`Screen:getSize`);
  `base/ffi/framebuffer.lua:414` (`scaleBySize`).
- `logger`: `frontend/logger.lua:93-98` (`err`); see the harness entry `logger` below.

## Capture harness (`spec/emulator/`)

### `UIManager.event_hook`

- `frontend/ui/uimanager.lua:53`; `frontend/ui/hook_container.lua:34-41` (`register`),
  `:88-98` (`execute`).
- A `HookContainer`. The capture patch registers a `KoPandaSettled` listener and the plugin
  under test executes it with `{ screen, paint_ms, prebuilt }`. The patch shoots on the first
  signal whose `screen` is `KOPANDA_SHOT_SCREEN` (default `home`) and copies the signal's
  string, number and boolean arguments into the sidecar. Listeners run in registration order
  (`hook_container.lua:94-96`), and a listener may execute the hook again from inside its own
  call (the book-close scenario sends its `scenario` signal from inside a `home` one).

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
- `2-kopanda-capture.lua` registers its listener before any plugin code runs. A capture's
  extra patches (`capture{ patches }`) must also start with `2-`; late patches run in
  natural-sort order of their names (`frontend/userpatch.lua:82`).

### The book-close scenario (`spec/emulator/scenarios/2-scenario-book-close.lua`)

- `FileManager.paintTo`: `FileManager` defines none and inherits
  `frontend/ui/widget/container/inputcontainer.lua:73`; the scenario wraps it at patch time
  with a counter armed from the close to the home's settled signal.
- `FileManager.instance.file_chooser.path`: `frontend/apps/filemanager/filemanager.lua:138-155`
  (`path = self.root_path`); the library the scenario takes its one book from.
- `ReaderUI:showReader(file)`: `frontend/apps/reader/readerui.lua:616`; a fresh profile has no
  archived sidecar, so no restore prompt (`:643-667`); an unsupported file shows a message and
  returns to the file manager (`:668-672`), which the scenario's 10 s poll reports as an error.
- `ReaderUI.instance`: set at the end of `init` (`readerui.lua:546`), cleared in
  `onCloseWidget` (`:900-908`); polled with its `document` until the book is open.
- `ReaderUI:onHome()`: `readerui.lua:935-940` (`setSuspendRepaints(false)`, `onClose`,
  `showFileManager`); called from a scheduled task, as KOReader's end-of-book file-browser
  action runs from `nextTick` (`frontend/apps/reader/modules/readerstatus.lua:144-148`).
- `document_metadata_folder`: `frontend/docsettings.lua:102` (default `doc`, the `.sdr`
  sidecar beside the book), so the spec opens a copy of a fixture book outside
  `spec/fixtures/library/`.

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
