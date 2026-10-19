# Lean-down plan (2026-10-19)

Owner's direction: make KoPanda smaller, leaner and easier to change. Approved on 2026-10-19, to run after the
Frosted look lands on `main`. Each item is its own commit; `bin/check --unit` per item, the full `bin/check` once
before each merge to `main`. No goldens anywhere (see AGENTS.md, Testing).

## Approved items, in order

1. **One base look.** `kopanda.koplugin/looks/base.lua` holds every token path with shared defaults (spacing, type
   sizes, every feature switched off). Each look file declares only what differs; `Looks.get` deep-merges; the
   parity test becomes "a look may only set a path the base has". Expected: five 900-line tables to about 900 plus
   100 to 250 per look. Opus.
2. **`spec/unit/looks_spec.lua` to rules only** (about 1,834 lines to 300): keep paths-exist, palette roles valid,
   colours by role, grey equal channels; drop every "give X the boards' values" pin (lines 326-1610 at the time of
   the survey). Opus, same agent as item 1.
3. **Merge the duplicated spec suites** (about 1,000 lines): Series/Authors in `failsafe_spec` (1773-1960 copies
   1584-1772), `shelf_lifecycle_spec` (271-505 mirrors 63-270), `authors_screen_spec` with `series_screen_spec`
   (+ `shelf_gestures_spec`); the library window in `library_lifecycle_spec`, `library_screen_spec`,
   `library_gestures_spec`; `library_sheets_spec` with `folder_sheet_spec`; `book_sheet_spec` 1086-1480 re-tests
   rows tested at 356-520; `sheet_spec` 561-595 repeats `failsafe_spec` 287-352. Table-driven, coverage kept. Opus.
4. **One shared helpers module** (about 300 lines of plugin plus their per-copy tests): `scaler`/`colorer`
   (library_tiles, shelf_rows, widgets/featured), `Fill:paintTo` (library_chrome, featured), `Box:paintTo`
   (featured_cover, swatch, quote, featured), `count_text` (5 modules), `books_text` (4), `inside(rect, pos)` (3),
   `guarded` (9; `guards.lua` can absorb), `note` (7), `settle` (6). Opus.
5. **Trim HOOKS.md** (about 600 lines): merge the menu sections 722-827 (6 to 1) and UIManager 115-150 (4 to 1);
   fold the per-scenario harness sections 2315-2495 into a table; move plugin-only notes (looks 855, quote 903,
   home rows 919, launcher 1431, support modules 2122) into code comments. Sonnet, last, after item 4 moves code.
6. **Process rules**: done, commit `29ad01d6` "docs: leaner process rules" (local on main, not yet pushed).

Items 1+2, 3 and 4 run as three parallel agents on separate worktrees off `main` (they touch different files);
item 5 after they land. Agents never spawn subagents.

## Survey the plan rests on (Sonnet, read-only, 2026-10-19)

## 1. Specs that mirror implementation
| File | Lines | a/b/c (est.) | Delete ranges | Saved |
|---|---|---|---|---|
| looks_spec.lua | 1834 | 36/54/2 | 326-1275 ("give X the boards' values"), 1276-1610 (Riso/Toybox pins, "comments every value"). Keep 103-325 and 1611-1834. | ~1,285 |
| sheet_spec.lua | 1677 | ~68/12/6 | 64-220 geometry pins, 522-560 chip type roles, 595-637 hint position, 924-952 night band; 561-595 repeats failsafe 287-352 | ~290 |
| book_sheet_spec.lua | 1489 | ~58/4/6 | 525-560 header cover size; 1086-1480 re-tests rows tested at 356-520 (parametrise) | ~200 |
| failsafe_spec.lua | 2223 | ~95/0/18 | 1773-1960 Authors copies 1584-1772 Series (loop); 320-352 duplicates sheet_spec | ~230 |
| shelf_lifecycle_spec.lua | 963 | ~29/0/12 | 271-505 Authors mirrors 63-270 Series (table-driven) | ~200 |
| swatch_spec.lua | 947 | ~30/8/3 | 400-545 content pins, 508 vs 595 duplicate, 703-845 lacks-text | ~190 |
Total ~2,400 (5% of 48.8k). Other >400-line files: likely pins: title_bar 893, featured_widget 873, shelf_rows 704, library_tiles 771, nav_bar 730, quick_settings 774, launcher_widget 891, home_layout 627, layout 626, icons 414, quote 523. Keep (behaviour): push_apply 916, push_pull 728, release_source 517, settings 645, reading_stats 903, weather 772, library_order 730, cloud_download 694, studio_menu 568. Merge pairs: authors_screen 752 + series_screen 631 (+ shelf_gestures 602); library_lifecycle 789 + library_screen 650 + library_gestures 474; library_sheets 808 + folder_sheet 439.

