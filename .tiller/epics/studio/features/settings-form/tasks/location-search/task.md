# Weather location search through the studio server

## Approach

The device's place search, run by the studio's server, and the location control's search. Starts after
`studio/settings-form/form`, and after `home/device-menus/location-search` has merged (its
`LocationSearch.url`, `LocationSearch.parse` and the recorded responses under `spec/fixtures/geocoding/`);
read `location_search.lua` as built first and record any rule that differs from
`device-menus/tasks/location-search/task.md:19-28`. The built plugin's rules win.

1. **`spec/fixtures/studio/geocoding_cases.lua`**: `return { urls = { { query, url }, ... },
   parses = { { fixture = "chicago.json", candidates = { { name, latitude, longitude, shown }, ... } },
   ... } }`. URLs for `"  Chicago "`, `"New York"`, `"60614"`, `"606140"`, `"6061A"`, `"São Paulo"` and
   `"a&b=c"`, `"St. John's (NL)!"`; parses for each recorded fixture, plus one hand-written fixture
   `spec/fixtures/geocoding/edge.json` holding a result without `name`, one with a string latitude, one
   whose `admin1` equals its name and one with no `admin1` or `country`.
2. **`studio/src/server/geocoding.ts`**: `trim` as `util.trim` (`frontend/util.lua:52-55`: Lua `%s`, the
   ASCII whitespace set), `urlEncode` as `util.urlEncode` (`:1443-1455`), `geocodeUrl(query)`,
   `parseGeocoding(body)` returning candidates or `null` for an unreadable body, and
   `searchPlaces(query, fetchImpl)` with a 10 s `AbortSignal.timeout`.
3. **`studio/src/server/routes/geocode.ts`**: `GET /api/geocode?q=`: `400 { error }` for an empty trimmed
   query; `502 { error }` for a fetch failure, status other than 200 (the device's `get`, `kopanda.koplugin/weather.lua:89-91`), unreadable body or timeout; else
   `200 { candidates }`. `fetch` is injectable through `createApp`'s options, so no test reaches the
   network.
4. **`LocationControl`** gains the search: field with placeholder "City or ZIP code" and Search (Enter
   too); empty does nothing; "Searching…"; "Choose a place" with a button per candidate's `shown`; a pick
   calls `onWrite("weather.location", { name, latitude, longitude })`; "No place found for “<query>”." and
   "Couldn't search for places." as notes. A new search replaces the list.
5. **`spec/unit/studio_geocoding_spec.lua`**: for each case, `LocationSearch.url(query)` and
   `LocationSearch.parse(<fixture text>)` give the case's URL and candidates.
6. Record in the PR the live response read before writing `edge.json`, as the device task did.

## Surfaces

- `spec/fixtures/studio/geocoding_cases.lua`, `spec/fixtures/geocoding/edge.json` (new)
- `studio/src/server/geocoding.ts`, `studio/src/server/routes/geocode.ts` (new), `app.ts` (mount, fetch
  option)
- `studio/src/ui/settings/controls/LocationControl.tsx`, `studio/src/ui/api.ts`
- `spec/unit/studio_geocoding_spec.lua`, `studio/test/server/geocoding.test.ts`,
  `studio/test/ui/location.test.tsx` (new)

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `spec/unit/studio_geocoding_spec.lua` (C6): every URL and parse case against `LocationSearch`.
- `studio/test/server/geocoding.test.ts` (C6): every case against `geocodeUrl` and `parseGeocoding`
  (fixtures read from `spec/fixtures/geocoding/`); the route with a stubbed fetch answering
  `chicago.json` (200 with candidates), `none.json` (200, empty), a 500, `"<html>"`, a rejected promise
  and a never-resolving one with the timeout shortened (each 502); `?q=%20` is 400; the stub saw the
  case's exact URL.
- `studio/test/ui/location.test.tsx` (C6): a search shows Searching… then Choose a place with the
  candidates' `shown` texts; a pick sends one PUT of exactly `{ name, latitude, longitude }`; an empty
  answer shows the no-place note naming the query; a 502 shows the failure note; neither sends a PUT.

## Edge cases

- `encodeURIComponent` leaves `!'()*` unencoded and `util.urlEncode` doesn't; the "St. John's (NL)!"
  case catches a port that uses it (the others encode the same either way).
- Lua's `%s` is ASCII whitespace, JavaScript's `trim` also strips Unicode spaces; port the Lua set.
- Open-Meteo is reached from the owner's Mac; a corporate proxy or offline Mac reads as "Couldn't search
  for places."
- The server is loopback-only, so the geocode route is not an open proxy.
