# Home cleanup (2026-11-03)

Decided on 2026-11-03 with the owner. The launcher drops to four slots that don't repeat the nav bar, so the quote
stays on the home at every text size. The home's layout becomes fixed, the swipes swap, a launcher slot can open any
plugin's menu item, and the settings menu loses what no longer does anything.

Lands after the stats window merges (`docs/plans/2026-11-03-stats-window-design.md`): that work removes
`layout.rows_2` and puts Stats on the nav bar in place of Authors.

## Decisions

| Question | Decision | What lost |
|---|---|---|
| Which bar has four slots | The launcher, editable; the nav bar stays fixed | Nav bar as four editable tabs with no launcher; four slots on both |
| Launcher default | Series, Authors, Subjects, Favorites; nothing repeats the nav bar | Keeping Library, History or Settings on both |
| Launcher shape | One row of four in Diner and Frosted; Editorial stays 2×2 | 2×2 everywhere, which pushes the launcher off Diner and Frosted on long-quote days; one row in Editorial, which cuts labels to "Aut…" |
| Launcher labels at Extra large | One size down, as the nav bar's are | Labels at full size, cut to "Favorit…" |
| Swipes | Swipe up opens quick settings, swipe down full settings | Removing swipe up and changing the Settings tab's tap |
| Top-edge tap | Follows swipe down, to full settings | Tap and swipe doing different things in one band |
| Swipe up on windows | Added, so every chrome window has it | Home only, which would leave windows no gesture for quick settings |
| Settings tab | Unchanged: tap for quick settings, hold for full settings | |
| Layout editing | Removed, on the device and in the studio | Keeping an editor for a one-page home |
| A home that doesn't fit | The quote drops first, never the launcher | Today's rule, which drops the last row, the launcher |
| Plugins with no Dispatcher action | A launcher entry can run any plugin's main-menu item | A Rakuyomi-only entry; leaving it out |
| Settings menu | Layout, Page 2, Quote source and Show reading stats go; Wallpaper shows only in Frosted; a row opens KOReader's full menu | Leaving the rows in |
| Tools › KoPanda | The Studio submenu goes; Check for update sits directly under Tools › KoPanda, beside Swatches | Check for update in the settings menu alone, which a broken home can't reach; deleting the whole studio now, which releases depend on (`bin/bundle` needs `studio/node_modules`) |

## Facts

- At Extra large with the longest quote (156 characters), 2×2 tiles drop the launcher in Diner and Frosted on the
  Colorsoft. One row of four fits with about 200 px spare in Diner. 2×2 fits in Editorial, whose rows are slim
  (captures of 2026-11-03).
- One row of four also fits both looks on the Paperwhite size, 1072×1448. `bin/preview` rendered a landscape request
  as portrait, so landscape is untested.
- Frosted's launcher icons overlap their labels at Extra large, with three columns or four (`looks/frosted.lua:210`,
  `tile_height = 74`).
- `Layout.size_at` grows the launcher's icons at Extra large; `NavBar` holds its labels at Large's size through
  `label_size` (`nav_bar.lua:45-47`).
- Diner and Frosted take `columns = 3` from `looks/base.lua:543`; Editorial sets its own (`looks/editorial.lua:200`).
- `HomeGestures.focused_top` is the shared top-edge step: a hold opens KOReader's menu, a tap or a swipe down opens
  quick settings (`home_gestures.lua:146-163`). `LibraryChrome.Window:routeGesture` calls it (`library_chrome.lua:806`).
- Swipe up is one of the home's own zones, and only the home's (`home_gestures.lua:62-71`, `:196-199`).
- `FileManager:registerModule` keeps each plugin on the file manager under its name
  (`frontend/apps/filemanager/filemanager.lua:379-383`, `:424`), and the menu builds items through each registered
  widget's `addToMainMenu` (`filemanagermenu.lua:851-852`).
- Rakuyomi registers a `rakuyomi` main-menu item and no Dispatcher action, and registers it only outside the reader
  (`frontend/rakuyomi.koplugin/main.lua`, upstream `main`). Its repository is archived.
- `kind = "plugin"` needs a Dispatcher action (`launcher_entries.lua:63-65`), and the studio mirrors its fields
  (`settings.lua:85`, `studio/src/core/validators.ts:35`).
- `SchemaMenu.items(group)` returns every row when no key has that group (`menu.lua`). With `quote.source` gone, a
  hold on the quote would open the whole menu through `settings_prefix = "quote"` (`home_gestures.lua:125-129`).
