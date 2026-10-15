# Icon registry with the canvas's default stroke icons

## Approach

1. Extract every inline `<svg>` from the canvas boards in `.tiller/design/2026-10-13-kopanda-screens/*.dc.html`
   (about 120 occurrences over 19 boards; most repeat across boards). Group identical drawings, then
   group drawings that are the same icon at a different size or stroke colour. Each distinct icon
   becomes one file `kopanda.koplugin/icons/<id>.svg`, with a `viewBox`, its stroke drawing kept, and
   colours normalised to ink (`#000000`): NanoSVG renders an SVG's own colours
   (`frontend/ui/renderimage.lua:338-393`), and the canvas strokes with `stroke="currentColor"` (for
   example `NavBarC.dc.html`), a name NanoSVG turns into mid-grey 128 (`base/build/arm64-apple-darwin23.5.0-debug/staging/include/nanosvg.h:1446-1457`).
   Later tinting is a separate concern.
2. Ids are short, stable, lower-snake names for what the icon is, not where it is (`library`, `series`,
   `authors`, `history`, `wifi`, `settings`, `folder`, `sun`, `moon`, …). Where one drawing serves two
   meanings, one id. Decorative shapes that aren't icons (dashed frames, rules) stay out.
3. `kopanda.koplugin/icons.lua`: `Icons.entries`, an ordered list of `{ id, label, used_in, file }`
   (`file` relative to the plugin folder, `used_in` a list of places from the direction doc and the
   canvas: `"launcher"`, `"nav"`, `"home sheet"`, `"quick settings"`, `"weather"`, `"empty states"` …),
   and `Icons.path(id)`, the file's path through `Fonts.path` (the fonts task's plugin-relative path
   helper), nil for an unknown id. Unlike the schema, the registry isn't dumped to JSON in this stage,
   so it may hold the lookup function.
4. Present the extracted set to the owner as a contact sheet (a rendered PNG through the emulator's
   LuaJIT and `RenderImage`) in the task's PR, so the ids and labels are reviewed with the drawings.
5. `main.lua` requires `icons` at load time with the others.
6. `HOOKS.md`: `ui/renderimage` `renderSVGImageFile` (`:338-393`) if `icons.lua` requires it; otherwise
   only the spec does and the harness section lists it.

## Surfaces

`kopanda.koplugin/icons/*.svg`, `kopanda.koplugin/icons.lua`, `main.lua` (require only),
`HOOKS.md`, `spec/unit/icons_spec.lua`.

## Tests

`icons_spec.lua` (C7), written first against an empty registry so the parity checks fail once a file
is added without an entry:

- Files under `icons/` and registry `file` values are the same set; ids unique; every entry has a
  non-empty `label` and `used_in`.
- No icon file contains `currentColor`.
- Every file renders through `RenderImage:renderSVGImageFile(file, 48, 48)` to a non-nil buffer with at
  least one pixel of non-zero alpha (catches strokes NanoSVG drops), and every such pixel is black,
  R = G = B = 0 (catches an unnormalised colour; the buffer is straight alpha, so anti-aliased edges
  stay black).
- No `.lua` under `kopanda.koplugin/` except `icons.lua` contains the text `.svg`.

## Edge cases

- A canvas icon that uses a feature NanoSVG lacks (masks, CSS classes): rewrite it with plain paths
  and say so in the PR.
- Licence: the canvas icons were drawn for this project in the design session, so they ship as the
  project's own; if any is recognisably a third-party set's glyph, stop and ask.
