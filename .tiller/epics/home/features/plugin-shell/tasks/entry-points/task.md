# Home tab, Tools entries and the KoPanda: home action

## Approach

Every way into the home and the settings stub: the Home tab in the file manager's top menu, a KoPanda
entry in both Tools menus, the dispatcher action, and the stub the settings entries open. KOReader
citations are at `e1fe1ac`, relative to `~/Projects/kodev/koreader/`. Everything here is skipped when
`guards` has refused the shell (`self.refused`).

1. **`kopanda.koplugin/settings_menu.lua`**: `open()` shows an `InfoMessage` saying KoPanda has no
   settings yet. The single seam `device-menus` replaces; the Tools entry's Settings and the home's swipe
   up (`gesture-routing`) both call it.
2. **`kopanda.koplugin/menu_entries.lua`**, the Home tab's order handling, in `pcall` throughout.
   - `home_tab_allowed()`: reads the user's order with `MenuSorter:readMSSettings("filemanager")`
     (`frontend/ui/menusorter.lua:22-32`; `settings/filemanager_menu_order.lua`, `dofile`d). If it
     defines `KOMenu:menu_buttons`, `mergeAndSort` will overlay it on the cached order (`:34-43`), so
     the tab exists only when the user's list names `kopanda_home`: return that, insert nothing into
     `KOMenu:menu_buttons`, which is left alone. A textless top-level item missing from the order would
     be an orphan inserted into tab 1 (`menusorter.lua:161-185`), which is what this avoids. When the
     list names it, set `order.kopanda_home = {}` in the cached order when absent (the user file's own
     entry, if any, overrides it in `mergeAndSort`, `menusorter.lua:37-39`): without an order entry a
     top-level id becomes a plain item (`:60`, `:70-72`) and is dropped for lacking `sub_item_table`
     (`:139-146`).
   - Otherwise `insert_home_tab()`: in the require-cached `ui/elements/filemanager_menu_order` (the
     table `FileManagerMenu:setUpdateItemTable` sorts against, `filemanagermenu.lua:858-862`; it is
     cached for exactly this kind of insert, `frontend/ui/plugin/insert_menu.lua:1-19`), if
     `KOMenu:menu_buttons` lacks `kopanda_home`, `table.insert(buttons, 2, "kopanda_home")` and set
     `order.kopanda_home = {}` (an empty order entry, as the reader's file-browser tab has,
     `frontend/ui/elements/reader_menu_order.lua:228`). Index 2 keeps `filemanager_settings` at 1, so the
     orphan pass (`menusorter.lua:182-184`) never drops unrelated items into the Home tab, and keeps the
     far-left and far-right tabs that `_getTabIndexFromLocation` opens (`filemanagermenu.lua:1083-1100`).
     Bookshelf inserts its tab the same way (`plugins/bookshelf.koplugin/main.lua:605-618` in the
     emulator's install; AGPL, read only, nothing copied). Returns true when the order holds the id.
   - `shift_saved_tab_index()`, after a successful insert into the default order: unless
     `State.get("menu_tab_shifted")`, a saved `filemanagermenu_tab_index` (read at
     `filemanagermenu.lua:1021`, `:1087`, saved at `:1051-1052`) of 2 or more is incremented, and
     `State.set("menu_tab_shifted", true)`. `addToMainMenu` runs inside `setUpdateItemTable`, which both
     readers of the index call first (`filemanagermenu.lua:1007-1009`, `:1084-1086`), so the shift lands
     before the index is used. Not done for a user's own order: they placed the tab.
3. **`main.lua` additions.**
   - `init` (both apps, unless refused): `self:onDispatcherRegisterActions()` and
     `self.ui.menu:registerToMainMenu(self)` (`filemanagermenu.lua:1136-1143`;
     `frontend/apps/reader/modules/readermenu.lua:560`; the pattern of `plugins/hello.koplugin/main.lua:23-30`).
   - `onDispatcherRegisterActions`: `Dispatcher:registerAction("kopanda_home", { category = "none",
     event = "KoPandaHome", title = "KoPanda: home", general = true })` (`frontend/dispatcher.lua:665-671`,
     a no-op when the name exists; fields `:8-32`; `DispatcherRegisterActions` is broadcast once, from
     `Dispatcher:init`, `:585-586`, `:645`, which Gestures calls from its own `init`,
     `plugins/gestures.koplugin/main.lua:219`, hence the call from `init` too).
   - `goHome()`: in the file manager, `showHome()` (from `home-lifecycle`; a no-op when a home is up); in
     the reader, `self.ui:onHome()` (`frontend/apps/reader/readerui.lua:935-940`), which closes the book
     (the pre-build runs from `CloseDocument`) and shows the file manager, whose `Show` brings the home.
   - `onKoPandaHome`: `self:goHome()`, returns true. `Dispatcher:execute` sends the event with
     `UIManager:sendEvent` (`dispatcher.lua:1586`), which offers it to the topmost widget first
     (`frontend/ui/uimanager.lua:962-1034`, `:988`).
   - `addToMainMenu(menu_items)`:
     - file manager, when `MenuEntries.home_tab_allowed()` or a successful insert: `menu_items.kopanda_home
       = { icon = "home", remember = false, callback = ... }` (`resources/icons/mdlight/home.svg`; the
       shape of `plus_menu`, `filemanagermenu.lua:841-848`, and the reader's tab, `readermenu.lua:65-74`).
       A tab's callback runs from `TouchMenu:switchMenuTab` (`frontend/ui/widget/touchmenu.lua:776-792`);
       it calls `self.ui.menu:onCloseFileManagerMenu()` (`filemanagermenu.lua:1049-1056`) then `goHome()`.
       After the callback, `switchMenuTab` updates an empty item table, which returns early
       (`touchmenu.lua:671-673`). `remember = false` keeps the tab's index from being saved and sends a
       saved index pointing at it to tab 1 (`touchmenu.lua:452-464`, `:777-779`).
     - both apps: `menu_items.kopanda = { text = "KoPanda", sorting_hint = "tools", sub_item_table = {
       { text = "Home", callback = ... }, { text = "Settings", callback = ... } } }`. With the hint it
       lands after "More tools" (`frontend/ui/elements/filemanager_menu_order.lua:122-136`,
       `reader_menu_order.lua:176-191`, `menusorter.lua:179-182`). An item's callback runs before the menu
       closes (`touchmenu.lua:913-926`), so both act from `UIManager:nextTick`.
4. **`home.lua`**: `Home:onKoPandaHome()` returns true. While the home is up it is the topmost widget
   and gets the event first; consuming it is the "already home" no-op.
5. **`HOOKS.md`**: entries for the cached menu order, `MenuSorter:readMSSettings` and the orphan rule,
   `TouchMenu` tab callbacks and `remember`, `filemanagermenu_tab_index`, `onCloseFileManagerMenu`,
   `registerToMainMenu` in both apps, `Dispatcher:registerAction` and `DispatcherRegisterActions`,
   `ReaderUI:onHome`, the `home` icon.

## Surfaces

- `kopanda.koplugin/settings_menu.lua`, `kopanda.koplugin/menu_entries.lua` (new)
- `kopanda.koplugin/main.lua`, `kopanda.koplugin/home.lua`, `kopanda.koplugin/HOOKS.md`
- `spec/unit/entry_points_spec.lua` (new); `spec/unit/guards_spec.lua`, `spec/unit/failsafe_spec.lua`
  (cases added)

## Tests

Written first, each run and seen failing before its implementation.

- `spec/unit/entry_points_spec.lua`, with `spec/plugin_harness.lua`; the menu is built with
  `fm.menu:onShowMenu()` and read from `fm.menu.tab_item_table`:
  - Home tab (contract C7): `tab_item_table[2].id == "kopanda_home"`, `icon == "home"`, `remember ==
    false`, one more tab than a baseline counted with KoPanda refused, tab 1's items all have text;
    with the home dismissed (a mid-screen tap), calling the open menu's `switchMenuTab(2)` closes the
    menu and, after a tick, the home is on top;
  - a second file manager in the same process: `KOMenu:menu_buttons` of the cached order holds
    `kopanda_home` exactly once;
  - Tools (C7): the tools tab of the file manager's menu holds an item with id `kopanda` and sub items
    Home and Settings; Home's callback plus a tick shows the home; Settings' callback plus a tick shows
    an `InfoMessage`; the same entry exists in a reader's menu (`readerui.menu:onShowMenu()`, its tools
    tab);
  - action (C7): `Dispatcher:getNameFromItem("kopanda_home")` (`dispatcher.lua:751-756`) returns
    "KoPanda: home"; with the home dismissed, `Dispatcher:execute({ kopanda_home = true })` plus a tick
    shows it; with the home up, the same leaves one home and the home consumed the event (a spy on the
    plugin instance's handler records no call); in a reader on a fixture EPUB, the action calls
    `onHome` (spy), and after `tick(2)` a file manager is shown with the home on top;
  - user order file (C8): with `<KO_HOME>/settings/filemanager_menu_order.lua` returning a
    `KOMenu:menu_buttons` list that copies the default and omits `kopanda_home`, the menu has the tab
    count of the baseline counted with KoPanda refused, no item without text in tab 1, and the Tools
    entry; with a user list that names `kopanda_home` third and has no `kopanda_home` order entry of its
    own, the Home tab is third, with the home icon, and the cached order has `kopanda_home = {}`;
  - saved index (C8): `filemanagermenu_tab_index = 3` before the first menu build reads 4 after it, and
    `state.lua` has `menu_tab_shifted == true`; a second build in a new file manager leaves 4; a saved 1
    stays 1 and the marker is still set; with the user's own order file, no shift and no marker.
- `spec/unit/guards_spec.lua` (contract C11): when refused, the file manager's menu has no
  `kopanda_home` tab and no `kopanda` item in Tools, and a spy on `Dispatcher.registerAction` records no
  `kopanda_home`.
- `spec/unit/failsafe_spec.lua` (C14): an order insert that errors leaves the tab count of a baseline
  counted with KoPanda refused, no `kopanda_home` item and a clean tab 1; a Home tab callback whose
  `goHome` errors leaves the menu closed and the file manager on top.
- Scope check: `bin/check spec/unit/entry_points_spec.lua` lists only that spec's tests.

## Edge cases

- `MenuSorter:mergeAndSort` copies the user's top-level entries into the cached order table
  (`menusorter.lua:35-40`), so after one merge in a session the cached `KOMenu:menu_buttons` is the
  user's list; `home_tab_allowed` reads the user's file each build rather than trusting the cached table.
- A user who removes KoPanda after the shift opens the menu one tab off once; the next close saves the
  right index (`filemanagermenu.lua:1051-1052`). Accepted.
- Non-touch devices get KOReader's `plus_menu` tab too (`filemanagermenu.lua:838-849`); the Home tab
  sits at 2 either way. The Kindle Colorsoft is touch, and so is the headless SDL device the unit specs
  run on (`frontend/device/sdl/device.lua:80`), which counts 5 tabs with no plugins, hence the
  baseline rather than an absolute count.
- The reader's Home entry and action close the book; when the book has unsaved highlights the
  reader's own `onClose` handles them (`readerui.lua:870-900`).
- `KoPandaHome` sent while a dialog sits above the home reaches the dialog first and, unconsumed, is
  not offered to the home (`uimanager.lua:1006-1031`); the home is already up, so nothing is lost.
- The action is registered in the reader too, so a Gestures binding in the reader works; its title
  carries the "KoPanda:" prefix the owner chose.
