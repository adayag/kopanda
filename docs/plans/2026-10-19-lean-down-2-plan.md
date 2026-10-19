# Lean-down 2 plan (2026-10-19)

> **For Claude:** run with superpowers:subagent-driven-development, one Opus builder per agent below on its own
> worktree off `main`; review per AGENTS.md (full review for A); the lead runs the full `bin/check` once per
> merge. Agents never spawn subagents.

Approved by the owner on 2026-10-19; not started. It folds in the spec lean-down plan (wave 3), which this
file replaces.

Second size review of the plugin (four read-only Opus reviewers, one per area). Plugin 21,150 Lua lines,
specs ~55k, studio ~13k. Owner's decisions on 2026-10-19: keep a plugin-only dev pull and drop the rest of
the LAN push; delete the swatch; stop restyling KOReader's file browser. Each item below is its own commit;
`bin/check --unit` per item, the full `bin/check` once before each merge to `main`. No goldens.

Expected: about 3,000 plugin lines and about 5,000 spec and studio lines removed by waves 1-2, then about
4,000 to 6,000 more spec lines by wave 3. Code deletions go first so wave 3 doesn't tidy specs that wave 1
or 2 deletes.

## Wave 1 (three parallel agents, separate worktrees off `main`)

### A. Update path: dev pull only (full review: push and bundle path)

- Delete Address and Profile, profile lists, studio download, settings push, the `plugins_disabled`
  set/restore and `Guards.enabled_shell_names` (studio_menu.lua:44-180, :250-272; push_pull.lua:19-26,
  :157-176, :227-266; guards.lua:57-67; push_apply.lua:182-199, :236-240, :258-277, :320-359, :414-424,
  :449-470; push_bundle.lua:87-113; push_notice.lua:25-44).
- Keep Check for update, probation and rollback. Keep a dev pull: the studio serves `bin/bundle`'s output
  over the LAN and the device installs it through `ReleaseSource.source{manifest_url, zip_url}` (~60 lines),
  so a working-tree build still reaches the Kindle without a merge. `studio_address` stays in state.
- Studio: drop profiles-as-devices from the push (routes/push.ts, PushStatus.tsx, bundle.ts `readSettings`,
  settings branch of `buildBundle`); keep profiles as screen-plus-settings pairs for preview and fit. Keep
  `lan-guard.ts` only if the dev pull still needs it.
- `push_bundle.sha256_file` and `bundle_hash` (spec-only) move to a spec helper.
- Specs: drop the settings and disable cases (push_apply_spec, push_pull_spec, studio_menu_spec,
  guards_spec); delete push_pull_spec :331-430, :481-503 (repeats push_bundle_spec :134-395); point the
  emulator push spec at a release-shaped zip and drop the ennUI switch-over fixture.
- `.env.example`: remove or rename `KOPANDA_PUSH_*`/`KOPANDA_STUDIO_HOST` as the dev pull needs; tell the
  owner `~/Projects/strem` needs the same change.
- Owner check before merge: the Kindle reports a real version (not `0.0.0-dev`) under Check for update.

### B. Deletions: swatch and the file-browser restyle

- **Step 0, report before deleting:** list every path on which KOReader's file manager is visible with
  neither the home nor the library over it (main.lua:178-203, :366; launcher_entries.lua:204-211; book
  close; failure fallbacks). If any is normal use rather than a fallback, stop and report to the lead.
- Swatch: swatch.lua, main.lua:23, :110, :410-421, :483, spec/unit/swatch_spec.lua,
  spec/emulator/swatch_capture_spec.lua, the swatch scenario, HOOKS.md :149-188. Drop item 4 of the spec
  lean-down (wave 3) needs no swatch decision any more.
- File browser: title_bar.lua, fm_nav.lua, main.lua:9, :84, :135, menu.lua:56, nav_bar's `file_browser`
  place, their specs and HOOKS.md sections. Directory launcher entries open `Library.show{dir}`. Keep
  `title_bar.count_on_shelf` (library_view, series, authors and helpers read it); delete the other
  `title_bar` tokens and type styles from base and every look.

### C. Library and sheets cleanup

- Delete `Books.add_source` and the `record.path` guards it forces (books.lua:17, :143-178 and the guards
  the review listed); the scenarios use a cloud_books placeholder instead.
- One `Shelf` base on `LibraryChrome.Window` for Series and Authors (~130), with
  `LibraryChrome.empty_note`.
- `Paint.box(w, h, fields)` and `Paint.place` replace the ~9 hand-built `FeaturedCover.Box` setups and
  `fixed()`; one download-badge builder for library_tiles and shelf_rows.
- `SheetLayout.build`: drop outputs only specs read (header, hint, header_parts, per-row rects), lay out at
  origin so the move pass goes, use `Looks.colorer`/`Paint.scaler`, then split into named local functions.
