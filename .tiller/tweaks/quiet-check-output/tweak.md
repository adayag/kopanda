# bin/check prints a summary per stage instead of per-test and FFI chatter

## What

Make `bin/check`'s default output short: one line per stage, one line per spec file with its test count,
the failures in full, and the final counts. Hide KOReader's debug-build `ffi/loadlib` lines (`has
monolibtic?`, the dlopen candidate list, `ffi.findlib`, `ffi.load`, `lib_search_path`) and Busted's
per-test `[ RUN ]` / `[ OK ]` lines unless `--verbose` is passed. Keep the full Busted output in
`--verbose` for debugging a single spec.

## Why

Every gate run prints about 60 lines of library-loading chatter plus two lines per test (26 tests and
rising). The agents that run the gate re-read that output on every turn, so each run costs tokens out
of proportion to its information. The lead and the reviewers already filter it by hand with a `grep -v`
noted in `AGENTS.md`; the script should do it once.

## Done when

- `bin/check` on a green tree prints under 20 lines: the `KOPANDA_KO_HOME=` line, `== lint`, the luacheck
  total, `== unit` and `== emulator` with one line per spec file and its test count, and the final
  PASSED counts.
- A failing test still prints Busted's failure block in full.
- `bin/check --verbose ...` prints what today's `bin/check` prints.
- `spec/unit/check_spec.lua` asserts the quiet shape (line count and the absence of `ffi.findlib`) and
  the verbose shape; the existing assertions still pass.
- The `grep -v` recipe is removed from `AGENTS.md` Commands.
