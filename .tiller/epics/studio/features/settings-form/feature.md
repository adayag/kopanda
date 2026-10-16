# Form, layout editor and launcher editor from the schema

## Summary

The editor over a profile's settings: a form generated from the schema JSON, a row editor for the
layout, and a launcher editor, all writing the plugin's settings file in the plugin's own format
(design §6 Form). The studio follows the device's rules and wording for every edit the device can make
(`home/device-menus`), so a profile edited in the studio reads on the Kindle exactly as one edited there.

## Behavior

- Every schema key renders as one control by its type: a choice for `choice`, a toggle for `boolean`,
  the pin or "Most recent book" for `path`, a place search for `location`, a row that opens the layout
  editor for `rows` and one that opens the launcher editor for `launcher`. Keys are grouped in schema
  order, the look first.
- A change writes the profile's settings file at once, one key per write, with no Save button.
- A key stored in the file but not in the schema is listed and kept; a stored value the plugin would
  refuse shows the default and says so; a file from a newer schema is shown and not written.
- The layout editor shows rows with their columns and width shares and makes the device's row
  operations; a change that leaves out more home rows than the current layout does is refused with the
  device's note, measured by the plugin's own fit rule for the profile's screen.
- The launcher editor lists entries with icon, label and kind, reorders, removes, adds by kind (the
  seventh entry and beyond going into a folder), and edits an entry's label and an action or plugin
  entry's icon.
- Tests prove every schema key has exactly one control, an unknown key in a settings file is reported
  and kept, the studio's validators and the plugin's agree on a shared corpus, and the plugin reads a
  studio-written file key for key.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac` (its `base/`
submodule at `eeabdaa8`). Repo paths are on `main` at `c0fbd0d` unless marked.

### Order and what is cited as spec

This feature starts after two recorded prerequisites, both specified and neither built today:

- `studio/studio-shell` (F-kglqs4): the `studio/` package, its scripts and the `bin/check` studio stage
  (`.tiller/epics/studio/features/studio-shell/feature.md:22-39`, `:130-138`); the profiles API, where
  `GET /api/profiles/:id` gives `settings_path` (`:97-103`); the profile directory shaped like a `KO_HOME`
  (`:61-83`), which says reading and writing the settings file is this feature's (`:82-83`); the
  checked-in `studio/src/schema.json` and its zod type `studio/src/schema.ts` (`:105-115`;
  `tasks/schema-contract/task.md:14-22`); and `ProfileScreen.tsx` with a bounded region left for the form
  (`tasks/profile-screens/task.md:13-16`).
- `home/device-menus` (F-sn4px5): the row operations `rows_edit.lua` and `Layout.overflow`
  (`.tiller/epics/home/features/device-menus/feature.md:265-301`), the entry operations `entries_edit.lua`
  with decision D3 (`:329-347`), the five kinds and their pickers (`:381-420`), the `action` icon
  (`:259-261`), the place search (`:134-170`), and the wording this feature mirrors.

Each task that uses a module either feature builds reads the built code first and records in its PR any
line that differs from the spec cited here. Where this spec quotes the device's wording, the built
plugin's wording wins and the studio follows it.

### The keys

No key enters the schema and `schema.version` stays 1 (`kopanda.koplugin/schema.lua:7`). The form covers
the nine keys (`schema.lua:9-118`) and their six types: `choice`, `rows`, `location`, `boolean`, `path`,
`launcher`. There is no number, text or icon type; the draft's "number with its range, text, icon picker"
named types the schema doesn't have.

### The settings file

`studio/src/core/lua.ts` reads and writes the plugin's file format in TypeScript;
`studio/src/server/settings-file.ts` applies it to a profile's `settings_path`. No Lua parser dependency
is added and nothing in the studio runs LuaJIT to read or write settings.

#### What the plugin writes

`Settings.set` saves one key and `schema_version` and flushes (`kopanda.koplugin/settings.lua:331`).
`LuaSettings:flush` writes `dump(self.data, nil, true)` through `util.writeToFile(…, true, true, …)`
(`frontend/luasettings.lua:270-275`), which frames it as `"-- " .. filepath .. "\nreturn " .. data .. "\n"`
(`frontend/util.lua:1126-1129`). `dump` with `ordered` (`frontend/dump.lua:10-73`) writes:

- a table as `{`, then per key a newline, four spaces per level, `[`key`] = `value`,`, then a newline and
  the closing indent before `}`; an empty table as `{}`;
- keys in `orderedPairs` order (`base/ffi/util.lua:720-766`): keys of one type by `<`, keys of two types
  by `tostring` of each; LuaJIT compares strings byte by byte;
- strings with `%q`, numbers and booleans with `tostring`.

Read on the emulator's LuaJIT on 2026-10-15: `%q` escapes `"`, `\` and newline (as `\` then a newline),
writes other control bytes as decimal `\ddd` with no padding unless a digit follows (`"\r1"` gives
`\0131`, a tab `\9`, NUL `\0`, DEL `\127`) and passes bytes of 128 and over through; `tostring` of a
number is `%.14g` (`0.1+0.2` gives `0.3`, `1e-5` gives `1e-05`, `-0.0` gives `-0`).

