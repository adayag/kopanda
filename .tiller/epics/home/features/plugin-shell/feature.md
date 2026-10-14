# The plugin shows a home over the file browser

## Summary

`kopanda.koplugin` loads under KOReader and puts a full-screen home widget over the file browser whenever
the file browser appears, the way ennUI does (design §5, Entry), with every hook wrapped so a failure
leaves KOReader's own file browser usable. The home it draws is a placeholder until `home-layout`; this
feature is the lifecycle, the ways in (a Home tab, Tools entries, a dispatcher action), the gesture
routing that keeps KOReader reachable from under the home, and the safety nets (coexistence refusal,
boot guard).

## Behavior

- The plugin registers with `is_doc_only = false`, so KOReader makes an instance of it in both the file
  manager and the reader.
- When the file browser is shown, the home appears over it, `covers_fullscreen`, so nothing beneath is
  painted, and it covers whatever KOReader's `start_with` setting opens on top of the file browser
  (history, favorites, folder shortcuts); `start_with = last` opens a book and no home. The home closes
  when the file browser closes (a book opens, KOReader quits).
- When a book closes, the home is pre-built before the file browser reappears, so showing it costs a
  paint and no build, and the file browser itself is never painted. The pre-build happens on every
  close, including a document switch, a reload and an exit, none of which brings back a file browser;
  that wasted build is accepted and the pending home is dropped when no file browser follows.
- After the home's first paint, the plugin announces it with the dev-loop settled signal
  (`KoPandaSettled`, `screen = "home"`, `paint_ms`), so the capture harness shoots the real plugin.
- Until `home-layout`, the home is a placeholder: the name "KoPanda" and the line "Tap to open the file
  browser". Tapping it outside KOReader's top menu zone and Gestures corner zones closes it and
  reveals the file browser beneath.
- Ways to the home: a Home tab in the file manager's top menu (KOReader's `home` icon, second tab) that
  opens the home when tapped; a KoPanda entry in the Tools menu of the file manager and of the reader,
  with Home and Settings; and the dispatcher action "KoPanda: home", which a Gestures or Profiles
  binding can run. In the reader, Home and the action close the book and land on the home.
- On the home, a swipe up from the bottom edge opens KoPanda's settings, which are a stub until
  `device-menus`. Nowhere else claims that gesture: not the file browser, not the reader.
- KOReader stays reachable from under the home: a tap or a downward swipe in KOReader's top menu zone
  opens the file manager's menu, exactly as it would without the home; every other gesture the home
  does not use is passed to the file manager's own touch zones, where the Gestures plugin registers its
  gestures, so its actions (frontlight edges, corners, multiswipes) work on the home; and actions
  those gestures dispatch still reach the file manager's modules (History, Collections and the like).
