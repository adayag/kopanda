# Checked-in catalog of KOReader actions, plugins and KoPanda icons

## Approach

Decisions S2 and S3: what the launcher editor offers comes from a JSON dump of the pinned build, checked
in and kept fresh the way the schema JSON is. Starts after `studio/studio-shell` (the package, the npm
script pattern) and after `home/device-menus` has merged (the `action`, `chevron_up` and `chevron_down`
icons); independent of the other tasks here. Repo lines on `main` at `c0fbd0d`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`.

1. **`bin/catalog-json`** (bash) and **`bin/catalog-json.lua`**, shaped as `bin/layout-fit` is (refusal
   with exit 2 and no luajit; a scratch `KO_HOME` removed on exit; `cd` to the emulator; `LUA_PATH` and
   `LUA_CPATH` as `bin/check:92-99` without the Busted rocks; stdout only the JSON). The Lua:
   - `require("ffi/loadlib")`, `commonrequire`; `G_reader_settings:saveSetting("plugins_disable_external",
     true)` before any plugin loads, so the emulator's own `plugins/` folders outside `BUILTIN_PLUGINS`
     (`frontend/pluginloader.lua:26-64`; SimpleUI, Bookshelf and the Solar icon pack are there) are
     discovered disabled (`:212-215`).
   - Show a file manager on an empty scratch directory (`FileManager:showFiles`, as
     `spec/plugin_harness.lua:95-98`), which loads the plugins and instantiates every one not
     `is_doc_only` (`frontend/apps/filemanager/filemanager.lua:418-424`), registering their actions.
   - **actions:** `Dispatcher:addSubMenu(caller, menu, scratch, "action")` into throwaway tables
     (`frontend/dispatcher.lua:1109-1170`); take items 2 to 5, asserting their texts are `section_list`'s
     first four titles in order (`:1132-1140`), else exit 1 naming what it found. For each section's
     items, settle which action it is (open fact below) and keep those whose tick stores `true` (`none`
     and `arg`, `:929-940`), as `{ id, title }`, `title` from `Dispatcher.getDisplayList({ [id] = true })[1].text`
     (`:866-890`).
   - **plugins:** `PluginLoader:loadPlugins()`'s enabled plugins (`pluginloader.lua:273-292`) that are
     loaded (`isPluginLoaded`, `:567-569`) and not `is_doc_only`, `kopanda` left out, as `{ name, label =
     fullname or name }`, sorted by label.
   - **icons:** with the plugin folder on `package.path`, `require("icons").entries` in order, each
     `{ id, label, svg }`, `svg` the file read from `kopanda.koplugin/<entry.file>`. `icons` requires
     `fonts` (`kopanda.koplugin/icons.lua:9`), which requires `ui/font` (`fonts.lua:7`): present here, so
     no stub.
   - **screens:** `require("launcher_entries").KOPANDA` and `.KOREADER`, each target's `{ label, icon }`
     (`launcher_entries.lua:17-32`). If requiring `launcher_entries` outside a loaded plugin pulls in
     state that fails headless (it requires `home` and `settings_menu`, `:6-8`), load the plugin with
     `PluginLoader:_load` as `spec/plugin_harness.lua:84-91` does, minus its file removals; record which
     was needed.
   - `rapidjson.encode(catalog, { sort_keys = true, pretty = true })` and a newline, as
     `bin/schema-json:21-24` does.
2. **`studio/package.json`** gains `"catalog": "../bin/catalog-json > src/catalog.json.tmp && mv
   src/catalog.json.tmp src/catalog.json"`; run it and commit `studio/src/catalog.json`.
3. **`studio/src/catalog.ts`**: a zod schema for the file and its inferred type, the parsed file exported
   as `catalog` (JSON import with `type: "json"`, as `schema.ts` loads the schema).
4. **`spec/unit/studio_catalog_spec.lua`**, as `studio_schema_spec.lua` does for the schema
   (`studio-shell/tasks/schema-contract/task.md:11-13`): fresh `bin/catalog-json` against the checked-in
   file, byte for byte, failing with "studio/src/catalog.json is stale: run npm run catalog in studio/";
   plus the content checks below.
