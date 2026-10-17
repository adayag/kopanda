# Task gates run the unit layers; the emulator layer runs at the feature check

## What

- `bin/check` gains a mode that runs luacheck, the studio's check and every `spec/unit/*_spec.lua`, and stops
  before `spec/emulator/`. Today it has only all, `--lint` and named specs (`bin/check:5-9`, `:151-160`). The
  mode stays a plain project command that never calls Tiller.
- `.tiller/tiller.yml`'s required gates split the tests gate:
  - task-level tests run the new mode;
  - feature-level tests keep the whole `bin/check`.
  
  Today one `tests` gate runs `bin/check` `on: [feature, task]`.
- `AGENTS.md`'s Commands section documents the mode. It also says that a task touching emulator goldens or
  the paint budget still runs its named emulator specs, as the goldens tasks do.

## Why

Owner decision, 2026-10-17. Every task's `tiller check` runs the full `bin/check`, about 5 minutes, of which
the emulator layer is about 1-2. A feature of six tasks ran it at least seven times. Emulator specs mostly
guard goldens that only a few tasks touch, and the feature check still runs them all before the PR.
Tradeoff accepted: a task that breaks a golden it didn't plan to touch is caught at the feature check, not at
its own gate.

## Done when

- `tiller check task` on a task runs lint, studio and unit specs, and no `spec/emulator/` file.
- `tiller check feature` still runs the whole `bin/check`.
- The new `bin/check` mode refuses and fails as the other modes do: exit 2 without luacheck, node or
  `studio/node_modules`; the first failing stage stops it.
- `AGENTS.md` documents the mode and when a task still runs emulator specs.
