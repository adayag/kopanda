-- The KoPanda home: a full-screen widget over the file browser, built from the layout.rows
-- setting as rows of widgets (layout.lua places them, widgets.lua finds them), drawn in the
-- active look with its header and footer.
-- Module state: Home.shown, the home on screen or nil; Home.pending, a home built on book
-- close and not yet shown, or nil.
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local Layout = require("layout")
local Looks = require("looks")
local Settings = require("settings")
local SettingsMenu = require("settings_menu")
local UIManager = require("ui/uimanager")
local Weather = require("weather")
local Widget = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local time = require("ui/time")
local Screen = require("device").screen

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
                    home.own_step = "tap"
                    return true
                end
            end,
        },
    }
end

-- A filled rectangle at (x, y) offset by rect's own. KOReader's paintRect greys any colour by
-- luminance (base/ffi/blitbuffer.lua:1704-1724), so a colour goes through paintRectRGB32
-- (:1827), as the swatch screen paints.
local function fill(bb, x, y, rect, color)
    if Blitbuffer.isColor8(color) then
        bb:paintRect(x + rect.x, y + rect.y, rect.w, rect.h, color)
    else
        bb:paintRectRGB32(x + rect.x, y + rect.y, rect.w, rect.h, color)
    end
end

-- The home's content: the filled chrome (paper, header, footer), then each slot's widget at
-- its place. The slot widgets are the array part, so free() and events reach them.
local Rows = WidgetContainer:extend{
    name = "kopanda_home_rows",
}

function Rows:paintTo(bb, x, y)
    for _, part in ipairs(self.fills) do
        fill(bb, x, y, part, part.color)
    end
    for i, widget in ipairs(self) do
        widget:paintTo(bb, x + self.places[i].x, y + self.places[i].y)
    end
end

