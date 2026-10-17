describe("the KoPanda home over the file browser", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    local FileManager = require("apps/filemanager/filemanager")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local Screen = require("device").screen
    local Home, settled_listener
    local original_paint = InputContainer.paintTo

    local function homes_on_stack()
        local count = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_home" then
                count = count + 1
            end
        end
        return count
    end

    before_each(function()
        harness.load()
        Home = require("home")
    end)

    after_each(function()
        if settled_listener then
            UIManager.event_hook:unregister("KoPandaSettled", settled_listener)
            settled_listener = nil
        end
        InputContainer.paintTo = original_paint
        harness.teardown()
    end)

    it("defers the show to the next UI tick", function()
        local fm = harness.show_fm()
        assert.equals(fm, harness.top())
        assert.equals(0, homes_on_stack())
    end)

    it("shows a full-screen home over the file manager", function()
        harness.show_fm()
        harness.tick(2)
        local home = harness.top()
        assert.equals("kopanda_home", home.name)
        assert.equals(Home.shown, home)
        assert.is_true(home.covers_fullscreen)
        assert.same(Screen:getSize(), home.dimen)
        assert.equals(FileManager.instance, harness.top(2))
    end)

    it("sends the settled signal once, after the home's first paint", function()
        local home_painted = false
        InputContainer.paintTo = function(self, ...)
            if self.name == "kopanda_home" then
                home_painted = true
            end
            return original_paint(self, ...)
        end
        local signals = {}
        settled_listener = function(args)
            signals[#signals + 1] = { args = args, after_paint = home_painted }
        end
        UIManager.event_hook:register("KoPandaSettled", settled_listener)
        harness.show_fm()
        harness.tick(4)
        assert.equals(1, #signals)
        assert.is_true(signals[1].after_paint)
        assert.equals("home", signals[1].args.screen)
        assert.is_number(signals[1].args.paint_ms)
    end)

    it("lands over a history list opened right after showFiles (start_with = history)", function()
        harness.show_fm()
        -- reader.lua:291-295 shows the history synchronously after showFiles.
        FileManager.instance.history:onShowHist()
        local history = harness.top()
        assert.is_not.equals(FileManager.instance, history)
        harness.tick(2)
        assert.equals("kopanda_home", harness.top().name)
        assert.equals(history, harness.top(2))
    end)

    it("closes with the file manager", function()
        harness.show_fm()
        harness.tick(2)
        local home = Home.shown
        FileManager.instance:onClose()
        assert.is_false(UIManager:isWidgetShown(home))
        assert.is_nil(Home.shown)
        assert.same({}, harness.stack())
    end)

    it("forgets a home KOReader closes itself", function()
        local fm = harness.show_fm()
        harness.tick(2)
        UIManager:close(Home.shown)
        assert.is_nil(Home.shown)
        fm:handleEvent(Event:new("Show"))
        harness.tick(2)
        assert.equals(1, homes_on_stack())
        assert.equals(Home.shown, harness.top())
    end)

    it("shows exactly one home when the file manager is closed and shown again", function()
        harness.show_fm()
        harness.tick(2)
        FileManager.instance:onClose()
        local fm = harness.show_fm()
        harness.tick(2)
        assert.equals(1, homes_on_stack())
        assert.equals("kopanda_home", harness.top().name)
        assert.equals(fm, harness.top(2))
    end)

    it("shows no home when the file manager closes before the deferred show", function()
        local fm = harness.show_fm()
        fm:onClose()
        harness.tick(2)
        assert.equals(0, homes_on_stack())
        assert.is_nil(Home.shown)
    end)

    it("ignores a second Show while a home is up", function()
        local fm = harness.show_fm()
        harness.tick(2)
        local home = Home.shown
        fm:handleEvent(Event:new("Show"))
        harness.tick(2)
        assert.equals(1, homes_on_stack())
        assert.equals(home, harness.top())
    end)

    it("shows no home from a reader's instance", function()
        harness.show_fm()
        harness.tick(2)
        Home.close()
        assert.equals(0, homes_on_stack())
        local reader = harness.open_reader()
        harness.tick(2)
        assert.equals(reader, harness.top())
        assert.equals(0, homes_on_stack())
        assert.is_nil(Home.shown)
    end)

    it("closes on a tap outside every tappable slot, leaving the file manager on top", function()
        local fm = harness.show_fm()
        harness.tick(2)
        local size = Screen:getSize()
        local pos = require("ui/geometry"):new{ x = size.w / 2, y = size.h / 2, w = 0, h = 0 }
        assert.is_nil(Home.shown:tappableSlotAt(pos))
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 2)))
        assert.equals(0, homes_on_stack())
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    it("stays up, under the file manager's menu, on a tap in KOReader's top menu zone", function()
        harness.show_fm()
        harness.tick(2)
        local home = Home.shown
        local size = Screen:getSize()
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 16)))
        assert.equals(FileManager.instance.menu.menu_container, harness.top())
        assert.equals(home, harness.top(2))
        assert.equals(home, Home.shown)
    end)
end)
