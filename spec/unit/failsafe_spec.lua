-- Every hook fails safe: an error is logged, no home is left on the stack, and the file
-- manager is on top and handling input.
describe("KoPanda failing safe", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Home, logged, settled_listener
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

    -- True when an error line logged through logger.err mentions text.
    local function logged_error(text)
        for _, call in ipairs(logged.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    -- The file manager is on top and still takes input: a Show reaches its modules.
    local function file_manager_usable()
        assert.equals(FileManager.instance, harness.top())
        assert.equals(0, homes_on_stack())
        assert.is_nil(Home.shown)
    end

    before_each(function()
        harness.load()
        Home = require("home")
        logged = spy.on(logger, "err")
    end)

    after_each(function()
        if settled_listener then
            UIManager.event_hook:unregister("KoPandaSettled", settled_listener)
            settled_listener = nil
        end
        InputContainer.paintTo = original_paint
        logger.err:revert()
        harness.teardown()
    end)

    it("leaves the file manager on top when the home's build throws", function()
        Home.init = function()
            error("kopanda-test: build failed")
        end
        harness.show_fm()
        harness.tick(2)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: build failed"))
    end)

    it("takes the home off the stack when its show throws after it reached the stack", function()
        -- UIManager:show puts the widget on the stack, then sends it Show (uimanager.lua:259).
        Home.onShow = function()
            error("kopanda-test: show failed")
        end
        harness.show_fm()
        harness.tick(2)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: show failed"))
    end)

    it("closes the home when its paint throws", function()
        InputContainer.paintTo = function(self, ...)
            if self.name == "kopanda_home" then
                error("kopanda-test: paint failed")
            end
            return original_paint(self, ...)
        end
        harness.show_fm()
        harness.tick(3)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: paint failed"))
    end)

    it("sends no settled signal when the home's paint throws", function()
        local settled = 0
        settled_listener = function()
            settled = settled + 1
        end
        UIManager.event_hook:register("KoPandaSettled", settled_listener)
        InputContainer.paintTo = function(self, ...)
            if self.name == "kopanda_home" then
                error("kopanda-test: paint failed")
            end
            return original_paint(self, ...)
        end
        harness.show_fm()
        harness.tick(4)
        file_manager_usable()
        assert.equals(0, settled)
    end)

    it("consumes a gesture and closes the home when the gesture body throws", function()
        harness.show_fm()
        harness.tick(2)
        local home = Home.shown
        Home.routeGesture = function()
            error("kopanda-test: gesture failed")
        end
        local size = Screen:getSize()
        local ok, consumed = pcall(home.handleEvent, home,
            Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 2)))
        assert.is_true(ok)
        assert.is_true(consumed)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: gesture failed"))
    end)
end)