The studio's writer produces exactly those bytes, the header naming the file's own absolute path. It
writes to a temporary file in the same directory, then renames it over the settings file, creating
`settings/kopanda/` first when it is missing. It writes no `.old`: `LuaSettings:backup` keeps one only
against a torn write (`frontend/luasettings.lua:252-267`), which the rename rules out; an existing `.old`
is left alone.

#### Reading

The reader accepts a Lua chunk of `--` line comments and whitespace, `return`, and one literal value:
tables with `[key] = value`, `Name = value` and positional fields separated by `,` or `;`; strings in
double or single quotes with Lua 5.1's escapes plus `\xXX` (LuaJIT's `\z` is left out: `dump` never writes it); decimal numbers with an optional sign,
fraction and exponent; `true` and `false`. Anything else (an expression, a call, a long string, `nil`, a
name such as the `inf` or `nan` that `dump` would write for a non-finite number) makes the file
unreadable, reported with its line and column; the reader never guesses. A table keeps its keys and their
types, so a list (keys exactly 1 to n), a keyed table and a table with sparse number keys stay apart, as
the plugin's `list_length` tells them apart (`settings.lua:16-32`).

#### The file's states

| File | The plugin | The studio |
|---|---|---|
| Missing | Every key reads its default (`luasettings.lua:27-45`) | Every key at its default; the first write creates it |
| `schema_version` absent, `false` or 1 | Read as version 1 (`settings.lua:264`) | Read and written |
| A number above 1 | Read, never written (`settings.lua:265-268`, `:319-321`) | Shown read-only, saying so |
| Any other `schema_version` | An integer of 0 or below asserts on a missing migration step (`settings.lua:244-245`) and a non-number raises on the comparison (`:265`), so every read is the default and every write fails; a number between 0 and 1 runs no step and is stamped 1 and flushed on open (`:243-249`, `:269-271`) | Unreadable, with the reason: no file the plugin wrote holds one |
| Unloadable, or returning `nil` or `false` | Falls back to `.old`, then `{}` (`luasettings.lua:31-45`), and the next write replaces it | Unreadable, with the reason; every key shown at its default, nothing written |
| Returning a non-table | Read as `{}` (`settings.lua:261-263`), and the next write replaces it | The same as above |
| Valid Lua outside the literal subset (an expression, a call, a long string, `\z`, a bare `inf` or `nan`) | Read as Lua evaluates it; a bare name is a nil global, so its key reads as absent | The same as above |

`migrations.lua` is empty at version 1 (`kopanda.koplugin/migrations.lua:1-4`), so no file can be older
than the schema today. The studio ports no migration: a Vitest asserts `schema.version` is 1 and fails
with "the studio reads only files at the schema's version: port migrations.lua's steps before raising
it", so the first schema bump meets the question deliberately.

Per key, in a readable file:

- **A stored value its validator accepts** is the value. **One it refuses**, or a key not stored, reads
  as the schema default, as `Settings.get` does (`settings.lua:279-299`); a refused one is reported.
- **A key not in the schema** (other than `schema_version`) is reported with its value as the writer
  would write it, and kept.
- **Writing** one key re-reads the file from disk, sets that key and `schema_version = 1`, keeps every
  other stored key as it was (unknown keys and refused values included, as `Settings.set` keeps the rest
  of the file), and writes. Writes to one profile run one at a time, so two quick changes can't lose one.

#### Validators

