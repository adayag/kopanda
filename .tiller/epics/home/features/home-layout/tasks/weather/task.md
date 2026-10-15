# Open-Meteo weather with a cached line, once per session and on tap

## Approach

1. **Schema.** Add `weather.location` (type `location`, the Chicago default from the feature, label
   "Weather location", group `weather`) and `weather.units` (choice Fahrenheit `fahrenheit` / Celsius
   `celsius`, default `fahrenheit`, group `weather`) between `layout.rows` and `quote.source`, which
   completes the seven-key order. Add the `location` validator. It returns false, never raises, unless
   the value is a table with exactly the keys `name`, `latitude` and `longitude`, where `name` is a
   non-empty string, `latitude` a number from −90 to 90 and `longitude` a number from −180 to 180.
2. **`kopanda.koplugin/weather.lua`** (module name checked against KOReader's, and against the
   `bookshelf` and `simpleui` folders in the emulator's `plugins/`, by `hooks_doc_spec.lua`; rename it if
   it collides):
   - `Weather.url(location, units)` builds the feature's forecast URL. Numbers are formatted with
     `%.5f`, so the URL is stable.
   - `Weather.fetch()`: `socketutil:set_timeout(5, 10)`, then
     `require("socket.http").request{ url, sink = socketutil.table_sink(chunks) }` looked up at call
     time, then `socketutil:reset_timeout()` on every path, including errors (`frontend/socketutil.lua:52-70`,
     `:98-115`; pattern `frontend/ui/wikipedia.lua:146-215`). It succeeds only on code 200 with non-nil
     headers and `rapidjson.decode` giving a table whose `current` has numeric `temperature_2m`,
     `weather_code` and `is_day`. On success it writes the cache and returns true. Otherwise it logs and
     returns false, leaving the cache untouched.
   - **Cache.** `settings/kopanda/weather.lua` through `LuaSettings:open` (`frontend/luasettings.lua:21-48`),
     with the directory created first because `flush` doesn't create it (`luasettings.lua:270-275`). This
     is the same handling as `state.lua`. Fields: `fetched_at`, `temperature`, `weather_code`, `is_day`,
     `units`, `latitude` and `longitude`.
   - `Weather.reading(now)` returns the cache when its units and coordinates match the settings, and nil
     otherwise.
   - `Weather.line(reading, now, look_id)` returns the condition word and the temperature text per look,
     plus the age suffix (none under 3600 s, whole hours under 48 h, whole days after). With no reading
     it returns "Weather needs Wi‑Fi".
   - **Session triggers**, with module state `attempted` and `succeeded` for the process:
     - `Weather.after_show(home)`, called by `home.lua` from a `UIManager:nextTick` scheduled in the
       settled callback (`home.lua:158-178`), fetches when `NetworkMgr:isConnected()` and not
       `attempted`, then `home:refresh()` on success.
     - `Home:onNetworkConnected` calls `Weather.on_connected(home)`, which fetches when `isConnected()`
       and not `succeeded`. The connected check matters: NetworkMgr broadcasts `NetworkConnected` at start
       when Wi‑Fi is up (`frontend/ui/network/manager.lua:152-154`), and the golden fixture relies on a
       stubbed `isConnected` to keep that from fetching.
       It returns nothing (`frontend/ui/widget/container/widgetcontainer.lua:80-107`).
     - `Weather.tap(home)` fetches at once when `isConnected()`, else
       `NetworkMgr:runWhenOnline(function() ... end)` (`frontend/ui/network/manager.lua:698-709`). On
       success it refreshes; on failure it shows `InfoMessage{ text = "Couldn't update the weather",
       timeout = 3 }`.
     - `NetworkMgr` is reached as `require("ui/network/manager")` at call time, so specs can stub it.
3. **`kopanda.koplugin/widgets/weather.lua`**, registered and required from `main.lua`, with
   `tap(ctx)` calling `Weather.tap(ctx.home)`:
   - Editorial: one line, "Partly cloudy, 61°" or "Partly cloudy, 61° · 3 h ago", in `type.weather`
     (label style, `muted`; Main:25).
   - Diner: the icon at 20 px through `RenderImage:renderSVGImageFile(Icons.path(is_day == 1 and "sun"
     or "moon"), w, h)` (`frontend/ui/renderimage.lua:338`), with no icon when there is no reading, then
     an 8 px gap and "61° partly cloudy" in `type.weather` (`strong`, 13, uppercase, tracking 0.06, `ink`;
     HomeRetro:48-51).
   - Left-aligned, truncated with an ellipsis to the column width.
4. `HOOKS.md` gains `NetworkMgr:isConnected`, `runWhenOnline`, `NetworkConnected`, `socketutil`,
   `socket.http`, `rapidjson`, `RenderImage:renderSVGImageFile` (if not already listed) and the
   `wifi_enable_action` behaviour behind `runWhenOnline`.

## Surfaces

`kopanda.koplugin/schema.lua`, `settings.lua`, `weather.lua` (new), `widgets/weather.lua` (new),
`widgets.lua`, `home.lua` (settled-callback hook, `onNetworkConnected`), `main.lua`,
`looks/editorial.lua`, `looks/diner.lua`, `HOOKS.md`; `spec/unit/weather_spec.lua` (new),
`spec/unit/schema_spec.lua` (the full seven-key list), `spec/unit/settings_spec.lua` (location
refusals).

## Tests

Written first and run failing. `socket.http.request` and `NetworkMgr` are stubbed with Busted `stub` and
reverted in `finally` (the pattern of KOReader's `spec/unit/opds_spec.lua:616-671`). `isOnline` is never
called and would do real DNS under the SDL device. Canned JSON is a trimmed copy of a real response.

- `weather_spec.lua` (C8):
  - URL contents for the default location in both units.
  - A 200 writes the cache, and a reopen reads it.
  - Lines for codes 0, 2, 3, 45, 61, 75, 95 and an unknown 42, with rounding of 61.5 and −0.4.
  - Ages at 59 min, 61 min, 47 h and 49 h.
  - A cache with other units or coordinates gives "Weather needs Wi‑Fi".
  - `after_show` connected fetches once across two shows; disconnected it neither fetches nor calls
    `runWhenOnline`.
  - `NetworkConnected` after a failure fetches when connected and does nothing when disconnected; after
    a success it does not fetch.
  - A tap connected fetches; disconnected it calls `runWhenOnline` once.
  - A timeout code, a 500, nil headers and `not json` each leave the cache file byte-identical, and on a
    tap show the message.
  - `set_timeout` and `reset_timeout` calls pair up on every path, including a raising `request`.
- `schema_spec.lua` (C1) now asserts the full seven-key list and the absence of `clock.twenty_four_hour`;
  `settings_spec.lua` (C2) gains the location refusals.
- `home_layout_spec.lua` (C4): after show, a stubbed fetch and refresh, no KoPanda task remains queued.

## Edge cases

- `runWhenOnline` drops the callback when connected but not online (`manager.lua:693-709`). That case is
  only reached when `isConnected()` was false at the tap, so the drop needs no handling beyond the log.
- The fetch blocks the UI for its duration. It runs only after the first paint and only on the triggers
  above, never in `build` or `paintTo`.
- A cache written by a newer plugin with extra fields still reads; a corrupt cache reads as no reading
  (LuaSettings falls back, `luasettings.lua:21-48`).
- `os.time()` jumping backwards (clock set on the device) gives a negative age, shown as no age.
