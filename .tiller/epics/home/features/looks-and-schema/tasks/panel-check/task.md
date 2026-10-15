# Token values settled from the Colorsoft panel

## Approach

1. Prepare the push: a plugin folder copy with no `spec/` and no dev files, and the steps for the
   owner from handoff §4 (USB is MTP-only and single-session; the folder goes to the Kindle's
   `koreader/plugins/`). The owner does the push; the agent never writes to the device.
2. The owner opens Tools › KoPanda › Swatches on the Colorsoft (SimpleUI stays enabled; the swatch is
   the one KoPanda entry it allows) with night mode off, and reads each panel. The owner reports, per
   look and variant, any value to change and the new value, or that none change. Photos are optional
   context, not evidence for a colour.
3. For each change: edit the token in `looks/<look>.lua` and the same value in the direction doc's
   tables (`.tiller/design/2026-10-13-kopanda-ui-direction.md`, "The two looks", the night palettes,
   the greys), in one commit. Editing that design doc moves it under Tiller's design-drift check; run
   `tiller drift` and route any finding through the human's confirmation, not by hand.
4. If anything changed, regenerate the swatch goldens, open them, and re-run `bin/check`.
5. The owner signs C13 (values final) once the panel reads right.

## Surfaces

`kopanda.koplugin/looks/editorial.lua`, `looks/diner.lua`, `.tiller/design/2026-10-13-kopanda-ui-direction.md`,
`spec/goldens/swatch-*.png|json`.

## Tests

No new test. `looks_spec.lua` (C5) re-runs over any changed value (format, parity, neutral greys);
`swatch_golden_spec.lua` (C11) over the regenerated goldens. C13 is the owner's sign-off.

## Edge cases

- No value changes: the task's output is the owner's C13 sign-off and an unchanged tree; close it with
  that recorded rather than an empty commit.
- A change to a grey value is checked on the paperwhite emulator profile only; the Paperwhite itself
  is another household member's device and is not part of this check.
- A wanted change that isn't a value (a different font size, a new role) is outside this task:
  capture it as a tweak.
