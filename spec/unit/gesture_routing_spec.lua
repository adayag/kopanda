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
end)
