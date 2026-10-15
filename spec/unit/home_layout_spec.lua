-- The home built from layout.rows (C4, the engine part): one slot per entry at its column width,
-- blank slots for a missing or failing widget, taps routed to a slot's widget, rebuilds on
-- Resume and TimeFormatChanged, and nothing left in UIManager's task queue. The widgets are
-- stubs registered for the spec.
describe("the home's rows", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    local Widget = require("ui/widget/widget")
    local Geom = require("ui/geometry")
    local Screen = require("device").screen
    local logger = require("logger")
    local Home, Widgets, Looks, Schema, stubs, builds, widths, contexts, taps, warned, errored

    -- A stub widget module: height h at any width, a build that counts and records its width
    -- and ctx, and the given tap.
    local function stub(id, h, tap)
        return {
            id = id,
            settings_prefix = id,
            height = function()
                return h
            end,
            build = function(width, ctx)
                builds[id] = (builds[id] or 0) + 1
                widths[id] = width
                contexts[id] = ctx
                return Widget:new{ name = "kopanda_spec_stub", stub = id, dimen = Geom:new{ w = width, h = h } }
            end,
            tap = tap,
        }
    end

    local function logged(text)
        for _, s in ipairs({ warned, errored }) do
            for _, call in ipairs(s.calls) do
                for _, arg in ipairs(call.vals) do
                    if tostring(arg):find(text, 1, true) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function show_home()
        local fm = harness.show_fm()
        harness.tick(2)
        assert.equals(Home.shown, harness.top())
        return fm, Home.shown
    end

    -- The home's slot for widget id.
    local function slot_of(home, id)
        for _, slot in ipairs(home.slots) do
            if slot.widget == id then
                return slot
            end
        end
    end

    local function tap_at(x, y)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", x, y)))
    end

    local function centre(rect)
        return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
    end

    local function copy(t)
        if type(t) ~= "table" then
            return t
        end
        local out = {}
        for k, v in pairs(t) do
            out[k] = copy(v)
        end
        return out
    end

    before_each(function()
        harness.load()
        Home = require("home")
        Widgets = package.loaded["widgets"]
        Looks = package.loaded["looks"]
        Schema = package.loaded["schema"]
        builds, widths, contexts, taps = {}, {}, {}, 0
        stubs = {
            date = stub("date", 60),
            clock = stub("clock", 50),
            quote = stub("quote", 120, function()
                taps = taps + 1
            end),
            weather = stub("weather", 20),
            stats = stub("stats", 20),
        }
        Widgets.get = function(id)
            return stubs[id]
        end
        warned = spy.on(logger, "warn")
        errored = spy.on(logger, "err")
    end)

    after_each(function()
        logger.warn:revert()
        logger.err:revert()
        harness.teardown()
    end)

    it("builds one slot per entry of the default layout at its column width", function()
        local _, home = show_home()
        -- Diner on the harness's 600 px screen at scale 1: the band's padding and the side
        -- margin are both 40, so each row is 520 wide; two columns share it less a 14 px gap.
        assert.equals(1, Screen:scaleBySize(1))
        assert.equals(600, Screen:getWidth())
        assert.same({ date = 253, clock = 253, quote = 520, weather = 253, stats = 253 }, widths)
        assert.same({ date = 1, clock = 1, quote = 1, weather = 1, stats = 1 }, builds)
        assert.equals(5, #home.slots)
    end)

    it("passes each build the look, variant, text size, time, screen and home", function()
        local before = os.time()
        local _, home = show_home()
        local ctx = contexts.date
        assert.equals(Looks.active(), ctx.look)
        assert.equals(Looks.variant(), ctx.variant)
        assert.equals("medium", ctx.text_size)
        assert.is_true(ctx.now >= before and ctx.now <= os.time())
        assert.equals(Screen, ctx.screen)
        assert.equals(home, ctx.home)
    end)

    it("leaves the schema default layout unchanged", function()
        local entry
        for _, e in ipairs(Schema.keys) do
            if e.id == "layout.rows" then
                entry = e
            end
        end
        local before = copy(entry.default)
        show_home()
        assert.same(before, entry.default)
    end)

    it("leaves a blank slot of its column width, logged, for a widget with no module", function()
        stubs.quote = nil
        local _, home = show_home()
        local slot = slot_of(home, "quote")
        assert.is_not_nil(slot)
        assert.equals(520, slot.built:getSize().w)
        assert.is_nil(slot.built.stub)
        assert.is_true(logged("quote"))
        assert.same({ date = 1, clock = 1, weather = 1, stats = 1 }, builds)
    end)

    it("leaves a blank slot, logged, for a widget whose height raises", function()
        stubs.clock.height = function()
            error("kopanda-test: height failed")
        end
        local _, home = show_home()
        assert.is_nil(builds.clock)
        assert.equals(253, slot_of(home, "clock").built:getSize().w)
        assert.is_true(logged("kopanda-test: height failed"))
        assert.equals(1, builds.date)
        assert.equals(1, builds.quote)
    end)

    it("leaves a blank slot, logged, for a widget whose build raises", function()
        stubs.weather.build = function()
            error("kopanda-test: build failed")
        end
        local _, home = show_home()
        assert.equals(home, harness.top())
        assert.equals(253, slot_of(home, "weather").built:getSize().w)
        assert.is_true(logged("kopanda-test: build failed"))
        assert.equals(1, builds.stats)
    end)

    it("runs a slot's tap once on a tap inside it, and stays up", function()
        local _, home = show_home()
        tap_at(centre(slot_of(home, "quote").rect))
        assert.equals(1, taps)
        assert.equals(home, Home.shown)
        assert.equals(home, harness.top())
    end)

    it("closes on a tap in a slot whose widget has no tap", function()
        local fm, home = show_home()
        local rect = slot_of(home, "stats").rect
        tap_at(centre(rect))
        assert.equals(0, taps)
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    it("rebuilds and repaints on Resume and TimeFormatChanged, leaving the broadcast to others", function()
        local _, home = show_home()
        -- Recorded by hand: a luassert spy deep-copies its arguments, so identity is lost.
        local set_dirty = UIManager.setDirty
        local repainted = false
        UIManager.setDirty = function(self, widget, refresh, ...)
            repainted = repainted or (widget == home and refresh == "ui")
            return set_dirty(self, widget, refresh, ...)
        end
        finally(function()
            UIManager.setDirty = set_dirty
        end)
        UIManager:broadcastEvent(Event:new("Resume"))
        assert.equals(2, builds.date)
        assert.is_true(repainted)
        UIManager:broadcastEvent(Event:new("TimeFormatChanged"))
        assert.equals(3, builds.quote)
        assert.is_falsy((home:handleEvent(Event:new("Resume"))))
        assert.is_falsy((home:handleEvent(Event:new("TimeFormatChanged"))))
        assert.equals(home, harness.top())
    end)

    it("rebuilds on refresh", function()
        local _, home = show_home()
        home:refresh()
        assert.equals(2, builds.stats)
    end)

    it("leaves no KoPanda task in the task queue after show, settle and resume", function()
        show_home()
        harness.tick(3)
        UIManager:broadcastEvent(Event:new("Resume"))
        harness.tick(3)
        for _, task in ipairs(UIManager._task_queue) do
            local source = debug.getinfo(task.action, "S").source
            assert.is_falsy(source:find("kopanda.koplugin", 1, true), source)
        end
    end)
end)
