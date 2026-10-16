# Generated settings menu, edit layout and launcher management

## Summary

Everything editable on the device: the settings menu generated from the schema into KOReader's native
menu widgets, and the two screens the schema can't express, edit layout and launcher entries, drawn in
the look (direction doc "Settings menus", "Edit layout", "Launcher management").

## Behavior

- `menu.lua` walks the schema and emits KOReader `TouchMenu` item tables, one flat list of every key in
  schema order with a separator between groups: a check for a boolean, radio choices for a choice, the
  featured book's own row for the path, a place search for the location, and a row that opens the
  matching screen for the layout and the launcher. Adding a key of an existing type to the schema adds a
  menu row with no other change; a test proves every schema key appears exactly once.
- The menu is native KOReader styling and is not restyled by a look.
- Edit layout: rows as a list with their columns as boxes showing width shares, up and down arrows,
  tap to select a row revealing Add column, Change widget, Remove row; Add row at the foot; Reset to
  the look's default. A change that would push a row off the home is refused with a message.
- Launcher entries: a list with icon, label and kind, arrows, remove; Add opens a picker by kind;
  the seventh entry and beyond go into a folder, with the folder's own list reachable from its row.
- "This widget's settings" from a sheet, and a hold on a widget without its own hold, open the same
  list cut down to that widget's group.
- Every change writes through `settings.lua` and repaints the home once.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. Repo paths are
on `main` at `ca26783` unless marked. Canvas references are to
`.tiller/design/2026-10-13-kopanda-screens/<board>.dc.html:<line>`; sizes are board pixels, scaled by
`Screen:scaleBySize` as the looks use them.

### Order and what is cited as spec

This feature starts after `sheets` (`home/sheets`, F-3ct1xn) has merged, a recorded prerequisite. The
tweak `split-home-lua` (TW-l2ibo3), which `sheets` itself waits for (`sheets/feature.md:37-39`), has merged
(`02ede75`): it split `home.lua` into `home.lua`, `home_rows.lua` (the rows a home builds) and
`home_gestures.lua` (the gesture order). `sheets` is not built today, so:

- `sheets`' modules (`sheet.lua`, `home_sheet.lua`, `book_sheet.lua`, `folder_sheet.lua`, the hold step,
  `FeaturedBook.describe`) are cited from its approved spec, `.tiller/epics/home/features/sheets/` on
  `main`. Each task that changes one of them reads the built code first and says so in its PR.
- The home's functions are cited by name plus their line at `ca26783`. The gesture order is
  `HomeGestures.route` (`home_gestures.lua:83-122`), where `sheets` adds the hold step; where that step
  sits once `sheets` is built is an open fact for `settings-menu`, the one task that changes it.

### The keys

No key enters the schema and `schema.version` stays 1. The menu covers the nine keys
(`schema.lua:9-118`); the screens' look is tokens, not keys. `featured.pinned` stays set from the book
sheet (direction doc "Schema consequences"); the menu only shows it and can unpin it.

### The settings menu

`kopanda.koplugin/menu.lua` (`SchemaMenu`) builds the item tables; `settings_menu.lua` hosts them. Both
are pure of looks: the menu is KOReader's own `TouchMenu`.

#### Items

`SchemaMenu.items(group)` returns one item per schema key, in `Schema.keys` order. With `group` naming a
group that has at least one key, only that group's keys; with no group, or a group with no keys, every
key. Today `date` and `clock` have no keys (`widgets/date.lua:17`, `widgets/clock.lua:10` name those
prefixes; no schema key has those groups), so their holds open the full list.

- **Separators.** In the full list, the last item of each group but the last carries `separator = true`,
  which `TouchMenu` draws as a line before the next item (`frontend/ui/widget/touchmenu.lua:715`).
- **Row text** is the key's schema `label`, then " · " and the current value where the type has one,
  through `text_func`, which `TouchMenu` re-reads on every redraw (`frontend/ui/widget/menu.lua:1610-1621`,
  `touchmenu.lua:107`).
- **Per type:**

