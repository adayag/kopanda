-- The nav bar under KOReader's file browser. FmNav.install() wraps FileManager.setupLayout
-- (frontend/apps/filemanager/filemanager.lua:116-359) once per process: the file chooser it
-- builds is made short of the bar's band, then the file manager's first child, the original's
-- fm_ui, goes inside a frame that holds it and a bar with Library active in the band. The
-- file manager's title bar is KoPanda's, built in place of KOReader's for that one call. Every
-- step of KoPanda's fails safe: an error is logged and KOReader's own layout stands.
-- Module state: whether the wrapper is installed in this process.
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local FileChooser = require("ui/widget/filechooser")
local FileManager = require("apps/filemanager/filemanager")
local KoTitleBar = require("title_bar")
local Looks = require("looks")
local NavBar = require("nav_bar")
local Paint = require("paint")
local PaintClock = require("paint_clock")
local Screen = require("device").screen
local TitleBar = require("ui/widget/titlebar")
local TouchMenu = require("ui/widget/touchmenu")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local FmNav = {}

local installed = false

-- The frame in a file manager's self[1]: the bar first among its children, so a gesture reaches
-- the bar before the chooser and the file manager's own zones (widgetcontainer.lua:80-107), and
-- fm_ui second. It keeps the look, variant and band it was built with, and layout_span, the
-- wrapped setupLayout's duration on both clocks (paint_clock.lua).
FmNav.Frame = WidgetContainer:extend{
    name = "kopanda_fm_nav",
    fm = nil,
    fm_ui = nil,
    look = nil,
    variant = nil,
    band = nil,
}

-- A bar in the frame's look and variant across the screen, on the band at its bottom.
local function new_bar(frame, variant)
    local bar = NavBar.new{
        look = frame.look,
        variant = variant,
        width = frame.dimen.w,
        where = "file_browser",
        listen = true,
    }
    bar.dimen.x, bar.dimen.y = 0, frame.dimen.h - frame.band
    return bar
end

function FmNav.Frame:init()
    self.dimen = Screen:getSize()
    self.bar = new_bar(self, self.variant)
    self[1] = self.bar
    self[2] = self.fm_ui
end

-- Paints the bar, rebuilt first when the variant changed since it was built: night mode reaches
-- widgets before the screen flips and then repaints everything, as the home relies on
-- (home.lua:282-291).
local function paint_bar(frame, bb, x, y)
    local variant = Looks.variant()
    if variant ~= frame.variant then
        local old = frame.bar
        frame.bar = new_bar(frame, variant)
        frame[1] = frame.bar
        frame.variant = variant
        old:free()
    end
    frame.bar:paintTo(bb, x + frame.bar.dimen.x, y + frame.bar.dimen.y)
end

-- Sends KoPandaSettled once per frame, from the first paint after which the file manager is the
-- topmost window and this frame still its layout. paint_ms is the wrapped setupLayout's
-- duration plus that paint's, without the time the file browser sat under the home, and cpu_ms
-- the same spans on the CPU clock.
local function settle(frame, paint_span)
    local fm = frame.fm
    if frame.settled or UIManager:getNthTopWidget(1) ~= fm or fm[1] ~= frame then
        return
    end
    frame.settled = true
    local paint_ms, cpu_ms = PaintClock.ms(PaintClock.plus(frame.layout_span, paint_span))
    UIManager.event_hook:execute("KoPandaSettled", {
        screen = "file_browser",
        paint_ms = paint_ms,
        cpu_ms = cpu_ms,
    })
end

-- fm_ui at the origin, then the bar. A bar that fails to paint is logged once per frame and its
-- band painted as the chooser's paper, so the file browser above it still shows.
function FmNav.Frame:paintTo(bb, x, y)
    local started = PaintClock.now()
    self.fm_ui:paintTo(bb, x, y)
    local ok, err = pcall(paint_bar, self, bb, x, y)
    if not ok then
        Paint.fill(bb, x, y + self.dimen.h - self.band, self.dimen.w, self.band, Blitbuffer.COLOR_WHITE)
        if not self.paint_failed then
            self.paint_failed = true
            logger.err("KoPanda: the file browser's nav bar failed to paint:", err)
        end
    end
    if not self.settled then
        local paint_span = PaintClock.since(started)
        UIManager:tickAfterNext(function()
            local settle_ok, settle_err = pcall(settle, self, paint_span)
            if not settle_ok then
                logger.err("KoPanda: the file browser's settled signal failed:", settle_err)
            end
        end)
    end
end

-- Puts the original's fm_ui in a frame as fm[1] and frees the bar of the frame it replaces.
local function wrap(fm, previous, look, band, started)
    local frame = FmNav.Frame:new{
        fm = fm,
        fm_ui = fm[1],
        look = look,
        variant = Looks.variant(),
        band = band,
    }
    fm[1] = frame
    frame.layout_span = PaintClock.since(started)
    if getmetatable(previous) == FmNav.Frame then
        previous.bar:free()
    end
end

