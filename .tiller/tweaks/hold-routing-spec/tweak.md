# Move the hold cases out of gesture_routing_spec.lua

## What

Move the `holds` describe block of `spec/unit/gesture_routing_spec.lua` (from `:425`, about 290 lines)
into its own `spec/unit/hold_routing_spec.lua`, sharing the file's setup helpers, with no case added,
removed or changed. The file was 797 lines on 2026-10-16, after `home/sheets` (F-3ct1xn) added the hold
cases.

## Why

AGENTS.md treats a file past 500 lines as the signal to plan decomposition. The `home/sheets` reviewer of
`home/sheets/hold-and-home-sheet` (T-odbt4w) advised doing it after the feature closed, because that
feature's C3 and C11 bound to `gesture_routing_spec.lua` by name while it was open.

## Done when

- `gesture_routing_spec.lua` and `hold_routing_spec.lua` are each under 500 lines.
- The two files together run exactly the cases the one file ran, all passing.
- `bin/check` is green.
