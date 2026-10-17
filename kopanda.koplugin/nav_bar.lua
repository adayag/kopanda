-- The nav bar: five tabs across a screen's bottom, Home, Library, Authors, History and Settings,
-- drawn from the look's nav tokens. The home and the file browser each build one with their own
-- tab active and set its dimen's x and y where they place it. A tap in a tab's column runs the
-- tab, a hold on Settings opens the quick-settings sheet, any other hold on the bar is consumed
-- and runs nothing, and every other gesture passes through.
--
-- launcher_entries and quick_settings are required at call time: launcher_entries requires home
-- (launcher_entries.lua:6), which reaches this module through home_rows, so a load-time require
-- would loop, and quick_settings requires launcher_entries.
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Icons = require("icons")
local InputContainer = require("ui/widget/container/inputcontainer")
local Layout = require("layout")
local Looks = require("looks")
local Paint = require("paint")
local Screen = require("device").screen
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local logger = require("logger")
local time = require("ui/time")

local NavBar = {}

-- The tabs, left to right.
NavBar.TABS = {
    { id = "home", label = "Home", icon = "home" },
    { id = "library", label = "Library", icon = "library" },
    { id = "authors", label = "Authors", icon = "authors" },
    { id = "history", label = "History", icon = "history" },
    { id = "settings", label = "Settings", icon = "settings" },
}

-- The active tab's id, by where the bar is: no screen of Authors, History or Settings carries it.
local ACTIVE = { home = "home", file_browser = "library" }

-- The y of a tab's content from the bar's top: below the edge, or below the active rule where
-- the rule is the longer, so every tab's content starts at one top; then the tab's padding.
local function content_top(nav, screen)
    local edge = screen:scaleBySize(nav.edge_width)
    return edge + math.max(0, screen:scaleBySize(nav.active_rule_width) - edge) + screen:scaleBySize(nav.padding_top)
end

-- The taller of the two label parts' lines. They are set with no text size, so the bar keeps one
-- height whatever the stored text size; the variant colours the line and doesn't change it.
local function label_height(look, screen)
    local ctx = { look = look, variant = "day" }
    local height = 0
    for _, part in ipairs({ look.type.nav_label, look.type.nav_label_active }) do
        local line = Typeset.line(part, "Home", screen:getWidth(), ctx)
        height = math.max(height, line:getSize().h)
        line:free()
    end
    return height
end

-- The bar's height in look on screen, in device pixels: the content's top, the icon, the gap,
-- a label line and the tab's bottom padding. Raises when a label face won't load.
function NavBar.height(look, screen)
    local nav = look.nav
    return content_top(nav, screen) + screen:scaleBySize(nav.icon_size) + screen:scaleBySize(nav.icon_gap)
        + label_height(look, screen) + screen:scaleBySize(nav.padding_bottom)
end

-- Runs the tab id from where, "home" or "file_browser". An error is logged with the tab's name
-- and goes no further, so the screen under the bar stays as it was.
function NavBar.run(id, where)
    local ok, err = pcall(function()
        if id == "home" then
            -- On the home, Home is the screen already. From the file browser, KoPanda's instance,
            -- registered under its name (frontend/apps/filemanager/filemanager.lua:379-389, :424).
            if where == "file_browser" then
                package.loaded["apps/filemanager/filemanager"].instance.kopanda:goHome()
            end
        elseif id == "history" then
            require("launcher_entries").run{ kind = "koreader", target = "history" }
        else
            require("launcher_entries").run{ kind = "kopanda", target = id }
        end
    end)
    if not ok then
        local label = id
        for _, tab in ipairs(NavBar.TABS) do
            if tab.id == id then
                label = tab.label
            end
        end
        logger.err("KoPanda: the nav bar's " .. label .. " tab failed:", err)
    end
end

local Bar = InputContainer:extend{
    name = "kopanda_nav_bar",
    look = nil,
    variant = nil,
    width = nil,
    where = nil,
    listen = false,
}

-- Builds each tab's icon and label once; the columns split the width less the side padding.
function Bar:init()
    local look, nav = self.look, self.look.nav
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = NavBar.height(look, Screen) }
    self.padding_x = Screen:scaleBySize(nav.padding_x)
    local shares = {}
    for i = 1, #NavBar.TABS do
        shares[i] = { share = 1 }
    end
    self.columns = Layout.columns(self.width - 2 * self.padding_x, shares, 0)
    local palette = Looks.palette(look, self.variant)
    local ctx = { look = look, variant = self.variant }
    local icon_size = Screen:scaleBySize(nav.icon_size)
    self.tabs = {}
    for i, tab in ipairs(NavBar.TABS) do
        local active = tab.id == ACTIVE[self.where]
        if active then
            self.active = i
        end
        self.tabs[i] = {
            icon = TintedIcon:new{
                file = Icons.path(tab.icon),
                size = icon_size,
                color = Looks.color(palette[active and nav.active_icon_color or nav.icon_color]),
            },
            label = Typeset.line(active and look.type.nav_label_active or look.type.nav_label, tab.label,
                self.columns[i].w, ctx),
        }
    end
    -- The range is a function, so the dimen the placer sets is the one matched
    -- (frontend/ui/gesturerange.lua:25-37).
    if self.listen then
        self.ges_events.NavBarGesture = {
            GestureRange:new{ ges = "tap", range = function() return self.dimen end },
            GestureRange:new{ ges = "hold", range = function() return self.dimen end },
        }
    end
