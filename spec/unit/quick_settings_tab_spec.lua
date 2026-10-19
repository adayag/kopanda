-- The quick-settings tab in KOReader's top menus (design: docs/plans/2026-10-18-menu-quick-
-- settings-design.md): just before Main in the file browser's and the reader's tab bar, opening
-- the sheet.
describe("the quick-settings tab", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local LuaSettings = require("luasettings")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local Sheet, QuickSettings, Home

    local function find(list, id)
        for index, item in ipairs(list) do
            if item.id == id then
                return item, index
            end
        end
    end

    local function last(list)
        return list[#list]
    end

    local function quick_settings_tab(tabs)
        return (assert(find(tabs, "kopanda_quick_settings"), "no quick-settings tab"))
    end

    -- Asserts the tab sits just before Main, the far-right tab.
    local function assert_before_main(tabs)
        local _, index = find(tabs, "kopanda_quick_settings")
        assert.equals(#tabs - 1, index)
        assert.equals("main", last(tabs).id)
    end

    -- Opens the menu as a swipe starting in the right third of the screen does
    -- (readermenu.lua:466-482, filemanagermenu.lua:1083-1100) and returns the open TouchMenu.
    local function swipe_right_third(menu)
        local index = menu:_getTabIndexFromLocation(harness.gesture("swipe", Screen:getWidth() - 5, 5))
        menu:onShowMenu(index)
        return menu.menu_container[1]
    end

    -- The ids of tab 1's items without text: what an orphan top-level item would add.
    local function textless_in_tab_one(tabs)
        local textless = {}
        for _, item in ipairs(tabs[1]) do
            if item.text == nil and item.text_func == nil then
                textless[#textless + 1] = tostring(item.id)
            end
        end
        return textless
    end

    local function user_order_file(menu)
        return DataStorage:getSettingsDir() .. "/" .. menu .. "_menu_order.lua"
    end

    -- Writes the user's own settings/<menu>_menu_order.lua with this KOMenu:menu_buttons.
    local function write_user_order(menu, buttons)
        local quoted = {}
        for _, id in ipairs(buttons) do
            quoted[#quoted + 1] = string.format("%q", id)
        end
        local path = user_order_file(menu)
        local f = assert(io.open(path, "w"))
        f:write('return { ["KOMenu:menu_buttons"] = { ' .. table.concat(quoted, ", ") .. " } }\n")
        f:close()
        return path
    end

    local function read(path)
        local f = assert(io.open(path, "r"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function stored_state(key)
        return LuaSettings:open(harness.state_file):readSetting(key)
    end

    local function forget_menus()
        os.remove(user_order_file("filemanager"))
        os.remove(user_order_file("reader"))
        G_reader_settings:delSetting("filemanagermenu_tab_index")
    end

    before_each(function()
        forget_menus()
        harness.load()
        Sheet = require("sheet")
        QuickSettings = require("quick_settings")
        Home = require("home")
    end)

    after_each(function()
        harness.teardown()
        forget_menus()
    end)

    describe("placement", function()
        it("is just before Main in the file browser's menu, the Home tab still second", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local tabs = fm.menu.tab_item_table
            assert_before_main(tabs)
            local tab = quick_settings_tab(tabs)
            assert.equals("appbar.contrast", tab.icon)
            assert.is_false(tab.remember)
            assert.equals("kopanda_home", tabs[2].id)
            assert.same({}, require("ui/elements/filemanager_menu_order").kopanda_quick_settings)
            local buttons = require("ui/elements/filemanager_menu_order")["KOMenu:menu_buttons"]
            assert.equals("kopanda_quick_settings", buttons[#buttons - 1])
            assert.equals("main", last(buttons))
        end)

        it("is just before Main in the reader's menu, with no Home tab", function()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            local tabs = reader.menu.tab_item_table
            assert_before_main(tabs)
            local tab = quick_settings_tab(tabs)
            assert.equals("appbar.contrast", tab.icon)
            assert.is_false(tab.remember)
            assert.is_nil(find(tabs, "kopanda_home"))
            local order = require("ui/elements/reader_menu_order")
            assert.same({}, order.kopanda_quick_settings)
            local buttons = order["KOMenu:menu_buttons"]
            assert.equals("kopanda_quick_settings", buttons[#buttons - 1])
            assert.equals("main", last(buttons))
        end)

        it("is appended to an order without Main", function()
            local buttons = require("ui/elements/filemanager_menu_order")["KOMenu:menu_buttons"]
            for index = #buttons, 1, -1 do
                if buttons[index] == "main" then
                    table.remove(buttons, index)
                end
            end
            local count = #buttons
            assert.is_true(require("menu_entries").tab("filemanager_quick_settings"))
            assert.equals(count + 1, #buttons)
            assert.equals("kopanda_quick_settings", last(buttons))
        end)

        it("leaves the file browser's right-third swipe on Main", function()
            local fm = harness.show_fm()
            harness.tick(2)
            local menu = swipe_right_third(fm.menu)
            local tabs = fm.menu.tab_item_table
            assert.equals(#tabs, menu.cur_tab)
            assert.equals("main", tabs[menu.cur_tab].id)
            assert.is_nil(Sheet.shown)
        end)

        it("leaves the reader's right-third swipe on Main", function()
            local reader = harness.open_reader()
            local menu = swipe_right_third(reader.menu)
            local tabs = reader.menu.tab_item_table
            assert.equals(#tabs, menu.cur_tab)
            assert.equals("main", tabs[menu.cur_tab].id)
            assert.is_nil(Sheet.shown)
        end)

        it("is inserted once across menu builds", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            fm.menu:onCloseFileManagerMenu()
            fm:onClose()
            fm = harness.show_fm()
            fm.menu:onShowMenu()
            local buttons = require("ui/elements/filemanager_menu_order")["KOMenu:menu_buttons"]
            local count = 0
            for _, id in ipairs(buttons) do
                if id == "kopanda_quick_settings" then
                    count = count + 1
                end
            end
            assert.equals(1, count)
            assert_before_main(fm.menu.tab_item_table)
        end)
    end)

    describe("the tap", function()
        local function sheets_on_stack()
            local count = 0
            for _, widget in ipairs(harness.stack()) do
                if widget.name == "kopanda_sheet" then
                    count = count + 1
                end
            end
            return count
        end

        it("closes the file browser's menu and opens the sheet over the home", function()
            local fm = harness.show_fm()
            harness.tick(2)
            local home = Home.shown
            assert.is_table(home)
            fm.menu:onShowMenu()
            quick_settings_tab(fm.menu.tab_item_table).callback()
            harness.tick(3)
            assert.is_nil(fm.menu.menu_container)
            local sheet = Sheet.shown
            assert.is_table(sheet)
            assert.equals("quick_settings", sheet.spec.name)
            assert.equals(sheet, harness.top())
            assert.equals(home, harness.top(2))
            assert.equals(1, sheets_on_stack())
        end)

        it("closes the reader's menu and opens the sheet over the page", function()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            quick_settings_tab(reader.menu.tab_item_table).callback()
            harness.tick(3)
            assert.is_nil(reader.menu.menu_container)
            local sheet = Sheet.shown
            assert.is_table(sheet)
            assert.equals("quick_settings", sheet.spec.name)
            assert.equals(sheet, harness.top())
            assert.equals(reader, harness.top(2))
            assert.equals(1, sheets_on_stack())
            assert.is_nil(Home.shown)
        end)

        it("closes the reader's menu and its bottom config menu through the tab bar", function()
            local reader = harness.open_reader()
            reader:handleEvent(Event:new("ShowConfigMenu"))
            assert.is_table(reader.config.config_dialog)
            reader.menu:onShowMenu()
            local _, index = find(reader.menu.tab_item_table, "kopanda_quick_settings")
            reader.menu.menu_container[1].bar.icon_widgets[index].callback()
            harness.tick(3)
            local sheet = Sheet.shown
            assert.is_table(sheet)
            assert.equals(sheet, harness.top())
            assert.is_nil(reader.menu.menu_container)
            assert.is_nil(reader.config.config_dialog)
            assert.equals(1, sheets_on_stack())
        end)

        it("is not reopened by the reader's next menu after a tap through the tab bar", function()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            local _, index = find(reader.menu.tab_item_table, "kopanda_quick_settings")
            reader.menu.menu_container[1].bar.icon_widgets[index].callback()
            harness.tick(3)
            Sheet.close()
            harness.tick(2)
            assert.is_nil(Sheet.shown)
            reader.menu:onShowMenu()
            harness.tick(3)
            assert.is_nil(Sheet.shown)
            assert.equals(reader.menu.menu_container, harness.top())
            assert.is_not.equals(index, reader.menu.menu_container[1].cur_tab)
        end)

        it("leaves the page when the sheet fails in the reader", function()
            local reader = harness.open_reader()
            local original = QuickSettings.body
            QuickSettings.body = function() error("boom") end
            finally(function() QuickSettings.body = original end)
            local home_close = spy.on(Home, "close")
            finally(function() Home.close:revert() end)
            reader.menu:onShowMenu()
            quick_settings_tab(reader.menu.tab_item_table).callback()
            harness.tick(3)
            assert.spy(home_close).was_not_called()
            assert.is_nil(Sheet.shown)
            assert.equals(0, sheets_on_stack())
            assert.equals(reader, harness.top())
            assert.is_true(UIManager:isWidgetShown(reader))
        end)

        it("logs and leaves the menu usable when the opener raises", function()
            local reader = harness.open_reader()
            local logger = require("logger")
            local errors = {}
            local original = logger.err
            logger.err = function(...)
                local parts = {}
                for i = 1, select("#", ...) do
                    parts[i] = tostring((select(i, ...)))
                end
                errors[#errors + 1] = table.concat(parts, " ")
            end
            finally(function() logger.err = original end)
            local open = QuickSettings.open
            QuickSettings.open = function() error("no sheet") end
            finally(function() QuickSettings.open = open end)
            reader.menu:onShowMenu()
            quick_settings_tab(reader.menu.tab_item_table).callback()
            harness.tick(3)
            assert.equals(0, sheets_on_stack())
            assert.equals(reader, harness.top())
            assert.equals(1, #errors)
            assert.truthy(errors[1]:find("KoPanda: the Quick settings tab failed:", 1, true))
            assert.truthy(errors[1]:find("no sheet", 1, true))
            reader.menu:onShowMenu()
            assert.is_table(reader.menu.menu_container)
            assert.equals(reader.menu.menu_container, harness.top())
        end)
    end)

    describe("a user's own menu order", function()
        it("gets no tab in the reader when it leaves the tab out, and is left alone", function()
            local path = write_user_order("reader", {
                "navi", "typeset", "setting", "tools", "search", "filemanager", "main",
            })
            local before = read(path)
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            assert.is_nil(find(reader.menu.tab_item_table, "kopanda_quick_settings"))
            assert.equals("main", last(reader.menu.tab_item_table).id)
            assert.same({}, textless_in_tab_one(reader.menu.tab_item_table))
            assert.equals(before, read(path))
        end)

        it("places the tab where the user's reader file names it", function()
            write_user_order("reader", {
                "navi", "kopanda_quick_settings", "typeset", "setting", "tools", "search", "filemanager", "main",
            })
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            local tab = reader.menu.tab_item_table[2]
            assert.equals("kopanda_quick_settings", tab.id)
            assert.equals("appbar.contrast", tab.icon)
        end)

        it("gets no tab in the file browser when it leaves the tab out", function()
            write_user_order("filemanager", {
                "filemanager_settings", "kopanda_home", "setting", "tools", "search", "plus_menu", "main",
            })
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.is_nil(find(fm.menu.tab_item_table, "kopanda_quick_settings"))
            assert.equals("kopanda_home", fm.menu.tab_item_table[2].id)
            assert.same({}, textless_in_tab_one(fm.menu.tab_item_table))
        end)

        it("keeps the user's list as written when it names Main elsewhere", function()
            write_user_order("reader", {
                "main", "navi", "typeset", "setting", "tools", "search", "filemanager", "kopanda_quick_settings",
            })
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            local tabs = reader.menu.tab_item_table
            assert.equals("main", tabs[1].id)
            assert.equals("kopanda_quick_settings", last(tabs).id)
        end)
    end)

    describe("the saved tab index", function()
        it("is not moved by the file browser's tab", function()
            G_reader_settings:saveSetting("filemanagermenu_tab_index", 5)
            assert.is_true(require("menu_entries").tab("filemanager_quick_settings"))
            assert.equals(5, G_reader_settings:readSetting("filemanagermenu_tab_index"))
            assert.is_nil(stored_state("menu_tab_shifted"))
        end)

        it("moves only for the Home tab when the file browser's menu is built", function()
            G_reader_settings:saveSetting("filemanagermenu_tab_index", 5)
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.equals(6, G_reader_settings:readSetting("filemanagermenu_tab_index"))
        end)

        it("is not moved by the reader's tab", function()
            local reader = harness.open_reader()
            reader.menu.last_tab_index = 3
            reader.menu:onShowMenu()
            reader.menu:onCloseReaderMenu()
            assert.equals(3, reader.doc_settings:readSetting("readermenu_tab_index"))
        end)
    end)

    describe("a failed insert", function()
        it("returns false and logs once for an unknown tab, leaving Tools › KoPanda", function()
            local logger = require("logger")
            local errors = {}
            local original = logger.err
            logger.err = function(...)
                local parts = {}
                for i = 1, select("#", ...) do
                    parts[i] = tostring((select(i, ...)))
                end
                errors[#errors + 1] = table.concat(parts, " ")
            end
            finally(function() logger.err = original end)
            assert.is_false(require("menu_entries").tab("nope"))
            assert.equals(1, #errors)
            assert.truthy(errors[1]:find("KoPanda: could not add a menu tab:", 1, true))
            assert.truthy(errors[1]:find("nope", 1, true))
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local tools = assert(find(fm.menu.tab_item_table, "tools"))
            assert.is_table(find(tools, "kopanda"))
        end)

        it("costs only the tab, logged, and leaves the Home tab and a clean tab 1", function()
            local logger = require("logger")
            local errors = {}
            local original = logger.err
            logger.err = function(...)
                errors[#errors + 1] = tostring((...))
            end
            finally(function() logger.err = original end)
            local order = require("ui/elements/filemanager_menu_order")
            finally(function() setmetatable(order, nil) end)
            setmetatable(order, {
                __newindex = function(t, key, value)
                    if key == "kopanda_quick_settings" then
                        error("kopanda-test: insert failed")
                    end
                    rawset(t, key, value)
                end,
            })
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local tabs = fm.menu.tab_item_table
            assert.is_nil(find(tabs, "kopanda_quick_settings"))
            assert.equals("kopanda_home", tabs[2].id)
            assert.equals("main", last(tabs).id)
            assert.same({}, textless_in_tab_one(tabs))
            assert.truthy(table.concat(errors, "\n"):find("KoPanda: could not add the Quick settings tab:", 1, true))
        end)
    end)
end)