- A home that didn't finish drawing at the last start is skipped once, with a notice naming where to
  open it from (ennUI's `boot_pending`).
- If SimpleUI, Bookshelf or ennUI is enabled, the shell does not start: no home, no tab, no Tools
  entry, no action; one message per start names which.
- `HOOKS.md` lists every KOReader internal this feature reads or patches, with `file:line` at the
  pinned build.
- No settings key is added. The boot flag and the tab-index migration marker are runtime state in
  `settings/kopanda/state.lua`, which is not a setting and which the studio never sees.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`; ennUI is
`critterforks/ennUI.koplugin` at `ae26fc4` (no licence: read, never copied); SimpleUI is the copy in the
emulator's `plugins/simpleui.koplugin` (2.7.5, MIT); Bookshelf the copy in the emulator's
`plugins/bookshelf.koplugin` (AGPL, read only).

### Plugin and modules

- `kopanda.koplugin/` holds `_meta.lua` (`fullname`, `description`, `version`; no `name`, which
  KOReader ignores with a warning, `frontend/pluginloader.lua:256-259`) and `main.lua`, a
  `WidgetContainer` with `is_doc_only = false`. The runtime name is the folder's, `kopanda`
  (`pluginloader.lua:210`, set at `:249`).
- KOReader prepends the plugin's root to `package.path` only while it `dofile`s `main.lua`
  (`pluginloader.lua:242`, restored at `:269-270`) and afterwards appends every enabled plugin's root
  (`:283-286`), so a same-named module in another plugin could shadow a lazy `require`. `main.lua`
  therefore requires every KoPanda module at load time. `package.loaded` is one table for the process,
  so module names also avoid every module path in KOReader's `frontend/` and `common/` and in the
  emulator's bundled and installed plugins; a spec checks it.
- `main.lua` is `dofile`d once and memoised (`pluginloader.lua:244`, `:274`); every file manager and
  every reader makes a fresh instance (`frontend/apps/filemanager/filemanager.lua:418-429`, with
  `{ ui = self }`; `frontend/apps/reader/readerui.lua:464-478`, with `ui` and `document`). An instance
  is in the file manager when `self.ui.document == nil` (ennUI `main.lua:44` uses the same test). State
  that must outlive an instance (the shown home, the pending home, once-per-start flags) lives at
  module level.
- KOReader wraps each `on*` function of the plugin module in a sandbox that logs and returns false on
  error (`pluginloader.lua:117-164`, applied at `:263`), pcalls `new` when making an instance
  (`:479-488`; a throwing `init` leaves its side effects and the plugin unregistered), and pcalls each
  `addToMainMenu` (`frontend/apps/filemanager/filemanagermenu.lua:851-856`). Nothing else KoPanda runs
  is protected by KOReader: the home widget's own handlers, `init`, the menu callbacks, the order
  insert and the `Dispatcher.execute` wrapper each catch their own errors, log them through `logger`,
  and fall back to "no home over a usable file browser".

### Lifecycle

- `FileManager:showFiles` builds a new file manager every time (`filemanager.lua:1312-1331`) and
  `UIManager:show` sends it `Show` (`frontend/ui/uimanager.lua:259`), which reaches the plugin instance
  as an array child (`filemanager.lua:379-389`; `frontend/ui/widget/container/widgetcontainer.lua:80-107`).
  `FileManager.instance` is set at the end of `init` (`filemanager.lua:447`), before `Show`.
- `onShow`, in the file manager only, returns nothing (a true return would stop the event reaching
  later modules, `widgetcontainer.lua:83-85`) and schedules the show with `UIManager:nextTick`
  (`uimanager.lua:431-433`). `reader.lua:291-299` shows history, favorites or folder shortcuts
  synchronously after `showFiles`, so a show from the next tick lands over them. (`start_with` is read
  only when KOReader starts without a path argument, `reader.lua:248-255`.) When a pending home exists
  (after a book close), `onShow` shows it at once instead (ennUI `main.lua:62-66`); nothing of
  `start_with` follows a book close.
- The home is an `InputContainer` with `covers_fullscreen = true` (ennUI `ennui_home.lua:108`).
  `UIManager:_repaint` skips `paintTo` beneath the topmost such widget (`uimanager.lua:1305-1316`), so
  with the home shown before the next repaint the file browser is never painted. The home is shown
  with `UIManager:show(home, "full")` (ennUI `main.lua:111`).
- Settled signal: from `UIManager:tickAfterNext` after the show (`uimanager.lua:447-456`, which lands
  past the next `_repaint`; see `HOOKS.md`), once per home instance,
  `UIManager.event_hook:execute("KoPandaSettled", { screen = "home", paint_ms = <ms>, prebuilt = <bool> })`
  inside a `pcall`. `paint_ms` is `time.monotonic()` from the start of the show path (the build, or for a
  pre-built home the `onShow`) to that callback. With no listener the call does nothing.
- `onCloseWidget` on the file manager instance closes the shown home (ennUI `main.lua:131`): closing the
  file manager sends it `CloseWidget` (`uimanager.lua:300`; `filemanager.lua:819-826`, and
  `:842-849` when a book opens), and a home left on the stack would keep KOReader from quitting.
- Placeholder content: a white full-screen frame with "KoPanda" and, under it, "Tap to open the file
  browser", centred, in KOReader's `cfont` at sizes from `Screen:scaleBySize`; fixed strings, so goldens
  are deterministic.

### Book close

- `ReaderUI:onClose` (`readerui.lua:870-900`) sends `CloseDocument` to the reader's modules (`:887`),
  closes the document and the reader, and its caller then shows the file manager (`ReaderUI:onHome`
  `:935-940`, `ReaderUI:showFileManager` `:581-596`; the reader menu's file-browser tab
  `frontend/apps/reader/modules/readermenu.lua:65-74`).
- The reader instance's `onCloseDocument` builds a home and keeps it as the module's pending home
  without showing it (ennUI's `Home.prebuild`, `ennui_home.lua:116-127`, read). The next `onShow` shows
  the pending home synchronously, not from `nextTick`, instead of building one. A close that runs inside
  a scheduled task (KOReader's end-of-book file-browser action,
  `frontend/apps/reader/modules/readerstatus.lua:144-148`) would otherwise paint the file browser
  before a `nextTick` show: `scheduleIn` stamps a fresh `time.now()` (`uimanager.lua:416`),
  `_checkTasks` runs only tasks due by its cached `_now` (`:1082`, `:1090`), and `_repaint` runs before
  the next pass (`:1563`). Before using it, the show checks the pending home's size against
  `Screen:getSize()`: `showFiles` resets the rotation (`filemanager.lua:1322`), so a home built in a
  rotated reader is dropped and a fresh one built in the same synchronous show.
- `CloseDocument` also fires on `reloadDocument` (`readerui.lua:959`), `switchDocument` (`:979`) and
  exit or restart (`readermenu.lua:386-393`), with no file browser after. The placeholder is cheap, so
  the build is accepted; a reader instance's `init` drops any pending home (a new book opened, so no
  file browser followed), and an exit drops it with the process.
- Paint budget, asserted in the emulator: after a book closes, the file manager's `paintTo` never runs
  before the home's settled signal, the home shown is the pre-built one, and the home's own share
  (`onShow` to its paint) is at most 100 ms. The time from the close to the home's paint is recorded in
  the capture sidecar for later features to tighten.

### Entry points

- **Home tab.** `addToMainMenu` runs before `MenuSorter:mergeAndSort` (`filemanagermenu.lua:851-862`),
  and the order table is the require-cached `ui/elements/filemanager_menu_order` (`:858-859`), whose
  `KOMenu:menu_buttons` are `filemanager_settings`, `setting`, `tools`, `search`, `plus_menu`, `main`
  (`frontend/ui/elements/filemanager_menu_order.lua:4-11`). KoPanda inserts `kopanda_home` at index 2,
  once per process (the technique `frontend/ui/plugin/insert_menu.lua:16-19` uses for `more_tools`, and
  Bookshelf for its tab, `plugins/bookshelf.koplugin/main.lua:605-618`), with an empty order entry
  `kopanda_home = {}` (as the reader's file-browser tab, `reader_menu_order.lua:228`). The menu item is
  `{ icon = "home", remember = false, callback = ... }` (`resources/icons/mdlight/home.svg`; the shape
  of `plus_menu`, `filemanagermenu.lua:841-848`, and the reader's `filemanager` tab,
  `readermenu.lua:65-74`). Tapping a tab runs its callback (`frontend/ui/widget/touchmenu.lua:776-792`);
  the callback closes the menu (`FileManagerMenu:onCloseFileManagerMenu`, `filemanagermenu.lua:1049`)
  and shows the home if it is not already up. Index 2 keeps tab 1, which collects un-hinted orphans
  (`frontend/ui/menusorter.lua:182-184`), and keeps both edge tabs that `_getTabIndexFromLocation`
  opens on a far-left or far-right gesture (`filemanagermenu.lua:1083-1100`).
- **The user's own order file.** `mergeAndSort` overlays `settings/filemanager_menu_order.lua` onto the
  cached order (`menusorter.lua:22-43`). When that file defines `KOMenu:menu_buttons`, KoPanda adds the
  `kopanda_home` item only if the user's list names it; otherwise the textless item would be an orphan
  inserted into tab 1 (`menusorter.lua:161-185`). When it does, KoPanda sets `order.kopanda_home = {}`
  in the cached order when absent (the user file's own entry, if any, overrides it in `mergeAndSort`,
  `menusorter.lua:37-39`); `KOMenu:menu_buttons` is left alone. Without an order entry a top-level id
  becomes a plain item (`:60`, `:70-72`) and is dropped for lacking `sub_item_table` (`:139-146`). The
  Tools entry remains either way.
- **The saved tab index.** `filemanagermenu_tab_index` (`filemanagermenu.lua:1021`, saved at
  `:1051-1052`) counts tabs, so a tab inserted at 2 shifts what a saved 2 or more opens. `remember =
  false` keeps the Home tab from being saved and makes a saved index pointing at it fall back to tab 1
  (`touchmenu.lua:452-464`). The first time KoPanda inserts its tab in a profile it increments a saved
  index of 2 or more and records that in the runtime state file, so the menu reopens on the tab the
  user left.
- **Tools.** `menu_items.kopanda = { text = "KoPanda", sorting_hint = "tools", sub_item_table = { Home,
  Settings } }` in both menus, registered from `init` through `self.ui.menu:registerToMainMenu(self)`
  (`filemanagermenu.lua:1136-1143`; `readermenu.lua:560`; `plugins/hello.koplugin/main.lua:27-30`). With
  the hint it lands after "More tools" (`filemanager_menu_order.lua:122-136`;
  `reader_menu_order.lua:176-191`; `menusorter.lua:179-182`). A menu item's callback runs before the
  menu closes (`touchmenu.lua:913-926`), so Home and Settings act from `UIManager:nextTick`.
- **Dispatcher action.** `Dispatcher:registerAction("kopanda_home", { category = "none", event =
  "KoPandaHome", title = "KoPanda: home", general = true })` from `init` and from
  `onDispatcherRegisterActions` (`frontend/dispatcher.lua:665-671`, a no-op when the name exists;
  `DispatcherRegisterActions` is broadcast once, `:585-586`, `:645`; the pattern of
  `plugins/hello.koplugin/main.lua:23-30`). The event goes out through `UIManager:sendEvent`
  (`dispatcher.lua:1586`) to the topmost widget first (`uimanager.lua:962-1034`, `:988`), which is the
  home while it is up, so the home widget handles `KoPandaHome` itself (a no-op, consumed). The file
  manager instance shows the home; the reader instance calls `self.ui:onHome()` (`readerui.lua:935-940`),
  which closes the book and shows the file manager, and the home follows from `onShow`. The event is
  named `KoPandaHome`, not `Home`, which is KOReader's own file-browser action (`dispatcher.lua:66`,
  `filemanager.lua:865`).
- **Settings stub.** `settings_menu.open()` shows an `InfoMessage` saying KoPanda has no settings yet.
  The Tools entry's Settings and the home's swipe up both call it; `device-menus` replaces its body.

### Gestures

- Gestures reach the topmost widget, then only `active_widgets` and `is_always_active` widgets
  (`uimanager.lua:962-1034`). With the home on top, the file manager's own handlers never see a gesture
  unless the home passes it on; the file manager's only active widget is the screenshot module
  (`filemanager.lua:400-403`), which keeps working because the home returns false for anything it does
  not consume.
- `Home:onGesture`, in order, each step stopping at the first that consumes:
  1. **Own:** a one-finger swipe north starting in the bottom edge band (`DSWIPE_ZONE_BOTTOM_EDGE`,
     the bottom eighth, `defaults.lua:75`, read through `G_defaults` as `filemanagermenu.lua:74-75` reads
     its zones) and outside the left and right edge bands (`DSWIPE_ZONE_LEFT_EDGE`/`RIGHT_EDGE`,
     `defaults.lua:72-73`, where Gestures binds frontlight swipes by default,
     `plugins/gestures.koplugin/defaults.lua:14-17`) opens the settings stub. The Gestures plugin has
     no bottom-edge-up gesture to collide with (`plugins/gestures.koplugin/defaults.lua:20-21`).
  2. **The file manager's menu:** `InputContainer.onGesture(fm.menu, ges)`
     (`frontend/ui/widget/container/inputcontainer.lua:266-285`) runs FileManagerMenu's own top-zone
     tap and swipe zones (`filemanagermenu.lua:71-124`, registered on the menu module itself, `:76`), so
     the menu opens exactly as without the home, honouring `activate_menu` (read once in
     `FileManagerMenu:init`, `filemanagermenu.lua:51`) and the edge-tab choice (`:1083-1114`). This
     replaces the draft's claim that the top zone "keeps working": it does not by
     itself (ennUI forwards by hand too, `ennui_home.lua:597-618`).
  3. **Nothing to page:** a one-finger west or east swipe starting outside the top and bottom edge
     bands is consumed. Passed on, it would page the hidden file chooser through the file manager's
     full-screen swipe zone (`filemanager.lua:81-98`, `:474-482`); Gestures binds west and east swipes
     only inside those bands (`plugins/gestures.koplugin/main.lua:1168-1195`).
  4. **The file manager's zones:** `InputContainer.onGesture(fm, ges)` runs the zones registered on the
     file manager itself, which include every Gestures-plugin zone (`gestures main.lua:1287-1288`
     registers on `self.ui`). This is ennUI's fallback (`ennui_home.lua:653-665`, read).
  5. **The placeholder's tap:** a tap no earlier step consumed closes the home.
  Anything left returns false.
- Actions a forwarded gesture dispatches go out through `Dispatcher:execute` →
  `UIManager:sendEvent` (`dispatcher.lua:1549`, `:1586`), to the home first. By reading, a file-manager
  module's event (`ShowHist`, handled by FileManagerHistory, `filemanagerhistory.lua:59`) is lost under
  the home: the home does not handle it and the file manager is neither active nor always active
  (`uimanager.lua:988`, `:1006-1031`). An emulator test settles it. If it is lost, KoPanda wraps
  `Dispatcher.execute` once per process: while a home is shown, it marks the live file manager
  `is_always_active` for the call (the flag `sendEvent` honours, `uimanager.lua:1021-1027`, whose
  comment names Dispatcher listeners), so an event the home doesn't consume reaches the file manager's
  modules; it calls the original in `pcall`, restores the flag, and re-raises any error. With no home
  shown it calls straight through. SimpleUI solves the same problem by moving its home to the bottom of
  `UIManager._window_stack` for the call (`plugins/simpleui.koplugin/infra/sui_patches.lua:5501-5553`,
  MIT); the flag avoids touching the window stack and is the first candidate, the sink the fallback if
  the emulator test shows the flag isn't enough.

### Coexistence and boot guard

- Coexistence: from each instance's `init` (file manager and reader), KoPanda reads the enabled list
  `PluginLoader:loadPlugins()` returns (memoised, `pluginloader.lua:273-292`; not `loaded_plugins`,
  which fills in path order as instances are made, `:479-482`) and matches each `.name`
  case-insensitively against `simpleui`, `bookshelf` and `ennui`. Runtime names are folder names:
  `simpleui` (`plugins/simpleui.koplugin`), `bookshelf`, and ennUI's `ennUI` from a git clone, though its
  `_meta.lua` says `ennui` (`pluginloader.lua:249`, `:256-259`). Any match refuses the shell for the
  process: no home, no pre-build, no tab, no Tools entry, no action, no gesture wrapper; and, once per
  start, from the first file manager, an `InfoMessage` from `nextTick` names the plugins (SimpleUI, Bookshelf, ennUI) and says to
  disable them in Plugin management (ennUI shows its startup notice the same way, `main.lua:69-79`).
- Runtime state: `settings/kopanda/state.lua`, opened with `LuaSettings:open`
  (`frontend/luasettings.lua:21-48`) under `DataStorage:getSettingsDir()` (`datastorage.lua:60`). Flush
  writes with `util.writeToFile`, which does not create directories (`luasettings.lua:270-275`,
  `frontend/util.lua:1124-1143`), so the state module creates `settings/kopanda/` first. Keys:
  `boot_pending` and `menu_tab_shifted`. Not a setting: no schema entry, never read by the studio.
- Boot guard: before the first home show of a KOReader process, `boot_pending` is set and flushed; it is
  cleared and flushed from the same `tickAfterNext` callback as the settled signal, and on any failure
  of the show. On the first file-manager show of a process, a set flag is cleared, the home is not shown
  that once, and an `InfoMessage` (timeout 8 s, from `nextTick`, as ennUI `main.lua:69-79`) says the
  home was skipped because it didn't finish drawing last time and names the Home tab and Tools ›
  KoPanda. The next show (Home tab, action, book close) tries again. Only the first show of each process
  is guarded; later shows, including book closes after it, write no state.

### Keys

This feature adds no settings key to the schema.

## Notes

Owner decisions, 2026-10-14:

- **Home entry:** a new top-level tab in the file manager's menu, KOReader's `home` icon at index 2,
  opening the home on tap, inserted into the require-cached order as Bookshelf does; the user's own
  order file and the shifted saved tab index are handled. Plus a Tools-menu entry in the file manager
  and the reader, and the dispatcher action "KoPanda: home".
- **Boot flag storage:** a separate runtime state file, `settings/kopanda/state.lua` (LuaSettings), not a
  settings key; the studio never sees it. The task that adds it adds one line to `AGENTS.md`
  Conventions: runtime state lives in `settings/kopanda/state.lua` and is not a setting.
- **KOReader gestures on the home:** forwarded. The home handles its own gestures (swipe up from the
  bottom edge opens settings), forwards the top-zone tap and swipe-down to the file manager's menu and
  every other gesture to KOReader so Gestures-plugin actions work, and dispatched events still reach the
  file manager's modules. Whether those events are lost without help is settled by an emulator test.

Defaults this spec writes in from the design without a question: the home sits over whatever
`start_with` opens (design §5); swipe up opens settings on the home only, a stub until `device-menus`;
"KoPanda: home" in the reader closes the book (ennUI `main.lua:161-177`); pre-build on every
`CloseDocument`; coexistence matched case-insensitively; the placeholder emits the settled signal; no
settings keys.

Interim choice for the placeholder: tapping it opens the file browser. Until `sheets` ("Open the file
browser" on the home's own sheet) and `launcher` (Library) exist, the placeholder needs a way to the
file browser other than the top menu; `home-layout` removes it with the placeholder.

Corrections to the draft: the top menu zone needs forwarding (it is not reached under a full-screen
widget, `uimanager.lua:962-1034`); the Home entry needs an order insert, there being no slot for a new
tab (`menusorter.lua:161-185`); ennUI's `main.lua:62-161` patches nothing, its hooks being event
handlers and API calls, with the KOReader internals it reads being `FileManager.instance` and, in
`ennui_home.lua`, the file manager's menu and `InputContainer.onGesture`; pre-build also runs on switch,
reload and exit; the dispatcher event reaches the home widget, not the plugin, while the home is up;
ennUI's runtime name may be `ennUI`. Separately, design §5 cites `ennui_home.lua:90` for `lastBookFile`;
that line is the comment, the function is `:92` (for `featured-book`).

KOReader's `start_with` setting is left alone. The settled signal `dev-loop` waits on is emitted here
for the real plugin; the probe stays as the harness's self-test.
