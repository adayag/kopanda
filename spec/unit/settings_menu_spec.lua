-- The settings menu on its own: KOReader's TouchMenu with one tab, the
-- appbar.settings icon, over the home, closed by a tap outside it or the Back key; a raising open
-- shows nothing and is logged.
describe("the settings menu", function()
    local harness = require("plugin_harness")
    local gestures = require("home_gestures")
    local Blitbuffer = require("ffi/blitbuffer")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local Event = require("ui/event")
    local Screen = require("device").screen
    local TouchMenu = require("ui/widget/touchmenu")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Home, SettingsMenu, SchemaMenu

    before_each(function()
        harness.load()
        Home = require("home")
        SettingsMenu = require("settings_menu")
        SchemaMenu = require("menu")
    end)

    after_each(function()
        harness.teardown()
    end)

    -- How many pixels of bb are not white.
    local function inked(bb)
        local n = 0
        for y = 0, bb:getHeight() - 1, 4 do
            for x = 0, bb:getWidth() - 1, 4 do
                local c = bb:getPixel(x, y):getColorRGB32()
                if c:getR() < 200 or c:getG() < 200 or c:getB() < 200 then
                    n = n + 1
                end
            end
        end
        return n
    end

    it("builds, paints and closes a TouchMenu with one tab", function()
        -- Behaviour settled against KOReader's own TouchMenu.
        local container = CenterContainer:new{ dimen = Screen:getSize(), ignore = "height" }
        local tapped = 0
        local items = {
            { text = "First", callback = function() tapped = tapped + 1 end, keep_menu_open = true },
            { text = "Second" },
        }
        items.icon = "appbar.settings"
        local menu = TouchMenu:new{
            width = Screen:getWidth(),
            tab_item_table = { items },
            show_parent = container,
        }
        container[1] = menu
        UIManager:show(container)
        assert.equals(container, harness.top())
        assert.equals(1, #menu.bar.icon_widgets)
        assert.equals(2, #menu.item_table)
        local bb = Blitbuffer.new(Screen:getWidth(), Screen:getHeight(), Blitbuffer.TYPE_BBRGB32)
        bb:fill(Blitbuffer.COLOR_WHITE)
        container:paintTo(bb, 0, 0)
        assert.truthy(inked(bb) > 0)
        menu:onMenuSelect(menu.item_table[1])
        assert.equals(1, tapped)
        assert.equals(container, harness.top())
        local size = Screen:getSize()
        menu:onTapCloseAllMenus(nil, harness.gesture("tap", size.w / 2, size.h - 2))
        assert.is_not.equals(container, harness.top())
    end)

    -- The settings menu's container, wherever it is on the stack, or nil.
    local function shown_menu()
        return gestures.settings_menu()
    end

    it("shows the weather group's two rows over the home", function()
        gestures.fm_with_home()
        local home = Home.shown
        SettingsMenu.open("weather")
        local container = shown_menu()
        assert.is_not_nil(container)
        assert.equals(container, harness.top())
        assert.equals(home, harness.top(2))
        local menu = container[1]
        assert.equals(TouchMenu, getmetatable(menu))
        assert.equals(1, #menu.tab_item_table)
        assert.equals("appbar.settings", menu.tab_item_table[1].icon)
        assert.equals(2, #menu.item_table)
        assert.equals("weather.location", menu.item_table[1].kopanda_key)
        assert.equals("weather.units", menu.item_table[2].kopanda_key)
    end)

    it("closes on a tap outside it, leaving the home on top", function()
        gestures.fm_with_home()
        local home = Home.shown
        SettingsMenu.open("weather")
        local container = shown_menu()
        local size = Screen:getSize()
        local below = container[1].dimen.y + container[1].dimen.h + 10
        assert.truthy(below < size.h)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", size.w / 2, below)))
        assert.is_nil(shown_menu())
        assert.equals(home, harness.top())
    end)

    it("closes on the Back key, leaving the home on top", function()
        gestures.fm_with_home()
        local home = Home.shown
        SettingsMenu.open()
        assert.is_not_nil(shown_menu())
        -- The event TouchMenu's key_events.Back sends for the Back key (touchmenu.lua:531).
        UIManager:sendEvent(Event:new("Back"))
        assert.is_nil(shown_menu())
        assert.equals(home, harness.top())
    end)

    it("shows nothing and logs when building the items raises", function()
        gestures.fm_with_home()
        local home = Home.shown
        local logged = spy.on(logger, "err")
        local items = SchemaMenu.items
        SchemaMenu.items = function()
            error("kopanda-test: items failed")
        end
        finally(function()
            SchemaMenu.items = items
            logger.err:revert()
        end)
        SettingsMenu.open()
        assert.is_nil(shown_menu())
        assert.equals(home, harness.top())
        local found = false
        for _, call in ipairs(logged.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find("kopanda-test: items failed", 1, true) then
                    found = true
                end
            end
        end
        assert.is_true(found)
    end)
end)