## 2. Tokens nothing reads (931 leaves in diner.lua; script scratchpad/chk.py, leaves.txt)
chip.small_caps, label.small_caps, stroke.hairline_grey, editor.header_text_color (~20 lines over 5 looks). Everything else is read, directly or by built name. The "identical paths in every look" spec (looks_spec 112-199) forces the copying.

## 3. Plugin modules over 400 lines
looks/* 890-926 each: one thing, copied; ~90 `type` entries each with flags mostly equal to a default (a defaults table saves ~150/look). library_chrome 796: box helpers + header + pager + Window class (move Window out). shelf_rows 615: re-declares scaler/colorer/line_height/new_box/Box (also in widgets/featured, library_tiles). push_apply 601: keep. main 519: show_* trio thin. widgets/featured 516: own Fill/Box/scaler/colorer. title_bar 501. books 495: listing + sidecar progress (split). swatch 492: dev screen, could be cut with swatch_spec 947 + capture spec + HOOKS 165-200 + scenario. sheet_layout 489, book_sheet 482, edit_layout 481, quick_settings 461, launcher_manage 457, editor 451: one thing each; edit_layout/launcher_manage/editor repeat note, scale, color_of, free_all, row_height.
Duplicated helpers: scaler/colorer (3 modules); Fill:paintTo (2); Box:paintTo (4); count_text (5); books_text (4); inside(rect,pos) (3); guarded (9; guards.lua could absorb); note (7); settle (6). A shared helpers module: ~200 lines of plugin plus per-copy tests.

## 4. HOOKS.md (2,596 lines, 101 sections)
0 citations of plugin files that are gone; 7 Module.fn names are KOReader internals. Mergeable: menu sections 722-827 (6→1), UIManager 115-150 (4→1), harness/scenario sections 2176-2596 (~420 lines, fold into a table), plugin-owned sections (looks 855, quote 903, home rows 919, launcher 1431, support modules 2122: ~400 lines to code comments). ~200 lines saved by merging, 2-3 h.

## 5. Process weight in AGENTS.md
| Rule | Buys | Relax to |
|---|---|---|
| Questions, plan, approval before code | no wrong-direction work | plan only for features |
| One question at a time | clarity | batch related questions |
| Opus everywhere; full review with 5 mutations, hand repros, re-check for device code | catches device/file bugs | full review only for push_* and file handling |
| Fresh fixer, fresh re-checker | no context bleed | resume the builder for small fixes |
| TDD no exceptions | regressions caught | no new test for pure token/layout-number changes |
| Golden rules in Testing | already dropped | remove leftover wording |
| file:line citations in every spec | no false facts | HOOKS.md only |
| full bin/check per feature | catches paint budget regressions | --unit per task, full gate at merge to main |
| "Ready to commit and push?" + summary | owner control | push only needs approval |
| Tiller sequence | traceability | dropped for plugin fixes already |
| parallel agents + independent reviewer | speed, independence | single agent under ~150 changed lines |
| 500/1000-line signals | module size | apply to specs too |

## Ranked top 10 (lines saved per hour)
1. looks_spec 326-1610 drop pins: 1,285 / 1.5 h
2. sheet_spec b-tests: 290 / 0.75 h
3. swatch_spec pins: 190 / 0.5 h
4. failsafe Authors merged with Series: 190 / 0.75 h
5. shelf_lifecycle Authors merged: 200 / 1 h
6. book_sheet record rows merged: 200 / 1.25 h
7. HOOKS.md merges: 200 / 1.5 h
8. authors_screen/series_screen merge: ~250 / 2 h
9. shared helpers module + per-copy tests: ~300 / 3 h
10. unread tokens: 20 / 0.25 h
Not ranked: type defaults table in looks (~600 lines, 4-6 h; superseded by the base-look refactor).
