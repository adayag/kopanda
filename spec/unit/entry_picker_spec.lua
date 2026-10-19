-- The add-an-entry picker: each of the five kinds turned into a launcher
-- entry the settings validator takes, or a note and no entry, over a real file manager with its
-- home up. on_entry records what it gets; no case writes the settings file. The plugin cases stub
-- PluginLoader, so the emulator's own plugins/ stays out of them.
describe("the entry picker", function()
    local harness = require("plugin_harness")
    local Dispatcher = require("dispatcher")
    local Event = require("ui/event")
    local InfoMessage = require("ui/widget/infomessage")
    local InputDialog = require("ui/widget/inputdialog")
    local PathChooser = require("ui/widget/pathchooser")
    local PluginLoader = require("pluginloader")
    local SpinWidget = require("ui/widget/spinwidget")
    local TouchMenu = require("ui/widget/touchmenu")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local EntryPicker, Home, Schema, Settings, Sheet

    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
    end

    local function settings_bytes()
        local f = io.open(harness.settings_file, "rb")
        if not f then
            return false
        end
        local bytes = f:read("*a")
        f:close()
        return bytes
    end

    local settings_before
    local got

    local function on_entry(entry)
        got[#got + 1] = entry
    end

    -- The one entry handed to on_entry, checked with the settings validator as a one-entry list.
    local function the_entry()
        assert.equals(1, #got)
        local launcher
        for _, key in ipairs(Schema.keys) do
            if key.id == "launcher.entries" then
                launcher = key
            end
        end
        assert.is_true(Settings.validators.launcher(launcher, { got[1] }))
        return got[1]
    end

    local function fm_with_home()
        local fm = harness.show_fm()
        harness.tick(2)
        assert.equals(Home.shown, harness.top())
        settings_before = settings_bytes()
        return fm
    end

    -- The widget on the stack whose class is class, or nil.
    local function shown(class)
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == class then
                return widget
            end
        end
    end

    -- The action list's TouchMenu, or nil.
    local function action_menu()
        for _, widget in ipairs(harness.stack()) do
            if widget[1] and getmetatable(widget[1]) == TouchMenu then
                return widget[1], widget
            end
        end
    end

    local function note()
        local top = harness.top()
        assert.equals(InfoMessage, getmetatable(top))
        return top.text
    end

    local function press(dialog, text)
        for _, button in ipairs(dialog.buttons[1]) do
            if button.text == text then
                return button.callback()
            end
        end
        error("no button " .. text)
    end

    local function tap_row(sheet, i)
        local rect = sheet.rows[i].rect
        UIManager:sendEvent(Event:new("Gesture",
            harness.gesture("tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))))
    end

    local function row_views(sheet)
        local views = {}
        for i, place in ipairs(sheet.rows) do
            views[i] = { label = place.row.label, icon = place.row.icon }
        end
        return views
    end

    local function register(id, value)
        Dispatcher:registerAction(id, value)
        cleanup(function()
            Dispatcher:removeAction(id)
        end)
    end

    -- The item of items whose text (or text_func's) is text.
    local function item_titled(items, text)
        for _, item in ipairs(items) do
            if (item.text or (item.text_func and item.text_func())) == text then
                return item
            end
        end
    end

    -- Selects the section titled section, then each action titled in titles, in the menu.
    local function tick(menu, section, titles)
        for _, title in ipairs(titles) do
            menu:onMenuSelect(item_titled(menu.tab_item_table[1], section))
            menu:onMenuSelect(item_titled(menu.item_table, title))
            menu:backToUpperMenu(true)
        end
    end

    before_each(function()
        harness.load()
        EntryPicker = require("entry_picker")
        Home = require("home")
        Schema = require("schema")
        Settings = require("settings")
        Sheet = require("sheet")
        settings_before = nil
        got = {}
    end)

    after_each(function()
        for i = #cleanups, 1, -1 do
            cleanups[i]()
        end
        cleanups = {}
        harness.teardown()
        if settings_before ~= nil then
            assert.equals(settings_before, settings_bytes())
        end
    end)

    it("offers the five kinds in order with their labels", function()
        assert.same({
            { kind = "kopanda", label = "KoPanda screen" },
            { kind = "koreader", label = "KOReader screen" },
            { kind = "directory", label = "Folder on disk" },
            { kind = "action", label = "Action" },
            { kind = "plugin", label = "Plugin" },
        }, EntryPicker.KINDS)
    end)

    describe("a screen", function()
        it("lists KoPanda's screens with their icons, and a tap adds { kind, target }", function()
            fm_with_home()
            EntryPicker.pick("kopanda", Home.shown.ctx, on_entry)
            local sheet = Sheet.shown
            assert.is_not_nil(sheet)
            assert.equals("KoPanda screen", sheet.spec.header.heading)
            assert.equals("picker", sheet.spec.name)
            assert.equals("home", sheet.spec.band)
            assert.same({
                { label = "Library", icon = "library" },
                { label = "Series", icon = "series" },
                { label = "Authors", icon = "authors" },
                { label = "Settings", icon = "settings" },
                { label = "Quick settings", icon = "quick_settings" },
            }, row_views(sheet))
            assert.same({}, got)
            tap_row(sheet, 2)
            assert.is_nil(Sheet.shown)
            assert.same({ kind = "kopanda", target = "series" }, the_entry())
        end)

        it("adds Quick settings as { kind = kopanda, target = quick_settings }", function()
            fm_with_home()
            EntryPicker.pick("kopanda", Home.shown.ctx, on_entry)
            local sheet = Sheet.shown
            assert.same({ label = "Quick settings", icon = "quick_settings" }, row_views(sheet)[5])
            tap_row(sheet, 5)
            assert.is_nil(Sheet.shown)
            assert.same({ kind = "kopanda", target = "quick_settings" }, the_entry())
        end)

        it("lists KOReader's screens", function()
            fm_with_home()
            EntryPicker.pick("koreader", Home.shown.ctx, on_entry)
            local sheet = Sheet.shown
            assert.equals("KOReader screen", sheet.spec.header.heading)
            assert.same({
                { label = "History", icon = "history" },
                { label = "Favorites", icon = "bookmark" },
                { label = "Collections", icon = "list" },
                { label = "Wi-Fi", icon = "wifi" },
            }, row_views(sheet))
            tap_row(sheet, 4)
            assert.same({ kind = "koreader", target = "wifi" }, the_entry())
        end)
    end)

    describe("a folder on disk", function()
        local function temp_dir(name)
            local dir = os.getenv("KO_HOME") .. "/" .. name
            if lfs.attributes(dir, "mode") ~= "directory" then
                assert(lfs.mkdir(dir))
            end
            return dir
        end

        it("opens a folders-only chooser at the file browser's path", function()
            local fm = fm_with_home()
            EntryPicker.pick("directory", Home.shown.ctx, on_entry)
            local chooser = harness.top()
            assert.equals(PathChooser, getmetatable(chooser))
            assert.is_true(chooser.select_directory)
            assert.is_false(chooser.select_file)
            assert.equals(fm.file_chooser.path, chooser.path)
        end)

        it("asks for a label, the folder's name, and adds { kind = directory, path, label }", function()
            fm_with_home()
            local dir = temp_dir("entry-picker-folder")
            EntryPicker.pick("directory", Home.shown.ctx, on_entry)
            local chooser = harness.top()
            chooser:onMenuHold({ path = dir })
            press(chooser.button_dialog, "Choose")
            assert.is_false(UIManager:isWidgetShown(chooser))
            local dialog = shown(InputDialog)
            assert.is_not_nil(dialog)
            assert.equals("Label", dialog.title)
            assert.equals("entry-picker-folder", dialog:getInputText())
            assert.same({}, got)
            dialog:setInputText("Tools")
            press(dialog, "Add")
            assert.is_false(UIManager:isWidgetShown(dialog))
            assert.same({ kind = "directory", path = ffiutil.realpath(dir), label = "Tools" }, the_entry())
        end)

        it("refuses / with its note", function()
            fm_with_home()
            EntryPicker.pick("directory", Home.shown.ctx, on_entry)
            harness.top().onConfirm("/")
            assert.equals("Choose a folder inside the root.", note())
            assert.is_nil(shown(InputDialog))
            assert.same({}, got)
        end)

        it("stores a path with a trailing / without it", function()
            fm_with_home()
            local dir = temp_dir("entry-picker-slash")
            EntryPicker.pick("directory", Home.shown.ctx, on_entry)
            harness.top().onConfirm(dir .. "/")
            local dialog = shown(InputDialog)
            assert.equals("entry-picker-slash", dialog:getInputText())
            press(dialog, "Add")
            assert.same({ kind = "directory", path = dir, label = "entry-picker-slash" }, the_entry())
        end)
    end)

    describe("the action tree", function()
        local NUMBER, READER = "kopanda_spec_pick_number", "kopanda_spec_pick_reader"

        it("shows only KOReader's four file-browser sections", function()
            fm_with_home()
            register(READER, { category = "none", event = "KoPandaSpecReader", title = "KoPanda spec reader",
                reader = true })
            local reference = {}
            Dispatcher:addSubMenu({}, reference, {}, "reference")
            EntryPicker.pick("action", Home.shown.ctx, on_entry)
            local menu, container = action_menu()
            assert.is_not_nil(menu)
            assert.equals(container, harness.top())
            local items = menu.tab_item_table[1]
            local texts = {}
            for i, item in ipairs(items) do
                texts[i] = item.text
                assert.is_nil(item_titled(item.sub_item_table, "KoPanda spec reader"), item.text)
            end
            assert.same({ reference[2].text, reference[3].text, reference[4].text, reference[5].text }, texts)
            assert.equals("appbar.settings", items.icon)
        end)

        it("adds the one action ticked with its display name as the editable label", function()
            fm_with_home()
            EntryPicker.pick("action", Home.shown.ctx, on_entry)
            local menu, container = action_menu()
            tick(menu, "General", { "History" })
            menu:onClose()
            assert.is_false(UIManager:isWidgetShown(container))
            local dialog = shown(InputDialog)
            assert.equals("History", dialog:getInputText())
            press(dialog, "Add")
            assert.same({ kind = "action", action = "history", label = "History", icon = "action" }, the_entry())
        end)

        it("adds nothing and says so when nothing is ticked", function()
            fm_with_home()
            EntryPicker.pick("action", Home.shown.ctx, on_entry)
            local menu = action_menu()
            menu:onClose()
            assert.equals("Pick one action.", note())
            assert.is_nil(shown(InputDialog))
            assert.same({}, got)
        end)

        it("adds nothing and says so when two are ticked", function()
            fm_with_home()
            EntryPicker.pick("action", Home.shown.ctx, on_entry)
            local menu = action_menu()
            tick(menu, "General", { "History", "Favorites" })
            menu:onClose()
            assert.equals("Pick one action.", note())
            assert.same({}, got)
        end)

        it("adds nothing and says so when the action ticked holds a value", function()
            fm_with_home()
            register(NUMBER, { category = "absolutenumber", event = "KoPandaSpecNumber", min = 1, max = 10,
                title = "KoPanda spec number", general = true })
            EntryPicker.pick("action", Home.shown.ctx, on_entry)
            local menu = action_menu()
            tick(menu, "General", { "KoPanda spec number" })
            local spin = harness.top()
            assert.equals(SpinWidget, getmetatable(spin))
            spin.callback({ value = 5 })
            UIManager:close(spin)
            menu:onClose()
            assert.equals("That action needs a value, which a launcher entry can't keep.", note())
            assert.is_nil(shown(InputDialog))
            assert.same({}, got)
        end)

        it("shows a note and no menu when KOReader's list isn't the shape it was read as", function()
            fm_with_home()
            local s = stub(Dispatcher, "addSubMenu", function(_, _, menu)
                for i = 1, 3 do
                    menu[i] = { text = "Item " .. i, sub_item_table = {} }
                end
            end)
            cleanup(function()
                s:revert()
            end)
            EntryPicker.pick("action", Home.shown.ctx, on_entry)
            assert.equals("Couldn't list KOReader's actions.", note())
            assert.is_nil(action_menu())
            assert.same({}, got)
        end)
    end)

    describe("a plugin", function()
        local function plugins(enabled, disabled, loaded)
            local load = stub(PluginLoader, "loadPlugins", function()
                return enabled, disabled
            end)
            local is_loaded = stub(PluginLoader, "isPluginLoaded", function(_, name)
                return loaded[name] == true
            end)
            cleanup(function()
                load:revert()
                is_loaded:revert()
            end)
        end

        it("lists only enabled plugins loaded here that aren't doc-only, then adds one from the tree", function()
            fm_with_home()
            plugins({
                { name = "kopanda", fullname = "KoPanda" },
                { name = "kopanda_spec_doc", fullname = "Doc only", is_doc_only = true },
                { name = "kopanda_spec_loaded", fullname = "Loaded one" },
                { name = "kopanda_spec_unloaded", fullname = "Not loaded" },
            }, {
                { name = "kopanda_spec_disabled", fullname = "Disabled" },
            }, {
                kopanda = true,
                kopanda_spec_doc = true,
                kopanda_spec_loaded = true,
                kopanda_spec_disabled = true,
            })
            EntryPicker.pick("plugin", Home.shown.ctx, on_entry)
            local sheet = Sheet.shown
            assert.equals("Plugin", sheet.spec.header.heading)
            assert.equals("picker", sheet.spec.name)
            assert.equals("home", sheet.spec.band)
            assert.same({ "Loaded one" }, { sheet.rows[1].row.label, sheet.rows[2] and sheet.rows[2].row.label })
            tap_row(sheet, 1)
            assert.is_nil(Sheet.shown)
            local menu = action_menu()
            assert.is_not_nil(menu)
            tick(menu, "General", { "History" })
            menu:onClose()
            local dialog = shown(InputDialog)
            assert.equals("History", dialog:getInputText())
            press(dialog, "Add")
            assert.same({ kind = "plugin", plugin = "kopanda_spec_loaded", action = "history", label = "History",
                icon = "action" }, the_entry())
        end)

        it("labels a plugin by its name when it has no fullname, sorted by label", function()
            fm_with_home()
            plugins({
                { name = "zeta" },
                { name = "kopanda_spec_b", fullname = "Beta" },
                { name = "alpha" },
            }, {}, { zeta = true, kopanda_spec_b = true, alpha = true })
            EntryPicker.pick("plugin", Home.shown.ctx, on_entry)
            local labels = {}
            for i, place in ipairs(Sheet.shown.rows) do
                labels[i] = place.row.label
            end
            assert.same({ "Beta", "alpha", "zeta" }, labels)
        end)

        it("pages through every plugin with a More row, then adds the one last by label", function()
            harness.at_colorsoft(function()
                fm_with_home()
                local enabled, loaded, labels = {}, {}, {}
                for i = 1, 28 do
                    local name = string.format("kopanda_spec_p%02d", i)
                    enabled[i] = { name = name, fullname = string.format("Plugin %02d", i) }
                    loaded[name] = true
                    labels[i] = enabled[i].fullname
                end
                plugins(enabled, {}, loaded)
                EntryPicker.pick("plugin", Home.shown.ctx, on_entry)
                local seen, pages = {}, 0
                local sheet = Sheet.shown
                while true do
                    pages = pages + 1
                    assert.truthy(pages <= 28, "the More row never ends")
                    assert.equals("Plugin", sheet.spec.header.heading)
                    assert.equals("picker", sheet.spec.name)
                    local n = #sheet.rows
                    local last = sheet.rows[n].row
                    for i = 1, n - 1 do
                        seen[#seen + 1] = sheet.rows[i].row.label
                    end
                    if last.label ~= "More…" then
                        seen[#seen + 1] = last.label
                        break
                    end
                    tap_row(sheet, n)
                    assert.is_not_nil(Sheet.shown)
                    assert.are_not.equals(sheet, Sheet.shown)
                    sheet = Sheet.shown
                end
                assert.truthy(pages > 1, "28 plugins fit one sheet; the More row isn't exercised")
                assert.same(labels, seen)
                tap_row(sheet, #sheet.rows)
                assert.is_nil(Sheet.shown)
                local menu = action_menu()
                tick(menu, "General", { "History" })
                menu:onClose()
                press(shown(InputDialog), "Add")
                assert.same({ kind = "plugin", plugin = "kopanda_spec_p28", action = "history", label = "History",
                    icon = "action" }, the_entry())
            end)
        end)

        it("says so when no plugin is loaded", function()
            fm_with_home()
            plugins({ { name = "kopanda", fullname = "KoPanda" } }, {}, { kopanda = true })
            EntryPicker.pick("plugin", Home.shown.ctx, on_entry)
            assert.equals("No plugins are loaded.", note())
            assert.is_nil(Sheet.shown)
        end)
    end)

    describe("the label", function()
        -- The label dialog for History, checked to have shown the keyboard (headless, the keyboard
        -- never reports itself visible, so the call is what's checked; a luassert spy would
        -- deep-copy the dialog it's called with).
        local function label_dialog()
            fm_with_home()
            local show_keyboard = InputDialog.onShowKeyboard
            local keyboard_for = {}
            InputDialog.onShowKeyboard = function(self, ...)
                keyboard_for[#keyboard_for + 1] = self
                return show_keyboard(self, ...)
            end
            cleanup(function()
                InputDialog.onShowKeyboard = show_keyboard
            end)
            EntryPicker.pick("action", Home.shown.ctx, on_entry)
            local menu = action_menu()
            tick(menu, "General", { "History" })
            menu:onClose()
            local dialog = shown(InputDialog)
            assert.equals(1, #keyboard_for)
            assert.equals(dialog, keyboard_for[1])
            return dialog
        end

        it("adds nothing on Cancel", function()
            local dialog = label_dialog()
            press(dialog, "Cancel")
            assert.is_false(UIManager:isWidgetShown(dialog))
            assert.same({}, got)
        end)

        it("does nothing on Add with an all-space label and keeps the dialog", function()
            local dialog = label_dialog()
            dialog:setInputText("   ")
            press(dialog, "Add")
            assert.is_true(UIManager:isWidgetShown(dialog))
            assert.same({}, got)
        end)

        it("trims the label it adds", function()
            local dialog = label_dialog()
            dialog:setInputText("  Recent  ")
            press(dialog, "Add")
            assert.equals("Recent", the_entry().label)
        end)
    end)

    it("logs and closes the dialog when on_entry throws, adding nothing more", function()
        fm_with_home()
        local err = spy.on(logger, "err")
        cleanup(function()
            err:revert()
        end)
        EntryPicker.pick("action", Home.shown.ctx, function()
            error("kopanda-test: on_entry failed")
        end)
        local menu = action_menu()
        tick(menu, "General", { "History" })
        menu:onClose()
        local dialog = shown(InputDialog)
        assert.has_no.errors(function()
            press(dialog, "Add")
        end)
        assert.is_false(UIManager:isWidgetShown(dialog))
        assert.spy(err).was.called()
    end)

    it("logs and closes the label dialog when a step fails while it is up, adding nothing", function()
        fm_with_home()
        local err = spy.on(logger, "err")
        local keyboard = stub(InputDialog, "onShowKeyboard", function()
            error("kopanda-test: the keyboard failed")
        end)
        cleanup(function()
            err:revert()
            keyboard:revert()
        end)
        EntryPicker.pick("action", Home.shown.ctx, on_entry)
        local menu = action_menu()
        tick(menu, "General", { "History" })
        assert.has_no.errors(function()
            menu:onClose()
        end)
        assert.spy(keyboard).was.called()
        assert.is_nil(shown(InputDialog))
        assert.spy(err).was.called()
        assert.same({}, got)
    end)
end)
