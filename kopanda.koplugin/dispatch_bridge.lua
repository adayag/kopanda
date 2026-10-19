-- Lets the actions a gesture dispatches from the home reach the file manager's modules. Dispatcher:execute
-- sends its events with UIManager:sendEvent (frontend/dispatcher.lua:1549, :1586), which offers them
-- to the topmost widget, the home, and then only to is_always_active widgets
-- (frontend/ui/uimanager.lua:988, :1006-1031); so while a home is shown the wrapper marks the file
-- manager is_always_active for the call (uimanager.lua:1021-1027). State: whether the wrapper is installed.
local Dispatcher = require("dispatcher")
local Home = require("home")
local logger = require("logger")

local DispatchBridge = {}

local installed = false

-- Marks the file manager under a shown home always active and returns it with the flag's
-- previous value; returns nil with no home shown or no file manager.
local function mark_file_manager()
    if not Home.shown then
        return nil
    end
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if not fm then
        return nil
    end
    local previous = fm.is_always_active
    fm.is_always_active = true
    return fm, previous
end

-- Wraps Dispatcher.execute, once per process. A failure of the wrapper's own work is logged and
-- the action runs as KOReader would run it; an action's own error is re-raised unchanged, after
-- the flag is put back.
function DispatchBridge.install()
    if installed then
        return
    end
    installed = true
    local original = Dispatcher.execute
    Dispatcher.execute = function(self, settings, exec_props)
        local ok, fm, previous = pcall(mark_file_manager)
        if not ok then
            logger.err("KoPanda: the dispatcher wrapper failed:", fm)
            fm = nil
        end
        if not fm then
            return original(self, settings, exec_props)
        end
        local call_ok, result = pcall(original, self, settings, exec_props)
        fm.is_always_active = previous
        if not call_ok then
            error(result, 0)
        end
        return result
    end
end

return DispatchBridge
