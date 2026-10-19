# Three new looks: Riso, Toybox, Frosted Plates (2026-10-19)

Decided on 2026-10-19 from the owner's Claude Design project "KoPanda design looks". A snapshot of the
design file and its runtime is in `.tiller/design/2026-10-19-kopanda-looks/` (`KoPanda Looks.dc.html`,
`support.js`), with each chosen look's token table, icon sets, verdict and the design's own Lua export
beside it (`riso.md`, `toybox.md`, `frosted.md`; `plates.md` is 3a, the opaque base Frosted inherits
from, kept for reference and not built). The design drew nine looks; the owner chose 1b Riso, 2c Toybox
and 3b Frosted Plates. Where this doc and the design file disagree, this doc wins; where this doc is
silent, the design file is the reference.

The UI direction of 2026-10-13 still governs everything a look does not change: the widget set, the
layout rows, the gesture vocabulary, native settings menus, and the rule that a look is a Lua token
table under `kopanda.koplugin/looks/`, not code.

## Decisions

| Topic | Decision |
|---|---|
| Looks | Five looks: Diner (default), Editorial, Riso, Toybox, Frosted. `look` gains three choices. Every look declares the same token paths (`spec/unit/looks_spec.lua` keeps checking parity across all of them). |
| Icons | Each new look ships its own icon set, vendored for every registry id: Riso takes Phosphor Fill, Toybox MingCute Line, Frosted Phosphor Bold. A look names its set with the token `icons.set` (`false` on Diner and Editorial, which keep Lucide). `Icons.path(id)` resolves through the active look's set and falls back to the Lucide file for an id a set lacks. Set files live under `icons/<set>/<id>.svg`, named by registry id, with the pack's own name, version and licence recorded in `icons/SOURCES.md`. |
| Fonts | Vendored as the existing families are (static instances, OFL, upstream commit and SHA-256 in `fonts/SOURCES.md`): Big Shoulders Display Black and Work Sans Medium and Bold for Riso; Baloo 2 ExtraBold and Nunito Bold, ExtraBold and SemiBold Italic for Toybox; Atkinson Hyperlegible Regular, Bold and Italic for Frosted. |
| Wallpaper | One new schema key, `wallpaper.file` (type `path`, default `false`, group appearance): a png or jpg on the device. Its settings row opens KOReader's file chooser filtered to those; the studio shows a text field and previews with the file when it exists locally. Only Frosted reads it. With no file, Frosted draws its plates on plain paper. |
| Frosted's plates | Not opacity. Each plate's rectangle is lightened toward paper with KOReader's `BlitBuffer:lightenRect` before the plate's text is drawn: 0.82 by day, 0.84 at night, 0.85 in grey. At night the plugin paints the inverse of the night palette and the framebuffer inverts it, so lightening the pre-inverted buffer is the dim the design asks for; the wallpaper bitmap is pre-inverted at night as covers are. The nav bar and every sheet stay opaque. |
| Riso's misregistration | Display type (clock, titles) is drawn twice: the pink pass offset 3 right and 2 down, the ink pass on top. Tiles, the sheet and the cover's trailing outline use the existing shadow and outline tokens. In grey the offset layer is a light grey ghost. |
| Toybox's blocks | Rounded blocks with a solid ink edge beneath (the existing hard shadow at x 0, y 6), round coloured icon badges on launcher tiles cycling sun, coral and mint, a pill progress bar, and a floating pill nav with a 6 px edge. |
| Goldens | Per new look: home day, home night, home Paperwhite, the book sheet, the library, the nav bar. Every other screen is covered by unit specs on the tokens and judged by the owner on the emulator. |
| Order | Groundwork (fonts, icon sets, N looks), then Riso, Toybox, Frosted. Each lands as its own commit on `main`; no Tiller unless the owner asks. |

## Device checks the owner does by hand

From the design's verdicts: that `lightenRect` reads the same on the Colorsoft's colour layer as in the
emulator; that Home takes a full refresh under Frosted (a lightened photo ghosts more than flat paper);
that Riso's 3 px offset reads as intent, not blur, on the 150 ppi colour layer, and its blue holds up in
sun; that Toybox's rounded ends leave no outline after page turns.

## Out of scope

The other six looks the design drew (Grid, Logbook, Ex Libris, Sticker Book, Funnies, Plates); the
alternate icon sets each look lists; a wallpaper push from the studio; wallpaper under any look but
Frosted.
