# Seven board icons in the registry, the swatch's fourth icon row and the regenerated catalog

## Approach

The icons the three library sheets draw, and their fallout. No other task's code is needed; it can start at
once. Repo lines on `main` at `5d8a955`. Feature decision D4, criteria C2, C13, C16.

1. **Seven SVG files** under `kopanda.koplugin/icons/`, each in the set's form (`icons/home.svg`: a 24×24
   viewBox, `fill="none"`, `stroke="#000000"`, width 2, round caps and joins; black because NanoSVG turns
   `currentColor` grey, `icons.lua:4-8`), each path copied from its board:
   - `home_plus.svg`: `M3 11l9-8 9 8v10H3z` and `M12 10v6M9 13h6` (HoldBookC:66);
   - `trash.svg`: `M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3` (HoldBookC:70);
   - `folder_open.svg`: `M3 6h6l2 2h10v11H3z` and `M10 13h6M13 10l3 3-3 3` (HoldFolderC:45);
   - `eye_off.svg`: the path at HoldFolderC:56, read whole from the board file;
   - `sort.svg`: `M7 4v16M3 16l4 4 4-4M14 6h7M14 11h5M14 16h3` (HoldEmptyC:44);
   - `filter.svg`: `M4 5h16l-6 8v6l-4-2v-4z` (HoldEmptyC:51);
   - `refresh.svg`: `M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5` (HoldEmptyC:57).
   Open fact: whether any of these is a Lucide glyph as drawn (the set's Lucide files carry an ISC comment in
   the registry, `icons.lua:38`, `:57-73`). Compare each path with Lucide's file of the same shape at the
   version the set came from (`icons/LICENSE-lucide.txt`); a path that matches gets the comment, one that
   doesn't is the canvas's own, like `home` and `folder`, and gets none.
2. **`icons.lua`:** seven entries after `download` (`icons.lua:70-73`), each with a label and `used_in`
   ("book sheet" for `home_plus` and `trash`; "library folder sheet" for `folder_open` and `eye_off`;
   "library sheet" for `sort`, `filter`, `refresh` and `eye_off`). `library` gains "library folder sheet" in
   its `used_in` (`icons.lua:15-16`), since Set as library root draws it (HoldFolderC:49).
3. **The swatch's fourth row.** The icon grid wraps by the widest id (`swatch.lua:257-299`): every cell is
   as wide as the widest id, so 38 icons take a fourth row, or a different count if a new id such as
   `folder_open` is wider than today's widest; the panels take what the header and icons leave
   (`swatch.lua:341-346`). The row count is this step's measurement, not a target. Measure first: run
   `swatch_spec.lua`'s fit cases (`spec/unit/swatch_spec.lua:371`, `:440-471`) with the seven icons in.
   If every panel's content still fits at the Colorsoft and the Paperwhite, nothing else changes. If Diner's
   panels overflow, as they did at 31 (cover-grid tiles task.md:49-54), bring the measured heights to the lead
   before changing any constant: the owner chose a fourth row (D4), so cramming 38 into three rows by the gap
   is not the fix, and the candidates (`ROW_GAP`, `ICON_LABEL_SIZE`, `ICON`, `swatch.lua:32-44`) each change
   what the swatch shows.
4. **The catalog:** `npm run catalog` in `studio/` rewrites `studio/src/catalog.json` with the seven icons
   and their SVG text (`bin/catalog-json.lua:98-104`, `:125`); the studio's launcher icon picker offers them
   too, as cover-grid's two (cover-grid D14, feature.md:98-102).
5. **The swatch goldens:** `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/swatch_golden_spec.lua`, each
   PNG opened before commit (`open <png>`), and the seven new icons looked at against their boards.

## Surfaces

- `kopanda.koplugin/icons/{home_plus,trash,folder_open,eye_off,sort,filter,refresh}.svg` (new),
  `kopanda.koplugin/icons.lua`; `kopanda.koplugin/swatch.lua` only if step 3's measurement and the lead say
  so.
- `studio/src/catalog.json` (regenerated), `spec/goldens/swatch-colorsoft.{png,json}`,
  `spec/goldens/swatch-paperwhite.{png,json}` (regenerated).
- `spec/unit/icons_spec.lua`.

## Tests

Written first, each run failing before the code:

- `icons_spec.lua` (C2): the registered ids include the seven (`spec/unit/icons_spec.lua:36-48`, the list
  grows to 38); `home_plus` and `trash` used in the book sheet, `folder_open`, `eye_off` and `library` in the
  library folder sheet, `sort`, `filter`, `refresh` and `eye_off` in the library sheet; every file renders
  (the spec's existing render and ink cases cover the new files once they are registered).
- `swatch_spec.lua` (C2) passes: every panel's content inside its panel, and the icons on the screen, at both
  sizes.
- `studio_catalog_spec.lua` (C2) passes against the regenerated catalog.
- `swatch_golden_spec.lua` (C13) passes after the regeneration and again on a second run.
- Scope check: `bin/check spec/unit/icons_spec.lua` runs that file alone (`bin/check:153-160`); confirm the
  summary names only its cases.

## Edge cases

- `filter` and `sort` are generic names; the registry is the one module that names an icon file
  (`icons.lua:1-2`), so no collision with KOReader's own `resources/icons` names matters.
- The board's folder path (`M3 6h6l2 2h10v11H3z`, HoldFolderC:37) differs from the registry's `folder.svg`
  (`M3 6h7l2 2h9v11H3z`); `folder_open` takes the board's, and the folder box keeps the registry's `folder`.
  Say so in the PR so the owner sees both in the swatch.
- A studio test that counts the catalog's icons would change with it; none does at `5d8a955` (a search of
  `studio/src` and `studio/test` for the icon count finds none); if one exists by then, update it and say so.