| Type | Keys | Row | Tap |
|---|---|---|---|
| `choice` | look, text_size, weather.units, quote.source | "Look · Diner": the stored value's choice label | A submenu (`sub_item_table_func`, `touchmenu.lua:892-911`) of the key's choices, each `radio = true` with `checked_func` true for the stored value (`touchmenu.lua:77-96`). A tap writes that value; `TouchMenu` keeps the submenu open and redraws it because the item has `checked_func` (`:920-923`). |
| `boolean` | stats.show | the label, with KOReader's check mark | `checked_func` reads the value; a tap writes its negation and the menu redraws (`:920-923`). |
| `path` | featured.pinned | "Featured book · Most recent", or "Featured book · <title>" when the pin names a file that is there | A radio submenu: "Most recent book", ticked when the stored value is false or names a file that is gone, which `FeaturedBook` reads as unpinned (`featured_book.lua:51-63`); and, when the pin names a file that is there, that book, ticked. A tap on "Most recent book" writes `false` when the stored value isn't already false. There is no file picker: pinning stays on the book sheet. |
| `location` | weather.location | "Weather location · Chicago, Illinois", the stored `name` | The place search below; the menu stays open (`keep_menu_open`, `touchmenu.lua:924-926`) and redraws after a pick. |
| `rows` | layout.rows | the label, "Layout" | Closes the menu, then opens edit layout from the next tick, as `main.lua`'s `after_menu` defers (`main.lua:256-262`). |
| `launcher` | launcher.entries | the label, "Launcher" | Closes the menu, then opens launcher management from the next tick. |

  The pinned book's title is `FeaturedBook.describe(file).title`, which `sheets` adds and which neither
  raises nor writes (`sheets/feature.md:362-363`); its file name when that gives no title.
- **A type with no row builder** is logged once and its key left out, so a new type can't break the
  menu. Every type in today's schema has one, which the every-key test proves.
- **Writes.** Every tap that changes a value calls `Settings.set(key, value)` (`settings.lua:307-348`).
  - A tap on the value already stored writes nothing and refreshes nothing.
  - A refused write (`false, reason`) is logged and shows a note, "Couldn't save <label>.", and
    changes nothing.
  - After a write, the home refreshes once: `Home.shown:refresh()` when a home is shown
    (`home.lua:60-72`). A home that isn't shown rebuilds from the settings on its next show.
  - A write to `weather.location` or `weather.units` makes the cached reading stale, since it is kept
    only for the stored coordinates and units (`weather.lua:146-150`). So when a home is shown and
    `NetworkMgr:isConnected()` (no prompt, no I/O, `weather.lua:197-198`), the write is followed by one
    `Weather.fetch()` (`weather.lua:96-130`), then the one refresh. Offline, the refresh alone, and the
    widget says it needs Wi‑Fi until the next fetch.
- **Every callback is guarded**: an error is logged, the menu stays as it was, and nothing is written
  after the error. `TouchMenu` doesn't sandbox item callbacks (`touchmenu.lua:913-919`).

#### Where the list opens

- **Tools › KoPanda › Settings** (`main.lua:320-323`) becomes a native submenu:
  `sub_item_table_func` returns `SchemaMenu.items()`, so the list opens inside KOReader's own menu, and
  its back arrow returns to KoPanda's entries. A raising build is logged and gives an empty table, which
  `TouchMenu` ignores (`touchmenu.lua:892-911`). The refused-plugin entry has no Settings
  (`main.lua:290-296`) and keeps none.
- **`SettingsMenu.open(group)`** (`settings_menu.lua:8-12` today, the stub) shows the list on its own,
  for every caller outside KOReader's menu. It builds a `TouchMenu` with one tab,
  `tab_item_table = { items }` where `items.icon = "appbar.settings"` (the icon KOReader's own settings
  tab uses, `frontend/apps/filemanager/filemanagermenu.lua:37`), inside a full-screen `CenterContainer`
  as `FileManagerMenu:onShowMenu` builds its own (`filemanagermenu.lua:1006-1047`), and shows it.
  - **One tab.** `TouchMenuBar:init` lays out any number of icons; with one, the before-last branch never
    runs and no separator is added (`touchmenu.lua:373`, `:421`), and the tab's icon is read from each
    tab table's `icon` (`:540`). The first `settings-menu` test builds and paints one to confirm it.
  - **Closing** is `TouchMenu`'s own: a tap outside it (`:508-512`, `:977-981`), the Back key (`:531`),
    or the up arrow at the top level (`:798-814`), each through the default `close_callback`, which
    closes the container (`:499-504`). Its `onCloseWidget` asks for a full-screen `flashui`
    (`:987-998`).
  - A raising `open` is logged and shows nothing, leaving what was under it usable.
- **The callers:**

| Caller | Today | After |
|---|---|---|
| The home's swipe up (`HomeGestures.route`, `home_gestures.lua:98-101`) | `SettingsMenu.open()` | unchanged: the full list |
| A hold on a slot whose module has no `hold` (`sheets/feature.md:86-87`) | `SettingsMenu.open()` | `SettingsMenu.open(slot.module.settings_prefix)`: weather opens its two keys, quote and stats one each, date and clock the full list |
| The book sheet's "This widget's settings" (`sheets/feature.md:324`) | `SettingsMenu.open()` | `SettingsMenu.open("featured")`: the one featured row |
| The home sheet's "KoPanda settings" (`sheets/feature.md:265`) | `SettingsMenu.open()` | unchanged: the full list |
| The launcher's Settings entry (`launcher_entries.lua:134-136`) | `SettingsMenu.open()` | unchanged: the full list |

