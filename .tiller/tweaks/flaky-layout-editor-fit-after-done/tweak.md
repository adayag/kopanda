# The layout editor's fit-after-Done test fails intermittently in a full bin/check

## What

`studio/test/ui/layout-editor.test.tsx:471-484`, "ignores a fit answer that arrives after Done, and
writes nothing", failed once at its final `expect(puts()).toEqual([])` (line 483) during a full
`bin/check` on branch `tiller/nav-bar/nav-bar/bar` (2026-10-16, commit `a526e97`, a change with no studio
code in it). It passed when the file ran alone, and the rerun of the whole gate passed. The test waits a
single `setTimeout(0)` after resolving the deferred fit answer, so a write the editor schedules later than
one macrotask under a loaded full run may land inside the assertion window, or a write from an earlier
test may still be counted by `puts()`. Which of these it is has not been shown.

Find the cause: run the studio stage repeatedly (or the file under load) until it fails, look at what
`puts()` holds, and fix the source: the test's wait, the fetch stub's reset between tests, or the
editor's handling of a fit answer after Done. Do not mask it with a retry.

## Why

`bin/check` is the gate for every task and feature. A flaky test turns green work red, so it gets rerun
and its result trusted less.

## Done when

The cause is named with evidence, and `npm --prefix studio run check` passes 20 consecutive runs, with the
test still asserting that no write follows a fit answer that arrives after Done.
