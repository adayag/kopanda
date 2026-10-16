-- The settings menu's rows, generated from schema.lua: one TouchMenu item per key, in schema
-- order, for KOReader's own menu (Tools › KoPanda › Settings) and for settings_menu.lua. Each
-- type has one row builder; a row's text is read on every redraw, so it follows the stored value.
-- A tap that changes a value writes it through Settings.set, then refreshes a shown home once,
-- after one weather fetch when the write makes the cached reading stale. Every function TouchMenu
-- calls is guarded: an error is logged and gives a safe answer, and nothing is written after it.
-- Module state: the types already logged as having no row builder, so each is logged once.
local FeaturedBook = require("featured_book")
local InfoMessage = require("ui/widget/infomessage")
local Schema = require("schema")
local Settings = require("settings")
local UIManager = require("ui/uimanager")
local Weather = require("weather")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")

local SchemaMenu = {}

local logged_types = {}

-- The keys whose write makes the cached weather reading stale (weather.lua:146-150).
local WEATHER_KEYS = { ["weather.location"] = true, ["weather.units"] = true }

-- f wrapped so an error is logged as what and gives fallback instead.
local function guarded(what, fallback, f)
    return function(...)
        local ok, result = pcall(f, ...)
        if not ok then
            logger.err("KoPanda: the settings menu's " .. what .. " failed:", result)
            return fallback
        end
        return result
    end
end

-- No timeout, so no timer (frontend/ui/widget/infomessage.lua:53, :283-290).
local function note(text)
    UIManager:show(InfoMessage:new{ text = text })
end

-- NetworkMgr, looked up at call time so a spec can stub it.
local function network()
    return require("ui/network/manager")
end

-- Stores value under entry's key unless it is already stored. A refused write is logged and
-- noted; a done one re-lays the file browser out for a new look, then refreshes a shown home
-- once, after one weather fetch when it changed the weather's place or units while connected.
-- home is required here, not at load: it reaches home_gestures, which requires settings_menu,
-- which requires this module; fm_nav is required here as home is.
local function write(entry, value)
    if util.tableEquals(Settings.get(entry.id), value) then
        return
    end
    local ok, why = Settings.set(entry.id, value)
    if not ok then
        logger.err("KoPanda: could not save " .. entry.id .. ":", why)
        note("Couldn't save " .. entry.label .. ".")
        return
    end
    if entry.id == "look" then
        require("fm_nav").relayout()
    end
    local home = require("home").shown
    if not home then
        return
    end
    if WEATHER_KEYS[entry.id] and network():isConnected() then
        Weather.fetch()
    end
    home:refresh()
end

-- The row text "label · value", the label alone when reading the value fails.
local function text_func(entry, value_text)
    return guarded(entry.id .. " row text", entry.label, function()
        return entry.label .. " · " .. value_text()
    end)
end

-- A callback for a row that opens a screen: TouchMenu closes itself after the callback
-- (frontend/ui/widget/touchmenu.lua:920-926), so the screen opens from the next tick, as
-- main.lua's after_menu defers. The module is required then, not at load: edit_layout requires
-- home, which reaches this module.
local function open_screen(entry, module)
    local open = guarded(entry.id .. " screen", nil, function()
        require(module).open{}
    end)
    return guarded(entry.id .. " row", nil, function()
        UIManager:nextTick(open)
    end)
end

local function is_file(path)
    return type(path) == "string" and lfs.attributes(path, "mode") == "file"
end

-- One builder per schema type: entry -> TouchMenu item (frontend/ui/widget/touchmenu.lua:73-96,
-- :892-926).
local BUILDERS = {}