end

-- The fill, the active tab's fill, the dividers right of every tab but the last, the edge across
-- the width, the active rule from the bar's top, then the icons and labels.
function Bar:paintTo(bb, x, y)
    local nav = self.look.nav
    local palette = Looks.palette(self.look, self.variant)
    local function color(role)
        return Looks.color(palette[role])
    end
    local w, h = self.dimen.w, self.dimen.h
    local edge = Screen:scaleBySize(nav.edge_width)
    local left = x + self.padding_x
    local active = self.columns[self.active]
    Paint.fill(bb, x, y, w, h, color(nav.fill_color))
    if active and nav.active_fill_color then
        Paint.fill(bb, left + active.x, y + edge, active.w, h - edge, color(nav.active_fill_color))
    end
    if nav.divider_width > 0 then
        local divider = Screen:scaleBySize(nav.divider_width)
        for i = 1, #self.columns - 1 do
            local column = self.columns[i]
            Paint.fill(bb, left + column.x + column.w - divider, y + edge, divider, h - edge, color(nav.divider_color))
        end
    end
    if edge > 0 then
        Paint.fill(bb, x, y, w, edge, color(nav.edge_color))
    end
    if active and nav.active_rule_width > 0 then
        Paint.fill(bb, left + active.x, y, active.w, Screen:scaleBySize(nav.active_rule_width),
            color(nav.active_rule_color))
    end
    local icon_size = Screen:scaleBySize(nav.icon_size)
    local icon_top = y + content_top(nav, Screen)
    local label_top = icon_top + icon_size + Screen:scaleBySize(nav.icon_gap)
    for i, tab in ipairs(self.tabs) do
        local column = self.columns[i]
        local column_x = left + column.x
        tab.icon:paintTo(bb, column_x + math.floor((column.w - icon_size) / 2), icon_top)
        local label_w = tab.label:getSize().w
        tab.label:paintTo(bb, column_x + math.floor((column.w - label_w) / 2), label_top)
    end
end

local function inside(rect, pos)
    return pos.x >= rect.x and pos.x < rect.x + rect.w and pos.y >= rect.y and pos.y < rect.y + rect.h
end

-- The tab whose column holds pos, or nil outside the bar or in its side padding.
function Bar:column_at(pos)
    if not inside(self.dimen, pos) then
        return nil
    end
    local x = pos.x - self.dimen.x - self.padding_x
    for i, column in ipairs(self.columns) do
        if x >= column.x and x < column.x + column.w then
            return NavBar.TABS[i]
        end
    end
    return nil
end

-- Opens the quick-settings sheet, its paint_ms from now. An error is logged with the tab's name
-- and goes no further, so the screen under the bar stays as it was.
local function open_quick_settings()
    local ok, err = pcall(function()
        require("quick_settings").open{ started = time.monotonic() }
    end)
    if not ok then
        logger.err("KoPanda: the nav bar's Settings hold failed:", err)
    end
end

-- Whether the bar consumes ges: a tap on it runs the tab under it, if any; a hold on Settings
-- opens the quick-settings sheet (bars/quick-settings, "The Settings-tab hold"), and a hold
-- anywhere else on it runs nothing; anything else, or anything off the bar, is left to what lies
-- beneath.
function Bar:handle(ges)
    if not inside(self.dimen, ges.pos) then
        return false
    end
    if ges.ges == "hold" then
        local tab = self:column_at(ges.pos)
        if tab and tab.id == "settings" then
            open_quick_settings()
        end
        return true
    end
    if ges.ges == "tap" then
        local tab = self:column_at(ges.pos)
        if tab then
            NavBar.run(tab.id, self.where)
        end
        return true
    end
    return false
end

function Bar:onNavBarGesture(_, ges)
    return self:handle(ges)
end

function Bar:free()
    for _, tab in ipairs(self.tabs or {}) do
        tab.icon:free()
        tab.label:free()
    end
    self.tabs = nil
end

-- A bar { look, variant, width, where, listen } width × NavBar.height(look, Screen), where "home"
-- (Home active) or "file_browser" (Library active). With listen it takes taps and holds on its
-- dimen itself; without, it takes none, and its screen hands them to handle.
function NavBar.new(args)
    return Bar:new{
        look = args.look,
        variant = args.variant,
        width = args.width,
        where = args.where,
        listen = args.listen or false,
    }
end

return NavBar