- Check for update sits inside Tools › KoPanda › Studio (`studio_menu.lua`) and in the settings menu
  (`settings_menu.lua:30-35`). Tools › KoPanda has no settings row (`main.lua:492-496`), so its Check for update is
  the way to install a fix when a release breaks the home.
- `editor.lua` stays: `launcher_manage.lua` uses it.
- The stats window's design says the Kindle's launcher has never been edited, so the new default reaches it.

## What the reader sees

- **The home.** Header, featured book, quote, launcher, at every text size.
- **The launcher.** Four slots. A hold still opens launcher management, which stops at four.
- **Long labels.** A label that still doesn't fit ends in an ellipsis.
- **A slot holding a plugin.** A tap runs the plugin's menu item over the home. A plugin that's gone shows greyed with
  "plugin missing", as a plugin entry does today.
- **Swipe up from the bottom edge.** Quick settings, on the home and every chrome window.
- **Swipe down or tap at the top edge, with Focused mode on.** Full settings, on the home and every chrome window.
  With Focused mode off, the top edge opens KOReader's own menu as it does today.
- **A hold on the quote.** Opens the home's sheet, since the quote no longer has settings.
- **The home's sheet.** Refresh weather, Open the file browser (with Focused mode off), Wi-Fi, KoPanda settings, Sleep.

## Settings menu

```
Look
Text size
Wallpaper              (only in Frosted)
Weather location
Units
Featured book
Launcher
Focused mode
Check for KoPanda update
KOReader menu
Apps (Storefront)      (only if installed)
```

KOReader menu opens the file manager's full menu (`FileManagerMenu:onShowMenu`, `filemanagermenu.lua:1006`) after the
settings menu closes. It's left out with no file manager up.

## Plugin menu items

A new launcher entry kind, `plugin_menu`: `{ kind, plugin, item, label, icon }`. `run` builds the plugin's items into
an empty table through `fm[plugin]:addToMainMenu`, then calls `item`'s callback. An item with no callback, a plugin
that isn't loaded, or an error reads as unavailable or is logged, and the home stays up.

In the picker, choosing a plugin lists its main-menu items alongside the existing action tree. An item with a submenu
and no callback isn't offered. The studio's validators and `entries-edit.ts` gain the kind; the settings round-trip
fixture proves the two sides agree.

## Removed

- `edit_layout.lua`, `rows_edit.lua`, the `rows` type, its row builder and validator, `layout.rows`, and the two
  Edit rows on the home's sheet.
- `Layout.overflow` and `Layout.fits` if nothing else calls them.
- The studio's `LayoutEditor.tsx`, `rows-edit.ts`, the layout-fit route and client, their tests and fixtures, and
  `bin/layout-fit`.
- `quote.source`, with `Quote.sources` reduced to the built-in list.
- `stats.show` and `widgets/stats.lua`.
- Any home widget that neither the fixed home nor the Stats window uses. `widgets/weather.lua` is the one to check.
- Look tokens only the removed screens read.
- The Studio submenu's address, profile and Pull rows, and the `studio_address` and `studio_profile` state. Pull code
  goes only where Check for update doesn't share it; the implementation plan traces that split.

The rows live in one table in `home_rows.lua`. Stored `layout.rows`, `quote.source` and `stats.show` values stay in
the file, unread, as the stats window's design found for `layout.rows_2`. `schema.version` stays 1.

## Failure

Every path keeps today's guards: a gesture or launcher run that fails is logged and leaves the screen as it was.

## Tests

- Launcher: four across and 2×2 by look; five entries refused; the new default.
- Fit: at Extra large with the longest quote, the quote and launcher both show on the Colorsoft and the Paperwhite;
  on a screen too short for both, the quote goes and the launcher stays.
- Gestures: the swap, on the home and on a chrome window; the top-edge tap; the Focused-off path unchanged.
- `plugin_menu`: runs through a stub plugin; missing plugin, missing item and a raising callback.
- Settings menu: the removed rows, Wallpaper by look, the KOReader menu row, a hold on the quote.
- Tools › KoPanda: Check for update directly under it, no Studio row.
- `AGENTS.md`, `README.md` and `HOOKS.md` lose `bin/layout-fit`, the two-page note and the Edit layout sections, and
  name the new Check for update path.

## Manual checks

- Labels at each text size in Diner and Frosted, by eye.
- Install Rakuyomi on the Kindle and tap its slot. The emulator can't prove it: it needs its own backend.

## Out of scope

- Frosted's overlap outside the launcher.
- Landscape, until `bin/preview` can render it.
- Editing the nav bar.
- Deleting the studio itself.
