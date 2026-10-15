# KoPanda — UI direction (2026-10-13)

Decided on 2026-10-13 from a design canvas of the device screens. The canvas is published at
https://claude.ai/artifact/GjdTxCARL5uCaBaMTtcqCE; a snapshot of its files is in
`2026-10-13-kopanda-screens/` beside this doc (`canvas.json` lays the boards out, one `.dc.html` per
board). This doc holds the decisions the canvas makes; the canvas is the reference for anything visual
this doc leaves out. Where a feature spec and the canvas disagree on behaviour, the spec wins; this doc
governs look, layout and gestures.

Every board is the Kindle Colorsoft at half size (632×840 for 1264×1680). Sizes below are device
pixels unless marked "board".

## Decisions

| Topic | Decision |
|---|---|
| Looks | Two looks ship, **Editorial** and **Diner**, as a first-class concept from stage 1. One setting, `look`, switches between them; **Diner is the default** on every profile. Widgets draw only from look tokens (below); a look is a Lua table, not code. A third direction, "Cover first", was drawn and dropped. |
| Widgets | The same widget set in both looks: date, clock, weather, quote, reading stats, featured book, launcher. A look never adds or removes a widget. |
| Layout | Rows of one to three columns. The home screen defaults: header row (date, clock); featured book row (cover beside text); quote row; launcher row; stats row. |
| Status bar | None. Clock, Wi‑Fi and battery are widgets or sheet rows, never chrome. KOReader's own top menu stays reachable by swiping down from the top edge. |
| Gestures | One vocabulary everywhere. Tap acts: the cover opens the book, a launcher entry runs, weather refreshes. Hold opens a sheet for the thing held. Hold on empty space opens the home screen's own sheet. Swipe up from the bottom edge opens settings. |
| Hold on the book | Sheet: the book's header (small cover, title, author, progress, last opened), then Open, Book details, Read status ›, More by this author ›, Feature a different book, This widget's settings. |
| Hold on empty space | Sheet headed "Home": Edit layout, Open the file browser, Refresh weather (with its age), Wi‑Fi (with its state), KoPanda settings, Sleep. |
| Featured book | Defaults to the most recently opened book; "Feature a different book" on its sheet pins another. No settings screen for it. |
| Launcher | At most six entries on the home screen; more go behind a folder entry. Default six: Library, Series, Authors, History, Wi‑Fi, Settings. Entries are KoPanda screens, KOReader screens, plugins, folders on disk and dispatcher actions. Tapping a folder entry opens a sheet listing its entries, each labelled with its kind; hold on the folder edits it. |
| Placeholder entries | Series and Authors are present from stage 1. Until their screens land (stage 5), tapping one shows a short "coming with the library" note. An entry is never hidden because its destination isn't built. |
| Launcher management | A list screen: each entry with its icon, label and kind, up and down arrows, and remove. Adding opens a picker by kind (plugin, KOReader screen, folder on disk, action). The seventh entry and beyond go into a folder. |
| Edit layout | A list of rows, each showing its columns as boxes with their width share, with up and down arrows. Tapping a row selects it and reveals Add column, Change widget and Remove row. Add row at the foot, and Reset to the look's default. No drag anywhere: e-ink has no drag. |
| Night mode | Each look has a night palette (below). KOReader's night mode inverts the whole framebuffer, so while it is on the plugin draws the inverse of the night palette and pre-inverts the cover bitmap, and the panel shows the palette as drawn here. Assumption to verify in stage 1: that `Screen:toggleNightMode` inverts at the framebuffer and that pre-inverting a blitbuffer is cheap enough per paint. |
| First run and failures | No book yet: a dashed cover frame, "Nothing open yet", and an Open the Library button in the featured slot. Weather with no fetch: "Weather needs Wi‑Fi" in the weather slot. Wi‑Fi off: the launcher entry shows "off". A launcher entry whose plugin is gone stays in place, greyed, with "plugin missing" and a dashed icon; it is never silently dropped. Stats with nothing read: "No streak yet · 0 min today". The quote shows regardless. |
| Quick settings (stage 4) | A sheet, not a bar: brightness and warmth as outlined bars with minus and plus buttons, then a grid of toggles and actions (Wi‑Fi, Night, Rotation lock, Sync books, Screenshot, Sleep) with the on state filled in ink. Opened from the home sheet, a launcher entry or a hold on the nav bar's Settings tab; which of those is decided when stage 4 is specified. KOReader's own top menu keeps the top edge. |
| Icons | Every icon the shell draws is an entry in an icon registry: a stable id, a human label, where it appears, and the default stroke SVG. Looks and, later, icon packs map by id. Stage 1 ships the registry with the default set so icon packs can be consumed after the MVP without renaming anything. |
| Screens | One build for every device. KOReader scales lengths with `Screen:scaleBySize`, which multiplies by the shorter screen edge over 600 px (averaged with a DPI factor only when the user overrides DPI; `base/ffi/framebuffer.lua:414`). KoPanda lays out at runtime from the screen's width and height and sizes everything through that scale, like a fluid page: rows fill the width, columns take their shares. The Colorsoft and the Paperwhite differ by two percent in scale, so the boards for both are the same layout. Goldens are per device profile. |
| Covers | Real covers from KOReader's book info manager; the boards show typographic placeholders. A cover is drawn with the look's cover frame (shadow or outline), never recoloured. |
| Nav bar (stage 3) | Five tabs: Home, Library, Authors, History, Settings. Editorial: a hairline bar, small-caps labels, a 3 px rule over the active tab. Diner: a teal band with ink dividers and the active tab as a mustard block. |
| Library (stage 5) | A three-column cover grid with a progress strip on each cover, a header with the count and two pickers (sort, status), the nav bar beneath. |
| Settings menus | Generated from the schema into KOReader's native menu widgets. A look does not restyle them: native menus stay native, so KOReader upgrades can't break them. |
| Paperwhite | The same two looks drawn for 16 greys, not desaturated. Greys are chosen for contrast: bands at mid grey with black text, tiles at light grey, flat fills next to grey become hatches, hairlines thicken to 2 px, the cover gains an outline. The device is the 11th-generation Paperwhite (2021, 6.8 inch): 1236×1648 at 300 DPI, confirmed by the owner. |

