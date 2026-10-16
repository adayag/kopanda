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
  since the file manager can close between `Show` and that tick, and the same way at gesture
  time by the home and at call time by the dispatcher wrapper.

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
- A reader instance's `onCloseDocument` first records the book's chapter for the featured book
  (the featured book entry below), then builds the home into `Home.pending` (not shown) and
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
  above); the settled signal and the show's `finished` run from a `nextTick` that the home's
  first `paintTo` schedules, past that `_repaint`, or at once from `onCloseWidget` for a home
  closed before it painted. Nothing is scheduled before the paint, so a home under a
  `covers_fullscreen` window waits without a task. A `tickAfterNext` from the show could land
  before the paint and tell `finished` the home hadn't painted (the harness entry for
  `scheduleIn`, `nextTick` and `tickAfterNext` has the details). A failed paint closes the home
  from `nextTick`.

### `UIManager:show`, `close` and `isWidgetShown`

- `frontend/ui/uimanager.lua:229` (`show`, which sends `Show` at `:259`), `:290-360`
  (`close`, which sends `CloseWidget` at `:300`), `:881-888` (`isWidgetShown`).
- The home is shown and closed with `"full"`; a home that reached the stack before failing
  is taken off it.
- The editor frame (`editor.lua`) is shown and closed the same way, with `"full"`, and is
  `covers_fullscreen` as the home is, so nothing beneath it is painted while it is up; an editor
  that reached the stack before failing is taken off it.

### `UIManager.event_hook`, the settled signal

- `frontend/ui/uimanager.lua:53`; `frontend/ui/hook_container.lua:88-98` (`execute`, which
  runs nothing with no listener).
- After the home's first paint the plugin executes `KoPandaSettled` with `{ screen, paint_ms,
  settle_ms, prebuilt }`, once per home; the capture harness entry below is the listener.
  `paint_ms` runs from the start of the show path to the end of the home's first `paintTo`;
  `settle_ms` runs on to the signal, which the first `paintTo`'s `nextTick`
  (`uimanager.lua:431-433`) queues behind tasks already due on the tick after the paint, such
  as coverbrowser's background extraction (`plugins/coverbrowser.koplugin/covermenu.lua:119`,
  a fork).

### The swatch screen

- `G_reader_settings` key `night_mode`: `frontend/device/devicelistener.lua:14-27` (KOReader's
  night-mode toggle writes it); read with `isTrue` to show the inversion note.
- `base/ffi/blitbuffer.lua:1704-1724` (`paintRect` greys any colour through `getColor8`),
  `:1827` (`paintRectRGB32`), `:2118-2126` (`paintBorderRGB32`): the panel fills and chips paint
  through the RGB32 variants.
- `frontend/ui/widget/textboxwidget.lua:854-906` (an RGB `fgcolor` or `bgcolor` gets an RGB32
  buffer on a colour screen, the glyphs blitted with `colorblitFromRGB32`), `:50` (`bgcolor`
  white by default), `:861-864` (the buffer filled with it): text in a palette's ink goes
  through `TextBoxWidget` with the panel's paper as `bgcolor`.
  `frontend/ui/widget/textwidget.lua:345-375` (`colorblitFrom`, which greys) is why not `TextWidget`.
- `frontend/ui/widget/iconwidget.lua:58-62` (given `file`, an `IconWidget` is a plain
  `ImageWidget`); `frontend/ui/widget/imagewidget.lua:202-226` (without `alpha` an icon is
  flattened onto white), `:518-557` (`paintTo` alpha-blends with `alpha`).
- `Screen:isColorEnabled` (`frontend/device/generic/device.lua:265-271`): when false every token
  is drawn as its `getColor8` luminance grey (`base/ffi/blitbuffer.lua:464-467`), as a grey
  panel's 8-bit framebuffer would show it; the emulator's grey profile keeps an RGB32
  framebuffer (`base/ffi/framebuffer_SDL3.lua:20-23`, `:85-86`), where an RGB32 paint keeps its hue.
- `frontend/ui/widget/verticalgroup.lua:15-31` (`getSize` fixes the layout on first call), so
  the swatch measures each group once it is complete.
- `TextBoxWidget.vertical_string_list`, the wrapped lines, one entry per line, filled at init
  (`frontend/ui/widget/textboxwidget.lua:337`, `:420`): `swatch.lua` reads its length to keep the
  "lacks" list in the spare cell only when it fits on one line.
- Shown and closed like the home: `covers_fullscreen`, `UIManager:show`/`close` with `"full"`,
  a full-screen tap zone through `registerTouchZones`
  (`frontend/ui/widget/container/inputcontainer.lua:144`), `onGesture` (`:266`) and `paintTo`
  (`:73`) each in a `pcall`, and the settled signal with `screen = "swatch"` and `paint_ms`.

### `G_defaults` keys `DTAP_ZONE_MENU`, `DTAP_ZONE_MENU_EXT` and the `DSWIPE_ZONE_*` edges

- `defaults.lua:59-60` (`DTAP_ZONE_MENU`, `DTAP_ZONE_MENU_EXT`), `:72-75`
  (`DSWIPE_ZONE_LEFT_EDGE`, `DSWIPE_ZONE_RIGHT_EDGE`, `DSWIPE_ZONE_TOP_EDGE`,
  `DSWIPE_ZONE_BOTTOM_EDGE`); read through `G_defaults:readSetting` as
  `frontend/apps/filemanager/filemanagermenu.lua:74-75` reads them, against `Screen:getSize()`
  at gesture time, in `home_gestures.lua`. The home's own zones (touch lock entry below) cover
  the screen at the home's build size and test these bands in their handlers.
- Screen ratios. A tap inside the top menu zones leaves the home up. The swipe up that
  opens the settings menu starts in the bottom edge band and outside the left and right bands,
  where Gestures binds frontlight and warmth swipes by default
  (`plugins/gestures.koplugin/defaults.lua:14-17`; it binds nothing to a bottom-edge swipe up,
  `:20-21`). A west or east swipe outside the top and bottom bands is consumed.

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
- `Guards.enabled_shell_names` reads the same list afresh at pull time and gives those plugins'
  runtime names as loaded, case kept: the pull's `disable` list, which the apply patch writes
  into `plugins_disabled`, matched there by exact folder name (`frontend/pluginloader.lua:210-212`).
  An error reading the list gives none, logged.

### `InfoMessage`, the refusal, boot-guard and pull notices

- `ui/widget/infomessage`: `frontend/ui/widget/infomessage.lua:47` (the class), `:52-53`
  (`text`, `timeout`), `:263-292` (`onShow` schedules the close when `timeout` is set).
- Shown from `UIManager:nextTick`. The refusal message has no timeout and is raised once per
  process from a file-manager instance. The boot guard's notice has a timeout of 8 s.
- `push_notice.lua` shows the apply patch's result (applied, rolled back, failed, restore
  failed) with no timeout: over the first home of a process that painted, or, while another
  shell refuses the home, from a file-manager instance when nothing is on probation.

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
- The apply patch (below) also writes `boot_pending = false` here, through `LuaSettings` before
  any plugin loads, when it applies a pull and when it restores one, so the boot guard never
  skips the home that proves or reports the install.
- The Studio menu (below) keeps `studio_address` (the studio's host:port as typed, trimmed) and
  `studio_profile` (the profile id to pull) here. An emptied address clears its key:
  `saveSetting(key, nil)` sets it to nil (`frontend/luasettings.lua:102-105`), so `flush` leaves
  it out, and `State.set`'s read-back takes the absent key as the nil it was given.

### The settings file, `settings/kopanda/settings.lua`

- `datastorage` and `libs/libkoreader-lfs` as for the runtime state file above; `settings.lua`
  makes and checks the directory, writes, and reads the file back the same way.
- `luasettings`: `frontend/luasettings.lua:21-48` (`open`: a missing file reads as `{}`, a corrupt
  one falls back to `.old`, then `{}`), `:31-33` (a file returning any truthy non-table is taken
  as the data; `settings.lua` reads it as `{}` through `reset`, `:247-250`), `:89-99`
  (`readSetting` with a truthy default writes the default into the data, so `settings.lua` never
  passes one and falls back to the schema default itself), `:102` (`saveSetting`), `:252-268`
  (`backup`: the `.old` that `open` falls back to, written when the file is more than 60 s old;
  KOReader's recovery, kept), `:270-275` (`flush`, which ignores the write's result).
- `frontend/util.lua:1124-1143` (`util.writeToFile`), as for the state file.
- The file holds `schema_version` beside the keys. `settings.lua` migrates an older file on open
  and never writes a newer one, the version stamp included.
- `Settings._migrate` and `Settings._reset` are KoPanda's own seams for
  `spec/unit/settings_spec.lua`, not KOReader internals; they are named here because the hooks
  check flags every underscore access.

### The apply patch, `patches/1-kopanda-apply.lua`

- `push_apply.lua` is also the patch: `arm` copies it to `<data>/patches/1-kopanda-apply.lua`
  (`datastorage.lua:79-81`, `getPatchesDir`), refusing when `patches/.patches_disabled` exists
  (`frontend/userpatch.lua:39-40`, checked once per process; `applyPatches` then runs nothing,
  `:110-111`). The copy goes through `1-kopanda-apply.lua.tmp`, which the loader skips: it runs
  only names ending `.lua` (`:87`).
- Early priority: the prefix `1` (`frontend/userpatch.lua:11-12`), run by `runUserPatchTasks`
  (`:65-100`) under `pcall(dofile, fullpath)` (`:89`), whose failure is only logged (`:92`).
  `reader.lua:25-27` applies early patches before `G_reader_settings` is opened (`:39-40`), and
  plugins are discovered with the first file manager
  (`frontend/apps/filemanager/filemanager.lua:418-429`).
  `dofile` passes the chunk no arguments and `require` passes the module name, which is how the
  file tells its two uses apart (`spec/unit/push_apply_spec.lua`'s module cases).
- The push folder, `<data>/settings/kopanda/push/` (`datastorage.lua:60-62`, `getSettingsDir`):
  the stage, the rollback set, probation and the result. Device-local runtime state, not a
  setting.
- `plugins_disabled` in `settings.reader.lua`: a table keyed by plugin folder name
  (`frontend/pluginloader.lua:175`, matched by exact name at `:212`). The patch adds the stage's
  `disable` names and the restore puts the recorded value back (or deletes the key). Only an early
  patch can write it: KOReader writes `G_reader_settings` back at exit (`reader.lua:306-308`).
- `luasettings`: `frontend/luasettings.lua:21-48` (`open`: a missing or corrupt file falls back
  to `.old`, then `{}`), `:89` (`readSetting`), `:102` (`saveSetting`), `:108` (`delSetting`),
  `:252-275` (`flush`; its backup renames the file onto `<file>.old` at `:262`, KOReader's rename,
  not the patch's). Each write is read back with `dofile`, as `state.lua` does.
- `ffi/util`: `base/ffi/util.lua:223-241` (`copyFile` ignores write errors, so `arm` checks the
  copy's size), `:588` (`fsyncOpenedFile`), `:614` (`fsyncDirectory`) for the records, which are
  written to `<name>.tmp`, synced, and renamed onto a name removed first.
- `dump`: `frontend/dump.lua:68-72` (`dump(value, nil, true)`, keys in order); records are read
  back with `load` in an empty environment.
- `libs/libkoreader-lfs`: `symlinkattributes`, `dir`, `mkdir`, `rmdir` and `attributes`
  (LuaFileSystem, `base/thirdparty/koreader-lfs/CMakeLists.txt:19`); the purge never follows a
  link.
- `PushApply._move`, `PushApply._purge`, `PushApply._write_record` and
  `PushApply._set_reader_key` are KoPanda's own seams for `spec/unit/push_apply_spec.lua`, not
  KOReader internals; they are named here because the hooks check flags every underscore access.

### The Studio menu and the pull: `InputDialog`, `ButtonDialog`, `ConfirmBox`, `Restart`, `NetworkMgr`, `socketutil`, `socket.http`, `ffi/sha2`

- Tools › KoPanda › Studio is in both of `addToMainMenu`'s menus, before Swatches. Its items'
  texts are `text_func`s and Pull's state an `enabled_func`, read each time the menu draws
  (`frontend/ui/widget/touchmenu.lua:74-75`, `:1026-1028`); Address and Profile are
  `keep_menu_open` and call the menu's `updateItems` (`:671`) after a save (the settings menu
  entry above). Every item acts from `UIManager:nextTick` and catches its own errors.
- `ui/widget/inputdialog`: the Address dialog as the place search's (that entry above),
  `frontend/ui/widget/inputdialog.lua:583` (`getInputText`), `:640` (`onShowKeyboard`), with the
  hint `192.168.1.20:4490`; `util.trim` (`frontend/util.lua:52`) before it is saved.
- `ui/widget/buttondialog`: the profile chooser, one row per profile by name and Cancel, as the
  place search's chooser (that entry above, `frontend/ui/widget/buttondialog.lua:62-75`).
- `ui/widget/confirmbox`: the pull's confirm and the restart offer
  (`frontend/ui/widget/confirmbox.lua:45-51`, with `cancel_text` at `:49`, `:107-122`); the restart
  offer's `ok_text` is Restart and its `cancel_text` Later, whose default `cancel_callback` does
  nothing, so the stage stays armed for the next start.
- `ui/event`: `frontend/ui/event.lua:30` (`Event:new`). Restart broadcasts `Event:new("Restart")`
  with `UIManager:broadcastEvent` (`frontend/ui/uimanager.lua:1042`). `DeviceListener:onRestart`
  (`frontend/device/devicelistener.lua:454-456`) runs the app menu's `exitOrRestart`: the file
  manager's closes the menu and the file manager (`frontend/apps/filemanager/filemanagermenu.lua:998-1004`),
  the reader's closes the menu and then the reader from a `nextTick`
  (`frontend/apps/reader/modules/readermenu.lua:386-393`); then `UIManager:restartKOReader` quits
  with 85 (`frontend/ui/uimanager.lua:1765-1769`), and the Kindle's launcher starts KOReader again
  while it exits 85 (`platform/kindle/koreader.sh:333-340`).
- `ui/uimanager`: the "Pulling <id>…" note is painted with `forceRePaint` (`frontend/ui/uimanager.lua:1404`)
  before the pull blocks the UI loop, and closed after; no timer, no progress redraws.
- `ui/network/manager`, required at call time so a spec can stub it:
  `frontend/ui/network/manager.lua:713-719` (`runWhenConnected`: the callback now when connected,
  else `beforeWifiAction`, `:605-618`, which turns Wi-Fi on, waits or prompts as the user's
  `wifi_enable_action` says, then runs it). It needs a connection only, not DNS (`isOnline`,
  `:641-648`, is never called). Profile and Pull fetch inside it.
- `socketutil`: `frontend/socketutil.lua:32-33` (`FILE_BLOCK_TIMEOUT` 15 s, `FILE_TOTAL_TIMEOUT`
  60 s), `:52-62` (`set_timeout`), `:64-70` (`reset_timeout`, on every path, a raising request
  included), `:98-115` (`table_sink`, the manifest and the profile list), `:118-140` (`file_sink`,
  each file; it closes the file at the body's end, so `push_pull.lua` closes one a failed request
  left open). The sinks read the total timeout when made, so each is made after `set_timeout`.
- `socket.http`: `request` as the weather entry above, looked up at call time, with
  `Accept-Encoding: identity`; a status other than 200 refuses, a 409 for a file as "changed in the
  studio during the pull".
- `rapidjson`: `decode` as the weather entry above; a decoded object or array is a table either
  way, so `push_bundle.lua` takes a table with items 1..n for an array and checks every field's type.
- `ffi/sha2`: `base/ffi/sha2.lua:4356-4410` (`sha256ext`: with no message it returns an updater fed
  chunk by chunk, then called with no argument for the hex digest), `:5612` (`sha256`). Each file's
  sha256 and the bundle hash, the studio's `hashTree` framing, are streamed through it.
- `util`: `frontend/util.lua:855-883` (`makePath`, the download's folders).
- `libs/libkoreader-lfs`: `symlinkattributes` (each downloaded file must be a `file` with one
  link, `nlink`), `attributes` (sizes) and `currentdir` (LuaFileSystem,
  `base/thirdparty/koreader-lfs/CMakeLists.txt:19`).
- The plugin's own folder, `self.path`: `frontend/pluginloader.lua:248` (the loader sets the plugin
  module's `path` to its root), which is relative on the Kindle (`:24` `DEFAULT_PLUGIN_PATH =
  "plugins"`, `:177`, `:204`) under the launcher's working directory
  (`platform/kindle/koreader.sh:130`), and `<KO_HOME>/plugins//kopanda.koplugin` under `KO_HOME`
  (`:196`, `:204`). The pull makes it absolute with `lfs.currentdir()` and collapses doubled
  slashes for the stage's `plugin_dir`, and refuses a folder not named `kopanda.koplugin`.
