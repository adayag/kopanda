-- paint_clock.lua's settled signal: a screen's paint_ms and cpu_ms from its show to its first
-- paint, sent on the dev loop's KoPandaSettled hook, a failure logged and kept from the UI loop.
describe("paint_clock", function()
    local harness = require("plugin_harness")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local PaintClock, signals, listener

    before_each(function()
        harness.load()
        PaintClock = package.loaded["paint_clock"]
        signals = {}
        listener = function(fields)
            signals[#signals + 1] = fields
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
    end)

    after_each(function()
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        harness.teardown()
    end)

    it("sends the screen's fields with paint_ms and cpu_ms from started to painted_at", function()
        local started = { wall = PaintClock.now().wall, cpu = 1.0 }
        local painted_at = { wall = started.wall + require("ui/time").ms(250), cpu = 1.0406 }
        PaintClock.settled("the sheet's", started, painted_at, { screen = "sheet", name = "book" })
        assert.same({ { screen = "sheet", name = "book", paint_ms = 250, cpu_ms = 41 } }, signals)
    end)

    it("runs paint_ms on to now without a paint stamp", function()
        PaintClock.settled("the swatch", PaintClock.now(), nil, { screen = "swatch" })
        assert.equals(1, #signals)
        assert.equals("swatch", signals[1].screen)
        assert.is_true(signals[1].paint_ms >= 0)
    end)

    it("logs a failure as what's settled signal, raising nothing", function()
        local logged = spy.on(logger, "err")
        finally(function()
            logger.err:revert()
        end)
        PaintClock.settled("the editor's", nil, nil, { screen = "edit_layout" })
        assert.same({}, signals)
        assert.spy(logged).was_called(1)
        assert.equals("KoPanda: the editor's settled signal failed:", logged.calls[1].vals[1])
    end)
end)