`studio/src/core/validators.ts` ports `Settings.validators` (`settings.lua:133-204`) with their helpers
(`list_length`, `is_slot`, `has_exactly`, `is_entry`, `ENTRY_FIELDS`, `:16-131`) over the reader's value
model, so a list, a keyed table and a sparse table are judged as Lua judges them. A shared corpus,
`spec/fixtures/studio/validator_cases.lua`, lists values per key with the expected verdict; a Lua spec
asserts `Settings.validators` gives each verdict and a Vitest asserts the TypeScript ones do, reading the
corpus with the studio's own reader. A case either side disagrees with fails, so the two can't drift.

#### The round trip

`spec/fixtures/studio/settings_written.lua` is committed: the TypeScript writer's output for a fixed
data set holding every schema key at a valid value other than its default (`quote.source` has only its
default, `schema.lua:74-77`), an unknown key holding a table with number and string keys, and strings with
a quote, a backslash, a newline, a tab and non-ASCII text, at the header path
`/mnt/us/koreader/settings/kopanda/settings.lua`.

- A Vitest asserts the writer still produces that file byte for byte.
- A Lua spec asserts that `LuaSettings:flush` writes the same bytes for the file's data (written at a
  temporary path, its header line then compared as the fixture's), and that, with the file copied into
  the test `KO_HOME`, `Settings.get` returns each key's value as written.

Together they prove, with no emulator in the Vitest, that the plugin reads a studio-written file key for
key and that the studio writes what the plugin would.

#### The settings API

On the profiles router (`studio-shell/feature.md:97-103`), JSON throughout:

- `GET /api/profiles/:id/settings`: `{ path, exists, state, reason?, schema_version, values, invalid,
  unknown }`. `state` is `writable`, `read_only` or `unreadable`; `values` holds every schema key's value
  as above (defaults when unreadable); `invalid` lists `{ key }` for refused stored values; `unknown` lists
  `{ key, text }` for keys outside the schema, `text` the value as the writer writes it.
- `PUT /api/profiles/:id/settings/:key` with `{ value }`: writes and answers the same shape, read from
  the file after the rename. A key not in the schema is `404 { error }`; a value its validator refuses is
  `400 { error }` naming the key, writing nothing, as `Settings.set` refuses (`settings.lua:312-315`); a
  read-only or unreadable file is `409 { error }`.

JSON maps onto Lua as arrays to lists and objects to keyed tables; `null` is refused.

### The form

`ProfileScreen.tsx`'s form region holds the form. The open profile's hash grows two routes:
`#/profiles/<id>/layout` opens the layout editor and `#/profiles/<id>/launcher` the launcher editor, each
with a Done back to the form, so a reload keeps the editor open.

- **One control per key**, in `schema.keys` order, under a heading per group (the group id capitalised:
  Appearance, Home, Weather, Quote, Stats, Featured, Launcher), labelled with the key's schema `label`.

| Type | Keys | Control |
|---|---|---|
| `choice` | look, text_size, weather.units, quote.source | One button per choice, its label shown, the current one marked; picking another writes its value |
| `boolean` | stats.show | A toggle; a change writes the new value |
| `path` | featured.pinned | "Most recent book" when the value is `false`, else the pinned path; a field to type a device path with Pin, and Most recent book to unpin (writes `false`). A path must be absolute and not `/` (`settings.lua:200-203`); anything else shows "A pin is a path on the device, starting with /." and writes nothing. The studio can't see the device's books, so it shows the path, where the device shows the title (`device-menus/feature.md:76`) |
| `location` | weather.location | The stored place's name and coordinates, and the place search below |
| `rows` | layout.rows | "Layout · N rows", opening the layout editor |
| `launcher` | launcher.entries | "Launcher · N entries", opening the launcher editor |

- **A type with no control** is reported in the form ("No control for <type> (<key>).") and skipped. The
  studio's schema type refuses an undeclared type at parse (`studio-shell/tasks/schema-contract/task.md:20-22`), so this
  path is reached only through a schema handed to the form in a test; a test proves every key of the real
  schema gets exactly one control.
- **Writing:** every change is one `PUT` of that key; picking the value already shown sends nothing. The
  control is disabled while its write is in flight; the answer becomes the form's state. A failed write
  shows "Couldn't save <label>: <error>." beside the control and the form keeps the file's state.
