# Swatch settled signal can fire before its first paint

Found while fixing the same race in the home (studio/device-push/apply-and-rollback (T-o5gnzj),
commit d7f6787 on `tiller/studio/device-push/apply-and-rollback`). Not reproduced on the swatch
itself; the code path is the one proven racy in the home.

## Reproduction

`Swatch.show` (`kopanda.koplugin/swatch.lua:402-411` on `main`) schedules `settle` with
`UIManager:tickAfterNext`, and the comment says that "lands past the next repaint". At KOReader
`e1fe1ac` it doesn't always: `tickAfterNext` re-queues through `nextTick`
(`frontend/ui/uimanager.lua:447-456`), `scheduleIn` stamps the task with `time.now()` (`:413-418`),
and `_checkTasks` samples `_now` once and runs every task due at or before it in the same pass
(`:1081-1104`), which `handleInput` runs before `_repaint` (`:1537-1564`). When the inner task's
`time.now()` falls in the same clock tick as `_now`, `settle` runs before the swatch's first
`paintTo`. `time.now` is `monotonic_coarse` (`frontend/ui/time.lua:182-199`, `:300`), so a coarser
clock makes the collision more likely.

For the home, a spec that held the clock still made the race fail 3 of 3 runs; unheld it failed about
1 run in 4. The swatch's equivalent: show the swatch with `time.now` held, tick, and record whether
`KoPandaSettled` arrives with `swatch.painted_at` still nil.

## Expected

The `KoPandaSettled` signal for `screen = "swatch"` is sent once, after the swatch's first
successful paint, and never for a paint that failed. That is what the comment at `swatch.lua:383`
promises and what the capture driver waits for (`spec/emulator/driver.lua:3`, `:225`).

## Actual

`settle` (`swatch.lua:384-398`) only checks `paint_failed`. When it runs before the paint it sends the
signal with `painted_at` nil, reports `paint_ms` as 0 (`(swatch.painted_at or now) - swatch.started`)
and lets a capture shoot a screen the swatch hasn't drawn yet. It can also send the signal for a paint
that fails afterwards.

## Fixed when

- A unit spec that holds `time.now` still shows the swatch and asserts `KoPandaSettled` arrives only
  after the first paint, with a real `paint_ms`. It fails on the current code.
- A paint that throws sends no settled signal, with the clock held.
- The swatch settles the way the home now does (after its first paint, from the next tick), or the way
  `editor.lua:278-292` does (wait for the paint when the tick finds none). It is not left to
  `tickAfterNext` alone.
- `bin/check` is green, and the swatch goldens are unchanged.