-- The rectangles of the header and footer chrome, each with its colour, in drawing order; a
-- part whose colour role the look lacks is left out.
local function chrome(arranged, look, color)
    local parts = {}
    local function add(rect, role)
        local c = role and color(role)
        if rect and c then
            parts[#parts + 1] = { x = rect.x, y = rect.y, w = rect.w, h = rect.h, color = c }
        end
    end
    local header, footer = arranged.header, arranged.footer
    add(header.band, look.home.header.band_color)
    add(header.edge, look.home.header.edge_color)
    add(header.rule, look.home.header.rule_color)
    if footer then
        local tokens = look.home.footer
        add(footer, tokens.gap_color)
        add({ x = footer.x, y = footer.y, w = footer.w, h = footer.edge }, tokens.edge_color)
        local line, pitch = footer.line, footer.pitch
        if line > 0 and pitch > 0 then
            for x = footer.x, footer.x + footer.w - 1, pitch do
                add({
                    x = x,
                    y = footer.y + footer.edge,
                    w = math.min(line, footer.x + footer.w - x),
                    h = footer.h - footer.edge,
                }, tokens.stripe_color)
            end
        end
    end
    return parts
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
    self:build()
end

-- Builds the rows into self[1] and self.slots (each { widget, rect, module, built }), with
-- self.ctx the context every widget got. A slot whose widget has no module, or whose height or
-- build raises, is left blank at its column width and logged; the rest of the home still
-- builds.
function Home:build()
    local look = Looks.active()
    local variant = Looks.variant()
    local palette = look.palettes[variant]
    local ctx = {
        look = look,
        variant = variant,
        text_size = Settings.get("text_size"),
        now = os.time(),
        screen = Screen,
        home = self,
    }
    local function color(role)
        return Looks.color(palette[role])
    end
    local arranged = Layout.arrange(Settings.get("layout.rows"), ctx)
    local paper = { x = 0, y = 0, w = self.dimen.w, h = self.dimen.h, color = color("paper") }
    local fills = { paper }
    for _, part in ipairs(chrome(arranged, look, color)) do
        fills[#fills + 1] = part
    end
    local rows = Rows:new{
        dimen = Geom:new{ w = self.dimen.w, h = self.dimen.h },
        fills = fills,
        places = {},
    }
    local slots = {}
    for _, row in ipairs(arranged.rows) do
        for _, slot in ipairs(row.slots) do
            local built
            if not slot.module then
                logger.warn("KoPanda: no home widget named", slot.widget, "; its slot is left blank")
            elseif slot.error then
                logger.err("KoPanda: the home widget", slot.widget, "failed to measure:", slot.error)
            else
                local ok, result = pcall(slot.module.build, slot.w, ctx)
                if ok and result then
                    built = result
                else
                    logger.err("KoPanda: the home widget", slot.widget, "failed to build:", result)
                end
            end
            built = built or Widget:new{ dimen = Geom:new{ w = slot.w, h = slot.h } }
            rows[#rows + 1] = built
            rows.places[#rows] = { x = slot.x, y = slot.y }
            slots[#slots + 1] = {
                widget = slot.widget,
                rect = Geom:new{ x = slot.x, y = slot.y, w = slot.w, h = slot.h },
                module = slot.module,
                built = built,
            }
        end
    end
    self.ctx = ctx
    self.slots = slots
    self[1] = rows
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

-- Rebuilds the rows and repaints the home, so the time, date and widgets are current. A failure
-- closes the home onto the file browser. Called by the weather fetch through ctx.home, which may
-- finish after this home has closed; a home that is not shown is left alone.
function Home:refresh()
    if Home.shown ~= self then
        return
    end
    local ok, err = pcall(function()
        local old = self[1]
        self:build()
        if old then
            old:free()
        end
        UIManager:setDirty(self, "ui")
    end)
    if not ok then
        logger.err("KoPanda: could not rebuild the home:", err)
        close_home(self)
    end
end

-- Broadcast to every window on wake (frontend/device/generic/device.lua:1125). Returns
-- nothing, so the event reaches the other windows.
function Home:onResume()
    self:refresh()
end

-- Broadcast when the 12-hour clock setting flips
-- (frontend/ui/elements/common_settings_menu_table.lua:87).
function Home:onTimeFormatChanged()
    self:refresh()
end

-- Broadcast when Wi-Fi connects, and at start when it is already up
-- (frontend/ui/network/manager.lua:109, :152-154): the weather fetches if none has succeeded
-- yet. Returns nothing, so the event reaches the other windows.
function Home:onNetworkConnected()
    local ok, err = pcall(Weather.on_connected, self)
    if not ok then
        logger.err("KoPanda: the weather failed on NetworkConnected:", err)
    end
end

-- The slot at pos whose widget acts on a tap, or nil.
function Home:tappableSlotAt(pos)
    for _, slot in ipairs(self.slots) do
        if slot.module and slot.module.tap and slot.rect:contains(pos) then
            return slot
        end
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
        -- The weather's once-per-process fetch, never before the first paint, and only while
        -- this home is still the one shown.
        UIManager:nextTick(function()
            if Home.shown ~= home then
                return
            end
            local weather_ok, weather_err = pcall(Weather.after_show, home)
            if not weather_ok then
                logger.err("KoPanda: the weather failed after the show:", weather_err)
            end
        end)
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
-- size (the screen rotated since) is dropped. Returns the home or nil. Each slot whose widget
-- has refresh updates it first: the home was built on CloseDocument before Statistics, whose
-- handler runs later, flushed the closing book's session. A failed refresh is logged and
-- leaves that slot as built.
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
    for _, slot in ipairs(pending.slots) do
        if slot.module and slot.module.refresh then
            local ok, err = pcall(slot.module.refresh, slot.built, pending.ctx)
            if not ok then
                logger.err("KoPanda: the home widget", slot.widget, "failed to refresh:", err)
            end
        end
    end
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
-- (gestures main.lua:1287-1288); a tap outside the top menu zones runs the tapped slot's widget
-- when it acts on taps, and otherwise closes the home onto the file browser. With
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
    if own_step == "tap" then
        local slot = self:tappableSlotAt(ges.pos)
        if slot then
            slot.module.tap(self.ctx)
        else
            close_home(self)
        end
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