- `patches/.patches_disabled`: `frontend/userpatch.lua:39-40` (checked once per process); the pull
  refuses before any request when it exists, as `PushApply.arm` does (the apply patch entry above).
- `datastorage`: `getDataDir` (`datastorage.lua:16-20`), the push folder and `patches/` under it.
- `PushApply._purge` and `PushApply._write_record` (the apply patch entry above) purge `download/`
  and the stage without following links, and write `staged.lua` as the patch's records are
  written; KoPanda's own seams, not KOReader internals.

### `InputContainer` gesture and paint dispatch

- `frontend/ui/widget/container/inputcontainer.lua:52` (`InputContainer`), `:73-99`
  (`paintTo`), `:266-285` (`onGesture`); `frontend/ui/uimanager.lua:962-1034` (`sendEvent`
  gives the topmost widget the gesture first).
- The home overrides `onGesture` and `paintTo`, each calling through a `pcall`: KOReader does
  not sandbox the home, so an error there would reach the UI loop.

### Gestures under the home: `sendEvent`, touch zones and the file manager's handlers

- `frontend/ui/uimanager.lua:962-1034` (`sendEvent`: the topmost widget at `:988`, then only
  `active_widgets` and `is_always_active` widgets down the stack, `:1006-1031`). With the home on
  top the file manager sees no gesture; its one active widget, the screenshot module
  (`frontend/apps/filemanager/filemanager.lua:400-403`), still does, since the home returns false
  for what it does not consume.
- `frontend/ui/widget/container/inputcontainer.lua:144-181` (`registerTouchZones`, zones per
  container, ordered by `overrides`), `:266-285` (`onGesture` runs a container's zones, then its
  `ges_events`). The home's route (`home_gestures.lua`) calls
  `InputContainer.onGesture(fm.menu, ges)`, then `InputContainer.onGesture(fm, ges)`.
- FileManagerMenu's zones: `frontend/apps/filemanager/filemanagermenu.lua:71-124`
  (`initGesListener`, the top-zone tap and swipe zones registered on the menu module itself),
  `:1120-1129` (registered from `SetDimensions`, which `FileManager:init` sends,
  `frontend/apps/filemanager/filemanager.lua:433`, and again on rotation), `:51`
  (`activate_menu`, read once in `init`), `:1102-1107` (`onTapShowMenu`), `:1109-1114`
  (`onSwipeShowMenu`, south only), `:1083-1100` (the far-left and far-right tabs).
- The file manager's own swipe zone: `frontend/apps/filemanager/filemanager.lua:81-98`
  (full screen), `:474-482` (`onSwipeFM` pages the file chooser; the zone's handler returns
  nothing, so later zones run too).
- The Gestures plugin registers its zones on the file manager (`plugins/gestures.koplugin/main.lua:1287-1288`,
  `self.ui:registerTouchZones`) and binds one-finger west and east swipes only in the top and
  bottom edge bands (`:1168-1195`); its actions run `Dispatcher:execute` (`:1327`).

### KOReader's touch lock: `setIgnoreTouchInput`, `_onGestureFiltered`, `isGestureAlwaysActive`

- `frontend/ui/widget/container/inputcontainer.lua:287-295` (`isGestureAlwaysActive`, false
  unless the Gestures plugin replaces it, `plugins/gestures.koplugin/main.lua:196-223`, by zone
  id), `:297-309` (`_onGestureFiltered`: only zones it approves, no `ges_events`), `:322-350`
  (`setIgnoreTouchInput` swaps `InputContainer.onGesture` for `_onGestureFiltered` and back;
  its comment at `:311-321` notes that a subclass overriding `onGesture` escapes the swap);
  `frontend/ui/uimanager.lua:142-145` (`UIManager:setIgnoreTouchInput`), `:268-271` (`show`
  lifts the lock for the widget shown).
- The home overrides `onGesture`, so its own steps, the swipe up to the settings menu, the
  closing tap and the hold, are touch zones on the home (`kopanda_home_swipe_up`,
  `kopanda_home_tap`, `kopanda_home_hold`, made in `home_gestures.lua`) run through
  `InputContainer.onGesture(home, ges)`: under the lock they match nothing and the settings
  message or sheet, whose `show` would lift the lock, never shows. A zone's handler only records
  its step; `HomeGestures.route` runs it in place, the closing tap and the hold after the
  forwarded steps. The forwarded steps go through `InputContainer.onGesture` too, so under
  the lock the file manager's zones the Gestures plugin marks always active still run. The
  lock's state is read nowhere: `UIManager._input_gestures_disabled` is private.

### `Dispatcher.execute`, the dispatch bridge

- `frontend/dispatcher.lua:1549` (`Dispatcher:execute`), `:1584-1586` (a `none` action's event
  goes out with `UIManager:sendEvent`); `frontend/ui/uimanager.lua:1021-1027` (`is_always_active`,
  whose comment names widgets that "listen to Dispatcher events").
- The emulator showed an action dispatched from the home lost (History, `ShowHist`,
  `frontend/apps/filemanager/filemanagerhistory.lua:59`). `dispatch_bridge.lua` wraps
  `Dispatcher.execute` once per process, from the first instance that isn't refused: with a home
  shown and a live file manager it sets `fm.is_always_active = true` for the call and puts the
  previous value back after, re-raising an action's error unchanged; otherwise it calls the
  original straight through. An error in its own work is logged and the original runs.
  `spec/plugin_harness.lua` puts the unwrapped function back on each load, as a new process has it.

### Main menu registration, both apps

- `frontend/apps/filemanager/filemanagermenu.lua:1136-1143` and
  `frontend/apps/reader/modules/readermenu.lua:560` (`registerToMainMenu`);
  `frontend/apps/filemanager/filemanagermenu.lua:851-856` and
  `frontend/apps/reader/modules/readermenu.lua:341` (each registered widget's `addToMainMenu` is
  pcalled with the `menu_items` table); the pattern of `plugins/hello.koplugin/main.lua:23-30`.
- Every instance registers from `init`; `self.ui.menu` exists by then, since
  both apps register their menu module before making plugin instances
  (`frontend/apps/filemanager/filemanager.lua:404`, :418-429;
  `frontend/apps/reader/readerui.lua:176`, :464-478). A refused instance registers too, and its
  `addToMainMenu` gives Tools › KoPanda the items Studio and Swatches; the Home tab, Home and
  Settings are left out.

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

### `Font:getFace` by path, the shipped fonts

- `frontend/ui/font.lua:307-312` (a name starting with `/` or `./` is opened as a path; anything
  else is looked up under KOReader's `fonts/` folder), `:313-327` (then searched for in the font
  list), `:329-332` (logs and returns nil when nothing loads), `:276` (scales the size by
  `Screen:scaleBySize`), `:288-291` (faces cached by path and size).
