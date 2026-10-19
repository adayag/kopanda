-- The folder sheet: a launcher folder's entries as a sheet's rows over a shown home,
-- each with its resolved icon and label and its kind or its suffix, a tap on a row running that
-- entry as the home does, the sheet reached through the real launcher, a folder too long for the
-- Colorsoft and where paint_ms starts. No case writes the settings file.
describe("the folder sheet", function()
    local harness = require("plugin_harness")
    local Dispatcher = require("dispatcher")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local InfoMessage = require("ui/widget/infomessage")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local time = require("ui/time")
    local util = require("util")
    local Screen = require("device").screen
    local FolderSheet, Home, LauncherEntries, Settings, Sheet

    -- Undo steps for the running test, run last first after it.
    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
    end

    local PLUGIN_ACTION, PLUGIN_EVENT = "kopanda_spec_folder_plugin", "KoPandaSpecFolderPlugin"
    local ACTION, ACTION_EVENT = "kopanda_spec_folder_action", "KoPandaSpecFolderAction"

    local function register(id, event)
        Dispatcher:registerAction(id, {
            category = "none",
            event = event,
            title = "KoPanda spec " .. id,
            general = true,
        })
        cleanup(function()
            Dispatcher:removeAction(id)
        end)
    end

    -- PluginLoader:isPluginLoaded true for terminal alone, for the rest of the test.
    local function terminal_loaded()
        local s = stub(PluginLoader, "isPluginLoaded", function(_, name)
            return name == "terminal"
        end)
        cleanup(function()
            s:revert()
        end)
    end

    local function temp_dir(name)
        local dir = os.getenv("KO_HOME") .. "/" .. name
        if lfs.attributes(dir, "mode") ~= "directory" then
            assert(lfs.mkdir(dir))
        end
        return dir
    end

    -- The settings file's bytes, or false when there is none.
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

    -- A file manager with its home up; the settings file as it stands is what each case leaves.
    local function fm_with_home()
        local fm = harness.show_fm()
        harness.tick(2)
        assert.equals(Home.shown, harness.top())
        settings_before = settings_bytes()
        return fm
    end

    -- The folder of five: a loaded plugin, an action, a real folder on disk, Wi-Fi (off) and a
    -- plugin that isn't loaded. Registers both actions and stubs the plugin loader.
    local function folder_of_five(dir)
        register(PLUGIN_ACTION, PLUGIN_EVENT)
        register(ACTION, ACTION_EVENT)
        terminal_loaded()
        return {
            kind = "folder",
            label = "Tools",
            entries = {
                { kind = "plugin", plugin = "terminal", action = PLUGIN_ACTION, label = "Terminal", icon = "terminal" },
                { kind = "action", action = ACTION, label = "Screenshot", icon = "screenshot" },
                { kind = "directory", path = dir, label = "Downloads" },
                { kind = "koreader", target = "wifi" },
                { kind = "plugin", plugin = "kopanda_absent", action = PLUGIN_ACTION, label = "Terminal",
                    icon = "terminal" },
            },
        }
    end

    local function centre(rect)
        return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
    end

    local function tap(x, y)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", x, y)))
    end

    -- Opens folder over the home through LauncherEntries.run, as a tap on its tile does, and
    -- returns the sheet shown.
    local function open(folder)
        LauncherEntries.run(folder, Home.shown.ctx)
        local sheet = Sheet.shown
        assert.is_not_nil(sheet)
        assert.equals(sheet, harness.top())
        harness.tick(2)
        return sheet
    end

    local function tap_row(sheet, i)
        tap(centre(sheet.rows[i].rect))
    end

    -- Wraps Sheet.show to record each call's arguments as passed (a spy keeps copies), then
    -- call through, until the test ends.
    local function record_shows()
        local original, calls = Sheet.show, {}
        Sheet.show = function(...)
            calls[#calls + 1] = { ... }
            return original(...)
        end
        cleanup(function()
            Sheet.show = original
        end)
        return calls
    end

    local function count_event(fm, event)
        local sent = { n = 0 }
        fm["on" .. event] = function()
            sent.n = sent.n + 1
            return true
        end
        return sent
    end

    before_each(function()
        harness.load()
        FolderSheet = require("folder_sheet")
        Home = require("home")
        LauncherEntries = require("launcher_entries")
        Settings = require("settings")
        Sheet = require("sheet")
        settings_before = nil
    end)

    after_each(function()
        for i = #cleanups, 1, -1 do
            cleanups[i]()
        end
        cleanups = {}
        harness.teardown()
        G_reader_settings:saveSetting("emulator_fake_wifi_connected", false)
        if settings_before ~= nil then
            assert.equals(settings_before, settings_bytes())
        end
    end)

    it("heads the sheet with the folder's label and count, in the folder band", function()
        fm_with_home()
        local sheet = open(folder_of_five(temp_dir("folder-sheet-head")))
        assert.equals("folder", sheet.spec.name)
        assert.equals("folder", sheet.spec.band)
        assert.same({ heading = "Tools", aside = "Folder · 5", aside_beside = true, hint = "Hold to edit" },
            sheet.spec.header)
    end)

    it("lists the entries in order with their icons, labels and kinds, the off and unavailable ones as on the home",
            function()
        fm_with_home()
        local sheet = open(folder_of_five(temp_dir("folder-sheet-rows")))
        assert.equals(5, #sheet.rows)
        local got = {}
        for i, place in ipairs(sheet.rows) do
            local row = place.row
            got[i] = { icon = row.icon, label = row.label, detail = row.detail, muted = row.muted }
            assert.is_nil(row.chip, "row " .. i)
            assert.is_function(row.run, "row " .. i)
        end
        assert.same({
            { icon = "terminal", label = "Terminal", detail = "Plugin", muted = false },
            { icon = "screenshot", label = "Screenshot", detail = "Action", muted = false },
            { icon = "folder", label = "Downloads", detail = "Folder on disk", muted = false },
            { icon = "wifi_off", label = "Wi-Fi", detail = "off", muted = false },
            { icon = "plugin_missing", label = "Terminal", detail = "plugin missing", muted = true },
        }, got)
    end)

    it("names KoPanda's and KOReader's entries by their kind", function()
        fm_with_home()
        G_reader_settings:saveSetting("emulator_fake_wifi_connected", true)
        local sheet = open({ kind = "folder", label = "Mine", entries = {
            { kind = "kopanda", target = "library" },
            { kind = "koreader", target = "wifi" },
        } })
        assert.same({ "Library", "KoPanda" }, { sheet.rows[1].row.label, sheet.rows[1].row.detail })
        assert.same({ "Wi-Fi", "KOReader", "wifi" },
            { sheet.rows[2].row.label, sheet.rows[2].row.detail, sheet.rows[2].row.icon })
    end)

    describe("a tap on a row", function()
        it("on the action closes the sheet and sends its action's event once", function()
            local fm = fm_with_home()
            local sheet = open(folder_of_five(temp_dir("folder-sheet-action")))
            local action = count_event(fm, ACTION_EVENT)
            local plugin = count_event(fm, PLUGIN_EVENT)
            tap_row(sheet, 2)
            assert.is_nil(Sheet.shown)
            assert.is_false(UIManager:isWidgetShown(sheet))
            assert.equals(1, action.n)
            assert.equals(0, plugin.n)
            assert.equals(Home.shown, harness.top())
        end)

        it("on the plugin sends the plugin's action event once", function()
            local fm = fm_with_home()
            local sheet = open(folder_of_five(temp_dir("folder-sheet-plugin")))
            local plugin = count_event(fm, PLUGIN_EVENT)
            tap_row(sheet, 1)
            assert.is_nil(Sheet.shown)
            assert.equals(1, plugin.n)
        end)

        it("on the folder on disk closes the sheet and the home and leaves the file browser there", function()
            local fm = fm_with_home()
            local dir = temp_dir("folder-sheet-dir")
            local sheet = open(folder_of_five(dir))
            tap_row(sheet, 3)
            assert.is_nil(Sheet.shown)
            assert.is_false(UIManager:isWidgetShown(sheet))
            assert.is_nil(Home.shown)
            assert.equals(ffiutil.realpath(dir), fm.file_chooser.path)
        end)

        it("on Wi-Fi toggles it through the file manager's network listener once", function()
            local fm = fm_with_home()
            local sheet = open(folder_of_five(temp_dir("folder-sheet-wifi")))
            local toggle = stub(fm.networklistener, "onToggleWifi", function()
                return true
            end)
            cleanup(function()
                toggle:revert()
            end)
            tap_row(sheet, 4)
            assert.is_nil(Sheet.shown)
            assert.stub(toggle).was.called(1)
        end)

        it("on the missing plugin shows its note over the home, with no sheet left", function()
            fm_with_home()
            local sheet = open(folder_of_five(temp_dir("folder-sheet-missing")))
            local execute = spy.on(Dispatcher, "execute")
            cleanup(function()
                execute:revert()
            end)
            tap_row(sheet, 5)
            assert.spy(execute).was_not.called()
            assert.is_nil(Sheet.shown)
            assert.is_false(UIManager:isWidgetShown(sheet))
            local top = harness.top()
            assert.equals(InfoMessage, getmetatable(top))
            assert.equals("Terminal: the kopanda_absent plugin isn't loaded.", top.text)
            assert.equals(Home.shown, harness.top(2))
        end)
    end)

    it("opens from a tap on the folder's tile through the real launcher", function()
        assert.is_true(Settings.set("launcher.entries", { {
            kind = "folder",
            label = "Tools",
            entries = { { kind = "kopanda", target = "library" }, { kind = "koreader", target = "history" } },
        } }))
        fm_with_home()
        local slot
        for _, s in ipairs(Home.shown.slots) do
            if s.widget == "launcher" then
                slot = s
            end
        end
        local built = slot.built
        assert.equals(1, #built.rects)
        local rect = built.rects[1]
        tap(built.painted_at.x + rect.x + math.floor(rect.w / 2), built.painted_at.y + rect.y + math.floor(rect.h / 2))
        local sheet = Sheet.shown
        assert.is_not_nil(sheet)
        assert.equals(sheet, harness.top())
        assert.equals("folder", sheet.spec.name)
        assert.same({ heading = "Tools", aside = "Folder · 2", aside_beside = true, hint = "Hold to edit" },
            sheet.spec.header)
        assert.same({ "Library", "History" }, { sheet.rows[1].row.label, sheet.rows[2].row.label })
        assert.equals(Home.shown, harness.top(2))
    end)

    it("shows the rows of a long folder that fit on the Colorsoft, logs once and raises nothing", function()
        fm_with_home()
        register(ACTION, ACTION_EVENT)
        local entries = {}
        for i = 1, 30 do
            entries[i] = { kind = "action", action = ACTION, label = "Entry " .. i, icon = "list" }
        end
        local colorsoft = setmetatable({
            getWidth = function() return 1264 end,
            getHeight = function() return 1680 end,
            getSize = function() return Geom:new{ x = 0, y = 0, w = 1264, h = 1680 } end,
        }, { __index = Screen })
        local ctx = {}
        for k, v in pairs(Home.shown.ctx) do
            ctx[k] = v
        end
        ctx.screen = colorsoft
        local warned = spy.on(logger, "warn")
        local err = spy.on(logger, "err")
        cleanup(function()
            warned:revert()
            err:revert()
        end)
        LauncherEntries.run({ kind = "folder", label = "Long", entries = entries }, ctx)
        local sheet = Sheet.shown
        assert.is_not_nil(sheet)
        assert.truthy(#sheet.rows > 0 and #sheet.rows < 30, #sheet.rows)
        for i, place in ipairs(sheet.rows) do
            assert.equals("Entry " .. i, place.row.label)
            assert.truthy(place.rect.y >= 0 and place.rect.y + place.rect.h <= 1680, "row " .. i)
        end
        assert.equals("Folder · 30", sheet.spec.header.aside)
        local logged = 0
        for _, call in ipairs(warned.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find("leaves out", 1, true) then
                    logged = logged + 1
                end
            end
        end
        assert.equals(1, logged)
        assert.spy(err).was_not.called()
        assert.equals(sheet, Sheet.shown)
    end)

    describe("a hold", function()
        local Editor

        -- Stores a launcher of Library, Mine (one entry) and Tools (two), shows the home and
        -- opens the sheet of the stored folder at index f; returns the sheet.
        local function stored_folder(f)
            local entries = {
                { kind = "kopanda", target = "library" },
                { kind = "folder", label = "Mine", entries = { { kind = "kopanda", target = "series" } } },
                { kind = "folder", label = "Tools", entries = {
                    { kind = "kopanda", target = "library" }, { kind = "koreader", target = "history" },
                } },
            }
            assert.is_true(Settings.set("launcher.entries", entries))
            fm_with_home()
            Editor = require("editor")
            return open(Settings.get("launcher.entries")[f])
        end

        it("in the sheet closes it and opens that folder's list, headed with its label", function()
            local sheet = stored_folder(3)
            local x, y = centre(sheet.rows[1].rect)
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("hold", x, y)))
            assert.is_nil(Sheet.shown)
            assert.is_false(UIManager:isWidgetShown(sheet))
            local editor = Editor.shown
            assert.is_not_nil(editor)
            assert.equals(editor, harness.top())
            assert.equals("Tools", editor.spec.title)
            assert.equals("Folder · 2", editor.spec.aside)
        end)

        it("finds the folder by its contents when the sheet's entry is a copy", function()
            local entries = {
                { kind = "folder", label = "Mine", entries = { { kind = "kopanda", target = "series" } } },
                { kind = "folder", label = "Tools", entries = { { kind = "kopanda", target = "library" } } },
            }
            assert.is_true(Settings.set("launcher.entries", entries))
            fm_with_home()
            Editor = require("editor")
            local sheet = open(util.tableDeepCopy(entries[2]))
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("hold", centre(sheet.rows[1].rect))))
            assert.equals("Tools", Editor.shown.spec.title)
        end)

        it("opens the top level when the folder is no longer stored", function()
            fm_with_home()
            Editor = require("editor")
            local sheet = open({ kind = "folder", label = "Gone",
                entries = { { kind = "kopanda", target = "series" } } })
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("hold", centre(sheet.rows[1].rect))))
            assert.is_nil(Sheet.shown)
            assert.equals("Launcher", Editor.shown.spec.title)
        end)
    end)

    it("starts paint_ms from the tap, before the first child resolves", function()
        fm_with_home()
        local resolved_at
        local resolve = LauncherEntries.resolve
        LauncherEntries.resolve = function(entry)
            resolved_at = resolved_at or time.monotonic()
            return resolve(entry)
        end
        cleanup(function()
            LauncherEntries.resolve = resolve
        end)
        local shows = record_shows()
        local folder = { kind = "folder", label = "Tools", entries = { { kind = "kopanda", target = "library" } } }
        LauncherEntries.run(folder, Home.shown.ctx)
        assert.equals(1, #shows)
        local opts = shows[1][3]
        assert.is_number(opts.started.wall)
        assert.is_number(opts.started.cpu)
        assert.is_number(resolved_at)
        assert.truthy(opts.started.wall <= resolved_at)
        assert.equals(Home.shown.ctx, shows[1][2])
    end)

    it("passes opts to the sheet as given", function()
        fm_with_home()
        local shows = record_shows()
        local opts = { started = time.monotonic() }
        FolderSheet.open({ kind = "folder", label = "Tools", entries = { { kind = "kopanda", target = "library" } } },
            Home.shown.ctx, opts)
        assert.equals(1, #shows)
        assert.equals(opts, shows[1][3])
        assert.equals(Home.shown.ctx, shows[1][2])
    end)
end)
