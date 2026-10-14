-- The home's gestures (C9): its own swipe up from the bottom edge, the file manager's menu from
-- the top zone, nothing paged under it, and every other gesture passed to the zones registered
-- on the file manager; none of it in the file browser or the reader.
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

    it("lets a corner zone on the file manager win over the placeholder's tap", function()
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
        -- The other corners are unbound: a tap there closes the placeholder.
        send(harness.gesture("tap", 10, size.h - 10))
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    it("still closes on a tap mid-screen", function()
        local fm = fm_with_home()
        local size = Screen:getSize()
        send(harness.gesture("tap", size.w / 2, size.h / 2))
        assert.is_nil(Home.shown)
        assert.equals(fm, harness.top())
    end)

    it("passes a tap to the file manager's zones only, not to the file chooser beneath", function()
        local fm = fm_with_home()
        local size = Screen:getSize()
        -- Close the placeholder and paint the file chooser, so its items have their places, then
        -- bring the home back over it.
        send(harness.gesture("tap", size.w / 2, size.h / 2))
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
