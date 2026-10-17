-- The home's gestures (C9): its own swipe up from the bottom edge, the file manager's menu from
-- the top zone, nothing paged under it and every other gesture passed to the zones registered on
-- the file manager; none of it in the file browser or the reader. Holds (sheets' C3 and C11) are
-- in hold_routing_spec.lua.
describe("gestures on the KoPanda home", function()
    local harness = require("plugin_harness")
    local gestures = require("home_gestures")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")
    local Home

    local send = gestures.send
    local settings_menu = gestures.settings_menu
    local fm_with_home = gestures.fm_with_home
    local slot_of = gestures.slot_of
    local point = gestures.point

    local function swipe(x, y, direction)
        local ges = harness.gesture("swipe", x, y)
        ges.direction = direction
        ges.distance = Screen:scaleBySize(300)
        return ges
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

    -- Every schema key, in order: the full settings list.
    local function all_keys()
        local keys = {}
        for i, entry in ipairs(require("schema").keys) do
            keys[i] = entry.id
        end
        return keys
    end

    it("opens the full settings list on a swipe up from the bottom edge", function()
        fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h * 15 / 16, "north"))
        local menu = settings_menu()
        assert.is_not_nil(menu)
        assert.equals(menu, harness.top())
        assert.equals(home, harness.top(2))
        assert.same(all_keys(), gestures.settings_keys())
    end)

    -- A hold on a slot whose widget has no hold of its own opens the settings for its group: the
    -- widget module's settings_prefix.
    describe("a hold on a widget without a hold", function()
        local function hold_on(id)
            local rect = slot_of(id).rect
            send(harness.gesture("hold", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)))
        end

        it("opens the weather's two settings over the home", function()
            fm_with_home()
            local home = Home.shown
            hold_on("weather")
            assert.equals(settings_menu(), harness.top())
            assert.equals(home, harness.top(2))
            assert.same({ "weather.location", "weather.units" }, gestures.settings_keys())
        end)

        it("opens the stats' one setting", function()
            fm_with_home()
            hold_on("stats")
            assert.same({ "stats.show" }, gestures.settings_keys())
        end)

        it("opens the full list from the date, whose group has no keys", function()
            fm_with_home()
            hold_on("date")
            assert.same(all_keys(), gestures.settings_keys())
        end)
    end)

    it("leaves a swipe up the bottom-left corner, inside the left edge band, alone", function()
        fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w / 16, size.h * 15 / 16, "north"))
        assert.is_nil(settings_menu())
        assert.equals(home, harness.top())
    end)

    it("leaves a swipe up the bottom-right corner, inside the right edge band, alone", function()
        fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w * 15 / 16, size.h * 15 / 16, "north"))
        assert.is_nil(settings_menu())
        assert.equals(home, harness.top())
    end)

    it("leaves a swipe up from mid-screen, outside the bottom edge band, alone", function()
        fm_with_home()
        local home = Home.shown
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h / 2, "north"))
        assert.is_nil(settings_menu())
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
        -- Just above the nav bar, which wins in its band (D4), and still in the corner eighth
        -- (DTAP_ZONE_BOTTOM_RIGHT, defaults.lua:69).
        local y = home.nav.dimen.y - 5
        assert.truthy(y >= size.h * 7 / 8)
        local ges = harness.gesture("tap", size.w - 10, y)
        send(ges)
        assert.equals(ges, received)
        assert.equals(home, harness.top())
        -- The other corners are unbound: a tap there closes the home.
        send(untapped(10, y))
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    -- The nav bar's band (the nav bar's C3, D4): a tap or a hold there goes to the bar before the
    -- zones on the file manager; anything else passes through as before.
    describe("in the nav bar's band", function()
        -- A zone on the file manager over the corner eighth at ratio_x, as the Gestures plugin
        -- registers its corner taps (plugins/gestures.koplugin/main.lua:985-990, :1287-1288).
        local function bind_corner(fm, ratio_x)
            local got = {}
            fm:registerTouchZones{ {
                id = "kopanda_spec_corner_" .. ratio_x,
                ges = "tap",
                screen_zone = { ratio_x = ratio_x, ratio_y = 7 / 8, ratio_w = 1 / 8, ratio_h = 1 / 8 },
                handler = function(ges)
                    got[#got + 1] = ges
                    return true
                end,
            } }
            return got
        end

        -- The centre of tab i of the shown home's bar.
        local function tab_centre(i)
            local bar = Home.shown.nav
            local column = bar.columns[i]
            return bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
                bar.dimen.y + math.floor(bar.dimen.h / 2)
        end

        it("runs the Settings tab, not a corner zone, on a tap at the bottom-right corner", function()
            local fm = fm_with_home()
            local home = Home.shown
            local got = bind_corner(fm, 7 / 8)
            local size = Screen:getSize()
            send(harness.gesture("tap", size.w - 10, size.h - 10))
            assert.same({}, got)
            assert.equals(settings_menu(), harness.top())
            assert.equals(home, harness.top(2))
            assert.same(all_keys(), gestures.settings_keys())
        end)

        it("runs the Home tab, which does nothing, not Gestures' frontlight corner, at the bottom-left", function()
            -- Gestures binds the bottom-left corner tap to the frontlight on any device with one
            -- (plugins/gestures.koplugin/defaults.lua:9), the emulator included
            -- (frontend/device/sdl/device.lua:157).
            local fm = fm_with_home()
            local home = Home.shown
            local got = bind_corner(fm, 0)
            local size = Screen:getSize()
            send(harness.gesture("tap", 10, size.h - 10))
            assert.same({}, got)
            assert.equals(home, Home.shown)
            assert.equals(home, harness.top())
        end)

        -- cover-grid C8: the Library tab's run is now the library, not the home folder.
        it("closes the home and shows the library on a tap on the Library tab", function()
            local fixture = require("library_fixture")
            fixture.install({ [fixture.ROOT] = { books = fixture.books(2) } })
            finally(fixture.restore)
            local fm = fm_with_home()
            local on_home = fm.onHome
            local calls = 0
            fm.onHome = function(...)
                calls = calls + 1
                return on_home(...)
            end
            local runs = spy.on(package.loaded["launcher_entries"], "run")
            finally(function()
                runs:revert()
            end)
            send(harness.gesture("tap", tab_centre(2)))
            local Library = package.loaded["library"]
            assert.spy(runs).was.called(1)
            assert.spy(runs).was.called_with({ kind = "kopanda", target = "library" })
            assert.equals(0, calls)
            assert.is_nil(Home.shown)
            assert.is_not_nil(Library.shown)
            assert.equals(Library.shown, harness.top())
            assert.equals(fm, harness.top(2))
        end)

        it("still opens the full settings list on a swipe up starting in the band", function()
            fm_with_home()
            local home = Home.shown
            local size = Screen:getSize()
            local y = size.h - 10
            assert.truthy(y >= home.nav.dimen.y)
            send(swipe(size.w / 2, y, "north"))
            assert.equals(settings_menu(), harness.top())
            assert.equals(home, harness.top(2))
            assert.same(all_keys(), gestures.settings_keys())
        end)

        it("does nothing on a tap in the band under KOReader's touch lock", function()
            local fm = fm_with_home()
            local home = Home.shown
            local on_home = fm.onHome
            local calls = 0
            fm.onHome = function(...)
                calls = calls + 1
                return on_home(...)
            end
            UIManager:setIgnoreTouchInput(true)
            finally(function()
                UIManager:setIgnoreTouchInput(false)
            end)
            send(harness.gesture("tap", tab_centre(2)))
            send(harness.gesture("tap", tab_centre(5)))
            assert.equals(0, calls)
            assert.is_nil(settings_menu())
            assert.equals(home, Home.shown)
            assert.equals(home, harness.top())
        end)
    end)

    -- Registers a stub widget with tap for every id of the default layout, each slot height
    -- tall[id] (60 when unset) as the table holds it at each build, and returns a function giving
    -- the taps so far.
    local function tappable_stubs(tall)
        local Widget = require("ui/widget/widget")
        local Geom = require("ui/geometry")
        local taps = 0
        local stubs = {}
        for _, id in ipairs({ "date", "clock", "quote", "weather", "stats" }) do
            stubs[id] = {
                id = id,
                height = function()
                    return tall[id] or 60
                end,
                build = function(width)
                    return Widget:new{ dimen = Geom:new{ w = width, h = tall[id] or 60 } }
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
        local tall = { quote = 20, weather = 20, stats = 20 }
        local taps = tappable_stubs(tall)
        local fm = fm_with_home()
        -- The last row grown to end on the nav bar's band, which takes its own taps first (D4),
        -- so its bottom-right corner lies in the corner eighth just above the bar.
        local stats = slot_of("stats").rect
        tall.weather = Home.shown.nav.dimen.y - stats.y
        tall.stats = tall.weather
        Home.shown:refresh()
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
        -- The last row ends above the nav bar, which takes its band first (D4).
        assert.truthy(rect.y + rect.h <= home.nav.dimen.y)
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
        assert.is_nil(settings_menu())
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
        assert.is_nil(settings_menu())
    end)

    it("opens no settings on a swipe up from the bottom edge in the reader", function()
        local reader = harness.open_reader()
        harness.tick(2)
        assert.equals(reader, harness.top())
        local size = Screen:getSize()
        send(swipe(size.w / 2, size.h * 15 / 16, "north"))
        assert.is_nil(settings_menu())
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
