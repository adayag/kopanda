-- The KoPanda home: a full-screen widget over the file browser, built from the layout.rows
-- setting as rows of widgets (home_rows.lua builds them), drawn in the active look with its
-- header and footer; its gestures are routed by home_gestures.lua.
-- Module state: Home.shown, the home on screen or nil; Home.just_closed, true when a book closed
-- in this process and no file-manager Show has consumed that close yet.
local FeaturedCover = require("featured_cover")
local HomeGestures = require("home_gestures")
local HomeRows = require("home_rows")
local InputContainer = require("ui/widget/container/inputcontainer")
local Looks = require("looks")
local PaintClock = require("paint_clock")
local Sheet = require("sheet")
local UIManager = require("ui/uimanager")
local Weather = require("weather")
local logger = require("logger")
local Screen = require("device").screen

local Home = InputContainer:extend{
    name = "kopanda_home",
    -- UIManager:_repaint skips paintTo beneath the topmost such widget.
    covers_fullscreen = true,
}

Home.shown = nil
Home.just_closed = false

function Home:init()
    self.dimen = Screen:getSize()
    self:registerTouchZones(HomeGestures.own_zones(self))
    self:build()
end

-- Builds the rows into self[1] and self.slots (each { widget, rect, module, built }), with
-- self.ctx the context every widget got and self.nav the nav bar, or nil (HomeRows.build).
function Home:build()
    self[1], self.slots, self.ctx, self.nav = HomeRows.build(self)
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

-- Builds the home's rows afresh and frees the old ones, settling a deferred refresh.
local function rebuild(home)
    local old = home[1]
    home:build()
    home.refresh_deferred = nil
    if old then
        old:free()
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
        rebuild(self)
        UIManager:setDirty(self, "ui")
    end)
    if not ok then
        logger.err("KoPanda: could not rebuild the home:", err)
        close_home(self)
    end
end

-- Marks the home out of date without rebuilding it, for a change made under a full-screen
-- window that hides it (the editor, editor.lua): KOReader paints nothing beneath such a window
-- (frontend/ui/uimanager.lua:1305-1316), so the rebuild waits for run_deferred_refresh.
function Home:defer_refresh()
    self.refresh_deferred = true
end

-- Refreshes the home once if a refresh was deferred and nothing has rebuilt it since.
function Home:run_deferred_refresh()
    if self.refresh_deferred then
        self:refresh()
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

-- Asks each slot's widget whose module has stale (widgets.lua) whether its built widget is out
-- of date, and rebuilds the home once if any is. A raising stale is logged and counts as not
-- stale; a failed rebuild closes the home (refresh).
local function refresh_if_stale(home)
    local any = false
    for _, slot in ipairs(home.slots or {}) do
        local stale = slot.module and slot.module.stale
        if stale then
            local ok, result = pcall(stale, slot.built, home.ctx)
            if not ok then
                logger.err("KoPanda: the home widget", slot.widget, "failed its stale check:", result)
            elseif result then
                any = true
            end
        end
    end
    if any then
        home:refresh()
    end
end

-- Broadcast when Wi-Fi connects, and at start when it is already up
-- (frontend/ui/network/manager.lua:109, :152-154): the weather fetches if none has succeeded
-- yet, then a widget showing the network's state is redrawn. Returns nothing, so the event
-- reaches the other windows.
function Home:onNetworkConnected()
    local ok, err = pcall(Weather.on_connected, self)
    if not ok then
        logger.err("KoPanda: the weather failed on NetworkConnected:", err)
    end
    refresh_if_stale(self)
end

-- Broadcast once Wi-Fi is down (frontend/ui/network/manager.lua:406-408): a widget showing the
-- network's state is redrawn. Returns nothing, so the event reaches the other windows.
function Home:onNetworkDisconnected()
    refresh_if_stale(self)
end

-- The slot at pos whose widget acts on a tap, or nil.
function Home:tappableSlotAt(pos)
    for _, slot in ipairs(self.slots) do
        if slot.module and slot.module.tap and slot.rect:contains(pos) then
            return slot
        end
    end
end

-- The first slot at pos, whatever its widget, or nil.
function Home:slotAt(pos)
    for _, slot in ipairs(self.slots) do
        if slot.rect:contains(pos) then
            return slot
        end
    end
end

-- Runs the show's finished callback (the boot guard's clear), if any, telling it whether the
-- home painted.
local function finish(opts, painted)
    if not opts.finished then
        return
    end
    local ok, err = pcall(opts.finished, painted)
    if not ok then
        logger.err("KoPanda: the show's finished callback failed:", err)
    end
end

