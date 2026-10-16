# KoPanda

The owner's own interface for KOReader e-readers: a plugin that replaces the shell (home screen first, then navigation bar, bars, library) and a desktop studio that edits the same settings the plugin's on-device menus edit, from one schema. Owner-only; not published.

- **Stack:** Lua on KOReader's LuaJIT (the plugin, `kopanda.koplugin/`); TypeScript on Node >=22 with Express, React 19, Vite and Vitest (the studio, `studio/`, from stage 2). No database.
- **Deployed:** nowhere. The plugin runs on the Kindle and in the emulator at `~/Projects/kodev/`; the studio runs locally.
- **Status:** run `tiller status`. Design inputs live under `.tiller/design/`: read `2026-10-13-kopanda-design.md` for the decisions, principles and stages, and `handoff-2026-10-08.md` §3–4 for device and emulator facts.

## Principles

- **Few settings, strong defaults.** The default look is the owner's. A settings key enters the schema only when the owner has wanted to change that thing on a real device, and each feature spec justifies each key it adds. Don't propose SimpleUI-style per-element options.
- **Context-aware interactions.** Tap acts; hold opens a menu for the thing held, whose actions depend on what it is. Behaviour adapts to context so settings don't have to.
- **E-ink rules.** The screen redraws only on input. No background timers, no animations.
- **Every hook into KOReader is wrapped** so a failure leaves KOReader's own file browser usable.
- **One schema.** No settings key exists outside `kopanda.koplugin/schema.lua`; the device menus and the studio form are both generated from it.

## Emulator, devices and references

- The KOReader emulator lives at `~/Projects/kodev/` (build `e1fe1ac`, 2026-10-08). Never vendor KOReader here. Rebuild is `./kodev build` in `~/Projects/kodev/koreader/` (~7 min). KOReader is pinned to that build; upgrading it is a deliberate chore that reruns the goldens and walks `kopanda.koplugin/HOOKS.md`.
- Headless capture: `~/Projects/kodev/capture.sh <out.png> [library] [delay]`, 1264×1680 in ~10 s. Screen env vars, `KO_HOME` profiles, the Retina window quirk and the fonts path are in the handoff §3. Don't rediscover them.
- A plugin folder present in both the emulator's `plugins/` and `<KO_HOME>/plugins/` loads twice. Tests copy the plugin into a scratch profile, so the emulator's own `plugins/` must not hold `kopanda.koplugin`.
- Primary device: Kindle Colorsoft SE, 1264×1680 @ 300 DPI, colour. USB is MTP-only and single-session; see handoff §4 before pushing.
- Reference plugins are read-only and cloned into a scratch folder, never committed: ennUI (no licence: read, don't copy), SimpleUI (MIT: pieces may be lifted with their notice), ZenOS (GPL-3.0: read, don't copy; copying makes KoPanda GPL). KOReader is AGPL-3.0.
- `kopanda.koplugin/HOOKS.md` lists every KOReader internal the plugin reads or patches with the `file:line` it was read from.

## Commands

