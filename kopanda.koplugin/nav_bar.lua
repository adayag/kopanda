-- The nav bar: five tabs in a band across a screen's bottom, Home, Library, Stats, History and Settings,
-- from the look's nav tokens. The home, the file browser and the library each build one with their own tab
-- active. A tap runs the tab, a hold on Settings opens the quick-settings sheet (with focused mode on, the two
-- swapped on Settings), any other hold is consumed, and every other gesture passes through. launcher_entries,
-- quick_settings, library, series_screen, authors_screen, subjects_screen and stats_screen are required at call time:
-- launcher_entries requires home (launcher_entries.lua:6), which reaches this module through home_rows.
local Focused = require("focused")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Helpers = require("helpers")
local Icons = require("icons")
local InputContainer = require("ui/widget/container/inputcontainer")
local Layout = require("layout")
local Looks = require("looks")
local Paint = require("paint")
local PaintClock = require("paint_clock")
local Screen = require("device").screen
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local logger = require("logger")

local NavBar = {}

-- The tabs, left to right.
NavBar.TABS = {
    { id = "home", label = "Home", icon = "home" },
    { id = "library", label = "Library", icon = "library" },
    { id = "stats", label = "Stats", icon = "stats" },
    { id = "history", label = "History", icon = "history" },
    { id = "settings", label = "Settings", icon = "settings" },
}

-- The active tab's id, by where the bar is: the Stats window lights Stats; the Series, Subjects and Authors
-- windows light none, and no screen of History or Settings carries the bar.
local ACTIVE = { home = "home", file_browser = "library", library = "library", stats = "stats" }

-- The y of a tab's content from the bar's top: below the edge, or below the active rule where
-- the rule is the longer, so every tab's content starts at one top; then the tab's padding.
local function content_top(nav, screen)
    local edge = screen:scaleBySize(nav.edge_width)
    return edge + math.max(0, screen:scaleBySize(nav.active_rule_width) - edge) + screen:scaleBySize(nav.padding_top)
end

-- The text size the labels are set at for the shell's text_size: Large's at Extra large, so five labels still
-- fit across the bar with space between them while the icons grow.
local function label_size(text_size)
    return text_size == "extra_large" and "large" or text_size
end

-- The taller of the two label parts' lines at text_size; the variant colours the line and doesn't
-- change it.
local function label_height(look, screen, text_size)
    local ctx = { look = look, variant = "day", text_size = label_size(text_size) }
    local height = 0
    for _, part in ipairs({ look.type.nav_label, look.type.nav_label_active }) do
        local line = Typeset.line(part, "Home", screen:getWidth(), ctx)
        height = math.max(height, line:getSize().h)
        line:free()
    end
    return height
end

-- The bar's height in look on screen at text_size's shell size, in device pixels: the content's top, the
-- icon, the gap, a label line and the tab's bottom padding. Raises when a label face won't load.
function NavBar.height(look, screen, text_size)
    local nav = look.nav
    text_size = Layout.shell_text_size(text_size)
    return content_top(nav, screen) + Layout.size_at(screen:scaleBySize(nav.icon_size), text_size)
        + screen:scaleBySize(nav.icon_gap) + label_height(look, screen, text_size)
        + screen:scaleBySize(nav.padding_bottom)
end

-- The window module each chrome window's bar closes on Home, by where.
local WINDOWS = { library = "library", series = "series_screen", authors = "authors_screen",
    subjects = "subjects_screen", stats = "stats_screen" }

-- Runs the tab id from where, "home", "file_browser", "library", "series", "authors", "subjects" or "stats". An error
-- is logged with the tab's name and goes no further, so the screen under the bar stays as it was.
function NavBar.run(id, where)
    local ok, err = pcall(function()
        -- A screen that isn't the library's leaves its books to be walked again: History and Settings open over
        -- the window, and History's Delete tells nothing (filemanager.lua:1169-1192). Required now, as it requires
        -- this module.
        if not WINDOWS[id] then
            require("library_chrome").forget_books()
        end
        if id == "home" then
            -- On the home, Home is the screen already. From the file browser, KoPanda's instance, registered under its
            -- name (frontend/apps/filemanager/filemanager.lua:379-389, :424); from a chrome window, the same once the
            -- window has closed onto the file browser. The window's module is required now: it requires this module.
            if WINDOWS[where] then
                require(WINDOWS[where]).close()
            end
            if where == "file_browser" or WINDOWS[where] then
                package.loaded["apps/filemanager/filemanager"].instance.kopanda:goHome()
            end
        elseif id == "stats" then
            -- On the Stats window, its first page; from anywhere else, the window shown through the plugin.
            local StatsScreen = require("stats_screen")
            if StatsScreen.shown then
                StatsScreen.shown:go(StatsScreen.shown:view(), 1)
            else
                package.loaded["apps/filemanager/filemanager"].instance.kopanda:showStats{}
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
    text_size = nil,
}

