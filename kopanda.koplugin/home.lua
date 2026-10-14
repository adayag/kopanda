-- The KoPanda home: a full-screen widget over the file browser. Until home-layout it is a
-- placeholder, the name and one line, with fixed strings so captures compare equal.
-- Module state: Home.shown, the home on screen or nil; Home.pending, a home built on book
-- close and not yet shown, or nil.
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local SettingsMenu = require("settings_menu")
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

-- Whether pos lies in the named G_defaults zone (screen ratios, defaults.lua:59-75), read as
-- filemanagermenu.lua:74-75 reads its zones, against the screen's size now.
local function in_zone(name, pos)
    local zone = G_defaults:readSetting(name)
    local size = Screen:getSize()
    return Geom:new{
        x = zone.x * size.w,
        y = zone.y * size.h,
        w = zone.w * size.w,
        h = zone.h * size.h,
    }:contains(pos)
end

-- KOReader's top menu zones.
local function in_menu_zone(pos)
    return in_zone("DTAP_ZONE_MENU", pos) or in_zone("DTAP_ZONE_MENU_EXT", pos)
end

-- A one-finger swipe up from the bottom edge band, outside the left and right edge bands, where
-- Gestures binds frontlight and warmth (plugins/gestures.koplugin/defaults.lua:14-17).
local function is_swipe_up_from_bottom(ges)
    return ges.ges == "swipe" and ges.direction == "north"
        and in_zone("DSWIPE_ZONE_BOTTOM_EDGE", ges.pos)
        and not in_zone("DSWIPE_ZONE_LEFT_EDGE", ges.pos)
        and not in_zone("DSWIPE_ZONE_RIGHT_EDGE", ges.pos)
end

-- A one-finger west or east swipe outside the top and bottom edge bands. Passed on, it would page
-- the hidden file chooser through the file manager's full-screen swipe zone (filemanager.lua:81-98,
-- :474-482); Gestures binds these swipes only inside those bands (gestures main.lua:1168-1195).
local function is_page_swipe(ges)
    return ges.ges == "swipe" and (ges.direction == "west" or ges.direction == "east")
        and not in_zone("DSWIPE_ZONE_TOP_EDGE", ges.pos)
        and not in_zone("DSWIPE_ZONE_BOTTOM_EDGE", ges.pos)
end

-- The home's own steps are touch zones on the home, matched through InputContainer.onGesture
-- rather than tested directly: KOReader's touch lock (InputContainer:setIgnoreTouchInput swaps
-- InputContainer.onGesture for _onGestureFiltered, which runs only the zones isGestureAlwaysActive
-- approves, frontend/ui/widget/container/inputcontainer.lua:297-350) then filters them as it does
-- every widget's, though the home overrides onGesture. A zone's handler only names its step, which
-- routeGesture runs in its place in the order. The zones cover the whole screen; their handlers
-- test the bands against the screen's size now.
local FULL_SCREEN = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 }

local function own_zones(home)
    return {
        {
            id = "kopanda_home_swipe_up",
            ges = "swipe",
            screen_zone = FULL_SCREEN,
            handler = function(ges)
                if is_swipe_up_from_bottom(ges) then
                    home.own_step = "settings"
                    return true
                end
            end,
        },
        {
            id = "kopanda_home_tap",
            ges = "tap",
            screen_zone = FULL_SCREEN,
            handler = function(ges)
                if not in_menu_zone(ges.pos) then
                    home.own_step = "close"
                    return true
                end
            end,
        },
    }
end

local Home = InputContainer:extend{
    name = "kopanda_home",
    -- UIManager:_repaint skips paintTo beneath the topmost such widget.
    covers_fullscreen = true,
}

Home.shown = nil
Home.pending = nil

function Home:init()
    self.dimen = Screen:getSize()
    self:registerTouchZones(own_zones(self))
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

-- Runs the show's finished callback (the boot guard's clear), if any.
local function finish(opts)
    if not opts.finished then
        return
    end
    local ok, err = pcall(opts.finished)
    if not ok then
        logger.err("KoPanda: the show's finished callback failed:", err)
    end
end

