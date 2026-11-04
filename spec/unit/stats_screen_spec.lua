-- The Stats window: rows of insight tiles flowed onto pages by fit, each page named by its first row; the tiles at the
-- stored text size, the chrome at the shell's; turned by swipes, read again at each build and on wake; read-only; a
-- tile that fails leaving a blank slot. Most cases use stub tiles of chosen heights; those that guard the real gaps use
-- the real widgets on a populated ReadingStats.insights.
describe("the Stats window", function()
    local harness = require("plugin_harness")
    local fixture = require("library_fixture")
    local text_of = fixture.text
    local Blitbuffer = require("ffi/blitbuffer")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local Widget = require("ui/widget/widget")
    local logger = require("logger")
    local Home, LibraryChrome, LibraryTiles, Looks, Paint, Settings, Sheet, StatsScreen, Widgets
    local real_get, stubs, seen, errored

    -- Each stub's height when none is chosen: all five fit a page of any test screen.
    local HEIGHTS = { reading = 40, streak = 30, forecast = 30, hours = 20, records = 20, months = 20 }

    -- A stub tile: its height comes from heights[id], its calls land in seen.
    local function stub(id, heights)
        return {
            id = id,
            settings_prefix = "stats",
            height = function(width, ctx)
                seen.measured[#seen.measured + 1] = { id = id, width = width, ctx = ctx }
                return heights[id]
            end,
            build = function(width, ctx)
                seen.built[#seen.built + 1] = { id = id, width = width, ctx = ctx }
                local dimen = Geom:new{ w = width, h = heights[id] }
                return Widget:new{ name = "kopanda_spec_tile", stub = id, dimen = dimen }
            end,
        }
    end

    -- Registers stub tiles of heights over HEIGHTS, returning the table a case may change.
    local function use_stubs(heights)
        local all = {}
        for id, h in pairs(HEIGHTS) do
            all[id] = heights and heights[id] or h
        end
        stubs = {}
        for id in pairs(all) do
            stubs[id] = stub(id, all)
        end
        Widgets.get = function(id)
            return stubs[id]
        end
        return all
    end

    -- The real tiles, recording what the window builds in seen.built, not the home's.
    local function use_real_tiles()
        Widgets.get = function(id)
            local widget = real_get(id)
            return {
                height = widget.height,
                build = function(width, ctx)
                    if HEIGHTS[id] then
                        seen.built[#seen.built + 1] = { id = id, width = width, ctx = ctx }
                    end
                    return widget.build(width, ctx)
                end,
            }
        end
    end

    -- A year of reading, a book under way, a session history.
    local function populate()
        local days, hours = {}, {}
        for i = 1, 371 do
            days[i] = 1800 + (i % 7) * 300
        end
        for h = 1, 24 do
            hours[h] = h * 100
        end
        local insights = { state = "ok", days = days, hours = hours,
            sessions = { count = 480, longest = 7200, average = 1800, pages_per_hour = 42 } }
        package.loaded["reading_stats"].insights = function()
            return insights
        end
        package.loaded["featured_book"].current = function()
            return { file = "/books/b.epub", title = "The Moonstone", percent = 0.62, status = "reading",
                seconds_left = 18000 }
        end
    end

    before_each(function()
        harness.load()
        Home = package.loaded["home"]
        LibraryChrome = package.loaded["library_chrome"]
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
        Paint = package.loaded["paint"]
        Settings = package.loaded["settings"]
        Sheet = package.loaded["sheet"]
        StatsScreen = package.loaded["stats_screen"]
        Widgets = package.loaded["widgets"]
        real_get = Widgets.get
        seen = { measured = {}, built = {} }
        errored = spy.on(logger, "err")
    end)

    after_each(function()
        logger.err:revert()
        harness.teardown()
    end)

    local function logged(...)
        local wanted = { ... }
        for _, call in ipairs(errored.calls) do
            local text = {}
            for i, arg in ipairs(call.vals) do
                text[i] = tostring(arg)
            end
            text = table.concat(text, " ")
            local all = true
            for _, piece in ipairs(wanted) do
                all = all and text:find(piece, 1, true) ~= nil
            end
            if all then
                return true
            end
        end
        return false
    end

    -- Records whether UIManager:setDirty is called with the widget, by hand: a luassert spy deep-copies its arguments.
    local function record_repaint(widget)
        local set_dirty = UIManager.setDirty
        local record = { repainted = false }
        UIManager.setDirty = function(self, w, ...)
            record.repainted = record.repainted or w == widget
            return set_dirty(self, w, ...)
        end
        finally(function()
            UIManager.setDirty = set_dirty
        end)
        return record
    end

    -- The Stats window, opened on the plugin from the home.
    local function show()
        local fm = harness.show_fm()
        harness.tick(2)
        fm.kopanda:showStats{}
        harness.tick(2)
        return LibraryChrome.shown
    end

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    local function swipe(direction)
        local ges = harness.gesture("swipe", math.floor(Screen:getWidth() / 2), math.floor(Screen:getHeight() / 2))
        ges.direction = direction
        send(ges)
    end

    local function page_name(screen)
        return text_of(screen.header.aside):lower()
    end

    -- The stub tiles the window's frame holds, in the frame's order: { id, x, y, w }.
    local function drawn(screen)
        local frame, list = screen[1], {}
        for i, child in ipairs(frame) do
            if child.stub then
                list[#list + 1] = { id = child.stub, x = frame.places[i].x, y = frame.places[i].y, w = child.dimen.w }
            end
        end
        return list
    end

    local function ids(screen)
        local list = {}
        for i, tile in ipairs(drawn(screen)) do
            list[i] = tile.id
        end
        return list
    end

    -- The room for rows and the row gap on the shown window.
    local function room_of(screen)
        local ctx = screen.ctx
        local h = LibraryTiles.header_height(ctx)
        return LibraryTiles.room(screen.dimen.h, ctx, h), Screen:scaleBySize(ctx.look.home.row_gap)
    end

    describe("opening", function()
        it("closes the home and shows a stats window at page 1", function()
            use_stubs()
            local screen = show()
            assert.is_nil(Home.shown)
            assert.equals("stats", screen.screen)
            assert.equals(StatsScreen.shown, screen)
            assert.equals(screen, harness.top())
            assert.equals(1, screen.page)
            assert.equals("stats", text_of(screen.header.title):lower())
        end)

        it("leaves the file manager on top, logged, when the window fails to show", function()
            local fm = harness.show_fm()
            harness.tick(2)
            local header = LibraryChrome.header
            LibraryChrome.header = function()
                error("kopanda-test: header")
            end
            finally(function()
                LibraryChrome.header = header
            end)
            package.loaded["nav_bar"].run("stats", "home")
            harness.tick(2)
            assert.is_nil(StatsScreen.shown)
            assert.is_nil(Home.shown)
            assert.equals(fm, harness.top())
            assert.is_true(logged("could not show the stats"))
        end)
    end)

    describe("the flow", function()
        it("draws the rows in order, a two-tile row's tiles side by side with the column gap between", function()
            use_stubs()
            local screen = show()
            local look = screen.ctx.look
            local tiles = drawn(screen)
            assert.same({ "reading", "streak", "forecast", "hours", "records" }, ids(screen))
            local left, right = tiles[2], tiles[3]
            assert.equals(left.y, right.y)
            assert.equals(left.w, right.w)
            assert.equals(left.x + left.w + Screen:scaleBySize(look.home.column_gap), right.x)
            local x = Screen:scaleBySize(look.shelf.list.side)
            assert.equals(x, tiles[1].x)
            assert.equals(screen.dimen.w - 2 * x, tiles[1].w)
            assert.equals(math.floor((tiles[1].w - Screen:scaleBySize(look.home.column_gap)) / 2), left.w)
            local gap = Screen:scaleBySize(look.home.row_gap)
            assert.equals(tiles[1].y + HEIGHTS.reading + gap, left.y)
            assert.equals(left.y + HEIGHTS.streak + gap, tiles[4].y)
        end)

        it("names a page by its first row", function()
            local heights = use_stubs()
            local screen = show()
            assert.equals("now", page_name(screen))
            local room = room_of(screen)
            heights.hours = room
            screen = show()
            assert.same({ "reading", "streak", "forecast" }, ids(screen))
            swipe("west")
            assert.equals("habits", page_name(screen))
            assert.same({ "hours", "records" }, ids(screen))
        end)

        it("starts the month row's own page however much room is left, named Over time", function()
            use_stubs{ reading = 1, streak = 1, forecast = 1, hours = 1, records = 1, months = 1 }
            local screen = show()
            assert.equals(2, screen.pages)
            swipe("west")
            assert.equals("over time", page_name(screen))
            assert.same({ "months" }, ids(screen))
        end)

        it("keeps a row ending exactly at the room on the page, and moves one a pixel taller", function()
            local heights = use_stubs()
            local screen = show()
            local room, gap = room_of(screen)
            heights.hours = room - HEIGHTS.reading - gap - HEIGHTS.streak - gap
            screen = show()
            assert.equals(2, screen.pages)
            assert.same({ "reading", "streak", "forecast", "hours", "records" }, ids(screen))

            heights.hours = heights.hours + 1
            screen = show()
            assert.equals(3, screen.pages)
            assert.same({ "reading", "streak", "forecast" }, ids(screen))
        end)

        it("sits a row taller than a page alone on its page, the rows around it still drawn", function()
            local heights = use_stubs()
            local screen = show()
            heights.streak = 3 * room_of(screen)
            screen = show()
            assert.equals(4, screen.pages)
            assert.same({ "reading" }, ids(screen))
            swipe("west")
            assert.same({ "streak", "forecast" }, ids(screen))
            swipe("west")
            assert.same({ "hours", "records" }, ids(screen))
            swipe("west")
            assert.same({ "months" }, ids(screen))
        end)

        it("sits a first row taller than a page alone on page 1, with no empty page before it", function()
            local heights = use_stubs()
            local screen = show()
            heights.reading = 3 * room_of(screen)
            screen = show()
            assert.equals(3, screen.pages)
            assert.equals("now", page_name(screen))
            assert.same({ "reading" }, ids(screen))
        end)

        it("counts each page's rows from its own top", function()
            local heights = use_stubs()
            local screen = show()
            heights.reading = room_of(screen)
            screen = show()
            assert.equals(3, screen.pages)
            assert.same({ "reading" }, ids(screen))
            swipe("west")
            assert.same({ "streak", "forecast", "hours", "records" }, ids(screen))
        end)

        it("gives a window at another text size its own flow", function()
            use_stubs()
            assert.equals(2, show().pages)
            assert.is_true(Settings.set("text_size", "extra_large"))
            local screen = show()
            assert.same({ "reading", "streak", "forecast", "hours", "records" }, ids(screen))
            assert.equals(screen.dimen.w - 2 * Screen:scaleBySize(screen.ctx.look.shelf.list.side), drawn(screen)[4].w)
        end)

        it("flows again on a rotation, the page kept in range", function()
            local tall = 500
            use_stubs{ reading = tall, streak = tall, forecast = tall, hours = tall, records = tall, months = tall }
            harness.at_colorsoft(function()
                local screen
                harness.at_screen(1680, 1264, function()
                    screen = show()
                    assert.equals(4, screen.pages)
                    screen:go(screen:view(), 4)
                    assert.equals(4, screen.page)
                end)
                screen:paintTo(Blitbuffer.new(1264, 1680, Blitbuffer.TYPE_BBRGB32), 0, 0)
                assert.equals(1264, screen.dimen.w)
                assert.equals(3, screen.pages)
                assert.equals(3, screen.page)
                assert.same({ "months" }, ids(screen))
            end)
        end)

        it("holds three rows on page 1 and the months on page 2 for each look at each size, at Medium", function()
            populate()
            use_real_tiles()
            for _, size in ipairs({ "at_colorsoft", "at_paperwhite" }) do
                harness[size](function()
                    for _, id in ipairs(Looks.ids()) do
                        assert.is_true(Settings.set("look", id))
                        seen.built = {}
                        local screen = show()
                        local where = id .. " " .. size
                        assert.equals(2, screen.pages, where)
                        assert.equals(5, #seen.built, where)
                        assert.equals("now", page_name(screen), where)
                        seen.built = {}
                        swipe("west")
                        assert.equals("over time", page_name(screen), where)
                        assert.equals("months", seen.built[1].id, where)
                        assert.equals(1, #seen.built, where)
                        assert.is_false(logged("failed to"), where)
                    end
                end)
            end
        end)
    end)

    describe("text size", function()
        it("runs hours and records full width at Extra large, side by side at Medium", function()
            use_stubs()
            local screen = show()
            local tiles = drawn(screen)
            assert.equals(tiles[4].y, tiles[5].y)
            assert.is_true(tiles[4].w < tiles[1].w)

            assert.is_true(Settings.set("text_size", "extra_large"))
            screen = show()
            tiles = drawn(screen)
            assert.same({ "reading", "streak", "forecast", "hours", "records" }, ids(screen))
            assert.equals(tiles[2].y, tiles[3].y)
            assert.is_true(tiles[2].w < tiles[1].w)
            assert.equals(tiles[1].w, tiles[4].w)
            assert.equals(tiles[1].w, tiles[5].w)
            assert.is_true(tiles[5].y > tiles[4].y)
        end)

        it("keeps streak and forecast side by side at Extra large, on Now above hours and records on Habits", function()
            populate()
            use_real_tiles()
            assert.is_true(Settings.set("text_size", "extra_large"))
            harness.at_colorsoft(function()
                local function built_ids()
                    local list = {}
                    for i, tile in ipairs(seen.built) do
                        list[i] = tile.id
                    end
                    seen.built = {}
                    return list
                end
                local screen = show()
                assert.equals(3, screen.pages)
                assert.equals("now", page_name(screen))
                assert.same({ "reading", "streak", "forecast" }, built_ids())
                swipe("west")
                assert.equals("habits", page_name(screen))
                assert.same({ "hours", "records" }, built_ids())
                swipe("west")
                assert.equals("over time", page_name(screen))
                assert.same({ "months" }, built_ids())
            end)
        end)

        it("gives the tiles the stored text size and a box, the chrome the shell's", function()
            use_stubs()
            assert.is_true(Settings.set("text_size", "large"))
            local screen = show()
            assert.equals("large", seen.built[1].ctx.text_size)
            assert.is_true(seen.built[1].ctx.boxed)
            assert.is_nil(screen.ctx.text_size)
            assert.is_nil(screen.nav.text_size)
        end)
    end)

    describe("turning", function()
        it("turns to the next page on a west swipe and back on an east one", function()
            use_stubs()
            local screen = show()
            swipe("west")
            assert.equals(2, screen.page)
            swipe("east")
            assert.equals(1, screen.page)
        end)

        it("rebuilds and repaints nothing on a west swipe on the last page", function()
            use_stubs()
            local screen = show()
            swipe("west")
            assert.equals(2, screen.page)
            local frame = screen[1]
            local record = record_repaint(screen)
            swipe("west")
            assert.equals(2, screen.page)
            assert.equals(frame, screen[1])
            assert.is_false(record.repainted)
        end)
    end)

    describe("freshness", function()
        local real_time = os.time

        after_each(function()
            os.time = real_time -- luacheck: ignore 122
        end)

        -- os.time() answers at; a time with a table goes through.
        local function clock_at(at)
            os.time = function(t) -- luacheck: ignore 122
                return t and real_time(t) or at
            end
        end

        it("reads the time at every build, so a turn gets the new now", function()
            use_stubs()
            local at = real_time()
            clock_at(at)
            local screen = show()
            assert.equals(at, seen.built[1].ctx.now)
            clock_at(at + 86400)
            swipe("west")
            assert.equals(at + 86400, seen.built[#seen.built].ctx.now)
            assert.equals(2, screen.page)
        end)

        it("rebuilds at the page shown on wake, with the new now, flowing again", function()
            use_stubs()
            local at = real_time()
            clock_at(at)
            local screen = show()
            swipe("west")
            seen.measured, seen.built = {}, {}
            clock_at(at + 86400)
            local record = record_repaint(screen)
            UIManager:broadcastEvent(Event:new("Resume"))
            assert.equals(screen, LibraryChrome.shown)
            assert.equals(2, screen.page)
            assert.same({ "months" }, ids(screen))
            assert.equals(6, #seen.measured)
            assert.equals(at + 86400, seen.measured[1].ctx.now)
            assert.equals(at + 86400, seen.built[1].ctx.now)
            assert.is_true(record.repainted)
        end)

        it("measures once across turns, while the screen and the text size hold", function()
            use_stubs()
            show()
            assert.equals(6, #seen.measured)
            swipe("west")
            swipe("east")
            assert.equals(6, #seen.measured)
        end)

        it("does not repaint for a book's metadata", function()
            use_stubs()
            local screen = show()
            local frame = screen[1]
            local record = record_repaint(screen)
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            harness.tick(2)
            assert.is_false(record.repainted)
            assert.equals(frame, screen[1])
        end)
    end)

    describe("night mode", function()
        it("rebuilds in the new variant at the next paint, keeping the flow", function()
            use_stubs()
            local screen = show()
            local kept, frame = screen.kept, screen[1]
            local variant = Looks.variant
            Looks.variant = function()
                return "night"
            end
            finally(function()
                Looks.variant = variant
            end)
            local bb = Blitbuffer.new(screen.dimen.w, screen.dimen.h, Blitbuffer.TYPE_BBRGB32)
            screen:paintTo(bb, 0, 0)
            bb:free()
            assert.are_not.equal(frame, screen[1])
            assert.equals(kept, screen.kept)
            assert.equals("night", screen.ctx.variant)
        end)
    end)

    describe("a failing tile", function()
        it("leaves a blank slot for one whose height raises, logged by id, and draws no such tile", function()
            use_stubs()
            stubs.streak.height = function()
                error("no streak")
            end
            local screen = show()
            assert.same({ "reading", "forecast", "hours", "records" }, ids(screen))
            assert.is_true(logged("streak", "failed to measure"))
            local tiles = drawn(screen)
            assert.equals(tiles[4].x, tiles[2].x)
            assert.is_true(tiles[2].x > tiles[1].x)
        end)

        it("leaves a blank slot for one whose build raises, logged by id", function()
            use_stubs()
            stubs.forecast.build = function()
                error("no forecast")
            end
            local screen = show()
            assert.same({ "reading", "streak", "hours", "records" }, ids(screen))
            assert.is_true(logged("forecast", "failed to build"))
            assert.equals(screen, LibraryChrome.shown)
        end)
    end)

    describe("read-only", function()
        it("runs nothing on a tap or a hold on a tile", function()
            use_stubs()
            local screen = show()
            local tile = drawn(screen)[1]
            local frame = screen[1]
            local record = record_repaint(screen)
            local x, y = tile.x + 10, tile.y + 10
            send(harness.gesture("tap", x, y))
            harness.tick(2)
            send(harness.gesture("hold", x, y))
            harness.tick(2)
            assert.is_nil(Sheet.shown)
            assert.equals(screen, LibraryChrome.shown)
            assert.equals(screen, harness.top())
            assert.equals(frame, screen[1])
            assert.is_false(record.repainted)
        end)
    end)

    it("draws the real tiles' box in Frosted, in the plate's keyline", function()
        populate()
        use_real_tiles()
        harness.at_colorsoft(function()
            assert.is_true(Settings.set("look", "frosted"))
            local screen = show()
            local ctx = seen.built[1].ctx
            local bb = Blitbuffer.new(1264, 1680, Blitbuffer.TYPE_BBRGB32)
            screen:paintTo(bb, 0, 0)
            local x = Paint.scaler(ctx)(ctx.look.shelf.list.side) + 100
            local top = LibraryTiles.header_height(screen.ctx) + Paint.scaler(ctx)(ctx.look.library.grid.padding_top)
            local want = Looks.colorer(ctx)(ctx.look.plate.keyline_color):getColorRGB32()
            local got = bb:getPixel(x, top):getColorRGB32()
            assert.same({ want.r, want.g, want.b }, { got.r, got.g, got.b })
        end)
    end)
end)
