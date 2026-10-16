-- Every hook fails safe: an error is logged, no home is left on the stack, and the file
-- manager is on top and handling input.
describe("KoPanda failing safe", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Home, logged, settled_listener
    local original_paint = InputContainer.paintTo

    local function homes_on_stack()
        local count = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_home" then
                count = count + 1
            end
        end
        return count
    end

    -- True when an error line logged through logger.err mentions text.
    local function logged_error(text)
        for _, call in ipairs(logged.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    -- The file manager is on top and still takes input: a tap in KOReader's top menu zone
    -- opens its menu (filemanagermenu.lua:72-90), which is then closed again.
    local function file_manager_usable()
        local fm = FileManager.instance
        assert.equals(fm, harness.top())
        assert.equals(0, homes_on_stack())
        assert.is_nil(Home.shown)
        local size = Screen:getSize()
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 16)))
        assert.is_not_nil(fm.menu.menu_container)
        assert.equals(fm.menu.menu_container, harness.top())
        fm.menu:onCloseFileManagerMenu()
        assert.equals(fm, harness.top())
    end

    before_each(function()
        harness.load()
        Home = require("home")
        logged = spy.on(logger, "err")
    end)

    after_each(function()
        if settled_listener then
            UIManager.event_hook:unregister("KoPandaSettled", settled_listener)
            settled_listener = nil
        end
        InputContainer.paintTo = original_paint
        logger.err:revert()
        harness.teardown()
    end)

    it("leaves the file manager on top when the home's build throws", function()
        Home.init = function()
            error("kopanda-test: build failed")
        end
        harness.show_fm()
        harness.tick(2)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: build failed"))
    end)

    it("takes the home off the stack when its show throws after it reached the stack", function()
        -- UIManager:show puts the widget on the stack, then sends it Show (uimanager.lua:259).
        Home.onShow = function()
            error("kopanda-test: show failed")
        end
        harness.show_fm()
        harness.tick(2)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: show failed"))
    end)

    it("closes the home when its paint throws", function()
        InputContainer.paintTo = function(self, ...)
            if self.name == "kopanda_home" then
                error("kopanda-test: paint failed")
            end
            return original_paint(self, ...)
        end
        harness.show_fm()
        harness.tick(3)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: paint failed"))
    end)

    -- The file browser it closes onto sends its own, with screen "file_browser" (fm_nav.lua).
    it("sends no settled signal when the home's paint throws", function()
        local settled = 0
        settled_listener = function(payload)
            if payload.screen == "home" then
                settled = settled + 1
            end
        end
        UIManager.event_hook:register("KoPandaSettled", settled_listener)
        InputContainer.paintTo = function(self, ...)
            if self.name == "kopanda_home" then
                error("kopanda-test: paint failed")
            end
            return original_paint(self, ...)
        end
        harness.show_fm()
        harness.tick(4)
        file_manager_usable()
        assert.equals(0, settled)
    end)

    it("lets a book close finish and builds afresh at show when the pre-build throws", function()
        local builds = 0
        Home.init = function()
            builds = builds + 1
            error("kopanda-test: build failed")
        end
        local reader = harness.open_reader()
        harness.tick(2)
        local ok = pcall(reader.onClose, reader)
        assert.is_true(ok)
        assert.is_nil(reader.document)
        assert.is_false(UIManager:isWidgetShown(reader))
        assert.equals(1, builds)
        assert.is_nil(Home.pending)
        assert.is_true(logged_error("kopanda-test: build failed"))
        assert.is_true(logged_error("could not pre-build the home"))
        logged:clear()
        harness.show_fm()
        harness.tick(2)
        assert.equals(2, builds)
        assert.is_true(logged_error("kopanda-test: build failed"))
        file_manager_usable()
    end)

    it("closes the home and logs when its rebuild on Resume throws", function()
        harness.show_fm()
        harness.tick(2)
        Home.build = function()
            error("kopanda-test: rebuild failed")
        end
        local ok = pcall(UIManager.broadcastEvent, UIManager, Event:new("Resume"))
        assert.is_true(ok)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: rebuild failed"))
    end)

    -- The rebuild a variant change brings runs inside the paint (night mode's C10).
    it("closes the home on the next tick when its rebuild for night mode throws in the paint", function()
        local had = G_reader_settings:has("color_rendering")
        local previous = G_reader_settings:readSetting("color_rendering")
        local night_mode = rawget(Screen, "night_mode")
        finally(function()
            Screen.night_mode = night_mode
            if had then
                G_reader_settings:saveSetting("color_rendering", previous)
            else
                G_reader_settings:delSetting("color_rendering")
            end
        end)
        G_reader_settings:saveSetting("color_rendering", true)
        Screen.night_mode = false
        harness.show_fm()
        harness.tick(2)
        local home = Home.shown
        assert.equals(home, harness.top())
        Home.build = function()
            error("kopanda-test: night rebuild failed")
        end
        Screen.night_mode = true
        UIManager:setDirty("all", "full")
        local ok = pcall(harness.tick, 1)
        assert.is_true(ok)
        assert.is_true(home.paint_failed)
        assert.is_true(logged_error("kopanda-test: night rebuild failed"))
        harness.tick(2)
        file_manager_usable()
    end)

    it("consumes a gesture and closes the home when the gesture body throws", function()
        harness.show_fm()
        harness.tick(2)
        local home = Home.shown
        Home.routeGesture = function()
            error("kopanda-test: gesture failed")
        end
        local size = Screen:getSize()
        local ok, consumed = pcall(home.handleEvent, home,
            Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 2)))
        assert.is_true(ok)
        assert.is_true(consumed)
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: gesture failed"))
    end)

    it("closes the home onto the file browser, with no sheet, when a widget's hold throws", function()
        local Geom = require("ui/geometry")
        local Widget = require("ui/widget/widget")
        local quote = {
            id = "quote",
            height = function()
                return 60
            end,
            build = function(width)
                return Widget:new{ dimen = Geom:new{ w = width, h = 60 } }
            end,
            hold = function()
                error("kopanda-test: hold failed")
            end,
        }
        package.loaded["widgets"].get = function(id)
            return id == "quote" and quote or nil
        end
        harness.show_fm()
        harness.tick(2)
        local rect
        for _, slot in ipairs(Home.shown.slots) do
            if slot.widget == "quote" then
                rect = slot.rect
            end
        end
        local ok = pcall(UIManager.sendEvent, UIManager, Event:new("Gesture",
            harness.gesture("hold", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))))
        assert.is_true(ok)
        for _, widget in ipairs(harness.stack()) do
            assert.is_not.equals("kopanda_sheet", widget.name)
        end
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: hold failed"))
    end)

    describe("a sheet", function()
        local Geom = require("ui/geometry")
        local Sheet

        local function sheets_on_stack()
            local count = 0
            for _, widget in ipairs(harness.stack()) do
                if widget.name == "kopanda_sheet" then
                    count = count + 1
                end
            end
            return count
        end

        -- A one-row sheet over a shown home, its header a book's whose cover is given.
        local function show(row, cover)
            harness.show_fm()
            harness.tick(2)
            assert.equals(Home.shown, harness.top())
            Sheet = require("sheet")
            Sheet.show({
                name = "test",
                band = "book",
                header = cover and { cover = cover, title = "A book" } or { heading = "Test" },
                rows = { row or { icon = "info", label = "Row", run = function() end } },
            }, Home.shown.ctx)
        end

        local function no_sheet()
            assert.equals(0, sheets_on_stack())
            assert.is_nil(Sheet.shown)
        end

        it("closes itself and the home when a row's action throws", function()
            show({ icon = "info", label = "Row", run = function() error("kopanda-test: row failed") end })
            local rect = Sheet.shown.rows[1].rect
            local ok = pcall(UIManager.sendEvent, UIManager, Event:new("Gesture",
                harness.gesture("tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))))
            assert.is_true(ok)
            no_sheet()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: row failed"))
        end)

        it("leaves the file manager on top when its build throws in the show", function()
            show(nil, setmetatable({}, { __index = function() error("kopanda-test: sheet build failed") end }))
            no_sheet()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: sheet build failed"))
        end)

        it("closes itself and the home from the next tick when its paint throws", function()
            show(nil, {
                getSize = function() return Geom:new{ w = 20, h = 30 } end,
                paintTo = function() error("kopanda-test: sheet paint failed") end,
                free = function() end,
            })
            assert.equals(Sheet.shown, harness.top())
            local ok = pcall(harness.tick, 3)
            assert.is_true(ok)
            no_sheet()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: sheet paint failed"))
        end)
    end)

    it("logs, shows no action list and adds nothing when the entry picker's action tree throws", function()
        local Dispatcher = require("dispatcher")
        local TouchMenu = require("ui/widget/touchmenu")
        local add = stub(Dispatcher, "addSubMenu", function()
            error("kopanda-test: action tree failed")
        end)
        finally(function()
            add:revert()
        end)
        harness.show_fm()
        harness.tick(2)
        Home.close()
        local added = spy.new(function() end)
        require("entry_picker").pick("action", nil, added)
        for _, widget in ipairs(harness.stack()) do
            assert.is_not.equals(TouchMenu, getmetatable(widget[1]))
        end
        assert.spy(added).was_not.called()
        file_manager_usable()
        assert.is_true(logged_error("kopanda-test: action tree failed"))
    end)

    describe("an editor screen", function()
        local Editor

        local function editors_on_stack()
            local count = 0
            for _, widget in ipairs(harness.stack()) do
                if widget.name == "kopanda_editor" then
                    count = count + 1
                end
            end
            return count
        end

        -- An editor of one card over the file manager, the home closed; card may change the card.
        local function show(card)
            harness.show_fm()
            harness.tick(2)
            Home.close()
            assert.equals(FileManager.instance, harness.top())
            Editor = require("editor")
            Editor.show({
                screen = "edit_layout",
                aside = "Home",
                title = "Edit layout",
                body = function(_, width)
                    local control = { kind = "card", rect = { x = 0, y = 0, w = width, h = 100 },
                        draw = function() end, run = function() end }
                    if card then
                        card(control)
                    end
                    return { { control } }
                end,
                foot = function()
                    return {}
                end,
            })
        end

        local function no_editor()
            assert.equals(0, editors_on_stack())
            assert.is_nil(Editor.shown)
        end

        it("leaves the file manager on top when its body throws in the show", function()
            show(function()
                error("kopanda-test: editor build failed")
            end)
            no_editor()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: editor build failed"))
        end)

        it("closes itself from the next tick when its paint throws", function()
            show(function(control)
                control.draw = function()
                    error("kopanda-test: editor paint failed")
                end
            end)
            assert.equals(Editor.shown, harness.top())
            local ok = pcall(harness.tick, 3)
            assert.is_true(ok)
            no_editor()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: editor paint failed"))
        end)

        it("logs and leaves no editor when edit layout's read of the settings throws", function()
            harness.show_fm()
            harness.tick(2)
            Editor = require("editor")
            local Settings = require("settings")
            local get = Settings.get
            Settings.get = function(key)
                if key == "layout.rows" then
                    error("kopanda-test: layout read failed")
                end
                return get(key)
            end
            local ok = pcall(require("edit_layout").open)
            Settings.get = get
            assert.is_true(ok)
            no_editor()
            assert.is_true(logged_error("kopanda-test: layout read failed"))
            Home.close()
            file_manager_usable()
        end)

        it("closes itself when a control's run throws", function()
            show(function(control)
                control.run = function()
                    error("kopanda-test: editor run failed")
                end
            end)
            local place = Editor.shown.places[2]
            local rect = place.rect
            local ok = pcall(UIManager.sendEvent, UIManager, Event:new("Gesture",
                harness.gesture("tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))))
            assert.is_true(ok)
            no_editor()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: editor run failed"))
        end)
    end)

    describe("launcher management", function()
        local Editor, LauncherManage

        -- The file manager on top, its home closed, and launcher management's modules loaded.
        local function over_fm()
            harness.show_fm()
            harness.tick(2)
            Home.close()
            assert.equals(FileManager.instance, harness.top())
            Editor = require("editor")
            LauncherManage = require("launcher_manage")
        end

        it("draws every row as unavailable and logs when resolving each entry throws", function()
            over_fm()
            local LauncherEntries = require("launcher_entries")
            local available = stub(LauncherEntries, "available", function()
                error("kopanda-test: resolve failed")
            end)
            finally(function()
                available:revert()
            end)
            LauncherManage.open{}
            local editor = Editor.shown
            assert.is_not_nil(editor)
            assert.equals(editor, harness.top())
            local rows = 0
            for _, place in ipairs(editor.places) do
                if place.control.name == "entry" then
                    rows = rows + 1
                    assert.is_true(place.control.muted)
                end
            end
            assert.truthy(rows > 0)
            local ok = pcall(harness.tick, 3)
            assert.is_true(ok)
            assert.equals(editor, Editor.shown)
            assert.is_true(logged_error("kopanda-test: resolve failed"))
            Editor.close()
            file_manager_usable()
        end)

        it("leaves no editor and logs when reading the launcher throws in open", function()
            over_fm()
            local Settings = require("settings")
            local get = stub(Settings, "get", function()
                error("kopanda-test: launcher read failed")
            end)
            finally(function()
                get:revert()
            end)
            LauncherManage.open{}
            get:revert()
            assert.is_nil(Editor.shown)
            for _, widget in ipairs(harness.stack()) do
                assert.is_not.equals("kopanda_editor", widget.name)
            end
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: launcher read failed"))
        end)
    end)

    describe("the dispatcher wrapper", function()
        local Dispatcher = require("dispatcher")

        it("re-raises an action's error and leaves the file manager's flag as it was", function()
            local fm = harness.show_fm()
            harness.tick(2)
            assert.equals(Home.shown, harness.top())
            local failure = { "kopanda-test: action failed" }
            fm.history.onShowHist = function()
                error(failure)
            end
            local ok, err = pcall(Dispatcher.execute, Dispatcher, { history = true })
            assert.is_false(ok)
            assert.equals(failure, err)
            assert.is_nil(fm.is_always_active)
        end)

        it("closes the home when a forwarded gesture's action throws", function()
            local fm = harness.show_fm()
            harness.tick(2)
            fm.history.onShowHist = function()
                error("kopanda-test: forwarded action failed")
            end
            fm:registerTouchZones{ {
                id = "kopanda_test_corner",
                ges = "tap",
                screen_zone = { ratio_x = 7 / 8, ratio_y = 7 / 8, ratio_w = 1 / 8, ratio_h = 1 / 8 },
                handler = function()
                    Dispatcher:execute({ history = true })
                    return true
                end,
            } }
            local size = Screen:getSize()
            local ok = pcall(UIManager.sendEvent, UIManager,
                Event:new("Gesture", harness.gesture("tap", size.w - 10, size.h - 10)))
            assert.is_true(ok)
            assert.is_nil(fm.is_always_active)
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: forwarded action failed"))
        end)

        it("runs the action unbridged and logs when its own lookup throws", function()
            harness.show_fm()
            harness.tick(2)
            local sent = spy.on(UIManager, "sendEvent")
            local loaded = package.loaded["apps/filemanager/filemanager"]
            package.loaded["apps/filemanager/filemanager"] = setmetatable({}, {
                __index = function()
                    error("kopanda-test: lookup failed")
                end,
            })
            local ok = pcall(Dispatcher.execute, Dispatcher, { history = true })
            package.loaded["apps/filemanager/filemanager"] = loaded
            UIManager.sendEvent:revert()
            assert.is_true(ok)
            assert.spy(sent).was.called()
            assert.equals("onShowHist", sent.calls[1].vals[2].handler)
            assert.is_nil(FileManager.instance.is_always_active)
            assert.is_true(logged_error("kopanda-test: lookup failed"))
        end)
    end)

    -- fm_nav.lua's wrapper of FileManager.setupLayout and its frame.
    describe("the file browser's nav bar", function()
        local Blitbuffer = require("ffi/blitbuffer")
        local FileChooser = require("ui/widget/filechooser")

        -- A file manager with its home closed.
        local function file_manager()
            local fm = harness.show_fm()
            harness.tick(2)
            Home.close()
            harness.tick()
            return fm
        end

        it("leaves the file manager usable when the band raises", function()
            package.loaded["nav_bar"].height = function()
                error("kopanda-test: band failed")
            end
            file_manager()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: band failed"))
        end)

        it("re-raises setupLayout's own error with FileChooser's height put back", function()
            local real = FileManager.setupLayout
            local failing = false
            FileManager.setupLayout = function(...)
                if failing then
                    error("kopanda-test: setupLayout failed")
                end
                return real(...)
            end
            local fm = file_manager()
            failing = true
            local ok, err = pcall(fm.reinit, fm)
            failing = false
            assert.is_false(ok)
            assert.truthy(tostring(err):find("kopanda-test: setupLayout failed", 1, true))
            assert.is_nil(rawget(FileChooser, "height"))
            file_manager_usable()
        end)

        it("leaves the file manager usable when the frame's build raises", function()
            package.loaded["nav_bar"].new = function()
                error("kopanda-test: bar failed")
            end
            file_manager()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: bar failed"))
        end)

        it("leaves the file manager usable when the bar's paint raises", function()
            local fm = file_manager()
            fm[1].bar.paintTo = function()
                error("kopanda-test: bar paint failed")
            end
            local size = Screen:getSize()
            local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
            fm:paintTo(bb, 0, 0)
            bb:free()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: bar paint failed"))
        end)

        it("leaves the file manager usable when a tab's run raises", function()
            local fm = file_manager()
            package.loaded["launcher_entries"].run = function()
                error("kopanda-test: tab failed")
            end
            local bar = fm[1].bar
            local column = bar.columns[5]
            local ok = pcall(UIManager.sendEvent, UIManager, Event:new("Gesture", harness.gesture("tap",
                bar.padding_x + column.x + column.w / 2, bar.dimen.y + bar.dimen.h / 2)))
            assert.is_true(ok)
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: tab failed"))
        end)

        it("leaves the file manager usable when a relayout's reinit raises", function()
            local fm = file_manager()
            fm.reinit = function()
                error("kopanda-test: reinit failed")
            end
            package.loaded["fm_nav"].relayout()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: reinit failed"))
        end)
    end)

    it("shows the home and logs when the state file can't be written", function()
        -- A plain file where settings/kopanda should be: the directory can't be made.
        local f = assert(io.open(harness.state_dir, "w"))
        f:close()
        harness.show_fm()
        harness.tick(2)
        assert.equals(1, homes_on_stack())
        assert.equals(Home.shown, harness.top())
        assert.is_true(logged_error("KoPanda: could not write the state file"))
    end)

    it("shows the home and logs when the state folder is read-only", function()
        -- The folder exists but can't take a file: LuaSettings:flush drops the write's error
        -- (frontend/luasettings.lua:270-275), so only a read-back can tell.
        local lfs = require("libs/libkoreader-lfs")
        lfs.mkdir(harness.state_dir)
        finally(function()
            os.execute("chmod 755 '" .. harness.state_dir .. "'")
        end)
        assert.is_true(os.execute("chmod 555 '" .. harness.state_dir .. "'") == 0)
        harness.show_fm()
        harness.tick(2)
        assert.equals(1, homes_on_stack())
        assert.equals(Home.shown, harness.top())
        assert.is_true(logged_error("KoPanda: could not write the state file"))
    end)

    it("shows the home when the boot flag is set but can't be cleared", function()
        -- A flag left by a home that never drew, in a file that can't be rewritten: skipping
        -- would repeat on every start, so the home shows, unguarded.
        local lfs = require("libs/libkoreader-lfs")
        lfs.mkdir(harness.state_dir)
        require("luasettings"):open(harness.state_file):saveSetting("boot_pending", true):flush()
        local long_ago = os.time() - 3600
        assert.truthy(lfs.touch(harness.state_file, long_ago, long_ago))
        finally(function()
            os.execute("chmod 755 '" .. harness.state_dir .. "'")
            os.execute("chmod 644 '" .. harness.state_file .. "'")
        end)
        assert.is_true(os.execute("chmod 444 '" .. harness.state_file .. "'") == 0)
        assert.is_true(os.execute("chmod 555 '" .. harness.state_dir .. "'") == 0)
        harness.show_fm()
        harness.tick(2)
        assert.equals(1, homes_on_stack())
        assert.equals(Home.shown, harness.top())
        assert.is_true(logged_error("KoPanda: could not write the state file"))
    end)

    it("reads a corrupt state file as no flag and shows the home", function()
        require("libs/libkoreader-lfs").mkdir(harness.state_dir)
        local f = assert(io.open(harness.state_file, "w"))
        f:write("this is not lua")
        f:close()
        harness.show_fm()
        harness.tick(2)
        assert.equals(1, homes_on_stack())
        assert.is_false(require("luasettings"):open(harness.state_file):readSetting("boot_pending"))
    end)

    describe("the menu entries", function()
        local PluginLoader = require("pluginloader")

        -- The file manager's tab count with KoPanda refused, the plugin then loaded afresh.
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

        -- Closes the home with a mid-screen tap, outside every tappable slot, and opens the file
        -- manager's menu.
        local function menu_without_home()
            local fm = harness.show_fm()
            harness.tick(2)
            local size = Screen:getSize()
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 2)))
            fm.menu:onShowMenu()
            return fm
        end

        it("leaves KOReader's tabs and a clean tab 1 when the order insert throws", function()
            local baseline = baseline_tab_count()
            local order = require("ui/elements/filemanager_menu_order")
            finally(function()
                setmetatable(order, nil)
            end)
            setmetatable(order, {
                __newindex = function(t, key, value)
                    if key == "kopanda_home" then
                        error("kopanda-test: insert failed")
                    end
                    rawset(t, key, value)
                end,
            })
            local fm = harness.show_fm()
            harness.tick(2)
            fm.menu:onShowMenu()
            local tabs = fm.menu.tab_item_table
            assert.equals(baseline, #tabs)
            for _, tab in ipairs(tabs) do
                assert.is_not.equals("kopanda_home", tab.id)
            end
            for _, item in ipairs(tabs[1]) do
                assert.is_not.equals("kopanda_home", item.id)
                assert.truthy(item.text or item.text_func)
            end
            -- The failure costs only the tab: the rest of KoPanda's menu entries are there.
            local kopanda
            for _, tab in ipairs(tabs) do
                for _, item in ipairs(tab) do
                    if item.id == "kopanda" then
                        kopanda = item
                    end
                end
            end
            assert.is_table(kopanda)
            fm.menu:onCloseFileManagerMenu()
            Home.close()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: insert failed"))
        end)

        it("closes the menu and leaves the file manager on top when the Home tab throws", function()
            local KoPanda = PluginLoader.enabled_plugins[1]
            KoPanda.goHome = function()
                error("kopanda-test: home tab failed")
            end
            local fm = menu_without_home()
            local menu = fm.menu.menu_container[1]
            local index
            for i, tab in ipairs(menu.tab_item_table) do
                if tab.id == "kopanda_home" then
                    index = i
                end
            end
            assert.is_number(index)
            menu:switchMenuTab(index)
            harness.tick()
            assert.is_nil(fm.menu.menu_container)
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: home tab failed"))
        end)

        it("logs and leaves the file manager on top when a Tools entry throws", function()
            local KoPanda = PluginLoader.enabled_plugins[1]
            KoPanda.goHome = function()
                error("kopanda-test: tools home failed")
            end
            local fm = menu_without_home()
            local tools
            for _, tab in ipairs(fm.menu.tab_item_table) do
                if tab.id == "tools" then
                    tools = tab
                end
            end
            local kopanda
            for _, item in ipairs(tools) do
                if item.id == "kopanda" then
                    kopanda = item
                end
            end
            fm.menu:onCloseFileManagerMenu()
            kopanda.sub_item_table[1].callback()
            harness.tick()
            file_manager_usable()
            assert.is_true(logged_error("kopanda-test: tools home failed"))
        end)

        it("gives an empty Settings submenu, logged, when building its rows throws", function()
            -- A schema key whose fields raise when read, so the row builder throws inside items.
            local keys = require("schema").keys
            keys[#keys + 1] = setmetatable({}, {
                __index = function()
                    error("kopanda-test: settings rows failed")
                end,
            })
            finally(function()
                keys[#keys] = nil
            end)
            local fm = menu_without_home()
            local tools
            for _, tab in ipairs(fm.menu.tab_item_table) do
                if tab.id == "tools" then
                    tools = tab
                end
            end
            local kopanda
            for _, item in ipairs(tools) do
                if item.id == "kopanda" then
                    kopanda = item
                end
            end
            assert.same({}, kopanda.sub_item_table[2].sub_item_table_func())
            assert.is_true(logged_error("kopanda-test: settings rows failed"))
            fm.menu:onCloseFileManagerMenu()
            file_manager_usable()
        end)
    end)

    describe("the place search", function()
        local ButtonDialog = require("ui/widget/buttondialog")
        local NetworkMgr = require("ui/network/manager")
        local http = require("socket.http")
        local rapidjson = require("rapidjson")
        local stubs, picks

        -- KoPanda's dialogs and notes from the search still on the window stack, by text or title.
        local function search_widgets()
            local left = {}
            for _, widget in ipairs(harness.stack()) do
                local label = widget.text or widget.title
                if label == "Weather location" or label == "Searching…" or label == "Choose a place" then
                    left[#left + 1] = label
                end
            end
            return left
        end

        -- Closes the home over the file manager, opens the search and searches for query.
        local function search_for(query)
            harness.show_fm()
            harness.tick(2)
            Home.close()
            local LocationSearch = require("location_search")
            LocationSearch.ask(function(location)
                picks[#picks + 1] = location
            end)
            local dialog
            for _, widget in ipairs(harness.stack()) do
                if widget.title == "Weather location" then
                    dialog = widget
                end
            end
            dialog:setInputText(query)
            for _, b in ipairs(dialog.button_table.buttons_layout[1]) do
                if b.text == "Search" then
                    b.callback()
                end
            end
        end

        -- Closes whatever note the search left on top of the file manager.
        local function dismiss_notes()
            while harness.top() ~= require("apps/filemanager/filemanager").instance do
                UIManager:close(harness.top())
            end
        end

        before_each(function()
            picks = {}
            stubs = {
                request = stub(http, "request", function(request)
                    request.sink('{"results":[{"name":"Chicago","admin1":"Illinois","country":"United States",'
                        .. '"latitude":41.85003,"longitude":-87.65005}]}')
                    return 1, 200, {}, "HTTP 200"
                end),
                is_connected = stub(NetworkMgr, "isConnected", function()
                    return true
                end),
                warn = spy.on(logger, "warn"),
            }
        end)

        after_each(function()
            for _, s in pairs(stubs) do
                s:revert()
            end
        end)

        it("logs a decode that throws, closes the searching note and picks nothing", function()
            stubs.decode = stub(rapidjson, "decode", function()
                error("kopanda-test: decode failed")
            end)
            search_for("Chicago")
            assert.same({}, search_widgets())
            assert.same({}, picks)
            local found = false
            for _, call in ipairs(stubs.warn.calls) do
                for _, arg in ipairs(call.vals) do
                    found = found or tostring(arg):find("kopanda-test: decode failed", 1, true) ~= nil
                end
            end
            assert.is_true(found)
            dismiss_notes()
            file_manager_usable()
        end)

        it("logs a search that throws while its note is up, closes the note and picks nothing", function()
            local LocationSearch = require("location_search")
            stubs.search = stub(LocationSearch, "search", function()
                error("kopanda-test: search failed")
            end)
            search_for("Chicago")
            assert.same({}, search_widgets())
            assert.same({}, picks)
            assert.is_true(logged_error("kopanda-test: search failed"))
            file_manager_usable()
        end)

        it("logs a chooser that throws, closes the searching note and picks nothing", function()
            stubs.new = stub(ButtonDialog, "new", function()
                error("kopanda-test: chooser failed")
            end)
            search_for("Chicago")
            assert.same({}, search_widgets())
            assert.same({}, picks)
            assert.is_true(logged_error("kopanda-test: chooser failed"))
            dismiss_notes()
            file_manager_usable()
        end)
    end)
end)
