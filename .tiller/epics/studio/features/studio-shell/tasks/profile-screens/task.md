# First screen lists profiles and opens one

## Approach

1. `studio/src/ui/api.ts`: typed `fetchProfiles()` and `fetchProfile(id)` over `/api/profiles`,
   throwing an `ApiError` carrying the server's `error` text and the HTTP `status` on a non-2xx answer,
   so the profile screen can tell a 404 ("No profile <id>") from any other failure (shown as its text).
2. `studio/src/ui/App.tsx`: read the hash (`#/profiles/<id>` opens a profile, anything else the list),
   follow `hashchange`; no router dependency.
3. `ProfileList.tsx`: "Loading profiles", then one button per valid profile with name, device,
   `<width>×<height> · <dpi> dpi · colour|greyscale` and "settings file" or "defaults"; an invalid one as
   its id and error, not a button; a failed request as its message.
4. `ProfileScreen.tsx`: the profile's name as the heading, device facts, settings path, "All settings
   at their defaults" when `has_settings` is false, and a "Profiles" link to `#/`. A 404 shows
   "No profile <id>" with the same link. Leave one clearly bounded region in the screen for the form
   that `studio/settings-form` adds; no placeholder text in it.
5. Styles in the scaffold's stylesheet: dark background, one violet accent for focus and the chosen
   row, system font stack.

## Surfaces

- `studio/src/ui/api.ts`, `App.tsx`, `ProfileList.tsx`, `ProfileScreen.tsx`, `styles.css`
- `studio/test/ui/profiles.test.tsx`

## Tests

`studio/test/ui/profiles.test.tsx` (C5), jsdom, with `fetch` stubbed per case:

- the loading line shows before the response resolves;
- two valid profiles and one invalid one render as two openable rows and one id-and-reason row;
- a 500 answer shows its error text;
- clicking Colorsoft sets `location.hash` to `#/profiles/colorsoft` and shows its name, device facts,
  settings path and the defaults line; with `has_settings` true the defaults line is absent;
- starting at `#/profiles/paperwhite` opens it without showing the list first;
- a 404 for `#/profiles/nope` shows "No profile nope", a 500 for a profile shows its error text; the
  back link returns to the list;
- an answer with no profiles shows "No profiles in <dir>" from the answer's `dir`.

Then the owner's C9 walk-through: `npm run dev`, and `npm run build && npm start` on 4490.

## Edge cases

- A hash with an encoded or odd id (`#/profiles/%2e%2e`) is passed to the API as an encoded path
  segment and answered 404 by the server, shown as "No profile".
- The profile list rerenders after a hash change back to `#/`, refetching so hand edits show.
