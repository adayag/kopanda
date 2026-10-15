# Launcher entries, folders and placeholders

## Summary

The launcher widget: up to six entries on the home screen, drawn as the look's tiles with icons from the
registry, each a KoPanda screen, a KOReader screen, a plugin, a folder on disk or a dispatcher action.
A seventh entry goes into a folder. Series and Authors are present from day one as placeholders
(direction doc "Launcher", "Placeholder entries", "Tap a folder entry").

## Behavior

- The default six: Library, Series, Authors, History, Wi‑Fi, Settings.
- Tap runs the entry: Library reveals the file browser, History opens KOReader's history, Wi‑Fi toggles
  and shows its state, Settings opens KoPanda's settings, a plugin entry runs the dispatcher action its
  plugin registers, an action entry dispatches it, a folder-on-disk entry opens the file browser there.
- Series and Authors show a short "coming with the library" note and return.
- A folder entry (a named group of entries) is drawn on the home like any other entry. Until `sheets`
  lands, tapping it shows a short note naming it; it is never hidden.
- An entry whose plugin is gone stays in place, greyed and labelled "plugin missing"; it is never
  silently dropped.
- Entries and folders live under the `launcher.entries` key; the widget never holds state of its own.
- Goldens for both looks on both profiles, including the missing-plugin state.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`; `base/` is the
koreader-base submodule in that checkout. Repo paths are on `main` at `bfb043c` unless marked. Canvas
references are to `.tiller/design/2026-10-13-kopanda-screens/<board>.dc.html:<line>`; sizes are board
pixels, as the looks use them.

One dependency is cited as spec, not code. `featured-book` is approved and not merged. Its key, its
default layout, its `home.lua` changes and its goldens are cited from
`.tiller/epics/home/features/featured-book/feature.md` and its `tasks/*/task.md` on `main` (commit
`bfb043c`). `home-layout` and `looks-and-schema` have merged, so their code is cited from `main`.

This feature starts after `featured-book` has merged.

### The key

One key enters the schema, after `featured.pinned`, the key `featured-book` adds after `stats.show`
(`featured-book/feature.md` "The key"). That makes nine keys with `look`. `schema.version` stays 1. The
key is new and has a default, so it needs no migration (`migrations.lua` is empty).

| Key | Type | Default | Group | Why it exists |
|---|---|---|---|---|
| `launcher.entries` | launcher; label "Launcher" | the default six (below) | `launcher` | The launcher's entries and folders (direction doc "Launcher", "Launcher management", "Schema consequences"). The owner wants to choose what the home's six entries run. |

No other key is added: there is no per-entry style option. A tile's colour, size and icon size are the
look's.

```lua
{
    id = "launcher.entries",
    type = "launcher",
    max_entries = 6,
    targets = {
        kopanda = { "library", "series", "authors", "settings" },
        koreader = { "history", "favorites", "collections", "wifi" },
    },
    default = {
        { kind = "kopanda", target = "library" },
        { kind = "kopanda", target = "series" },
        { kind = "kopanda", target = "authors" },
        { kind = "koreader", target = "history" },
        { kind = "koreader", target = "wifi" },
        { kind = "kopanda", target = "settings" },
    },
    label = "Launcher",
    group = "launcher",
}
```

- `max_entries` and `targets` are data the validator reads, the way `rows` reads `widgets` and
  `max_columns` (`schema.lua:32-47`; `settings.lua:75-93`). The studio and `device-menus` read the same
  lists to offer their pickers.
- Every value is a string, a number or a table of them, so the entry survives `bin/schema-json`'s dump and
  `schema_json_spec.lua:23`'s round trip. The default holds no empty table and no `false`.

#### Entries

An entry is a table with exactly the fields of its kind. Every field is a non-empty string, except a
folder's `entries`.

| Kind | Fields | Label | Icon |
|---|---|---|---|
| `kopanda` | `target`, one of `targets.kopanda` | Library, Series, Authors, Settings | `library`, `series`, `authors`, `settings` |
| `koreader` | `target`, one of `targets.koreader` | History, Favorites, Collections, Wi-Fi | `history`, `bookmark`, `list`, `wifi` (`wifi_off` when off) |
| `plugin` | `plugin` (the plugin's folder name without `.koplugin`), `action` (a dispatcher id), `label`, `icon` | `label` | `icon` |
| `action` | `action` (a dispatcher id), `label`, `icon` | `label` | `icon` |
| `directory` | `path` (absolute: starts with `/`, longer than one character), `label` | `label` | `folder` |
| `folder` | `label`, `entries` (one or more entries, none of them a folder) | `label` | `folder` |

- `kopanda` targets are KoPanda's own screens. `koreader` targets are KOReader's, each run by one
  dispatcher id (below). The list holds only targets that have a dispatcher id, need no argument and have
  an icon in the registry:
  - KOReader's file browser home (`filemanager`, `frontend/dispatcher.lua:66`) is left out: Library is
    that.
  - File search (`file_search`, `:163`) is left out: the registry has no icon for it. It can be an
    `action` entry.
- `icon` names a registry id (`icons.lua:13-53`). The validator checks only that it is a non-empty string,
  so a later icon pack or a removed icon never invalidates the whole list. An id the registry doesn't hold
  draws the entry without an icon, logged once per build.
- `bookmark` and `list` gain `"launcher"` in their `used_in`.
- A folder's entries are not limited in number. Folders don't nest: the owner's one folder board holds
  three plain entries (FolderOpen:42-61).

#### The validator

`Settings.validators.launcher(entry, value)` joins `Settings.validators` (`settings.lua:60-109`). It never
raises (`settings.lua:58-59`). It is true exactly when:

- `value` is a list (keys exactly 1 to n, the existing `list_length`, `settings.lua:18-32`) of 0 to
  `entry.max_entries` entries;
- each entry is a table whose fields are exactly its kind's, by the table above;
- `kopanda` and `koreader` targets are in `entry.targets[kind]`;
- `path` starts with `/` and is longer than one character;
- a folder's `entries` is a list of one or more entries, each valid by the same rules and none a folder.

An empty list is allowed, and draws no launcher (below). A stored value the validator rejects reads as the
default six, as every key does (`settings.lua:184-204`). One bad entry therefore resets the whole list.
`device-menus` and the studio write only valid lists, through `Settings.set`, which refuses an invalid one
(`settings.lua:212-220`).

### Resolving and running entries

`kopanda.koplugin/launcher_entries.lua` is the one module that knows what an entry is and does. The widget
draws from it, and `sheets`' folder sheet reuses it.

#### `LauncherEntries.resolve(entry)`

It returns a view `{ label, icon, state, suffix }`, read when the home is built. Every read is inside
`pcall`. An entry whose resolution raises is logged and drawn unavailable, with the suffix "not available".

- `state` is `"ready"`, `"off"` or `"unavailable"`.
- **Plugin.** Unavailable, with the suffix "plugin missing", when either:
  - `PluginLoader:isPluginLoaded(entry.plugin)` is false (`frontend/pluginloader.lua:567-569`). A
    disabled plugin loads only its `_meta.lua` and is never instantiated (`:211-215`). The file manager
    instantiates every enabled plugin that is not `is_doc_only` (`frontend/apps/filemanager/filemanager.lua:418-423`),
    filling `loaded_plugins` (`pluginloader.lua:479-488`).
  - the plugin is loaded, but its action is not registered: `#Dispatcher.getDisplayList({ [entry.action] = true }) == 0`
    (`frontend/dispatcher.lua:866-890`). That lists an id only when it is in `settingsList` and its
    condition holds (`:689-696`).

  Without that second test a tap would do nothing, since `execute` skips an id it doesn't know without a
  word (`:1569`, `:1435-1448`). An example is a plugin that renamed its action.
- **Action.** Unavailable, with the suffix "not available", when `getDisplayList` doesn't list
  `entry.action`.
- **KOReader.** The same test on the target's dispatcher id. For example, `toggle_wifi` is registered
  only on a device with a Wi‑Fi toggle (`dispatcher.lua:124`).
- **Directory.** Unavailable, with the suffix "folder missing", when
  `lfs.attributes(entry.path, "mode") ~= "directory"`. A missing folder is treated like a missing plugin,
  because tapping it would otherwise open some other folder: `changeToPath` climbs silently to the nearest
  existing ancestor (`frontend/ui/widget/filechooser.lua:342-346`). The direction doc's rule ("never
  silently dropped", "First run and failures") covers it the same way.
- **Wi‑Fi.** The `koreader` target `wifi` is `"off"`, with the suffix "off" and the icon `wifi_off`, when
  `NetworkMgr:isWifiOn()` is false. On the Kindle that is `sysfsWifiOn` (`frontend/device/kindle/device.lua:523`), which checks that
  `/sys/class/net/<interface>` exists (`frontend/ui/network/manager.lua:205-208`): a stat, cheap at build. On a device without a Wi‑Fi toggle it is always true
  (`frontend/ui/network/manager.lua:182-186`). There is no "connecting" state.
- **Everything else** is `"ready"`: `kopanda` targets, folders, and available entries of the other kinds.

#### `LauncherEntries.run(entry, ctx)`

This is what a tap on the entry does:

| Entry | Run |
|---|---|
| Library | `Home.close()`, then `FileManager.instance:onHome()` (`filemanager.lua:865-870`): the calls `featured-book`'s Open the Library button makes (`featured-book/feature.md` "The widget", Tap). |
| Series, Authors | A note: "Series are coming with the library." / "Authors are coming with the library." |
| Settings | `SettingsMenu.open()` (`settings_menu.lua:8-12`), the stub until `device-menus`. |
| `koreader` | `Dispatcher:execute({ [id] = true })`, with `id` the target's: `history` (`dispatcher.lua:68`), `favorites` (`:70`), `collections` (`:71`), `toggle_wifi` (`:124`). |
| `plugin`, `action`, available | `Dispatcher:execute({ [entry.action] = true })`. |
| `directory`, available | `Home.close()`, then `FileManager.instance.file_chooser:changeToPath(entry.path)` (`filechooser.lua:341-371`). That fires `PathChanged`, which updates the file manager's title bar (`filemanager.lua:108-114`). |
| Folder | A note: "Tools holds 3 entries; folders open in a later update." (the folder's label and count; "1 entry" for one). |
| Unavailable | A note: "Terminal: the terminal plugin isn't loaded." / "Downloads: /mnt/us/downloads isn't there." / "Screenshot isn't available here." (the label, plus the plugin or path). |

- **Dispatching.** `Dispatcher:execute` goes through KoPanda's dispatch bridge, which marks the file
  manager `is_always_active` while a home is shown (`dispatch_bridge.lua:36-58`). So the event reaches the
  file manager's module under the home: `FileManagerHistory:onShowHist`
  (`frontend/apps/filemanager/filemanagerhistory.lua:59`), `FileManagerCollection:onShowColl` with the
  default collection (`filemanagercollection.lua:76-77`), `onShowCollList` (`:845`, which opens the
  default collection itself when `coll_default` is set, `:856-858`), and `NetworkListener:onToggleWifi`
  (`frontend/ui/network/networklistener.lua:54-60`).
  - History over the home closes back onto it (`gesture_routing_spec.lua:421-433`).
  - All four are `category = "none"` with no `arg`, so `execute` sends `Event:new(event)`
    (`dispatcher.lua:1583-1587`).
- **Notes** are `InfoMessage`s with no `timeout`: no timer, by the e-ink rule. `timeout` defaults to nil
  (`frontend/ui/widget/infomessage.lua:53`), and only a set one schedules a close (`:283-290`). A tap
  anywhere dismisses the note (`dismissable` defaults to true, `:67`; full-screen `TapClose`, `:88-100`,
  `:307-312`), and the home is beneath it.
- **Out of scope:**
  - **News downloader.** Its "Go to news folder" and "Sync news feeds" are main-menu items only and
    register no dispatcher action (`plugins/newsdownloader.koplugin/main.lua:173-195`). It can be a
    `directory` entry for its news folder.
  - **Reader-only plugin actions.** An `is_doc_only` plugin is never loaded in the file manager
    (`filemanager.lua:419`), so its entry reads "plugin missing" there. A reader-only action is dropped
    by `isActionEnabled` with no reader up (`dispatcher.lua:1445`). `device-menus`' picker doesn't
    offer either.

#### Wi‑Fi on the home

The tile shows the state read at build. The home repaints when the state changes:

- `NetworkMgr` broadcasts `NetworkConnected` once connected (`manager.lua:109`) and `NetworkDisconnected`
  from `disableWifi`'s callback (`:406-408`). In the emulator, both come 2 s after the fake toggle
  (`frontend/device/sdl/device.lua:477-501`).
- The widget contract gains an optional `stale(built, ctx)`. It returns true when the built widget no
  longer shows the current state. The launcher's says so when its Wi‑Fi entry's drawn state differs from
  `NetworkMgr:isWifiOn()`.
- `Home:onNetworkConnected` (`home.lua:277-282`), after the weather, and a new `Home:onNetworkDisconnected`
  each call `stale` on every built slot whose module has it. If any returns true, they call
  `self:refresh()` once (`home.lua:244-260`). Both return nothing, so the event still reaches the other
  windows. The refresh is wrapped like the weather call; a failure is logged.
- `Resume` already rebuilds the home (`home.lua:264-266`).

### The widget

`kopanda.koplugin/widgets/launcher.lua`, id `launcher`, settings prefix `launcher`, registered in
`widgets.lua` (`:15-21`) and required from `main.lua`, by the widget contract as built (`widgets.lua:1-8`)
and as `featured-book` extends it (`tap` returning `false` falls through; `after_show`,
`featured-book/feature.md` "The widget"). The launcher has no `after_show` and no `refresh`.

- **Default layout.** `"launcher"` joins `layout.rows`' `widgets` list after `featured`. The default gains
  a full-width launcher row after the quote, before the weather and stats strip, the direction doc's order
  ("Layout": header; featured book; quote; launcher; stats; `home-layout/feature.md` "Default layout").
  HomeRetro draws its launcher after the strip (HomeRetro:47, :55), but the direction doc governs layout
  and there is one default for both looks.

  ```lua
  default = {
      { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
      { { widget = "featured", share = 1 } },
      { { widget = "quote", share = 1 } },
      { { widget = "launcher", share = 1 } },
      { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
  }
  ```

  A stored layout written before this feature doesn't name `launcher` and stays as stored.
- **Grid.** Entries fill a grid in list order, left to right, then top to bottom:
  - `launcher.columns` columns: Editorial 2 (Main:60), Diner 3 (HomeRetro:55).
  - Column widths from `Layout.columns(width, slots, launcher.column_gap)` (`layout.lua:22-42`) over
    share-1 slots, so the columns and gaps fill the width exactly.
  - `ceil(n / columns)` rows, `launcher.row_gap` apart.
  - With no entries the widget is 0 high, and the row engine gives a row of height 0 no gap
    (`layout.lua:105`).
- **Editorial** (Main:60-62), each entry a text row:
  - `padding.y` 15 above and below;
  - the icon at `icon_size` 22, then `icon_gap` 14, then the label (`launcher_label`: `strong` 16, `ink`);
  - a rule under the entry in `tile.rule_color` (`hairline_light`) at `stroke.hairline` (Main:61);
  - column gap 32, row gap 0 (Main:60).

  The entry's height is `2 × padding.y + max(icon, label line) + rule`.
- **Diner** (HomeRetro:55-57), each entry a tile `launcher.tile_height` 104 high:
  - padding 12/14;
  - the icon at 28 at its top left, and the label (`launcher_label`: `display` 14, `ink`) at its foot;
  - a `tile.outline_color` outline at `stroke.outline` with the `shadow.tile` hard shadow, drawn as
    `widgets/quote.lua:75-92` draws its tile;
  - column and row gap 14 (HomeRetro:55).

  The widget's height adds `shadow.tile.y` so the last row's shadow isn't cut.
  - **Fill by position**: the first three tiles take `launcher.accent_1_color` mustard, `accent_2_color`
    pink and `accent_3_color` teal (HomeRetro:56, :60, :64). The rest take `tile.fill_color` (paper,
    :68-76). The grey palette maps those roles to the PWRetro tiles' greys (PWRetro:56, :60, :64).
  - The accent follows the position, not the entry, so any first three entries are coloured.
- **States.**
  - **Off** (Wi‑Fi): the `wifi_off` icon and the label in their colours, then the suffix "off"
    (`launcher_suffix`, `muted`; EmptyStates:63-65).
  - **Unavailable:** the `plugin_missing` dashed icon (`icons/plugin_missing.svg`, `stroke-dasharray`), and
    the label and suffix in `muted` (EmptyStates:67-69, where the whole row is greyed). Diner keeps the
    tile's fill, outline and shadow; only its content greys. Diner has no board for this state.
  - **Suffix placement.** Editorial puts the suffix on the label's line, `launcher.suffix_gap` 6 after it
    (EmptyStates:65, :69), and ellipsizes the label to leave room. Diner puts it on its own line under the
    label (`launcher.suffix_below = true`): "Terminal PLUGIN MISSING" doesn't fit a third of the width on
    one line.
  - Labels never wrap; a long one ends in an ellipsis.
- **Icons in a colour.** Icons are black stroke files, and NanoSVG draws a file's own colours
  (`icons.lua:4-8`; `icons_spec.lua:88-92`, `:105-130` keep them black). `ImageWidget`'s `dim` only lightens and assumes
  a white ground (`frontend/ui/widget/imagewidget.lua:570-579`). So the launcher draws every icon through a
  small `kopanda.koplugin/tinted_icon.lua`, the method that note proposes:
  - render the file with `RenderImage:renderSVGImageFile(path, size, size)`, which gives an RGB32 buffer
    with straight alpha (`frontend/ui/renderimage.lua:338-344`, `:390-393`);
  - `alphablitFrom` it onto a white 8-bit buffer, then `invertRect` it, giving a mask whose ink is white
    (`base/ffi/blitbuffer.lua:1318`, `:1506`, `:1567`);
  - at paint, `colorblitFrom(mask, …, color)` for a grey colour and `colorblitFromRGB32` for a colour
    (`:1405-1437`). These use the mask's 8-bit value as alpha (`:990-1006`).

  The mask is built once per build, not per paint, and freed with the widget. Icons draw in `ink` (or
  `muted` when unavailable). Black files thus take the look's ink, and night mode can pass its own role
  later. Night tiles are `night-mode`'s.
- **Tokens.**
  - A `launcher` block joins both looks with identical paths: `columns`, `column_gap`, `row_gap`,
    `icon_size`, `icon_gap`, `padding { x, y }`, `tile_height`, `accent_1_color`, `accent_2_color`,
    `accent_3_color`, `suffix_gap` and `suffix_below`. Each value carries its board line in a comment. A
    value the look doesn't have is `false`: Editorial's `tile_height` and accents, Diner's `icon_gap`.
    Accents are numbered keys ending `_color`, because `looks_spec.lua:157-184` allows a string token only as
    a palette role under a key ending `color` (or a face or a marker), and mustard, pink and teal are Diner
    roles (`looks/diner.lua:27-29`). A list of roles would fail that check.
  - Two `type` parts, `launcher_label` and `launcher_suffix`, follow the type rules
    (`looks_spec.lua:186`):
    - Editorial: `strong` 16 `ink` (Main:61, weight 500, the `strong` face); `strong` 11, uppercase,
      tracking 0.1, `muted` (EmptyStates:65).
    - Diner: `display` 14 `ink` (HomeRetro:56, weight 800); `display` 11, uppercase, tracking 0.1, `muted`
      (the look's label style, `looks/diner.lua` `label`).
  - No new palette role. The board's plugin-missing grey `#a09d94` is in no palette, so `muted` stands in
    (see Notes).
- **Tap** (`tap(ctx, …)`; direction doc "Gestures": "a launcher entry runs"):
  - The entry under the tap is found from the entries' rectangles, kept on the built widget relative to
    the origin it was last painted at.
  - A tap inside an entry calls `LauncherEntries.run(entry, ctx)` and consumes the tap.
  - A tap in a gap between entries returns `false`, so it falls through to the home's next step
    (`featured-book`'s change to `home.lua`).
  - On `main`, `tap` gets only `ctx` (`home.lua:480-487`). How the widget learns the tap's position after
    `featured-book` merges is an open fact for the `widget` task (see that task).
  - Hold is `sheets`'.
- **Errors.**
  - Resolution is per entry, in `pcall`, so one bad entry greys alone.
  - A raising `run` reaches `Home:onGesture`'s `pcall`, which logs and closes the home onto the file
    browser (`home.lua:494-502`). That is the failsafe every tap has.
  - A failed build blanks the slot (`home.lua:207-215`).

### Goldens and budget

Every populated and typecover golden that `featured-book` commits changes, because the default layout
gains the launcher row (`featured-book/feature.md` "Goldens and budget"). This feature regenerates them
and adds a paperwhite pair of the empty home.

- **The empty scenario** of the fixture userpatch (`spec/emulator/scenarios/2-scenario-home-fixture.lua`)
  writes `launcher.entries` as the default five, with the sixth, Settings, replaced by
  `{ kind = "plugin", plugin = "kopanda_absent", action = "terminal", label = "Terminal", icon = "terminal" }`.
  That is the EmptyStates board's own launcher (EmptyStates:46-71).
  - No plugin of that name exists, so the entry is missing on every profile without touching the driver.
    The driver has no per-capture list of disabled plugins (`spec/emulator/driver.lua:18`, `:104-111`).
  - The patch writes it as it writes `look`: `LuaSettings` with `schema_version` 1
    (`2-scenario-home-fixture.lua:48-56`).
- **Wi‑Fi** is off in every capture: the driver turns the emulator's fake Wi‑Fi off (`driver.lua:80`,
  `:109`), so every golden shows "Wi-Fi off". The on state is covered by the unit specs and the owner's
  emulator run.
- **Goldens** (names after `featured-book`'s):
  - populated, both looks on both profiles, regenerated;
  - empty, both looks on the Colorsoft, regenerated, now with the missing plugin;
  - typecover, both looks on the Colorsoft, regenerated;
  - new: empty, both looks on the Paperwhite (`home-empty-diner-paperwhite`,
    `home-empty-editorial-paperwhite`), so the greyed entry is seen in grey too.
- **No row dropped.** No capture's log may contain the row engine's "doesn't fit the screen" line
  (`layout.lua:115`). Diner's five rows (header band, a 210 px cover row, the quote tile, two 104 px tile
  rows, the strip and the footer) have never been measured together. Whether they fit both profiles is an
  open fact for the `goldens` task (see that task).
- **Budgets.** `home-layout`'s and `featured-book`'s paint budgets hold with this row: a freshly built
  populated home paints in at most 250 ms on each profile, and after a book close the home's share is at
  most 100 ms. The row adds up to six `lfs` stats, a `getDisplayList` per dispatcher entry, an
  `isWifiOn` and six SVG renders to the build.

### HOOKS.md

Every new KOReader surface goes into `kopanda.koplugin/HOOKS.md` with its `file:line`:

- `PluginLoader:isPluginLoaded`;
- `Dispatcher.getDisplayList`, and the ids `history`, `favorites`, `collections` and `toggle_wifi` with
  their events and handlers;
- `NetworkMgr:isWifiOn` and the `NetworkDisconnected` broadcast;
- `FileChooser:changeToPath` and its climb, and `PathChanged`;
- `RenderImage:renderSVGImageFile`, and the `Blitbuffer` calls `alphablitFrom`, `invertRect`,
  `colorblitFrom` and `colorblitFromRGB32`;
- `InfoMessage`'s `timeout` and `dismissable`.

## Notes

Managing entries on the device is `device-menus`; this feature draws and runs them. The folder sheet (a
tap on a folder entry listing its entries by kind) is `sheets`'; this feature defines folder entries in
`launcher.entries`, validates them and draws them on the home.

Defaults this spec writes in from the design, the canvas and the reads, without a question:

- **Kinds and their names.** `folder` is the named group (LauncherManage:77, "Folder · 3 entries");
  `directory` is the picker's "Folder on disk" (LauncherManage:100). `kopanda` and `koreader` targets are
  fixed lists in the schema; `plugin`, `action`, `directory` and `folder` entries carry their own label,
  and `plugin` and `action` entries their own icon id, because nothing else can name them.
- **KOReader screens:** History, Favorites, Collections and Wi-Fi. The file browser home is Library.
  File search has no icon, so it is an `action` entry if wanted.
- **Unavailable is one state for three causes:** a plugin not loaded or its action gone ("plugin
  missing"), a folder on disk gone ("folder missing"), and an action KOReader doesn't offer here ("not
  available"). All draw the dashed icon and grey, and a tap on one shows why.
- **Greyed is `muted`**, not the EmptyStates board's `#a09d94`, which is in no palette. Adding a role would
  need six values with one from a board.
- **Diner accents by position:** the first three tiles are mustard, pink and teal, whatever they hold.
- **Diner's greyed tile and its suffix line** have no board.
- **Spacing the row engine owns.** Editorial's launcher sits 10 px under the quote on the board (Main:60);
  the row engine puts its 28 px `row_gap` there. The Paperwhite boards' smaller tile and padding (PWRetro:55-56,
  PWEditorial:60-61) aren't kept: a look has one set of sizes.
- **"Wi-Fi" with a plain hyphen.** The boards write U+2011 (Main:79), which the look faces may lack, and a
  one-line label never breaks.
- **Wi‑Fi shows "off" in every golden**, since captures run with the fake Wi‑Fi off.

For the owner:

- **The notes' wording** is a draft: "Series are coming with the library.", the folder note, and the three
  unavailable notes. Replace them with your own.
- **A tap on a greyed entry shows why** rather than doing nothing. "Tap acts" reads that way.
- **An unregistered action also reads "plugin missing"** when its plugin is loaded. This extends "missing
  when the plugin isn't loaded" so that no tile is ever a dead tap.
- **Turning Wi‑Fi on from the tile on the Kindle** may show KOReader's own "Scanning…" and network list
  over the home (`manager.lua:1115-1121`, `:1248`, `:1259`). That is KOReader's toggle, kept as it is;
  the emulator's fake toggle can't show it.