- **Reported:** keys outside the schema in a section "Not in the schema" with their text and "Kept as
  they are when the studio writes."; a refused stored value beside its control, "The stored value isn't
  allowed, so this shows the default."; a read-only file as a line above the form, "This settings file is
  from schema version <n>, newer than this studio's <m>, so it is shown and not written.", every control
  disabled; an unreadable file as "The studio can't read this settings file: <reason>", every control
  disabled.

### The place search

The device's rules, run by the studio's server (`device-menus/feature.md:134-152`;
`tasks/location-search/task.md:19-28`):

- `GET /api/geocode?q=<query>` trims the query as `util.trim` does (`frontend/util.lua:52-55`), and
  requests `https://geocoding-api.open-meteo.com/v1/search?name=<encoded>&count=10&language=en&format=json`,
  adding `&countryCode=US` when the trimmed query is exactly five digits. Encoding is `util.urlEncode`'s:
  every byte of the UTF-8 text outside `A-Z a-z 0-9 - . _ ~` as `%XX` upper case, after a newline becomes
  CR LF (`frontend/util.lua:1443-1455`), which `encodeURIComponent` is not.
- It answers `{ candidates }`, each `{ name, latitude, longitude, shown }` by the device's naming: `name`
  is "<name>, <admin1>" when `admin1` is non-empty and differs from the name, else "<name>, <country>"
  when `country` is, else the name; `shown` adds ", <country>" when the country isn't already its last
  part; a result without a non-empty name or with a non-number coordinate is skipped. No `results` is an
  empty list.
- An empty query is `400`; a failed request, a status other than 200 (as the device's `get`, `kopanda.koplugin/weather.lua:89-91`), an unreadable body or no answer within
  10 s (the device's total timeout, `kopanda.koplugin/weather.lua:76`) is `502 { error }`. The server
  binds to loopback only (`studio-shell/feature.md:41-42`); this is its first outbound request.
- The location control: a field with the hint "City or ZIP code" and Search; an empty query does
  nothing; "Searching…" while waiting; then "Choose a place" with one button per candidate's `shown`, a
  pick writing exactly `{ name, latitude, longitude }`; "No place found for “<query>”." for none;
  "Couldn't search for places." for any failure. The device's "needs Wi‑Fi" note has no studio case.

A shared case file, `spec/fixtures/studio/geocoding_cases.lua`, lists queries with their URLs and the
device's recorded responses (`spec/fixtures/geocoding/*.json`, which `home/device-menus/location-search`
commits) with their candidates; a Lua spec asserts `LocationSearch.url` and `LocationSearch.parse` give
them and a Vitest asserts the server's functions do.

### Fitting the layout (decision S1)

The studio runs the plugin's own rule, not a port of it.

- **`bin/layout-fit <width> <height> <dpi> [settings file]`**, shaped like `bin/schema-json`
  (`bin/schema-json:8-16`): the emulator's LuaJIT at `KOPANDA_EMULATOR` with the same default, exit 2
  naming the path without it. It reads a JSON array of row lists on stdin and prints
  `{ "screen": { "width": w, "height": h }, "overflow": [n, …] }`, one count per row list, each
  `Layout.overflow(rows, ctx)` (`device-menus/feature.md:294-301`; `tasks/edit-layout/task.md:10-12`).
  Exit 1 with the reason for input that isn't JSON, a row list `Settings.validators.rows` refuses (naming
  its index), or a Lua error.
- **Its process** is a headless KOReader in a scratch `KO_HOME`, removed on exit, with the plugin's
  modules on `package.path`, as `bin/check` runs specs (`bin/check:92-99`). The settings file, when given
  and present, is copied to the scratch's `settings/kopanda/settings.lua`, so the look, text size and the
  settings the widgets read come from the profile through the plugin's own `Settings.get`.
- **The ctx** is the home's (`kopanda.koplugin/home_rows.lua:84-91`) without `home`, which no widget's
  height reads (`ctx.home` appears only in tap and after-show code, `widgets/featured.lua:462`, `:493`,
  `widgets/weather.lua:60`). The palette variant changes colours only (`looks.lua:35-44`; its uses in
  widgets pick colours or a hatch, e.g. `widgets/featured.lua:254`), so a profile's colour flag is no
  input.