-- Builds each tab's icon and label once; the columns split the width less the side padding.
function Bar:init()
    local look, nav = self.look, self.look.nav
    self.text_size = Layout.shell_text_size(self.text_size)
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = NavBar.height(look, Screen, self.text_size) }
    self.padding_x = Screen:scaleBySize(nav.padding_x)
    local shares = {}
    for i = 1, #NavBar.TABS do
        shares[i] = { share = 1 }
    end
    self.columns = Layout.columns(self.width - 2 * self.padding_x, shares, 0)
    local palette = Looks.palette(look, self.variant)
    local ctx = { look = look, variant = self.variant, text_size = label_size(self.text_size) }
    self.icon_size = Layout.size_at(Screen:scaleBySize(nav.icon_size), self.text_size)
    self.tabs = {}
    for i, tab in ipairs(NavBar.TABS) do
        local active = tab.id == ACTIVE[self.where]
        if active then
            self.active = i
        end
        self.tabs[i] = {
            icon = TintedIcon:new{
                file = Icons.path(tab.icon),
                size = self.icon_size,
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

-- The band across the bottom: its fill, the active tab's fill, the dividers right of every tab
-- but the last, the edge across the width and the active rule from the bar's top.
local function paint_band(self, bb, x, y, color)
    local nav = self.look.nav
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
end

-- The band (paint_band), then the icons and labels.
function Bar:paintTo(bb, x, y)
    local nav = self.look.nav
    paint_band(self, bb, x, y, Looks.colorer({ look = self.look, variant = self.variant }))
    local left = x + self.padding_x
    local icon_top = y + content_top(nav, Screen)
    local label_top = icon_top + self.icon_size + Screen:scaleBySize(nav.icon_gap)
    for i, tab in ipairs(self.tabs) do
        local column = self.columns[i]
        local column_x = left + column.x
        tab.icon:paintTo(bb, column_x + math.floor((column.w - self.icon_size) / 2), icon_top)
        local label_w = tab.label:getSize().w
        tab.label:paintTo(bb, column_x + math.floor((column.w - label_w) / 2), label_top)
    end
end

-- The tab whose column holds pos, or nil outside the bar or in its side padding.
function Bar:column_at(pos)
    if not Helpers.inside(self.dimen, pos) then
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

-- Opens the quick-settings sheet over where, its paint_ms from now. Over the library the sheet's
-- failure closes the library (beneath); elsewhere, the home if shown. An error is logged with from,
-- what opened it, and goes no further, so the screen beneath stays as it was.
function NavBar.open_quick_settings(where, from)
    local ok, err = pcall(function()
        local beneath = where == "library" and require("library") or nil
        require("quick_settings").open{ started = PaintClock.now(), beneath = beneath }
    end)
    if not ok then
        logger.err("KoPanda: " .. from .. " could not open quick settings:", err)
    end
end

-- Whether the bar consumes ges: a tap on it runs the tab under it; a hold on Settings opens the
-- quick-settings sheet, any other hold runs nothing; with focused mode on, a tap on Settings opens the
-- sheet and a hold there runs the tab; anything else is left to what lies beneath.
function Bar:handle(ges)
    if not Helpers.inside(self.dimen, ges.pos) or (ges.ges ~= "tap" and ges.ges ~= "hold") then
        return false
    end
    local tab = self:column_at(ges.pos)
    if tab and tab.id == "settings" then
        local opens_sheet = Focused.on() and "tap" or "hold"
        if ges.ges == opens_sheet then
            NavBar.open_quick_settings(self.where, "the nav bar's Settings tab")
        else
            NavBar.run(tab.id, self.where)
        end
    elseif tab and ges.ges == "tap" then
        NavBar.run(tab.id, self.where)
    end
    return true
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

-- A bar { look, variant, width, where, listen, text_size } width × NavBar.height(look, Screen, text_size), its
-- type at text_size's shell size, where "home" (Home active), "file_browser" or "library" (Library active).
-- With listen it takes taps and holds on its dimen itself; without, it takes none, and its screen hands them
-- to handle.
function NavBar.new(args)
    return Bar:new{
        look = args.look,
        variant = args.variant,
        width = args.width,
        where = args.where,
        listen = args.listen or false,
        text_size = args.text_size,
    }
end

return NavBar