## The two looks

| Token | Editorial | Diner |
|---|---|---|
| Display face | Newsreader (serif), 500 | Bricolage Grotesque, 800 |
| Text face | IBM Plex Sans | Bricolage Grotesque, 500–700 |
| Accent face | none | Caveat (the greeting, the library count) |
| Paper | `#f3f1ea` | `#f5f1e6` |
| Ink | `#1c1b19` | `#2f2e2b` |
| Muted | `#6b6861` | `#5a5750` |
| Text | `#4a4843` | ink |
| Hairline | `#c9c5b8` | none; strokes are ink |
| Light hairline | `#e2dfd4` (row rules) | none |
| Accents | none | teal `#6fb3ab`, pink `#e8a59d`, mustard `#e0bd6a` |
| Band | none | teal (the header band) |
| Stroke | 1 px hairlines, 2 px for the main rule | 3 px ink outlines, 4 px band edges |
| Shadow | soft: 2 px right, 3 px down, hairline colour | hard, ink: 4 px on tiles, 8 px on sheets; 6 px pink under the cover |
| Corner radius | 3 px on covers, 0 elsewhere | 0 |
| Tile | text row with a hairline under it | filled box with outline and hard shadow |
| Progress | 4 px bar, ink on hairline | 14 px bar, 2 px ink outline, mustard fill on a paper track |
| Sheet | paper panel from the bottom edge under a 2 px rule | outlined box with 8 px ink shadow and a coloured header band |
| Chip | small caps, muted | outlined uppercase label on pink |
| Labels | 11 px small caps, 0.14 em tracking (board) | 11 px uppercase, 800, 0.1 em (board) |

