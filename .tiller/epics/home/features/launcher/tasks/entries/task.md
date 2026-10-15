# Launcher entries in the schema, resolved and run

## Approach

The data half of the launcher, with no drawing: the key, its validator, what each entry resolves to, and
what a tap on it runs. Paths into KOReader are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`; repo
lines are on `main` at `bfb043c`. This task starts after `featured-book` has merged, so `schema.lua` holds
eight keys ending in `featured.pinned`.

1. **Schema.** In `kopanda.koplugin/schema.lua`, after `featured.pinned`, add `launcher.entries` exactly
   as the feature gives it: `type = "launcher"`, `max_entries = 6`, `targets`, the default six,
   `label = "Launcher"`, `group = "launcher"`. A comment says what `max_entries` and `targets` are, as the
   `layout.rows` comment does (`schema.lua:33-35`). `schema.version` stays 1.
2. **Validator.** In `settings.lua`, add `Settings.validators.launcher(entry, value)`, with local helpers:
   - `has_exactly(t, names)`: true when `t` is a table whose keys are exactly `names`;
   - `is_name(v)`: a non-empty string;
   - `is_entry(schema_entry, e, in_folder)`: by `e.kind`:
     - `kopanda` and `koreader`: fields `kind`, `target`, with `target` in `schema_entry.targets[kind]`;
     - `plugin`: `kind`, `plugin`, `action`, `label`, `icon`;
     - `action`: `kind`, `action`, `label`, `icon`;
     - `directory`: `kind`, `path`, `label`, with `path` a string starting with `/` and longer than 1;
     - `folder`: only when `not in_folder`; `kind`, `label`, `entries`, with `entries` a list of 1 or more
       (`list_length`, `settings.lua:18-32`), each `is_entry(…, true)`;
     - any other kind: false.

     Every string field other than `kind` must pass `is_name`.
   - The top level: `list_length(value)` from 0 to `entry.max_entries`, each `is_entry(…, false)`.

   Nothing in it can raise: every field is type-checked before it is compared or indexed
   (`settings.lua:58-59`).
3. **`kopanda.koplugin/launcher_entries.lua`.** No widget code. It holds:
   - **The fixed tables.**
     - `KOPANDA = { library = { label = "Library", icon = "library" }, series = …, authors = …,
       settings = { label = "Settings", icon = "settings" } }`;
     - `KOREADER = { history = { label = "History", icon = "history", action = "history" },
       favorites = { label = "Favorites", icon = "bookmark", action = "favorites" },
       collections = { label = "Collections", icon = "list", action = "collections" },
       wifi = { label = "Wi-Fi", icon = "wifi", action = "toggle_wifi" } }`

     The dispatcher ids are from `frontend/dispatcher.lua:68`, `:70`, `:71` and `:124`. A spec asserts the
     two tables' keys equal the schema's `targets` lists, so they cannot drift.
   - **`LauncherEntries.available(entry)`** returns true, or false and a suffix:
     - `plugin`: false with "plugin missing" unless
       `require("pluginloader"):isPluginLoaded(entry.plugin)` (`frontend/pluginloader.lua:567-569`) and
       the action is registered;
     - `action`: false with "not available" unless registered;
     - `koreader`: the same test on the target's id;
     - `directory`: false with "folder missing" unless
       `lfs.attributes(entry.path, "mode") == "directory"`;
     - everything else: true.

     "Registered" is `#Dispatcher.getDisplayList({ [id] = true }) == 1` (`dispatcher.lua:866-890`; it
     lists an id only when `isAvailable(settingsList[id])`, `:689-696`).
   - **`LauncherEntries.resolve(entry)`** returns `{ label, icon, state, suffix }`, inside `pcall`:
     - unavailable: `state = "unavailable"`, `icon = "plugin_missing"`, the suffix from `available`;
     - the Wi-Fi target with `require("ui/network/manager"):isWifiOn()` false
       (`frontend/ui/network/manager.lua:182`; on the Kindle `sysfsWifiOn`, `frontend/device/kindle/device.lua:523`,
       `manager.lua:205-208`): `state = "off"`,
       `icon = "wifi_off"`, `suffix = "off"`;
     - otherwise `"ready"`, with the label and icon from the fixed tables or the entry, and a folder's or
       directory's icon `folder`.

     A raising resolution is logged and returns
     `{ label = <best label or "Entry">, icon = "plugin_missing", state = "unavailable", suffix = "not available" }`.
   - **`LauncherEntries.run(entry, ctx)`**, by the feature's table:
     - Library: `Home.close()`, then `require("apps/filemanager/filemanager").instance:onHome()`
       (`frontend/apps/filemanager/filemanager.lua:865-870`). If `featured-book` merged a shared helper
       for these two calls, call it instead.
     - Series and Authors: `note(text)`.
     - Settings: `SettingsMenu.open()`.
     - `koreader`, `plugin` and `action`, when available: `Dispatcher:execute({ [id] = true })`. The call
       reaches KoPanda's bridge, since the bridge replaces `Dispatcher.execute` itself
       (`dispatch_bridge.lua:41-57`).
     - `directory`, when available: `Home.close()`, then `fm.file_chooser:changeToPath(entry.path)`
       (`frontend/ui/widget/filechooser.lua:341-371`).
     - Folder: `note(T("%1 holds %2; folders open in a later update.", label, count))`, where `count` is
       "1 entry" or "N entries".
     - Unavailable: the note for its cause:
       - `"<label>: the <plugin> plugin isn't loaded."` (also used when the plugin is loaded but its action
         is gone);
       - `"<label>: <path> isn't there."`;
       - `"<label> isn't available here."`.

     `available` is re-checked at tap time, so a folder deleted since the build gives the note rather than
     a climb. `ctx` is unused today; it is kept so `sheets` can pass its own.
   - **`note(text)`** is `UIManager:show(InfoMessage:new{ text = text })`, with no `timeout`
     (`frontend/ui/widget/infomessage.lua:53`, `:283-290`). It is dismissed by a tap anywhere (`:67`,
     `:88-100`).
