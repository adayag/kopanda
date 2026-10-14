-- Closing a book builds the home before the file browser comes back, and the file manager's
-- show puts that pre-built home up at once.
describe("the KoPanda home pre-built on book close", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local Home, new_spy

    -- The home's constructor: Home:new{} resolves Widget:new through Home's metatable, so the
    -- spy sits on Home itself and sees every build.
    local function spy_builds()
        new_spy = spy.on(Home, "new")
        return new_spy
    end

    before_each(function()
        harness.load()
        Home = require("home")
    end)

    after_each(function()
        if new_spy then
            new_spy:revert()
            new_spy = nil
        end
        harness.teardown()
    end)

    it("builds a home on CloseDocument and keeps it pending, not shown", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        assert.is_not_nil(Home.pending)
        assert.equals("kopanda_home", Home.pending.name)
        assert.is_false(UIManager:isWidgetShown(Home.pending))
        assert.is_nil(Home.shown)
    end)

    it("puts the pending home on top synchronously from the file manager's show", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        local pending = Home.pending
        local builds = spy_builds()
        local fm = harness.show_fm()
        assert.equals(pending, harness.top())
        assert.equals(fm, harness.top(2))
        assert.equals(pending, Home.shown)
        assert.is_nil(Home.pending)
        harness.tick(2)
        assert.equals(pending, harness.top())
        assert.equals(pending, Home.shown)
        assert.spy(builds).was_not_called()
    end)

    it("signals a pre-built home's paint as prebuilt", function()
        local signals = {}
        local listener = function(args)
            signals[#signals + 1] = args
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        harness.show_fm()
        harness.tick(4)
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        assert.equals(1, #signals)
        assert.equals("home", signals[1].screen)
        assert.is_true(signals[1].prebuilt)
        assert.is_number(signals[1].paint_ms)
    end)

    it("times a pending home that the deferred show finds", function()
        local signals = {}
        local listener = function(args)
            signals[#signals + 1] = args
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
        harness.show_fm()
        Home.prebuild()
        local pending = Home.pending
        harness.tick(4)
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        assert.equals(pending, harness.top())
        assert.equals(1, #signals)
        assert.is_true(signals[1].prebuilt)
        assert.is_number(signals[1].paint_ms)
    end)

    it("drops a pending home of another size and shows a fresh one", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        local pending = Home.pending
        local size = Screen:getSize()
        pending.dimen = Geom:new{ x = 0, y = 0, w = size.h, h = size.w }
        local freed = spy.on(pending, "free")
        harness.show_fm()
        harness.tick(2)
        local home = harness.top()
        assert.equals("kopanda_home", home.name)
        assert.is_not.equals(pending, home)
        assert.equals(home, Home.shown)
        assert.same(size, home.dimen)
        assert.is_false(UIManager:isWidgetShown(pending))
        assert.is_nil(Home.pending)
        assert.spy(freed).was_called()
    end)

    it("drops the pending home when a new reader starts (switch, reload)", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        local pending = Home.pending
        assert.is_not_nil(pending)
        local freed = spy.on(pending, "free")
        harness.open_reader("the-time-machine.epub")
        assert.is_nil(Home.pending)
        assert.spy(freed).was_called()
    end)

    it("builds nothing more on a second CloseDocument while a home is pending", function()
        local reader = harness.open_reader()
        harness.tick(2)
        local builds = spy_builds()
        -- KoPanda's handler returns nothing, so CloseDocument goes on to later modules.
        local consumed = reader.kopanda:handleEvent(Event:new("CloseDocument"))
        assert.is_falsy(consumed)
        local pending = Home.pending
        assert.is_not_nil(pending)
        reader:onClose()
        assert.equals(pending, Home.pending)
        assert.spy(builds).was_called(1)
    end)
end)
