-- Focused mode's reader hooks: with focused.on, KOReader's top and bottom menu gestures and a tap on the status bar
-- open the focused panel in place of KOReader's menus, and a hold on the status bar runs nothing; with it off, or
-- when the panel fails, KOReader's own handler runs. The six handlers are replaced by recording stubs before the
-- hooks wrap them, and the panel's opener by a recorder; every stub is put back after the test that makes it.
describe("the focused hooks", function()
    local harness = require("plugin_harness")
    local Geom = require("ui/geometry")
    local ReaderConfig = require("apps/reader/modules/readerconfig")
    local ReaderFooter = require("apps/reader/modules/readerfooter")
    local ReaderMenu = require("apps/reader/modules/readermenu")
    local logger = require("logger")
    local FocusedHooks, FocusedPanel, Settings

    local HANDLERS = {
        { ReaderMenu, "onTapShowMenu" },
        { ReaderMenu, "onSwipeShowMenu" },
        { ReaderConfig, "onTapShowConfigMenu" },
        { ReaderConfig, "onSwipeShowConfigMenu" },
        { ReaderFooter, "TapFooter" },
        { ReaderFooter, "onHoldFooter" },
    }

    -- Undo steps for the running test, run last first after it.
    local undo = {}

    local function set(t, key, value)
        local old = rawget(t, key)
        undo[#undo + 1] = function()
            rawset(t, key, old)
        end
        rawset(t, key, value)
    end

    -- Each original's calls, by handler name, as { self, args... }; and the panel's opens, as the ui.
    local calls, opened

    -- A reader's ui recording the events sent to it.
    local function fake_ui()
        local ui = { events = {} }
        function ui:handleEvent(event)
            self.events[#self.events + 1] = event.handler:sub(3)
        end
        return ui
    end

    -- An instance of class over a fake ui, with KOReader's default activate_menu and a footer shown at the bottom.
    local function instance(class)
        return setmetatable({
            ui = fake_ui(),
            activation_menu = "swipe_tap",
            view = { footer_visible = true },
            footer_content = { dimen = Geom:new{ x = 0, y = 1600, w = 1264, h = 80 } },
        }, { __index = class })
    end

    local function ges(direction, x, y)
        return { ges = direction and "swipe" or "tap", direction = direction,
            pos = Geom:new{ x = x or 600, y = y or 40, w = 0, h = 0 } }
    end

    before_each(function()
        undo = {}
        harness.load()
        calls, opened = {}, {}
        for _, handler in ipairs(HANDLERS) do
            local class, name = handler[1], handler[2]
            calls[name] = {}
            set(class, name, function(self, ...)
                calls[name][#calls[name] + 1] = { self, ... }
                return "original " .. name
            end)
        end
        FocusedPanel = require("focused_panel")
        Settings = require("settings")
        set(FocusedPanel, "open", function(ui)
            opened[#opened + 1] = ui
        end)
        FocusedHooks = require("focused_hooks")
        FocusedHooks.install()
    end)

    after_each(function()
        for i = #undo, 1, -1 do
            undo[i]()
        end
        harness.teardown()
    end)

    -- How many calls every original has had, all told.
    local function original_calls()
        local n = 0
        for _, list in pairs(calls) do
            n = n + #list
        end
        return n
    end

    it("opens the panel for a top tap or swipe down, a bottom tap or swipe up and a status bar tap", function()
        local cases = {
            { ReaderMenu, "onTapShowMenu", ges(), {} },
            { ReaderMenu, "onSwipeShowMenu", ges("south"), { "HandledAsSwipe" } },
            { ReaderConfig, "onTapShowConfigMenu", nil, {} },
            { ReaderConfig, "onSwipeShowConfigMenu", ges("north", 600, 1600), { "HandledAsSwipe" } },
            { ReaderFooter, "TapFooter", ges(nil, 600, 1620), {} },
        }
        for _, case in ipairs(cases) do
            opened = {}
            local self = instance(case[1])
            assert.is_true(self[case[2]](self, case[3]), case[2])
            assert.same({ self.ui }, opened, case[2])
            assert.same(case[4], self.ui.events, case[2])
        end
        assert.equals(0, original_calls())
    end)

    it("passes over a gesture KOReader's activate_menu or the swipe's direction rules out, opening nothing", function()
        local cases = {
            { ReaderMenu, "onTapShowMenu", "swipe", ges() },
            { ReaderMenu, "onSwipeShowMenu", "tap", ges("south") },
            { ReaderMenu, "onSwipeShowMenu", "swipe_tap", ges("north") },
            { ReaderConfig, "onTapShowConfigMenu", "swipe", nil },
            { ReaderConfig, "onSwipeShowConfigMenu", "tap", ges("north", 600, 1600) },
            { ReaderConfig, "onSwipeShowConfigMenu", "swipe_tap", ges("south", 600, 1600) },
        }
        for _, case in ipairs(cases) do
            local self = instance(case[1])
            self.activation_menu = case[3]
            assert.is_nil(self[case[2]](self, case[4]), case[2] .. " " .. case[3])
            assert.same({}, self.ui.events, case[2])
        end
        assert.same({}, opened)
        assert.equals(0, original_calls())
    end)

    it("runs KOReader's own handlers with their arguments when the mode is off, and opens nothing", function()
        Settings.set("focused.on", false)
        for _, handler in ipairs(HANDLERS) do
            local self = instance(handler[1])
            local g = ges("south")
            assert.equals("original " .. handler[2], self[handler[2]](self, g, "extra"), handler[2])
            assert.same({ { self, g, "extra" } }, calls[handler[2]], handler[2])
        end
        assert.same({}, opened)
    end)

    it("runs KOReader's own handler, and logs why, when the panel fails to open", function()
        set(FocusedPanel, "open", function()
            error("kopanda-test: no panel")
        end)
        local err = spy.on(logger, "err")
        undo[#undo + 1] = function()
            err:revert()
        end
        local self = instance(ReaderMenu)
        local g = ges()
        assert.equals("original onTapShowMenu", self:onTapShowMenu(g))
        assert.same({ { self, g } }, calls.onTapShowMenu)
        local logged = false
        for _, call in ipairs(err.calls) do
            logged = logged or call.vals[1] == "KoPanda: the focused panel failed:"
        end
        assert.is_true(logged)
    end)

    it("consumes a hold on the status bar, and passes one beside it on to KOReader's handler", function()
        local self = instance(ReaderFooter)
        assert.is_true(self:onHoldFooter(ges(nil, 600, 1620)))
        assert.equals(0, original_calls())
        assert.same({}, opened)
        local beside = ges(nil, 600, 1500)
        assert.equals("original onHoldFooter", self:onHoldFooter(beside))
        assert.same({ { self, beside } }, calls.onHoldFooter)
        self.view.footer_visible = false
        calls.onHoldFooter = {}
        self:onHoldFooter(ges(nil, 600, 1620))
        assert.equals(1, #calls.onHoldFooter)
    end)

    it("wraps each handler once however often it is installed", function()
        local wrapped = {}
        for i, handler in ipairs(HANDLERS) do
            wrapped[i] = handler[1][handler[2]]
        end
        FocusedHooks.install()
        for i, handler in ipairs(HANDLERS) do
            assert.equals(wrapped[i], handler[1][handler[2]], handler[2])
        end
    end)
end)
