# Read and write a profile's settings file, with validators shared with the plugin

## Approach

The foundation: the studio reads and writes `settings/kopanda/settings.lua` as the plugin does, judges
values as the plugin does, and serves both through the profile's settings API. Starts after
`studio/studio-shell` has merged; read its built `profiles.ts`, `routes/profiles.ts`, `app.ts` and
`schema.ts` first and record any line that differs from its spec. Repo lines on `main` at `c0fbd0d`;
KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`.

1. **`studio/src/core/lua.ts`**, pure, no dependency:
   - A value model for what a settings file can hold: string, number, boolean, and a table that keeps
     its keys (string or number) and values, with helpers `listLength(t)` (`settings.lua:16-32`'s rule:
     keys exactly 1 to n, else none) and `get(t, key)`. JSON mapping both ways: arrays to lists, objects to
     keyed tables; `null` and non-finite numbers refused.
   - `parse(text)`: the subset in the feature's "Reading" (comments, `return`, one literal; `[k] =`,
     `Name =`, positional fields; `,` or `;`; quoted strings with Lua 5.1 escapes plus `\xXX` (not LuaJIT's `\z`, which `dump` never writes), `\ddd` up to
     three digits, `\` + newline; decimal numbers with sign, fraction and exponent; `true`, `false`).
     Strings are bytes decoded as UTF-8; invalid UTF-8 is unreadable. Returns the value or an error with
     line and column. A repeated key keeps the last value, as Lua does.
   - `serialize(value, headerPath)`: `"-- " + headerPath + "\nreturn " + dump(value) + "\n"`
     (`frontend/util.lua:1126-1129`), `dump` as `frontend/dump.lua:10-73` with `orderedPairs`
     (`base/ffi/util.lua:720-766`): same-type keys by `<` (strings byte-wise, numbers numerically), mixed
     types by their `tostring`; strings by LuaJIT's `%q` and numbers by `%.14g`, the byte rules the
     feature records (read on the emulator's LuaJIT on 2026-10-15). Implement `%.14g` with
     `toPrecision(14)`, trailing zeros and point stripped, exponent as `e+NN`/`e-NN` with at least two
     digits, exponential form exactly when C's `%g` would choose it (exponent < -4 or >= 14), `-0` as `-0`.
2. **`studio/src/core/validators.ts`**: a port of `Settings.validators` and its helpers
   (`kopanda.koplugin/settings.lua:16-204`) over the value model, keyed by type, each `(entry, value) =>
   boolean`, never throwing. `entry` is the schema key from `studio/src/schema.ts`.
3. **`spec/fixtures/studio/validator_cases.lua`**: `return { { key = "<id>", value = <literal>, valid =
   true|false, why = "<short reason>" }, ... }`, written by hand in the reader's subset. At least: each
   choice key with each choice and an unlisted string and a number; the boolean with `true`, `false`, `1`
   and `"true"`; `layout.rows` with the default, an empty table, a sparse list (`{ [1] = …, [3] = … }`), a
   keyed table, a row of four, a share of 0, 4 and 1.5, a slot with an extra field, a repeated widget, an
   unknown widget; `weather.location` with the default, an extra field, an empty name, latitude 91 and
   longitude -181, a string coordinate; `featured.pinned` with `false`, `true`, `"/a"`, `"/"`, `"a/b"`;
   `launcher.entries` with the default, an empty list, seven entries, each kind valid and with a field
   missing or extra, an empty string field, a folder inside a folder, an empty folder, a screen target
   outside the schema's, a relative and a root directory path, an unknown kind.
4. **`studio/src/server/settings-file.ts`**:
   - `readSettings(path)` → `{ exists, state, reason?, schemaVersion, values, invalid, unknown, stored }`
     by the feature's "The file's states" table and per-key rules. `schema_version` absent or `false` is 1;
     a number above `schema.version` is `read_only` (1.5 included, as `settings.lua:265` reads it); any other non-1 value is `unreadable`.
   - `writeSetting(path, key, value)`: refuses a key outside the schema, a value its validator refuses, a
     read-only or unreadable file; otherwise re-reads the file, sets the key and `schema_version`
     (`settings.lua:331`), `mkdir -p` the directory, writes `serialize(data, path)` to
     `<path>.tmp-<pid>-<random>` in the same directory, renames it over `path`, and returns
     `readSettings(path)`. A failure removes the temporary file and leaves the original.
   - A per-path queue so writes to one file run one at a time.
5. **`studio/src/server/routes/settings.ts`**: `GET /api/profiles/:id/settings` and
   `PUT /api/profiles/:id/settings/:key` as the feature's "The settings API", on the profiles router,
   resolving the profile through `getProfile` (so an id is never joined into a path unchecked,
   `studio-shell/tasks/profiles/task.md:56-57`). Errors through `HttpError`.
6. **The round-trip fixture** `spec/fixtures/studio/settings_written.lua`: the writer's output for a data
   set held in `studio/test/core/settings-written.test.ts` (every key valid and not its default but
   `quote.source`; an unknown key `["studio.note"] = { 3, [10] = true, x = "y" }`; a directory entry
   label with `"`, `\`, a newline, a tab and "Café “quoted”"; a location of 47.60621, -122.33207), header
   `/mnt/us/koreader/settings/kopanda/settings.lua`. With `KOPANDA_UPDATE_GOLDENS=1` the test writes the
   file instead of comparing, as the goldens do (`.env.example`); add that use to the variable's comment
   and to AGENTS.md's Commands line for it.
