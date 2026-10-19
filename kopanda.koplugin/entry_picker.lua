-- The add-an-entry picker: EntryPicker.pick(kind, ctx, on_entry) turns one of the five kinds of launcher
-- entry into an entry the settings validator takes and calls on_entry with it, or shows a note. It
-- writes nothing. Every step runs guarded: an error is logged, the open dialog closes, on_entry isn't called.
local CenterContainer = require("ui/widget/container/centercontainer")
local Dispatcher = require("dispatcher")
local Helpers = require("helpers")
local InputDialog = require("ui/widget/inputdialog")
local PathChooser = require("ui/widget/pathchooser")
local PluginLoader = require("pluginloader")
local Schema = require("schema")
local Sheet = require("sheet")
local TouchMenu = require("ui/widget/touchmenu")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local util = require("util")
local Screen = require("device").screen

local EntryPicker = {}

-- The kinds, in the order the add screen offers them, with their labels.
EntryPicker.KINDS = {
    { kind = "kopanda", label = "KoPanda screen" },
    { kind = "koreader", label = "KOReader screen" },
    { kind = "directory", label = "Folder on disk" },
    { kind = "action", label = "Action" },
    { kind = "plugin", label = "Plugin" },
}

-- fn wrapped for one pick: an error is logged with what, and every widget the pick showed that
-- is still up is closed.
local function guard(pick, what, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            logger.err("KoPanda: the entry picker", what, err)
            for _, widget in ipairs(pick.shown) do
                if UIManager:isWidgetShown(widget) then
                    pcall(UIManager.close, UIManager, widget)
                end
            end
        end
    end
end

local function show(pick, widget)
    pick.shown[#pick.shown + 1] = widget
    UIManager:show(widget)
end

-- The "Label" dialog holding default; Add with a label that isn't all space closes it and calls
-- done with the label trimmed, Cancel closes it.
local function ask_label(pick, default, done)
    local dialog
    dialog = InputDialog:new{
        title = "Label",
        input = default,
        buttons = { {
            {
                text = "Cancel",
                id = "close",
                callback = guard(pick, "failed on Cancel:", function()
                    UIManager:close(dialog)
                end),
            },
            {
                text = "Add",
                is_enter_default = true,
                callback = guard(pick, "failed on Add:", function()
                    local label = util.trim(dialog:getInputText())
                    if label ~= "" then
                        UIManager:close(dialog)
                        done(label)
                    end
                end),
            },
        } },
    }
    show(pick, dialog)
    dialog:onShowKeyboard()
end

-- A sheet headed heading, a row for each spec in rows ({ label, icon, run }), each run guarded.
-- Rows that don't fit go on as many more sheets of the same heading as they take, each reached
-- from its More row.
local function sheet(pick, ctx, heading, rows)
    for _, row in ipairs(rows) do
        row.run = guard(pick, "failed on a row:", row.run)
    end
    local function page(page_rows)
        Sheet.show({ name = "picker", band = "home", header = { heading = heading }, rows = page_rows,
            more = { run = guard(pick, "failed on More:", page) } }, ctx)
    end
    page(rows)
end

local function screen_sheet(pick, ctx, kind, heading, by_target)
    local targets
    for _, key in ipairs(Schema.keys) do
        if key.id == "launcher.entries" then
            targets = key.targets[kind]
        end
    end
    local rows = {}
    for _, target in ipairs(targets) do
        local screen = by_target[target]
        rows[#rows + 1] = {
            label = screen.label,
            icon = screen.icon,
            run = function()
                pick.on_entry({ kind = kind, target = target })
            end,
        }
    end
    sheet(pick, ctx, heading, rows)
end

-- KOReader's action tree, its four file-browser sections only; on close, the one action ticked
-- and its label go to done(id, label), or a note says why nothing is added.
local function action_tree(pick, done)
    local scratch, caller, menu = {}, {}, {}
    Dispatcher:addSubMenu(caller, menu, scratch, "action")
    -- After "Nothing", the General, Device, Screen and lights and File browser sections; the
    -- reader's sections and the trailing items follow.
    local items = { icon = "appbar.settings" }
    if #menu >= 8 then
        for i = 2, 5 do
            if type(menu[i].sub_item_table) == "table" then
                items[#items + 1] = menu[i]
            end
        end
    end
    if #items ~= 4 then
        logger.err("KoPanda: the entry picker found", #menu, "items in KOReader's action tree, not its sections")
        Helpers.note("Couldn't list KOReader's actions.")
        return
    end
    local container = CenterContainer:new{ ignore = "height", dimen = Screen:getSize() }
    local touch_menu = TouchMenu:new{
        width = Screen:getWidth(),
        tab_item_table = { items },
        show_parent = container,
    }
    local closed = false
    touch_menu.close_callback = guard(pick, "failed closing the action tree:", function()
        if closed then
            return
        end
        closed = true
        UIManager:close(container)
        local ticked = {}
        for id, value in pairs(scratch.action or {}) do
            if id ~= "settings" then
                ticked[#ticked + 1] = { id = id, value = value }
            end
        end
        if #ticked ~= 1 then
            Helpers.note("Pick one action.")
        elseif ticked[1].value ~= true then
            Helpers.note("That action needs a value, which a launcher entry can't keep.")
        else
            local id = ticked[1].id
            ask_label(pick, Dispatcher.getDisplayList({ [id] = true })[1].text, function(label)
                done(id, label)
            end)
        end
    end)
    container[1] = touch_menu
    show(pick, container)
end

-- Where the folder chooser opens: the file browser's folder, or the reader's last one.
local function start_path()
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if fm and fm.file_chooser then
        return fm.file_chooser.path
    end
    local ReaderUI = package.loaded["apps/reader/readerui"]
    local reader = ReaderUI and ReaderUI.instance
    if reader then
        return (reader:getLastDirFile())
    end
end

-- launcher_entries is required when a screen is picked, not at load: it requires home and
-- settings_menu (launcher_entries.lua:6,8), which reach back here through the settings menu.
local PICKERS = {
    kopanda = function(pick, ctx)
        local LauncherEntries = require("launcher_entries")
        screen_sheet(pick, ctx, "kopanda", "KoPanda screen", LauncherEntries.KOPANDA)
    end,
    koreader = function(pick, ctx)
        local LauncherEntries = require("launcher_entries")
        screen_sheet(pick, ctx, "koreader", "KOReader screen", LauncherEntries.KOREADER)
    end,
    directory = function(pick)
        show(pick, PathChooser:new{
            select_directory = true,
            select_file = false,
            path = start_path(),
            onConfirm = guard(pick, "failed on a chosen folder:", function(path)
                path = path:gsub("/+$", "")
                if path == "" then
                    Helpers.note("Choose a folder inside the root.")
                    return
                end
                ask_label(pick, path:match("[^/]+$"), function(label)
                    pick.on_entry({ kind = "directory", path = path, label = label })
                end)
            end),
        })
    end,
    action = function(pick)
        action_tree(pick, function(id, label)
            pick.on_entry({ kind = "action", action = id, label = label, icon = "action" })
        end)
    end,
    plugin = function(pick, ctx)
        local rows = {}
        for _, plugin in ipairs((PluginLoader:loadPlugins())) do
            local name = plugin.name
            if name ~= "kopanda" and not plugin.is_doc_only and PluginLoader:isPluginLoaded(name) then
                rows[#rows + 1] = {
                    label = plugin.fullname or name,
                    run = function()
                        action_tree(pick, function(id, label)
                            pick.on_entry({ kind = "plugin", plugin = name, action = id, label = label,
                                icon = "action" })
                        end)
                    end,
                }
            end
        end
        if #rows == 0 then
            Helpers.note("No plugins are loaded.")
            return
        end
        table.sort(rows, function(a, b)
            return a.label < b.label
        end)
        sheet(pick, ctx, "Plugin", rows)
    end,
}

-- Picks an entry of kind (one of KINDS' kinds) under ctx (the screen's, for its sheets) and
-- calls on_entry with it, or shows a note and calls nothing.
function EntryPicker.pick(kind, ctx, on_entry)
    local pick = { on_entry = on_entry, shown = {} }
    guard(pick, "failed to open " .. tostring(kind) .. ":", function()
        PICKERS[kind](pick, ctx)
    end)()
end

return EntryPicker