5. **AGENTS.md** Commands gains `bin/catalog-json`'s line; the KOReader upgrade chore (AGENTS.md
   "Emulator, devices and references") names `npm run catalog` beside the goldens.

**Open facts, settled here and recorded in the PR:**

- **Which item is which action.** `_addItem`'s `none`/`arg` items carry a `text` and a `callback` but no
  id (`dispatcher.lua:932-939`). Candidates: (a) run each item's `callback(nil)` against a fresh scratch
  and read the one key it sets and its value, the device picker's own rule
  (`device-menus/tasks/entry-picker/task.md:38-44`), skipping items without a plain `callback`; (b) read
  the module's `settingsList` and `dispatcher_menu_order` through `debug.getupvalue` on
  `Dispatcher.registerAction` (`:665-671`). Prefer (a), which uses only what the menu exposes; (b) only if
  (a) can't tell `none`/`arg` items from others.
- **Which bundled plugins load on the emulator,** and which instantiate in a headless file manager.
  Several disable themselves in `main.lua` by returning `disabled = true` (hello always,
  `plugins/hello.koplugin/main.lua:8-9`; timesync without root, `plugins/timesync.koplugin/main.lua:9-10`;
  SSH without dropbear, `plugins/SSH.koplugin/main.lua:21-22`), and an instance that fails to create is skipped
  (`filemanager.lua:420-424`). List in the PR the bundled plugins left out and why, so the owner sees what
  the studio can't offer.
- **The run time,** since `bin/check` runs it once per gate: record it in the PR.

## Surfaces

- `bin/catalog-json`, `bin/catalog-json.lua` (new), `AGENTS.md`
- `studio/package.json`, `studio/src/catalog.json`, `studio/src/catalog.ts` (new)
- `spec/unit/studio_catalog_spec.lua`, `studio/test/catalog.test.ts` (new)

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `spec/unit/studio_catalog_spec.lua` (C11):
  - the checked-in file equals a fresh run; a second case compares a copy with one action removed,
    through the spec's own helper, and asserts the message names `npm run catalog` (the real files are not
    edited);
  - the sections are General, Device, Screen and lights, File browser, in order, and `history` is in
    General with the title "History"; no action id appears whose stored tick would not be `true` (check
    `toggle_wifi`'s presence and an `absolutenumber` action's absence, both read from `dispatcher.lua`);
  - every plugin name is in `BUILTIN_PLUGINS` (read by name from `pluginloader.lua`'s table in the spec,
    since it is local), none is `autoturn`, `coverimage`, `kosync` or `perceptionexpander` (the bundled
    `is_doc_only` ones), none is `kopanda`;
  - the icons are `Icons.entries`' ids in order, `action` among them, each `svg` equal to its file;
  - the screens equal `LauncherEntries.KOPANDA` and `.KOREADER` in label and icon;
  - `KOPANDA_EMULATOR=/nonexistent bin/catalog-json` exits 2 naming the path.
- `studio/test/catalog.test.ts` (C11): the zod schema parses the checked-in file; a copy with an action
  missing its `id` fails naming it.

## Edge cases

- KOReader's strings are gettext'd; the scratch `G_reader_settings` has no language, so titles are
  English. Assert one known title so a language leak fails.
- The emulator's `plugins/` holds untracked folders (SimpleUI, Bookshelf, the Solar pack);
  `plugins_disable_external` keeps them out whatever is installed.
- An action whose `condition` holds on the emulator but not on the Kindle (e.g. keyboard ones, the SDL
  device has a keyboard, `frontend/device/sdl/device.lua:72`) is offered and reads "not available" on the
  device (`launcher_entries.lua:60-79`); one hidden on the emulator is missing. The feature records this.
- A KOReader upgrade changes the catalog; the staleness spec makes it a deliberate regeneration.