- `frontend/pluginloader.lua:24` (`DEFAULT_PLUGIN_PATH = "plugins"`), `:204` (a plugin root is
  the lookup path joined with the folder name, so relative on a device), `:242` (that root is
  first in `package.path` while `main.lua` loads), `:248` (the plugin module's `path`).
- `fonts.lua` takes the plugin folder from its own source path as `require` found it, and its
  join (KoPanda's own, exposed to `spec/unit/fonts_spec.lua` as Fonts._join) gives a relative
  folder a `./` prefix so `getFace` treats the file as a path.
- `base/ffi/freetype.lua:207-225` (`newFaceSize` has no variation-axis calls), so the fonts ship
  as static instances: a variable font would render its default instance only.

### The looks: `Screen:isColorEnabled` and `Blitbuffer.colorFromString`

- `frontend/device/generic/device.lua:265-271` (`isColorEnabled`: the user's `color_rendering`
  setting when present, the panel's `isColorScreen` otherwise). `looks.lua` draws the grey palette
  when it is false, so a colour panel with colour rendering off gets grey too; the plugin never
  reads `color_rendering` itself.
- `base/ffi/blitbuffer.lua:2653-2683` (`colorFromString`: `#rrggbbaa`, `#rrggbb` or `#vv`, nil
  for any other length; non-hex digits or a non-string raise), which `looks.lua` calls in a
  `pcall`. The look files hold palette colours as `#rrggbb` only.
- `base/ffi/blitbuffer.lua:464-467` (a colour greyed by luminance, `getColor8`): two hues can land
  on the same grey, so each look's `grey` palette names an explicit grey per role.

### Night mode: `Screen.night_mode`, KOReader's inversion and the toggle

- `Screen.night_mode` (`base/ffi/framebuffer.lua:22`, `false` until toggled), flipped by
  `toggleNightMode` (`:476-477`), which then inverts in hardware when the device can
  (`:478-480`) or else flips the screen buffer's inverse flag (`:481-488`, and the full buffer's
  when a viewport is set). `Looks.variant()` reads the flag, after `isColorEnabled`, and answers
  `"night"`; `Looks.palette` then inverts the night palette per channel, so the panel, which
  shows the inverse of what is painted on both paths, shows the night palette as designed.
- The software path's per-paint inversion: `base/ffi/blitbuffer.lua:840-844` (`setPixel`),
  `:1506-1516` (`fill`), `:1704-1724` (`paintRect`), `:1827-1845` (`paintRectRGB32`), each
  inverting the colour as it writes it when the flag is set; `:592-597` (an RGB colour inverts
  each channel). `spec/unit/night_mode_spec.lua` paints on a buffer with the flag set and reads
  its stored pixels through a copy with the flag cleared, as `Screen:shot` does
  (`base/ffi/framebuffer.lua:566-581`; `getPixel` inverts what it reads while the flag is set,
  `base/ffi/blitbuffer.lua:819-826`). It looks for a `TextWidget`'s colour as its grey, since
  `TextWidget` draws through `colorblitFrom` (`frontend/ui/widget/textwidget.lua:369`), which
  takes the colour's `getColor8A` (`base/ffi/blitbuffer.lua:1405-1407`).
- `ImageWidget`'s `original_in_nightmode` (default `true`) and `is_icon` (`true` only for
  `IconWidget`), `frontend/ui/widget/imagewidget.lua:76-77`: in night mode it inverts its own
  rectangle after the blit unless it is an icon (`:583-593`), so the original shows through. The
  featured cover is a plain `ImageWidget` and the plugin adds no inversion of its own; the
  launcher's `TintedIcon` is no `ImageWidget`, and its tint inverts as it is painted
  (`colorblitFromRGB32`, `base/ffi/blitbuffer.lua:1422-1437`).
- The toggle's path: KOReader's menu broadcasts `ToggleNightMode`
  (`frontend/ui/elements/common_settings_menu_table.lua:266-271`); a gesture goes through
  `Dispatcher`'s `night_mode` action (`frontend/dispatcher.lua:138`, `ToggleNightMode`) or
  `set_night_mode` (`:139`, `SetNightMode`). `DeviceListener:onSetNightMode` calls
  `onToggleNightMode` only when the state differs (`frontend/device/devicelistener.lua:29-34`).
  Either reaches the home before `DeviceListener` toggles the screen and calls
  `setDirty("all", "full")` (`:14-27`), so the home handles neither event: its `paintTo`
  compares the variant it was built with against `Looks.variant()` and rebuilds inside that
  repaint, inside its paint `pcall`, with no `setDirty` of its own. `Home.take_pending` drops a
  pre-built home of another variant.
- Night mode at start: the device toggles it before any UI exists when `night_mode` is set in
  `G_reader_settings` (`frontend/device/generic/device.lua:344-347`), so the first home is built
  at night.

### The quote: `TextBoxWidget`'s line height and ellipsis

- `frontend/ui/widget/textboxwidget.lua:48` (`line_height` is extra space in em), `:151`
  (`line_height_px = Math.round((1 + line_height) * face.size)`, `Math.round` at
  `frontend/optmath.lua:43-45`), `:173-181` (a given `height` holds `floor(height / line_height_px)`
  lines), `:253-260` (`height_overflow_show_ellipsis` marks the last shown line
  `line_with_ellipsis`; `height_adjust` shrinks `height` to the lines there are), `:870-887`
  (that line drawn with the ellipsis, `ellipsis_added`). `widgets/quote.lua` sets `height` to
  four of `line_height_px` so the quote takes at most four lines and a longer one ends in "…".
- `spec/unit/quote_spec.lua` reads `vertical_string_list`, `lines_per_page`, `line_with_ellipsis`,
  `line_height_px`, `height` and `face.orig_size` (`frontend/ui/font.lua:337-344`) on the built
  text box to count its lines, and counts a quote's characters with `util`'s `splitToChars`
  (`frontend/util.lua:469`), which `typeset.lua` also uses.
- `base/ffi/blitbuffer.lua:2096` (`paintBorder`), `:2118-2126` (`paintBorderRGB32`): Diner's tile
  outline, a colour through the RGB32 variant as the fills.

### The home's rows: `Resume`, `TimeFormatChanged` and `setDirty`

- `frontend/device/generic/device.lua:1125` (`Resume` broadcast on wake),
  `frontend/ui/elements/common_settings_menu_table.lua:87` (`TimeFormatChanged` broadcast when the
  12-hour clock setting flips), `frontend/ui/uimanager.lua:1042-1061` (`broadcastEvent` reaches
  every window-level widget whatever a handler returns). The home rebuilds its rows on both and
  returns nothing; it schedules no task of its own for them.
- `frontend/ui/uimanager.lua:659` (`setDirty`): a rebuilt home is repainted with `"ui"`.
- `frontend/ui/widget/container/widgetcontainer.lua:80-107` (`propagateEvent` offers an event to
  the children before the container's own handler, so a slot widget that consumed `Resume` would
  keep the home from rebuilding), `:110-117` (`free` frees the array part): the rows container
  holds the slot widgets in its array part, and the old one is freed after a rebuild.
- `base/ffi/framebuffer.lua:414-425` (`scaleBySize`): `layout.lua` scales every look length
  (margins, gaps, header, footer) once; `frontend/ui/font.lua:276` scales font sizes, so
  `Layout.font_size` doesn't. `Layout.screen` is the screen it scales by, a seam the spec
  replaces with one of another size.
- `base/ffi/blitbuffer.lua:2712` (`isColor8`), `:1704-1724` (`paintRect`, which greys a colour),
  `:1827` (`paintRectRGB32`): the paper, header band, edge, rule and footer stripe are filled by
  `home_rows.lua` as the swatch screen fills its panels.

### The date and clock: `datetime` tables and `twelve_hour_clock`

- `frontend/datetime.lua:29-42` (`longMonthTranslation`, keyed by the English month name
  `os.date("%B")` gives in the C locale), `:54-62` (`shortDayOfWeekToLongTranslation`, keyed by
  the English abbreviation `os.date("%a")` gives). `widgets/date.lua` looks both up, so the date
  follows KOReader's language.
- `twelve_hour_clock` in `G_reader_settings`: read with `isTrue`, as
  `frontend/datetime.lua:298-300` reads it, so unset is the 24-hour clock; set by Settings › Time
  and date › 12-hour clock (`frontend/ui/elements/common_settings_menu_table.lua:76-89`), which
  broadcasts `TimeFormatChanged` (the home's rows entry above). The 24-hour form is
  `os.date("%-H:%M")`, KOReader's own on Linux and Kindle (`frontend/datetime.lua:262-264`).
- Letter spacing: `frontend/ui/widget/textwidget.lua:27-65` (TextWidget has no tracking field),
  so `typeset.lua` sets a tracked line as one TextWidget per character from
  `util.splitToChars` (`frontend/util.lua:469`) in a `HorizontalGroup` with `allow_mirroring`
  off (`frontend/ui/widget/horizontalgroup.lua:11`). A line too wide for its column falls back
  to one TextWidget with `max_width`, which KOReader cuts with an ellipsis
  (`frontend/ui/widget/textwidget.lua:36-37`, `:202-238`).
- Line height: TextWidget's `forced_height` and `forced_baseline`
  (`frontend/ui/widget/textwidget.lua:43-44`), which `getSize` reports (`:298`) and the xtext
  paint draws at (`:362`); `getBaseline` (`:312`) gives the face's baseline, not a forced one.
  `typeset.lua` sets a part whose `line_height` isn't 0 at `(1 + line_height)` em, rounded, as
  TextBoxWidget sizes a line (`frontend/ui/widget/textboxwidget.lua:151`), and centres the face's
  height from `face.ftsize:getHeightAndAscender()` (`base/ffi/freetype.lua:154-159`, the call
  textboxwidget.lua:153-158 makes) in it. `Typeset.baseline` gives the home row the line's
  baseline.

### The Statistics plugin's database and settings, the reading stats

- The database: `plugins/statistics.koplugin/main.lua:27` (`DataStorage:getSettingsDir() ..
  "/statistics.sqlite3"`; `datastorage`: `datastorage.lua:60`, `getSettingsDir`). `reading_stats.lua`
  checks it with `util.fileExists` (`util`: `frontend/util.lua:830`, as
  `frontend/ui/data/onetime_migration.lua:620` does) and opens it only when it exists, since a
  creating open would leave an empty file the plugin then fails to open (`main.lua:292-317`).
- `lua-ljsqlite3/init` (`main.lua:13`): `base/thirdparty/lua-ljsqlite3/init.lua:325-329` (open modes),
  `:331-350` (`open(path, "ro")`, read-only), `:370-379` (`prepare`), `:611-613` (`step`), `:668`
  (`bind`), `:568` (statement `close`), `:352` (connection `close`); integers come back as int64
  cdata and go through `tonumber`. Errors are raised as `ljsqlite3[<code>] <message>` followed by a
  traceback (`:58-61`, codes `:65-70`); `busy` and `locked` read as the last numbers.
- `page_stat_data` and its columns `id_book`, `start_time`, `duration`: `main.lua:405-416`, the
  `start_time` index `:419`; `start_time` is `os.time()` epoch seconds (`:2584`), `duration` whole
  seconds (`:2604`). The plugin's `createDB` makes it WAL where `Device:canUseWAL()`
  (`main.lua:455-460`, `frontend/device/generic/device.lua:131`); a read-only connection reads it.
- The `book` table and its columns `id`, `md5`, `pages`, `last_open`: `main.lua:462-482`; the unique
  index is on `(title, authors, md5)` (`:483`), so one md5 can have several rows and
  `seconds_per_page` takes the one with the latest `last_open`. `md5` is the sidecar's
  `partial_md5_checksum` (`main.lua:2737`).
- The `page_stat` view: `main.lua:422-451` (with its `numbers` table), which rescales every
  `page_stat_data` row to the book row's `pages` (`:438-451`; the rescale on a page-count change,
  `:422-452`). `seconds_per_page` runs the plugin's capped-average query on it
  (`STATISTICS_SQL_BOOK_CAPPED_TOTALS_QUERY`, `main.lua:40-49`) with the cap bound as a parameter;
  the time left is the stats popup's sum over the book row's pages (`main.lua:1579`).
- `max_sec`, the cap on one page's time: a field of the plugin's `statistics` settings table,
  default `DEFAULT_MAX_READ_SEC` 120 (`main.lua:30`, `:83`, the read `:143`); `reading_stats.lua`
  reads the table without a default and takes 120 when `max_sec` is absent.
- `G_reader_settings` key `plugins_disabled`: `frontend/pluginloader.lua:175` (read keyed by folder
  name, `:212`); `statistics` in it reads as off.
- `G_reader_settings` key `statistics`, the plugin's own table (`main.lua:61` `settings_key`, `:85`
  `is_enabled` default, `:143` the read); `is_enabled == false` reads as off. Both keys are read
  without a default, which `readSetting` would write back (`frontend/luasettings.lua:89-99`).
- `CloseDocument` order: `ReaderUI:onClose` sends it with `handleEvent`
  (`frontend/apps/reader/readerui.lua:887`), which offers it to the reader's modules in array order
  (`frontend/ui/widget/container/widgetcontainer.lua:80-89`); plugins join that array in
  `PluginLoader:loadPlugins` order (`readerui.lua:464-474`), sorted by path
  (`frontend/pluginloader.lua:289`). `kopanda.koplugin` sorts before `statistics.koplugin`, and in
  the emulator KoPanda's handler ran first (module 37 against 64) with the closing session not yet
  in `page_stat_data`, so `Home.take_pending` has the stats widget read its numbers again.
- `datetime`: `frontend/datetime.lua:29-42` (`longMonthTranslation`, the month name).

### Book records: the home folder, the file browser's filters, CoverBrowser's rows and the sidecar

`books.lua` lists the library and builds one record per book. It requires each KOReader module
below at call time, so a spec's stub or a toggled field is read as it is now.

- `apps/filemanager/filemanagerutil`: `getHomeFolder()`
  (`frontend/apps/filemanager/filemanagerutil.lua:25-27`, `home_dir`, else `Device.home_dir`, else
  `"."`), the library root.
- `ui/widget/filechooser`, the file browser's listing rules (`frontend/ui/widget/filechooser.lua:114-143`):
  - `FileChooser.show_hidden`, a class field set from `G_reader_settings` when the module loads
    (`:24`) and by `toggleShowFilesMode` (`:415-420`), read on each listing; names starting with `.`
    only while it is on (`:120`);
  - `exclude_dirs` (`:28-54`, `%.sdr$` among them) through `FileChooser:show_dir` (`:81-86`), called
    on the class;
  - `exclude_files` (`:55-72`), matched against the name by `books.lua` itself, since `show_file`
    (`:88-97`) also applies the status filter and `file_filter`, which the library doesn't; the
    patterns are unanchored at the end where written so (`^BookReader%.sqlite`, `:57`);
  - `getPathList` reads a folder with `pcall(lfs.dir, path)` (`:116`), so a folder that can't be read
    lists nothing; `books.lua` does the same and logs it. A `._` file is never listed (`:135`).
- `document/documentregistry`: `DocumentRegistry:hasProvider(file)`
  (`frontend/document/documentregistry.lua:63-85`), asked with the file's name, as the file
  manager's own `file_filter` asks (`frontend/apps/filemanager/filemanager.lua:143`). For a suffix
  with no provider it tests `DocSettings:hasSidecarFile` and, when there is one, calls
  `DocSettings:open` (`:81-82`), as the file browser's filter does on every listing; `books.lua`
  never calls `DocSettings:open` itself.
- `bookinfomanager`, CoverBrowser's cache, by `pcall(require, "bookinfomanager")` (a failure means
  CoverBrowser is off, `frontend/pluginloader.lua:283-287`). One `getBookInfo(path, false)` per
  record (`plugins/coverbrowser.koplugin/bookinfomanager.lua:325-404`), with the path as listed:
  rows are keyed by directory and file name (`:68`, the unique index). Its row's `title`,
  `authors`, `series` and `series_index` (`:53-56`; `series_index` is `REAL`, so it may be
  fractional) and the flags `unsupported`, `cover_fetched`, `has_cover` and `ignore_cover`
  (`:37-47`, `'Y'` or nil, `unsupported` a reason string). The cover state follows
  `plugins/coverbrowser.koplugin/mosaicmenu.lua:471-488`'s order. `bcid` (`:27-28`) is not an id.
  The real `getBookInfo` itself calls `hasProvider` with the full path (`:332-333`).
- The authors separator: crengine joins every `dc:creator`, each trimmed, with `"\n"`
  (`base/thirdparty/kpvcrlib/crengine/crengine/src/epubfmt.cpp:1179-1199`), and KOReader splits them
  on it (`frontend/apps/filemanager/filemanagerbookinfo.lua:287-301`). `books.lua` splits on newlines,
  trims each name, makes runs of white space one space and drops empty names.
- The series split: `Document:getProps` splits a trailing `" #N"` off the series into a number
  (`frontend/document/document.lua:169-185`), so the column holds the name alone.
- `docsettings`: `DocSettings:findSidecarFile` (`frontend/docsettings.lua:159-175`) and
  `DocSettings.openSettingsFile` (`:301-315`), the light read the featured book made before;
  `DocSettings:hasSidecarFile` (`:151-153`) is `findSidecarFile` giving a path, the test for a book
  never opened, which `books.lua` makes from the same `findSidecarFile` call. `doc_props.title` and
  `doc_props.authors` fill what CoverBrowser leaves empty, field by field.
- Read status and progress, the rules of `BookList` (`frontend/ui/widget/booklist.lua`):
  `getBookStatus` gives `new` for a book with no sidecar (`:366-369`); `setBookInfoCache` keeps any
  `summary.status` with a status string, else `reading` (`:292-296`, the six statuses `:371-378`),
  which `books.lua` narrows to `reading`, `abandoned` and `complete`; the pages order (`:298-306`).
- `ffi/util`: `realpath` (`base/ffi/util.lua:171-176`, nil for a missing path), the record's id,
  `"file:"` plus the realpath, the identity the reading history uses (`frontend/readhistory.lua:26`).
- `spec/unit/books_coverbrowser_spec.lua` runs the real CoverBrowser: `disable_plugins` and
  `load_plugin` (`spec/unit/commonrequire.lua:57-62`, `:64-75`) load it through
  `PluginLoader:_load`, whose `main.lua` requires `bookinfomanager` at its top
  (`plugins/coverbrowser.koplugin/main.lua:6`); then `extractBookInfo(filepath, cover_specs)`
  (`bookinfomanager.lua:422-570`) in-process, and `setBookInfoProperties` and `deleteBookInfo`
  (`:572-600`).

