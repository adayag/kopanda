-- The home's gestures (C9; sheets' C3 and C11): its own swipe up from the bottom edge, the file
-- manager's menu from the top zone, nothing paged under it, every other gesture passed to the
-- zones registered on the file manager, and a hold opening the held widget's hold, its settings
-- or the home's sheet; none of it in the file browser or the reader.
describe("gestures on the KoPanda home", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local InfoMessage = require("ui/widget/infomessage")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")
    local Home

    local SETTINGS_TEXT = "KoPanda has no settings yet."

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    local function swipe(x, y, direction)
        local ges = harness.gesture("swipe", x, y)
        ges.direction = direction
        ges.distance = Screen:scaleBySize(300)
        return ges
    end

    -- The settings stub's message, wherever it is on the stack, or nil.
    local function settings_message()
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == InfoMessage and widget.text == SETTINGS_TEXT then
                return widget
            end
        end
    end

    -- A tap at (x, y) that no slot's widget acts on: the point is outside every slot of the
    -- shown home whose widget has tap.
    local function untapped(x, y)
        local Geom = require("ui/geometry")
        for _, slot in ipairs(Home.shown.slots) do
            if slot.module and slot.module.tap then
                assert.is_false(slot.rect:contains(Geom:new{ x = x, y = y, w = 0, h = 0 }), slot.widget)
            end
        end
        return harness.gesture("tap", x, y)
    end

    -- A file manager with its home up.
    local function fm_with_home(dir)
        local fm = harness.show_fm(dir)
        harness.tick(2)
        assert.equals(Home.shown, harness.top())
        return fm
    end

    -- A folder of 60 subfolders, more than one page of the file chooser.
    local function long_library()
        local dir = os.getenv("KO_HOME") .. "/gesture-long-library"
        if not lfs.attributes(dir, "mode") then
            assert(lfs.mkdir(dir))
            for i = 1, 60 do
                assert(lfs.mkdir(string.format("%s/folder-%02d", dir, i)))
            end
        end
        return dir
    end

    before_each(function()
        harness.load()
        Home = require("home")
    end)

    after_each(function()
        harness.teardown()
    end)

    it("opens the settings stub on a swipe up from the bottom edge", function()
        fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h * 15 / 16, "north"))
        local message = settings_message()
        assert.is_not_nil(message)
        assert.equals(message, harness.top())
        assert.equals(home, harness.top(2))
    end)

    it("leaves a swipe up the bottom-left corner, inside the left edge band, alone", function()
        fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w / 16, size.h * 15 / 16, "north"))
        assert.is_nil(settings_message())
        assert.equals(home, harness.top())
    end)

    it("leaves a swipe up the bottom-right corner, inside the right edge band, alone", function()
        fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w * 15 / 16, size.h * 15 / 16, "north"))
        assert.is_nil(settings_message())
        assert.equals(home, harness.top())
    end)

    it("leaves a swipe up from mid-screen, outside the bottom edge band, alone", function()
        fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h / 2, "north"))
        assert.is_nil(settings_message())
        assert.equals(home, harness.top())
    end)

    it("opens the file manager's menu over the home on a tap at the top centre", function()
        local fm = fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(harness.gesture("tap", size.w / 2, size.h / 16))
        assert.is_not_nil(fm.menu.menu_container)
        assert.equals(fm.menu.menu_container, harness.top())
        assert.equals(home, harness.top(2))
        assert.equals(home, Home.shown)
    end)

    it("opens the file manager's menu over the home on a swipe down from the top centre", function()
        local fm = fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h / 16, "south"))
        assert.is_not_nil(fm.menu.menu_container)
        assert.equals(fm.menu.menu_container, harness.top())
        assert.equals(home, harness.top(2))
    end)

    it("honours activate_menu = swipe: a tap at the top centre opens no menu", function()
        -- Read once, in FileManagerMenu:init (filemanagermenu.lua:51).
        G_reader_settings:saveSetting("activate_menu", "swipe")
        finally(function()
            G_reader_settings:delSetting("activate_menu")
        end)
        local fm = fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(harness.gesture("tap", size.w / 2, size.h / 16))
        assert.is_nil(fm.menu.menu_container)
        assert.equals(home, harness.top())
        send(swipe(size.w / 2, size.h / 16, "south"))
        assert.is_not_nil(fm.menu.menu_container)
    end)

    it("consumes a west or east swipe mid-screen, leaving the file chooser's page", function()
        local fm = fm_with_home(long_library())
        local home = Home.shown
        assert.truthy(fm.file_chooser.page_num > 1)
        local page = fm.file_chooser.page
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h / 2, "west"))
        assert.equals(page, fm.file_chooser.page)
        send(swipe(size.w / 2, size.h / 2, "east"))
        assert.equals(page, fm.file_chooser.page)
        assert.equals(home, harness.top())
        assert.equals(home, Home.shown)
    end)

    it("passes a west swipe in the bottom edge band to a zone registered there", function()
        local fm = fm_with_home()
        local received
        -- As the Gestures plugin registers its bottom edge swipes (gestures main.lua:963-968, :1026-1029,
        -- :1189-1195).
        fm:registerTouchZones{ {
            id = "kopanda_spec_bottom_edge_swipe",
            ges = "swipe",
            screen_zone = { ratio_x = 0, ratio_y = 7 / 8, ratio_w = 1, ratio_h = 1 / 8 },
            handler = function(ges)
                received = ges
                return true
            end,
            overrides = { "filemanager_swipe" },
        } }
        local size = Screen:getSize()
        local ges = swipe(size.w / 2, size.h * 15 / 16, "west")
        send(ges)
        assert.equals(ges, received)
        assert.equals(Home.shown, harness.top())
    end)

    it("passes a gesture it doesn't use to a zone registered on the file manager", function()
        local fm = fm_with_home()
        local received
        fm:registerTouchZones{ {
            id = "kopanda_spec_two_finger_tap",
            ges = "two_finger_tap",
            screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 },
            handler = function(ges)
                received = ges
                return true
            end,
        } }
        local size = Screen:getSize()
        local ges = harness.gesture("two_finger_tap", size.w / 2, size.h / 2)
        -- The span between the fingers (frontend/device/gesturedetector.lua:537-545), which the
        -- screenshot module's two-finger zone reads.
        ges.span = Screen:scaleBySize(100)
        send(ges)
        assert.equals(ges, received)
        assert.equals(Home.shown, harness.top())
    end)

    it("lets a corner zone on the file manager win over the home's tap", function()
        local fm = fm_with_home()
        local received
        fm:registerTouchZones{ {
            id = "kopanda_spec_corner_tap",
            ges = "tap",
            screen_zone = { ratio_x = 7 / 8, ratio_y = 7 / 8, ratio_w = 1 / 8, ratio_h = 1 / 8 },
            handler = function(ges)
                received = ges
                return true
            end,
        } }
        local home = Home.shown
        local size = Screen:getSize()
        local ges = harness.gesture("tap", size.w - 10, size.h - 10)
        send(ges)
        assert.equals(ges, received)
        assert.equals(home, harness.top())
        -- The other corners are unbound: a tap there closes the home.
        send(untapped(10, size.h - 10))
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    -- Registers a stub widget with tap for every id of the default layout, each slot height
    -- tall[id] (60 when unset), and returns a function giving the taps so far.
    local function tappable_stubs(tall)
        local Widget = require("ui/widget/widget")
        local Geom = require("ui/geometry")
        local taps = 0
        local stubs = {}
        for _, id in ipairs({ "date", "clock", "quote", "weather", "stats" }) do
            local h = tall[id] or 60
            stubs[id] = {
                id = id,
                height = function()
                    return h
                end,
                build = function(width)
                    return Widget:new{ dimen = Geom:new{ w = width, h = h } }
                end,
                tap = function()
                    taps = taps + 1
                end,
            }
        end
        package.loaded["widgets"].get = function(id)
            return stubs[id]
        end
        return function()
            return taps
        end
    end

    local function slot_of(id)
        for _, slot in ipairs(Home.shown.slots) do
            if slot.widget == id then
                return slot
            end
        end
    end

    local function point(x, y)
        return require("ui/geometry"):new{ x = x, y = y, w = 0, h = 0 }
    end

    it("opens the file manager's menu on a tap in the top menu zone over a tappable slot", function()
        local taps = tappable_stubs({})
        local fm = fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        local rect = slot_of("date").rect
        local x, y = rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
        -- Inside the slot and inside DTAP_ZONE_MENU, the top eighth (defaults.lua:59).
        assert.is_true(rect:contains(point(x, y)))
        assert.truthy(y < size.h / 8)
        send(harness.gesture("tap", x, y))
        assert.equals(0, taps())
        assert.is_not_nil(fm.menu.menu_container)
        assert.equals(fm.menu.menu_container, harness.top())
        assert.equals(home, harness.top(2))
    end)

    it("lets a corner zone on the file manager win over a tappable slot under it", function()
        local size = Screen:getSize()
        local tall = math.floor(size.h * 0.67)
        local taps = tappable_stubs({ quote = 20, weather = tall, stats = tall })
        local fm = fm_with_home()
        local received
        fm:registerTouchZones{ {
            id = "kopanda_spec_corner_tap",
            ges = "tap",
            screen_zone = { ratio_x = 7 / 8, ratio_y = 7 / 8, ratio_w = 1 / 8, ratio_h = 1 / 8 },
            handler = function(ges)
                received = ges
                return true
            end,
        } }
        local home = Home.shown
        local rect = slot_of("stats").rect
        local x, y = rect.x + rect.w - 5, rect.y + rect.h - 5
        assert.is_true(rect:contains(point(x, y)))
        assert.truthy(x >= size.w * 7 / 8 and y >= size.h * 7 / 8)
        local ges = harness.gesture("tap", x, y)
        send(ges)
        assert.equals(ges, received)
        assert.equals(0, taps())
        assert.equals(home, harness.top())
    end)

    it("still closes on a tap outside every tappable slot", function()
        local fm = fm_with_home()
        local size = Screen:getSize()
        send(untapped(size.w / 2, size.h / 2))
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    it("passes a tap to the file manager's zones only, not to the file chooser beneath", function()
        -- A layout with no featured row, so the file chooser's items lie under no slot that acts
        -- on a tap: the featured book under one would open.
        assert.is_true(package.loaded["settings"].set("layout.rows", {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "quote", share = 1 } },
            { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
        }))
        local fm = fm_with_home()
        local size = Screen:getSize()
        -- Close the home and paint the file chooser, so its items have their places, then
        -- bring the home back over it.
        send(untapped(size.w / 2, size.h / 2))
        UIManager:forceRePaint()
        require("dispatcher"):execute({ kopanda_home = true })
        harness.tick(2)
        assert.is_not_nil(Home.shown)
        assert.equals(Home.shown, harness.top())
        local item
        for _, row in ipairs(fm.file_chooser.layout) do
            local dimen = row[1].dimen
            if dimen and dimen.y and dimen.y > size.h / 4 then
                item = row[1]
                break
            end
        end
        assert.is_not_nil(item)
        local selected = false
        fm.file_chooser.onMenuSelect = function()
            selected = true
            return true
        end
        send(harness.gesture("tap", item.dimen.x + item.dimen.w / 2, item.dimen.y + item.dimen.h / 2))
        harness.tick(2)
        assert.is_false(selected)
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    -- KOReader's touch lock, the toggle_touch_input action (inputcontainer.lua:297-350).
    it("honours KOReader's ignore touch input", function()
        local InputContainer = require("ui/widget/container/inputcontainer")
        local always_active = InputContainer.isGestureAlwaysActive
        local fm = fm_with_home()
        local home = Home.shown
        UIManager:setIgnoreTouchInput(true)
        finally(function()
            UIManager:setIgnoreTouchInput(false)
            InputContainer.isGestureAlwaysActive = always_active
        end)
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h * 15 / 16, "north"))
        assert.is_nil(settings_message())
        assert.equals(home, harness.top())
        send(harness.gesture("tap", size.w / 2, size.h / 2))
        assert.equals(home, Home.shown)
        assert.equals(home, harness.top())
        -- A zone the Gestures plugin reports always active still gets its gesture.
        local received
        fm:registerTouchZones{ {
            id = "kopanda_spec_always_active_tap",
            ges = "tap",
            screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 },
            handler = function(ges)
                received = ges
                return true
            end,
        } }
        InputContainer.isGestureAlwaysActive = function(_, id)
            return id == "kopanda_spec_always_active_tap"
        end
        local ges = harness.gesture("tap", size.w / 2, size.h / 2)
        send(ges)
        assert.equals(ges, received)
        assert.equals(home, harness.top())
    end)

    it("opens no settings on a swipe up from the bottom edge in the file browser", function()
        local fm = fm_with_home()
        local size = Screen:getSize()
        send(harness.gesture("tap", size.w / 2, size.h / 2))
        assert.equals(fm, harness.top())
        send(swipe(size.w / 2, size.h * 15 / 16, "north"))
        assert.is_nil(settings_message())
    end)

    it("opens no settings on a swipe up from the bottom edge in the reader", function()
        local reader = harness.open_reader()
        harness.tick(2)
        assert.equals(reader, harness.top())
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h * 15 / 16, "north"))
        assert.is_nil(settings_message())
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
            assert.is_nil(settings_message())
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
            assert.is_nil(settings_message())
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
            assert.equals(settings_message(), harness.top())
            assert.equals(home, harness.top(2))
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
            assert.is_nil(settings_message())
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
            assert.is_nil(settings_message())
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
            assert.is_nil(settings_message())
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

        -- Records the opts.started each Sheet.show gets and the time.monotonic() on entry to
        -- each HomeSheet.open, for the rest of the test.
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
            assert.is_number(seen.started[1])
            assert.truthy(seen.started[1] <= seen.entered[1])
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
            assert.is_number(seen.started[1])
            assert.is_number(hold_entered)
            assert.truthy(seen.started[1] <= hold_entered)
            assert.truthy(seen.started[1] <= seen.entered[1])
        end)
    end)

    -- A Gestures action runs Dispatcher:execute, which sends its event with UIManager:sendEvent
    -- (frontend/dispatcher.lua:1549, :1586), to the home first.
    describe("actions dispatched while the home is up", function()
        local Dispatcher = require("dispatcher")
        local PluginLoader = require("pluginloader")

        it("reach the file manager's History, shown over the home", function()
            local fm = fm_with_home()
            local home = Home.shown
            Dispatcher:execute({ history = true })
            local list = fm.history.booklist_menu
            assert.is_not_nil(list)
            assert.equals(list, harness.top())
            assert.equals(home, harness.top(2))
            -- Closing the list returns to the home, not the file browser.
            list.close_callback()
            assert.equals(home, harness.top())
            assert.equals(home, Home.shown)
        end)

        it("reach the file manager with it marked always active for the call only", function()
            local fm = fm_with_home()
            local during
            fm.history.onShowHist = function()
                during = fm.is_always_active
                return true
            end
            Dispatcher:execute({ history = true })
            assert.is_true(during)
            assert.is_nil(fm.is_always_active)
        end)

        it("go straight through with no home up", function()
            local fm = fm_with_home()
            local size = Screen:getSize()
            send(harness.gesture("tap", size.w / 2, size.h / 2))
            assert.equals(fm, harness.top())
            local reached, during = false, nil
            fm.history.onShowHist = function()
                reached, during = true, fm.is_always_active
                return true
            end
            Dispatcher:execute({ history = true })
            assert.is_true(reached)
            assert.is_nil(during)
        end)

        it("are bridged by one wrapper per process, whatever the number of file managers", function()
            local fm = fm_with_home()
            local wrapped = Dispatcher.execute
            assert.is_not.equals(harness.dispatcher_execute, wrapped)
            fm:onClose()
            harness.show_fm()
            harness.tick(2)
            assert.equals(wrapped, Dispatcher.execute)
            require("apps/filemanager/filemanager").instance:onClose()
            harness.open_reader()
            harness.tick(2)
            assert.equals(wrapped, Dispatcher.execute)
        end)

        it("are left alone by a refused shell", function()
            table.insert(PluginLoader.enabled_plugins, { name = "simpleui" })
            harness.show_fm()
            harness.tick(2)
            assert.equals(harness.dispatcher_execute, Dispatcher.execute)
        end)
    end)
end)