-- Signals the home's first paint on the dev loop's settled hook, once per home, then runs the
-- finished callback. A home whose paint failed sends no signal: the screen shows the file
-- browser, not the home. paint_ms runs from opts.started to the first paint, and cpu_ms on the
-- CPU clock; settle_ms runs on to this signal, which lands behind whatever other tasks came due
-- after the paint.
local function settle(home, opts)
    if home.settled then
        return
    end
    home.settled = true
    if not home.paint_failed then
        local ok, err = pcall(function()
            local now = PaintClock.now()
            local paint_ms, cpu_ms = PaintClock.ms(PaintClock.since(opts.started, home.painted_at or now))
            UIManager.event_hook:execute("KoPandaSettled", {
                screen = "home",
                paint_ms = paint_ms,
                cpu_ms = cpu_ms,
                settle_ms = (PaintClock.ms(PaintClock.since(opts.started, now))),
            })
        end)
        if not ok then
            logger.err("KoPanda: the settled signal failed:", err)
        end
        -- The weather's once-per-process fetch and each slot's after_show, never before the
        -- first paint, and only while this home is still the one shown.
        UIManager:nextTick(function()
            if Home.shown ~= home then
                return
            end
            local weather_ok, weather_err = pcall(Weather.after_show, home)
            if not weather_ok then
                logger.err("KoPanda: the weather failed after the show:", weather_err)
            end
            for _, slot in ipairs(home.slots) do
                local after_show = slot.module and slot.module.after_show
                if after_show and Home.shown == home then
                    local slot_ok, slot_err = pcall(after_show, home.ctx, slot.built)
                    if not slot_ok then
                        logger.err("KoPanda: the home widget", slot.widget, "failed after the show:", slot_err)
                    end
                end
            end
        end)
    end
    finish(opts, home.painted_at ~= nil and not home.paint_failed)
end

-- Builds a home and shows it, closing the chrome window shown first (the library, Series or
-- Authors), as a window's show closes the home (LibraryChrome.show): one of them is up at a time,
-- so no home hides a window that a target run from it would act on in place. opts: started (a
-- PaintClock stamp at the start of the show path), finished (called once: with true after the
-- home's first paint, or with false when the home closes before painting or its build, show or
-- paint fails). On any error the home is taken off the stack and the file browser beneath is left
-- as it is.
function Home.show(opts)
    local home
    local ok, err = pcall(function()
        -- library_chrome requires this module, so it is required here, at call time.
        require("library_chrome").close()
        home = Home:new{}
        Home.shown = home
        UIManager:show(home, "full")
        -- The home settles from its first paint, or from its close if that comes first; nothing
        -- is scheduled until then. A tickAfterNext here would land before the paint whenever the
        -- clock hasn't moved since the UI loop's pass began, since UIManager runs its inner
        -- nextTick in that same pass (frontend/ui/uimanager.lua:447-456, 1081-1104, 1537-1564).
        home.settle_opts = opts
    end)
    if not ok then
        logger.err("KoPanda: could not show the home:", err)
        if home and UIManager:isWidgetShown(home) then
            close_home(home)
        end
        Home.shown = nil
        finish(opts, false)
    end
end

function Home.close()
    if Home.shown then
        close_home(Home.shown)
    end
end

-- Paints the home, rebuilt first when the variant changed since its build. Night mode toggled
-- from the menu or Dispatcher reaches the home before DeviceListener flips the screen, which then
-- asks for this repaint (frontend/device/devicelistener.lua:14-27), so the paint is where the
-- home sees the new variant, and it asks for no repaint of its own.
local function paint(home, bb, x, y)
    if home.ctx.variant ~= Looks.variant() then
        rebuild(home)
    end
    InputContainer.paintTo(home, bb, x, y)
end

-- A widget can't be closed from inside the repaint, so a failed paint, its rebuild included,
-- closes the home from the next tick, leaving the file browser beneath. A show waiting on this
-- paint settles from the next tick, which runs after this repaint.
function Home:paintTo(bb, x, y)
    local ok, err = pcall(paint, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = PaintClock.now()
    end
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the home failed to paint:", err)
        UIManager:nextTick(function()
            close_home(self)
        end)
    end
    local opts = self.settle_opts
    if opts then
        self.settle_opts = nil
        UIManager:nextTick(function()
            settle(self, opts)
        end)
    end
end

-- KOReader may close the home itself; Home.shown must not outlive it, nor the featured cover's
-- bounded check, nor a sheet shown over it, nor a show waiting on a paint that won't come.
function Home:onCloseWidget()
    if Home.shown == self then
        Home.shown = nil
    end
    local opts = self.settle_opts
    if opts then
        self.settle_opts = nil
        settle(self, opts)
    end
    local ok, err = pcall(FeaturedCover.cancel)
    if not ok then
        logger.err("KoPanda: could not drop the cover check:", err)
    end
    local sheet_ok, sheet_err = pcall(Sheet.close)
    if not sheet_ok then
        logger.err("KoPanda: could not close the sheet over the home:", sheet_err)
    end
end

-- The KoPanda: home action while the home is up: the home is on top, gets the event first
-- (frontend/ui/uimanager.lua:988) and consumes it, leaving the one home there is.
function Home:onKoPandaHome()
    return true
end

-- The home's gestures, in order (HomeGestures.route).
function Home:routeGesture(ges)
    return HomeGestures.route(self, ges, close_home)
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