Night palettes. Editorial: paper `#15161a`, ink `#e8e6df`, muted `#9b988f`, text `#c4c1b8`, hairline
`#3a3b40`, light hairline `#2a2b30`; the cover gets a hairline outline instead of a shadow. Diner: paper
`#1e1c1a`, ink `#f1ece0`, muted `#bdb7a9`, teal `#2f6b65` (the band too), pink `#b86f68`, mustard
`#b8923c`; outlines
and hard shadows turn cream, the greeting reads "Good night", and the weather icon is a moon. Mustard
and pink tiles take dark text.

Greys for the Paperwhite: paper `#f4f4f4`, ink `#111111`, muted `#444444`/`#555555`, band `#9a9a9a`,
tiles `#c8c8c8` / `#e0e0e0` / `#b0b0b0`, hairline `#8c8c8c`, light `#d0d0d0`, cover `#4a4a4a` (the
placeholder cover's fill, not a look token). Editorial takes muted `#555555` and text `#444444`, and
its cover outline and shadow are the hairline `#8c8c8c`. Diner takes muted `#444444`; its accents map
to the tiles as mustard `#c8c8c8`, pink `#e0e0e0`, teal `#b0b0b0`, and its mustard progress fill
becomes a 135° hatch of ink on paper.

## Type sizes on the device (Editorial board values doubled)

| Element | Board | Device |
|---|---|---|
| Date and clock | 36 px serif | 72 px |
| Featured title | 28 px serif | 56 px |
| Quote | 18 px italic serif | 36 px |
| Launcher entry | 16 px | 32 px |
| Small caps labels | 11 px | 22 px |
| Sheet rows | 17 px | 34 px |
| Nav labels | 11 px | 22 px |

Diner's clock is 56 px on the board (112 px on the device); its featured title 28 px; tiles 14 px labels.

## Schema consequences

Keys the canvas implies, all of them justified by a screen on it:

- `look`: editorial | diner.
- `layout.rows`: the row list, each row its slots and width shares.
- `featured.pinned`: a file path or nil (set from the sheet, not a settings screen).
- `clock.twenty_four_hour`: boolean.
- `weather.units`, `weather.location`: units and a ZIP or coordinates.
- `quote.source`: built-in | highlights | both.
- `text_size`: small | medium | large (one scale for every widget).
- `launcher.entries`: the list, at most six at the top level.
- `icons.pack`: folder name.
- `stats.show`: boolean.

Ten keys. Fonts, colours, strokes, shadows and radii are not keys; they are the look.

## Candidates, not scope

Seen on the canvas but not promised by any stage: a greeting with the owner's name (Diner header),
"last opened" on the book sheet, Wi‑Fi state on the home sheet, the library's status filter picker, a
"Sync books" action on the quick-settings sheet. Each enters a feature spec only if that feature wants it.

## Noted for after the MVP (owner, 2026-10-13)

- **To be read, collections, shelves.** Undecided as concepts; Series and Authors replace them on
  the home screen and nav bar for now. KOReader has no to-be-read status, only collections and reading
  status, so if it returns it is a collection by convention.
- **Icon packs.** Consuming existing packs (Solar and others) by mapping onto the icon registry's ids.
- **Calibre-Web-NextGen as a library source.** The Kindle pulls books over OPDS from the owner's CWNG
  server; the library should be able to show books that aren't downloaded yet, with their covers and
  metadata cached, and download on tap. Stage 5's book model therefore never assumes a local file:
  a book is identified by an id, has an optional path, and the cover and metadata cache is keyed by
  that id. (This is distinct from CWNG's library-folder feature, which stays off.)
- **Android profile.** Screen size unknown; the fluid layout should carry it, goldens come later.

## Out of scope (owner, 2026-10-13)

The reader (status bars, page browser, dictionary and highlight menus) and sleep screens. KOReader's
own stay as they are.
