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
  settle_ms, prebuilt }`, once per home; the capture harness entry below is the listener.
  `paint_ms` runs from the start of the show path to the end of the home's first `paintTo`;
  `settle_ms` runs on to the signal, which `tickAfterNext` (`uimanager.lua:447-456`) queues
  behind tasks already due on the tick after the paint, such as coverbrowser's background
  extraction (`plugins/coverbrowser.koplugin/covermenu.lua:119`, a fork).

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
  at gesture time. The home's own zones (touch lock entry below) cover the screen at the home's
  build size and test these bands in their handlers.
- Screen ratios. A tap inside the top menu zones leaves the home up. The swipe up that
  opens the settings stub starts in the bottom edge band and outside the left and right bands,
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
  `ges_events`). The home calls `InputContainer.onGesture(fm.menu, ges)`, then
  `InputContainer.onGesture(fm, ges)`.
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
- The home overrides `onGesture`, so its own steps, the swipe up to the settings stub and the
  closing tap, are touch zones on the home (`kopanda_home_swipe_up`, `kopanda_home_tap`) run
  through `InputContainer.onGesture(self, ges)`: under the lock they match nothing and the
  settings message, whose `show` would lift the lock, never shows. A zone's handler only records
  its step; `routeGesture` runs it in place, the closing tap after the forwarded steps. The
  forwarded steps go through `InputContainer.onGesture` too, so under the lock the file
  manager's zones the Gestures plugin marks always active still run. The lock's state is read
  nowhere: `UIManager._input_gestures_disabled` is private.

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
  `addToMainMenu` gives Tools › KoPanda the one item Swatches; the Home tab, Home and Settings
  are left out.

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
  `:1827` (`paintRectRGB32`): the paper, header band, edge, rule and footer stripe are filled as
  the swatch screen fills its panels.

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

### The featured cover: CoverBrowser's `bookinfomanager`, `ImageWidget` and the bounded check

- `bookinfomanager` (`plugins/coverbrowser.koplugin/bookinfomanager.lua`), reached by
  `pcall(require, "bookinfomanager")` in `featured_cover.lua`, at call time. The plugin's folder
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
  with it a fresh decompressed `cover_bb` when `has_cover` is set (`:380-396`). The build reads
  with `true`; the extraction test reads with `false`; each check reads with `false` first, and
  the last check with `true`.
- A row with `ignore_cover` draws the placeholder even with a cached cover, its bitmap freed, as
  CoverBrowser draws no cover for it (`plugins/coverbrowser.koplugin/mosaicmenu.lua:508`,
  `listmenu.lua:272`).
- `isCachedCoverInvalid(bookinfo, cover_specs)`, a plain function (`:1013-1030`): true for a row
  with no `cover_w` (`:1014-1015`), so the never-ask rows are tested before it, in
  `plugins/coverbrowser.koplugin/mosaicmenu.lua:471-488`'s order. An unusable `cover_bb` is freed,
  as `mosaicmenu.lua:478-479` does.
- `extractInBackground(files)` (`:689-745`): terminates earlier jobs, CoverBrowser's own included
  (`:695`), closes the database connection (`:699`), forks the extraction (`:721`) and returns
  `true` (`:744`), or `false` when the fork fails (`:724`). Asked at most once per file per
  process, only from `FeaturedCover.after_show`, never from `build` or `paintTo`.
- `isExtractingInBackground()` (`:685-687`), the only completion signal, counts CoverBrowser's own
  jobs too. CoverBrowser polls it once a second (`plugins/coverbrowser.koplugin/covermenu.lua:164-175`);
  the featured cover does the same through `UIManager:scheduleIn` (`frontend/ui/uimanager.lua:413`)
  for at most 30 checks, and `FeaturedCover.cancel` drops it with `UIManager:unschedule` (`:518`).
- It turns false only when CoverBrowser's collector reaps the extraction's pid, every
  `subprocesses_collect_interval` = 10 s (`bookinfomanager.lua:139`; `collectSubprocesses`
  `:627-650`, first scheduled by `extractInBackground` at `:735-742`), so a cover written at 2 s
  would wait for it. Each check therefore reads the row first and stops once it holds a cover
  that fits.
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

### `emulator_fake_wifi_connected`

- `frontend/device/sdl/device.lua:478-500` (the emulator's `NetworkMgr:isConnected` and
  `isWifiOn` read it, true when unset). The driver writes it false into every profile and
  `spec/plugin_harness.lua` sets it false on each load, so no capture or unit spec fetches the
  weather; a spec that wants a connection stubs `isConnected`.

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

### The home fixture (`spec/emulator/scenarios/2-scenario-home-fixture.lua`)

- Read by `home_golden_spec.lua` and `home_capture_spec.lua`, whose captures pass `TZ`,
  `KOPANDA_HOME_FIXTURE` (`populated` or `empty`) and, for Editorial, `KOPANDA_HOME_LOOK` through
  the driver's `env` option. Applied at `reader.lua:190`, before any plugin code runs.
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
- With a look, it writes `kopanda/settings.lua` with `look` and `schema_version = 1`
  (`frontend/luasettings.lua:102` `saveSetting`), as `kopanda.koplugin/settings.lua` stores it.
- Any failure logs `KOPANDA_SCENARIO: home fixture failed` and exits with status 4, which the
  driver reports with the log tail.

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
