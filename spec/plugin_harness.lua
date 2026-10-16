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
-- KoPanda's runtime state file (kopanda.koplugin/state.lua) and its directory under KO_HOME.
M.state_dir = require("datastorage"):getSettingsDir() .. "/kopanda"
M.state_file = M.state_dir .. "/state.lua"
-- KoPanda's settings file (kopanda.koplugin/settings.lua), in the same directory.
M.settings_file = M.state_dir .. "/settings.lua"
-- KoPanda's weather cache (kopanda.koplugin/weather.lua), in the same directory.
M.weather_file = M.state_dir .. "/weather.lua"

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

-- Dispatcher.execute as KOReader defines it, before any plugin wraps it.
M.dispatcher_execute = require("dispatcher").execute
-- FileManager.setupLayout as KOReader defines it, before fm_nav.lua wraps it.
M.fm_setup_layout = require("apps/filemanager/filemanager").setupLayout

-- Loads the plugin as the only enabled one, with its modules' state, runtime state file and
-- settings file fresh (no boot flag or setting left by an earlier spec), KOReader's
-- require-cached file manager menu order fresh (no Home tab inserted and no user order merged
-- by an earlier spec), and
-- Dispatcher.execute and FileManager.setupLayout unwrapped, as in a new process, and returns
-- the plugin module (the class KOReader makes an instance of per file manager and reader).
-- PluginLoader:_load reads main, meta, path and name (frontend/pluginloader.lua:231-271).
-- The emulator's fake Wi-Fi is off, so NetworkMgr:isConnected() is false
-- (frontend/device/sdl/device.lua:478-500) and no home shown by a spec fetches the weather; a
-- spec that wants a connection stubs isConnected.
function M.load()
    disable_plugins()
    G_reader_settings:saveSetting("emulator_fake_wifi_connected", false)
    require("dispatcher").execute = M.dispatcher_execute
    require("apps/filemanager/filemanager").setupLayout = M.fm_setup_layout
    for _, name in ipairs(M.module_names()) do
        package.unload(name) -- luacheck: ignore 143
    end
    package.unload("ui/elements/filemanager_menu_order") -- luacheck: ignore 143
    os.remove(M.state_file)
    os.remove(M.state_file .. ".old")
    os.remove(M.settings_file)
    os.remove(M.settings_file .. ".old")
    os.remove(M.weather_file)
    os.remove(M.weather_file .. ".old")
    os.remove(M.state_dir)
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

-- Runs fn with the device screen answering as the emulator's Colorsoft profile does: 1264×1680
-- with no DPI override, so scaleBySize is ceil(px × 1264 / 600) (ffi/framebuffer.lua:414-426)
-- and Font:getFace scales by it (frontend/ui/font.lua:276). TextWidget's vertical padding is
-- Size.padding.small, scaled once when the class loads (frontend/ui/widget/textwidget.lua:34,
-- frontend/ui/size.lua:52), so it is set to its Colorsoft value too. The unit screen's own
-- values come back afterwards, even when fn raises, so nothing built under fn should be painted
-- into the unit screen's 600×800 buffer before the caller is done with it.
function M.at_colorsoft(fn)
    local Geom = require("ui/geometry")
    local Screen = require("device").screen
    local TextWidget = require("ui/widget/textwidget")
    local W, H = 1264, 1680
    local function scale(px)
        return math.ceil(px * W / 600)
    end
    local stubs = {
        { Screen, "getWidth", function() return W end },
        { Screen, "getHeight", function() return H end },
        { Screen, "getSize", function() return Geom:new{ x = 0, y = 0, w = W, h = H } end },
        { Screen, "scaleBySize", function(_, px) return scale(px) end },
        { TextWidget, "padding", scale(2) },
    }
    local saved = {}
    for i, stub in ipairs(stubs) do
        saved[i] = rawget(stub[1], stub[2])
        stub[1][stub[2]] = stub[3]
    end
    local ok, err = pcall(fn)
    for i, stub in ipairs(stubs) do
        stub[1][stub[2]] = saved[i]
    end
    if not ok then
        error(err, 0)
    end
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