A widget's group is its module's `settings_prefix` (`widgets.lua:2`): `weather` (`widgets/weather.lua:56`),
`quote` (`widgets/quote.lua:23`), `stats` (`widgets/stats.lua:17`), `featured` (`widgets/featured.lua:28`)
and `launcher` (`widgets/launcher.lua:21`) match their keys' groups (`schema.lua:57`, `:68`, `:79`, `:86`,
`:95`, `:117`). The launcher and the featured book have their own holds, so neither reaches this row.

### The place search

`kopanda.koplugin/location_search.lua`. Open-Meteo's geocoding endpoint, which `home-layout` handed to
this feature (`home-layout/feature.md:365-367`).

- **The request:** `https://geocoding-api.open-meteo.com/v1/search?name=<query>&count=10&language=en&format=json`,
  the query trimmed (`util.trim`, `frontend/util.lua:52`) and encoded (`util.urlEncode`, `:1443`). A
  query of exactly five digits is a US ZIP code and adds `&countryCode=US`, since a bare ZIP also matches
  places abroad.
- **The response,** read on 2026-10-15 from the live endpoint: `{ results = [ { name, latitude,
  longitude, admin1, country, country_code, postcodes, ... } ] }`, and no `results` at all when nothing
  matches. "60614" with `countryCode=US` gives one result, Chicago, Illinois, at 41.85003, -87.65005:
  the schema's default (`schema.lua:55`). The task re-reads the shape with one live request before it
  writes its fixtures, and records the response it saw.
- **A candidate** is `{ name, latitude, longitude }`, the three fields the validator takes
  (`settings.lua:171-183`). Its `name` is "<name>, <admin1>" when `admin1` is present and differs from
  `name`, else "<name>, <country>" when `country` is present, else `name`; a result without a non-empty
  `name` or with a non-number coordinate is skipped. The list shown adds the country to the name when
  it isn't in it already, so two Springfields read apart.
- **The fetch** reuses the weather's request: `weather.lua`'s local `get(url)` (`:72-92`), with its
  timeouts and their reset on every path, becomes `Weather.get(url)`, called by both. It blocks the UI
  for its duration, at most the timeouts it sets (`socketutil:set_timeout(5, 10)`, `:75`).
- **The flow,** `LocationSearch.ask(on_pick)`, from the location row:
  1. An `InputDialog` (`frontend/ui/widget/inputdialog.lua:125-167`) titled "Weather location" with
     the hint "City or ZIP code" and the buttons Cancel and Search (Search `is_enter_default`), its
     keyboard shown (`:640`). An empty query does nothing.
  2. Search closes the dialog. When `NetworkMgr:isConnected()` is false: the note "Finding a place needs
     Wi‑Fi." and nothing is written. No prompt to turn Wi‑Fi on.
  3. Otherwise a note "Searching…" with no timeout is shown and painted (`UIManager:forceRePaint`,
     `frontend/ui/uimanager.lua:1404`) before the blocking fetch, and closed after it.
  4. No results: the note "No place found for “<query>”." A failed request or an unreadable body: the
     note "Couldn't search for places." Nothing is written either way.
  5. Results: a `ButtonDialog` titled "Choose a place", one button per candidate in the order returned,
     then Cancel (`frontend/ui/widget/buttondialog.lua:1-40`). A tap closes it and calls `on_pick`.
- `on_pick` is the menu's write: `Settings.set("weather.location", candidate)`, then the weather rule
  above, then the menu redraws its row.
- Notes are `InfoMessage`s with no timeout, as the launcher's are (`launcher_entries.lua:109-113`).

### The two screens

Edit layout and launcher management are KoPanda's two hand-written screens. Each is a full-screen
`InputContainer` over whatever is shown, drawn in the active look, as the boards draw them
(EditLayout:17-104, LauncherManage:17-106). Both boards are Editorial's; Diner has none.

#### The frame

`kopanda.koplugin/editor.lua`, shared by both screens:

- **Header** (EditLayout:19-25, LauncherManage:19-25): an aside over a title on the left, a Done button
  on the right, a rule under them.