-- Signals the home's first paint on the dev loop's settled hook, once per home, then runs the
-- finished callback. A home whose paint failed sends no signal: the screen shows the file
-- browser, not the home. paint_ms runs from opts.started to the first paint; settle_ms runs on
-- to this signal, which lands behind whatever other tasks came due after the paint.
local function settle(home, opts)
    if home.settled then
        return
    end
    home.settled = true
    if not home.paint_failed then
        local ok, err = pcall(function()
            local now = time.monotonic()
            UIManager.event_hook:execute("KoPandaSettled", {
                screen = "home",
                paint_ms = time.to_ms((home.painted_at or now) - opts.started),
                settle_ms = time.to_ms(now - opts.started),
                prebuilt = opts.prebuilt == true,
            })
        end)
        if not ok then
            logger.err("KoPanda: the settled signal failed:", err)
        end
    end
    finish(opts)
end

-- opts: widget (a pre-built home to show; default: a fresh build), started (time.monotonic()
-- at the start of the show path), prebuilt, finished (called once, after the first paint's
-- settled signal or on a caught failure). On any error the home is taken off the stack and the
-- file browser beneath is left as it is.
function Home.show(opts)
    local home
    local ok, err = pcall(function()
        home = opts.widget or Home:new{}
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
        finish(opts)
    end
end

function Home.close()
    if Home.shown then
        close_home(Home.shown)
    end
end

-- Builds a home and keeps it as Home.pending, not shown. A failed build is logged and leaves
-- nothing pending, so the next show builds afresh.
function Home.prebuild()
    local ok, home = pcall(Home.new, Home, {})
    if ok then
        Home.pending = home
    else
        logger.err("KoPanda: could not pre-build the home:", home)
    end
end

-- Forgets the pending home and frees it.
function Home.drop_pending()
    local pending = Home.pending
    Home.pending = nil
    if pending then
        local ok, err = pcall(pending.free, pending)
        if not ok then
            logger.err("KoPanda: could not free the pending home:", err)
        end
    end
end

-- Hands over the pending home when it was built at the screen's current size; one of another
-- size (the screen rotated since) is dropped. Returns the home or nil.
function Home.take_pending()
    local pending = Home.pending
    if not pending then
        return nil
    end
    local size = Screen:getSize()
    if pending.dimen.w ~= size.w or pending.dimen.h ~= size.h then
        Home.drop_pending()
        return nil
    end
    Home.pending = nil
    return pending
end

-- A widget can't be closed from inside the repaint, so a failed paint closes the home from
-- the next tick, leaving the file browser beneath.
function Home:paintTo(bb, x, y)
    local ok, err = pcall(InputContainer.paintTo, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = time.monotonic()
    end
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

-- The KoPanda: home action while the home is up: the home is on top, gets the event first
-- (frontend/ui/uimanager.lua:988) and consumes it, leaving the one home there is.
function Home:onKoPandaHome()
    return true
end

-- The home's gestures, in order, each step stopping at the first that consumes: its own swipe
-- up; the file manager's menu zones (top-zone tap and swipe down, by KOReader's own rules,
-- filemanagermenu.lua:71-124, :1102-1114); a page swipe, consumed since there is nothing to
-- page; the zones registered on the file manager itself, the Gestures plugin's among them
-- (gestures main.lua:1287-1288); a tap outside the top menu zones closes the placeholder. With
-- the home on top, UIManager:sendEvent offers the file manager nothing but its screenshot
-- module (frontend/ui/uimanager.lua:962-1034), hence the forwarding.
function Home:routeGesture(ges)
    self.own_step = nil
    -- The home's own zones, under KOReader's touch lock (see own_zones).
    InputContainer.onGesture(self, ges)
    local own_step = self.own_step
    self.own_step = nil
    if own_step == "settings" then
        SettingsMenu.open()
        return true
    end
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if fm and InputContainer.onGesture(fm.menu, ges) then
        return true
    end
    if is_page_swipe(ges) then
        return true
    end
    if fm and InputContainer.onGesture(fm, ges) then
        return true
    end
    if own_step == "close" then
        close_home(self)
        return true
    end
    return false
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
