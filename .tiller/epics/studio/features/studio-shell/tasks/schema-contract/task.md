# Checked-in schema JSON, its npm regeneration and the equality spec

## Approach

1. `studio/package.json` gains `"schema": "../bin/schema-json > src/schema.json.tmp && mv
   src/schema.json.tmp src/schema.json"`, so a refused run (exit 2, no emulator) leaves the checked-in
   file alone; run it and commit `studio/src/schema.json`. The file lives under `src/` because the
   server tsconfig's `rootDir` is `src` (theme studio `tsconfig.server.json:9`) and settings-form's
   server code will import it. `bin/schema-json` resolves the repo root from `$0`, so it runs from
   `studio/` (`bin/schema-json:8`).
2. `spec/unit/studio_schema_spec.lua`: run `bin/schema-json` the way `spec/unit/schema_json_spec.lua`
   does (`:17-24`), read `studio/src/schema.json`, and assert the two are byte-identical. On a mismatch
   the failure message says `studio/src/schema.json is stale: run npm run schema in studio/`.
3. `studio/src/schema.ts`: the TypeScript shape of the schema, a zod schema plus its inferred type,
   built from `kopanda.koplugin/schema.lua:6-118`: `{ version: number, keys: Key[] }`, `Key` a
   discriminated union on `type` over the types the schema uses today (`choice`, `rows`, `location`,
   `boolean`, `path`, `launcher`), each with the fields that type carries (choices for `choice`;
   widgets and max_columns for `rows`; max_entries and targets for `launcher`; read each from the
   file, not from this list). Export the parsed checked-in file as `schema`, loaded with a JSON import
   (`with { type: "json" }` under NodeNext) so the build carries it and nothing runs LuaJIT. The JSON
   import's inferred type widens `type` to `string`, so the zod parse, not the type checker, is what
   catches an undeclared key type.

## Surfaces

- `studio/package.json`, `studio/src/schema.json`, `studio/src/schema.ts`
- `spec/unit/studio_schema_spec.lua`, `studio/test/schema.test.ts`

## Tests

- `spec/unit/studio_schema_spec.lua` (C1): passes on the regenerated file; a second case writes a
  copy of the schema JSON with an extra key into a temp file, points the comparison at it through the
  spec's own helper, and asserts the failure message names `npm run schema`. Do not edit the real
  `schema.lua` or `studio/src/schema.json` in the test.
- `studio/test/schema.test.ts` (C6): the zod schema parses `studio/src/schema.json`; a copy with one
  key's `type` changed to an undeclared type fails to parse, naming that key's index.

## Edge cases

- rapidjson prints floats at full precision (the default location's coordinates); byte comparison is
  against the same encoder, so this is stable.
- A Lua empty table would encode as `{}`; the schema has none today. If a later key adds one, the zod
  schema decides how it is read.
- Resolve paths from `KOPANDA_ROOT`, which `bin/check` exports (`bin/check:14`), so the spec runs the
  same from any working directory.
