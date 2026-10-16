# The generated form over every schema key

## Approach

The form in the profile screen: one control per schema key, the reports, and the routes to the two
editors, which later tasks fill. Starts after `studio/settings-form/settings-file`. Read the built
`App.tsx`, `api.ts` and `ProfileScreen.tsx` from `studio/studio-shell` first
(`studio-shell/tasks/profile-screens/task.md:5-19`).

1. **`studio/src/ui/api.ts`** gains `fetchSettings(id)` and `putSetting(id, key, value)`, throwing the
   existing `ApiError` with the server's `error` and status.
2. **Routing** in `App.tsx`: `#/profiles/<id>` the form, `#/profiles/<id>/layout` and
   `#/profiles/<id>/launcher` an editor slot; anything else under a profile is the form. The editor slots
   render placeholders that `layout-editor` and `launcher-editor` replace: a heading and Done back to
   `#/profiles/<id>`.
3. **`studio/src/ui/settings/SettingsForm.tsx`**: props `schema` (default the real one), `settings` (the
   API state), `onWrite(key, value)`. Groups `schema.keys` by consecutive `group` in order, each under its
   id capitalised; one control per key from a type-to-component table; a type missing from the table
   renders "No control for <type> (<key>)." in its place and the rest continue.
4. **Controls** in `studio/src/ui/settings/controls/`:
   - `ChoiceControl`: a button per choice with its label, the current one `aria-pressed`; a click on
     another calls `onWrite`.
   - `BooleanControl`: a checkbox-style toggle.
   - `PathControl`: "Most recent book" (shown and selected when the value is `false`) and the pinned path
     otherwise; a text field and Pin, validated with the studio's `path` validator before sending, the
     note "A pin is a path on the device, starting with /." on refusal; Most recent book writes `false`.
   - `LocationControl`: the stored name and coordinates only; `location-search` adds the search.
   - `RowsControl`, `LauncherControl`: "Layout · N rows" and "Launcher · N entries" links to the editor
     routes.
5. **`ProfileScreen.tsx`** loads the settings with the profile, renders the form in its region, and
   handles `onWrite`: one `putSetting`, the control disabled while it runs, the answer replacing the
   state; on failure "Couldn't save <label>: <error>." beside the control and a refetch.
6. **Reports:** a "Not in the schema" section listing `unknown` keys with their `text` and "Kept as they
   are when the studio writes."; "The stored value isn't allowed, so this shows the default." beside each
   `invalid` key; the read-only and unreadable lines above the form with every control disabled.
7. Styles in the shell's stylesheet: dark, one violet accent for the selected choice, focus and the
   editor links; the theme studio's `src/ui/form/` (`koreader-theme-studio` @a0de5dd) is a reference for
   spacing, copy what fits.

## Surfaces

- `studio/src/ui/api.ts`, `App.tsx`, `ProfileScreen.tsx`, `styles.css`
- `studio/src/ui/settings/SettingsForm.tsx`, `studio/src/ui/settings/controls/*.tsx` (new)
- `studio/test/ui/settings-form.test.tsx` (new); `studio/test/ui/profiles.test.tsx` only if the
  profile screen's fetches change its stubs

## Tests

Written first and run failing.

`studio/test/ui/settings-form.test.tsx` (C5), jsdom, `fetch` stubbed per case:

- **Every key once:** with the real `schema`, the form has exactly one control per key, found by the
  key id on a `data-key` attribute, in `schema.keys` order; the first is `look`; group headings in order.
- **No control:** a schema with an extra key of type `widgetty` shows "No control for widgetty (x)." and
  every other control.
- **Choice:** clicking Editorial on Diner sends one `PUT /api/profiles/colorsoft/settings/look` with
  `{ value: "editorial" }`; clicking Diner (shown) sends none.
- **Boolean, path:** one PUT each; the path field with `books/a.epub` and with `/` shows the note and
  sends nothing; Most recent book on a pinned profile sends `false`.
- **Failure:** a 400 answer shows "Couldn't save Look: …" and the control shows the file's value again.
- **Reports:** `unknown` and `invalid` render as specified; `state: "read_only"` and `"unreadable"`
  disable every control and show their lines.
- **Editors:** the Layout and Launcher rows set `#/profiles/colorsoft/layout` and `/launcher`; loading
  at either shows the editor slot; Done returns to the form.

The shell's `profiles.test.tsx` still passes (C14).

## Edge cases

- A settings answer missing a key the schema has (an older server during dev): the control shows the
  schema default.
- A write answered after the user navigated to an editor: the state still updates; nothing is lost.
- Two quick clicks on different choices: the second waits for the first (the control is disabled), so
  writes stay ordered.
- `quote.source` has one choice: its control shows one button, already selected.
