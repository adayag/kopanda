-- Focused mode's reader hooks: with focused.on, a top tap or swipe down, a bottom tap or swipe up and a tap on the
-- status bar open the focused panel in place of KOReader's menus, and a hold on the status bar runs nothing. Wraps
-- ReaderMenu:onTapShowMenu and :onSwipeShowMenu (frontend/apps/reader/modules/readermenu.lua:484-503),
-- ReaderConfig:onTapShowConfigMenu and :onSwipeShowConfigMenu (readerconfig.lua:154-166) and ReaderFooter:TapFooter
-- and :onHoldFooter (readerfooter.lua:2517-2530, :2647-2663); with the mode off, or on a failure, the original runs.
local Event = require("ui/event")
local Focused = require("focused")
local FocusedPanel = require("focused_panel")
local ReaderConfig = require("apps/reader/modules/readerconfig")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local ReaderMenu = require("apps/reader/modules/readermenu")
local logger = require("logger")

local FocusedHooks = {}

local installed = false

-- Cancels a pan scroll the swipe made, as the originals do (readermenu.lua:490, readerconfig.lua:150).
local function handled_as_swipe(self)
    local ok, err = pcall(function()
        self.ui:handleEvent(Event:new("HandledAsSwipe"))
    end)
    if not ok then
        logger.err("KoPanda: the focused panel could not mark its swipe handled:", err)
    end
end

-- Wraps class[name]: with the mode on, a gesture wants(self, ...) accepts opens the panel over self.ui, runs
-- after(self) when given and returns true; one it refuses returns nil, as the original does, so the reader's other
-- zones still get it. With the mode off, or when wants or the panel raises, the original runs with the same arguments.
local function wrap(class, name, wants, after)
    local original = class[name]
    class[name] = function(self, ...)
        if not Focused.on() then
            return original(self, ...)
        end
        local ok, opened = pcall(function(...)
            if not wants(self, ...) then
                return false
            end
            FocusedPanel.open(self.ui)
            return true
        end, ...)
        if not ok then
            logger.err("KoPanda: the focused panel failed:", opened)
            return original(self, ...)
        end
        if not opened then
            return nil
        end
        if after then
            after(self)
        end
        return true
    end
end

local function tap_allowed(self)
    return self.activation_menu ~= "swipe"
end

-- A swipe the original would take: allowed by activate_menu and in direction.
local function swipe_allowed(direction)
    return function(self, ges)
        return self.activation_menu ~= "tap" and ges.direction == direction
    end
end

local function always()
    return true
end

-- A hold on the shown status bar, where the original would open its skim dialog (readerfooter.lua:2647-2663), is
-- consumed; any other hold goes to the original, which passes it on to the word hold.
local function wrap_hold_footer()
    local original = ReaderFooter.onHoldFooter
    ReaderFooter.onHoldFooter = function(self, ges, ...)
        if not Focused.on() then
            return original(self, ges, ...)
        end
        local ok, on_footer = pcall(function()
            local dimen = self.footer_content.dimen
            return self.view.footer_visible and dimen ~= nil and dimen:contains(ges.pos)
        end)
        if not ok then
            logger.err("KoPanda: could not tell whether a hold is on the status bar:", on_footer)
        elseif on_footer then
            return true
        end
        return original(self, ges, ...)
    end
end

-- Wraps the six handlers on their classes, once per process; every reader's modules are instances of them.
function FocusedHooks.install()
    if installed then
        return
    end
    installed = true
    wrap(ReaderMenu, "onTapShowMenu", tap_allowed)
    wrap(ReaderMenu, "onSwipeShowMenu", swipe_allowed("south"), handled_as_swipe)
    wrap(ReaderConfig, "onTapShowConfigMenu", tap_allowed)
    wrap(ReaderConfig, "onSwipeShowConfigMenu", swipe_allowed("north"), handled_as_swipe)
    wrap(ReaderFooter, "TapFooter", always)
    wrap_hold_footer()
end

return FocusedHooks
