-- Runs kopanda.koplugin inside a real headless KOReader for the unit specs: KOReader's own
-- spec/unit/commonrequire.lua (dummy screen and input, G_reader_settings under KO_HOME), the
-- plugin loaded through PluginLoader:_load so its on* handlers are sandboxed as on a device,
-- and a FileManager built by FileManager:showFiles, the only way KOReader makes one.
-- commonrequire defines disable_plugins, fastforward_ui_events and package.unload.
-- luacheck: read globals disable_plugins fastforward_ui_events
require("commonrequire")
local lfs = require("libs/libkoreader-lfs")

local M = {}

M.root = assert(os.getenv("KOPANDA_ROOT"), "plugin_harness: KOPANDA_ROOT unset")
M.plugin_dir = M.root .. "/kopanda.koplugin"
M.library = M.root .. "/spec/fixtures/library"

-- Every .lua file under the plugin, as a path relative to the plugin root, sorted.
function M.plugin_files()
    local files = {}
    local function walk(dir, prefix)
        for entry in lfs.dir(dir) do
            if entry ~= "." and entry ~= ".." then
                local path = dir .. "/" .. entry
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    walk(path, prefix .. entry .. "/")
                elseif mode == "file" and entry:match("%.lua$") then
                    files[#files + 1] = prefix .. entry
                end
            end
        end
    end
    walk(M.plugin_dir, "")
    table.sort(files)
    return files
end

-- KoPanda's own module names: every plugin file but main.lua and _meta.lua, which KOReader
-- dofile()s rather than requires.
function M.module_names()
    local names = {}
    for _, file in ipairs(M.plugin_files()) do
        if file ~= "main.lua" and file ~= "_meta.lua" then
            names[#names + 1] = file:gsub("%.lua$", "")
        end
    end
    return names
end

-- Loads the plugin as the only enabled one, with its modules' state fresh, and returns the
-- plugin module (the class KOReader makes an instance of per file manager and reader).
-- PluginLoader:_load reads main, meta, path and name (frontend/pluginloader.lua:231-271).
function M.load()
    disable_plugins()
    for _, name in ipairs(M.module_names()) do
        package.unload(name) -- luacheck: ignore 143
    end
    local PluginLoader = require("pluginloader")
    PluginLoader:_load{ {
        main = M.plugin_dir .. "/main.lua",
        meta = M.plugin_dir .. "/_meta.lua",
        path = M.plugin_dir,
        name = "kopanda",
    } }
    return assert(PluginLoader.enabled_plugins[1], "plugin_harness: kopanda did not load")
end

-- Shows a file manager on dir (default: the fixture library) and returns it.
function M.show_fm(dir)
    local FileManager = require("apps/filemanager/filemanager")
    FileManager:showFiles(dir or M.library)
    return FileManager.instance
end

-- Opens a reader on a fixture book (KOReader's spec/unit/readerui_spec.lua:14-17), shows it
-- and returns it.
function M.open_reader(book)
    local DocumentRegistry = require("document/documentregistry")
    local ReaderUI = require("apps/reader/readerui")
    local Screen = require("device").screen
    local reader = ReaderUI:new{
        dimen = Screen:getSize(),
        document = DocumentRegistry:openDocument(M.library .. "/" .. (book or "frankenstein.epub")),
    }
    require("ui/uimanager"):show(reader)
    return reader
end

-- Runs the UI loop n times (default 1), every scheduled task brought due first.
function M.tick(n)
    for _ = 1, n or 1 do
        fastforward_ui_events()
    end
end

-- The nth widget from the top of the window stack (default: the top one).
function M.top(n)
    return require("ui/uimanager"):getNthTopWidget(n or 1)
end

-- Every widget on the window stack, top first.
function M.stack()
    local widgets = {}
    for widget in require("ui/uimanager"):topdown_widgets_iter() do
        widgets[#widgets + 1] = widget
    end
    return widgets
end

-- A synthetic gesture at (x, y): the fields GestureRange:match reads
-- (frontend/ui/gesturerange.lua:21-51).
function M.gesture(ges, x, y)
    local Geom = require("ui/geometry")
    local time = require("ui/time")
    return { ges = ges, pos = Geom:new{ x = x, y = y, w = 0, h = 0 }, time = time.now() }
end

-- Closes any reader and file manager, then everything left on the stack, and drops every
-- scheduled task, so the next spec starts from an empty UI.
function M.teardown()
    local UIManager = require("ui/uimanager")
    local ReaderUI = package.loaded["apps/reader/readerui"]
    if ReaderUI and ReaderUI.instance then
        ReaderUI.instance:onClose()
    end
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if FileManager and FileManager.instance then
        FileManager.instance:onClose()
    end
    local widget = M.top()
    while widget do
        UIManager:close(widget)
        widget = M.top()
    end
    UIManager:quit()
end

return M