- `bin/check`: the gate. luacheck, then every `spec/unit/*_spec.lua`, then every `spec/emulator/*_spec.lua` on the emulator's LuaJIT under a fresh `KO_HOME`; stops at the first failing stage.
- `bin/check --lint`: luacheck alone (Tiller's build gate).
- `bin/check <spec>...`: exactly those spec files, no luacheck.
- `bin/check --verbose ...`: combines with any mode above. By default each stage prints only luacheck's total or Busted's suite summary, plus each file with a failing test and that test's output in full; `--verbose` prints luacheck's per-file lines, Busted's per-test lines and KOReader's library-loading chatter.
- `bin/schema-json`: prints `kopanda.koplugin/schema.lua` as JSON with sorted keys on stdout (the studio's build input), through the emulator's LuaJIT and bundled `rapidjson`; refuses with exit 2 without a luajit at `KOPANDA_EMULATOR`.
- `KOPANDA_UPDATE_GOLDENS=1 bin/check <spec>`: writes that spec's captures as its goldens under `spec/goldens/` (PNG plus JSON sidecar; masks and notes in an existing sidecar are kept). Open every regenerated PNG and look at it before committing.

`bin/check` needs `luacheck` on `PATH` (`brew install luacheck`) and the emulator at `KOPANDA_EMULATOR` (see `.env.example`); it refuses with exit 2 otherwise.

## Conventions and gotchas

- Lua: KOReader's style (4-space indent, `local` everything, modules return a table). Widgets are small tables: `id`, `build(width, ctx)`, `height(ctx)`, settings prefix.
- The schema is pure data, no functions, so a LuaJIT one-liner can dump it to JSON for the studio.
- Settings live in `settings/kopanda/settings.lua` through KOReader's `LuaSettings`; reads fall back to the schema default, writes to undefined keys are refused.
- Runtime state (the boot guard flag, one-time migration markers) lives in `settings/kopanda/state.lua` through `LuaSettings`; it is not a setting, has no schema entry, and the studio never reads or writes it.
- Out of scope, don't re-suggest: context-aware looks (per-book themes, time rules), the CWNG library folder, the Xteink X4 Pro, publishing the plugin, translations.
- Open requirement questions live in Tiller (`tiller queue --kind answer_question`). Ask them one at a time.

## Testing

- TDD, no exceptions: write the failing test first, run it, implement, run again. Every behaviour change ships with a test.
- Two layers: Busted unit specs on KOReader's LuaJIT under a fresh `KO_HOME` for the pure parts; emulator goldens at Colorsoft resolution, status strip masked, regenerated only deliberately and eyeballed before commit.
- Emulator captures run on the fixture library `spec/fixtures/library/` (three public-domain EPUBs with covers) unless a spec passes its own `library_dir`. To add a book: a public-domain EPUB under 2 MB with an embedded cover, plus a `manifest.lua` entry whose `sha256` is `shasum -a 256 <file>`; `spec/unit/fixtures_spec.lua` checks the count of three, so change it with the book.

<!-- shared-workflow-start -->
## Working with agents

### Before changing anything
- Ask clarifying questions, then present a plan and get approval before writing code. Never assume requirements or make architectural decisions without explicit consent.
- Offer 2–3 approaches with trade-offs when a real decision is needed. Break large tasks into small, reviewable steps.
- Ask one question at a time. Do the homework first: read the relevant code and docs, check how similar things are done here, then ask the one thing only the user can decide.

### While working
- Make the minimal change that accomplishes the task. Don't refactor unrelated code; mention issues you notice outside scope instead of fixing them.
- Stop and ask when something unexpected comes up: an edge case the plan didn't cover, a conflicting pattern, a missing dependency or env var, a security concern, or any ambiguity. Don't decide silently to keep moving.
- No TODO comments — do it or ask. No commented-out example code.
- New or changed env var: document it in `.env.example` here AND tell the user that `~/Projects/strem` (compose service, `.env.example`, `.env.enc`) needs the same change.
- Changing a health-check endpoint, port, or image name breaks strem's compose until strem is updated — same rule.

### Code
- YAGNI, especially before adding a dependency or an abstraction. Prefer the simple solution; simple doesn't equal clever.
- Write idiomatic code for the language at hand; don't invent patterns or conventions the ecosystem doesn't use.
- Tests must prove correctness — no tests that merely mirror the implementation.
- Don't use deprecated or undocumented APIs.
- A file passing 500 lines is a signal to plan decomposition; at 1000, do it.

### Subagents
- Run every subagent on Opus; keep an independent reviewer. Run subagents in parallel whenever the dependency order allows. Brief an agent with the full task text and the verified facts and a short checklist, and tell it to read `bin/check` output through a filter that drops KOReader's library-loading chatter and the per-test lines, so its transcript stays small.
- One agent, one job, one transcript. A fix round is a fresh agent briefed with the review's findings, the task plan and the diff, never a resume of the builder; a re-check is a fresh agent briefed with the review report and the fix diff, never a resume of the reviewer. A resumed agent re-reads everything it did before.
- One reviewer per task, covering spec compliance and code quality in one brief. Review depth follows what the change touches. Code that runs on the device or handles files from outside (the plugin, the studio's push and bundle handling, anything that reads a file it didn't write) gets the full review: mutation checks capped at the five riskiest, hand reproductions of the paths the review suspects, and a re-check after the fix unless the fixer re-ran those mutations itself and reported them. A pure refactor with an existing test net gets one review pass that traces behavior old against new, with no mutation pass and no re-check. Everything else gets one review with mutation checks and a re-check only for a security finding.
- A reviewer's report ends with a numbered fix list the lead can paste into the fixer's brief: file:line, what's wrong, the fix, the test that proves it. The fixer writes each test first and reports it failing before the fix.
- A gate that fails on a test outside the task's surfaces is rerun for that file alone; if it passes, the gate is rerun once and the flaky test is queued as a tweak, named in the evidence commit.

### Before committing
- Self-review every change against the plan: unintended side effects, missing tests, missing docs.
- Present a summary of the changes and a proposed commit message, then ask: "Ready to commit and push?" Never commit without approval.
- `git add <specific files>`, never `git add -A`.
- Work on `main`. Never force-push. Never include AI attribution (Claude, Anthropic, Co-Authored-By) in commits.
<!-- shared-workflow-end -->

## Project additions

- Specs: every concrete claim about code outside this repo (a KOReader or reference-plugin file, function, key, default, value list or format) cites the `file:line` it was read from, at the pinned commit. An uncheckable claim is marked as an assumption, and the task that depends on it verifies it first.
- Under Tiller, a `tiller start` or execute instruction covers the whole publication sequence: commit, `tiller check`, push, open the PR, `tiller submit`, commit and push the state. Don't stop to ask before committing; stop at the owner's decisions (PR review and merge, attestation, approval). Task work reaches `main` through a PR the owner merges; `.tiller/`-only state commits go straight to `main`.
- Under Tiller, one session carries a feature from start through submission and post-merge closeout. When a draft PR awaits attestation, stop for the owner's decision, then continue in the same session once they report it.
- Hand the owner each `tiller attest` command prefixed with `cd <the aggregate's worktree> &&`, so the attestation lands on the review branch beside the gate evidence. Attesting in the primary checkout writes it to `main`, and merging that into the aggregate conflicts in `feature.yml`.

<!-- tiller:begin (managed by `tiller join`; edits inside are overwritten) -->
## Tiller

This project uses Tiller to run its SDLC workflow. Specs, decomposition, planning, and acceptance gates live in `.tiller/`, under git, beside the code they describe.

One hard rule: drive work to the edge of done and stop. You may propose, build, attach evidence, run gates, and open PRs. Authorized execution includes creating task branches and merging them into the recorded feature or epic aggregate, never into the configured integration branch. A gate is the human's decision, not the human's keyboard: run `approve` only on an explicit human instruction naming the nodes. You never attest a human gate and never cross work to done, even on instruction; the final integration merge is the human's, and Tiller records the crossing from it.

PRs are for code: a change that touches only `.tiller/` commits directly, with no pull request.

Read `.tiller/orientation.md` for the full rules and how to work. Run `tiller status` before each session to see where things stand.
<!-- tiller:end -->
