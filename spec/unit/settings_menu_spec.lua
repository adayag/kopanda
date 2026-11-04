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
    -- KoPanda's settings end with an Updates section: Check for KoPanda update, KOReader menu with a file manager up,
    -- then Apps (Storefront) while Storefront is loaded with its storefront_open action registered; a group's view has
    -- none of them.
    describe("the Updates section", function()
        local Dispatcher = require("dispatcher")
        local PluginLoader = require("pluginloader")
        local StudioMenu

        before_each(function()
            StudioMenu = require("studio_menu")
        end)

        -- Storefront loaded with its action registered, for the rest of the test.
        local function storefront()
            Dispatcher:registerAction("storefront_open", {
                category = "none",
                event = "KoPandaSpecStorefront",
                title = "Storefront",
                general = true,
            })
            local s = stub(PluginLoader, "isPluginLoaded", function(_, name)
                return name == "storefront"
            end)
            finally(function()
                s:revert()
                Dispatcher:removeAction("storefront_open")
            end)
        end

        -- The items the settings menu shows for group over the home.
        local function items_shown(group)
            gestures.fm_with_home()
            SettingsMenu.open(group)
            return shown_menu()[1].item_table
        end

        -- The item in items reading text.
        local function reading(items, text)
            for _, item in ipairs(items) do
                if item.text == text then
                    return item
                end
            end
        end

        local function settings_count()
            local n = 0
            for _ in ipairs(SchemaMenu.items()) do
                n = n + 1
            end
            return n
        end

        it("ends the settings with Check for KoPanda update, KOReader menu and Apps (Storefront), set apart", function()
            storefront()
            local items = items_shown()
            local n = #items
            assert.equals(settings_count() + 3, n)
            assert.is_true(items[n - 3].separator)
            assert.equals("Check for KoPanda update", items[n - 2].text)
            assert.equals("KOReader menu", items[n - 1].text)
            assert.equals("Apps (Storefront)", items[n].text)
        end)

        it("leaves Apps (Storefront) out while Storefront isn't loaded", function()
            local items = items_shown()
            assert.equals(settings_count() + 2, #items)
            assert.equals("KOReader menu", items[#items].text)
        end)

        it("opens KOReader's menu over the home from the tick after the settings menu closes", function()
            local items = items_shown()
            local fm = require("apps/filemanager/filemanager").instance
            local home = Home.shown
            shown_menu()[1]:onMenuSelect(reading(items, "KOReader menu"))
            assert.is_nil(shown_menu())
            assert.is_nil(fm.menu.menu_container)
            harness.tick()
            assert.is_not_nil(fm.menu.menu_container)
            assert.equals(fm.menu.menu_container, harness.top())
            assert.equals(home, harness.top(2))
        end)

        it("leaves KOReader menu out with no file manager up", function()
            assert.is_nil(require("apps/filemanager/filemanager").instance)
            SettingsMenu.open()
            local items = shown_menu()[1].item_table
            assert.is_nil(reading(items, "KOReader menu"))
            assert.equals("Check for KoPanda update", items[#items].text)
        end)

        it("leaves the section out of a group's view", function()
            storefront()
            local items = items_shown("weather")
            assert.equals(2, #items)
            assert.equals("weather.units", items[2].kopanda_key)
        end)

        it("leaves KOReader menu out of the featured group", function()
            local items = items_shown("featured")
            assert.equals(1, #items)
            assert.equals("featured.pinned", items[1].kopanda_key)
        end)

        it("checks for an update of the plugin's own folder, from the tick after the tap", function()
            local checked = {}
            local s = stub(StudioMenu, "check_for_update", function(plugin)
                checked[#checked + 1] = plugin
            end)
            finally(function()
                s:revert()
            end)
            reading(items_shown(), "Check for KoPanda update").callback()
            assert.equals(0, #checked)
            harness.tick()
            assert.equals(1, #checked)
            assert.truthy(checked[1].path:match("kopanda%.koplugin$"), checked[1].path)
        end)

        it("names Settings, not the Studio menu, for a check that fails", function()
            local NetworkMgr = require("ui/network/manager")
            local ReleaseSource = require("release_source")
            local logged = {}
            local stubs = {
                stub(NetworkMgr, "runWhenConnected", function(_, callback)
                    callback()
                end),
                stub(ReleaseSource, "latest", function()
                    error("kopanda-test: no network")
                end),
                stub(logger, "err", function(...)
                    logged[#logged + 1] = table.concat({ ... }, " ")
                end),
            }
            finally(function()
                for _, s in ipairs(stubs) do
                    s:revert()
                end
            end)
            reading(items_shown(), "Check for KoPanda update").callback()
            harness.tick()
            local failure
            for _, line in ipairs(logged) do
                if line:find("kopanda-test: no network", 1, true) then
                    failure = line
                end
            end
            assert.truthy(failure, table.concat(logged, "\n"))
            assert.truthy(failure:find("Settings › Check for KoPanda update failed", 1, true), failure)
        end)

        it("opens Storefront through the launcher's entry", function()
            storefront()
            local LauncherEntries = require("launcher_entries")
            local ran = {}
            local s = stub(LauncherEntries, "run", function(entry)
                ran[#ran + 1] = entry
            end)
            finally(function()
                s:revert()
            end)
            local items = items_shown()
            items[#items].callback()
            harness.tick()
            local entry = { kind = "plugin", plugin = "storefront", action = "storefront_open", label = "Storefront" }
            assert.same({ entry }, ran)
        end)
    end)
end)
