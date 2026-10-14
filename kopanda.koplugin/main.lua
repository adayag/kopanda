-- KoPanda: the owner's own interface for KOReader. KOReader makes an instance of this plugin
-- in every file manager and every reader; in a file manager it puts the home over the file
-- browser when the file browser is shown, and closes it when the file browser closes.
--
-- Every KoPanda module is required here, at load time: KOReader prepends the plugin root to
-- package.path only while it dofile()s this file (frontend/pluginloader.lua:242, :269-270),
-- so a later require could resolve to another plugin's same-named file (:283-286).
local Guards = require("guards")
local Home = require("home")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local time = require("ui/time")

local KoPanda = WidgetContainer:extend{
    name = "kopanda",
    is_doc_only = false,
}

function KoPanda:init()
    local ok, err = pcall(function()
        -- The file manager makes instances with { ui = self }; the reader adds `document`.
        local in_fm = self.ui ~= nil and self.ui.document == nil
        -- With another shell enabled this instance does nothing; every handler checks it first.
        if Guards.refused() then
            self.refused = true
            if in_fm then
                Guards.notify_once()
            end
            return
        end
        self.in_fm = in_fm
    end)
    if not ok then
        logger.err("KoPanda: init failed:", err)
    end
end

-- Shows the home unless one is up or the file manager has gone since the show was scheduled.
function KoPanda:showHome()
    if Home.shown then
        return
    end
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if not (FileManager and FileManager.instance) then
        return
    end
    Home.show{ started = time.monotonic() }
end

-- The file manager's Show. The home goes up from the next tick, so it lands over whatever
-- KOReader shows synchronously after showFiles (history, favorites, folder shortcuts).
-- Returns nothing: a true return would stop Show reaching later modules.
function KoPanda:onShow()
    if self.refused then
        return
    end
    if not self.in_fm then
        return
    end
    local ok, err = pcall(UIManager.nextTick, UIManager, function()
        local show_ok, show_err = pcall(self.showHome, self)
        if not show_ok then
            logger.err("KoPanda: could not show the home:", show_err)
        end
    end)
    if not ok then
        logger.err("KoPanda: could not schedule the home:", err)
    end
end

-- The file manager closing (quit, or a book opening) takes the home with it; a home left on
-- the stack would keep KOReader from quitting.
function KoPanda:onCloseWidget()
    if self.refused then
        return
    end
    if self.in_fm then
        Home.close()
    end
end

return KoPanda
