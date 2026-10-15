# bin/check gains the studio's typecheck, lint and tests

## Approach

1. In `bin/check`'s no-argument path only (`bin/check:73-76`), add a `run_studio` stage between
   `run_lint` and `run_layer unit`: print `== studio`, then `npm --prefix "$KOPANDA_ROOT/studio" run
   check`. Its failure exits 1 before the unit layer starts.
2. Before running the stages in that path, refuse with exit 2 through the existing `refuse()`
   (`bin/check:16-19`), in the luacheck refusal's style (`bin/check:21-23`):
   - `node` not on `PATH`: the reason, then the indented fix lines `    brew install node` and
     `    npm ci --prefix studio`;
   - `$KOPANDA_ROOT/studio/node_modules` not a directory: the reason, then `    npm ci --prefix studio`.

   The top-level refusals (luacheck, luajit) stay where they are and keep their order, so `--lint`
   and named-spec runs never look for node. The temp-tree cases (`check_spec.lua:64-83`) copy no
   `studio/`; the cases at `:27-62` run in the real root, which will hold `studio/`, and stay safe
   because they use named-spec or `--lint` mode.
3. `.luacheckrc`: add `studio/node_modules/**` and `studio/dist/**` to `exclude_files` (today only
   `spec/fixtures/**`, `.luacheckrc:12-14`), since `luacheck .` runs from the repo root
   (`bin/check:36`).
4. Update the header comment in `bin/check` and the `bin/check` line in `AGENTS.md` Commands to name
   the studio stage; add the node and `npm ci --prefix studio` prerequisite beside the luacheck one
   there, saying that every checkout and worktree, an aggregate's included, needs `npm ci --prefix
   studio` before `tiller check` or `tiller eval`.

## Surfaces

- `bin/check`, `.luacheckrc`, `AGENTS.md`
- `spec/unit/check_spec.lua`

## Tests

Extend `spec/unit/check_spec.lua` (C7), in its existing style of copying `bin/`, `spec/` and
`.luacheckrc` into a temp tree:

- A temp tree with `studio/package.json` whose `check` script prints a marker and exits 1, and an
  empty `studio/node_modules/`: `bin/check` exits 1, output has `== studio` and the marker, and no
  `== unit`.
- The same tree without `studio/node_modules/`: exit 2, stderr names `npm ci --prefix studio`.
- With `PATH` holding luacheck but no `node`: exit 2, stderr names `brew install node` and
  `npm ci --prefix studio`. Build that `PATH` as a temp dir holding a symlink to
  `/opt/homebrew/bin/luacheck` (its wrapper uses absolute paths) plus `/usr/bin:/bin`. The node first
  on the owner's `PATH` is nvm's and `/opt/homebrew/bin` holds one too, so neither directory may be
  on it.
- A `.lua` file with a lint error under the temp tree's `studio/node_modules/`, and one under
  `studio/dist/`, does not fail lint.
- C10: a named-spec run in the copied temp tree (no `studio/`) with that node-less `PATH` exits 0.

The existing tests (C10) run unchanged and still pass.

## Edge cases

- The lint stage in the temp tree must still pass for the studio tests to reach `== studio`; the
  existing lint-failure test shows the copied tree lints clean.
- The new tests must not run the real studio check (slow, and recursive through `bin/check`); the fake
  `package.json` keeps them fast.
- npm prints its own banner lines; the stage passes them through rather than filtering.
