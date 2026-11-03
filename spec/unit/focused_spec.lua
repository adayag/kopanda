-- Focused mode's switch: Focused.on() reads focused.on at each call, true with nothing stored, and reads a
-- Settings.get that raises as off, logging why.
describe("Focused.on", function()
    local harness = require("plugin_harness")
    local logger = require("logger")
    local Focused, Settings

    before_each(function()
        harness.load()
        Focused = package.loaded["focused"]
        Settings = package.loaded["settings"]
    end)

    after_each(function()
        harness.teardown()
    end)

    it("is true with nothing stored", function()
        assert.is_true(Focused.on())
    end)

    it("is false once focused.on is set false, and true again once set true", function()
        assert.is_true(Settings.set("focused.on", false))
        assert.is_false(Focused.on())
        assert.is_true(Settings.set("focused.on", true))
        assert.is_true(Focused.on())
    end)

    it("is false, and logs why, when Settings.get raises", function()
        local get = stub(Settings, "get", function()
            error("kopanda-test: no settings")
        end)
        local err = spy.on(logger, "err")
        finally(function()
            get:revert()
            err:revert()
        end)
        assert.is_false(Focused.on())
        local logged = false
        for _, call in ipairs(err.calls) do
            logged = logged or (call.vals[1] == "KoPanda: could not read focused.on:"
                and tostring(call.vals[2]):find("kopanda-test: no settings", 1, true) ~= nil)
        end
        assert.is_true(logged)
    end)
end)
