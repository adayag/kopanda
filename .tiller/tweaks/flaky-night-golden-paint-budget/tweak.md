# The night golden's paint budget fails intermittently in a full bin/check under load

## What

`spec/emulator/night_golden_spec.lua:85-98`, "the night goldens match a fresh capture of
home-night-editorial on colorsoft, its paper the night paper", failed once at its budget assertion
(line 98, `paint_ms <= PAINT_BUDGET_MS`, the budget 250 at line 31) with `paint_ms 330`, during a full
`bin/check` under `tiller check task T-7g6ybl` on branch `tiller/bars/quick-settings/panel` (2026-10-17,
commit `2547f79`, a change that touches neither the home nor night mode). The machine's load average was
about 90 at the time. The file passed alone (4 of 4), and the rerun of the whole gate passed. The
failed run's evidence is `artifacts/tiller/gates/tests-2547f79-out-e5d06215644ccf929bf382f797a746cb8ea300321e5055af12606c66a2daf602.txt`
on that branch.

The budget measures wall-clock time from the open to the first paint, so a loaded host can push an
honest paint past it. Decide how the budget should hold under load: measure on an idle machine to see
the real margin, then choose between a budget that holds (for example the best of several captures, or a
CPU-time measure) and a run that refuses to judge the budget when the host is loaded. Do not simply raise
the number until it passes.

## Why

`bin/check` is the gate for every task and feature. A budget that fails under load turns green work red,
so it gets rerun and its result trusted less, and the same budget guards the sheets'
(`spec/emulator/sheet_golden_spec.lua:15-18`).

## Done when

The cause is shown with measurements, and a full `bin/check` passes the night goldens' budget while the
host runs another full `bin/check` alongside, with the budget still failing a paint that is genuinely
slower than 250 ms on an idle machine.