- library_chrome `tools()` and `settle` call the helpers directly; `Library.on_picker` becomes a direct
  call; one return slot instead of two; library_order keeps one in-memory table and trims `stored()`'s
  validation; library_sheets uses `Guards.guarded`; `cover_state` shares `BookCovers.wants`.

## Wave 2 (after wave 1 lands; two parallel agents)

### D. Home and editing cleanup (uses `Paint.box` from C)

- Home: delete the dead footer (layout.lua:114-120, :227, :276-288; home_rows.lua:72-87; base and diner
  tokens), the unread `label` group, `chip.small_caps/uppercase/text_color`, `stroke.hairline_grey`,
  `editor.header_text_color`, `home.header.align`; drop widget `id`/`settings_prefix`; drop icons
  `used_in` and set metadata; `Layout.fits` and spec-only `arranged` fields; widgets.lua registry;
  featured_cover's spec-only functions; `Typeset.face`/`Typeset.box` for the 4 copies; `Paint.fill`/
  `Paint.blit`; home.lua uses `PaintClock.settled` and `Guards.guarded`.
- Editing: `Editor.kit` shared by edit_layout and launcher_manage; one canvas widget for editor `Frame`,
  quick_settings `Body`, sheet_layout `Panel`; `Looks.colorer` and one `Typeset.recolored` for the copies;
  `util.tableEquals` for `same`/`State.same` (push_apply's copy stays); `Settings.entry(id)`; optional
  fallback on `Guards.guarded` (menu.lua:24-34); edit_layout measures overflow each time; the small
  wrappers.
- Settings: delete the migration runner and the newer-version guard (schema v1 has no steps), the
  `menu_tab_shifted` migration, `quote.source` and `stats.show` (studio settings-file.ts and the
  round-trip fixture follow).

### E. Emulator spec consolidation

- One table-driven capture spec for quick_settings, sheet, nav, screens and library_placeholder captures;
  one shared scenario frame for the four scenarios that repeat it.

## Wave 3: spec lean-down (after wave 2 lands)

The unit suite keeps every behaviour it proves and loses lines, so a plugin change drags less spec with it.
No plugin code changes. At the time of writing `spec/unit/` was 48,134 lines in 101 files, 2,175 `it` blocks
at 22 lines each, 10,997 lines of per-file setup before the first `it`; re-measure after wave 2. Busted on the
emulator's LuaJIT (`bin/check <spec>`, `--verbose` for per-test lines); spec helpers load through `require`
on `spec/?.lua` (`spec/plugin_harness.lua`, `spec/shelf_fixture.lua`, `spec/shelf_screen_cases.lua` are the
models).

### Rules for every wave 3 item

- A test goes only when it is a pin (asserts a look's value the look table already states), a duplicate
  (another test fails for the same break) or folded into a table row that still fails for its break.
- Test names keep their variant ("series: …", "diner: …"). A `.tiller/**/feature.eval.md` binds tests by file
  path (`grep -rn "_spec.lua" .tiller --include=*.md`); a bound file keeps its name.
- Before touching a file, save its test names: `bin/check --verbose spec/unit/<x>_spec.lua 2>&1 | grep "^\[ *OK" > before.txt`;
  after, diff against the same for the new file. Every removed name is listed in the commit message with
  its reason (pin, duplicate, folded into `<name>`).
- `bash -c 'bin/check --unit; echo EXIT $?'` green per item (zsh shell; quiet output); luacheck clean.
- Don't touch `.tiller/`, `kopanda.koplugin/`, `spec/emulator/`, or `looks_spec.lua`.
- Commits: one per file or file pair, plain messages, no AI attribution, `git add` by name.

### F. One spec support module (about 600 to 900 lines)

Create `spec/support.lua`; modify the spec files that define each helper
(`grep -ln "^\s*local function <name>(" spec/unit/*_spec.lua`). The same local helpers are typed by hand in
file after file: `read` (22 files), `write` (19), `rgb` (14), `pixel` (14), `tap` (13), `scale` (12), `walk`
(11), `run` (10), `ctx_for` (10), `painted` (9), `near` (9), `find` (9), `cleanup` (9), `book` (9), `texts`
(8). Their copies total about 1,262 lines, so moving every copy saves at most ~1,050. Not every copy is the
same function: `rgb` is both "hex to {r,g,b}" and "sample an image buffer at x,y"; `pixel` is both "sample a
Blitbuffer at x,y" and a synthetic pattern for a PNG test.

1. For each name, group the copies by shape (`grep -h -A6 "^\s*local function <name>(" spec/unit/*_spec.lua`).
   A shape shared by three or more files moves into `spec/support.lua` under a name that says what it does
   (`hex_rgb`, `sample_rgb`, `read_file`, `write_file`, `tap_at`, `walk_widgets`, `find_widget`, `texts_of`,
   `near`, `ctx_for`). A shape used by one or two files stays where it is.
2. Write `spec/unit/support_spec.lua` first: one `it` per shared helper proving its behaviour at the edges the
   copies' own tests touched (an empty widget tree, a missing file, a hex with upper-case digits, a tolerance
   of 0). Run it failing, write the module, run it passing.
3. Replace the copies one file at a time: delete the local, `local S = require("support")`, call `S.<name>`.
   Run that spec. Commit per three to five files: `tests: <files> use spec/support`.
4. `ctx_for` (a paint ctx for a look, variant and screen) and `book` (a fixture record) carry the most
   set-up; if their shapes differ by one field, the shared one takes an `opts` table rather than keeping ten
   copies.
5. Leave the `require` preambles alone; a one-line `require` is cheaper than a harness field.

`support.lua` stays under 200 lines; every spec file still reads alone.

### G. Rules, not values, in the widget specs (about 3,000 lines)

Files (those wave 1-2 leave standing): `launcher_widget_spec.lua`, `featured_widget_spec.lua`,
`quick_settings_spec.lua`, `library_tiles_spec.lua`, `nav_bar_spec.lua`, `shelf_rows_spec.lua`,
`home_layout_spec.lua`, `layout_spec.lua`, `quote_spec.lua`. (`title_bar_spec.lua` goes with B.)

The pattern that goes: a test that builds a widget in Diner, then asserts the face is Bricolage 800, the
size 22, the colour the ink. The look table states those values; the test only proves the widget read the
table, and it breaks on every design change. What stays, as one `it` over every look id: the widget reads
its face, size and colour from the token path the plugin names (break the token in a scratch copy of the
look and the assertion must fail), and the rules the widget keeps regardless of look (a count of zero draws
no badge; a title too wide gets an ellipsis; the lit tab is the current screen).

Per file: list each `it` and tag it pin, rule or behaviour; for a pin, write the rule it hides (if any) once
over `Looks.ids()`; delete the pins; keep every behaviour test; run, diff the names, commit
`tests: <x>_spec states rules, not values`.

### H. Table-driven bodies in the longest files (about 1,500 to 2,500 lines)

Files: `failsafe_spec.lua`, `sheet_spec.lua`, `book_sheet_spec.lua`, `shelf_lifecycle_spec.lua`,
`reading_stats_spec.lua`, `library_sheets_spec.lua`, `library_lifecycle_spec.lua`, `weather_spec.lua`,
`library_order_spec.lua`. `failsafe_spec`'s 85 tests each break a different hook and its Series/Authors
blocks are already table-shaped, so expect little there.

These are behaviour tests, kept in full; what changes is the shape. A block of `it`s that each build the
same fixture, poke one thing and assert one result becomes one table of rows and one `it` per row with the
row's name (the model: `spec/shelf_screen_cases.lua`).

Per file: find runs of three or more `it`s whose bodies differ only in inputs and expected values; write the
rows table with a `name` per row that keeps the old test name; one `it(row.name, …)` in a `for` loop; a
row's one difference (an extra assertion only one case needs) goes in a row field, never dropped; run, diff
the names (one for one), commit `tests: <x>_spec rows`. Stop at 600 lines per file or when the remaining
`it`s don't share a shape.

G and H touch disjoint files and run as two agents in parallel after F lands. Floor with coverage unchanged:
about 40,000 to 41,000 unit lines from today's 48,134, less what waves 1-2 delete. Below that is a choice to
cover less.

## Order and sizing

| Wave | Agent | Lines out | Time |
|---|---|---|---|
| 1 | A update path (full review) | ~2,300 (plugin, spec, studio) | 1-1.5 h |
| 1 | B swatch and file-browser restyle | ~3,750 | 45 min |
| 1 | C library and sheets | ~630 plugin + specs | 1 h |
| 2 | D home and editing | ~700 plugin + specs | 1 h |
| 2 | E emulator specs | ~300 | 30 min |
| 3 | F spec support module | 600-900 | 1.5 h |
| 3 | G rules not values, after F | ~3,000 | 2 h |
| 3 | H table-driven, after F, parallel with G | 1,500-2,500 | 2 h |

## Not in this plan

- One cover-arrival path for the library (−120, full-page repaint on e-ink), the quote and stats caches
  (−75 to −110, paint budget): later, each with a paint-budget check.
- Frosted's plate/wallpaper (~300) and Riso's misregister (~90): per-look cost, kept.
- `main.lua` loads modules under generic names (`settings`, `menu`, `layout`, `paint`) into the shared
  `package.loaded`; a later plugin requiring one of those names gets KoPanda's. Separate decision.
