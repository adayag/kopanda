-- The nav bar: five tabs across a screen's bottom, Home, Library, Authors, History and Settings,
-- drawn from the look's nav tokens: a band across the bottom, or with nav.float a pill on the
-- page inset by nav.margin (Toybox). The home, the file browser and the library each build one with
-- their own tab active and set its dimen's x and y where they place it. A tap in a tab's column runs
-- the tab, a hold on Settings opens the quick-settings sheet, any other hold on the bar is consumed
-- and runs nothing, and every other gesture passes through.
--
-- launcher_entries, quick_settings, library, series_screen and authors_screen are required at call
-- time: launcher_entries requires home (launcher_entries.lua:6), which reaches this module through
-- home_rows, so a load-time require would loop, quick_settings requires launcher_entries, and the
-- chrome windows reach this module through library_chrome.
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
    { id = "authors", label = "Authors", icon = "authors" },
    { id = "history", label = "History", icon = "history" },
    { id = "settings", label = "Settings", icon = "settings" },
}

-- The active tab's id, by where the bar is: the Authors window lights Authors; the Series window
-- lights none, and no screen of History or Settings carries the bar.
local ACTIVE = { home = "home", file_browser = "library", library = "library", authors = "authors" }

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
-- a label line and the tab's bottom padding; a floating pill's outline at its foot and its margin
-- below it besides. Raises when a label face won't load.
function NavBar.height(look, screen)
    local nav = look.nav
    local h = content_top(nav, screen) + screen:scaleBySize(nav.icon_size) + screen:scaleBySize(nav.icon_gap)
        + label_height(look, screen) + screen:scaleBySize(nav.padding_bottom)
    if nav.float then
        h = h + screen:scaleBySize(nav.edge_width) + screen:scaleBySize(nav.margin.bottom)
    end
    return h
end

-- The window module each chrome window's bar closes on Home, by where.
local WINDOWS = { library = "library", series = "series_screen", authors = "authors_screen" }

-- Runs the tab id from where, "home", "file_browser", "library", "series" or "authors". An error is logged
-- with the tab's name and goes no further, so the screen under the bar stays as it was.
function NavBar.run(id, where)
    local ok, err = pcall(function()
        if id == "home" then
            -- On the home, Home is the screen already. From the file browser, KoPanda's instance,
            -- registered under its name (frontend/apps/filemanager/filemanager.lua:379-389, :424);
            -- from a chrome window, the same once the window has closed onto the file browser. The
            -- window's module is required now: it requires this module.
            if WINDOWS[where] then
                require(WINDOWS[where]).close()
            end
            if where == "file_browser" or WINDOWS[where] then
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

-- Builds each tab's icon and label once; the columns split the width less the side padding, and
-- for a floating pill its margin and outline, with the tab gap between them.
function Bar:init()
    local look, nav = self.look, self.look.nav
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = NavBar.height(look, Screen) }
    -- Where the columns start from the bar's left: its side padding, and a floating pill's margin
    -- and outline before it.
    self.padding_x = Screen:scaleBySize(nav.padding_x)
    if nav.float then
        self.padding_x = self.padding_x + Screen:scaleBySize(nav.margin.side) + Screen:scaleBySize(nav.edge_width)
    end
    local shares = {}
    for i = 1, #NavBar.TABS do
        shares[i] = { share = 1 }
    end
    self.columns = Layout.columns(self.width - 2 * self.padding_x, shares, nav.tab_gap)
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

-- A floating pill on the band's fill: the pill's shadow, its fill, the active tab's pill and its
-- outline inside the pill's padding, then the pill's outline; all rounded by nav.radius, which
-- the paint holds to half the pill's height (base/ffi/blitbuffer.lua:2169-2197).
local function paint_pill(self, bb, x, y, color)
    local nav = self.look.nav
    local function scale(px)
        return Screen:scaleBySize(px)
    end
    local w, h = self.dimen.w, self.dimen.h
    local edge, radius = scale(nav.edge_width), scale(nav.radius)
    local side = scale(nav.margin.side)
    local pill_x, pill_w, pill_h = x + side, w - 2 * side, h - scale(nav.margin.bottom)
    Paint.fill(bb, x, y, w, h, color(nav.fill_color))
    local shadow_color = color(nav.shadow.color)
    if shadow_color then
        Paint.fill(bb, pill_x + scale(nav.shadow.x), y + scale(nav.shadow.y), pill_w, pill_h, shadow_color, radius)
    end
    -- A pill whose fill role the variant lacks takes the page's, so its shadow stays under it.
    Paint.fill(bb, pill_x, y, pill_w, pill_h, color(nav.float_fill_color) or color(nav.fill_color), radius)
    local active = self.columns[self.active]
    if active then
        local inset = edge + scale(nav.padding_x)
        local lit_x, lit_y, lit_h = x + self.padding_x + active.x, y + inset, pill_h - 2 * inset
        if nav.active_fill_color then
            Paint.fill(bb, lit_x, lit_y, active.w, lit_h, color(nav.active_fill_color), radius)
        end
        if nav.active_outline_width > 0 then
            Paint.border(bb, lit_x, lit_y, active.w, lit_h, scale(nav.active_outline_width),
                color(nav.active_outline_color), radius)
        end
    end
    if edge > 0 then
        Paint.border(bb, pill_x, y, pill_w, pill_h, edge, color(nav.edge_color), radius)
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

-- The band (paint_band) or the floating pill (paint_pill), then the icons and labels.
function Bar:paintTo(bb, x, y)
    local nav = self.look.nav
    local color = Looks.colorer({ look = self.look, variant = self.variant })
    if nav.float then
        paint_pill(self, bb, x, y, color)
    else
        paint_band(self, bb, x, y, color)
    end
    local left = x + self.padding_x
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

-- Opens the quick-settings sheet from the bar on where, its paint_ms from now. Over the library
-- the sheet's failure closes the library (beneath); elsewhere, the home if shown. An error is
-- logged with the tab's name and goes no further, so the screen under the bar stays as it was.
local function open_quick_settings(where)
    local ok, err = pcall(function()
        local beneath = where == "library" and require("library") or nil
        require("quick_settings").open{ started = PaintClock.now(), beneath = beneath }
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
    if not Helpers.inside(self.dimen, ges.pos) then
        return false
    end
    if ges.ges == "hold" then
        local tab = self:column_at(ges.pos)
        if tab and tab.id == "settings" then
            open_quick_settings(self.where)
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
-- (Home active), "file_browser" or "library" (Library active). With listen it takes taps and holds on its
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
