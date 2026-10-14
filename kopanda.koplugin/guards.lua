-- Coexistence: KoPanda refuses its shell while another shell plugin is enabled, and says which.
-- Module state: the conflicts, computed on the first call of the process, and whether the
-- message has been raised.
local InfoMessage = require("ui/widget/infomessage")
local PluginLoader = require("pluginloader")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local Guards = {}

-- Runtime plugin names are folder names (frontend/pluginloader.lua:210, :249), and a git clone
-- of ennUI is `ennUI.koplugin`, so names are matched lowercased.
local SHELLS = {
    simpleui = "SimpleUI",
    bookshelf = "Bookshelf",
    ennui = "ennUI",
}

local conflicts
local notified = false

-- The display names of the enabled shell plugins, in PluginLoader's order. A failure to read
-- the list is logged and refuses nothing, leaving KOReader's own file browser as it is.
function Guards.conflicts()
    if conflicts then
        return conflicts
    end
    local ok, found = pcall(function()
        local names = {}
        for _, plugin in ipairs(PluginLoader:loadPlugins()) do
            local display = SHELLS[plugin.name:lower()]
            if display then
                names[#names + 1] = display
            end
        end
        return names
    end)
    if not ok then
        logger.err("KoPanda: could not check for other shell plugins:", found)
        found = {}
    end
    conflicts = found
    return conflicts
end

function Guards.refused()
    return #Guards.conflicts() > 0
end

-- Raises the refusal message from the next tick, once per process.
function Guards.notify_once()
    if notified then
        return
    end
    notified = true
    local names = Guards.conflicts()
    local verb, pronoun = "is", "it"
    if #names > 1 then
        verb, pronoun = "are", "them"
    end
    local text = string.format("KoPanda's home is off while %s %s enabled. "
        .. "Disable %s in Plugin management and restart KOReader.", table.concat(names, " and "), verb, pronoun)
    UIManager:nextTick(function()
        UIManager:show(InfoMessage:new{ text = text })
    end)
end

return Guards