- **Body:** the screen's cards and rows, then its foot.
- **Built from** a ctx like the home's: `{ look = Looks.active(), variant = Looks.variant(), text_size,
  now, screen }` (`HomeRows.build`, `home_rows.lua:84-91`), so it opens the same over the home, the file browser or a book.
- **Showing and closing:** `UIManager:show(screen, "full")` and `UIManager:close(screen, "full")`, as the
  home shows and closes (`home.lua:200`, `:42`). It `covers_fullscreen` (`home.lua:17-21`), so nothing
  beneath it is painted while it is up (`frontend/ui/uimanager.lua:1305-1316`).
- **What closes it:** Done; the Back key where `Device:hasKeys()`, and the `Back` event, as the sheet
  binds them (`sheets/feature.md:224-226`).
- **Input:** taps only. A tap on a control runs it; a tap anywhere else does nothing. Holds, swipes and
  `hold_release` do nothing.
- **A change** applies the screen's operation, writes the key once through `Settings.set`, refreshes the
  home once when shown, then rebuilds the screen and repaints it once (`setDirty(screen, "ui")`). No timer
  is scheduled and nothing animates. A refused operation shows its note and writes nothing.
- **Pickers over a screen** are sheets (`Sheet.show(spec, ctx, opts)`, `sheets/feature.md:108-117`,
  `:201-203`), named `picker` with the home's band, so they take the look; a tap on a row closes the
  sheet, then runs it (`:220-221`). Notes and KOReader's own dialogs (`InputDialog`, `PathChooser`,
  `ConfirmBox`) stay native.
- **The settled signal:** after the first paint, from `tickAfterNext` as the home sends its own
  (`settle`, `home.lua:149-189`), `KoPandaSettled{ screen = "edit_layout" | "launcher", paint_ms }` once,
  `paint_ms` from the tap that opened it (`opts.started`) or the start of `open`.
- **Failing safe:** build, paint, gesture and key handlers each run in `pcall`. A failure is logged and
  closes the screen, from the next tick for a paint (`home.lua:283-297`), leaving what was beneath.
- **Too tall:** a body that doesn't fit leaves out the rows that don't, logged once.

#### Tokens

A new `editor` block and type parts, with identical paths in both looks, each value carrying its board
line in a comment, by `looks_spec.lua`'s rules (`spec/unit/looks_spec.lua:83`, `:173`, `:202`). Editorial
takes the boards'. Diner has no board, so it takes its own vocabulary from the direction doc ("The two
looks": 3 px ink outlines, hard ink shadows of 4 px on tiles, flat accent fills, a teal header band):

| Token | Editorial | Diner (no board) |
|---|---|---|
| `padding.top`, `.side`, `.bottom` | 40, 40, 28 (EditLayout:19, :101) | 40, 40, 28 |
| `header_band_color`, `header_text_color` | false, false | `band`, `on_band` (the home's header, `looks/diner.lua` palettes) |
| `header_rule_color`, `header_rule_width`, `header_gap` | `ink`, 1, 16 (EditLayout:19) | `outline`, 3, 16 |
| `body_gap` (the header rule to the body's first row) | 18 (EditLayout:27; LauncherManage:27 draws 10) | 18 |
| `button_outline_color`, `button_outline_width`, `button_fill_color` | `ink`, 1, false (EditLayout:24) | `outline`, 3, `paper` |
| `button_padding.x`, `.y` | 14, 8 (EditLayout:24) | 14, 8 |
| `card_gap`, `card_padding.x`, `.y` | 12, 14, 12 (EditLayout:27, :29) | 10, 14, 12 (10 so the default layout's five rows fit with one selected) |
| `card_outline_color`, `card_outline_width` | `hairline`, 1 (EditLayout:29) | `outline`, 3 |
| `selected_outline_color`, `selected_fill_color` | `ink`, `hairline_light` (EditLayout:43; see Notes) | `outline`, `mustard` |
| `arrow_size`, `arrow_gap` | 28, 14 (EditLayout:30-32) | 28, 14 |
| `disabled_color` | `hairline` (EditLayout:90) | `muted` |
| `box_padding.x`, `.y`, `box_gap` | 12, 10, 8 (EditLayout:36-37) | 12, 10, 8 |
| `row_padding.y`, `row_rule_color`, `row_rule_width`, `icon_size`, `icon_gap` | 14, `hairline`, 1, 22, 14 (LauncherManage:29-30) | 14, `outline`, 2, 22, 14 |
| `control_size` | 30 (LauncherManage:35) | 30 |
| `kind_gap`, `kind_columns` | 8, 2 (LauncherManage:97) | 8, 2 |

Type parts, each `{ color, face, line_height, size, tracking, uppercase }` (`looks_spec.lua:202`):

| Part | Editorial | Diner |
|---|---|---|
| `editor_aside` | `text` 11, uppercase, 0.14, `muted` (EditLayout:21) | `strong` 11, uppercase, 0.1, `on_band` |
| `editor_title` | `display` 34, `ink` (EditLayout:22) | `display` 30, `on_band` |
| `editor_button` | `strong` 11, uppercase, 0.12, `ink` (EditLayout:24) | `display` 11, uppercase, 0.1, `ink` |
| `editor_caption` | `text` 11, uppercase, 0.12, `muted` (EditLayout:35) | `strong` 11, uppercase, 0.1, `muted` |
| `editor_box` | `strong` 15, `ink` (EditLayout:37) | `strong` 15, `ink` |
| `editor_share` | `strong` 15, `muted` (EditLayout:37) | `strong` 15, `muted` |
| `editor_label` | `strong` 16, `ink` (LauncherManage:32) | `strong` 16, `ink` |
| `editor_kind` | `text` 11, uppercase, 0.1, `muted` (LauncherManage:33) | `strong` 11, uppercase, 0.08, `muted` |
| `editor_note` | `text` 12, `muted` (LauncherManage:103) | `text` 12, `muted` |

Cards cast the editor's own `card_shadow`, `{ x, y, color }` as `shadow.tile` is: Editorial `false` (the boards
draw none), Diner 2 px in `shadow`, half the home tiles' 4 px (`looks/diner.lua:87`), so the screens read lighter
than the home (owner decision, 2026-10-16). The boards' weight 600 is each look's `strong` face, as `featured_button` takes it
(`looks/editorial.lua` `type.featured_button`). The night and grey palettes need no new role: every token
names an existing one.

#### Icons

The arrows and the remove cross are icons, not glyphs. No KoPanda face has ▲ (U+25B2) or ▼ (U+25BC): the
cmaps of all eight font files under `fonts/` were read on 2026-10-15 and none maps either. So:

- `chevron_up` and `chevron_down`: Lucide's `chevron-up` and `chevron-down`, stroke 2, as `sun` is taken
  (`icons.lua:37`; `icons/LICENSE-lucide.txt`);
- the remove control is the registry's `close` (`icons.lua:52`);
- `action`: Lucide's `zap`, the generic icon an `action` or `plugin` entry gets when it is added
  (decision D4). The registry has no generic action icon: `terminal`, `sync` and `screenshot` name
  particular things (`icons.lua:31-34`).

Each joins `Icons.entries` with a label and its `used_in`.

### Edit layout

`kopanda.koplugin/rows_edit.lua`, pure operations on a `layout.rows` value, and
`kopanda.koplugin/edit_layout.lua`, the screen.

#### The operations

Every operation takes the rows and returns new rows, or `nil` and the note to show; none changes what
it was given. `Settings.get` hands back the stored table itself (`settings.lua:285-298`), so the screen
works on a deep copy (`util.tableDeepCopy`, `frontend/util.lua:184`).

- `move(rows, i, delta)`: row `i` up or down one; `nil` past either end.
- `add_row(rows, widget)`: a new last row `{ { widget = widget, share = 1 } }`.
- `add_column(rows, i, widget)`: a new last slot with share 1; refused at `max_columns` (`schema.lua:39`).
- `change_widget(rows, i, j, widget)` and `set_share(rows, i, j, share)`, share 1 to 3
  (`settings.lua:46`).
- `remove_column(rows, i, j)`: on a row of two or more columns.
- `remove_row(rows, i)`: refused for the only row ("The home needs at least one row."), since the
  validator wants one or more (`settings.lua:151-154`).
- `reset()`: a copy of the schema's default (`schema.lua:40-46`). The looks hold no layout of their own,
  so "the look's default" is this one in both looks.
- `unused(rows)`: the schema's widgets not on the home, in schema order (`schema.lua:38`). A widget is
  on the home at most once (`settings.lua:43`), so every widget picker lists only these.

Labels: Date, Clock, Weather, Quote, Reading stats, Featured book, Launcher, by id (EditLayout:37-95 draws
all but Weather). A column's share reads "full" alone in its row, else its share over the row's total,
reduced: "1/2", "1/3", "2/3" (EditLayout:37, :51). A card's caption is "Row N · one column", "two
columns" or "three columns", with " · selected" when selected (EditLayout:35, :49).

#### Fitting

A change is refused, with the note "That won't fit on the home.", when the new rows leave out more rows
than the current ones do. `Layout.fits(rows, ctx)` answers only whether nothing is left out
(`layout.lua:266-270`); a new `Layout.overflow(rows, ctx)` gives the count, from the same placement
without logging (`layout.lua:45-102`, `:167-259`). Comparing counts rather than asking `fits` lets a
layout the studio wrote too tall still shrink. Every change is checked, moves and resets included: row 1
carries the header's chrome (`layout.lua:176-206`), so order changes height.

#### The screen

EditLayout:17-104. Header: "Home" over "Edit layout", Done.

- **A card per row** (EditLayout:29-41): the up and down arrows on the left, the up arrow greyed on the
  first row and the down on the last (EditLayout:90); the caption; a box per column with its widget's
  label and its share.
- **A tap on a card** selects it (EditLayout:43-58), or a tap on a selected card's box selects that
  column; the first column is selected when a row is. One row is selected at a time; the selection is
  the screen's, never stored. The selected card has the selected outline and fill, and below its boxes:
  - **Add column:** a picker of the unused widgets; greyed at three columns or with none unused.
  - **Change widget:** a picker of the unused widgets for the selected column, its own widget first and
    ticked.
  - **Width** (rows of two or more columns): a picker of 1, 2 and 3, the selected column's share ticked.
  - **Remove column** (rows of two or more columns).
  - **Remove row** (EditLayout:56), drawn in the disabled colour as the board draws it, but live.

  The buttons wrap to a second line when they don't fit the card.
- **A tap on an arrow** moves its row; the selection follows the row.
- **The foot** (EditLayout:101-104): Add row (a picker of the unused widgets; greyed when none) and Reset
  to the look's default.
- **Ways in:** the home sheet's Edit layout row, in place of its note (`sheets/feature.md:18`, `:261`),
  and the menu's Layout row.

### Launcher management

`kopanda.koplugin/entries_edit.lua`, pure operations on a `launcher.entries` value;
`kopanda.koplugin/launcher_manage.lua`, the screen; `kopanda.koplugin/entry_picker.lua`, the add flows.

#### The operations

Pure, as the row operations are, on a deep copy. A list is the top level or one folder's `entries`.

- `move(entries, path, delta)` within its list; `remove(entries, path)`.
- Removing a folder from the top level removes its entries with it, after KOReader's `ConfirmBox`
  ("Remove <label> and its N entries?").
- Removing a folder's only entry removes the folder, since a folder holds one or more entries
  (`settings.lua:119-123`), and the screen returns to the top level.
- **`add(entries, entry, folder)`**, decision D3:
  - into a folder's list: at its end;
  - at the top level with fewer than `max_entries` (6, `schema.lua:103`): at the end;
  - at the top level with six: at the end of the first top-level folder, if there is one;
  - with six and no folder: the sixth entry and the new one become a folder labelled "More" in slot six.

  Folders don't nest (`settings.lua:101`), so a folder is never added into one.

#### The screen

LauncherManage:17-106. Header: "N of 6 on the home screen" over "Launcher", Done (LauncherManage:21-24),
N the top level's count and 6 `max_entries`.

- **A row per entry** (LauncherManage:29-38): the entry's icon, its label, and a kind line; then up,
  down and remove. The ends' arrows are greyed (LauncherManage:35, :91). Icon and label come from
  `LauncherEntries.resolve` (`launcher_entries.lua:82-107`), so an unavailable entry shows the dashed
  icon, greyed.
- **The kind line** is the launcher spec's kind name, then a detail: "KoPanda · library", "KOReader ·
  history", "Plugin · <plugin>", "Action · <action id>", "Folder on disk · <path>", "Folder · N entries ›"
  (`sheets/feature.md:391-393`; `launcher/feature.md:374-375`). The board writes "Screen · library" for three KoPanda screens and
  "KoPanda · settings" for the fourth (LauncherManage:33, :88); the kind names win, as the folder sheet
  uses them (`sheets/feature.md:392-393`). An unavailable or off entry shows its suffix in place of the
  detail.
- **A tap on a folder's row** (not its controls) opens that folder's own list: the same screen, its
  header "Folder · N" over the folder's label (FolderOpen:35-38), Done returning to the top level. A tap
  on any other row does nothing.
- **Add an entry** (LauncherManage:95-104): the caption, the five kinds as buttons two to a row, and the
  note "The seventh entry and beyond go into a folder." on the top level only. A folder's list adds into
  that folder.
- **A list that fills the screen** refuses another entry with the note "There's no room for another
  entry here." rather than drawing one that can't be seen; only a long folder can.
- **Ways in** (decision D5):
  - a hold on the launcher widget: `widgets/launcher.lua` gains `hold(ctx, ges, built)`, the contract
    `sheets` adds (`sheets/feature.md:89-91`), which opens the top level and consumes the hold;
  - "Hold to edit" on a folder's sheet (FolderOpen:40): the folder sheet's header gains that hint at its
    right, and a hold inside the sheet opens that folder's list. `sheet.lua` gains an optional `hold` in
    a sheet's spec and an optional `hint` in a heading header; a sheet without `hold` ignores holds as
    before (`sheets/feature.md:227`);
  - the menu's Launcher row.

#### Adding an entry

Decision D4. `EntryPicker.pick(kind, ctx, on_entry)` ends by calling `on_entry(entry)` with a valid
entry, or shows a note and calls nothing.

| Kind | Picker | Entry |
|---|---|---|
| KoPanda screen | A sheet of `targets.kopanda` (`schema.lua:105`), each with its label and icon from `LauncherEntries.KOPANDA` (`launcher_entries.lua:16-21`) | `{ kind = "kopanda", target }` |
| KOReader screen | The same for `targets.koreader` (`schema.lua:106`; `launcher_entries.lua:25-30`) | `{ kind = "koreader", target }` |
| Folder on disk | KOReader's `PathChooser` choosing folders only (`select_file = false`), from the file browser's path, as Folder shortcuts uses it (`frontend/apps/filemanager/filemanagershortcuts.lua:427-439`; `onConfirm(path)`, `frontend/ui/widget/pathchooser.lua:137-155`) | `{ kind = "directory", path, label }`, the label the folder's name, edited first |
| Action | The action tree below | `{ kind = "action", action, label, icon = "action" }` |
| Plugin | A sheet of the plugins loaded here, then the action tree | `{ kind = "plugin", plugin, action, label, icon = "action" }` |

- Kinds' fields are the validator's (`settings.lua:84-91`). Screen entries carry no label.
- **The action tree** is KOReader's own: `Dispatcher:addSubMenu(caller, menu, location, settings)` into a
  scratch table (`frontend/dispatcher.lua:1109-1170`), shown as a one-tab `TouchMenu` like the settings
  list. Only its four file-browser sections are kept: General, Device, Screen and lights, File browser,
  `section_list`'s first four (`dispatcher.lua:1132-1140`), the items after "Nothing" at index 1. Reader,
  reflowable and fixed-layout actions are never offered, since `Dispatcher:execute` drops them with no
  reader up (`isActionEnabled`, `dispatcher.lua:1435-1449`; `launcher/feature.md:194-197`). On close,
  the scratch table's keys other than `settings` are the ticked actions (`dispatcher.lua:740-749`,
  `:799-830`):
  - exactly one, ticked `true`: that action;
  - one holding a value (a number or a string: the `absolutenumber`, `incrementalnumber`, `string` and `configurable` categories, `dispatcher.lua:943-1067`; only `none` and `arg` store `true`, `:931-940`): the note "That action
    needs a value, which a launcher entry can't keep.", since an entry runs its action with `true`
    (`launcher_entries.lua:184-185`);
  - none, or more than one: the note "Pick one action." Nothing is added.
- **The plugin list** is `PluginLoader:loadPlugins()`'s enabled plugins (cached after the first call,
  `frontend/pluginloader.lua:273-292`) that are loaded here (`isPluginLoaded`, `:566-568`) and not
  `is_doc_only`, so never one the file manager doesn't load (`frontend/apps/filemanager/filemanager.lua:419`;
  `launcher/feature.md:194-197`), by `fullname` or `name` (`pluginloader.lua:104-115`), KoPanda itself
  left out. `registerAction` keeps no link from an action to its plugin (`dispatcher.lua:665-671`), so the
  plugin's action is picked from the same tree, and `plugin` records which plugin must be loaded for it
  (`launcher_entries.lua:60-63`).
- **The label** for an action or plugin entry defaults to the action's display name,
  `Dispatcher.getDisplayList({ [id] = true })[1].text` (`dispatcher.lua:866-890`); for a folder on disk,
  the path's last part. An `InputDialog` titled "Label" shows it for editing, with Cancel and Add; an
  empty label isn't accepted. Cancel adds nothing.
- **A chosen path** must be one the validator takes: absolute and not `/` (`settings.lua:117-118`).
  `/` gives the note "Choose a folder inside the root." and adds nothing.

### Goldens and budget

- **A scenario userpatch**, `spec/emulator/scenarios/2-scenario-screens.lua`, named to run after the home
  fixture's (`frontend/userpatch.lua:60-61`, alphanumeric order). `KOPANDA_SCREEN=layout` opens edit
  layout with row 2 selected, as EditLayout:43-58 draws it; `KOPANDA_SCREEN=launcher` first stores a
  launcher of Library, Series, Authors, History, a folder "Tools" of three action entries, and Settings,
  as LauncherManage:29-93 draws it, then opens launcher management. Each opens from the tick after the
  home's first settled signal.
- **Four goldens on the Colorsoft:** `edit-layout-diner`, `edit-layout-editorial`, `launcher-diner` and
  `launcher-editorial`, over the `populated` fixture, each shot on its screen's `KoPandaSettled`
  (`spec/emulator/patches/2-kopanda-capture.lua:61-74`).
- **Budget:** each capture's `paint_ms` is at most 250 ms, the home's tripwire
  (`spec/emulator/home_capture_spec.lua:7-10`).
- **Nothing else changes shape:** every home golden and `sheets`' four sheet goldens match unchanged. The
  folder sheet's hint has no golden, as the folder sheet has none.
- The settings menu is KOReader's and gets no golden.

### HOOKS.md

Every new KOReader surface goes into `kopanda.koplugin/HOOKS.md` with its `file:line`, by the task that
first uses it: `TouchMenu`'s item fields, its one-tab use and its closing; `FileManagerMenu:onShowMenu`'s
container pattern and the `appbar.settings` icon; `InputDialog`, `ButtonDialog`, `ConfirmBox` and
`PathChooser`; `Dispatcher:addSubMenu`, its section order, the scratch table's shape,
`Dispatcher.getDisplayList` and `isActionEnabled`; `PluginLoader:loadPlugins`, `isPluginLoaded` and
`is_doc_only`; `UIManager:forceRePaint`; `util.urlEncode`, `util.trim` and `util.tableDeepCopy`; and
Open-Meteo's geocoding endpoint and response.

## Notes

The draft said "spinners for ranges, pickers for icon": the schema has neither type. The table above maps
the six types it has. The menu row's labels are the schema's (`Layout`, `Launcher`), not the board's
"Rows and widgets" and "Launcher entries"; the SettingsMenu board's Clock 24-hour and Icon pack rows have
no key and don't appear. The direction doc says the spec wins on behaviour.

`sheets`' contract asserts the settings stub and the Edit layout note (its C3, C4 and C5). Those
criteria are history once it merges; this feature changes the specs they bind (`gesture_routing_spec`,
`home_sheet_spec`, `book_sheet_spec`) to what replaces the stub.

Owner decisions of 2026-10-15 written in: D1 (one flat list, a widget's group cut), D2 (the featured
row), D3 (the seventh entry), D4 (the five kinds, the action tree, the label, the generic icon) and D5
(the ways into each screen).

For the owner, each a default the lead chose that you can overturn at approval:

- **Width and Remove column** are on no board. Without them a share can't change on the device and a
  column can only go with its row. They appear on rows of two or more columns.
- **Editorial's selected card** is `hairline_light` (`#e2dfd4`); the board's `#e9e6dc` is in no palette.
- **Diner's two screens** have no board. They take Diner's band header, 3 px outlines, 2 px card shadows and a
  mustard selected card.
