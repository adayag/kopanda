# Split home.lua past the 500-line signal

## What

Split `kopanda.koplugin/home.lua` into smaller modules along its existing seams, with no behaviour
change. It was 548 lines on 2026-10-15, before `home/night-mode` (F-4jh8sz) adds about 15 more for the
rebuild-on-variant-change check.

## Why

AGENTS.md says a file past 500 lines is the signal to plan decomposition. The owner chose on 2026-10-15
to keep the night-mode diff small and split the file separately.

## Done when

- `home.lua` and every module split out of it are each under 500 lines.
- No settings key, hook or behaviour changes: every existing unit spec and emulator golden passes
  unchanged, and none is regenerated.
- `kopanda.koplugin/HOOKS.md` still names each KOReader internal at its new module and line.
- `bin/check` is green.