7. **`spec/unit/studio_settings_file_spec.lua`** and **`spec/unit/studio_validators_spec.lua`** (below).

## Surfaces

- `studio/src/core/lua.ts`, `studio/src/core/validators.ts` (new)
- `studio/src/server/settings-file.ts`, `studio/src/server/routes/settings.ts` (new);
  `studio/src/server/routes/profiles.ts` or `app.ts` to mount it
- `spec/fixtures/studio/validator_cases.lua`, `spec/fixtures/studio/settings_written.lua` (new)
- `spec/unit/studio_settings_file_spec.lua`, `spec/unit/studio_validators_spec.lua` (new)
- `studio/test/core/lua.test.ts`, `studio/test/core/validators.test.ts`,
  `studio/test/core/settings-written.test.ts`, `studio/test/server/settings.test.ts` (new)
- `.env.example` (the `KOPANDA_UPDATE_GOLDENS` comment), `AGENTS.md` (its Commands line)

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `studio/test/core/lua.test.ts` (C3): parse round trips of every `%q` case the feature lists (`\0131`,
  `\9`, backslash-newline, `\0`, `\127`, UTF-8 passed through), `%.14g` numbers (`0.3`, `1e-05`, `1e+15`,
  `9.007199254741e+15`, `-0`, `41.85003`), nested tables, number and string keys, `Name =` and
  positional fields, comments; a list, a keyed table and a sparse table stay apart; each of an
  expression, a call, `nil`, `inf`, a long string, two values and an unterminated string is unreadable
  with its line and column; `serialize` orders `{ [10]=…, [2]=…, b=…, a=…, [1]=… }` as orderedPairs does
  (numbers 1, 2, 10, then strings), and an empty table is `{}`.
- `studio/test/core/validators.test.ts` (C2, C3): every case of `validator_cases.lua`, read with
  `parse`, gets its verdict, the message naming the case's `why`; and `schema.version` is 1, failing with
  "the studio reads only files at the schema's version: port migrations.lua's steps before raising it".
- `spec/unit/studio_validators_spec.lua` (C2): every case's verdict from `Settings.validators[entry.type]`.
- `studio/test/core/settings-written.test.ts` (C1): `serialize(data, header)` equals the fixture's bytes.
- `spec/unit/studio_settings_file_spec.lua` (C1): `LuaSettings:open(<tmp>)`, `:reset(dofile(fixture))`,
  `:flush()`; the written bytes with their first line replaced by the fixture's equal the fixture. Then the
  fixture copied to `harness.settings_file` (`spec/plugin_harness.lua:19`) with `Settings._reset()`:
  `Settings.get` of every schema key deep-equals the fixture's value, and differs from the default for
  every key but `quote.source`.
- `studio/test/server/settings.test.ts` (C4), supertest over a temp profiles directory: a missing file;
  valid, refused and unknown keys; `schema_version` 2 and 1.5 (read-only), 0, 0.5 and `"1"` (unreadable); a file
  with `os.exit()` (unreadable, line and column); a PUT of each kind of refusal leaving the bytes
  identical; a PUT writing one key, keeping an unknown key and a refused value of another key as they
  were, stamping `schema_version`, creating `settings/kopanda/`, leaving no `.tmp-` file; two PUTs
  started together both present after; the answer equals a following GET.
- Confirm `npm --prefix studio test -- test/core/lua.test.ts` runs only that file, and `bin/check
  spec/unit/studio_validators_spec.lua` only that spec (the scope the bindings assume).

## Edge cases

- A file the device wrote names a device path in its header; the reader ignores comments, and the next
  studio write names the Mac path. The device rewrites its own on its next flush.
- `-0`: LuaJIT writes `-0`; JavaScript's `String(-0)` is `"0"`, so the writer checks `Object.is(v, -0)`.
- A number with more than 14 significant digits loses them on write, as on the device (`%.14g`); a place
  from Open-Meteo has five or six decimals.
- A string with bytes that aren't UTF-8 (only a hand edit could make one) makes the file unreadable rather
  than mangling it on the next write.
- A repeated key in a hand-written file: the last wins, as `dofile` does.
- The `.old` the device keeps is never read or written; a profile directory holding one is unchanged.
- `PUT` with a value equal to the stored one still writes; the form doesn't send one.
