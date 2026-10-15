# The probe capture on colorsoft fails intermittently in a full bin/check

## What

`spec/emulator/capture_spec.lua:51`, "captures the probe at the colorsoft size with a settled sidecar",
failed once during a full `bin/check` on branch `tiller/home/launcher/entries` (2026-10-15, commit
`bd0a16b`). That commit changes no capture, driver or probe code. The file then passed 5/5 alone, and
the next full run passed 28/28 emulator tests. The output filter dropped the failure message, so which
assertion failed (size, `screen`, `paint_ms` or a capture error) is not known.

This is the second flaky probe test. `tweaks/flaky-probe-golden-paperwhite` (TW-4ae71f, for
`golden_spec.lua:56`) records the first. Both capture the probe plugin through `spec/emulator/driver.lua`,
so they may share a cause. Find it: run the full emulator stage repeatedly until this test fails, keep
the failing assertion and the capture's sidecar, and fix the source of the nondeterminism. Do not mask
it or retry inside the test.

## Why

`bin/check` is the gate for every task and feature. A flaky capture turns green work red, so it gets
rerun and its result trusted less.

## Done when

The failing assertion and its cause are named with evidence, and the full `bin/check` passes 20
consecutive runs. If the cause is the same as `flaky-probe-golden-paperwhite`'s, one fix closes both,
and this tweak says so.