-- The stored choice's label; a radio submenu of the choices, the stored one checked.
function BUILDERS.choice(entry)
    local function label_of(value)
        for _, choice in ipairs(entry.choices) do
            if choice.value == value then
                return choice.label
            end
        end
        return tostring(value)
    end
    return {
        text_func = text_func(entry, function()
            return label_of(Settings.get(entry.id))
        end),
        sub_item_table_func = guarded(entry.id .. " choices", {}, function()
            local sub = {}
            for i, choice in ipairs(entry.choices) do
                sub[i] = {
                    text = choice.label,
                    radio = true,
                    checked_func = guarded(entry.id .. " check", false, function()
                        return Settings.get(entry.id) == choice.value
                    end),
                    callback = guarded(entry.id .. " choice", nil, function()
                        write(entry, choice.value)
                    end),
                }
            end
            return sub
        end),
    }
end

-- KOReader's check mark; a tap writes the negation.
function BUILDERS.boolean(entry)
    return {
        text = entry.label,
        checked_func = guarded(entry.id .. " check", false, function()
            return Settings.get(entry.id) == true
        end),
        callback = guarded(entry.id .. " toggle", nil, function()
            write(entry, not Settings.get(entry.id))
        end),
    }
end

-- The featured book's pin: "Most recent" unless it names a file that is there, which
-- FeaturedBook reads as unpinned (featured_book.lua:65-78). Its submenu unpins, and offers the
-- pinned book while it is there; pinning stays on the book sheet.
function BUILDERS.path(entry)
    local function title(pin)
        return FeaturedBook.describe(pin).title
    end
    return {
        text_func = text_func(entry, function()
            local pin = Settings.get(entry.id)
            return is_file(pin) and title(pin) or "Most recent"
        end),
        sub_item_table_func = guarded(entry.id .. " choices", {}, function()
            local pin = Settings.get(entry.id)
            local sub = { {
                text = "Most recent book",
                radio = true,
                checked_func = guarded(entry.id .. " check", false, function()
                    return not is_file(Settings.get(entry.id))
                end),
                callback = guarded(entry.id .. " unpin", nil, function()
                    write(entry, false)
                end),
            } }
            if is_file(pin) then
                sub[2] = {
                    text = title(pin),
                    radio = true,
                    checked_func = guarded(entry.id .. " check", false, function()
                        return Settings.get(entry.id) == pin
                    end),
                    callback = guarded(entry.id .. " pin", nil, function()
                        write(entry, pin)
                    end),
                }
            end
            return sub
        end),
    }
end

-- The stored place's name; a tap runs the place search with the menu kept open, and a pick is
-- written and the row redrawn. location_search is required then: it is not needed at load.
function BUILDERS.location(entry)
    return {
        text_func = text_func(entry, function()
            return Settings.get(entry.id).name
        end),
        keep_menu_open = true,
        callback = guarded(entry.id .. " search", nil, function(touchmenu)
            require("location_search").ask(guarded(entry.id .. " pick", nil, function(candidate)
                write(entry, candidate)
                touchmenu:updateItems()
            end))
        end),
    }
end

function BUILDERS.rows(entry)
    return { text = entry.label, callback = open_screen(entry, "edit_layout") }
end

function BUILDERS.launcher(entry)
    return { text = entry.label, callback = open_screen(entry, "launcher_manage") }
end

-- The rows for group: its keys when any key has that group, else every key; in schema order,
-- each group's last row but the list's last carrying a separator, drawn as a line before the next
-- (frontend/ui/widget/touchmenu.lua:715). A key of a type with no builder is left out.
function SchemaMenu.items(group)
    local cut = false
    for _, entry in ipairs(Schema.keys) do
        if entry.group == group then
            cut = true
        end
    end
    local items, groups = {}, {}
    for _, entry in ipairs(Schema.keys) do
        if not cut or entry.group == group then
            local build = BUILDERS[entry.type]
            if build then
                local item = build(entry)
                item.kopanda_key = entry.id
                items[#items + 1] = item
                groups[#items] = entry.group
            elseif not logged_types[entry.type] then
                logged_types[entry.type] = true
                logger.err("KoPanda: the settings menu has no row for the type", entry.type, "of", entry.id)
            end
        end
    end
    for i = 1, #items - 1 do
        if groups[i] ~= groups[i + 1] then
            items[i].separator = true
        end
    end
    return items
end

return SchemaMenu
