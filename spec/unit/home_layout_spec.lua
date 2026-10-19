-- The home built from layout.rows (C4, the engine part): one slot per entry at its column width,
-- blank slots for a missing or failing widget, taps routed to a slot's widget, rebuilds on
-- Resume and TimeFormatChanged and on a network change a widget's stale reports, and nothing
-- left in UIManager's task queue. The widgets are stubs registered for the spec.
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
            featured = stub("featured", 100),
            launcher = stub("launcher", 80),
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
        assert.same({ date = 253, clock = 253, featured = 520, quote = 520, launcher = 520, weather = 253,
            stats = 253 }, widths)
        assert.same({ date = 1, clock = 1, featured = 1, quote = 1, launcher = 1, weather = 1, stats = 1 }, builds)
        assert.equals(7, #home.slots)
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

    -- The header row aligns its slots to the bottom (Main.dc.html:19, HomeRetro.dc.html:19
    -- align-items: flex-end), the clock's baseline level with the date's last line.
    it("sets the date's last line and the clock on one baseline at the header's bottom, other rows at their top",
            function()
        local Blitbuffer = require("ffi/blitbuffer")
        local Settings = package.loaded["settings"]
        stubs.date = require("widgets/date")
        stubs.clock = require("widgets/clock")
        stubs.stats = stub("stats", 30)
        -- Typeset paints a line's glyphs through Typeset.paint_glyphs (typeset.lua).
        local Typeset = package.loaded["typeset"]
        local paint = Typeset.paint_glyphs
        local painted
        Typeset.paint_glyphs = function(self, bb, x, y, color)
            painted[#painted + 1] = { x = x, baseline = y + (self.forced_baseline or self:getBaseline()) }
            return paint(self, bb, x, y, color)
        end
        finally(function()
            Typeset.paint_glyphs = paint
        end)
        local bb = Blitbuffer.new(Screen:getWidth(), Screen:getHeight(), Blitbuffer.TYPE_BBRGB32)
        for _, case in ipairs({ { "editorial", "small" }, { "editorial", "large" }, { "diner", "small" },
                { "diner", "medium" }, { "diner", "large" } }) do
            local id = case[1] .. " " .. case[2]
            Settings.set("look", case[1])
            Settings.set("text_size", case[2])
            local home = Home:new{}
            local rows = home[1]
            local function place(id_)
                local slot = slot_of(home, id_)
                for i, widget in ipairs(rows) do
                    if widget == slot.built then
                        return rows.places[i], slot
                    end
                end
            end
            painted = {}
            rows:paintTo(bb, 0, 0)
            -- The baselines painted in a slot's box, lowest last; the other slots are stubs that
            -- paint no text, and the nav bar's labels lie below every slot.
            local function baselines(id_)
                local rect = slot_of(home, id_).rect
                local found = {}
                for _, p in ipairs(painted) do
                    if p.x >= rect.x and p.x < rect.x + rect.w and p.baseline >= rect.y
                            and p.baseline <= rect.y + rect.h then
                        found[#found + 1] = p.baseline
                    end
                end
                table.sort(found)
                return found
            end
            local date, clock = baselines("date"), baselines("clock")
            assert.truthy(#date > 0 and #clock > 0, id)
            assert.equals(clock[1], clock[#clock], id .. " clock glyphs on one baseline")
            assert.equals(date[#date], clock[1], id .. " date's last line and clock")
            -- The lower of the two sits on the header row's bottom.
            local bottom = 0
            for _, id_ in ipairs({ "date", "clock" }) do
                local at, slot = place(id_)
                bottom = math.max(bottom, at.y + slot.built:getSize().h)
            end
            local header = slot_of(home, "date").rect
            assert.equals(header.y + header.h, bottom, id)
            -- Row 3's shorter weather stays at its row's top.
            for _, id_ in ipairs({ "weather", "stats" }) do
                local at, slot = place(id_)
                assert.equals(slot.rect.y, at.y, id .. " " .. id_)
            end
            home:free()
        end
        bb:free()
    end)

    it("grows the header row to hold its slots on one baseline, and sets a slot with no baseline on its bottom",
            function()
        -- The date drops 20 below its baseline at 40, the clock 5 below its baseline at 45: the
        -- row's baseline lies 45 down, 20 above its bottom.
        stubs.date.baseline = function()
            return 40
        end
        stubs.clock.baseline = function()
            return 45
        end
        local home = Home:new{}
        local function top(id)
            local slot = slot_of(home, id)
            for i, widget in ipairs(home[1]) do
                if widget == slot.built then
                    return home[1].places[i].y - slot.rect.y, slot.rect.h
                end
            end
        end
        local date_top, row_h = top("date")
        assert.equals(65, row_h)
        assert.equals(5, date_top)
        assert.equals(0, (top("clock")))
        home:free()
        stubs.clock.baseline = nil
        home = Home:new{}
        date_top, row_h = top("date")
        assert.equals(60, row_h)
        assert.equals(0, date_top)
        assert.equals(10, (top("clock")))
        home:free()
    end)

    it("leaves a blank slot of its column width, logged, for a widget with no module", function()
        stubs.quote = nil
        local _, home = show_home()
        local slot = slot_of(home, "quote")
        assert.is_not_nil(slot)
        assert.equals(520, slot.built:getSize().w)
        assert.is_nil(slot.built.stub)
        assert.is_true(logged("quote"))
        assert.same({ date = 1, clock = 1, featured = 1, launcher = 1, weather = 1, stats = 1 }, builds)
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

    it("passes a slot's tap the home's ctx, the gesture and the slot's built widget", function()
        local got
        stubs.quote.tap = function(...)
            got = { ... }
        end
        local _, home = show_home()
        local slot = slot_of(home, "quote")
        local x, y = centre(slot.rect)
        tap_at(x, y)
        assert.equals(home.ctx, got[1])
        assert.same({ x, y }, { got[2].pos.x, got[2].pos.y })
        assert.equals(slot.built, got[3])
    end)

    it("falls through to closing the home when a slot's tap returns false", function()
        stubs.quote.tap = function()
            taps = taps + 1
            return false
        end
        local fm, home = show_home()
        tap_at(centre(slot_of(home, "quote").rect))
        assert.equals(1, taps)
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    it("calls each slot's after_show once, with the ctx and its built widget, after the settled signal", function()
        local got = {}
        stubs.quote.after_show = function(ctx, built)
            got[#got + 1] = { ctx = ctx, built = built, settled = Home.shown and Home.shown.settled }
        end
        local _, home = show_home()
        harness.tick(3)
        assert.equals(1, #got)
        assert.equals(home.ctx, got[1].ctx)
        assert.equals(slot_of(home, "quote").built, got[1].built)
        assert.is_true(got[1].settled)
    end)

    it("logs a raising after_show and keeps the home up", function()
        stubs.quote.after_show = function()
            error("kopanda-test: after_show failed")
        end
        local _, home = show_home()
        harness.tick(3)
        assert.is_true(logged("kopanda-test: after_show failed"))
        assert.equals(home, Home.shown)
    end)

    it("drops the featured cover's check when the home closes", function()
        local FeaturedCover = package.loaded["featured_cover"]
        local cancel = FeaturedCover.cancel
        local cancels = 0
        FeaturedCover.cancel = function()
            cancels = cancels + 1
        end
        finally(function()
            FeaturedCover.cancel = cancel
        end)
        show_home()
        Home.close()
        assert.equals(1, cancels)
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

    -- A network change asks each slot's stale (widgets.lua) and rebuilds the home once when any
    -- says its widget is out of date; NetworkConnected after the weather's own handler.
    describe("on a network change", function()
        local Weather, on_connected, order

        before_each(function()
            Weather = package.loaded["weather"]
            on_connected = Weather.on_connected
            order = {}
            Weather.on_connected = function()
                order[#order + 1] = "weather"
            end
        end)

        after_each(function()
            Weather.on_connected = on_connected
        end)

        -- stale for a stub that records its call and answers with answer (a function raises).
        local function stale_answering(answer)
            return function(built, ctx)
                order[#order + 1] = { built = built, ctx = ctx }
                if type(answer) == "function" then
                    return answer()
                end
                return answer
            end
        end

        for _, name in ipairs({ "NetworkConnected", "NetworkDisconnected" }) do
            it("rebuilds a shown home once on " .. name .. " when slots' stale say so, leaving it to others",
                    function()
                stubs.quote.stale = stale_answering(true)
                stubs.launcher.stale = stale_answering(true)
                local _, home = show_home()
                assert.equals(1, builds.date)
                assert.is_falsy((home:handleEvent(Event:new(name))))
                assert.equals(2, builds.date)
                local quote, launcher = slot_of(home, "quote"), slot_of(home, "launcher")
                assert.is_true(builds.quote == 2 and builds.launcher == 2)
                assert.equals(home, Home.shown)
                UIManager:broadcastEvent(Event:new(name))
                assert.equals(3, builds.date)
                assert.equals(home, harness.top())
                -- The first check had the built widgets and the ctx of the build before it.
                local checks = {}
                for _, call in ipairs(order) do
                    if type(call) == "table" then
                        checks[#checks + 1] = call
                    end
                end
                assert.is_true(#checks >= 1)
                assert.is_true(checks[1].built ~= quote.built and checks[1].built ~= launcher.built)
                assert.is_table(checks[1].ctx.look)
            end)

            it("doesn't rebuild on " .. name .. " when every stale is false", function()
                stubs.quote.stale = stale_answering(false)
                stubs.launcher.stale = stale_answering(false)
                local _, home = show_home()
                assert.is_falsy((home:handleEvent(Event:new(name))))
                assert.equals(1, builds.date)
                assert.equals(2, #order - (name == "NetworkConnected" and 1 or 0))
            end)

            it("logs a raising stale on " .. name .. ", counts it not stale and keeps the home up", function()
                stubs.quote.stale = stale_answering(function()
                    error("kopanda-test: stale failed")
                end)
                local _, home = show_home()
                assert.is_falsy((home:handleEvent(Event:new(name))))
                assert.equals(1, builds.date)
                assert.is_true(logged("kopanda-test: stale failed"))
                assert.equals(home, Home.shown)
                assert.equals(home, harness.top())
            end)
        end

        it("asks stale on NetworkConnected after the weather's handler", function()
            stubs.launcher.stale = stale_answering(false)
            local _, home = show_home()
            home:handleEvent(Event:new("NetworkConnected"))
            assert.equals("weather", order[1])
            assert.is_table(order[2])
            assert.equals(slot_of(home, "launcher").built, order[2].built)
            assert.equals(home.ctx, order[2].ctx)
        end)

        it("does nothing on a network change once the home has closed", function()
            stubs.launcher.stale = stale_answering(true)
            local _, home = show_home()
            Home.close()
            home:handleEvent(Event:new("NetworkDisconnected"))
            assert.equals(1, builds.date)
        end)
    end)

    it("rebuilds on refresh", function()
        local _, home = show_home()
        home:refresh()
        assert.equals(2, builds.stats)
    end)

    it("neither rebuilds nor repaints on refresh once closed", function()
        -- A tap's fetch runs once online, which may be after the home has closed.
        local _, home = show_home()
        Home.close()
        assert.is_nil(Home.shown)
        -- Recorded by hand: a luassert spy deep-copies its arguments, so identity is lost.
        local set_dirty = UIManager.setDirty
        local repainted = false
        UIManager.setDirty = function(self, widget, ...)
            repainted = repainted or widget == home
            return set_dirty(self, widget, ...)
        end
        finally(function()
            UIManager.setDirty = set_dirty
        end)
        local built = builds.stats
        home:refresh()
        assert.equals(built, builds.stats)
        assert.is_false(repainted)
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

    it("leaves no KoPanda task in the task queue after a weather fetch and its refresh", function()
        -- Replaced by hand: this file's stub() makes widget modules.
        local NetworkMgr = require("ui/network/manager")
        local Weather = package.loaded["weather"]
        local is_connected, fetch = NetworkMgr.isConnected, Weather.fetch
        local fetches = 0
        NetworkMgr.isConnected = function()
            return true
        end
        Weather.fetch = function()
            fetches = fetches + 1
            return true
        end
        finally(function()
            NetworkMgr.isConnected = is_connected
            Weather.fetch = fetch
        end)
        show_home()
        harness.tick(3)
        assert.equals(1, fetches)
        assert.equals(2, builds.date)
        for _, task in ipairs(UIManager._task_queue) do
            local source = debug.getinfo(task.action, "S").source
            assert.is_falsy(source:find("kopanda.koplugin", 1, true), source)
        end
    end)

    -- The nav bar (the nav bar's C3): built with Home active in the band under the rows, the rows'
    -- last child so it paints over them, and left out, logged, when its build raises.
    describe("the nav bar", function()
        local Blitbuffer = require("ffi/blitbuffer")
        local RED = Blitbuffer.ColorRGB32(255, 0, 0, 255)

        local function rgb(color)
            local c = color:getColorRGB32()
            return { c:getR(), c:getG(), c:getB() }
        end

        -- The weather's widget paints red from its top to the screen's bottom, over the band.
        local function overreaching_weather()
            local Overreach = Widget:extend{}
            function Overreach:paintTo(bb, x, y)
                bb:paintRectRGB32(x, y, self.dimen.w, Screen:getHeight() - y, RED)
            end
            stubs.weather.build = function(width)
                return Overreach:new{ dimen = Geom:new{ w = width, h = 20 } }
            end
        end

        -- The home painted into an RGB32 buffer of the screen's size, and the colour at (x, y).
        local function painted_at(home, x, y)
            local bb = Blitbuffer.new(Screen:getWidth(), Screen:getHeight(), Blitbuffer.TYPE_BBRGB32)
            home:paintTo(bb, 0, 0)
            local got = rgb(bb:getPixel(x, y))
            bb:free()
            return got
        end

        it("is drawn with Home active in the band under the rows, painted over them", function()
            overreaching_weather()
            local _, home = show_home()
            local look = Looks.active()
            local bar = home.nav
            assert.equals("kopanda_nav_bar", bar.name)
            assert.equals("home", bar.where)
            assert.equals(1, bar.active)
            local h = package.loaded["nav_bar"].height(look, Screen)
            assert.same({ 0, Screen:getHeight() - h, Screen:getWidth(), h },
                { bar.dimen.x, bar.dimen.y, bar.dimen.w, bar.dimen.h })
            local rows = home[1]
            assert.equals(bar, rows[#rows])
            assert.same({ x = 0, y = bar.dimen.y }, rows.places[#rows])
            for _, slot in ipairs(home.slots) do
                assert.truthy(slot.rect.y + slot.rect.h <= bar.dimen.y, slot.widget)
            end
            -- Column 2 under the edge, above its icon, and under the weather's red.
            local x = bar.padding_x + bar.columns[2].x + 2
            local y = bar.dimen.y + Screen:scaleBySize(look.nav.edge_width) + 1
            local weather = slot_of(home, "weather").rect
            assert.truthy(x >= weather.x and x < weather.x + weather.w)
            local fill = Looks.color(Looks.palette(look, home.ctx.variant)[look.nav.fill_color])
            assert.same(rgb(fill), painted_at(home, x, y))
        end)

        it("leaves the band paper, logged, and the slots built when its build raises", function()
            package.loaded["nav_bar"].new = function()
                error("kopanda-test: bar failed")
            end
            local _, home = show_home()
            assert.equals(home, harness.top())
            assert.is_nil(home.nav)
            assert.is_true(logged("kopanda-test: bar failed"))
            assert.same({ date = 1, clock = 1, featured = 1, quote = 1, launcher = 1, weather = 1, stats = 1 }, builds)
            local look = Looks.active()
            local paper = Looks.color(Looks.palette(look, home.ctx.variant).paper)
            local h = package.loaded["nav_bar"].height(look, Screen)
            assert.same(rgb(paper), painted_at(home, Screen:getWidth() - 3, Screen:getHeight() - math.floor(h / 2)))
        end)
    end)
end)
