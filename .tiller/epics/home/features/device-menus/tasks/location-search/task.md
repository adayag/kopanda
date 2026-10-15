# Weather location search through Open-Meteo's geocoding

## Approach

`kopanda.koplugin/location_search.lua`: the place search the menu's location row runs, from a typed city
or ZIP code to a stored `{ name, latitude, longitude }`. It writes nothing itself; `on_pick` does. Repo
lines on `main` at `ca26783`; KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. Independent
of the other tasks.

1. **Read the endpoint first.** Make one live request each for "Chicago" and for "60614" with
   `countryCode=US`, and one for a nonsense query, and save them as
   `spec/fixtures/geocoding/{chicago,zip-60614,none}.json`. On 2026-10-15 they returned
   `{ results = [ { id, name, latitude, longitude, elevation, feature_code, country_code, admin1..4,
   timezone, population, postcodes, country_id, country, ... } ], generationtime_ms }` and, for no match,
   `{ generationtime_ms }` with no `results`. If the shape has changed, stop and report it before writing
   the parser. A `spec/fixtures/` file is excluded from luacheck (`.luacheckrc` `exclude_files`), and these are JSON.
2. **`Weather.get(url)`:** `weather.lua`'s local `get` (`:72-92`) becomes a module function with the same
   body; `Weather.fetch` calls `Weather.get`. Nothing else in `weather.lua` changes.
3. **`LocationSearch.url(query)`:** `util.trim` (`frontend/util.lua:52`), then
   `https://geocoding-api.open-meteo.com/v1/search?name=` .. `util.urlEncode(q)` (`:1443`) ..
   `&count=10&language=en&format=json`, plus `&countryCode=US` when `q` matches `^%d%d%d%d%d$`.
4. **`LocationSearch.parse(body)`:** `rapidjson.decode` in `pcall` (as `weather.lua:103` decodes); not a
   table → `nil, "unreadable"`; no `results` → `{}`. Each result with a non-empty string `name` and number
   `latitude` and `longitude` becomes `{ name = <stored name>, latitude, longitude, shown = <button text> }`:
   - stored name: "<name>, <admin1>" when `admin1` is a non-empty string different from `name`, else
     "<name>, <country>" when `country` is, else `name`;
   - button text: the stored name, then ", <country>" when `country` is non-empty and not already its
     last part.
5. **`LocationSearch.search(query)`:** `Weather.get(url)` then `parse`; a `nil` body gives
   `nil, <why>`.
6. **`LocationSearch.ask(on_pick)`**, the flow of the feature's "The place search":
   - `InputDialog` titled "Weather location", `input_hint = "City or ZIP code"`, Cancel and Search
     (`is_enter_default`), `onShowKeyboard()` (`frontend/ui/widget/inputdialog.lua:125-167`, `:583`, `:640`);
   - Search with an empty trimmed query does nothing; otherwise it closes the dialog, then:
     - `require("ui/network/manager"):isConnected()` false (`weather.lua:197-198`): note "Finding a place
       needs Wi‑Fi."; stop;
     - show `InfoMessage{ text = "Searching…" }` (no timeout), `UIManager:forceRePaint()`
       (`frontend/ui/uimanager.lua:1404`), `search`, close the message;
     - `nil`: note "Couldn't search for places."; `{}`: note "No place found for “<query>”.";
     - otherwise a `ButtonDialog` (`frontend/ui/widget/buttondialog.lua:1-40`) titled "Choose a place",
       one row per candidate (`shown`), then Cancel; a tap closes it and calls
       `on_pick{ name, latitude, longitude }` (no `shown`: the validator takes exactly three fields,
       `settings.lua:171-183`).
   - Every step guarded: an error is logged, open dialogs close, `on_pick` isn't called.
7. The label text, U+2011 in "Wi‑Fi": `InfoMessage` uses KOReader's UI font, not a look face, so the glyph
   question the sheets had doesn't arise; check it renders in the emulator once and use a plain hyphen if
   not.
8. **`main.lua`** requires `location_search`. **HOOKS.md:** `InputDialog`, `ButtonDialog`,
   `UIManager:forceRePaint`, `util.trim`, `util.urlEncode`, and the geocoding endpoint with the date its
   response was read.

## Surfaces

`kopanda.koplugin/location_search.lua` (new), `weather.lua`, `main.lua`, `HOOKS.md`,
`spec/fixtures/geocoding/*.json` (new). Specs: `spec/unit/location_search_spec.lua` (new),
`spec/unit/weather_spec.lua`, `spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `location_search_spec.lua` (C3), `socket.http` stubbed as `weather_spec.lua` stubs it (its
  `serve`, `serve_ok` and `serve_failure` helpers, `weather_spec.lua:48-66`), so no case reaches the network:
  - `url("  Chicago ")` and `url("New York")` (encoded space), no `countryCode`; `url("60614")` with
    `countryCode=US`; `url("606140")` and `url("6061A")` without;
  - `parse` of `chicago.json`: first candidate `{ name = "Chicago, Illinois", latitude = 41.85003,
    longitude = -87.65005 }`, which `Settings.validators.location` accepts; `none.json` gives `{}`;
    `"<html>"` gives `nil`; a result missing `latitude` is skipped; a result whose `admin1` equals its
    `name` reads "<name>, <country>";
  - `ask` offline (`isConnected` stubbed false): the Wi‑Fi note, `http.request` never called, `on_pick`
    never called;
  - `ask` online with `zip-60614.json` served: a `ButtonDialog` with one candidate row and Cancel; its tap
    calls `on_pick` once with exactly three fields;
  - `ask` online with `none.json`: the no-place note; with a 500: the couldn't-search note; neither calls
    `on_pick`;
  - `ask`'s Searching note is shown and painted before `http.request` runs (order of spies) and is closed
    after; no `scheduleIn` is called anywhere in the flow;
  - an empty query keeps the dialog and requests nothing.
- `weather_spec.lua` (C3): the existing timeout-reset cases pass through `Weather.get`; one case calls
  `Weather.get` directly with a raising request and sees the timeouts reset.
- `failsafe_spec.lua` (C15): `rapidjson.decode` raising inside `ask` is logged, closes the Searching
  note, and calls nothing.

## Edge cases

- The fetch blocks the UI up to the timeouts `Weather.get` sets (5 s connect, 10 s total,
  `weather.lua:75`); the Searching note is what the owner sees meanwhile.
- A ZIP outside the US needs a city name instead; the note for no result says what was searched.
- Results Open-Meteo returns in another script (`language=en` asks for English names): stored as given.
- Ten results at most (`count=10`); a `ButtonDialog` taller than the screen scrolls
  (`buttondialog.lua:53`, `:187-189`).
