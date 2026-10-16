-- The place search (C3): the geocoding URL from a typed query, the candidates read from a
-- recorded Open-Meteo response, and the flow from the query dialog to on_pick. socket.http's
-- request and NetworkMgr are stubbed in every test; no test touches the network. The
-- responses under spec/fixtures/geocoding/ were read from the live endpoint on 2026-10-15.
describe("location search", function()
    local harness = require("plugin_harness")
    local NetworkMgr = require("ui/network/manager")
    local UIManager = require("ui/uimanager")
    local http = require("socket.http")
    local LocationSearch, Settings

    local BASE = "https://geocoding-api.open-meteo.com/v1/search?name="
    local TAIL = "&count=10&language=en&format=json"

    local function fixture(name)
        local f = assert(io.open(harness.root .. "/spec/fixtures/geocoding/" .. name, "rb"))
        local text = f:read("*a")
        f:close()
        return text
    end

    -- The URLs socket.http was asked for, in order; how it answers the next request; whether
    -- NetworkMgr reports a connection; the order of shows, paints, closes and requests; and
    -- the stubs, made in before_each and reverted in after_each.
    local requests, respond, net, events, stubs

    -- socket.http's request answers with code and headers, feeding body to the request's sink
    -- (weather_spec.lua's helpers).
    local function serve(code, headers, body)
        respond = function(request)
            if body then
                request.sink(body)
            end
            return 1, code, headers, "HTTP " .. tostring(code)
        end
    end

    local function serve_ok(body)
        serve(200, { ["content-type"] = "application/json" }, body)
    end

    -- The widget on the window stack whose field equals value, or nil.
    local function shown_with(field, value)
        for _, widget in ipairs(harness.stack()) do
            if widget[field] == value then
                return widget
            end
        end
        return nil
    end

    -- The texts of the InfoMessages on the window stack, top first.
    local function notes()
        local texts = {}
        for _, widget in ipairs(harness.stack()) do
            if type(widget.text) == "string" and widget.title == nil then
                texts[#texts + 1] = widget.text
            end
        end
        return texts
    end

    -- The button whose text is text in a ButtonTable's rows.
    local function button(button_table, text)
        for _, row in ipairs(button_table.buttons_layout) do
            for _, b in ipairs(row) do
                if b.text == text then
                    return b
                end
            end
        end
        error("no button " .. text)
    end

    -- The texts of a ButtonTable's buttons, one list per row.
    local function button_rows(button_table)
        local rows = {}
        for _, row in ipairs(button_table.buttons_layout) do
            local texts = {}
            for _, b in ipairs(row) do
                texts[#texts + 1] = b.text
            end
            rows[#rows + 1] = texts
        end
        return rows
    end

    local function query_dialog()
        return shown_with("title", "Weather location")
    end

    -- Opens the search, types query and taps Search. Returns the calls on_pick received.
    local function search_for(query)
        local picks = {}
        LocationSearch.ask(function(location)
            picks[#picks + 1] = location
        end)
        local dialog = assert(query_dialog(), "no query dialog")
        dialog:setInputText(query)
        button(dialog.button_table, "Search").callback()
        return picks
    end

    before_each(function()
        harness.load()
        LocationSearch = require("location_search")
        Settings = require("settings")
        requests = {}
        events = {}
        respond = function()
            error("kopanda-test: no response set")
        end
        net = { connected = true }
        local show, close, repaint = UIManager.show, UIManager.close, UIManager.forceRePaint
        stubs = {
            request = stub(http, "request", function(request)
                requests[#requests + 1] = request.url
                events[#events + 1] = "request"
                return respond(request)
            end),
            is_connected = stub(NetworkMgr, "isConnected", function()
                return net.connected
            end),
            is_online = stub(NetworkMgr, "isOnline", function()
                error("kopanda-test: isOnline called")
            end),
            show = stub(UIManager, "show", function(self, widget, ...)
                events[#events + 1] = "show " .. tostring(widget.text or widget.title)
                return show(self, widget, ...)
            end),
            close = stub(UIManager, "close", function(self, widget, ...)
                events[#events + 1] = "close " .. tostring(widget.text or widget.title)
                return close(self, widget, ...)
            end),
            repaint = stub(UIManager, "forceRePaint", function(self, ...)
                events[#events + 1] = "paint"
                return repaint(self, ...)
            end),
            schedule_in = spy.on(UIManager, "scheduleIn"),
        }
    end)

    after_each(function()
        for _, s in pairs(stubs) do
            s:revert()
        end
        harness.teardown()
    end)

    describe("url", function()
        it("trims the query and asks for ten English results", function()
            assert.equals(BASE .. "Chicago" .. TAIL, LocationSearch.url("  Chicago "))
        end)

        it("encodes the query", function()
            assert.equals(BASE .. "New%20York" .. TAIL, LocationSearch.url("New York"))
        end)

        it("limits exactly five digits to the US", function()
            assert.equals(BASE .. "60614" .. TAIL .. "&countryCode=US", LocationSearch.url("60614"))
            assert.equals(BASE .. "60614" .. TAIL .. "&countryCode=US", LocationSearch.url(" 60614 "))
            assert.equals(BASE .. "606140" .. TAIL, LocationSearch.url("606140"))
            assert.equals(BASE .. "6061A" .. TAIL, LocationSearch.url("6061A"))
            assert.equals(BASE .. "6061" .. TAIL, LocationSearch.url("6061"))
        end)
    end)

    describe("parse", function()
        it("reads the recorded Chicago response into candidates in the order returned", function()
            local candidates = LocationSearch.parse(fixture("chicago.json"))
            assert.equals(10, #candidates)
            local first = candidates[1]
            assert.same({ name = "Chicago, Illinois", latitude = 41.85003, longitude = -87.65005,
                shown = "Chicago, Illinois, United States" }, first)
            assert.equals("Willard, Ohio", candidates[2].name)
            assert.equals("Chicago, Jalisco, Mexico", candidates[5].shown)
            assert.is_true(Settings.validators.location(nil, {
                name = first.name, latitude = first.latitude, longitude = first.longitude }))
        end)

        it("reads a response with no results as none", function()
            assert.same({}, LocationSearch.parse(fixture("none.json")))
        end)

        it("reads text that is not JSON, or JSON that is not an object, as unreadable", function()
            local candidates, why = LocationSearch.parse("<html>")
            assert.is_nil(candidates)
            assert.is_string(why)
            assert.is_nil((LocationSearch.parse("42")))
        end)

        it("skips a result without a name or with a coordinate that is not a number", function()
            local body = '{"results":['
                .. '{"name":"Nolat","longitude":1.5,"country":"France"},'
                .. '{"name":"Strlat","latitude":"1.5","longitude":1.5},'
                .. '{"name":"","latitude":1.5,"longitude":1.5},'
                .. '{"latitude":1.5,"longitude":1.5},'
                .. '{"name":"Kept","latitude":1.5,"longitude":2.5}]}'
            assert.same({ { name = "Kept", latitude = 1.5, longitude = 2.5, shown = "Kept" } },
                LocationSearch.parse(body))
        end)

        it("names a place by its country when its admin1 is its own name or missing", function()
            local body = '{"results":['
                .. '{"name":"Berlin","admin1":"Berlin","country":"Germany","latitude":52.52,"longitude":13.41},'
                .. '{"name":"Monaco","country":"Monaco","latitude":43.73,"longitude":7.42},'
                .. '{"name":"Springfield","admin1":"Illinois","country":"","latitude":39.8,"longitude":-89.64}]}'
            local candidates = LocationSearch.parse(body)
            assert.same({ name = "Berlin, Germany", latitude = 52.52, longitude = 13.41,
                shown = "Berlin, Germany" }, candidates[1])
            assert.same({ name = "Monaco, Monaco", latitude = 43.73, longitude = 7.42, shown = "Monaco, Monaco" },
                candidates[2])
            assert.same({ name = "Springfield, Illinois", latitude = 39.8, longitude = -89.64,
                shown = "Springfield, Illinois" }, candidates[3])
        end)
    end)

    describe("search", function()
        it("fetches the query's URL and reads the response", function()
            serve_ok(fixture("zip-60614.json"))
            local candidates = LocationSearch.search("60614")
            assert.same({ LocationSearch.url("60614") }, requests)
            assert.equals(1, #candidates)
            assert.equals("Chicago, Illinois", candidates[1].name)
        end)

        it("returns nil and why for a failed request", function()
            serve(500, {}, "oops")
            local candidates, why = LocationSearch.search("Chicago")
            assert.is_nil(candidates)
            assert.is_string(why)
        end)
    end)

    describe("ask", function()
        it("asks for a city or ZIP code with Cancel and Search, the keyboard shown", function()
            local InputDialog = require("ui/widget/inputdialog")
            local show_keyboard = spy.on(InputDialog, "onShowKeyboard")
            finally(function()
                InputDialog.onShowKeyboard:revert()
            end)
            LocationSearch.ask(function() end)
            local dialog = assert(query_dialog())
            assert.equals("City or ZIP code", dialog.input_hint)
            assert.same({ { "Cancel", "Search" } }, button_rows(dialog.button_table))
            assert.spy(show_keyboard).was.called_with(match.is_ref(dialog))
        end)

        it("searches on Enter", function()
            serve_ok(fixture("zip-60614.json"))
            LocationSearch.ask(function() end)
            local dialog = assert(query_dialog())
            dialog:setInputText("60614")
            dialog.enter_callback()
            assert.same({ LocationSearch.url("60614") }, requests)
            assert.is_not_nil(shown_with("title", "Choose a place"))
        end)

        it("closes on Cancel, requesting nothing", function()
            LocationSearch.ask(function() end)
            button(query_dialog().button_table, "Cancel").callback()
            assert.is_nil(query_dialog())
            assert.same({}, requests)
        end)

        it("keeps the dialog and requests nothing for an empty query", function()
            local picks = search_for("   ")
            assert.is_not_nil(query_dialog())
            assert.same({}, requests)
            assert.same({}, picks)
        end)

        it("offline, says it needs Wi-Fi, requests nothing and picks nothing", function()
            net.connected = false
            local picks = search_for("Chicago")
            assert.is_nil(query_dialog())
            assert.same({ "Finding a place needs Wi-Fi." }, notes())
            assert.same({}, requests)
            assert.same({}, picks)
        end)

        it("offers one row per candidate and Cancel, and a tap picks exactly three fields", function()
            serve_ok(fixture("zip-60614.json"))
            local picks = search_for("60614")
            assert.same({ LocationSearch.url("60614") }, requests)
            local chooser = assert(shown_with("title", "Choose a place"))
            assert.same({ { "Chicago, Illinois, United States" }, { "Cancel" } }, button_rows(chooser.buttontable))
            assert.same({}, picks)
            button(chooser.buttontable, "Chicago, Illinois, United States").callback()
            assert.is_nil(shown_with("title", "Choose a place"))
            assert.same({ { name = "Chicago, Illinois", latitude = 41.85003, longitude = -87.65005 } }, picks)
        end)

        it("picks nothing when the chooser is cancelled", function()
            serve_ok(fixture("chicago.json"))
            local picks = search_for("Chicago")
            local chooser = assert(shown_with("title", "Choose a place"))
            assert.equals(11, #button_rows(chooser.buttontable))
            button(chooser.buttontable, "Cancel").callback()
            assert.is_nil(shown_with("title", "Choose a place"))
            assert.same({}, picks)
        end)

        it("says no place was found for the query, and picks nothing", function()
            serve_ok(fixture("none.json"))
            local picks = search_for(" Xqzvbnmkw ")
            assert.same({ "No place found for “Xqzvbnmkw”." }, notes())
            assert.is_nil(shown_with("title", "Choose a place"))
            assert.same({}, picks)
        end)

        it("says it couldn't search on a failed request, and picks nothing", function()
            serve(500, {}, "oops")
            local picks = search_for("Chicago")
            assert.same({ "Couldn't search for places." }, notes())
            assert.is_nil(shown_with("title", "Choose a place"))
            assert.same({}, picks)
        end)

        it("shows and paints the searching note before the request, and closes it after", function()
            serve_ok(fixture("zip-60614.json"))
            search_for("60614")
            local function at(event)
                for i, e in ipairs(events) do
                    if e == event then
                        return i
                    end
                end
                error("no event " .. event .. " in " .. table.concat(events, ", "))
            end
            assert.is_true(at("show Searching…") < at("paint"))
            assert.is_true(at("paint") < at("request"))
            assert.is_true(at("request") < at("close Searching…"))
            assert.is_nil(shown_with("text", "Searching…"))
            assert.spy(stubs.schedule_in).was_not.called()
        end)

        it("schedules nothing on any path", function()
            serve(500, {}, "oops")
            search_for("Chicago")
            net.connected = false
            search_for("Chicago")
            serve_ok(fixture("none.json"))
            net.connected = true
            search_for("Chicago")
            assert.spy(stubs.schedule_in).was_not.called()
        end)
    end)
end)
