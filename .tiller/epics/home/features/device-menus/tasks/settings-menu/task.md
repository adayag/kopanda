# The settings menu generated from the schema, and its callers

## Approach

`menu.lua` builds the item tables from the schema, `settings_menu.lua` shows them, Tools › KoPanda ›
Settings carries them natively, and each caller of the stub passes its group. Repo lines on `main` at
`ca26783`; KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. Starts after
`home/device-menus/edit-layout`, `launcher-manage` and `location-search`, whose screens and search the
rows open.

1. **Open fact first: does a one-tab `TouchMenu` build, paint and close?** Reading says yes:
   `TouchMenuBar:init` lays out `#icons` icons with no branch that needs two (`touchmenu.lua:373`, `:421`),
   and `switchToTab(1)` picks the only tab (`:452-464`). Settle it with the first test: build
   `TouchMenu:new{ width = Screen:getWidth(), tab_item_table = { items }, show_parent = container }` with
   `items.icon = "appbar.settings"`, show it in the harness, paint it into a `Blitbuffer`, tap an item and
   tap outside. If it raises or draws no items, stop and report it: the fallback (opening KoPanda's
   submenu inside `FileManagerMenu` by path) depends on Tools' sort order and needs the owner's decision.
2. **Open fact: where does the hold step live once `sheets` is built?** At `ca26783` the gesture order is
   `HomeGestures.route` (`home_gestures.lua:83-122`), which `Home:routeGesture` calls (`home.lua:317-320`);
   `sheets` adds the hold step to that order (`sheets/tasks/hold-and-home-sheet/task.md` step 3). Find it
   with `grep -rn "SettingsMenu.open" kopanda.koplugin/`; change it where it is and record which module in
   the PR.
3. **`kopanda.koplugin/menu.lua`** (`SchemaMenu`), requiring `schema`, `settings`, `weather` and
   `featured_book` at load, and at call time `home`, `edit_layout`, `launcher_manage` and
   `location_search`: `home` requires `home_gestures` (`home.lua:7`), which requires `settings_menu`
   (`home_gestures.lua:5`), which requires this module, and `main.lua` requires `home` first
   (`main.lua:12`), so a load-time `require("home")` here would be a require loop:
   - `SchemaMenu.items(group)`: the feature's "Items" rules: the group cut (a group is used when any key
     has it), schema order, `separator` on each group's last item but the list's last.
   - A builder per type, `BUILDERS[type](entry) -> item`, by the feature's table: `choice`, `boolean`,
     `path`, `location`, `rows`, `launcher`. A type without one is logged once per type and skipped.
   - `write(entry, value)`: equal to `Settings.get` (deep compare for tables) → nothing; else
     `Settings.set`; `false` → log and the note "Couldn't save <label>."; `true` → for `weather.location`
     and `weather.units`, with `Home.shown` and `NetworkMgr:isConnected()`, `Weather.fetch()` once; then
     `Home.shown:refresh()` once when shown.
   - `rows` and `launcher` items: `callback` (no `checked_func`, so `TouchMenu` closes itself after it,
     `touchmenu.lua:920-926`) schedules `UIManager:nextTick` to open `EditLayout.open{}` or
     `LauncherManage.open{}`, guarded as `main.lua`'s `after_menu` (`:246-262`).
   - `location` item: `keep_menu_open = true`; `callback(touchmenu)` runs
     `LocationSearch.ask(function(c) write(entry, c); touchmenu:updateItems() end)`.
   - `path` item (`featured.pinned`): `text_func` reads the pin and, when `lfs.attributes(pin, "mode") ==
     "file"`, `FeaturedBook.describe(pin).title` (from `sheets`), or the file's name; its
     `sub_item_table_func` gives "Most recent book" and, when the pin is a file, the book, both `radio`.
   - Every callback, `text_func`, `checked_func` and `sub_item_table_func` runs in `pcall`; a failure is
     logged and gives a safe answer (text: the label alone; checked: false; submenu: `{}`).
4. **`kopanda.koplugin/settings_menu.lua`**, `SettingsMenu.open(group)`: in `pcall`, a full-screen
   `CenterContainer{ dimen = Screen:getSize(), ignore = "height" }` holding the one-tab `TouchMenu` of
   `SchemaMenu.items(group)`, `show_parent` the container (`filemanagermenu.lua:1011-1047`), then
   `UIManager:show(container)`. The default `close_callback` closes the container
   (`touchmenu.lua:499-504`). The file's header comment says what it is now. A raising open is logged.
5. **`main.lua`**: Tools › KoPanda › Settings (`main.lua:320-323`) becomes `{ text = "Settings",
   sub_item_table_func = function() return guarded items or {} end }`. `menu` is required at load
   (`main.lua:22-48`).