### The featured book: reading history, sidecars, CoverBrowser and the chapter

- `readhistory`: `frontend/readhistory.lua:15-16` (`ReadHistory.hist`), `:369-373` (read from its
  file when the module loads), `:332-333` (the opened book inserted at the head, so the list is
  most recent first), `:82` (at most `history_size`, 500, entries). Entries are built at `:25-36`:
  `file` is the realpath (`:26`) and `select_enabled` is whether the file existed then, updated
  only through KOReader (`:226-227`), so `featured_book.lua` re-checks each candidate with
  `lfs.attributes(file, "mode") == "file"`. Required at call time, never written.
- `ui/quickstart`: `QuickStart.quickstart_filename`, set by `getQuickStart`
  (`frontend/ui/quickstart.lua:414-419`, `:470`); the QuickStart guide is skipped as
  `ReaderUI:getLastDirFile` skips it (`frontend/apps/reader/readerui.lua:571-577`).
  A known limitation, kept as specified: the field is set only in a process that called
  `getQuickStart`, which `reader.lua:257-261` does at boot only while `QuickStart:isShown()` is
  false (`quickstart.lua:400-403`, the first run of a version), so on later boots it is nil. When
  set, it is built on `DataStorage:getDataDir()` (`quickstart.lua:414`, `:418`), which is the
  relative `"."` with `KO_HOME` unset and no platform folder applying (`datastorage.lua:19-42`,
  the fallback at `:41-42`), while history
  holds realpaths (`frontend/readhistory.lua:26`). Either way the comparison misses, and the
  guide is featured when it is the newest history entry.
- `docsettings`, read through `books.lua` (the "Book records" entry above), which the featured book
  asks for its record and progress: `DocSettings:findSidecarFile` (`frontend/docsettings.lua:159-175`, the sidecar
  path or nil, by `getOrderedLocationCandidates` `:101-110` and `getSidecarDir` `:118-135`, in the
  order the `G_reader_settings` key `document_metadata_folder` gives, `:102`, `:121`;
  `spec/unit/featured_book_spec.lua` sets it to `dir`) and
  `DocSettings.openSettingsFile` (`:301-315`: `dofile` in a `pcall`, empty data for nil, a corrupt
  file or an empty table; it cannot flush). `DocSettings:open` is never called: it removes
  candidates it finds invalid (`:282-284`). Read through `isTrue` and `readSetting`
  (`frontend/luasettings.lua:124-126`, `:89-99`, no default passed).
- The sidecar keys read, in `books.lua`'s `Books.for_path` and `Books.progress`:
  - `percent_finished`, 0 to 1 (`frontend/apps/reader/modules/readerrolling.lua:338`,
    `readerpaging.lua:163`), clamped to 0 to 1, absent as 0;
  - `summary.status`, `reading`, `abandoned` or `complete`, anything else as `reading`
    (`frontend/ui/widget/booklist.lua:292-296`, the statuses `:371-378`); a book with no sidecar is
    `new` in the model (`:366-369`), which the featured book reads as `reading`;
  - `pagemap_doc_pages` when `pagemap_use_page_labels` is true, else `doc_pages`, else `stats.pages`
    when it isn't 0 (`booklist.lua:298-306`);
  - `doc_props.title` and `doc_props.authors` (`frontend/apps/reader/readerui.lua:492-493`);
  - `partial_md5_checksum` (`readerui.lua:497-501`), the Statistics `book.md5`.
- `bookinfomanager`, CoverBrowser's cache, reached by `books.lua`: its folder is on `package.path` only when the plugin is
  enabled (`frontend/pluginloader.lua:283-287`), so `pcall(require, "bookinfomanager")` failing
  means disabled. The module is the initialised instance
  (`plugins/coverbrowser.koplugin/bookinfomanager.lua:1032-1034`).
  `BookInfoManager:getBookInfo(file, false)` (`:325-404`) gives the cached `title` and `authors`
  (several authors newline-separated) without decompressing a cover (`:376-379`), or nil for a
  book not indexed (`:359-362`).
- `ffi/util`: `realpath` (`base/ffi/util.lua:171-176`, nil for a missing path), to compare the
  recorded chapter's file with the featured file.
- The chapter: `ReaderToc:getTocTitleOfCurrentPage`
  (`frontend/apps/reader/modules/readertoc.lua:476-480`), the TOC title of `pageno`, `""` when no
  entry covers the page (`:446-453`), filling an unfilled TOC itself (`:383-384`). Called on
  `CloseDocument`, which is sent before the document closes (`readerui.lua:887`, `:891`), with
  `self.ui.document.file`; both go into the runtime state file as `featured_chapter_file` and
  `featured_chapter`. A raising lookup is logged and records the chapter as `""`, and a failed
  write clears `featured_chapter`, so no earlier chapter survives either.

### The weather: `NetworkMgr`, `socketutil`, `socket.http`, `rapidjson` and its cache

- `ui/network/manager`, required at call time so a spec can stub it:
  - `frontend/ui/network/manager.lua:187` (`NetworkMgr:isConnected`; on the Kindle
    `ifHasAnAddress`, `frontend/device/kindle/device.lua:523-524`, with no prompt and no network
    I/O; in the emulator the `emulator_fake_wifi_connected` setting,
    `frontend/device/sdl/device.lua:478-500`, which the unit harness and the capture driver turn
    off). `isOnline` (`manager.lua:641-648`) resolves a hostname, so the plugin never calls it.
  - `manager.lua:698-709` (`runWhenOnline`: the callback now when online; otherwise
    `beforeWifiAction`, `:605-618`, which turns Wi-Fi on, waits, or prompts as the user's
    `wifi_enable_action` says, and drops the callback when connected but not online). Only a tap
    on the weather calls it.
  - `NetworkConnected`: broadcast when Wi-Fi comes up (`manager.lua:109`) and at start when it is
    already up (`:152-154`, from a `nextTick`). The home's handler returns nothing, so the
    broadcast reaches every window (`frontend/ui/widget/container/widgetcontainer.lua:80-107`).
- `socketutil`: `frontend/socketutil.lua:52-62` (`set_timeout(5, 10)`), `:64-70`
  (`reset_timeout`, called on every path, a raising request included), `:91-93` (the timeout
  codes), `:98-115` (`table_sink`, which stops a body past the total timeout); the pattern of
  `frontend/ui/wikipedia.lua:146-215`.
- `socket.http`: `base/build/arm64-apple-darwin23.5.0-debug/common/socket/http.lua:30-41`
  (`https` through LuaSec), `:432-436` (`request` is `socket.protect`ed, so a failure returns
  `nil` and the error), `:375`, `:406` (a table request returns `1, code, headers, status`; an
  HTTP/0.9 reply has no headers). `request` is looked up at call time, not kept in a local.
- `rapidjson`: `common/rapidjson.so`; `decode` returns `nil` and a message for text that is not
  JSON (`base/thirdparty/lua-rapidjson/build/downloads/source/API.md:26-34`).
- The cache, `settings/kopanda/weather.lua`: `luasettings` and `datastorage` as for the runtime
  state file above, `frontend/luasettings.lua:247-250` (`reset`). Runtime state, not a setting:
  no schema entry, and the studio never reads it. A failed fetch writes nothing.
- The sun and moon go through `IconWidget` (the swatch entry above), which renders an SVG with
  `RenderImage:renderSVGImageFile` (`frontend/ui/widget/imagewidget.lua:175`).

### The place search: `InputDialog`, `ButtonDialog`, `forceRePaint`, `util` and the geocoding endpoint

- `ui/widget/inputdialog`: `frontend/ui/widget/inputdialog.lua:124-167` (the class; `title`,
  `input_hint`, `buttons`), `:354-362` (Enter runs the button marked `is_enter_default`), `:583`
  (`getInputText`), `:640` (`onShowKeyboard`), `:633` (`onCloseWidget` closes the keyboard with the
  dialog). The Cancel button's `id = "close"` follows `:25`.
- `ui/widget/buttondialog`: `frontend/ui/widget/buttondialog.lua:1-40` (rows of buttons with
  `text` and `callback`), `:62-75` (`buttons`, `title`), `:187-189` and `:217` (a table taller than
  the screen scrolls in a `ScrollableContainer`). Ten candidates and Cancel at most.
- `ui/uimanager`: `frontend/ui/uimanager.lua:1404` (`forceRePaint` drains the paint queue now), so the
  "Searching…" note is on screen before the fetch blocks the UI loop; `show` and `close` as above.
- `ui/widget/infomessage`: the notes and "Searching…" have no timeout, so no timer
  (`frontend/ui/widget/infomessage.lua:283-290`).
- `util`: `frontend/util.lua:52` (`trim`), `:1443` (`urlEncode`, RFC 3986 unreserved characters
  kept, a space as `%20`).
- `ui/network/manager`: `isConnected` as the weather entry above; offline the search says so and
  fetches nothing.
- The fetch is the weather's `Weather.get` (`socketutil` timeouts and their reset, `socket.http`), and
  the body is decoded with `rapidjson` in a `pcall`, as the weather entry above.
- Open-Meteo's geocoding endpoint, read live on 2026-10-15:
  `https://geocoding-api.open-meteo.com/v1/search?name=<query>&count=10&language=en&format=json`, plus
  `&countryCode=US` for a five-digit ZIP code. A match returns `{ results = [ { id, name, latitude,
  longitude, elevation, feature_code, country_code, admin1_id.., timezone, population, postcodes,
  country_id, country, admin1..admin4 } ], generationtime_ms }`; no match returns only
  `{ generationtime_ms }`. "60614" with `countryCode=US` returned one result, Chicago, Illinois, at
  41.85003, -87.65005. The recorded responses are `spec/fixtures/geocoding/*.json`.

### The settings menu: `TouchMenu`'s items, one tab and closing

- `menu.lua` builds the rows as `TouchMenu` items, which `ui/widget/touchmenu` reads as
  follows: `frontend/ui/widget/touchmenu.lua:73-96` (`enabled`, `checked_func`, `radio` draw a
  radio or check mark), `:107` and `frontend/ui/widget/menu.lua:1610-1621` (`Menu.getMenuText`:
  `text_func` is read on every redraw, and an item with `sub_item_table_func` gets the submenu
  arrow), `:715` (`separator` draws a line before the next item), `:892-911`
  (`sub_item_table_func` is called on tap; an empty table opens nothing), `:913-926` (the
  `callback` gets the menu; with `checked_func` the menu redraws, with `keep_menu_open` it stays,
  otherwise it closes after the callback), `:671` (`updateItems`, which the location row calls
  after a pick). `TouchMenu` doesn't catch a callback's error, so every function `menu.lua` hands
  it is guarded.
- Tools › KoPanda › Settings is a native submenu: its `sub_item_table_func` returns the rows,
  or `{}` when building them fails.
- `settings_menu.lua` shows the rows on their own in a `TouchMenu` with one tab:
  `tab_item_table = { items }` with `items.icon = "appbar.settings"`, the icon of KOReader's own
  settings tab (`frontend/apps/filemanager/filemanagermenu.lua:37`). Tabs are read from each
  tab table's `icon` (`touchmenu.lua:540`); with one icon `TouchMenuBar:init`'s separator and
  before-last branches don't run (`:373`, `:421`). `settings_menu_spec.lua` builds, paints and
  closes one.
- The container is `FileManagerMenu:onShowMenu`'s pattern
  (`frontend/apps/filemanager/filemanagermenu.lua:1006-1047`): a full-screen
  `ui/widget/container/centercontainer` with `ignore = "height"` holding the `TouchMenu`, whose
  `show_parent` it is. KoPanda's menu sets no `close_callback`, so the default closes the
  container (`touchmenu.lua:499-504`), from a tap outside the menu (`:508-512`, `:977-981`), the
  Back key (`:531`) or the up arrow at the top level (`:798-814`); `onCloseWidget` asks for a
  full-screen `flashui` (`:987-998`). It saves no tab index, unlike `FileManagerMenu`'s close
  (`filemanagermenu.lua:1051-1052`).
- `util`: `frontend/util.lua:146` (`tableEquals`), so a tap on the value already stored, a place
  table included, writes nothing.
- `ui/network/manager`: `isConnected` as the weather entry above, before the one weather fetch
  that follows a write of the weather's place or units while a home is shown.
- `ui/widget/infomessage`: "Couldn't save <label>." has no timeout, so no timer
  (`frontend/ui/widget/infomessage.lua:283-290`).
- The Layout and Launcher rows open their screens from `UIManager:nextTick`, after the menu has
  closed itself (`touchmenu.lua:920-926`).

### Edit layout: `util.tableDeepCopy` and its notes

- `util`: `frontend/util.lua:184-203` (`tableDeepCopy`). `Settings.get` hands back the stored
  table itself, so `edit_layout.lua` copies `layout.rows` when it opens, and every
  `rows_edit.lua` operation copies the rows it is given before changing them.