4. **`main.lua`** requires `launcher_entries`, beside the other modules (`main.lua:22-40`).
5. **HOOKS.md:**
   - `PluginLoader:isPluginLoaded` and `loaded_plugins` (`pluginloader.lua:479-488`, `:578-580`);
   - `Dispatcher.getDisplayList`, and the ids `history`, `favorites`, `collections` and `toggle_wifi` with
     their events and handlers: `filemanagerhistory.lua:59`, `filemanagercollection.lua:76`, `:845`,
     `networklistener.lua:54-60`;
   - `NetworkMgr:isWifiOn`;
   - `FileChooser:changeToPath`, its climb (`filechooser.lua:342-346`) and `PathChanged`
     (`filemanager.lua:108-114`);
   - `FileManager:onHome` (if `featured-book` hasn't listed it);
   - `InfoMessage` `timeout` and `dismissable`.

## Surfaces

`kopanda.koplugin/schema.lua`, `settings.lua`, `launcher_entries.lua` (new), `main.lua` (require),
`HOOKS.md`; specs `spec/unit/schema_spec.lua`, `spec/unit/settings_spec.lua`,
`spec/unit/launcher_entries_spec.lua` (new). `spec/unit/schema_json_spec.lua` runs unchanged against the
new key.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `schema_spec.lua` (C1): the nine-key order ending in `launcher.entries` with its fields, `max_entries`,
  `targets` and the default six. Its validator exists and accepts the default (the existing type and
  default checks, `schema_spec.lua:133-140`).
- `schema_json_spec.lua` (C1): unchanged; it must still pass, proving the new entry survives the JSON round
  trip.
- `settings_spec.lua` (C2):
  - **Accepted, each surviving a reopen:**
    - the default;
    - an empty list;
    - six entries, one of each kind;
    - a folder of three;
    - a plugin entry naming a plugin that doesn't exist.
  - **Refused, each leaving the file byte-identical:**
    - seven top-level entries;
    - an unknown kind;
    - a `kopanda` target outside `targets`;
    - an extra field;
    - a missing `label`;
    - an empty-string `label`;
    - a number for `action`;
    - a relative `path`, and `"/"`;
    - a folder inside a folder;
    - a folder with no entries;
    - a list with a hole (`{ [1] = e, [3] = e }`);
    - a string.
  - A stored invalid list reads as the default six without raising.
- `launcher_entries_spec.lua` (C3), in the plugin harness:
  - **Fixed tables:** the keys of the `KOPANDA` and `KOREADER` tables equal the schema's `targets` lists.
  - **`resolve` per kind**, with `PluginLoader.isPluginLoaded` stubbed and a spec action registered with
    `Dispatcher:registerAction` and removed with `Dispatcher:removeAction` (`dispatcher.lua:665-684`) in
    `finally`:
    - a loaded plugin with a registered action is ready;
    - a plugin not loaded reads "plugin missing";
    - a loaded plugin with an unregistered action reads "plugin missing";
    - an unregistered action reads "not available";
    - a directory that is a real temporary folder is ready;
    - a removed folder, and a path naming a file, read "folder missing";
    - a folder entry is ready with the `folder` icon;
    - the default six resolve to the labels Library, Series, Authors, History, Wi-Fi and Settings, with
      their icons.
  - **Wi-Fi.** `emulator_fake_wifi_connected` false (the harness default, `spec/plugin_harness.lua:71`)
    gives `off`, `wifi_off` and "off"; true gives `ready` and `wifi`.
  - **A raising resolution** (`isPluginLoaded` stubbed to error) gives "not available" and logs.
  - **`run`**, with a real file manager and home shown (`harness.show_fm(); harness.tick(2)`, as
    `gesture_routing_spec.lua` does):
    - History shows `fm.history.booklist_menu` over the home, and closing it leaves the home on top;
    - Wi-Fi calls `NetworkListener:onToggleWifi` once (spied on `fm.networklistener`);
    - an available plugin entry sends its action's event once;
    - Library closes the home and calls `onHome` once;
    - a directory entry closes the home and leaves `fm.file_chooser.path` at the folder's realpath;
    - Settings calls `SettingsMenu.open` once.
  - **Notes** (`UIManager.show` spied): Series, Authors, the folder ("Tools holds 3 entries; …" and
    "1 entry"), and each unavailable cause show an `InfoMessage` with the spec's text and a nil `timeout`.
    No `scheduleIn` is called. An unavailable entry's run dispatches nothing. A folder removed after
    resolving gives the folder-missing note, not a `changeToPath`.
  - **Never writes:** after every case the settings file is byte-identical (or absent).

## Edge cases

- A plugin entry can name a plugin folder whose `main.lua` returned `{ disabled = true }` (SSH without
  dropbear, `plugins/SSH.koplugin/main.lua:21-23`). It is never instantiated, so it reads "plugin missing",
  which is the truth.
- Plugin availability read during the pre-build on `CloseDocument` sees the reader's `loaded_plugins`.
  The file manager's `onClose` finalizes the list (`filemanager.lua:821`), and the reader instantiates
  every enabled plugin (`frontend/apps/reader/readerui.lua:464-465`). That is a superset of the file
  manager's for non-doc-only plugins, so no available entry greys, and doc-only ones are out of scope. The
  home shows moments later in the file manager, which re-reads them on its next build.
- `getDisplayList` calls `getNameFromItem`, which only reads `settingsList` (`dispatcher.lua:751-758`). It
  has no side effects.
- Two entries of the same target are allowed and both work.
- A `directory` path on an unmounted SD card fails the `lfs` test and reads "folder missing".
