# Pure-data schema with look, the settings store with versioning, and the JSON dump

## Approach

1. `kopanda.koplugin/schema.lua`: `return { version = 1, keys = { { id = "look", type = "choice",
   choices = { { value = "diner", label = "Diner" }, { value = "editorial", label = "Editorial" } },
   default = "diner", label = "Look", group = "appearance" } } }`. No `require`, no functions, no
   upvalues, so plain `dofile` works on the device's LuaJIT and in `bin/schema-json`.
2. `kopanda.koplugin/settings.lua`, modelled on `state.lua` (same module-state shape, same mkdir and
   read-back write path, every call wrapped so a failure is logged and reads as the default):
   - Opens `DataStorage:getSettingsDir() .. "/kopanda/settings.lua"` with `LuaSettings:open` on first
     use. `LuaSettings:open` never errors: a missing file is `{}`, a corrupt one falls back to `.old`
     then `{}` (`frontend/luasettings.lua:21-48`), but a file returning a non-table is taken as the
     data (`:32-33`), so the module treats a non-table `data` as empty.
   - A corrupt file falls back to `settings.lua.old`, which `flush`'s `backup()` writes whenever the
     file is more than 60 s old (`frontend/luasettings.lua:36-40`, `:251-265`); that is KOReader's
     recovery and is kept.
   - Never passes a default to `readSetting`: with a truthy default it writes the default into the
     data (`frontend/luasettings.lua:89-99`). Reads the raw value and falls back itself.
   - A per-type validator table, holding `choice` only: a value is valid when it equals one of the
     entry's `choices[i].value`. `Settings.get(key)` returns the stored value when valid, else the
     schema default; an undefined key logs and returns nil.
   - `Settings.set(key, value)` returns `false, reason` for an undefined key, a disallowed value or a
     file newer than the schema, writing nothing. Otherwise saves, stamps `schema_version`, flushes and
     reads back as `State.set` does (flush neither makes the directory nor reports a failed write,
     `frontend/luasettings.lua:270-275`, `frontend/util.lua:1124-1143`).
   - Versioning on open: a missing `schema_version` counts as 1. Older than `schema.version`: apply
     `migrations[v + 1]` … `migrations[schema.version]` from `kopanda.koplugin/migrations.lua` (a list
     of functions taking and returning the data table; empty at version 1), stamp, flush. Newer: mark
     the store read-only for the session. The runner is a local function that takes the step list as
     an argument, exposed for the spec as `Settings._migrate(data, steps, target)`.
   - `Settings._reset()` drops the cached `LuaSettings` object so the spec can reopen; nothing else
     calls it.
3. `bin/schema-json`: bash, same `KOPANDA_ROOT` and `KOPANDA_EMULATOR` defaulting and exit-2 refusal as
   `bin/check`; runs `SCHEMA="$KOPANDA_ROOT/kopanda.koplugin/schema.lua" LUA_CPATH="$KOPANDA_EMULATOR/common/?.so"
   "$KOPANDA_EMULATOR/luajit" -e 'io.write(require("rapidjson").encode(dofile(os.getenv("SCHEMA")),
   {sort_keys = true, pretty = true}), "\n")'`. Positional arguments after `-e` aren't `arg[1]`, hence
   the env var. `rapidjson` is the only bundled encoder that sorts keys (`sort_keys`,
   `base/thirdparty/lua-rapidjson/build/downloads/source/API.md:80`; dkjson orders only listed keys,
   `$KOPANDA_EMULATOR/common/dkjson.lua:325-346`). Research ran this command against an inline table; the task runs it
   against the real file.
4. `main.lua` requires `schema`, `settings` and `migrations` at load time with the others (plugin root
   is on `package.path` only during load, `frontend/pluginloader.lua:242`, `:269-270`).
5. `spec/plugin_harness.lua` `load()` also removes `settings.lua` and `settings.lua.old` before it
   removes the directory (`spec/plugin_harness.lua:68-70` removes only the state file today, and all
   unit specs share one `KO_HOME` per run), so no spec sees another's settings.
6. `HOOKS.md`: `luasettings`, `datastorage` already listed for state; add the `readSetting` default
   trap and `rapidjson` (harness side) with their lines. AGENTS.md Commands: one line for
   `bin/schema-json`.

## Surfaces

`kopanda.koplugin/schema.lua`, `settings.lua`, `migrations.lua`, `main.lua` (requires only),
`kopanda.koplugin/HOOKS.md`, `bin/schema-json`, `AGENTS.md`, `spec/plugin_harness.lua`, `spec/unit/schema_spec.lua`,
`spec/unit/schema_json_spec.lua`, `spec/unit/settings_spec.lua`.

## Tests

Written first, each run failing before the code exists.

- `schema_spec.lua` (C1): loads `schema.lua` with `loadfile` + `setfenv` to an empty environment (no
  `require`), walks the result to assert no function values; asserts `version == 1`, entry fields,
  unique ids, every type has a validator in `settings.lua` (the type set lives there, not in the
  schema), `look`'s choices, labels, default
  and group.
- `schema_json_spec.lua` (C2): runs `bin/schema-json` twice through `io.popen` from `KOPANDA_ROOT`,
  asserts identical output, decodes it with `rapidjson.decode` and asserts deep equality with
  `dofile(schema.lua)`; runs it with `KOPANDA_EMULATOR=/nonexistent` and asserts exit 2, reading the
  status from the output as `spec/unit/check_spec.lua:6-14` does, since `io.popen`'s `close()` doesn't
  return it reliably on KOReader's LuaJIT.
- `settings_spec.lua` (C3, C4) under the fresh `KO_HOME`: default with no file; default with a corrupt
  file (garbage bytes, and `return 5`) with `settings.lua.old` removed first, and the `.old` value with a
  usable `.old` beside a corrupt file; default with `look = "retro"` stored; stored value when valid;
  set of an undefined key and of `"retro"` returns false with a reason and leaves the file's bytes
  unchanged; accepted set creates the directory and survives `_reset()`; no `schema_version` reads as
  1 and is stamped on first write; `_migrate` with two injected steps from 1 to 3 runs them in order
  and stamps 3; a file stamped 99 reads with fallback, refuses `set`, bytes unchanged.

## Edge cases

- The settings directory is a file, or unwritable: `set` returns false with the reason, `get` keeps
  returning defaults, nothing raises into KOReader.
- A stored key the schema no longer defines stays in the file untouched; `get` refuses to read it.
- A file from a newer schema must never be rewritten by this plugin, including the version stamp.
