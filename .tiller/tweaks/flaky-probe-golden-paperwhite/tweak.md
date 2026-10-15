# The probe golden on paperwhite fails intermittently in a full bin/check

## What

`spec/emulator/golden_spec.lua:56`, "matches the committed probe golden on paperwhite", failed once
during a full `bin/check` on branch `tiller/home/home-layout/goldens-and-budget` (2026-10-15, commit
`fda430c`). The same file passed 9/9 when run alone, and two later full runs passed 26/26 emulator
tests. The output filter in use dropped the failure message, so the pixel difference and the failing
assertion (`checked.ok` or a capture error) are not known. The task's tests gate failed once on the same
branch and passed when rerun, which was most likely this test (recorded in the T-ltupc3 evidence commit).

Find the cause: run the full emulator stage repeatedly until it fails, keep the
`spec/.artifacts/goldens/probe-paperwhite.*` capture and diff, and fix the source of the
nondeterminism (the probe plugin, the paperwhite profile, or the capture timing). Do not mask it.

## Why

`bin/check` is the gate for every task and feature. A flaky golden turns green work red, so it gets
rerun and its result trusted less.

## Done when

The cause is named with evidence, and the full `bin/check` passes 20 consecutive runs with the probe
golden's masks unchanged (or the flake is shown to come from somewhere else, and that is fixed instead).
