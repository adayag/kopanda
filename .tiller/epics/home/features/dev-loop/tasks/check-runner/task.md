# bin/check runs luacheck and Busted specs on the emulator's LuaJIT under a fresh KO_HOME

## Approach

Build the gate command and the unit-spec layer, then prove them with two specs and wire Tiller's gates.

1. **`bin/check`** (bash, `set -euo pipefail`). Resolve `KOPANDA_ROOT` from the script's own location and
   `KOPANDA_EMULATOR` from the environment, defaulting to
   `$HOME/Projects/kodev/koreader/koreader-emulator-arm64-apple-darwin23.5.0-debug/koreader`. Modes:
   - no arguments: `lint`, then `unit` (every `spec/unit/*_spec.lua`), then `emulator` (every
     `spec/emulator/*_spec.lua`); stop at the first failing stage.
   - `--lint`: luacheck alone.
   - one or more paths: run exactly those spec files through the Busted runner, no luacheck. Paths are
     made absolute before the script changes into the emulator directory.
   Preflight: `luacheck` on `PATH` (else print `brew install luacheck` and exit 2) and
   `$KOPANDA_EMULATOR/luajit` present (else name the path and the variable, exit 2). Every stage's
   non-zero status is normalised to exit 1 (`run_stage || exit 1`): Busted exits with the count of
   failures plus errors (`busted/runner.lua:224–225`), which would otherwise collide with the refusal
   code 2.
2. **Busted invocation**, copied in shape from KOReader's `runtests_busted` (`base/test-runner/runtests`,
   the `cmd` array): `cd "$KOPANDA_EMULATOR"`, then
   `./luajit -e 'require "busted.runner" {standalone = false}' /dev/null --output=gtest --sort-files
   --helper=<repo>/spec/helper.lua --loaders=lua --lazy -- <spec files>` with
   `LUA_PATH='?.lua;common/?.lua;frontend/?.lua;spec/front/unit/?.lua;spec/rocks/share/lua/5.1/?.lua;spec/rocks/share/lua/5.1/?/init.lua;<repo>/spec/?.lua;<repo>/kopanda.koplugin/?.lua'`
   and `LUA_CPATH='?.so;common/?.so;spec/rocks/lib/lua/5.1/?.so'`. `spec/front/unit/?.lua` is where
   the emulator install holds KOReader's `commonrequire.lua`. No `--config-file` and no `--run`
   (`--run` names a configuration inside a config file, `busted/modules/cli.lua:138, 193–207`, and is
   ignored without one; KOReader passes `--config-file=spec/config.lua`, `base/test-runner/runtests:124`): spec files are passed as
   positional roots, which Busted 2.3.0 accepts as files (`busted/modules/test_file_loader.lua:17–19`),
   and `--helper` takes an absolute `.lua` path (`busted/modules/helper_loader.lua:15`). Busted paths
   are under the emulator's `spec/rocks/share/lua/5.1/`.
3. **Fresh `KO_HOME`**: `mktemp -d` per invocation, exported, removed by an `EXIT` trap. The script
   prints the path on a `KOPANDA_KO_HOME=` line so `check_spec` can assert it is gone afterwards.
4. **`spec/helper.lua`**: KOReader's `base/test-runner/busted_helper.lua` verbatim in function (make
   `KO_HOME`, preload Busted modules, strip `spec/rocks/` from `package.path`/`cpath` so a spec never
   requires a rock by accident, `require("ffi/loadlib")`), with the repo paths kept.
5. **`.luacheckrc`**: `std = "luajit"`, `self = false`, globals `G_reader_settings`, `G_defaults`;
   `files["spec/**"].std = "+busted"`; `max_line_length = 120`; `unused_args = false` as KOReader. No
   `ignore` list.
6. **`.tiller/tiller.yml`**: uncomment and set
   `build: { kind: command, run: "bin/check --lint", on: [feature, task] }` and
   `tests: { kind: command, run: "bin/check", on: [feature, task] }`.
7. **`.env.example`** at the repo root documenting `KOPANDA_EMULATOR` (and, ahead of golden-compare,
   nothing else). `AGENTS.md` Commands section: `bin/check`, `bin/check --lint`, `bin/check <spec>...`.

## Surfaces

- `bin/check` (new)
- `spec/helper.lua` (new)
- `spec/unit/environment_spec.lua`, `spec/unit/check_spec.lua` (new)
- `spec/fixtures/failing_spec.lua`, `spec/fixtures/lint-warning.lua` (new; inputs for `check_spec`,
  excluded from the lint stage by living under `spec/fixtures/` and listed in `.luacheckrc`'s
  `exclude_files`)
- `.luacheckrc`, `.env.example` (new)
- `.tiller/tiller.yml` (gates), `AGENTS.md` (Commands)

## Tests

Written first, each run and seen failing before its implementation.

- `spec/unit/environment_spec.lua`: `require("commonrequire")` succeeds; `require("luasettings")` and
  `require("ui/widget/container/widgetcontainer")` load;
  `os.getenv("KO_HOME")` is set, is a directory, is not `KOPANDA_EMULATOR` and not under the repo;
  `package.path` carries the repo's `spec/?.lua` and `kopanda.koplugin/?.lua`; `package.path` does not
  carry `spec/rocks/`.
- `spec/unit/check_spec.lua` shells out to `bin/check` with `io.popen` (through `sh -c '...; echo;
  echo $?'`, so the status is on its own line after a newline whatever the command printed last, since
  LuaJIT's `os.execute` return differs across platforms):
  - `bin/check spec/fixtures/failing_spec.lua`, a fixture with two failing tests, exits 1 (not 2: proves
    the normalisation of Busted's failure count) and the output names both failing tests.
  - `bin/check spec/unit/environment_spec.lua` exits 0 and its output does not contain `luacheck`
    (targeted runs skip lint).
  - the `KOPANDA_KO_HOME=` path printed by a run does not exist after it.
  - `KOPANDA_EMULATOR=/nonexistent bin/check --lint` exits 2 and names `/nonexistent`.
  - `bin/check --lint` run from a temporary copy of the repo root with `spec/fixtures/lint-warning.lua`
    moved into `spec/unit/` exits 1 and names that file (proves the lint stage fails the gate).
- Scope check for the contract: run `bin/check spec/unit/check_spec.lua` and confirm the output lists
  only that spec's tests, so the ref-only bindings in `feature.eval.md` resolve as intended.

## Edge cases

- `luacheck` missing: refusal with the brew command, exit 2, before anything else runs.
- Spaces in paths: every path quoted; the repo lives under `~/Projects/elatedpanda/kopanda` but the
  script must not assume it.
- A spec that crashes LuaJIT (segfault in an FFI call): the `EXIT` trap still removes `KO_HOME`; the
  stage's non-zero status propagates.
- `check_spec` runs `bin/check` from inside a `bin/check` run; the inner run gets its own `KO_HOME` and
  must not remove the outer one (each trap removes only the directory it made).
- The emulator folder contains `settings.reader.lua` from interactive use; nothing in a spec run reads
  it because `KO_HOME` points elsewhere. `environment_spec` asserts `G_reader_settings` is under
  `KO_HOME`.
- GNU vs BSD tools: the script uses only bash builtins, `mktemp`, `find` and `sort` with POSIX flags;
  no `timeout`, no `env -C`, no `getopt`.