- **Arrows are Lucide chevrons**, not the board's filled triangles, which no face has.
- **After a location or units change** a connected home fetches the weather before its one refresh, so
  the widget doesn't sit empty until the next tap. The menu waits up to the fetch's timeouts.
- **ZIP codes are US** when the query is five digits; any other query is searched worldwide.
- **Removing a folder** asks first; removing anything else doesn't. Reset to the default doesn't ask.
- **A folder's only entry** removed takes the folder with it.
- **A full folder list** refuses another entry rather than leave it unseen; the D3 overflow refuses the
  same way.
- **No renaming** of an entry or a folder after it is added, no moving one between the top level and a
  folder, and duplicates are allowed: none is in the decisions.
- **A hold anywhere on the launcher** opens the top level, the folder entries included. The direction
  doc's "hold on the folder edits it" is met by the folder sheet's "Hold to edit".
- **Wording to replace with your own:** "Couldn't save <label>.", "City or ZIP code", "Finding a place
  needs Wi‑Fi.", "Searching…", "No place found for …", "Couldn't search for places.", "Choose a place",
  "That won't fit on the home.", "The home needs at least one row.", "Pick one action.", "That action
  needs a value, …", "Choose a folder inside the root.", "There's no room for another entry here.",
  "Remove <label> and its N entries?", "Most recent book", "More" and the label "Width".
- **The settings menu from the reader:** Tools › KoPanda › Settings exists in the reader too
  (`main.lua:310`), so the screens can open over a book. They work there; the home rebuilds on its next
  show.
