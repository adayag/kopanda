# The layout-fit timeout test reads sleep-pid before a loaded host has written it

## What

`studio/test/server/layout-fit.test.ts:72-84`, "answers unchecked when it doesn't answer in time, the process
and its children stopped", failed once during a full `bin/check` in the library/context-menu/folder-sheet
(T-id5xlc) worktree on 2026-10-17 with ENOENT reading `sleep-pid` (`:82`). The file passed alone (15/15) and the
gate passed on its rerun. The fixture `studio/test/fixtures/layout-fit/slow.sh:3-5` writes its sleeper's pid to
`$KOPANDA_FAKE_FIT_DIR/sleep-pid` only once it runs; the check's 200 ms timeout (`:78`) can stop the script
before that line on a loaded host, so the test reads a file that was never written.

## Why

A flaky test in the tests gate fails `bin/check` and `tiller check` on work that never touched the studio, and
costs a rerun of a five-minute gate each time.

## Done when

The test no longer depends on the fixture reaching its pid line within the timeout (for example it waits for
the pid file, or treats a missing file as a sleeper never started), still proves that a timed-out fit stops
the process and its children, and passes repeatedly under a loaded host, such as alongside a full
`bin/check` in another worktree.
