# Probe golden on colorsoft captures a blank screen under tiller check

## What

`spec/emulator/golden_spec.lua:56`, "matches the committed probe golden on colorsoft", failed in two
consecutive `tiller check task T-xem8p9` runs on branch `tiller/home/night-mode/palette` (2026-10-15,
commits `d7a8e25` and `92ea06e`): 0.88 % of pixels differ, and the actual capture is a blank white screen,
shot before the probe fixture plugin painted. The probe doesn't load KoPanda. On the same branch, plain
`bin/check` passed twice in a row, and `main` passed twice too. The gate evidence files
`artifacts/tiller/gates/tests-d7a8e25-out-*.txt` and `tests-92ea06e-out-*.txt` on that branch hold the
full output. It looks like the same race as `tweaks/flaky-probe-golden-paperwhite`, which might share
its cause.

## Why

The tests gate must be deterministic. A capture that can shoot before the first paint makes every gate
run a coin toss, and it hides real golden regressions behind reruns.

## Done when

- The cause is named: why the shot can land before the probe's paint, and why running under `tiller check`
  makes it more likely.
- The capture waits for the probe's paint, and a test fails on the old timing.
- Five consecutive `tiller check` runs of the tests gate pass with no probe golden failure.
