-- A hold on the KoPanda home (sheets' C3 and C11): the held widget's hold, its settings or the
-- home's sheet, after the zones registered on the file manager. The home's other gestures are in
-- gesture_routing_spec.lua.
describe("gestures on the KoPanda home", function()
    local harness = require("plugin_harness")
    local gestures = require("home_gestures")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local Home

    local send = gestures.send
    local settings_menu = gestures.settings_menu
    local settings_keys = gestures.settings_keys
    local fm_with_home = gestures.fm_with_home
    local slot_of = gestures.slot_of
    local point = gestures.point

    before_each(function()
        harness.load()
        Home = require("home")
    end)

    after_each(function()
        harness.teardown()
    end)

    -- A hold on the home (sheets' C3): the held slot's widget's hold, its settings when it has
    -- none, or the home's sheet, after the zones registered on the file manager.
    describe("holds", function()
        local Geom = require("ui/geometry")
        local time = require("ui/time")
        local Sheet

        -- Registers a stub widget for date, clock, quote, weather and stats, each 60 tall; one
        -- whose id is in holds gets holds[id] as its hold. featured and launcher get no module,
        -- so their slots are blank. Returns the stubs by id.
        local function stubs_with(holds)
            local Widget = require("ui/widget/widget")
            local stubs = {}
            for _, id in ipairs({ "date", "clock", "quote", "weather", "stats" }) do
                stubs[id] = {
                    id = id,
                    height = function()
                        return 60
                    end,
                    build = function(width)
                        return Widget:new{ dimen = Geom:new{ w = width, h = 60 } }
                    end,
                    hold = holds[id],
                }
            end
            package.loaded["widgets"].get = function(id)
                return stubs[id]
            end
            return stubs
        end

        -- A hold function that records each call's arguments and returns result.
        local function recording(result)
            local calls = {}
            return function(...)
                calls[#calls + 1] = { ... }
                return result
            end, calls
        end

        local function sheet_shown()
            return Sheet.shown ~= nil and Sheet.shown == harness.top()
        end

        local function sheets_on_stack()
            local count = 0
            for _, widget in ipairs(harness.stack()) do
                if widget.name == "kopanda_sheet" then
                    count = count + 1
                end
            end
            return count
        end

        -- A point on the shown home outside every slot's rectangle and outside the corners,
        -- scanned for in 10 px steps.
        local function empty_point()
            local size = Screen:getSize()
            for y = math.floor(size.h / 8), math.floor(size.h * 7 / 8), 10 do
                for x = math.floor(size.w / 8), math.floor(size.w * 7 / 8), 10 do
                    local inside = false
                    for _, slot in ipairs(Home.shown.slots) do
                        if slot.rect:contains(point(x, y)) then
                            inside = true
                            break
                        end
                    end
                    if not inside then
                        return x, y
                    end
                end
            end
            error("no point outside every slot")
        end

        local function centre_of(id)
            local rect = slot_of(id).rect
            return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
        end

        local function hold(x, y)
            local ges = harness.gesture("hold", x, y)
            send(ges)
            return ges
        end

        before_each(function()
            Sheet = require("sheet")
        end)

        it("opens the home sheet over the home on a hold outside every slot", function()
            stubs_with({})
            fm_with_home()
            local home = Home.shown
            hold(empty_point())
            assert.is_true(sheet_shown())
            assert.equals("home", Sheet.shown.spec.name)
            assert.equals(home, harness.top(2))
            assert.equals(home, Home.shown)
            assert.is_nil(settings_menu())
        end)

        it("opens the home sheet on a hold in a blank slot that has no widget module", function()
            -- A slot with no module measures 0 (layout.lua:163-166), so the blank one shares a
            -- row whose other slot gives it its height.
            local stubs = stubs_with({})
            stubs.clock = nil
            fm_with_home()
            assert.is_nil(slot_of("clock").module)
            assert.truthy(slot_of("clock").rect.h > 0)
            hold(centre_of("clock"))
            assert.is_true(sheet_shown())
            assert.equals("home", Sheet.shown.spec.name)
        end)

        it("runs the held slot's hold once with the home's ctx, the gesture and the built widget", function()
            local quote_hold, calls = recording(nil)
            stubs_with({ quote = quote_hold })
            fm_with_home()
            local home = Home.shown
            local ges = hold(centre_of("quote"))
            assert.equals(1, #calls)
            assert.equals(home.ctx, calls[1][1])
            assert.equals(ges, calls[1][2])
            assert.equals(slot_of("quote").built, calls[1][3])
            assert.equals(0, sheets_on_stack())
            assert.is_nil(settings_menu())
            assert.equals(home, harness.top())
        end)

        it("opens the home sheet when the held slot's hold returns false", function()
            local quote_hold, calls = recording(false)
            stubs_with({ quote = quote_hold })
            fm_with_home()
            local home = Home.shown
            hold(centre_of("quote"))
            assert.equals(1, #calls)
            assert.is_true(sheet_shown())
            assert.equals("home", Sheet.shown.spec.name)
            assert.equals(home, harness.top(2))
        end)

        it("opens the held widget's settings when its module has no hold", function()
            stubs_with({})
            fm_with_home()
            local home = Home.shown
            local open = spy.on(package.loaded["settings_menu"], "open")
            finally(function()
                open:revert()
            end)
            local x, y = centre_of("weather")
            assert.is_true(Home.shown:onGesture(harness.gesture("hold", x, y)))
            assert.spy(open).was.called(1)
            assert.equals(0, sheets_on_stack())
            assert.equals(settings_menu(), harness.top())
            assert.equals(home, harness.top(2))
        end)

        it("opens the quote's settings, cut to its group, on a hold on the quote", function()
            fm_with_home()
            assert.is_nil(slot_of("quote").module.hold)
            hold(centre_of("quote"))
            assert.same({ "quote.source" }, settings_keys())
            assert.equals(0, sheets_on_stack())
        end)

        -- As the Gestures plugin registers hold_top_right_corner (gestures main.lua:1128-1131,
        -- :1287-1305): bound, its handler returns true; unbound, nothing (:1316-1320).
        local function corner_hold_zone(fm, result)
            local calls = 0
            fm:registerTouchZones{ {
                id = "kopanda_spec_hold_top_right_corner",
                ges = "hold",
                screen_zone = { ratio_x = 7 / 8, ratio_y = 0, ratio_w = 1 / 8, ratio_h = 1 / 8 },
                handler = function()
                    calls = calls + 1
                    return result
                end,
            } }
            return function()
                return calls
            end
        end

        -- A point inside the clock's slot and inside the top-right corner.
        local function clock_corner()
            local size = Screen:getSize()
            local rect = slot_of("clock").rect
            local x, y = rect.x + rect.w - 5, rect.y + 5
            assert.truthy(x >= size.w * 7 / 8 and y < size.h / 8)
            return x, y
        end

        it("lets a hold zone on the file manager that consumes the hold win", function()
            local clock_hold, calls = recording(nil)
            stubs_with({ clock = clock_hold })
            local fm = fm_with_home()
            local zone_calls = corner_hold_zone(fm, true)
            local home = Home.shown
            hold(clock_corner())
            assert.equals(1, zone_calls())
            assert.equals(0, #calls)
            assert.equals(0, sheets_on_stack())
            assert.is_nil(settings_menu())
            assert.equals(home, harness.top())
        end)

        it("passes a hold to the home's step when the file manager's zone returns nothing", function()
            local clock_hold, calls = recording(nil)
            stubs_with({ clock = clock_hold })
            local fm = fm_with_home()
            local zone_calls = corner_hold_zone(fm, nil)
            hold(clock_corner())
            assert.equals(1, zone_calls())
            assert.equals(1, #calls)
        end)

        -- D3: a hold on the nav bar is consumed and runs nothing.
        it("opens no sheet and runs no slot's hold on a hold in the nav bar's band", function()
            local held, calls = recording(nil)
            stubs_with({ date = held, clock = held, quote = held, weather = held, stats = held })
            fm_with_home()
            local home = Home.shown
            local bar = home.nav
            local size = Screen:getSize()
            for i, column in ipairs(bar.columns) do
                hold(bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
                    bar.dimen.y + math.floor(bar.dimen.h / 2))
                assert.equals(home, harness.top(), "tab " .. i)
            end
            hold(10, size.h - 10)
            hold(size.w - 10, size.h - 10)
            assert.equals(0, #calls)
            assert.equals(0, sheets_on_stack())
            assert.is_nil(settings_menu())
            assert.equals(home, Home.shown)
            assert.equals(home, harness.top())
        end)

        it("opens nothing on a hold under KOReader's touch lock", function()
            stubs_with({})
            fm_with_home()
            local home = Home.shown
            UIManager:setIgnoreTouchInput(true)
            finally(function()
                UIManager:setIgnoreTouchInput(false)
            end)
            hold(empty_point())
            hold(centre_of("weather"))
            assert.equals(0, sheets_on_stack())
            assert.is_nil(settings_menu())
            assert.equals(home, harness.top())
        end)

        it("changes nothing on the hold_release after the home sheet shows", function()
            stubs_with({})
            fm_with_home()
            local home = Home.shown
            local x, y = empty_point()
            hold(x, y)
            local sheet = Sheet.shown
            assert.is_true(sheet_shown())
            send(harness.gesture("hold_release", x, y))
            assert.equals(sheet, Sheet.shown)
            assert.equals(sheet, harness.top())
            assert.equals(home, harness.top(2))
            assert.equals(1, sheets_on_stack())
            assert.is_nil(settings_menu())
        end)

        it("takes its sheet with it when the home is closed", function()
            stubs_with({})
            local fm = fm_with_home()
            hold(empty_point())
            assert.is_true(sheet_shown())
            -- As KOReader closes a window by itself, not through Home.close.
            UIManager:close(Home.shown)
            assert.equals(0, sheets_on_stack())
            assert.is_nil(Sheet.shown)
            assert.is_nil(Home.shown)
            assert.equals(fm, harness.top())
        end)

        -- Records the opts.started stamp each Sheet.show gets and the time.monotonic() on entry
        -- to each HomeSheet.open, for the rest of the test.
        local function timings()
            local seen = { started = {}, entered = {} }
            local HomeSheet = require("home_sheet")
            local open, show = HomeSheet.open, Sheet.show
            HomeSheet.open = function(...)
                seen.entered[#seen.entered + 1] = time.monotonic()
                return open(...)
            end
            Sheet.show = function(spec, ctx, opts)
                seen.started[#seen.started + 1] = opts and opts.started
                return show(spec, ctx, opts)
            end
            finally(function()
                HomeSheet.open, Sheet.show = open, show
            end)
            return seen
        end

        it("starts the home sheet's paint_ms at the hold, before the sheet is built", function()
            stubs_with({})
            fm_with_home()
            local seen = timings()
            hold(empty_point())
            assert.equals(1, #seen.started)
            assert.is_number(seen.started[1].wall)
            assert.is_number(seen.started[1].cpu)
            assert.truthy(seen.started[1].wall <= seen.entered[1])
        end)

        it("starts the paint_ms at the hold when the held slot's hold returns false", function()
            -- The held slot's hold notes the clock on entry and spins until it moves on, so a
            -- start taken after that hold is later than the entry.
            local hold_entered
            stubs_with({
                quote = function()
                    hold_entered = time.monotonic()
                    while time.monotonic() <= hold_entered do
                    end
                    return false
                end,
            })
            fm_with_home()
            local seen = timings()
            hold(centre_of("quote"))
            assert.equals(1, #seen.started)
            assert.is_number(seen.started[1].wall)
            assert.is_number(seen.started[1].cpu)
            assert.is_number(hold_entered)
            assert.truthy(seen.started[1].wall <= hold_entered)
            assert.truthy(seen.started[1].wall <= seen.entered[1])
        end)
    end)
end)
