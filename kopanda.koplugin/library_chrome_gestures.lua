-- The gesture route of the library's windows: the touch zones a window registers, matched through
-- InputContainer.onGesture (frontend/ui/widget/container/inputcontainer.lua:297-350), its tap and hold steps and the
-- order of its steps. tap and routeGesture are LibraryChrome.Window's methods (library_chrome.lua).
local BD = require("ui/bidi")
local Helpers = require("helpers")
local HomeGestures = require("home_gestures")
local InputContainer = require("ui/widget/container/inputcontainer")
local LibrarySheets = require("library_sheets")
local PaintClock = require("paint_clock")
local logger = require("logger")

local ChromeGestures = {}

-- As the home's (home_gestures.lua): the window's own steps are touch zones on it, matched through
-- InputContainer.onGesture, so KOReader's touch lock filters them
-- (frontend/ui/widget/container/inputcontainer.lua:297-350). A handler only names its step, which route runs.
local FULL_SCREEN = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 }

function ChromeGestures.own_zones(window)
    local zones = {}
    for _, ges in ipairs({ "tap", "hold", "swipe" }) do
        zones[#zones + 1] = {
            id = "kopanda_library_" .. ges,
            ges = ges,
            screen_zone = FULL_SCREEN,
            handler = function()
                window.own_step = ges
                return true
            end,
        }
    end
    return zones
end

-- The action a tap at pos runs, or nil where no part of the window acts on taps: its own parts
-- (window:action_at); the back control runs window:back(); a live pager arrow turns the page.
local function action_at(window, pos)
    local own = window:action_at(pos)
    if own then
        return own
    end
    local top, foot = window.header, window.pager
    local back = top.back_rect or top.title_rect
    if back and Helpers.inside(back, pos) then
        return function()
            window:back()
        end
    end
    for delta, which in pairs({ [-1] = "prev", [1] = "next" }) do
        if foot[which].live and Helpers.inside(foot[which].rect, pos) then
            return function()
                window:turn(delta)
            end
        end
    end
    return nil
end

-- Whether a tap at pos is the window's: one on a part that acts on taps runs its action, a
-- raising one logged with the page left as it was.
function ChromeGestures:tap(pos)
    local action = action_at(self, pos)
    if not action then
        return false
    end
    local ok, err = pcall(action)
    if not ok then
        logger.err("KoPanda: the " .. self.screen .. "'s tap failed:", err)
    end
    return true
end

-- The hold step: what lies at pos (window.hit) handed to the window's own hold_sheet, else to
-- LibrarySheets.hold, which opens its sheet over the window. A hit or dispatch that raises is logged and
-- the hold consumed.
local function hold_step(window, pos)
    local started = PaintClock.now()
    local ok, err = pcall(function()
        local hit = window.hit and window.hit(pos.x, pos.y)
        if window.hold_sheet then
            window:hold_sheet(hit, started)
        else
            LibrarySheets.hold(window, hit, started)
        end
    end)
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s hold failed:", err)
    end
    return true
end

-- The window's gestures, in order, each step stopping at the first that consumes: a tap or hold in the nav
-- bar's band; a tap on a part of the window that acts on taps (window:tap); the home's bottom-edge step
-- (HomeGestures.bottom_swipe) for a swipe the window's own zones named; a west or east swipe outside the
-- edge bands turns the page, mirrored as Menu:onSwipe reads it (frontend/ui/widget/menu.lua:1518-1523);
-- the home's top-edge step (HomeGestures.focused_top) for a gesture the window's own zones named; the home's
-- forward step (HomeGestures.forward), so a hold corner bound on the file manager wins over the hold, as on the
-- home; then the hold step. Whatever none of them takes is consumed.
function ChromeGestures:routeGesture(ges)
    self.own_step = nil
    InputContainer.onGesture(self, ges)
    local own_step = self.own_step
    self.own_step = nil
    if (own_step == "tap" or own_step == "hold") and self.nav and self.nav:handle(ges) then
        return true
    end
    if own_step == "tap" and self:tap(ges.pos) then
        return true
    end
    if own_step == "swipe" and HomeGestures.bottom_swipe(ges, self.nav and self.nav.where or self.screen) then
        return true
    end
    if own_step == "swipe" and HomeGestures.is_page_swipe(ges) then
        self:turn(BD.flipDirectionIfMirroredUILayout(ges.direction) == "west" and 1 or -1)
        return true
    end
    if own_step and HomeGestures.focused_top(ges) then
        return true
    end
    if HomeGestures.forward(ges) then
        return true
    end
    if own_step == "hold" then
        return hold_step(self, ges.pos)
    end
    return true
end

return ChromeGestures