-- Shows the one tab of KOReader's own items that fm.menu[which] builds, as SettingsMenu.open
-- shows KoPanda's (settings_menu.lua), under the icon of KOReader's file browser settings tab
-- (frontend/apps/filemanager/filemanagermenu.lua:36). The items are built fresh on each open, so
-- their callbacks reach the current chooser (:873-957). A failure is logged and shows nothing.
local function open_tab(fm, which, what)
    local ok, err = pcall(function()
        local items = fm.menu[which](fm.menu).sub_item_table
        items.icon = "appbar.filebrowser"
        local container = CenterContainer:new{ dimen = Screen:getSize(), ignore = "height" }
        container[1] = TouchMenu:new{
            width = Screen:getWidth(),
            tab_item_table = { items },
            show_parent = container,
        }
        UIManager:show(container)
    end)
    if not ok then
        logger.err("KoPanda: could not open the file browser's " .. what .. " menu:", err)
    end
end

-- The title bar's sort picker: KOReader's sort items.
function FmNav.open_sort(fm)
    open_tab(fm, "getSortingMenuTable", "sort")
end

-- The title bar's status picker: KOReader's book status filter.
function FmNav.open_status(fm)
    open_tab(fm, "getShowFilterMenuTable", "status")
end

-- What TitleBar.new is while the wrapped setupLayout runs, so the file manager's one
-- TitleBar:new call (filemanager.lua:118-136) builds KoPanda's bar in look: it puts prior, the
-- class's own new (nil, so Widget:new is found again), back first, so KoTitleBar:new and any later
-- call build as KOReader does; then builds the bar from a copy of KOReader's attributes, its
-- callbacks and show_parent included, plus fm, the look and the pickers. A build that raises is
-- logged and KOReader's own bar is built from the untouched attributes.
local function one_shot(fm, look, prior)
    return function(class, attrs, ...)
        TitleBar.new = prior
        local ok, bar = pcall(function()
            local copy = {}
            for key, value in pairs(attrs) do
                copy[key] = value
            end
            copy.fm = fm
            copy.look = look
            copy.on_sort = function()
                FmNav.open_sort(fm)
            end
            copy.on_status = function()
                FmNav.open_status(fm)
            end
            return KoTitleBar:new(copy)
        end)
        if ok then
            return bar
        end
        logger.err("KoPanda: the file browser's title bar failed to build:", bar)
        return TitleBar.new(class, attrs, ...)
    end
end

-- Wraps FileManager.setupLayout, once per process. Unless the file manager has KoPanda's
-- instance, registered under its name (filemanager.lua:379-389), and it isn't refused, the
-- original runs alone. Otherwise the band's height for the active look is taken first (on a
-- failure, logged, the original runs alone at full height); FileChooser.height is set on the
-- class while the original runs, so the chooser it builds reads it through its metatable
-- (frontend/ui/widget/widget.lua:26-48) at Menu:init (frontend/ui/widget/menu.lua:701-704), and
-- TitleBar.new is the one-shot that builds KoPanda's title bar in the band's look; both are put
-- back on every path, the original's own error re-raised unchanged; then the frame goes in (on a
-- failure, logged, fm[1] stays the original's fm_ui, at the screen's height).
function FmNav.install()
    if installed then
        return
    end
    installed = true
    local original = FileManager.setupLayout
    FileManager.setupLayout = function(fm, ...)
        local kopanda = fm.kopanda
        if not kopanda or kopanda.refused then
            return original(fm, ...)
        end
        local started = PaintClock.now()
        local ok, look, band = pcall(function()
            local active = Looks.active()
            return active, NavBar.height(active, Screen)
        end)
        if not ok then
            logger.err("KoPanda: the file browser's nav bar band failed:", look)
            return original(fm, ...)
        end
        local previous = fm[1]
        local height = rawget(FileChooser, "height")
        local new = rawget(TitleBar, "new")
        FileChooser.height = Screen:getHeight() - band
        TitleBar.new = one_shot(fm, look, new)
        local call_ok, err = pcall(original, fm, ...)
        FileChooser.height = height
        TitleBar.new = new
        if not call_ok then
            error(err, 0)
        end
        local fm_ui = fm[1]
        local wrap_ok, wrap_err = pcall(wrap, fm, previous, look, band, started)
        if not wrap_ok then
            logger.err("KoPanda: the file browser's nav bar failed to build:", wrap_err)
            -- The chooser was built short of the band; fm_ui at the screen's height paints its
            -- background over the band too (framecontainer.lua:115-126), so the band is paper.
            fm_ui.height = Screen:getHeight()
        end
    end
end

-- Re-lays the file manager out after a look change, since the looks' bars differ in height:
-- reinit re-runs the wrapped setupLayout and keeps the folder and its page
-- (filemanager.lua:789-810). Only a file manager carrying the bar is re-laid; with none, the
-- next one builds in the new look. An error is logged and the layout stays until the next.
function FmNav.relayout()
    local ok, err = pcall(function()
        local fm = FileManager.instance
        if fm and getmetatable(fm[1]) == FmNav.Frame then
            fm:reinit()
            UIManager:setDirty(fm, "ui")
        end
    end)
    if not ok then
        logger.err("KoPanda: could not re-lay the file browser out:", err)
    end
end

return FmNav