- **What a height depends on**, so the count is the device's rule on this Mac, today:
  - the time: the date's lines, the clock's text and the quote of the day (`widgets/date.lua:40`,
    `widgets/clock.lua:26`, `widgets/quote.lua:75`);
  - the profile's settings: `stats.show` (`widgets/stats.lua:131-139`), `quote.source` (`widgets/quote.lua:32`),
    `launcher.entries` (`widgets/launcher.lua:148-149`);
  - the machine: the weather row reads the cached reading (`widgets/weather.lua:26`), absent in a scratch
    `KO_HOME`; the launcher resolves each entry (`launcher_entries.lua:84-109`), so plugin entries read
    "plugin missing" and device folders "folder missing" here, and Diner puts a suffix on its own line
    (`looks/diner.lua:321`, `widgets/launcher.lua:99-101`). The featured row's height is the cover box
    from tokens alone (`widgets/featured.lua:410-413`, `featured_cover.lua:132-142`).

  Both counts in a check carry the same machine, so the comparison holds where the absolute count might
  not. A layout admitted here that is a row too tall on the Kindle loses that row there, logged, and the
  device's own editor can fix it (`device-menus/feature.md:299-301`).
- **The server:** `POST /api/profiles/:id/layout-fit` with `{ rows }` runs `bin/layout-fit` once with the
  profile's width, height and dpi and its settings file, for the current effective `layout.rows` and the
  proposed rows, and answers `{ checked: true, current, proposed }`. Any failure to check (exit 2, another
  exit, unreadable output, no answer within 30 s) answers `{ checked: false, reason }`. The script is
  found from the server module's own location, so `npm run dev` and `npm start` both reach the repo's
  `bin/`; the server passes its environment through, so `KOPANDA_EMULATOR` works as for `bin/check`.
- **The editor** asks before every change, moves and resets included (row 1 carries the header's chrome,
  `layout.lua:176-206`, so order changes height), shows "Checking fit…" and takes no other edit while it
  waits, then: `proposed > current` → "That won't fit on the home." and nothing written; otherwise the
  write. Unchecked → the write, and "Fit not checked" with the reason stays under the editor's header
  until a later check succeeds. The studio builds, tests and starts without the emulator
  (`studio-shell/feature.md:109-111`); only the fit check needs it.

### The layout editor

`studio/src/core/rows-edit.ts` ports `RowsEdit` (`device-menus/tasks/edit-layout/task.md:13-31`): `move`,
`add_row`, `add_column` (refused at `max_columns`, `schema.lua:39`), `change_widget`, `set_share` (1 to 3),
`remove_column` (rows of two or more), `remove_row` (refused for the only row), `reset`, `unused`, `label`,
`share_text`, `caption`, with their notes. A shared corpus, `spec/fixtures/studio/rows_edit_cases.lua`,
names each operation's arguments and its result or refusal; a Lua spec asserts `RowsEdit` gives them and a
Vitest asserts the port does.

The screen mirrors edit layout (`device-menus/feature.md:303-325`): header "Home" over "Edit layout" and
Done; a card per row with up and down arrows (disabled at the ends), its caption and a box per column with
the widget's label and share; a click on a card selects it (first column), a click on a box of the selected
card selects that column; the selected card shows Add column (disabled at three columns or none unused),
Change widget, Width and Remove column (rows of two or more) and Remove row; the foot holds Add row
(disabled with none unused) and "Reset to the look's default". Pickers list `unused(rows)`; Change widget
lists the column's own widget first, marked; Width lists 1, 2 and 3, the share marked. The selection is the
editor's, never stored, and follows a moved row. Every change goes through the fit check, then one `PUT` of
`layout.rows`.

### The catalog (decision S2, S3)

`studio/src/catalog.json` is checked in and is byte for byte the output of a new `bin/catalog-json`,
which `npm run catalog` writes (temp file then `mv`, as `npm run schema` does,
`studio-shell/tasks/schema-contract/task.md:5-7`). `spec/unit/studio_catalog_spec.lua` diffs it against a
fresh run and fails with "studio/src/catalog.json is stale: run npm run catalog in studio/". The studio
imports it; nothing in the studio runs LuaJIT for it. `studio/src/catalog.ts` types it (zod).

`bin/catalog-json` runs a headless KOReader file manager in a scratch `KO_HOME`, with external plugins
off (`plugins_disable_external`, `frontend/pluginloader.lua:212-215`) so only KOReader's bundled plugins
load (`BUILTIN_PLUGINS`, `:26-64`), and prints JSON with sorted keys:

