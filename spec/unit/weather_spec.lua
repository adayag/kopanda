-- Open-Meteo weather (C8): the request URL, the cache in settings/kopanda/weather.lua, the line
-- per look with its age, the session's fetch triggers (after the show, NetworkConnected, a tap),
-- failures leaving the cache as it was, and the widget's icon and text. socket.http's request
-- and NetworkMgr are stubbed in every test; no test touches the network.
describe("weather", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local NetworkMgr = require("ui/network/manager")
    local UIManager = require("ui/uimanager")
    local http = require("socket.http")
    local socketutil = require("socketutil")
    local cache_file = harness.state_dir .. "/weather.lua"
    local Weather, Settings

    local NEEDS_WIFI = "Weather needs Wi\u{2011}Fi"
    local CHICAGO = { name = "Chicago, Illinois", latitude = 41.85003, longitude = -87.65005 }

    -- A trimmed copy of a real response for the default location in °F (2026-10-15). The
    -- latitude and longitude it echoes are the model grid's, not the ones asked for.
    local BODY = '{"latitude":41.85271,"longitude":-87.65361,"utc_offset_seconds":-18000,'
        .. '"timezone":"America/Chicago","current_units":{"time":"iso8601","interval":"seconds",'
        .. '"temperature_2m":"°F","weather_code":"wmo code","is_day":""},'
        .. '"current":{"time":"2026-10-15T09:15","interval":900,"temperature_2m":58.4,"weather_code":3,"is_day":1}}'

    local function read(path)
        local f = io.open(path, "rb")
        if not f then
            return nil
        end
        local text = f:read("*a")
        f:close()
        return text
    end

    local function write(path, text)
        require("libs/libkoreader-lfs").mkdir(harness.state_dir)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    -- The URLs socket.http was asked for, in order; how it answers the next request; whether
    -- NetworkMgr reports a connection; and the stubs, made in before_each and reverted in
    -- after_each.
    local requests, respond, net, stubs

    -- socket.http's request answers with code and headers, feeding body to the request's sink.
    local function serve(code, headers, body)
        respond = function(request)
            if body then
                request.sink(body)
            end
            return 1, code, headers, "HTTP " .. tostring(code)
        end
    end

    local function serve_ok(body)
        serve(200, { ["content-type"] = "application/json" }, body or BODY)
    end

    -- socket.http's request returns nil and err, as LuaSocket does on a timeout.
    local function serve_failure(err)
        respond = function()
            return nil, err
        end
    end

    -- NetworkMgr reports connected (or not). Returns the runWhenOnline stub, which records its
    -- callback and doesn't run it.
    local function network(connected)
        net.connected = connected
        return stubs.run_when_online
    end

    -- The messages UIManager:show was given, by text.
    local function messages()
        local shown = {}
        local s = stub(UIManager, "show", function(_, widget)
            shown[#shown + 1] = { text = widget.text, timeout = widget.timeout }
        end)
        finally(function()
            s:revert()
        end)
        return shown
    end

    -- A stand-in for the home, counting refreshes.
    local function fake_home()
        local home = { refreshed = 0 }
        function home:refresh()
            self.refreshed = self.refreshed + 1
        end
        return home
    end

    local function reading(fields)
        local r = {
            fetched_at = 1000000,
            temperature = 61.4,
            weather_code = 2,
            is_day = 1,
            units = "fahrenheit",
            latitude = CHICAGO.latitude,
            longitude = CHICAGO.longitude,
        }
        for k, v in pairs(fields or {}) do
            r[k] = v
        end
        return r
    end

    -- The cache file's text holding r.
    local function cache_text(r)
        local parts = {}
        for _, k in ipairs({ "fetched_at", "temperature", "weather_code", "is_day", "latitude", "longitude" }) do
            parts[#parts + 1] = string.format("[%q] = %s", k, tostring(r[k]))
        end
        parts[#parts + 1] = string.format("[\"units\"] = %q", r.units)
        for k, v in pairs(r) do
            if k == "extra" then
                parts[#parts + 1] = string.format("[\"extra\"] = %q", v)
            end
        end
        return "return { " .. table.concat(parts, ", ") .. " }\n"
    end

    before_each(function()
        harness.load()
        Weather = require("weather")
        Settings = require("settings")
        requests = {}
        respond = function()
            error("kopanda-test: no response set")
        end
        net = { connected = false }
        stubs = {
            request = stub(http, "request", function(request)
                requests[#requests + 1] = request.url
                return respond(request)
            end),
            is_connected = stub(NetworkMgr, "isConnected", function()
                return net.connected
            end),
            run_when_online = stub(NetworkMgr, "runWhenOnline"),
            -- A DNS lookup on this device; nothing may call it.
            is_online = stub(NetworkMgr, "isOnline", function()
                error("kopanda-test: isOnline called")
            end),
        }
    end)

    after_each(function()
        for _, s in pairs(stubs) do
            s:revert()
        end
        harness.teardown()
        os.remove(cache_file)
        os.remove(cache_file .. ".old")
    end)

    describe("url", function()
        it("asks for the current temperature, code and day flag at the coordinates in the units", function()
            local base = "https://api.open-meteo.com/v1/forecast?latitude=41.85003&longitude=-87.65005"
                .. "&current=temperature_2m,weather_code,is_day&temperature_unit="
            assert.equals(base .. "fahrenheit&timezone=auto", Weather.url(CHICAGO, "fahrenheit"))
            assert.equals(base .. "celsius&timezone=auto", Weather.url(CHICAGO, "celsius"))
        end)

        it("formats the coordinates to five places", function()
            local url = Weather.url({ name = "x", latitude = -33.9, longitude = 151.2 }, "celsius")
            assert.truthy(url:find("latitude=-33.90000&longitude=151.20000&", 1, true), url)
        end)
    end)

    describe("fetch", function()
        it("asks for the stored location and units", function()
            local sydney = { name = "Sydney", latitude = -33.86785, longitude = 151.20732 }
            assert.is_true(Settings.set("weather.location", sydney))
            assert.is_true(Settings.set("weather.units", "celsius"))
            serve_ok()
            assert.is_true(Weather.fetch())
            assert.same({ Weather.url(sydney, "celsius") }, requests)
        end)

        it("caches a 200 with the time of the fetch, the units and the coordinates asked for", function()
            serve_ok()
            local before = os.time()
            assert.is_true(Weather.fetch())
            local after = os.time()
            local cached = dofile(cache_file)
            assert.is_true(cached.fetched_at >= before and cached.fetched_at <= after)
            assert.equals(58.4, cached.temperature)
            assert.equals(3, cached.weather_code)
            assert.equals(1, cached.is_day)
            assert.equals("fahrenheit", cached.units)
            assert.equals(CHICAGO.latitude, cached.latitude)
            assert.equals(CHICAGO.longitude, cached.longitude)
        end)

        it("is read back after a reopen", function()
            serve_ok()
            assert.is_true(Weather.fetch())
            package.loaded["weather"] = nil
            Weather = require("weather")
            local r = Weather.reading()
            assert.is_table(r)
            assert.equals(58.4, r.temperature)
            assert.equals(3, r.weather_code)
        end)

        local failures = {
            ["a timeout"] = function()
                serve_failure(socketutil.TIMEOUT_CODE)
            end,
            ["a sink timeout"] = function()
                serve_failure(socketutil.SINK_TIMEOUT_CODE)
            end,
            ["a 500"] = function()
                serve(500, {}, "oops")
            end,
            ["nil headers"] = function()
                serve(200, nil, BODY)
            end,
            ["a body that is not json"] = function()
                serve_ok("not json")
            end,
            ["a body with no current"] = function()
                serve_ok('{"latitude":41.85}')
            end,
            ["a current with a string temperature"] = function()
                serve_ok('{"current":{"temperature_2m":"58","weather_code":3,"is_day":1}}')
            end,
            ["a current with no weather code"] = function()
                serve_ok('{"current":{"temperature_2m":58.4,"is_day":1}}')
            end,
            ["a request that raises"] = function()
                respond = function()
                    error("kopanda-test: request raised")
                end
            end,
        }

        it("leaves the cache file byte-identical on every failure", function()
            local text = cache_text(reading())
            for what, setup in pairs(failures) do
                write(cache_file, text)
                setup()
                local ok, fetched = pcall(Weather.fetch)
                assert.is_true(ok, what .. ": " .. tostring(fetched))
                assert.is_false(fetched, what)
                assert.equals(text, read(cache_file), what)
            end
        end)

        it("writes no cache on a failure with none there", function()
            serve(500, {}, "oops")
            assert.is_false(Weather.fetch())
            assert.is_nil(read(cache_file))
        end)

        it("resets socketutil's timeout after setting it, on every path", function()
            local set = spy.on(socketutil, "set_timeout")
            local reset = spy.on(socketutil, "reset_timeout")
            finally(function()
                socketutil.set_timeout:revert()
                socketutil.reset_timeout:revert()
            end)
            local paths = 0
            for _, setup in pairs(failures) do
                setup()
                Weather.fetch()
                paths = paths + 1
            end
            serve_ok()
            Weather.fetch()
            paths = paths + 1
            assert.spy(set).was.called(paths)
            assert.spy(reset).was.called(paths)
            assert.spy(set).was.called_with(match.is_ref(socketutil), 5, 10)
            assert.equals(socketutil.DEFAULT_BLOCK_TIMEOUT, socketutil.block_timeout)
            assert.equals(socketutil.DEFAULT_TOTAL_TIMEOUT, socketutil.total_timeout)
        end)
    end)

    describe("reading", function()
        it("is the cache when its units and coordinates match the settings", function()
            write(cache_file, cache_text(reading()))
            local r = Weather.reading()
            assert.is_table(r)
            assert.equals(61.4, r.temperature)
        end)

        it("still reads a cache with fields it doesn't know", function()
            write(cache_file, cache_text(reading({ extra = "from a newer plugin" })))
            assert.is_table(Weather.reading())
        end)

        it("is nil for a cache in other units or at other coordinates", function()
            for what, fields in pairs({
                ["celsius"] = { units = "celsius" },
                ["another latitude"] = { latitude = 41.9 },
                ["another longitude"] = { longitude = -87.6 },
            }) do
                write(cache_file, cache_text(reading(fields)))
                assert.is_nil(Weather.reading(), what)
                assert.equals(NEEDS_WIFI, Weather.line(Weather.reading(), 1000000, "editorial"), what)
            end
        end)

        it("is nil with no cache and with a corrupt one", function()
            assert.is_nil(Weather.reading())
            write(cache_file, "this is not lua {{{")
            assert.is_nil(Weather.reading())
            write(cache_file, 'return { temperature = "warm" }')
            assert.is_nil(Weather.reading())
        end)
    end)

    describe("line", function()
        local now = 1000000

        it("names the condition from the WMO code in each look", function()
            local cases = {
                { 0, "Clear, 61°", "61° clear" },
                { 2, "Partly cloudy, 61°", "61° partly cloudy" },
                { 3, "Overcast, 61°", "61° overcast" },
                { 45, "Fog, 61°", "61° fog" },
                { 61, "Rain, 61°", "61° rain" },
                { 75, "Snow, 61°", "61° snow" },
                { 95, "Thunderstorm, 61°", "61° thunderstorm" },
                { 42, "61°", "61°" },
            }
            for _, case in ipairs(cases) do
                local r = reading({ weather_code = case[1], fetched_at = now })
                assert.equals(case[2], Weather.line(r, now, "editorial"), "code " .. case[1])
                assert.equals(case[3], Weather.line(r, now, "diner"), "code " .. case[1])
            end
        end)

        it("rounds the temperature to a whole degree", function()
            assert.equals("62°", Weather.line(reading({ temperature = 61.5, weather_code = 42, fetched_at = now }), now,
                "editorial"))
            assert.equals("0° clear", Weather.line(reading({ temperature = -0.4, weather_code = 0, fetched_at = now }),
                now, "diner"))
            assert.equals("-1° clear", Weather.line(reading({ temperature = -0.6, weather_code = 0, fetched_at = now }),
                now, "diner"))
        end)

        it("adds the age once the reading is an hour old, in hours under two days and days after", function()
            local function aged(seconds, look)
                return Weather.line(reading({ fetched_at = now - seconds }), now, look)
            end
            assert.equals("Partly cloudy, 61°", aged(59 * 60, "editorial"))
            assert.equals("Partly cloudy, 61° · 1 h ago", aged(61 * 60, "editorial"))
            assert.equals("Partly cloudy, 61° · 47 h ago", aged(47 * 3600, "editorial"))
            assert.equals("Partly cloudy, 61° · 2 d ago", aged(49 * 3600, "editorial"))
            assert.equals("61° partly cloudy · 3 h ago", aged(3 * 3600 + 5, "diner"))
        end)

        it("shows no age for a reading from the future", function()
            assert.equals("Partly cloudy, 61°", Weather.line(reading({ fetched_at = now + 7200 }), now, "editorial"))
        end)

        it("says the weather needs Wi-Fi with no reading", function()
            assert.equals(NEEDS_WIFI, Weather.line(nil, now, "editorial"))
            assert.equals(NEEDS_WIFI, Weather.line(nil, now, "diner"))
        end)
    end)

    describe("after_show", function()
        it("fetches once per process when connected, refreshing the home", function()
            network(true)
            serve_ok()
            local home = fake_home()
            Weather.after_show(home)
            Weather.after_show(home)
            assert.equals(1, #requests)
            assert.equals(1, home.refreshed)
        end)

        it("does not fetch again after a failed attempt", function()
            network(true)
            serve(500, {}, "oops")
            local home = fake_home()
            Weather.after_show(home)
            Weather.after_show(home)
            assert.equals(1, #requests)
            assert.equals(0, home.refreshed)
        end)

        it("neither fetches nor prompts when disconnected", function()
            local run_when_online = network(false)
            serve_ok()
            Weather.after_show(fake_home())
            assert.equals(0, #requests)
            assert.stub(run_when_online).was_not.called()
        end)

        it("runs from the shown home after its settled signal", function()
            network(true)
            local settled_at_request
            respond = function(request)
                local Home = package.loaded["home"]
                settled_at_request = Home.shown and Home.shown.settled
                request.sink(BODY)
                return 1, 200, {}, "HTTP 200"
            end
            harness.show_fm()
            harness.tick(4)
            assert.equals(1, #requests)
            assert.is_true(settled_at_request)
            assert.is_table(Weather.reading())
        end)
    end)

    describe("on_connected", function()
        it("fetches after a failed attempt when connected", function()
            network(true)
            serve(500, {}, "oops")
            Weather.after_show(fake_home())
            assert.equals(1, #requests)
            local home = fake_home()
            Weather.on_connected(home)
            assert.equals(2, #requests)
            assert.equals(0, home.refreshed)
        end)

        it("does nothing when disconnected", function()
            local run_when_online = network(false)
            serve_ok()
            Weather.on_connected(fake_home())
            assert.equals(0, #requests)
            assert.stub(run_when_online).was_not.called()
        end)

        it("does not fetch after a success", function()
            network(true)
            serve_ok()
            local home = fake_home()
            Weather.after_show(home)
            Weather.on_connected(home)
            assert.equals(1, #requests)
            assert.equals(1, home.refreshed)
        end)

        it("is what the shown home does on NetworkConnected, returning nothing", function()
            network(false)
            serve_ok()
            harness.show_fm()
            harness.tick(4)
            local home = package.loaded["home"].shown
            assert.is_table(home)
            assert.equals(0, #requests)
            network(true)
            assert.is_falsy((home:handleEvent(Event:new("NetworkConnected"))))
            assert.equals(1, #requests)
            UIManager:broadcastEvent(Event:new("NetworkConnected"))
            assert.equals(1, #requests)
        end)
    end)

    describe("tap", function()
        it("fetches at once when connected, refreshing the home", function()
            local run_when_online = network(true)
            serve_ok()
            local home = fake_home()
            Weather.tap(home)
            assert.equals(1, #requests)
            assert.equals(1, home.refreshed)
            assert.stub(run_when_online).was_not.called()
        end)

        it("fetches on every tap, after a success too", function()
            network(true)
            serve_ok()
            local home = fake_home()
            Weather.after_show(home)
            Weather.tap(home)
            Weather.tap(home)
            assert.equals(3, #requests)
        end)

        it("asks NetworkMgr to run the fetch once online when disconnected", function()
            local run_when_online = network(false)
            serve_ok()
            local home = fake_home()
            Weather.tap(home)
            assert.equals(0, #requests)
            assert.stub(run_when_online).was.called(1)
            local callback = run_when_online.calls[1].vals[2]
            assert.is_function(callback)
            callback()
            assert.equals(1, #requests)
            assert.equals(1, home.refreshed)
        end)

        it("shows that the update failed, and keeps the cache, on each failure", function()
            network(true)
            local text = cache_text(reading())
            local shown = messages()
            for i, setup in ipairs({
                function()
                    serve_failure(socketutil.TIMEOUT_CODE)
                end,
                function()
                    serve(500, {}, "oops")
                end,
                function()
                    serve(200, nil, BODY)
                end,
                function()
                    serve_ok("not json")
                end,
            }) do
                write(cache_file, text)
                setup()
                local home = fake_home()
                Weather.tap(home)
                assert.equals(text, read(cache_file), "case " .. i)
                assert.equals(0, home.refreshed, "case " .. i)
                assert.same({ text = "Couldn't update the weather", timeout = 3 }, shown[i], "case " .. i)
            end
            assert.equals(4, #shown)
        end)
    end)

    describe("the widget", function()
        local Looks, Icons, Widgets

        before_each(function()
            Looks = require("looks")
            Icons = require("icons")
            Widgets = require("widgets")
        end)

        local function ctx(look_id, home)
            return {
                look = Looks.get(look_id),
                variant = "day",
                text_size = "medium",
                now = 1000000,
                screen = require("device").screen,
                home = home,
            }
        end

        -- Every widget in the tree under widget for which pick is true.
        local function find(widget, pick, found)
            found = found or {}
            if type(widget) ~= "table" then
                return found
            end
            if pick(widget) then
                found[#found + 1] = widget
            end
            for _, child in ipairs(widget) do
                find(child, pick, found)
            end
            return found
        end

        -- The text drawn under widget, its pieces joined in order (a tracked line is set a
        -- character at a time).
        local function drawn(widget)
            local out = {}
            for _, w in ipairs(find(widget, function(w)
                return type(w.text) == "string"
            end)) do
                out[#out + 1] = w.text
            end
            return table.concat(out)
        end

        local function icons(widget)
            local out = {}
            for _, w in ipairs(find(widget, function(w)
                return w.is_icon == true
            end)) do
                out[#out + 1] = w.file
            end
            return out
        end

        it("is registered as weather, with a tap", function()
            local module = Widgets.get("weather")
            assert.is_table(module)
            assert.equals("weather", module.id)
            assert.is_function(module.tap)
        end)

        it("taps through to the fetch with the home", function()
            local module = Widgets.get("weather")
            local s = stub(Weather, "tap")
            finally(function()
                s:revert()
            end)
            local home = fake_home()
            module.tap(ctx("diner", home))
            assert.stub(s).was.called(1)
            assert.equals(home.refreshed, s.calls[1].vals[1].refreshed)
        end)

        it("draws Diner's sun by day and moon by night beside the uppercased line", function()
            local module = Widgets.get("weather")
            write(cache_file, cache_text(reading({ fetched_at = 1000000 })))
            local built = module.build(300, ctx("diner"))
            assert.equals(300, built:getSize().w)
            assert.same({ Icons.path("sun") }, icons(built))
            assert.equals("61° PARTLY CLOUDY", drawn(built))
            write(cache_file, cache_text(reading({ fetched_at = 1000000, is_day = 0 })))
            assert.same({ Icons.path("moon") }, icons(module.build(300, ctx("diner"))))
        end)

        it("draws Editorial's line without an icon", function()
            local module = Widgets.get("weather")
            write(cache_file, cache_text(reading({ fetched_at = 1000000 })))
            local built = module.build(300, ctx("editorial"))
            assert.equals(300, built:getSize().w)
            assert.same({}, icons(built))
            assert.equals("PARTLY CLOUDY, 61°", drawn(built))
        end)

        it("draws the Wi-Fi line with no icon when nothing is cached", function()
            local module = Widgets.get("weather")
            local built = module.build(300, ctx("diner"))
            assert.same({}, icons(built))
            assert.equals(NEEDS_WIFI:upper(), drawn(built))
        end)

        it("truncates a long line to the column and measures what it builds", function()
            local module = Widgets.get("weather")
            write(cache_file, cache_text(reading({ fetched_at = 1000000 - 30 * 3600 })))
            for _, look in ipairs({ "diner", "editorial" }) do
                local c = ctx(look)
                local h = module.height(60, c)
                local built = module.build(60, c)
                assert.equals(60, built:getSize().w, look)
                assert.is_true(built[1]:getSize().w <= 60, look)
                local cut = find(built, function(w)
                    return type(w.text) == "string" and w:isTruncated()
                end)
                assert.equals(1, #cut, look)
                assert.equals(h, built:getSize().h, look)
            end
        end)
    end)
end)
