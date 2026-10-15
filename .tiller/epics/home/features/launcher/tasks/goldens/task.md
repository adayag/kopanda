# Home goldens with the launcher row, the missing plugin and the height budget

## Approach

The home goldens and budgets with the launcher row in the default layout. Repo lines are on `main` at
`bfb043c`; the goldens and the fixture userpatch are as `featured-book`'s `goldens` task leaves them
(`featured-book/tasks/goldens/task.md`).

1. **Open fact first: do Diner's five default rows fit both profiles?**
   - The rows: the header band, the featured row (a 210 px cover box plus its 6 px shadow,
     `featured-book/feature.md` "The widget", Geometry), the quote tile, two 104 px tile rows with a 14 px gap and the
     4 px shadow, and the strip, with 22 px row gaps (`looks/diner.lua` `home.row_gap`) and the footer
     stripe. They have never been measured together.
   - If they overflow, the row engine drops the last row (the strip) and logs "home row N doesn't fit the
     screen and is left out" (`layout.lua:115`).
   - **How it is measured:** in a scratch run of the populated Diner capture on each profile, log each
     row's height and the space left, from `Layout.arrange`'s `heights` and `dropped`
     (`layout.lua:212-214`). Then make the check permanent: `home_golden_spec.lua` asserts that no
     capture's log contains "doesn't fit the screen" (the driver returns the log path, `driver.capture`'s
     `log`, as `home_capture_spec.lua` reads it).
   - **If it fits** on both profiles, record the margin in the PR.
   - **If it doesn't fit**, stop and report to the owner with the measured heights. Don't commit goldens
     with a dropped row, and don't pick a fix alone. The candidates are:
     - (a) a shorter Diner `launcher.tile_height`;
     - (b) a smaller Diner `home.row_gap`;
     - (c) a shorter featured cover box;
     - (d) a different default layout for one look.

     Each changes a token or the default the owner looks at.

   Editorial (two rows of about 53 px under a 28 px gap) is checked by the same assertion.
2. **Fixture userpatch** (`spec/emulator/scenarios/2-scenario-home-fixture.lua`).
   - The `empty` scenario writes `launcher.entries` into `settings/kopanda/settings.lua`, next to the
     look, with `LuaSettings` and `schema_version` 1, as it writes `look` (`:48-56`). The value is the
     default five without Settings, then
     `{ kind = "plugin", plugin = "kopanda_absent", action = "terminal", label = "Terminal", icon = "terminal" }`.
     That is the EmptyStates board's launcher (EmptyStates:46-71).
     - Since `look` may be unset for Diner, the patch opens the file once and saves whichever keys apply.
     - No plugin is named `kopanda_absent`, so `PluginLoader:isPluginLoaded` is false in every profile.
       This needs no driver option: the driver's disabled list is fixed (`spec/emulator/driver.lua:18`,
       `:104-111`), and a real plugin's presence would vary with the emulator's untracked plugins.
   - The `populated` scenario writes no launcher entries, so it shows the default six.
   - The header comment lists the new write.
3. **`spec/emulator/home_golden_spec.lua`:**
   - regenerate every `home-*` golden `featured-book` commits: populated ×4, empty ×2 and typecover ×2;
   - add `home-empty-diner-paperwhite` and `home-empty-editorial-paperwhite` to the scenario list
     (`home_golden_spec.lua:14-21`);
   - add the no-dropped-row assertion of step 1 to every scenario;
   - generate with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/home_golden_spec.lua`;
   - open every PNG next to its board (Main, HomeRetro, PWEditorial, PWRetro, EmptyStates).

   The PR lists every difference that is on purpose:
   - "Wi-Fi off" on every golden (the fake Wi‑Fi is off, `driver.lua:80`, `:109`);
   - `muted` in place of the board's `#a09d94`;
   - Diner's suffix line and greyed tile (no board);
   - Editorial's 28 px gap above the launcher against the board's 10;
   - the Paperwhite boards' smaller tiles not kept;
   - icons at stroke 2 against the boards' 1.6;
   - the launcher placed before the strip in Diner (the direction doc's order, not HomeRetro's).
4. **Budgets.** `spec/emulator/home_capture_spec.lua` keeps `paint_ms <= 250` on each profile, with the
   launcher row. `spec/emulator/book_close_spec.lua` runs as is, and its 100 ms share must still hold.
   - If either bound fails, report the measured number and the slow part rather than raise the bound.
   - To find the slow part, time the six SVG renders and masks, the `getDisplayList` calls and the `lfs`
     stats in a scratch run.

## Surfaces

`spec/emulator/scenarios/2-scenario-home-fixture.lua`, `spec/emulator/home_golden_spec.lua`,
`spec/goldens/home-*.png` and `.json` (eight regenerated, two new); `HOOKS.md` harness section for the
fixture's settings write. `spec/emulator/home_capture_spec.lua` and `book_close_spec.lua` change only if
the measurement in step 1 needs a hook there.

## Tests

- `home_golden_spec.lua` (C8): fails first on the eight changed goldens and the two missing ones. Then the
  goldens are generated, eyeballed and committed, and a second plain run passes. The no-dropped-row
  assertion fails first only if a row is dropped. Run it once with a deliberately tall stub row in a
  scratch layout to prove the assertion can fail.
- Determinism: two consecutive plain runs pass with empty masks.
- `home_capture_spec.lua` (C9) and `book_close_spec.lua` (C10) pass unchanged in their assertions.

## Edge cases

- Diner's grey palette shows only on the Paperwhite profile. The new empty pair is the one place the
  greyed tile is seen in grey.
- The empty scenario's stored list is valid by `entries`' validator, or it would read as the default six
  and the golden would show Settings. The golden itself proves the entry was read.
- If `featured-book`'s goldens task changed the driver (an `extra_disabled` option or a cover-cache seed),
  this task uses the driver as it is and adds nothing to it.
