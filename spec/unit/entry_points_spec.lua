-- Every way into the home (C7): the Home tab in the file manager's menu, KoPanda in both Tools
-- menus, and the "KoPanda: home" dispatcher action. A user's own menu order and the saved tab
-- index (C8).
describe("KoPanda's entry points", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local InfoMessage = require("ui/widget/infomessage")
    local LuaSettings = require("luasettings")
    local PluginLoader = require("pluginloader")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local Home
    local user_order_file = DataStorage:getSettingsDir() .. "/filemanager_menu_order.lua"

    local function homes_on_stack()
        local count = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_home" then
                count = count + 1
            end
        end
        return count
    end

    -- Shows the file manager with its home, then closes the home with a mid-screen tap.
    local function fm_without_home()
        local fm = harness.show_fm()
        harness.tick(2)
        local size = Screen:getSize()
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 2)))
        assert.equals(0, homes_on_stack())
        assert.equals(fm, harness.top())
        return fm
    end

    -- The file manager's tab count with KoPanda refused: KOReader's own tabs on this device.
    -- Leaves the plugin loaded afresh, not refused.
    local function baseline_tab_count()
        harness.teardown()
        harness.load()
        table.insert(PluginLoader.enabled_plugins, { name = "simpleui" })
        local fm = harness.show_fm()
        fm.menu:onShowMenu()
        local count = #fm.menu.tab_item_table
        harness.teardown()
        harness.load()
        Home = require("home")
        return count
    end

    local function find(list, id)
        for index, item in ipairs(list) do
            if item.id == id then
                return item, index
            end
        end
    end

    -- The items of tab 1 without text: what an orphan top-level item would add.
    local function textless_in_tab_one(tabs)
        local textless = {}
        for _, item in ipairs(tabs[1]) do
            if item.text == nil and item.text_func == nil then
                textless[#textless + 1] = tostring(item.id)
            end
        end
        return textless
    end

    local function count_in(list, id)
        local count = 0
        for _, value in ipairs(list) do
            if value == id then
                count = count + 1
            end
        end
        return count
    end

    -- Writes the user's own settings/filemanager_menu_order.lua with this KOMenu:menu_buttons.
    local function write_user_order(buttons)
        local quoted = {}
        for _, id in ipairs(buttons) do
            quoted[#quoted + 1] = string.format("%q", id)
        end
        local f = assert(io.open(user_order_file, "w"))
        f:write('return { ["KOMenu:menu_buttons"] = { ' .. table.concat(quoted, ", ") .. " } }\n")
        f:close()
    end

    -- KOReader's default tabs, without KoPanda's.
    local function default_buttons()
        local buttons = {}
        for _, id in ipairs(require("ui/elements/filemanager_menu_order")["KOMenu:menu_buttons"]) do
            if id ~= "kopanda_home" then
                buttons[#buttons + 1] = id
            end
        end
        return buttons
    end

    -- A user's own top-level list that places the Home tab third.
    local NAMES_HOME_THIRD = {
        "filemanager_settings", "setting", "kopanda_home", "tools", "search", "plus_menu", "main",
    }

    local function stored_state(key)
        return LuaSettings:open(harness.state_file):readSetting(key)
    end

    before_each(function()
        os.remove(user_order_file)
        G_reader_settings:delSetting("filemanagermenu_tab_index")
        harness.load()
        Home = require("home")
    end)

    after_each(function()
        harness.teardown()
        os.remove(user_order_file)
        G_reader_settings:delSetting("filemanagermenu_tab_index")
    end)

    describe("the Home tab", function()
        it("sits at index 2 with the home icon and is not remembered", function()
            local baseline = baseline_tab_count()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local tabs = fm.menu.tab_item_table
            assert.equals(baseline + 1, #tabs)
            assert.equals("kopanda_home", tabs[2].id)
            assert.equals("home", tabs[2].icon)
            assert.is_false(tabs[2].remember)
            assert.same({}, textless_in_tab_one(tabs))
        end)

        it("closes the menu and shows the home when tapped", function()
            local fm = fm_without_home()
            fm.menu:onShowMenu()
            local menu = fm.menu.menu_container
            assert.equals(menu, harness.top())
            menu[1]:switchMenuTab(2)
            harness.tick()
            assert.is_nil(fm.menu.menu_container)
            assert.is_false(UIManager:isWidgetShown(menu))
            assert.equals(1, homes_on_stack())
            assert.equals(Home.shown, harness.top())
            assert.equals(fm, harness.top(2))
        end)

        it("is in the cached order once after a second file manager", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            fm.menu:onCloseFileManagerMenu()
            fm:onClose()
            fm = harness.show_fm()
            fm.menu:onShowMenu()
            local buttons = require("ui/elements/filemanager_menu_order")["KOMenu:menu_buttons"]
            assert.equals(1, count_in(buttons, "kopanda_home"))
            assert.equals("kopanda_home", fm.menu.tab_item_table[2].id)
        end)
    end)

    describe("the Tools entry", function()
        local function kopanda_item(tabs)
            local tools = find(tabs, "tools")
            assert.is_table(tools)
            return find(tools, "kopanda")
        end

        it("is in the file manager's Tools with Home and Settings", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local item = kopanda_item(fm.menu.tab_item_table)
            assert.is_table(item)
            assert.equals("KoPanda", item.text)
            assert.equals(2, #item.sub_item_table)
            assert.equals("Home", item.sub_item_table[1].text)
            assert.equals("Settings", item.sub_item_table[2].text)
        end)

        it("shows the home from Home", function()
            local fm = fm_without_home()
            fm.menu:onShowMenu()
            kopanda_item(fm.menu.tab_item_table).sub_item_table[1].callback()
            harness.tick()
            assert.equals(1, homes_on_stack())
            assert.equals(Home.shown, harness.top())
        end)

        it("shows the settings stub from Settings", function()
            local fm = fm_without_home()
            fm.menu:onShowMenu()
            fm.menu:onCloseFileManagerMenu()
            kopanda_item(fm.menu.tab_item_table).sub_item_table[2].callback()
            harness.tick()
            assert.equals(InfoMessage, getmetatable(harness.top()))
        end)

        it("is in the reader's Tools", function()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            local item = kopanda_item(reader.menu.tab_item_table)
            assert.is_table(item)
            assert.equals("Home", item.sub_item_table[1].text)
            assert.equals("Settings", item.sub_item_table[2].text)
            assert.is_nil(find(reader.menu.tab_item_table, "kopanda_home"))
        end)
    end)

    describe("the KoPanda: home action", function()
        local Dispatcher = require("dispatcher")

        it("is registered with its title", function()
            harness.show_fm()
            assert.equals("KoPanda: home", Dispatcher:getNameFromItem("kopanda_home"))
        end)

        it("shows the home in the file manager", function()
            fm_without_home()
            Dispatcher:execute({ kopanda_home = true })
            harness.tick()
            assert.equals(1, homes_on_stack())
            assert.equals(Home.shown, harness.top())
        end)

        it("is consumed by a home already up", function()
            local fm = harness.show_fm()
            harness.tick(2)
            local home = Home.shown
            assert.is_true(home:handleEvent(Event:new("KoPandaHome")))
            local handler = spy.new(function() end)
            fm.kopanda.onKoPandaHome = handler
            Dispatcher:execute({ kopanda_home = true })
            harness.tick(2)
            assert.spy(handler).was_not_called()
            assert.equals(1, homes_on_stack())
            assert.equals(home, harness.top())
        end)

        it("closes the book and lands on the home in the reader", function()
            local reader = harness.open_reader()
            harness.tick()
            local on_home = spy.on(reader, "onHome")
            Dispatcher:execute({ kopanda_home = true })
            assert.spy(on_home).was_called(1)
            harness.tick(2)
            assert.is_not_nil(FileManager.instance)
            assert.equals(1, homes_on_stack())
            assert.equals(Home.shown, harness.top())
            assert.equals(FileManager.instance, harness.top(2))
        end)
    end)

    describe("a user's own menu order", function()
        it("gets no Home tab and no orphan when it leaves the tab out", function()
            local baseline = baseline_tab_count()
            write_user_order(default_buttons())
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local tabs = fm.menu.tab_item_table
            assert.equals(baseline, #tabs)
            assert.is_nil(find(tabs, "kopanda_home"))
            assert.same({}, textless_in_tab_one(tabs))
            assert.is_table(find(find(tabs, "tools"), "kopanda"))
        end)

        it("places the Home tab where it names it", function()
            write_user_order(NAMES_HOME_THIRD)
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local tabs = fm.menu.tab_item_table
            assert.equals("kopanda_home", tabs[3].id)
            assert.equals("home", tabs[3].icon)
            assert.same({}, textless_in_tab_one(tabs))
            assert.same({}, require("ui/elements/filemanager_menu_order").kopanda_home)
        end)
    end)

    describe("the saved tab index", function()
        it("moves up one, once per profile, when the tab is first inserted", function()
            G_reader_settings:saveSetting("filemanagermenu_tab_index", 3)
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.equals(4, G_reader_settings:readSetting("filemanagermenu_tab_index"))
            assert.equals(4, fm.menu.menu_container[1].last_index)
            assert.is_true(stored_state("menu_tab_shifted"))
            fm.menu:onCloseFileManagerMenu()
            fm:onClose()
            fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.equals(4, G_reader_settings:readSetting("filemanagermenu_tab_index"))
        end)

        it("leaves tab 1 alone and still sets the marker", function()
            G_reader_settings:saveSetting("filemanagermenu_tab_index", 1)
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.equals(1, G_reader_settings:readSetting("filemanagermenu_tab_index"))
            assert.is_true(stored_state("menu_tab_shifted"))
        end)

        it("is not moved for a user's own order", function()
            write_user_order(NAMES_HOME_THIRD)
            G_reader_settings:saveSetting("filemanagermenu_tab_index", 3)
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.equals(3, G_reader_settings:readSetting("filemanagermenu_tab_index"))
            assert.is_nil(stored_state("menu_tab_shifted"))
        end)

        it("is not moved when the marker can't be written", function()
            -- A plain file where settings/kopanda should be: the marker can't be stored, and a
            -- shift without it would repeat at every start.
            local f = assert(io.open(harness.state_dir, "w"))
            f:close()
            G_reader_settings:saveSetting("filemanagermenu_tab_index", 3)
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.equals(3, G_reader_settings:readSetting("filemanagermenu_tab_index"))
            assert.equals("kopanda_home", fm.menu.tab_item_table[2].id)
        end)
    end)
end)
