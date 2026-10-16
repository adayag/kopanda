-- bin/catalog-json's dump, run on the emulator's LuaJIT from its koreader directory in a scratch
-- KO_HOME. Writes the catalog to KOPANDA_CATALOG_OUT; exits 1 naming what it found when KOReader's
-- action tree is not shaped as read.
require("ffi/loadlib")
require("commonrequire")
local lfs = require("libs/libkoreader-lfs")
local rapidjson = require("rapidjson")

local root = assert(os.getenv("KOPANDA_ROOT"), "catalog-json: KOPANDA_ROOT unset")
local out = assert(os.getenv("KOPANDA_CATALOG_OUT"), "catalog-json: KOPANDA_CATALOG_OUT unset")

local function fail(message)
    io.stderr:write("bin/catalog-json: ", message, "\n")
    os.exit(1)
end

local function read(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

-- Only KOReader's bundled plugins load: the others are discovered disabled
-- (frontend/pluginloader.lua:212-215), whatever the emulator's plugins/ holds.
G_reader_settings:saveSetting("plugins_disable_external", true)

-- A file manager on an empty folder loads the plugins and instantiates every one not
-- is_doc_only (frontend/apps/filemanager/filemanager.lua:418-424), which registers their actions.
local empty = os.getenv("KO_HOME") .. "/empty"
lfs.mkdir(empty)
require("apps/filemanager/filemanager"):showFiles(empty)

-- The action tree's file-browser sections, after "Nothing" (frontend/dispatcher.lua:1109-1140).
local SECTIONS = { "General", "Device", "Screen and lights", "File browser" }

-- Which action a section item ticks, read as the device's entry picker reads it: run the item's
-- callback with the scratch empty and take the one key it stores. A `none` or `arg` item has a
-- plain text and a callback that stores true (frontend/dispatcher.lua:931-940); the others carry
-- a text_func or no callback, or store a value (:941-1067). Returns the id, or nil for an item a
-- launcher can't run.
local function ticked_action(item, scratch)
    if type(item.text) ~= "string" or type(item.callback) ~= "function" then
        return nil
    end
    scratch.action = nil
    item.callback(nil)
    local found
    for key, value in pairs(scratch.action or {}) do
        if key ~= "settings" then
            if found then
                return nil
            end
            found = value == true and key or false
        end
    end
    scratch.action = nil
    return found or nil
end

local function actions()
    local Dispatcher = require("dispatcher")
    local scratch, caller, menu = {}, {}, {}
    Dispatcher:addSubMenu(caller, menu, scratch, "action")
    local sections = {}
    for i, title in ipairs(SECTIONS) do
        local entry = menu[i + 1]
        local text = entry and entry.text
        if text ~= title or type(entry.sub_item_table) ~= "table" then
            fail(("the action tree's item %d is %q, not the section %q"):format(i + 1, tostring(text), title))
        end
        local list = {}
        for _, item in ipairs(entry.sub_item_table) do
            local id = ticked_action(item, scratch)
            if id then
                list[#list + 1] = { id = id, title = Dispatcher.getDisplayList({ [id] = true })[1].text }
            end
        end
        sections[i] = { title = title, actions = list }
    end
    return sections
end

-- The plugins the file manager instantiated (frontend/pluginloader.lua:273-292, :567-569), not
-- is_doc_only, kopanda left out, labelled as the device's plugin sheet labels them.
local function plugins()
    local PluginLoader = require("pluginloader")
    local list = {}
    for _, plugin in ipairs((PluginLoader:loadPlugins())) do
        if PluginLoader:isPluginLoaded(plugin.name) and not plugin.is_doc_only and plugin.name ~= "kopanda" then
            list[#list + 1] = { name = plugin.name, label = plugin.fullname or plugin.name }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function icons()
    local list = {}
    for i, entry in ipairs(require("icons").entries) do
        list[i] = { id = entry.id, label = entry.label, svg = read(root .. "/kopanda.koplugin/" .. entry.file) }
    end
    return list
end

local function screens()
    local LauncherEntries = require("launcher_entries")
    local function label_and_icon(by_target)
        local rows = {}
        for target, row in pairs(by_target) do
            rows[target] = { label = row.label, icon = row.icon }
        end
        return rows
    end
    return {
        kopanda = label_and_icon(LauncherEntries.KOPANDA),
        koreader = label_and_icon(LauncherEntries.KOREADER),
    }
end

local catalog = { actions = actions(), plugins = plugins() }
-- The plugin's modules, found as the plugin finds them once loaded; added only now, so no bundled
-- plugin's own require meets a KoPanda module of the same name.
package.path = root .. "/kopanda.koplugin/?.lua;" .. package.path
catalog.icons = icons()
catalog.screens = screens()

local file = assert(io.open(out, "wb"))
file:write(rapidjson.encode(catalog, { sort_keys = true, pretty = true }), "\n")
file:close()
os.exit(0)