6. **Callers** (the feature's table): the hold step passes `slot.module.settings_prefix`; the book sheet's
   This widget's settings passes `"featured"` (`sheets/tasks/book-sheet/task.md:66`). The swipe up, the
   home sheet and the launcher's Settings entry keep `SettingsMenu.open()`.
7. **HOOKS.md:** `TouchMenu`'s item fields (`touchmenu.lua:73-96`, `:715`, `:892-926`), its one-tab use
   (`:373`, `:421`, `:540`), closing (`:499-504`, `:508-512`, `:531`, `:798-814`, `:977-998`);
   `Menu.getMenuText` (`menu.lua:1610-1621`); `FileManagerMenu:onShowMenu`'s container and the
   `appbar.settings` icon (`filemanagermenu.lua:37`, `:1006-1047`).

## Surfaces

`kopanda.koplugin/menu.lua` (new), `settings_menu.lua`, `main.lua`, the hold step's module (step 2),
`book_sheet.lua`, `HOOKS.md`. Specs: `spec/unit/menu_spec.lua` (new), `spec/unit/settings_menu_spec.lua`
(new), `spec/unit/entry_points_spec.lua`, `spec/unit/gesture_routing_spec.lua`,
`spec/unit/home_sheet_spec.lua`, `spec/unit/book_sheet_spec.lua`, `spec/unit/launcher_entries_spec.lua`,
`spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `menu_spec.lua` (C1, C3), in the harness with a real settings file:
  - **Every key once:** `items()`'s items, mapped back to keys (each item carries `kopanda_key`), equal
    `Schema.keys`' ids in order; separators sit on the last item of appearance, home, weather, quote,
    stats and featured and nowhere else.
  - **Groups:** `items("weather")` is location then units with no separator; `items("date")`,
    `items("clock")`, `items(nil)` and `items("nope")` are the full list.
  - **Choice:** the look row reads "Look · Diner"; its submenu's radio items are Diner (checked) and
    Editorial; Editorial's callback writes `editorial` once and calls `Home.refresh` once on a shown home;
    Diner's (already stored) writes nothing (bytes unchanged) and refreshes nothing.
  - **Boolean:** "Show reading stats" is checked; its callback writes `false`, then `true`.
  - **Path:** no pin: "Featured book · Most recent", one radio item, checked. A pin to a fixture EPUB:
    "Featured book · <its title>", two items, the book checked; "Most recent book" writes `false`. A pin
    to a gone file: "· Most recent", one item, checked; its tap writes `false`.
  - **Location:** "Weather location · Chicago, Illinois"; with `LocationSearch.ask` stubbed to pick
    `{ name = "Paris, Île-de-France", latitude = 48.85341, longitude = 2.3488 }`, the stored value is
    exactly that and the row reads it.
  - **Weather after a write** (C3): units changed with a shown home and `isConnected` true:
    `Weather.fetch` (spied) runs once before the one `Home.refresh`; with `isConnected` false, no fetch
    and one refresh.
  - **Screens:** the Layout and Launcher callbacks open nothing at once and open the editor named
    `edit_layout` or `launcher` after a tick.
  - **Refused write:** `Settings.set` stubbed false: the note, bytes unchanged. **Raising callback:**
    logged, nothing written. **Unknown type:** with a stubbed schema key of type `bogus`, it is left out
    and logged once.
- `settings_menu_spec.lua` (C2): step 1's one-tab case; `open("weather")` shows a `TouchMenu` with two
  items over the home; a tap outside closes it (not on the stack); the Back key closes it; `open` with
  `SchemaMenu.items` raising shows nothing and logs.
- `entry_points_spec.lua` (C2): "shows the settings stub from Settings" (`:194`) becomes: the file
  manager's Tools › KoPanda › Settings has a `sub_item_table_func` whose items are `SchemaMenu.items()`;
  the reader's (`:203`) too.
- `gesture_routing_spec.lua` (C2, C14): the swipe up (`:76`) opens the menu with the full list; a hold on
  the weather slot opens it with two items, on the stats slot one, on the date slot the full list.
- `home_sheet_spec.lua`, `book_sheet_spec.lua`, `launcher_entries_spec.lua` (C2): KoPanda settings and
  the launcher's Settings call `SettingsMenu.open` with no group; This widget's settings with
  `"featured"`.
- `failsafe_spec.lua` (C15): a builder raising inside `items` (stubbed) in the Tools submenu gives `{}`,
  logged; the file manager handles input.
- `hooks_doc_spec.lua` (C16) passes with the new requires named in `HOOKS.md`.

## Edge cases

- The menu opened from the reader (Tools there, `main.lua:310`): writes work; `Home.shown` is nil, so
  nothing refreshes and no fetch runs.
- A settings file from a newer schema is read-only (`settings.lua:265-268`, `:319-322`): every write is
  refused, so every tap shows "Couldn't save …".
- The look changed while the standalone menu is over the home: the home refreshes beneath it and
  `_repaint` repaints the menu above (`uimanager.lua:1298-1346`).
- The standalone menu saves no tab index: `FileManagerMenu` saves its own on close
  (`filemanagermenu.lua:1052`), and nothing here does, so KOReader's menu keeps its remembered tab.
