# Spec lean-down plan (2026-10-19)

> **For Claude:** run with superpowers:subagent-driven-development, one Opus builder per item on its own
> worktree off `main`, one reviewer per item, a fresh fixer; the lead runs the full `bin/check` once per merge.

**Goal:** the unit suite keeps every behaviour it proves today and loses about a quarter of its lines, so a
change to the plugin drags less spec with it.

**Architecture:** three passes over `spec/unit/` (48,134 lines, 101 files, 2,175 `it` blocks at 22 lines each,
10,997 lines of per-file setup before the first `it`). First the helpers every file re-types move into one
support module; then the specs that pin look values become rules; then the longest files go table-driven.
No plugin code changes. The measure of "nothing lost" is the same every time: the list of test names before
and after, and for a folded test, that it still fails for each failure the originals caught.

**Tech stack:** Busted on the emulator's LuaJIT (`bin/check <spec>`, `bin/check --verbose <spec>` for per-test
lines), luacheck. Spec helpers live in `spec/` and load through `require` on `spec/?.lua`
(`spec/plugin_harness.lua`, `spec/shelf_fixture.lua`, `spec/shelf_screen_cases.lua` are the models).

---

## Rules for every item

- A test goes only when it is a pin (asserts a look's value the look table already states), a duplicate
  (another test fails for the same break) or folded into a table row that still fails for its break.
- Test names keep their variant ("series: …", "diner: …"). A `.tiller/**/feature.eval.md` binds tests by file
  path (`grep -rn "_spec.lua" .tiller --include=*.md`); a bound file keeps its name.
- Before touching a file, save its test names: `bin/check --verbose spec/unit/<x>_spec.lua 2>&1 | grep "^\[ *OK" > before.txt`;
  after, diff against the same for the new file. Every removed name is listed in the commit message with
  its reason (pin, duplicate, folded into `<name>`).
- `bash -c 'bin/check --unit; echo EXIT $?'` green per item (zsh shell; quiet output); luacheck clean.
- Don't touch `.tiller/`, `kopanda.koplugin/`, `spec/emulator/`, or `looks_spec.lua` (done in the lean-down).
- Commits: one per file or file pair, plain messages, no AI attribution, `git add` by name.

## Item 1: one spec support module (about 2,000 to 3,000 lines)

**Files:** create `spec/support.lua`; modify the spec files that define each helper (`grep -ln "^\s*local function <name>(" spec/unit/*_spec.lua`).

The same local helpers are typed by hand in file after file: `read` (22 files), `write` (19), `rgb` (14),
`pixel` (14), `tap` (13), `scale` (12), `walk` (11), `run` (10), `ctx_for` (10), `painted` (9), `near` (9),
`find` (9), `cleanup` (9), `book` (9), `texts` (8). Not every copy is the same function: `rgb` is both
"hex to {r,g,b}" and "sample an image buffer at x,y"; `pixel` is both "sample a Blitbuffer at x,y" and a
synthetic pattern for a PNG test. So:

1. For each name, group the copies by shape (`grep -h -A6 "^\s*local function <name>(" spec/unit/*_spec.lua`).
   A shape shared by three or more files moves into `spec/support.lua` under a name that says what it does
   (`hex_rgb`, `sample_rgb`, `read_file`, `write_file`, `tap_at`, `walk_widgets`, `find_widget`, `texts_of`,
   `near`, `ctx_for`). A shape used by one or two files stays where it is.
2. Write `spec/unit/support_spec.lua` first: one `it` per shared helper proving its behaviour at the edges the
   copies' own tests touched (an empty widget tree, a missing file, a hex with upper-case digits, a tolerance
   of 0). Run it failing, write the module, run it passing.
3. Replace the copies one file at a time: delete the local, `local S = require("support")`, call `S.<name>`.
   Run that spec. Commit per three to five files: `tests: <files> use spec/support`.
