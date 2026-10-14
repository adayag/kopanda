-- KoPanda: the owner's own interface for KOReader. KOReader makes an instance of this plugin
-- in every file manager and every reader; in a file manager it puts the home over the file
-- browser when the file browser is shown, and closes it when the file browser closes.
--
-- Every KoPanda module is required here, at load time: KOReader prepends the plugin root to
-- package.path only while it dofile()s this file (frontend/pluginloader.lua:242, :269-270),
-- so a later require could resolve to another plugin's same-named file (:283-286).
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
        self.in_fm = self.ui ~= nil and self.ui.document == nil
        -- A reader starting means no file browser followed the last close (a switch or a
        -- reload), so the home built for it is not needed.
        if not self.in_fm then
            Home.drop_pending()
        end
    end)
    if not ok then
        logger.err("KoPanda: init failed:", err)
    end
end

-- Shows the home unless one is up or the file manager has gone since the show was scheduled:
-- the pending home when there is one at the screen's size, a fresh build otherwise. started is
-- when the show path began (default: now).
function KoPanda:showHome(started)
    if Home.shown then
        return
    end
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if not (FileManager and FileManager.instance) then
        return
    end
    started = started or time.monotonic()
    local pending = Home.take_pending()
    if pending then
        Home.show{ widget = pending, started = started, prebuilt = true }
    else
        Home.show{ started = started }
    end
end

-- The file manager's Show. With a home pending (a book just closed) it goes up at once, inside
-- Show, so it is on the stack before the next repaint even when the close ran from a scheduled
-- task, and nothing of start_with follows a book close. Otherwise the home goes up from the
-- next tick, so it lands over whatever KOReader shows synchronously after showFiles (history,
-- favorites, folder shortcuts). Returns nothing: a true return would stop Show reaching later
-- modules.
function KoPanda:onShow()
    if not self.in_fm then
        return
    end
    if Home.pending then
        local show_ok, show_err = pcall(self.showHome, self, time.monotonic())
        if not show_ok then
            logger.err("KoPanda: could not show the home:", show_err)
        end
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

-- A reader closing its book: build the home now, so the file browser that usually follows
-- shows it without a build. CloseDocument also fires on reload, switch and exit, with no file
-- browser after; that build is wasted, which is accepted since the home is cheap to build, and
-- the next reader's init drops it. Returns nothing, so the event reaches later modules.
function KoPanda:onCloseDocument()
    if self.in_fm or Home.pending then
        return
    end
    Home.prebuild()
end

-- The file manager closing (quit, or a book opening) takes the home with it; a home left on
-- the stack would keep KOReader from quitting.
function KoPanda:onCloseWidget()
    if self.in_fm then
        Home.close()
    end
end

return KoPanda