- **`actions`:** the action tree's four file-browser sections, in `section_list` order with their titles
  (`frontend/dispatcher.lua:1132-1140`), each listing in tree order the actions a launcher can run: the
  ones `Dispatcher:_addItem` lists with category `none` or `arg` (`:931-940`), as `{ id, title }`, `title`
  the action's display name (`Dispatcher.getDisplayList`, `:866-890`), which the device takes as the
  default label (`device-menus/feature.md:415-417`). Actions the bundled plugins register when the file
  manager instantiates them (`registerAction`, `:665-671`; `frontend/apps/filemanager/filemanager.lua:418-424`)
  are included.
- **`plugins`:** the bundled plugins the file manager loads: enabled, not `is_doc_only`
  (`filemanager.lua:419`), loaded (`isPluginLoaded`, `pluginloader.lua:567-569`), as `{ name, label }`,
  `label` the `fullname` or `name`, sorted by label as the device's sheet is
  (`device-menus/tasks/entry-picker/task.md:47-51`).
- **`icons`:** the registry's entries in order (`kopanda.koplugin/icons.lua:13-55`, with device-menus'
  `chevron_up`, `chevron_down` and `action`), each `{ id, label, svg }`, `svg` the text of its file under
  `kopanda.koplugin/icons/`. `icons.lua` requires `fonts` (`icons.lua:9`), which requires KOReader's
  `ui/font` (`fonts.lua:7`); the dump runs inside KOReader already, so it requires `icons` as the plugin
  does, with no stub.
- **`screens`:** `LauncherEntries.KOPANDA` and `.KOREADER`, each target's label and icon
  (`launcher_entries.lua:17-32`), for the screen pickers and the list.

The catalog is what the pinned build loads on the emulator, and that is its limit. A plugin not bundled
with KOReader (SimpleUI, the owner's `cwngsync`) can't be picked in the studio, nor can its actions; nor
can a bundled plugin that disables itself on the emulator's device (`main.lua` returning
`disabled = true` on a device check, e.g. `plugins/timesync.koplugin/main.lua:9-10`,
`plugins/SSH.koplugin/main.lua:21-22`), nor an action whose `condition` fails there
(`dispatcher.lua:689-695`). Such entries are added on the device. One the catalog offers that the Kindle
lacks shows there as unavailable (`launcher_entries.lua:60-79`).

### The launcher editor

