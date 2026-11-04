-- The home's gestures: its own touch zones and the order a gesture on the home runs in, a page swipe, one of its own
-- zones, consumed so it can't page the file chooser under the home. The home's onGesture (home.lua) calls route through
-- a pcall. With focused mode on, a hold in the top zone opens FileManagerMenu:onShowMenu
-- (frontend/apps/filemanager/filemanagermenu.lua:1006); a tap or swipe there reads its activation_menu (:51).
local Focused = require("focused")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local NavBar = require("nav_bar")
local PaintClock = require("paint_clock")
local SettingsMenu = require("settings_menu")
local Screen = require("device").screen

local HomeGestures = {}

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

-- A one-finger west or east swipe outside the top and bottom edge bands. Passed on, it would page the
-- hidden file chooser through the file manager's full-screen swipe zone (filemanager.lua:81-98, :474-482);
-- Gestures binds these swipes only inside those bands (gestures main.lua:1168-1195).
function HomeGestures.is_page_swipe(ges)
    return ges.ges == "swipe" and (ges.direction == "west" or ges.direction == "east")
        and not in_zone("DSWIPE_ZONE_TOP_EDGE", ges.pos)
        and not in_zone("DSWIPE_ZONE_BOTTOM_EDGE", ges.pos)
end

-- The home's own steps are touch zones on the home, matched through InputContainer.onGesture: KOReader's
-- touch lock swaps it for _onGestureFiltered, which runs only the zones isGestureAlwaysActive approves
-- (frontend/ui/widget/container/inputcontainer.lua:297-350). A zone's handler only names its step, which
-- route runs in order. The zones cover the whole screen; their handlers test the bands against the
-- screen's size now. A tap or swipe in the top menu zones names the "top" step.
local FULL_SCREEN = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 }

-- The zones the home registers on itself at init.
function HomeGestures.own_zones(home)
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
                home.own_step = in_menu_zone(ges.pos) and "top" or "tap"
                return true
            end,
        },
        {
            id = "kopanda_home_page",
            ges = "swipe",
            screen_zone = FULL_SCREEN,
            handler = function(ges)
                if HomeGestures.is_page_swipe(ges) then
                    home.own_step = "page"
                    return true
                end
            end,
        },
        {
            id = "kopanda_home_top_swipe",
            ges = "swipe",
            screen_zone = FULL_SCREEN,
            handler = function(ges)
                if in_menu_zone(ges.pos) then
                    home.own_step = "top"
                    return true
                end
            end,
        },
        -- No menu-zone test: the file manager's menu zones are tap and swipe only
        -- (frontend/apps/filemanager/filemanagermenu.lua:76-113).
        {
            id = "kopanda_home_hold",
            ges = "hold",
            screen_zone = FULL_SCREEN,
            handler = function()
                home.own_step = "hold"
                return true
            end,
        },
    }
end

-- A hold on the home: inside a slot whose widget has hold, that hold, unless it returns false; else the
-- settings of its group; outside every slot or in a blank one, the home's sheet. home_sheet is required
-- here: it reaches launcher_entries, which requires home (launcher_entries.lua:5), which requires this.
local function hold(home, ges)
    local started = PaintClock.now()
    local slot = home:slotAt(ges.pos)
    local module = slot and slot.module
    if module then
        if not module.hold then
            SettingsMenu.open(module.settings_prefix)
            return true
        end
        if module.hold(home.ctx, ges, slot.built) ~= false then
            return true
        end
    end
    require("home_sheet").open(home.ctx, { started = started })
    return true
end

-- The top-edge step, shared by the home and the library (library_chrome.lua): with focused mode on and a file
-- manager up, a tap or a swipe down in the top menu zones opens the quick-settings sheet over where (a nav bar's
-- where), each only as KOReader's activate_menu lets the file manager's menu open on it
-- (filemanagermenu.lua:1102-1114), and a hold there opens that menu. Whether one consumed ges.
function HomeGestures.focused_top(ges, where)
    if not in_menu_zone(ges.pos) or not Focused.on() then
        return false
    end
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local menu = FileManager and FileManager.instance and FileManager.instance.menu
    if not menu then
        return false
    end
    if ges.ges == "hold" then
        menu:onShowMenu()
        return true
    end
    local activation = menu.activation_menu
    if (ges.ges == "tap" and activation ~= "swipe")
        or (ges.ges == "swipe" and ges.direction == "south" and activation ~= "tap") then
        NavBar.open_quick_settings(where, "the top edge")
        return true
    end
    return false
end

-- The forward step, shared by the home and the library (library_chrome.lua): the file manager's menu
-- zones (filemanagermenu.lua:71-124, :1102-1114); a page swipe, consumed; then the zones on the file
-- manager itself, the Gestures plugin's among them (gestures main.lua:1287-1288). With a KoPanda window
-- on top, UIManager:sendEvent offers the file manager nothing but its screenshot module
-- (frontend/ui/uimanager.lua:962-1034), hence the forwarding. Whether one consumed ges.
function HomeGestures.forward(ges)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if fm and InputContainer.onGesture(fm.menu, ges) then
        return true
    end
    if HomeGestures.is_page_swipe(ges) then
        return true
    end
    if fm and InputContainer.onGesture(fm, ges) then
        return true
    end
    return false
end

-- The home's gestures, in order, each step stopping at the first that consumes: its own swipe up; a
-- tap or hold in the nav bar's band; its own page swipe, consumed; the top-edge step (focused_top); the
-- forward step, so a hold corner bound on the file manager wins over the hold (gestures main.lua:1124-1139);
-- the hold step; a tap outside the top menu zones runs the tapped slot's widget, and otherwise, or on
-- false, closes the home onto the file browser via close(home), or with focused mode on is consumed.
function HomeGestures.route(home, ges, close)
    home.own_step = nil
    -- The home's own zones, under KOReader's touch lock (see own_zones).
    InputContainer.onGesture(home, ges)
    local own_step = home.own_step
    home.own_step = nil
    if own_step == "settings" then
        SettingsMenu.open()
        return true
    end
    if (own_step == "tap" or own_step == "hold") and home.nav and home.nav:handle(ges) then
        return true
    end
    if own_step == "page" then
        return true
    end
    if (own_step == "top" or own_step == "hold") and HomeGestures.focused_top(ges, "home") then
        return true
    end
    if HomeGestures.forward(ges) then
        return true
    end
    if own_step == "hold" then
        return hold(home, ges)
    end
    if own_step == "tap" then
        local slot = home:tappableSlotAt(ges.pos)
        if slot and slot.module.tap(home.ctx, ges, slot.built) ~= false then
            return true
        end
        if not Focused.on() then
            close(home)
        end
        return true
    end
    return false
end

return HomeGestures
