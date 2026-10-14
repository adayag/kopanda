-- The KoPanda home: a full-screen widget over the file browser. Until home-layout it is a
-- placeholder, the name and one line, with fixed strings so captures compare equal.
-- Module state: Home.shown, the home on screen or nil.
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local logger = require("logger")
local time = require("ui/time")
local Screen = require("device").screen

-- Font:getFace scales these by the screen's DPI itself (frontend/ui/font.lua:276).
local TITLE_SIZE = 36
local LINE_SIZE = 18
local GAP = 16

local Home = InputContainer:extend{
    name = "kopanda_home",
    -- UIManager:_repaint skips paintTo beneath the topmost such widget.
    covers_fullscreen = true,
}

Home.shown = nil

function Home:init()
    self.dimen = Screen:getSize()
    self[1] = FrameContainer:new{
        width = self.dimen.w,
        height = self.dimen.h,
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        CenterContainer:new{
            dimen = Geom:new{ w = self.dimen.w, h = self.dimen.h },
            VerticalGroup:new{
                TextWidget:new{
                    text = "KoPanda",
                    face = Font:getFace("cfont", TITLE_SIZE),
                },
                VerticalSpan:new{ width = Screen:scaleBySize(GAP) },
                TextWidget:new{
                    text = "Tap to open the file browser",
                    face = Font:getFace("cfont", LINE_SIZE),
                },
            },
        },
    }
end

local function close_home(home)
    if Home.shown == home then
        Home.shown = nil
    end
    local ok, err = pcall(UIManager.close, UIManager, home, "full")
    if not ok then
        logger.err("KoPanda: could not close the home:", err)
    end
end

-- Signals the home's first paint on the dev loop's settled hook, once per home.
local function settle(home, opts)
    if home.settled then
        return
    end
    home.settled = true
    local ok, err = pcall(function()
        UIManager.event_hook:execute("KoPandaSettled", {
            screen = "home",
            paint_ms = time.to_ms(time.monotonic() - opts.started),
            prebuilt = opts.prebuilt == true,
        })
    end)
    if not ok then
        logger.err("KoPanda: the settled signal failed:", err)
    end
end

-- opts: started (time.monotonic() at the start of the show path), prebuilt. On any error the
-- home is taken off the stack and the file browser beneath is left as it is.
function Home.show(opts)
    local home
    local ok, err = pcall(function()
        home = Home:new{}
        Home.shown = home
        UIManager:show(home, "full")
        -- Lands past the next repaint, so the signal follows the paint.
        UIManager:tickAfterNext(function()
            settle(home, opts)
        end)
    end)
    if not ok then
        logger.err("KoPanda: could not show the home:", err)
        if home and UIManager:isWidgetShown(home) then
            close_home(home)
        end
        Home.shown = nil
    end
end

function Home.close()
    if Home.shown then
        close_home(Home.shown)
    end
end

-- A widget can't be closed from inside the repaint, so a failed paint closes the home from
-- the next tick, leaving the file browser beneath.
function Home:paintTo(bb, x, y)
    local ok, err = pcall(InputContainer.paintTo, self, bb, x, y)
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the home failed to paint:", err)
        UIManager:nextTick(function()
            close_home(self)
        end)
    end
end

-- KOReader may close the home itself; Home.shown must not outlive it.
function Home:onCloseWidget()
    if Home.shown == self then
        Home.shown = nil
    end
end

-- KOReader's top menu zones (defaults.lua:59-60), read as filemanagermenu.lua:74-75 reads them.
local function in_menu_zone(pos, dimen)
    for _, key in ipairs({ "DTAP_ZONE_MENU", "DTAP_ZONE_MENU_EXT" }) do
        local zone = G_defaults:readSetting(key)
        local rect = Geom:new{
            x = zone.x * dimen.w,
            y = zone.y * dimen.h,
            w = zone.w * dimen.w,
            h = zone.h * dimen.h,
        }
        if rect:contains(pos) then
            return true
        end
    end
    return false
end

-- The placeholder's gestures: a tap outside the top menu zones closes the home.
function Home:routeGesture(ges)
    if ges.ges ~= "tap" or in_menu_zone(ges.pos, self.dimen) then
        return false
    end
    close_home(self)
    return true
end

-- The home is not a plugin, so KOReader does not sandbox this handler: an error here would
-- reach the UI loop. A failure closes the home and consumes the gesture.
function Home:onGesture(ges)
    local ok, consumed = pcall(self.routeGesture, self, ges)
    if ok then
        return consumed
    end
    logger.err("KoPanda: the home failed to handle a gesture:", consumed)
    close_home(self)
    return true
end

return Home
