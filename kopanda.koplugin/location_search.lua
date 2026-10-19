-- The place search the settings menu's location row runs: a typed city or ZIP code, Open-Meteo's
-- geocoding endpoint, and a choice among the places it returns. It writes nothing itself; the
-- caller's on_pick gets the chosen { name, latitude, longitude }. The fetch blocks the UI for
-- its duration, at most the timeouts Weather.get sets, so a note says so while it runs.
local ButtonDialog = require("ui/widget/buttondialog")
local Helpers = require("helpers")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local Weather = require("weather")
local logger = require("logger")
local rapidjson = require("rapidjson")
local util = require("util")

local LocationSearch = {}

-- The geocoding URL for query, trimmed and encoded (frontend/util.lua:52, :1443). Exactly five
-- digits is a US ZIP code, which also matches places abroad, so it is limited to the US.
function LocationSearch.url(query)
    local q = util.trim(query)
    local url = "https://geocoding-api.open-meteo.com/v1/search?name=" .. util.urlEncode(q)
        .. "&count=10&language=en&format=json"
    if q:match("^%d%d%d%d%d$") then
        url = url .. "&countryCode=US"
    end
    return url
end

local function text(value)
    return type(value) == "string" and value ~= ""
end

-- The candidates in a geocoding response, in the order returned: { name, latitude, longitude,
-- shown }, name as stored ("Chicago, Illinois") and shown as the chooser's button reads
-- ("Chicago, Illinois, United States"). A result without a name or with a coordinate that is
-- not a number is skipped; a response with no results is none. Nil and why for a body that is
-- not a JSON object.
function LocationSearch.parse(body)
    local ok, data = pcall(rapidjson.decode, body)
    if not ok then
        return nil, "unreadable: " .. tostring(data)
    end
    if type(data) ~= "table" then
        return nil, "unreadable"
    end
    local candidates = {}
    if type(data.results) ~= "table" then
        return candidates
    end
    for _, result in ipairs(data.results) do
        local name, latitude, longitude = result.name, result.latitude, result.longitude
        if text(name) and type(latitude) == "number" and type(longitude) == "number" then
            local stored = name
            if text(result.admin1) and result.admin1 ~= name then
                stored = name .. ", " .. result.admin1
            elseif text(result.country) then
                stored = name .. ", " .. result.country
            end
            local shown = stored
            local last_part = stored:match("[^,]*$"):gsub("^%s+", "")
            if text(result.country) and result.country ~= last_part then
                shown = stored .. ", " .. result.country
            end
            candidates[#candidates + 1] = { name = stored, latitude = latitude, longitude = longitude, shown = shown }
        end
    end
    return candidates
end

-- The candidates for query, or nil and why when the request fails or its body is unreadable.
function LocationSearch.search(query)
    local body, why = Weather.get(LocationSearch.url(query))
    if not body then
        return nil, why
    end
    return LocationSearch.parse(body)
end

-- NetworkMgr, looked up at call time so a spec can stub it.
local function network()
    return require("ui/network/manager")
end

-- Asks for a place and calls on_pick with the chosen { name, latitude, longitude }: the query
-- dialog, then offline a note, else a searching note over the blocking fetch, then a note for
-- no result or a failure, or a chooser with one row per candidate. Every step is guarded: an
-- error is logged, the flow's open dialogs close, and on_pick isn't called.
function LocationSearch.ask(on_pick)
    -- The dialogs this flow has shown and not yet closed.
    local open = {}
    local function show(widget)
        open[widget] = true
        UIManager:show(widget)
        return widget
    end
    local function close(widget)
        open[widget] = nil
        UIManager:close(widget)
    end
    local function guarded(fn)
        return function()
            local ok, err = pcall(fn)
            if not ok then
                logger.err("KoPanda: the place search failed:", err)
                for widget in pairs(open) do
                    open[widget] = nil
                    pcall(UIManager.close, UIManager, widget)
                end
            end
        end
    end

    local function choose(candidates)
        local chooser
        local buttons = {}
        for _, candidate in ipairs(candidates) do
            buttons[#buttons + 1] = { {
                text = candidate.shown,
                callback = guarded(function()
                    close(chooser)
                    on_pick({ name = candidate.name, latitude = candidate.latitude, longitude = candidate.longitude })
                end),
            } }
        end
        buttons[#buttons + 1] = { {
            text = "Cancel",
            callback = guarded(function()
                close(chooser)
            end),
        } }
        chooser = show(ButtonDialog:new{ title = "Choose a place", buttons = buttons })
    end

    local function run(query)
        if not network():isConnected() then
            -- A plain hyphen, though the spec writes U+2011: no plugin source holds one (fonts_spec.lua).
            Helpers.note("Finding a place needs Wi-Fi.")
            return
        end
        -- Painted now: the fetch blocks the UI loop that would paint it (frontend/ui/uimanager.lua:1404).
        local searching = show(InfoMessage:new{ text = "Searching…" })
        UIManager:forceRePaint()
        local candidates, why = LocationSearch.search(query)
        close(searching)
        if not candidates then
            logger.warn("KoPanda: could not search for places:", why)
            Helpers.note("Couldn't search for places.")
        elseif #candidates == 0 then
            Helpers.note("No place found for “" .. query .. "”.")
        else
            choose(candidates)
        end
    end

    guarded(function()
        local dialog
        dialog = show(InputDialog:new{
            title = "Weather location",
            input_hint = "City or ZIP code",
            buttons = { {
                {
                    text = "Cancel",
                    id = "close",
                    callback = guarded(function()
                        close(dialog)
                    end),
                },
                {
                    text = "Search",
                    is_enter_default = true,
                    callback = guarded(function()
                        local query = util.trim(dialog:getInputText())
                        if query == "" then
                            return
                        end
                        close(dialog)
                        run(query)
                    end),
                },
            } },
        })
        dialog:onShowKeyboard()
    end)()
end

return LocationSearch
