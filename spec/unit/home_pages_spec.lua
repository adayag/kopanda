-- The home's two pages: page 1 built from layout.rows, page 2 from layout.rows_2, turned by a
-- west or east swipe mid-screen, kept through a refresh and a Resume, and back to page 1 for a new
-- home. The widgets are stubs registered for the spec.
describe("the home's pages", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    local Widget = require("ui/widget/widget")
    local Geom = require("ui/geometry")
    local Screen = require("device").screen
    local logger = require("logger")
    local Home, Widgets, stubs, builds, errored

    -- A stub widget module: height h at any width, a build that counts.
    local function stub(id, h)
        return {
            id = id,
            settings_prefix = id,
            height = function()
                return h
            end,
            build = function(width)
                builds[id] = (builds[id] or 0) + 1
                return Widget:new{ name = "kopanda_spec_stub", stub = id, dimen = Geom:new{ w = width, h = h } }
            end,
        }
    end

    -- Records whether UIManager:setDirty is called with the widget and "ui". Recorded by hand: a luassert
    -- spy deep-copies its arguments, so identity is lost.
    local function record_repaint(widget)
        local set_dirty = UIManager.setDirty
        local record = { repainted = false }
        UIManager.setDirty = function(self, w, refresh, ...)
            record.repainted = record.repainted or (w == widget and refresh == "ui")
            return set_dirty(self, w, refresh, ...)
        end
        finally(function()
            UIManager.setDirty = set_dirty
        end)
        return record
    end

    local function logged(text)
        for _, call in ipairs(errored.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    return true
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

    local function slot_of(home, id)
        for _, slot in ipairs(home.slots) do
            if slot.widget == id then
                return slot
            end
        end
    end

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    local function swipe(x, y, direction)
        local ges = harness.gesture("swipe", x, y)
        ges.direction = direction
        ges.distance = Screen:scaleBySize(300)
        return ges
    end

    -- A west or east swipe mid-screen.
    local function turn(direction)
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h / 2, direction))
        harness.tick()
    end

    before_each(function()
        harness.load()
        Home = require("home")
        Widgets = package.loaded["widgets"]
        builds = {}
        stubs = {}
        for id, h in pairs({ date = 60, clock = 50, quote = 120, weather = 20, stats = 20, featured = 100,
            launcher = 80, heatmap = 100, calendar = 120, forecast = 110, hours = 80, records = 90 }) do
            stubs[id] = stub(id, h)
        end
        Widgets.get = function(id)
            return stubs[id]
        end
        errored = spy.on(logger, "err")
    end)

    after_each(function()
        logger.err:revert()
        harness.teardown()
    end)

    it("starts on page 1 and builds page 2's rows on a west swipe mid-screen, repainting", function()
        local _, home = show_home()
        assert.equals(1, home.page)
        assert.truthy(slot_of(home, "launcher"))
        assert.is_nil(slot_of(home, "heatmap"))
        local record = record_repaint(home)
        local old = home[1]
        local free, freed = old.free, 0
        old.free = function(...)
            freed = freed + 1
            return free(...)
        end
        turn("west")
        assert.equals(2, home.page)
        assert.is_true(record.repainted)
        assert.equals(1, freed)
        assert.are_not.equal(old, home[1])
        assert.equals(home, harness.top())
        assert.truthy(slot_of(home, "heatmap"))
        assert.is_nil(slot_of(home, "launcher"))
        assert.same({ date = 2, clock = 2, quote = 1, weather = 1, stats = 1, featured = 1, launcher = 1,
            heatmap = 1, calendar = 1, forecast = 1, hours = 1, records = 1 }, builds)
    end)

    it("returns to page 1 on an east swipe mid-screen", function()
        local _, home = show_home()
        turn("west")
        turn("east")
        assert.equals(1, home.page)
        assert.truthy(slot_of(home, "launcher"))
        assert.is_nil(slot_of(home, "heatmap"))
        assert.equals(2, builds.launcher)
        assert.equals(1, builds.heatmap)
        assert.equals(home, harness.top())
    end)

    it("stays at either end, rebuilding and repainting nothing", function()
        local _, home = show_home()
        local record = record_repaint(home)
        turn("east")
        assert.equals(1, home.page)
        assert.same({ date = 1, clock = 1, quote = 1, weather = 1, stats = 1, featured = 1, launcher = 1 }, builds)
        assert.is_false(record.repainted)
        turn("west")
        record.repainted = false
        turn("west")
        assert.equals(2, home.page)
        assert.is_false(record.repainted)
        assert.equals(1, builds.heatmap)
        assert.equals(2, builds.date)
        assert.equals(home, harness.top())
    end)

    it("keeps the page through a refresh and a Resume", function()
        local _, home = show_home()
        turn("west")
        home:refresh()
        assert.equals(2, home.page)
        assert.equals(2, builds.heatmap)
        UIManager:broadcastEvent(Event:new("Resume"))
        assert.equals(2, home.page)
        assert.equals(3, builds.heatmap)
        assert.equals(1, builds.launcher)
    end)

    it("starts a new home on page 1", function()
        local _, home = show_home()
        turn("west")
        Home.close()
        harness.tick()
        Home.show({})
        harness.tick(2)
        local again = Home.shown
        assert.is_not_nil(again)
        assert.are_not.equal(home, again)
        assert.equals(1, again.page)
        assert.truthy(slot_of(again, "launcher"))
        assert.is_nil(slot_of(again, "heatmap"))
    end)

    it("leaves a blank slot, logged, for a page-2 widget whose build raises", function()
        stubs.calendar.build = function()
            error("kopanda-test: build failed")
        end
        local _, home = show_home()
        turn("west")
        assert.equals(2, home.page)
        assert.equals(home, harness.top())
        local slot = slot_of(home, "calendar")
        assert.is_not_nil(slot)
        assert.is_nil(slot.built.stub)
        assert.is_true(logged("kopanda-test: build failed"))
        assert.equals(1, builds.forecast)
    end)

    it("closes the home, logged, when page 2 fails to build", function()
        local fm, home = show_home()
        package.loaded["home_rows"].build = function()
            error("kopanda-test: rows failed")
        end
        turn("west")
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
        assert.are_not.equal(home, harness.top())
        assert.is_true(logged("could not turn"))
        assert.is_true(logged("kopanda-test: rows failed"))
    end)

    it("doesn't turn on a west swipe in the top or bottom edge band", function()
        local _, home = show_home()
        local size = Screen:getSize()
        for _, name in ipairs({ "DSWIPE_ZONE_TOP_EDGE", "DSWIPE_ZONE_BOTTOM_EDGE" }) do
            local zone = G_defaults:readSetting(name)
            send(swipe(size.w / 2, (zone.y + zone.h / 2) * size.h, "west"))
            harness.tick()
            assert.equals(1, home.page, name)
        end
        assert.is_nil(builds.heatmap)
        assert.equals(1, builds.launcher)
        assert.equals(home, harness.top())
    end)

    it("doesn't turn under KOReader's touch lock", function()
        local InputContainer = require("ui/widget/container/inputcontainer")
        local _, home = show_home()
        InputContainer:setIgnoreTouchInput(true)
        finally(function()
            InputContainer:setIgnoreTouchInput(false)
        end)
        turn("west")
        assert.equals(1, home.page)
        assert.is_nil(builds.heatmap)
        assert.equals(home, harness.top())
    end)

    it("turns by the mirrored direction in a mirrored layout", function()
        local BD = require("ui/bidi")
        local _, home = show_home()
        local mirrored = BD._mirrored_ui_layout
        BD._mirrored_ui_layout = true
        finally(function()
            BD._mirrored_ui_layout = mirrored
        end)
        turn("west")
        assert.equals(1, home.page)
        assert.is_nil(builds.heatmap)
        turn("east")
        assert.equals(2, home.page)
        assert.equals(1, builds.heatmap)
        assert.equals(home, harness.top())
    end)
end)