`studio/src/core/entries-edit.ts` ports `EntriesEdit` (`device-menus/tasks/launcher-manage/task.md:12-26`):
`move` and `remove` within a list (a folder's only entry removed takes the folder), `add` by decision D3
(into a folder at its end; a top level under `max_entries`, `schema.lua:103`, at its end; a full top level
into its first folder's end; else the sixth entry and the new one become a folder "More" in slot six),
`count` and `kind_line`. A shared corpus, `spec/fixtures/studio/entries_edit_cases.lua`, is asserted against
`EntriesEdit` by a Lua spec and against the port by a Vitest. Two operations are the studio's own (decision
S3): `set_label` for an entry of a kind with a label (plugin, action, directory, folder,
`settings.lua:84-91`) and `set_icon` for an action or plugin entry; folder and directory entries draw the
folder icon and screen entries their table's, whatever is stored (`launcher_entries.lua:95-101`).

The screen mirrors launcher management (`device-menus/feature.md:349-371`):

- Header "<N> of 6 on the home screen" over "Launcher", Done. A row per entry: its icon, label and kind
  line, up and down (disabled at the ends) and remove. Icons are the catalog's SVGs, inked black
  (`icons.lua:1-8`), so each is drawn on a light tile; an icon id the catalog lacks shows the id. Screen
  entries take their catalog label and icon.
- A click on a folder's row opens its list, headed "Folder · N" over the folder's label, Done returning to
  the top level. Removing a folder asks "Remove <label> and its N entries?" first.
- A click on another entry's label edits it in place (an empty label after trimming is refused); an action
  or plugin entry's icon opens the icon picker, every catalog icon on its tile with its label.
- "Add an entry": KoPanda screen, KOReader screen, Folder on disk, Action, Plugin
  (`device-menus/tasks/entry-picker/task.md:10-13`), and on the top level "The seventh entry and beyond go
  into a folder." A folder's list adds into that folder.
  - **Screens:** the schema's targets for the kind (`schema.lua:104-107`), each with its catalog label and
    icon; a pick adds `{ kind, target }`.
  - **Folder on disk:** a typed device path, its trailing `/` removed; `/` gives "Choose a folder inside
    the root." and a path not starting with `/` gives "Type a folder path on the device, starting with /.";
    then the label, defaulting to the path's last part; adds `{ kind = "directory", path, label }`.
  - **Action:** the catalog's four sections, one action picked; the label, defaulting to its title; the
    icon, defaulting to `action`; adds `{ kind = "action", action, label, icon }`.
  - **Plugin:** the catalog's plugins, then the same action list, label and icon; adds
    `{ kind = "plugin", plugin, action, label, icon }`.
  - Cancel at any step adds nothing.
- Every change is one `PUT` of `launcher.entries`. No moving between the top level and a folder, and
  duplicates are allowed, as on the device (`device-menus/feature.md:479-480`). An entry whose action or
  plugin the catalog lacks (added on the device) is listed by its ids and moves, removes and edits as any
  other.

### What the preview takes from this feature

Nothing beyond the file. `studio/preview` (F-29oj9m) materialises the profile's settings into a scratch
`KO_HOME`; this feature leaves the settings file at `settings_path`, replaced by rename on each successful
`PUT`, and the `PUT`'s answer is the moment a change landed. Marking the preview stale is the preview's.

## Notes

Owner decisions of 2026-10-16 written in: S1 (the fit runs the plugin's own rule through `bin/layout-fit`,
"Fit not checked" without the emulator), S2 (actions and plugins from a checked-in catalog of the pinned
build, with a staleness spec) and S3 (the icon registry offered for action and plugin entries, default
`action`, and labels edited for every kind that has one).

For the owner, each a default the lead or the spec chose that you can overturn at approval:

- **The studio reads and writes the file in TypeScript,** strictly: the literal subset `dump` writes plus
  the hand-written forms (`Name =`, positional fields, comments). A file outside it is reported, never
  guessed at.
- **The studio won't write over a file it can't read.** The device differs by case: an unloadable or
  non-table file reads as defaults and is replaced on its next change; valid Lua outside the subset is
  read as Lua evaluates it. Fix or delete the file to edit the profile.
- **No `.old` backup** is written; the rename makes a torn file impossible.
- **Every change writes at once,** one key per write, with no Save.
- **Shared corpora rather than trust:** the validators, the round trip, the row and entry operations and
  the geocoding rules are each asserted on both sides from one fixture under `spec/fixtures/studio/`.
  The row and entry corpora are the spec's addition beyond the brief, to keep the two ports from drifting.
- **Any failure to check fit** (not only a missing emulator) allows the edit with "Fit not checked" and the
  reason.
- **The catalog embeds each icon's SVG text,** so no route serves files from the plugin folder and an icon
  change also makes the catalog stale.
- **A long folder** has no "no room" refusal in the studio: that rule is about the device's screen. The
  device's folder sheet decides what it shows.
- **Groups are headed** by their ids capitalised; the schema has no group labels.
- **Visual direction:** the theme studio's 2026-10-09 default (dark, one violet accent), as the shell
  sets it; no drawn board. The layout and launcher editors follow the device screens' structure, not
  their look.
- **Wording to replace with your own:** "No control for <type> (<key>).", "Couldn't save <label>:
  <error>.", "Not in the schema", "Kept as they are when the studio writes.", "The stored value isn't
  allowed, so this shows the default.", "This settings file is from schema version <n>, newer than this
  studio's <m>, so it is shown and not written.", "The studio can't read this settings file: <reason>",
  "A pin is a path on the device, starting with /.", "Pin", "Layout · N rows", "Launcher · N entries",
  "Checking fit…", "Fit not checked", "Type a folder path on the device, starting with /.", "Label",
  "Icon". The device's wording ("Most recent book", "City or ZIP code", "Searching…", "Choose a place",
  "No place found for …", "Couldn't search for places.", "That won't fit on the home.", "The home needs at
  least one row.", "Choose a folder inside the root.", "Remove <label> and its N entries?", "More", "Reset
  to the look's default", "The seventh entry and beyond go into a folder.") follows the device's.

Validation messages are the validators' own: the server's refusal names the key, as `Settings.set` does;
field help beyond the labels is not added.