- `ui/widget/infomessage`: a refused change ("That won't fit on the home.", "Couldn't save the
  layout." and `rows_edit.lua`'s notes) shows a note with no timeout, so no timer
  (`frontend/ui/widget/infomessage.lua:52-53`, `:283-290`).
- Its pickers are `sheet.lua`'s sheets over the editor frame; the frame is the editor entries
  above.

### The featured cover: CoverBrowser's `bookinfomanager`, `ImageWidget` and the bounded check

- `bookinfomanager` (`plugins/coverbrowser.koplugin/bookinfomanager.lua`), reached by
  `pcall(require, "bookinfomanager")` in `book_covers.lua`, the cover reader and the one asker,
  at call time; `featured_cover.lua` reads and asks through it. The plugin's folder
  joins `package.path` only for an enabled plugin (`frontend/pluginloader.lua:283-287`); a disabled
  one loads only its `_meta.lua` (`:208-216`, `plugins_disabled` read at `:175`), so a failed
  require means CoverBrowser is off and the placeholder is drawn. CoverBrowser is built in and on
  by default (`pluginloader.lua:37`). The module returns its one `BookInfoManager` table
  (`bookinfomanager.lua:131`, `:1034`).
- `getBookInfo(filepath, get_cover)` (`bookinfomanager.lua:325-404`): `nil` for a file not in the
  database or still being indexed (`:359-361`; `in_progress=0` in the select, `:114-115`); a
  never-extract row with `ignore_cover` for a file with no document provider (`:333-357`);
  otherwise the `BOOKINFO_COLS_SET` columns (`:77-103`), flags `'Y'` or nil, `unsupported` a
  reason string (`:38`), `cover_w` and `cover_h` read even without `get_cover` (`:373-378`), and
  with it a fresh decompressed `cover_bb` when `has_cover` is set (`:380-396`). `BookCovers.read`
  reads with `true`; the extraction test reads with `false`; each check reads each pending file
  with `false`, and the last check each still pending with `true`.
- The cache `book_covers.lua` relies on: one row per file, keyed by directory and file name
  (`bookinfomanager.lua:68`), its cover scaled down at extraction to the box asked for when bigger
  (`:533-540`), so a file keeps one thumbnail and smaller boxes fit it down.
- A row with `ignore_cover` draws the placeholder even with a cached cover, its bitmap freed, as
  CoverBrowser draws no cover for it (`plugins/coverbrowser.koplugin/mosaicmenu.lua:508`,
  `listmenu.lua:272`).
- `isCachedCoverInvalid(bookinfo, cover_specs)`, a plain function (`:1013-1030`): true for a row
  with no `cover_w` (`:1014-1015`), so the never-ask rows are tested before it, in
  `plugins/coverbrowser.koplugin/mosaicmenu.lua:471-488`'s order. An unusable `cover_bb` is freed,
  as `mosaicmenu.lua:478-479` does.
- `extractInBackground(files)` (`:689-745`): terminates earlier jobs, CoverBrowser's own included
  (`:695`), closes the database connection (`:699`), forks the extraction (`:721`) and returns
  `true` (`:744`), or `false` when the fork fails (`:724`). One subprocess walks the batch's
  files in order, extracting each (`:702-711`). Asked only from `BookCovers.request`, at most once
  per file per process unless a later request replaced the one that asked for it (its
  extraction terminated, `:695`), with every wanted file of the batch in one call; the featured
  cover asks through `FeaturedCover.after_show`, never from `build` or `paintTo`.
- `isExtractingInBackground()` (`:685-687`), the only completion signal, counts CoverBrowser's own
  jobs too. CoverBrowser polls it once a second (`plugins/coverbrowser.koplugin/covermenu.lua:164-175`);
  `book_covers.lua` does the same through `UIManager:scheduleIn` (`frontend/ui/uimanager.lua:413`)
  for at most 30 checks, and `BookCovers.cancel` (through `FeaturedCover.cancel`) drops it with
  `UIManager:unschedule` (`:518`).
- It turns false only when CoverBrowser's collector reaps the extraction's pid, every
  `subprocesses_collect_interval` = 10 s (`bookinfomanager.lua:139`; `collectSubprocesses`
  `:627-650`, first scheduled by `extractInBackground` at `:735-742`), so a cover written at 2 s
  would wait for it. Each check therefore reads the pending rows first, and stops once none is
  pending.
- `ui/widget/imagewidget`: `frontend/ui/widget/imagewidget.lua:62` (`image_disposable` defaults
  to true, so the widget frees `cover_bb` in `free`, `:600-606`), `:86-89` and `:320-328`
  (`scale_factor = 0` fits the image in `width` by `height`, keeping its aspect).
- The cover box is painted with `base/ffi/blitbuffer.lua:2169-2197` (`paintRoundedRect` and its
  RGB32 variant) and `:2096-2135` (`paintBorder` with a radius); a real cover is square, as
  `FrameContainer` rounds its background and border, not its content
  (`frontend/ui/widget/container/framecontainer.lua:124-139`). The placeholder title is a
  `TextBoxWidget` with `height_overflow_show_ellipsis` (`frontend/ui/widget/textboxwidget.lua:54`).
  `spec/unit/featured_cover_spec.lua` reads its `vertical_string_list`, `lines_per_page` and
  `line_with_ellipsis`, as `quote_spec.lua` does (the quote widget's entry above).

### The placeholder title's size: `TextBoxWidget`'s split-word flags

- `has_split_inside_word`, set on the box when a word was broken mid-word on any line, shown or
  past `lines_per_page`: with xtext at `frontend/ui/widget/textboxwidget.lua:421-424`, without at
  `:478-480`; not in the class defaults, so nil on a box that split nothing. `featured_cover.lua`
  (`split_shown`) reads it first, as CoverBrowser's fake cover does before trying a smaller size
  (`plugins/coverbrowser.koplugin/mosaicmenu.lua:211-214`), and `placeholder_text` builds the
  title one size smaller, down to `MIN_TITLE_SIZE`, while a shown line splits a word.
- `vertical_string_list[i].no_allowed_break_met`, the xtext line table stored whole (`:420`), its
  flag the one that sets `has_split_inside_word` (`:421`). `split_shown` reads it on the shown
  lines only, `1` to `math.min(lines_per_page, #vertical_string_list)`; `lines_per_page` is
  `floor(height / line_height_px)` for a given `height` (`:180`), the lines drawn before the
  ellipsis (`:253-254`). A split on a line past the ellipsis doesn't step the size down.
- `use_xtext` (`:112`, `G_reader_settings:nilOrTrue("use_xtext")`, which the file manager's
  developer menu flips, `frontend/apps/filemanager/filemanagermenu.lua:730-733`) picks the
  fallback: without xtext the line tables (`:541-545`) carry no flag, so `split_shown` takes the
  box's `has_split_inside_word` alone and a split on a hidden line also steps the size down.
- If these change: a renamed `has_split_inside_word`, or a renamed `no_allowed_break_met` under
  xtext, reads as no split, so the title stays at its size and breaks a word mid-word again; the
  narrow-box test in `spec/unit/featured_cover_spec.lua` fails on the split title. A nil
  `lines_per_page` makes `math.min` raise out of `FeaturedCover.build`. A renamed `use_xtext`
  reads as the non-xtext fallback, smaller titles where only a hidden line split.

### The featured widget: `FileManager:openFile`, `onHome` and `FrameContainer`'s stripes

- `FileManager:openFile(file)` (`frontend/apps/filemanager/filemanager.lua:1616-1639`): with no
  provider given it picks one (`DocumentRegistry:getProvider`) and opens a document through
  `ReaderUI:showReader`, KOReader's own path to the reader, which closes the file manager and the
  home with it. A tap on the featured book calls it on `FileManager.instance` (the entry above),
  read through `package.loaded` at tap time.
- `FileManager:onHome()` (`filemanager.lua:865-870`): resumes repaints and sends the file chooser to
  the home folder. The first run's "Open the Library" closes the home, then calls it.
- `FrameContainer`'s `stripe_color` and `stripe_width`
  (`frontend/ui/widget/container/framecontainer.lua:48-50`): with both set and no `stripe_over`, it
  hatches its area after its background (`:128-132`) through `hatchRect`
  (`base/ffi/blitbuffer.lua:2209-2235`), whose stripes run along x + y = constant, on and off of
  `stripe_width` each measured along x (`:2223`). The C path takes a `Color8`
  (`blitbuffer.lua:129`, `:2217`), so the grey hatch's ink is passed through `getColor8`. Diner's
  grey progress fill.
- The title and the first run's lines are `TextBoxWidget`s with `height_adjust`, which shrinks a
  box to the lines it holds (`frontend/ui/widget/textboxwidget.lua:53`, `:256-260`), and
  `height_overflow_show_ellipsis` (`:54`), at line heights as `:151` counts them.
- The first run's button keeps its rectangle on the screen when it paints, and a tap inside it is
  tested with `Geom:contains` (`frontend/ui/geometry.lua:255-266`), which takes the far edges in.

### The launcher's entries: plugins, dispatcher ids, Wi-Fi, `changeToPath` and notes

- `pluginloader`: `PluginLoader:isPluginLoaded(name)` (`frontend/pluginloader.lua:567-569`), true
  when `loaded_plugins` holds the name. `loaded_plugins` fills as instances are made
  (`createPluginInstance`, `:479-488`) and is emptied by `finalize` (`:578-580`), which the file
  manager's `onClose` calls (`frontend/apps/filemanager/filemanager.lua:821`); the file manager
  instantiates every enabled plugin that isn't `is_doc_only` (`:418-423`), the reader every
  enabled plugin (`frontend/apps/reader/readerui.lua:464-465`). A plugin whose `main.lua`
  returned `{ disabled = true }` is never instantiated (`plugins/SSH.koplugin/main.lua:21-23`),
  so its entry reads "plugin missing". Read at call time from `launcher_entries.lua`.
- `dispatcher`: `Dispatcher.getDisplayList(settings)` (`frontend/dispatcher.lua:866-890`) lists
  an id only when `isAvailable(settingsList[id])` (`:689-696`); it calls `getNameFromItem`
  (`:751-758`), which reads `settingsList`. An entry is available when
  `#getDisplayList({ [id] = true }) == 1`. `execute` skips an id it doesn't know without a word
  (`:1569`, `:1435-1448`), hence the check. `registerAction` and `removeAction` (`:665-684`) are
  how the spec adds and drops an action.
- The `koreader` targets' dispatcher ids, all `category = "none"` with no `arg`, so `execute`
  sends `Event:new(event)` (`:1583-1587`) through the dispatch bridge above:
  - `history` (`:68`, `ShowHist`): `FileManagerHistory:onShowHist`
    (`frontend/apps/filemanager/filemanagerhistory.lua:59`), its list kept as `booklist_menu`;
  - `favorites` (`:70`, `ShowColl`): `FileManagerCollection:onShowColl`
    (`frontend/apps/filemanager/filemanagercollection.lua:76`);
  - `collections` (`:71`, `ShowCollList`): `onShowCollList` (`filemanagercollection.lua:845`);
  - `toggle_wifi` (`:124`, `ToggleWifi`, registered only with `Device:hasWifiToggle()`):
    `NetworkListener:onToggleWifi` (`frontend/ui/network/networklistener.lua:54-60`), registered
    on the file manager as `networklistener` (`filemanager.lua:415`, `:379-381`).
- `ui/network/manager`: `NetworkMgr:isWifiOn()` (`frontend/ui/network/manager.lua:182-186`,
  true without a Wi-Fi toggle); on the Kindle `sysfsWifiOn`
  (`frontend/device/kindle/device.lua:523`), a stat of `/sys/class/net/<interface>`
  (`manager.lua:205-208`); in the emulator the `emulator_fake_wifi_connected` setting
  (`frontend/device/sdl/device.lua:497-499`). Read at call time; false draws Wi-Fi off.
- `FileChooser:changeToPath(path)` (`frontend/ui/widget/filechooser.lua:341-371`): climbs
  silently to the nearest existing ancestor (`:342-346`), so a directory entry is checked with
  `lfs.attributes(path, "mode")` first and again at tap time; it fires `PathChanged`
  (`:367-369`), which updates the file manager's title bar (`filemanager.lua:108-114`).
- `FileManager:onHome()` (`filemanager.lua:865-870`), as the featured widget's entry above: the
  Library entry closes the home, then calls it.
- `ffi/util`: `template` (`base/ffi/util.lua:785`), the unavailable notes.
- A folder entry's tap opens the folder sheet (`folder_sheet.lua`) through `sheet.lua`, with
  the `ui/time` `monotonic` it took on the tap as the sheet's start; `folder_sheet` is required
  at call time, since it requires `launcher_entries`. Its rows run their entries through `run`.
- `ui/widget/infomessage`: `timeout` defaults to nil (`frontend/ui/widget/infomessage.lua:53`)
  and only a set one schedules a close (`:283-290`); `dismissable` defaults to true (`:67`), a
  full-screen `TapClose` (`:88-100`). The launcher's notes set neither, so no timer runs and a
  tap anywhere dismisses them.

### The launcher widget: tinted icons, its taps and the network events

- `ui/renderimage`: `RenderImage:renderSVGImageFile(file, size, size)`
  (`frontend/ui/renderimage.lua:338-344`) returns a `TYPE_BBRGB32` buffer with straight alpha
  (`:390-393`), or nothing for a file NanoSVG can't open, logged by KOReader (`:355-358`).
  `tinted_icon.lua` calls it in `pcall` and draws nothing on either failure.
- `ffi/blitbuffer`, the tinted icon's mask: `Blitbuffer.new(size, size, TYPE_BB8)`
  (`base/ffi/blitbuffer.lua:2591`), `fill(COLOR_WHITE)` (`:1506`), `alphablitFrom` the render
  onto it (`:1318`, straight alpha), then `invertRect` (`:1567`): the ink is white, the ground
  black. At paint, `colorblitFrom(mask, ..., color)` for a `Color8` (`:1405-1420`) and
  `colorblitFromRGB32` for a colour (`:1422-1437`), split by `Blitbuffer.isColor8` (`:2712`)
  as `home_rows.lua` fills; both take the mask's 8-bit value as the colour's alpha
  (`setPixelColorize`, `:990-1006`; `setPixelColorizeRGB32`, `:1009-1027`). The mask is built
  once per build and freed with the widget (`free`).
- This replaces `ImageWidget`'s `dim`, which only lightens and assumes a white ground; the note at
  `frontend/ui/widget/imagewidget.lua:570-579` proposes the mask method used here.
- The tiles and rows: `paintRect` and `paintRectRGB32`, `paintBorder` and `paintBorderRGB32`, as
  the quote's tile above.
- A tap reaches the widget as `tap(ctx, ges, built)` from `HomeGestures.route` (through `Home:routeGesture`), `ges.pos` in screen
  coordinates; the grid keeps the origin it was last painted at and tests each entry's
  rectangle with `Geom:contains` (`frontend/ui/geometry.lua:255-266`).
- `NetworkDisconnected`: broadcast from `disableWifi`'s callback
  (`frontend/ui/network/manager.lua:406-408`); `NetworkConnected` as the weather's entry above.
  The home's handlers for both ask each slot's `stale` and rebuild once, and return nothing, so
  the broadcast reaches every window. In the emulator both come 2 s after the fake toggle
  (`frontend/device/sdl/device.lua:477-501`: `turnOnWifi` and `turnOffWifi` flip
  `emulator_fake_wifi_connected` and schedule the broadcast, and `isWifiOn` reads it).
- `ui/network/manager`: `NetworkMgr:isWifiOn()` (the launcher's entries above), read at call
  time by the launcher's `stale`.

### The sheet: its refreshes, keys, Back and gestures

- `UIManager:show(sheet, "ui", rect)` (`frontend/ui/uimanager.lua:229-273`) schedules the one
  paint of the panel and its shadow; `UIManager:close(sheet, "flashui", rect)` (`:290-355`)
  marks every window from the topmost `covers_fullscreen` one up dirty again, the home under
  the sheet, then refreshes the rectangle. `_repaint` (`:1298-1346`) paints from that window up
  and every window above a dirty one, so a home refresh repaints the sheet over it. The sheet's
  `dimen` is the whole screen and it is not `covers_fullscreen`.
- The refreshes follow `ButtonDialog`'s: `"ui"` on show unless coloured on a Kaleido panel
  (`frontend/ui/widget/buttondialog.lua:89-90`, `:327-331`) and `"flashui"` on close (`:333-337`).
  Only Kobo sets `hasKaleidoWfm` (`frontend/device/generic/device.lua:118`,
  `frontend/device/kobo/device.lua:800`), so on the Kindle it is `"ui"` too.
- The Back key: `key_events.Close = { { Device.input.group.Back } }` only where `Device:hasKeys()`,
  as `ButtonDialog` binds it (`buttondialog.lua:98-108`). `hasKeys` is false by default
  (`frontend/device/generic/device.lua:92`), true in the emulator
  (`frontend/device/sdl/device.lua:73`), and true on a Kindle only once a frame-tap input is
  found (`frontend/device/kindle/device.lua:553-556`, `:673-675`). `Device.input.group.Back` is
  `{ "Back" }` on every device's input (`frontend/device/input.lua:121`); `InputContainer:onKeyPress`
  matches it with `Key:match` (`frontend/ui/widget/container/inputcontainer.lua:238-250`,
  `frontend/device/key.lua:60-92`).
- KOReader's Back: the dispatcher's `fm_back` sends the `Back` event (`frontend/dispatcher.lua:169`)
  to the top widget, the sheet, whose `onBack` closes it and consumes it.
- The editor frame binds both as the sheet does: `key_events.Close = { { Device.input.group.Back } }`
  only where `Device:hasKeys()` (`buttondialog.lua:98-108`), and `onBack` for the `Back` event
  (`frontend/dispatcher.lua:169`), each closing it. Its taps are one `ges_events.TapEditor` whose
  range is a function returning its `dimen` (`frontend/ui/gesturerange.lua:25-37`), so a rebuild at
  a new size moves it.
- Taps: `ges_events.TapSheet`, one `GestureRange` (`frontend/ui/gesturerange.lua:14`, `:21-51`)
  over the whole screen, consumed wherever it lands, as `ButtonDialog:onTapClose` consumes a tap
  (`buttondialog.lua:347-352`), so `sendEvent` offers it to no window below
  (`frontend/ui/uimanager.lua:988-1031`). Under KOReader's touch lock `ges_events` are filtered as
  the home's zones are (the touch-lock entry above).
- Holds: a hold's lift sends `hold_release` to the top widget, by then the sheet
  (`frontend/device/gesturedetector.lua:1346-1356`); the sheet registers nothing for `hold`
  (unless its spec has a `hold`, the launcher management entry below), `hold_release`,
  `hold_pan` or swipes, so they reach only the active widgets below.
- The settled signal goes from a `nextTick` (`frontend/ui/uimanager.lua:431-433`) that the
  sheet's first good `paintTo` schedules: it runs from the next `_checkTasks`, past that
  `_repaint` (`handleInput` `:1542-1564`). Nothing is scheduled before the paint, so a sheet
  under a `covers_fullscreen` window waits without a task; polling there would keep
  `_task_queue_dirty` set and spin `handleInput`'s loop.
- The home closing by any path, KOReader's own close included, closes a shown sheet with it:
  `UIManager:close` sends `CloseWidget` before it walks the stack (`frontend/ui/uimanager.lua:298-300`),
  and the home's `onCloseWidget` calls `Sheet.close` in a `pcall`.

### The hold on the home: the `hold` gesture, Gestures' hold corners and the home sheet's rows

- The `hold` gesture fires while the finger is still down, after `HOLD_INTERVAL_MS`, 500 ms
  (`frontend/device/gesturedetector.lua:63`, `:1276-1287`); the lift sends `hold_release` to the
  top widget (`:1346-1356`), the sheet's entry above.
- Nothing under the home took a hold before: the file manager's menu zones are tap and swipe only
  (`frontend/apps/filemanager/filemanagermenu.lua:76-113`), so the home's hold zone has no
  menu-zone test, and the file chooser's hold is a menu item's `HoldSelect`
  (`frontend/ui/widget/menu.lua:124-128`, `frontend/apps/filemanager/filemanager.lua:171-177`),
  which `InputContainer.onGesture(fm, ges)` never visits, since it runs the file manager's own
  zones and `ges_events` only (`frontend/ui/widget/container/inputcontainer.lua:266-285`).
- The hold step runs after the zones registered on the file manager, so the Gestures plugin's
  four hold-corner zones win when bound: their rectangles come from `DTAP_ZONE_TOP_LEFT` and the
  other corners (`plugins/gestures.koplugin/main.lua:971-998`; `defaults.lua:66-69` in the
  KOReader root, each corner an eighth of each side), `hold_top_left_corner` to
  `hold_bottom_left_corner` are `ges = "hold"` (`main.lua:1124-1139`) with `overrides_hold_corner`
  (`:1044`), registered through `registerGesture` on the file manager (`:1287-1305`). Unbound, or
  with `ignore_hold_corners` (`:245`), `gestureAction` returns nothing (`:1316-1320`) and the hold
  carries on to the home's step.
- Gestures' default binds `hold_top_right_corner = { refresh_content = true }`
  (`plugins/gestures.koplugin/defaults.lua:11`): the dispatcher's `refresh_content`
  (`frontend/dispatcher.lua:162`, `RefreshContent`) reaches `FileManager.onRefreshContent`, the
  file chooser's `refreshPath` (`frontend/apps/filemanager/filemanager.lua:857-862`). That corner
  (`DTAP_ZONE_TOP_RIGHT`, `defaults.lua:67`: x from 1106 and y under 210 on the Colorsoft) covers
  the right end of both looks' clock, so a hold there refreshes the hidden file chooser and opens
  no sheet.
- The home sheet's Sleep row is the dispatcher's `suspend` (`frontend/dispatcher.lua:94`, listed
  only with `Device:canSuspend()`), run through `LauncherEntries.run` and the dispatch bridge as
  the launcher's action entries are: its `RequestSuspend` reaches the file manager's
  `devicelistener` (`filemanager.lua:414`), `DeviceListener:onRequestSuspend`
  (`frontend/device/devicelistener.lua:458-460`), which calls `UIManager:suspend`, which runs the
  `Suspend` handler on the next tick (`frontend/ui/uimanager.lua:1679-1686`). The emulator can
  suspend (`frontend/device/sdl/device.lua:165`) by simulation: its `Suspend` handler
  (`:417-428`) shows the screensaver (`simulateSuspend`, `:462-468`). The Kindle can
  (`frontend/device/kindle/device.lua:402`).
- Its Wi-Fi row is the launcher's Wi-Fi entry (the launcher's entries above); its Edit layout note
  is an `InfoMessage` with no timeout, as the launcher's notes are.
- "Wi-Fi" takes a plain hyphen: Diner's row face, `fonts/bricolage-grotesque/BricolageGrotesque-Bold.ttf`,
  has no U+2011 (`face.ftsize:hasGlyph(0x2011)` false, `base/ffi/freetype.lua:75`), so the
  boards' non-breaking hyphen would come from a fallback font.

### The book sheet: KOReader's status buttons, `BookList`, book details and the history's times

- `apps/filemanager/filemanagerutil`, required by `book_sheet.lua`:
  `filemanagerutil.genStatusButtonsRow(doc_settings_or_file, caller_callback)`
  (`frontend/apps/filemanager/filemanagerutil.lua:118-146`) builds the reading, abandoned and
  complete buttons in that order (`:141-145`). With a `DocSettings` it reads the file from its
  `doc_path` and the status from its raw `summary.status` (`:120-123`), so a sidecar with no
  status ticks nothing; with a bare path it starts from an empty `summary` and reads the status
  through `BookList.getBookStatus` (`:124-127`). The current status's button is the one with
  `enabled = false` (`:132`), the row the sub-sheet ticks. A button's `callback` sets
  `summary.status`, then calls `filemanagerutil.saveSummary` (`:106-115`: opens the sidecar with
  `DocSettings:open` when given a path, so it is created when there is none, sets
  `summary.modified` to today's `%Y-%m-%d`, saves `summary` and flushes), then
  `BookList.setBookInfoCacheProperty(file, "status", s)`, then the caller's callback, KoPanda's
  home refresh. The sub-sheet passes the `DocSettings` when `DocSettings:hasSidecarFile(file)`
  (`frontend/docsettings.lua:151-153`: true when `findSidecarFile`, `:159-175`, finds a sidecar
  file in any location, or the legacy history file when that location is enabled), so a
  sidecar's other summary fields survive the write. The file dialog chooses by the cached
  `BookList.hasBookBeenOpened(file)` instead (`frontend/apps/filemanager/filemanager.lua:255-270`,
  reached from `onFileHold`, `:171-177`), which a stale cache entry `{ been_opened = false }`
  answers false while a sidecar exists; a bare path's write then starts from an empty `summary`
  and wipes the note and rating.
- `ui/widget/booklist`, required by `book_sheet.lua`: `BookList.hasBookBeenOpened` (whether a
  sidecar exists, cached, `frontend/ui/widget/booklist.lua:348-356`), `getDocSettings`
  (`DocSettings:open`, caching the book's info, `:358-364`), `getBookStatus` (`"new"` for a book
  never opened, `:366-369`, through `getBookInfo`, `:337-346`), `getBookStatusString(status, false,
  true)` (`:386-389`: Reading, On hold, Finished for the single-book strings, `:380-384`, and New
  from the group strings, `:371-378`) and `setBookInfoCacheProperty` (`:318-326`), with the cache
  `BookList.book_info_cache` (`:15`). `setBookInfoCache` maps a missing or unknown status to
  reading (`:293-296`), so the book sheet's detail reads Reading where the sub-sheet ticks nothing.
- `DocSettings:open` removes a sidecar candidate it finds invalid, empty or not a table
  (`frontend/docsettings.lua:283-284`). `book_sheet.lua` reaches it through `getBookInfo`
  (`booklist.lua:337-346`) when the sheet opens, for the Read status detail, and through
  `getDocSettings` (`:358-364`) when the sub-sheet opens: the path KOReader's own file dialog takes
  on a hold. `featured_book.lua`'s rule of opening sidecars light (the featured book's entry above)
  covers that module only.
- `FileManager.instance.bookinfo:show(file)` (the module registered at
  `frontend/apps/filemanager/filemanager.lua:406`; `frontend/apps/filemanager/filemanagerbookinfo.lua:71-87`
  takes a path and opens the sidecar itself when the book has one) shows KOReader's book details
  page over the home. Its `close_callback` broadcasts `InvalidateMetadataCache` and
  `BookMetadataChanged` when a property was edited, and `BookMetadataChanged` when the summary was
  (`filemanagerbookinfo.lua:267-285`); the home handles neither, so an edit shows on the next
  rebuild. Read through `package.loaded` at tap time, as the featured widget's tap reads the file
  manager.
- `ReadHistory.hist[i].time` (`frontend/readhistory.lua:25-35`, the entry's `time` beside its
  realpath `file`, `:26`): set by `addItem` when a book opens (`:313-339`;
  `frontend/apps/reader/readerui.lua:510`) and by `updateLastBookTime` when it closes
  (`readhistory.lua:342-350`; `readerui.lua:882`). The book sheet's "opened" counts local calendar
  days from it, comparing the book by `ffi/util`'s `realpath`; `readhistory` is required at call
  time.
- The small cover is `FeaturedCover.build` at the sheet's `cover_w` by `cover_h`, which reads
  CoverBrowser's cache and never asks for an extraction; a cached cover too small for the box is
  left out by `BookInfoManager.isCachedCoverInvalid`
  (`plugins/coverbrowser.koplugin/bookinfomanager.lua:1013-1030`; the featured cover's entry above).

### The entry picker: `PathChooser`, the action tree, the plugin list and the label dialog

- `ui/widget/pathchooser`: `frontend/ui/widget/pathchooser.lua:13-21` (`select_directory`,
  `select_file`), `:104-155` (`onMenuHold` asks "Choose this folder?"; Choose calls
  `onConfirm(path)` with the `realpath`, `:109`, then closes its dialog and the chooser,
  `:151-155`). Opened as Folder shortcuts opens it
  (`frontend/apps/filemanager/filemanagershortcuts.lua:427-439`): at the file browser's
  `file_chooser.path`, or with no file browser the reader's `getLastDirFile()`
  (`apps/reader/readerui`: `frontend/apps/reader/readerui.lua:565-579`), both read through
  `package.loaded`. `onConfirm` runs guarded, so the chooser's own closes after it still run.
- `dispatcher`: `Dispatcher:addSubMenu(caller, menu, location, settings)`
  (`frontend/dispatcher.lua:1109-1170`) into a throwaway `caller` and scratch `location`; it runs
  `Dispatcher:init` (`:1110`, a return once initialized, `:586`) and sets `caller.updated`
  (`:924`, `:1125`), which nothing reads. Its order: "Nothing" at index 1 (`:1112-1131`), then one
  item per `section_list` entry (`:1132-1140`), each with a `sub_item_table` (`:1167`): General,
  Device, Screen and lights, File browser (indexes 2 to 5), then Reader, Reflowable and Fixed
  layout; arrange, execute and QuickMenu items follow (`:1170-1378`). The picker keeps 2 to 5 and
  refuses with a note unless there are at least eight items and each kept one has a
  `sub_item_table`. A hold on a section clears its ticks (`:1155-1165`).
- The scratch table's shape: `location[settings][id] = value` (`_addItem`'s `setValue`,
  `:913-927`), with `settings.order` beside the ids once two are ticked (`_addToOrder`,
  `:799-830`; `_itemsCount` leaves `settings` out, `:740-749`). `none` and `arg` actions store
  `true` (`:931-940`); `absolutenumber` and `incrementalnumber` a spin value (`:943-1024`);
  `string` and `configurable` an arg (`:1025-1067`). A launcher entry runs its action with `true`
  (`launcher_entries.lua`'s `run`), so only a `true` one is taken.
- Reader, reflowable and fixed-layout sections are dropped because `Dispatcher:isActionEnabled`
  (`:1435-1449`) disables a `reader`, `rolling` or `paging` action with no reader up.
- `Dispatcher.getDisplayList({ [id] = true })[1].text` (`:866-890`, `getNameFromItem` `:751-758`)
  is the action's label before editing.
- `pluginloader`: `PluginLoader:loadPlugins()` (`frontend/pluginloader.lua:273-292`, cached
  after the first call; its first list is the enabled plugins), `isPluginLoaded` (`:567-569`),
  `is_doc_only` (the file manager skips such a plugin, `frontend/apps/filemanager/filemanager.lua:419`),
  `fullname or name` as the plugin manager labels it (`pluginloader.lua:104-109`). `kopanda` is
  left out.
- `ui/widget/inputdialog`: `frontend/ui/widget/inputdialog.lua:124-167` (`title`, `input`,
  `buttons`), `:357` (`is_enter_default`), `:774-784` (`onCloseDialog` presses the button with
  `id = "close"`, Cancel here), `:583` (`getInputText`), `:596` (`setInputText`, the spec's),
  `:640` (`onShowKeyboard`, called after `show`, as `frontend/apps/filemanager/filemanagercollection.lua:1118-1119`
  does), `:633-638` and `:786-797` (closing it closes its keyboard).
- `util`: `util.trim` (`frontend/util.lua:52`); an all-space label is refused, the trimmed one
  kept.
- `ui/widget/touchmenu`, one tab: `TouchMenu:new{ width, tab_item_table = { items }, show_parent }`
  with `items.icon = "appbar.settings"` (`frontend/ui/widget/touchmenu.lua:469-470`, `:539-548`, the
  tab bar's icons), inside a full-screen `CenterContainer` as `FileManagerMenu:onShowMenu` shows its
  menu (`frontend/apps/filemanager/filemanagermenu.lua:1006-1047`). `close_callback` replaces
  the default close (`touchmenu.lua:500-504`); `closeMenu` (`:973-975`) calls it from a tap
  outside (`:977-981`), `onClose` (`:983-985`) and Back at the top level (`:798-818`). The picker
  closes the container itself, once. `onMenuSelect` (`:873-929`) opens a section and runs an
  action item's callback.
- `logger.err` for every guarded failure; the sheets are `sheet.lua`'s.

### Launcher management: `ConfirmBox`, the sheet's hold and `util`'s table copies

- `ui/widget/confirmbox`: `frontend/ui/widget/confirmbox.lua:45-51` (`text`, `ok_text`,
  `ok_callback`, `cancel_callback`), `:62` (`init`), `:107-122` (Cancel runs `cancel_callback`,
  OK runs `ok_callback`, each then closes the box), `:242-247` (`onClose`, from the Back key and
  from a tap outside it, `:249-254`, runs `cancel_callback`). Removing a launcher folder asks
  through it, `ok_text = "Remove"`; Cancel writes nothing, and the `ok_callback` runs guarded.
- `util`: `util.tableDeepCopy` (`frontend/util.lua:184-202`) copies `launcher.entries` before
  every list operation, since `Settings.get` hands back the stored table; `util.tableEquals`
  (`:146-174`) finds the folder sheet's folder among the stored entries, the sheet holding the
  entry the launcher was built with.
- The sheet's hold: `ges_events.HoldSheet`, a `GestureRange` of `ges = "hold"` whose range is a
  function returning the panel (`frontend/ui/gesturerange.lua:25-37`), registered only for a spec
  with `hold`. The sheet closes, then runs it; the lift's `hold_release`
  (`frontend/device/gesturedetector.lua:1346-1356`) reaches the editor it opened, which has no
  handler for it.
- The launcher's hold: the home's hold step (`home_gestures.lua`) calls the widget's `hold`,
  which returns nothing, so the step takes the hold as done and opens no settings.
- The editor's Done runs the spec's `done` when it has one, a folder's list opened from the top
  level going back to it; the frame's show and close are the editor entries above.

### Widget and support modules

- `ui/widget/container/widgetcontainer`: `frontend/ui/widget/container/widgetcontainer.lua:19`
  (the plugin's base class).
- `ui/widget/container/inputcontainer`: `frontend/ui/widget/container/inputcontainer.lua:52`
  (the home's base class).
- `ui/widget/container/framecontainer`: `frontend/ui/widget/container/framecontainer.lua:27`
  (`width`, `height`, `background`), `:104` (`paintTo`).
- `ui/widget/container/centercontainer`: `frontend/ui/widget/container/centercontainer.lua:7`.
- `ui/widget/container/leftcontainer`: `frontend/ui/widget/container/leftcontainer.lua:8-10`
  (`allow_mirroring`), `:12-26` (`paintTo` aligns its content left and centres it vertically in
  `dimen`, `:19-23`); the date's column and the weather's line.
- `ui/widget/container/rightcontainer`: `frontend/ui/widget/container/rightcontainer.lua:8-10`,
  `:12-26` (`paintTo` aligns its content right and centres it vertically in `dimen`, `:19-23`);
  the clock's column.
- `ui/widget/verticalgroup`: `frontend/ui/widget/verticalgroup.lua:8`.
- `ui/widget/verticalspan`: `frontend/ui/widget/verticalspan.lua:6`.
- `ui/widget/widget`: `frontend/ui/widget/widget.lua:40` (`new`), `:70` (`paintTo` draws nothing),
  the home's blank slot.
- `ui/widget/textwidget`: `frontend/ui/widget/textwidget.lua:27` (`text`, `face`).
- `ui/widget/textboxwidget`: `frontend/ui/widget/textboxwidget.lua:37` (`text`, `face`,
  `width`, `fgcolor`, `bgcolor`; the swatch entry above).
- `ui/widget/horizontalgroup`: `frontend/ui/widget/horizontalgroup.lua:9` (`align`).
- `ui/widget/horizontalspan`: `frontend/ui/widget/horizontalspan.lua:6` (`width`).
- `ui/widget/iconwidget`: `frontend/ui/widget/iconwidget.lua:43` (`file`, `width`, `height`,
  `alpha`; the swatch entry above).
- `datetime`: `frontend/datetime.lua:29-42`, `:54-62` (the date and clock entry above).
- `util`: `frontend/util.lua:469` (`splitToChars`, the date and clock entry above).
- `ui/font`: `frontend/ui/font.lua:269-276` (`getFace` scales the size by
  `Screen:scaleBySize` itself).
- `ui/geometry`: `frontend/ui/geometry.lua:37` (`Geom:new`), `:255-266` (`contains`).
- `ui/gesturerange`: `frontend/ui/gesturerange.lua:14` (`new`, `ges` and `range`), `:21-51`
  (`match`); the sheet's tap range.
- `ffi/blitbuffer`: `base/ffi/blitbuffer.lua:2717` (`COLOR_WHITE`), `:2653-2683`
  (`colorFromString`, the looks entry above).
- `ui/uimanager`: the entries above.
- `ui/time`: `frontend/ui/time.lua:149` (`to_ms`), `:249` (`monotonic`).
- `optmath`: `frontend/optmath.lua:43-45` (`Math.round`, the quote entry above).
- `device`: `frontend/device/generic/device.lua:332` (`Screen:getSize`), `:265-271`
  (`Screen:isColorEnabled`, the looks entry above);
  `base/ffi/framebuffer.lua:348` (`getWidth`), `:352` (`getHeight`), `:414` (`scaleBySize`).
- `logger`: `frontend/logger.lua:96` (`warn`), `:97` (`err`); see the harness entry `logger` below.

## Capture harness (`spec/emulator/`)

### `UIManager.event_hook`

- `frontend/ui/uimanager.lua:53`; `frontend/ui/hook_container.lua:34-41` (`register`),
  `:88-98` (`execute`).
- A `HookContainer`. The capture patch registers a `KoPandaSettled` listener and the plugin
  under test executes it with `{ screen, paint_ms, settle_ms, prebuilt }`. The patch shoots on the first
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
  `handleInput` `:1537-1564`.
- Tasks run only from the UI loop, so the patch's watchdog cannot fire while KOReader hangs:
  the driver's kill covers that.
- `tickAfterNext` re-queues its action through `nextTick` at `time.now()`; the action lands
  past the next `_repaint` only when `time.now()` has advanced past the `_now` that
  `_checkTasks` sampled at `:1082`, since a task due at `_now` runs in the same pass
  (`:1088-1097`).
- `time.now` is `time.monotonic_coarse` (`frontend/ui/time.lua:300`), which on macOS is
  `CLOCK_MONOTONIC` at µs resolution (`:185-199`). When the `_now` sample
  (`frontend/ui/uimanager.lua:1082`) and the wrapper's `nextTick` schedule time
  (`time.now()` at `uimanager.lua:416`) fall in the same floored microsecond, the re-queued
  action is due at `_now` and runs in the same pass: the probe's `tickAfterNext` signal ran
  before the first `_repaint` in about 6 % of captures, a blank white shot. The probe now
  queues its signal with `nextTick` from its widget's first `paintTo`, inside `_repaint`, so
  it always runs past the paint; `spec/emulator/scenarios/2-scenario-held-clock.lua` holds
  `time.now()` through each pass so a capture spec reproduces the race on every run. The
  home's own settle did the same until it too moved to its first `paintTo`: about one run in
  ten of `spec/unit/push_notice_spec.lua` gave the show's `finished` `false` after a good
  paint, and that spec now holds `time.now()` to reproduce it on every run.

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

### `emulator_fake_wifi_connected`

- `frontend/device/sdl/device.lua:478-500` (the emulator's `NetworkMgr:isConnected` and
  `isWifiOn` read it, true when unset). The driver writes it false into every profile and
  `spec/plugin_harness.lua` sets it false on each load, so no capture or unit spec fetches the
  weather; a spec that wants a connection stubs `isConnected`.

### `night_mode`

- `frontend/device/generic/device.lua:344-347` (the device toggles night mode before any UI
  exists when it is set); `base/ffi/framebuffer.lua:566-581` (`Screen:shot` writes what the
  panel shows in night mode too).
- Written true only by a capture with `night_mode` (`night_golden_spec.lua`); every other profile
  leaves it absent, so its `settings.reader.lua` is as before.

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

### The gesture-forward scenario (`spec/emulator/scenarios/2-scenario-gesture-forward.lua`)

- The Gestures settings file: `plugins/gestures.koplugin/main.lua:32`
  (`settings/gestures.lua`), `:227-252` (`loadSettings`: one table per mode, `gesture_fm` for
  the file manager, and `custom_multiswipes`; a non-empty file is used as it is, `:231`). The
  patch writes it with `LuaSettings` (`frontend/luasettings.lua:21-48`, `:102`) before any
  plugin loads, binding `tap_right_bottom_corner` to `history` (`frontend/dispatcher.lua:68`,
  event `ShowHist`).
- The tap: a `Gesture` event sent with `UIManager:sendEvent` inside `DTAP_ZONE_BOTTOM_RIGHT`
  (`defaults.lua:69`), with the fields `GestureRange:match` reads
  (`frontend/ui/gesturerange.lua:21-51`).
- `FileManager.instance.history.booklist_menu`: `frontend/apps/filemanager/filemanagerhistory.lua:59-61`
  (the list `onShowHist` shows), checked with `UIManager:isWidgetShown`
  (`frontend/ui/uimanager.lua:881-888`); the home with `UIManager:topdown_widgets_iter`
  (`:846`).

### The swatch scenario (`spec/emulator/scenarios/2-scenario-swatch.lua`)

- On the first home's settled signal it opens Tools › KoPanda › Swatches as the menu does:
  `FileManager.instance.menu:onShowMenu()` (`frontend/apps/filemanager/filemanagermenu.lua:1006-1032`,
  which builds `tab_item_table` at `:1007-1009`, `:862`), the item's `callback`, then `onCloseFileManagerMenu`
  (`:1049`), the order `frontend/ui/widget/touchmenu.lua:913-926` runs them in. The capture is
  taken on the swatch's own signal (`shot_screen = "swatch"`); a failure is sent as a `"swatch"`
  signal with `error`.

### The night-toggle scenario (`spec/emulator/scenarios/2-scenario-night-toggle.lua`)

- On the first home's settled signal it wraps the home module's `paintTo`
  (`package.loaded["home"]`, `kopanda.koplugin/home.lua`) to count the paints from then on, and
  toggles night mode from `nextTick` by `KOPANDA_NIGHT_ROUTE`:
  - `menu`: `UIManager:broadcastEvent(Event:new("ToggleNightMode"))`
    (`frontend/ui/uimanager.lua:1042`), what the menu item runs
    (`frontend/ui/elements/common_settings_menu_table.lua:266-271`);
  - `dispatcher`: `Dispatcher:execute({ night_mode = true })` (`frontend/dispatcher.lua:138`,
    `:1549-1598`, sent with `sendEvent`), through the plugin's dispatch bridge.
- Either reaches the file manager's `DeviceListener` (`frontend/apps/filemanager/filemanager.lua:414`),
  which toggles the screen and calls `setDirty("all", "full")`
  (`frontend/device/devicelistener.lua:14-27`). The scenario reports, from `tickAfterNext`
  (past that repaint), a `"scenario"` signal with `home_paints` and `night_mode`, the screen's
  `night_mode` (`base/ffi/framebuffer.lua:22`); a failure is reported with `error`.

### The cover-rect scenario (`spec/emulator/scenarios/2-scenario-cover-rect.lua`)

- On the first home's settled signal it finds the featured slot's `ImageWidget` in
  `package.loaded["home"].shown` (by metatable: `Widget:new` makes the class the instance's metatable,
  `frontend/ui/widget/widget.lua:26-31`, `:40-48`) and reports the `dimen` its `paintTo` kept
  (`frontend/ui/widget/imagewidget.lua:518-531`) as `cover_x`, `cover_y`, `cover_w`, `cover_h`
  in a `"scenario"` signal. That is the rectangle `ImageWidget` inverts again in night mode
  (`:76-77`, `:583-593`), which `night_golden_spec.lua` compares un-inverted on the Paperwhite.

### The sheet-hold scenario (`spec/emulator/scenarios/2-scenario-sheet-hold.lua`)

- Run after the home fixture by `sheet_golden_spec.lua`. On the first home's settled signal it
  finds the home with `UIManager:topdown_widgets_iter` (`frontend/ui/uimanager.lua:846`) and,
  from `nextTick`, sends one `Gesture` hold with `UIManager:sendEvent` (`:962-1034`), with the
  fields `GestureRange:match` reads (`frontend/ui/gesturerange.lua:21-51`), at a point
  `KOPANDA_SHEET_HOLD` names: `book`, the centre of the featured slot's rectangle; `home`,
  `x = 4` at half the screen's height, checked outside every slot and outside the four
  `DTAP_ZONE_*` corners (`defaults.lua:66-69`, read through `G_defaults:readSetting`). No
  `hold_release` follows. The capture is taken on the sheet's own signal
  (`shot_screen = "sheet"`); a failure is sent as a `"sheet"` signal with `error`.

### The home fixture (`spec/emulator/scenarios/2-scenario-home-fixture.lua`)

- Read by `home_golden_spec.lua`, `home_capture_spec.lua`, `night_golden_spec.lua`,
  `night_toggle_spec.lua` and `sheet_golden_spec.lua`, whose captures pass `TZ`,
  `KOPANDA_HOME_FIXTURE` (`populated`, `typecover` or `empty`) and, for Editorial,
  `KOPANDA_HOME_LOOK` through the driver's `env` option. Applied at `reader.lua:190`, before any
  plugin code runs.
- `os.time()` and `os.date(format)` with no time argument are replaced for the whole process and
  answer 2026-10-13 08:42 in `TZ` (America/Chicago); calls with a time pass through. KOReader's
  own no-argument callers, such as the log line's stamp (`frontend/logger.lua:73`), read the frozen
  instant too. `ui/time`'s monotonic clock is untouched, so `paint_ms` stays real.
- No `NetworkMgr` stub: the driver's `emulator_fake_wifi_connected = false` (the entry above)
  already makes `isConnected` false, so no fetch runs after the show or from the start-up
  `NetworkConnected` (`frontend/ui/network/manager.lua:152-154`, sent only when connected).
- Populated, it writes, from `DataStorage:getSettingsDir()` (`datastorage.lua:60`):
  - `kopanda/weather.lua`, the cache `kopanda.koplugin/weather.lua` writes, through `LuaSettings`
    (`frontend/luasettings.lua:21` `open`, `:247` `reset`, `:270` `flush`);
  - `statistics.sqlite3` (`plugins/statistics.koplugin/main.lua:27`) through the emulator's
    `lua-ljsqlite3/init` (`base/thirdparty/lua-ljsqlite3/init.lua:331`, `exec` splitting on `;` at
    `:381-391`), with the plugin's DDL (`main.lua:405-496`) and `user_version` 20221111 (`:35`).
    On a fresh profile `checkInitDatabase` finds the `book` table and creates nothing
    (`main.lua:372-374`); with `convert_to_db` set it compares the version (`:318-319`) and leaves
    a current one as it is.
- Populated and typecover, it also writes the featured book, `frankenstein.epub` under
  `$KOPANDA_ROOT/spec/fixtures/library/`, by its realpath (`base/ffi/util.lua:162-171`), the form
  history stores (`frontend/readhistory.lua:25-26`):
  - `G_reader_settings` `document_metadata_folder = "dir"`, in memory for the run: `DocSettings`
    reads it for each lookup and write (`frontend/docsettings.lua:101-111`, `:118-136`,
    `:317-339`), so the sidecar lands under `<KO_HOME>/docsettings/` (`datastorage.lua:67-69`) and
    nothing is written into the fixture library;
  - `<KO_HOME>/history.lua` (`readhistory.lua:12`) in the `{ time, file }` form `_flush` writes
    (`:89-97`) and `_read` `dofile`s (`:103-119`), through `util.writeToFile`
    (`frontend/util.lua:1124`). `ReadHistory` reads it when first required (`:369-373`); one already
    loaded is made to read it again with `reload(true)` (`:359-367`);
  - the sidecar through `DocSettings:open` (`docsettings.lua:221`), `saveSetting`
    (`frontend/luasettings.lua:102-105`, chainable) and `flush` (`docsettings.lua:317-339`):
    `percent_finished` 0.62, `doc_pages` 220, `doc_props` title and authors, `summary.status`
    `reading` and `partial_md5_checksum` from `util.partialMD5` (`util.lua:1094`), the keys ReaderUI
    saves (`frontend/apps/reader/modules/readerrolling.lua:338`,
    `frontend/apps/reader/readerui.lua:493`, `:497-501`);
  - in `statistics.sqlite3`, a `book` row with that md5 and `pages = 220`, and ten
    `page_stat_data` rows of 90 s on 2025-01-01 with `total_pages = 220`, so the `page_stat` view
    keeps them as they are (`plugins/statistics.koplugin/main.lua:438-451`) and each stays under the
    default 120 s `max_sec` (`:30`): 84 pages left at 90 s is "2 h 6 min left";
  - `kopanda/state.lua`, KoPanda's runtime state, with `featured_chapter_file` and
    `featured_chapter = "Letter IV"`, through `LuaSettings`.
- Typecover adds `coverbrowser` to `G_reader_settings`' `plugins_disabled` in memory, which
  `PluginLoader:_discover` reads later in `FileManager:init` (`frontend/pluginloader.lua:175`,
  `:210-216`).
- Populated wraps `PluginLoader.loadPlugins` (`pluginloader.lua:273-291`). After its first call,
  which `FileManager:init` makes before it instantiates any plugin
  (`frontend/apps/filemanager/filemanager.lua:418`) and which puts CoverBrowser's folder on
  `package.path` (`pluginloader.lua:283-287`), it requires `bookinfomanager` and runs
  `extractBookInfo(file, { max_cover_w, max_cover_h })`
  (`plugins/coverbrowser.koplugin/bookinfomanager.lua:422-570`) synchronously, for the featured
  widget's own full-width box (`featured_cover.lua` `FeaturedCover.box`), so
  `isCachedCoverInvalid` (`:1013-1030`) passes and the widget asks for no extraction after the
  show. It then checks `getBookInfo(file, false)` (`:325-404`) for `has_cover`. Run in-process,
  `extractBookInfo` points crengine's cache at CoverBrowser's `tmpcr3cache` for the rest of the run
  (`:423-439`); the home draws nothing with crengine. All of it runs before the file manager's
  `Show`, where KoPanda's `paint_ms` clock starts, so `paint_ms` never includes it.
- It opens `kopanda/settings.lua` once and writes the keys its scenario sets with
  `schema_version = 1` (`frontend/luasettings.lua:21` `open`, `:102` `saveSetting`, `:270`
  `flush`), as `kopanda.koplugin/settings.lua` stores them: `look` when a look is given, and,
  empty, `launcher.entries` as the schema's default five without Settings and a sixth
  `{ kind = "plugin", plugin = "kopanda_absent", action = "terminal", label = "Terminal", icon = "terminal" }`.
  No plugin has that name, so `PluginLoader:isPluginLoaded` (`frontend/pluginloader.lua:567-569`,
  a lookup in `loaded_plugins`) is false on every profile and the entry shows "plugin missing",
  whatever plugins the emulator's own `plugins/` holds.
- Any failure logs `KOPANDA_SCENARIO: home fixture failed` and exits with status 4, which the
  driver reports with the log tail.

### Multi-start runs (`run_starts`), exit 85 and no relaunch on macOS

- `frontend/ui/uimanager.lua:1765-1769` (`restartKOReader` quits with 85); `reader.lua:312-313`
  (`exitReader` returns a numeric exit code), `:328` (`os.exit` with it).
- `frontend/device/sdl/device.lua:142` (`canRestart = notOSX`): the emulator on macOS doesn't
  start itself again on 85, and running `./luajit reader.lua` directly has no launcher loop, so the
  driver's next start is the relaunch. `run_starts` writes the scratch profile once and runs each
  start on it, accepting the exit statuses that start lists (85 for a start that restarts, 3 for a
  start the capture patch's settle cap ends). The capture patch is inactive in a start without
  `shot` (`KOPANDA_SHOT` unset, `spec/emulator/patches/2-kopanda-capture.lua:8-11`).
- Extra plugins (`extra_plugins`) are copied into `<KO_HOME>/plugins/`; one whose folder name the
  emulator's own `plugins/` also holds would load twice, so the driver refuses it. That `plugins/`
  is a symlink to `~/Projects/kodev/koreader/plugins` (scanned as `plugins`,
  `frontend/pluginloader.lua:24`, `:177`), which holds the real `simpleui`, `bookshelf` and
  `solariconpack`; the push spec's stand-in shell is therefore `spec/fixtures/push/shells/ennui.koplugin`,
  which the coexistence guard matches lower-cased (`kopanda.koplugin/guards.lua:11-17`) and which
  the driver's default disabled list, matched by exact name (`pluginloader.lua:211-212`), leaves on.

### The push server (`spec/emulator/push_server.lua`): `socket.bind`

- `base/build/arm64-apple-darwin23.5.0-debug/common/socket.lua:27-40` (`bind`: a listening TCP
  socket, `reuseaddr` set); LuaSocket's `getsockname`, `settimeout` and `accept`
  (`base/build/arm64-apple-darwin23.5.0-debug/thirdparty/luasocket/source/src/tcp.c:47`, `:56`,
  `:66`).
- Bound to `127.0.0.1` on port 0, so the system picks a free port and parallel worktrees never
  collide; the port is written to a file the spec waits for. `accept` with a timeout of the
  server's lifetime returns nil once that long passes with no connection, and the server exits.
  It runs as its own process: Busted blocks on the driver's `io.popen():read` while the emulator
  runs.
- KOReader's `socket.http` client (the pull's, the Studio menu entry above) reads the body by
  `Content-Length`; every answer carries it and `Connection: close`.

### The push-pull scenario (`spec/emulator/scenarios/2-scenario-push-pull.lua`)

- Active when `KOPANDA_PUSH_ADDRESS` is set. Polls with `UIManager:scheduleIn` until
  `FileManager.instance` (`frontend/apps/filemanager/filemanager.lua:447`) and KoPanda's
  `push_pull` and `guards` modules are in `package.loaded` (required by `main.lua` at load, in the
  refused instance too).
- KoPanda's folder is the `path` the loader set on its module (`frontend/pluginloader.lua:248`),
  found in `PluginLoader:loadPlugins()` (`:273-291`); the data folder is `DataStorage:getDataDir()`
  (`datastorage.lua:16-20`, `KO_HOME`). The pull is `PushPull.pull` with `Guards.enabled_shell_names()`,
  called directly: the emulator's Wi-Fi is off (`emulator_fake_wifi_connected` above), so
  `NetworkMgr:runWhenConnected` is bypassed.
- Then `UIManager:broadcastEvent(Event:new("Restart"))` (`frontend/ui/uimanager.lua:1042`,
  `frontend/ui/event.lua:30`), as the restart offer does: `DeviceListener:onRestart`
  (`frontend/device/devicelistener.lua:454-456`) closes the file manager
  (`frontend/apps/filemanager/filemanagermenu.lua:998-1004`) and quits with 85. A failed pull logs
  `KOPANDA_SCENARIO: <message>` and quits with 5.

### The notices scenario (`spec/emulator/scenarios/2-scenario-notices.lua`)

- Active when `KOPANDA_NOTICES` names a file. Wraps `UIManager.show`
  (`frontend/ui/uimanager.lua:229`) at patch time, before any plugin runs (`reader.lua:190`), so
  the plugin's `UIManager:show` calls go through it; an `InfoMessage`
  (`frontend/ui/widget/infomessage.lua:47`) is told by its metatable, which `Widget:new` sets to the
  class (`frontend/ui/widget/widget.lua:26-31`, `:40-48`). Each one's `text` is appended to the
  file as one line before the original `show` runs; the spec reads the last line.

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
- `bin/schema-json` encodes the schema with `sort_keys` and `pretty`
  (`base/thirdparty/lua-rapidjson/build/downloads/source/API.md:79-80`), so two runs are
  byte-identical; `spec/unit/schema_json_spec.lua` decodes it. The bundled dkjson orders only the
  keys it is given and the rest in `pairs` order (`common/dkjson.lua:325-346`).

### `RenderImage:renderSVGImageFile`, the icon check

- `frontend/ui/renderimage.lua:338-345` (`renderSVGImageFile`), `:349` (NanoSVG is the renderer),
  `:351-393` (a `TYPE_BBRGB32` buffer of the requested size, the drawing centred at its aspect
  ratio, returned with straight alpha at `:393`).
- NanoSVG draws a file's own colours; an unknown colour name such as `currentColor` parses to
  grey 128 (`base/build/arm64-apple-darwin23.5.0-debug/staging/include/nanosvg.h:1446-1457`), and
  the rasteriser unpremultiplies its output (`nanosvgrast.h:1206`, `:1450`), so a black stroke's
  anti-aliased edge stays R = G = B = 0.
- `spec/unit/icons_spec.lua` renders every registered icon at 48×48 and reads each pixel with
  `Blitbuffer:getPixel` (`base/ffi/blitbuffer.lua:819-827`; a `ColorRGB32` has `r`, `g`, `b`,
  `alpha`, `:54-59`). The plugin itself only names icon files, through `icons.lua`.