4. The per-file `ctx_for` (a paint ctx for a look, variant and screen) and `book` (a fixture record) are the
   two with the most set-up around them; if their shapes agree across files, they save the most. If they
   differ by one field, give the shared one an `opts` table rather than keeping ten copies.
5. Leave the `require` preambles alone; a one-line `require` is cheaper than a harness field.

Expected: 2,000 to 3,000 lines out; `support.lua` under 200 lines; every spec file still readable alone.

## Item 2: rules, not values, in the widget specs (about 3,500 lines)

**Files:** `title_bar_spec.lua` (893), `launcher_widget_spec.lua` (891), `featured_widget_spec.lua` (873),
`quick_settings_spec.lua` (774), `library_tiles_spec.lua` (771), `nav_bar_spec.lua` (730),
`shelf_rows_spec.lua` (704), `home_layout_spec.lua` (627), `layout_spec.lua` (716), `quote_spec.lua` (523).

The pattern that goes: a test that builds a widget in Diner, then asserts the face is Bricolage 800, the
size 22, the colour the ink. The look table states those values; the test only proves the widget read the
table, and it breaks on every design change. What stays, as one `it` over every look id: the widget reads
its face, size and colour from the token path the plugin names (break the token in a scratch copy of the
look and the assertion must fail), and the rules the widget keeps regardless of look (a count of zero draws
no badge; a title too wide gets an ellipsis; the lit tab is the current screen).

Per file:
1. List each `it`; tag it pin, rule or behaviour.
2. For a pin, find the rule it hides (if any) and write that rule once over `Looks.ids()`.
3. Delete the pins. Keep every behaviour test as is.
4. Run the file, diff the names, commit: `tests: <x>_spec states rules, not values`.

Items 2 and 3 touch disjoint files and can run as two agents in parallel after item 1 lands.

## Item 3: table-driven bodies in the longest files (about 4,000 lines)

**Files:** `failsafe_spec.lua` (2,161), `sheet_spec.lua` (1,642), `book_sheet_spec.lua` (1,475),
`shelf_lifecycle_spec.lua` (920), `reading_stats_spec.lua` (903), `library_sheets_spec.lua` (808),
`library_lifecycle_spec.lua` (778), `weather_spec.lua` (772), `library_order_spec.lua` (730).

These are behaviour tests, kept in full; what changes is the shape. A block of six `it`s that each build
the same fixture, poke one thing and assert one result becomes one table of six rows and one `it` per row
with the row's name. The model is what `spec/shelf_screen_cases.lua` and the merged `failsafe_spec` already
do for Series and Authors.

Per file:
1. Find runs of three or more `it`s whose bodies differ only in inputs and expected values.
2. Write the rows table above them, with a `name` per row that keeps the old test name.
3. One `it(row.name, …)` in a `for` loop; delete the originals. A row's one difference (an extra assertion
   only one case needs) goes in a row field, never dropped.
4. Run the file, diff the names (they must match one for one), commit: `tests: <x>_spec rows`.

Stop at 600 lines per file or when the remaining `it`s don't share a shape; don't force a table on tests
that differ in what they set up.

## Item 4: `swatch_spec.lua` (947 lines), decision first

The swatch is a developer screen. If the owner cuts the swatch (`swatch.lua` 481, `swatch_capture_spec`,
the HOOKS.md rows, the scenario patch), its spec goes with it; if the swatch stays, its spec gets item 2's
pass and nothing more. Ask before touching it.

## Order and sizing

| Item | Agent | Lines out | Time |
|---|---|---|---|
| 1 support module | Opus, one | 2,000 to 3,000 | 2 h |
| 2 rules not values | Opus, one, after 1 | 3,500 | 2 h |
| 3 table-driven | Opus, one, after 1, parallel with 2 | 4,000 | 3 h |
| 4 swatch | owner's call | 0 or 947 | |

Floor with coverage unchanged: about 36,000 lines from 48,134. Below that is a choice to cover less.
