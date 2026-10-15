-- What a launcher entry resolves to and what a tap on it runs (C3): the fixed tables match the
-- schema's targets, each kind resolves ready, off or unavailable by what the device holds, and
-- run opens the screen, dispatches the action or shows a note, never writing the settings file.
describe("LauncherEntries", function()
    local harness = require("plugin_harness")
    local Dispatcher = require("dispatcher")
    local InfoMessage = require("ui/widget/infomessage")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local LauncherEntries, Home

    -- Undo steps for the running test, run last first after it. busted keeps only a test's last
    -- finally, so the helpers can't each register one.
    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
    end

    local SPEC_ACTION = "kopanda_spec_launcher_action"
    local SPEC_EVENT = "KoPandaSpecLauncherAction"

    local function plugin_entry(name, action)
        return { kind = "plugin", plugin = name, action = action or SPEC_ACTION, label = "Terminal", icon = "terminal" }
    end

    local function action_entry(action)
        return { kind = "action", action = action, label = "Screenshot", icon = "screenshot" }
    end

    local function directory_entry(path)
        return { kind = "directory", path = path, label = "Downloads" }
    end

    local function folder_entry(count)
        local entries = {}
        for i = 1, count do
            entries[i] = { kind = "kopanda", target = "library" }
        end
        return { kind = "folder", label = "Tools", entries = entries }
    end

    -- The spec's dispatcher action, registered for the rest of the test.
    local function register_action()
        Dispatcher:registerAction(SPEC_ACTION, {
            category = "none",
            event = SPEC_EVENT,
            title = "KoPanda spec action",
            general = true,
        })
        cleanup(function()
            Dispatcher:removeAction(SPEC_ACTION)
        end)
    end

    -- PluginLoader:isPluginLoaded true for the names given, for the rest of the test.
    local function plugins_loaded(names)
        local s = stub(PluginLoader, "isPluginLoaded", function(_, name)
            return names[name] == true
        end)
        cleanup(function()
            s:revert()
        end)
    end

    -- A fresh, real folder under KO_HOME.
    local function temp_dir(name)
        local dir = os.getenv("KO_HOME") .. "/" .. name
        if lfs.attributes(dir, "mode") ~= "directory" then
            assert(lfs.mkdir(dir))
        end
        return dir
    end

    local function set_wifi(on)
        G_reader_settings:saveSetting("emulator_fake_wifi_connected", on)
    end

    -- The InfoMessages UIManager:show was given, by text and timeout; nothing else is shown.
    local function notes()
        local shown = {}
        local s = stub(UIManager, "show", function(_, widget)
            if getmetatable(widget) == InfoMessage then
                shown[#shown + 1] = { text = widget.text, timeout = widget.timeout }
            else
                shown[#shown + 1] = { widget = widget }
            end
        end)
        cleanup(function()
            s:revert()
        end)
        return shown
    end

    -- A file manager with its home up.
    local function fm_with_home()
        local fm = harness.show_fm()
        harness.tick(2)
        assert.equals(Home.shown, harness.top())
        return fm
    end

    -- The view of an entry that can't run.
    local function unavailable(label, suffix)
        return { label = label, icon = "plugin_missing", state = "unavailable", suffix = suffix }
    end

    local function sorted_keys(t)
        local keys = {}
        for k in pairs(t) do
            keys[#keys + 1] = k
        end
        table.sort(keys)
        return keys
    end

    local function sorted(list)
        local copy = { unpack(list) }
        table.sort(copy)
        return copy
    end

    before_each(function()
        harness.load()
        LauncherEntries = require("launcher_entries")
        Home = require("home")
    end)

    after_each(function()
        for i = #cleanups, 1, -1 do
            cleanups[i]()
        end
        cleanups = {}
        harness.teardown()
        set_wifi(false)
        -- No case writes the settings file: harness.load removed it, and it is still absent.
        assert.is_nil(lfs.attributes(harness.settings_file, "mode"))
    end)

    describe("fixed tables", function()
        it("hold exactly the schema's kopanda and koreader targets", function()
            local entry = require("schema").keys[9]
            assert.equals("launcher.entries", entry.id)
            assert.same(sorted(entry.targets.kopanda), sorted_keys(LauncherEntries.KOPANDA))
            assert.same(sorted(entry.targets.koreader), sorted_keys(LauncherEntries.KOREADER))
        end)
    end)

    describe("resolve", function()
        it("reads a loaded plugin with a registered action as ready", function()
            register_action()
            plugins_loaded({ terminal = true })
            assert.same({ label = "Terminal", icon = "terminal", state = "ready" },
                LauncherEntries.resolve(plugin_entry("terminal")))
        end)

        it("reads a plugin that isn't loaded as plugin missing", function()
            register_action()
            plugins_loaded({})
            assert.same(unavailable("Terminal", "plugin missing"),
                LauncherEntries.resolve(plugin_entry("terminal")))
        end)

        it("reads a loaded plugin whose action isn't registered as plugin missing", function()
            plugins_loaded({ terminal = true })
            assert.same(unavailable("Terminal", "plugin missing"),
                LauncherEntries.resolve(plugin_entry("terminal", "kopanda_spec_no_such_action")))
        end)

        it("reads an action entry as ready when registered and not available when not", function()
            register_action()
            assert.same({ label = "Screenshot", icon = "screenshot", state = "ready" },
                LauncherEntries.resolve(action_entry(SPEC_ACTION)))
            assert.same(unavailable("Screenshot", "not available"),
                LauncherEntries.resolve(action_entry("kopanda_spec_no_such_action")))
        end)

        it("reads a real folder as ready, and a removed folder or a file as folder missing", function()
            local dir = temp_dir("launcher-resolve-dir")
            assert.same({ label = "Downloads", icon = "folder", state = "ready" },
                LauncherEntries.resolve(directory_entry(dir)))
            local file = dir .. "/a-file.txt"
            local f = assert(io.open(file, "w"))
            f:write("x")
            f:close()
            assert.same(unavailable("Downloads", "folder missing"),
                LauncherEntries.resolve(directory_entry(file)))
            os.remove(file)
            assert(lfs.rmdir(dir))
            assert.same(unavailable("Downloads", "folder missing"),
                LauncherEntries.resolve(directory_entry(dir)))
        end)

        it("reads a folder entry as ready with the folder icon", function()
            assert.same({ label = "Tools", icon = "folder", state = "ready" },
                LauncherEntries.resolve(folder_entry(3)))
        end)

        it("reads the default six as Library, Series, Authors, History, Wi-Fi and Settings", function()
            set_wifi(true)
            local views = {}
            for i, entry in ipairs(require("schema").keys[9].default) do
                views[i] = LauncherEntries.resolve(entry)
            end
            assert.same({
                { label = "Library", icon = "library", state = "ready" },
                { label = "Series", icon = "series", state = "ready" },
                { label = "Authors", icon = "authors", state = "ready" },
                { label = "History", icon = "history", state = "ready" },
                { label = "Wi-Fi", icon = "wifi", state = "ready" },
                { label = "Settings", icon = "settings", state = "ready" },
            }, views)
        end)

        it("reads Favorites and Collections with their icons", function()
            assert.same({ label = "Favorites", icon = "bookmark", state = "ready" },
                LauncherEntries.resolve({ kind = "koreader", target = "favorites" }))
            assert.same({ label = "Collections", icon = "list", state = "ready" },
                LauncherEntries.resolve({ kind = "koreader", target = "collections" }))
        end)

        it("reads Wi-Fi as off when the radio is off and ready when it is on", function()
            local wifi = { kind = "koreader", target = "wifi" }
            set_wifi(false)
            assert.same({ label = "Wi-Fi", icon = "wifi_off", state = "off", suffix = "off" },
                LauncherEntries.resolve(wifi))
            set_wifi(true)
            assert.same({ label = "Wi-Fi", icon = "wifi", state = "ready" }, LauncherEntries.resolve(wifi))
        end)

        it("logs a raising resolution and reads it as not available", function()
            register_action()
            local s = stub(PluginLoader, "isPluginLoaded", function()
                error("spec: isPluginLoaded failed")
            end)
            local err = spy.on(logger, "err")
            cleanup(function()
                s:revert()
                err:revert()
            end)
            assert.same(unavailable("Terminal", "not available"),
                LauncherEntries.resolve(plugin_entry("terminal")))
            assert.spy(err).was.called()
        end)
    end)

    describe("run", function()
        it("shows History over the home, and closing it leaves the home on top", function()
            local fm = fm_with_home()
            local home = Home.shown
            LauncherEntries.run({ kind = "koreader", target = "history" }, {})
            local list = fm.history.booklist_menu
            assert.is_not_nil(list)
            assert.equals(list, harness.top())
            assert.equals(home, harness.top(2))
            list.close_callback()
            assert.equals(home, harness.top())
            assert.equals(home, Home.shown)
        end)

        it("toggles Wi-Fi through the file manager's network listener once", function()
            local fm = fm_with_home()
            local toggle = stub(fm.networklistener, "onToggleWifi", function()
                return true
            end)
            cleanup(function()
                toggle:revert()
            end)
            LauncherEntries.run({ kind = "koreader", target = "wifi" }, {})
            assert.stub(toggle).was.called(1)
        end)

        it("sends an available plugin entry's action event once", function()
            local fm = fm_with_home()
            register_action()
            plugins_loaded({ terminal = true })
            local sent = 0
            fm["on" .. SPEC_EVENT] = function()
                sent = sent + 1
                return true
            end
            LauncherEntries.run(plugin_entry("terminal"), {})
            assert.equals(1, sent)
        end)

        it("sends an available action entry's event once", function()
            local fm = fm_with_home()
            register_action()
            local sent = 0
            fm["on" .. SPEC_EVENT] = function()
                sent = sent + 1
                return true
            end
            LauncherEntries.run(action_entry(SPEC_ACTION), {})
            assert.equals(1, sent)
        end)

        it("lets a raising run reach its caller, so the home's failsafe closes it", function()
            fm_with_home()
            register_action()
            local s = stub(Dispatcher, "execute", function()
                error("spec: execute failed")
            end)
            cleanup(function()
                s:revert()
            end)
            local ok, err = pcall(LauncherEntries.run, action_entry(SPEC_ACTION), {})
            assert.is_false(ok)
            assert.matches("spec: execute failed", err)
        end)

        it("opens the Library: closes the home and sends the file browser home once", function()
            local fm = fm_with_home()
            local on_home = spy.on(fm, "onHome")
            LauncherEntries.run({ kind = "kopanda", target = "library" }, {})
            assert.is_nil(Home.shown)
            assert.spy(on_home).was.called(1)
        end)

        it("opens a directory entry: closes the home and leaves the file browser at the folder", function()
            local fm = fm_with_home()
            local dir = temp_dir("launcher-run-dir")
            LauncherEntries.run(directory_entry(dir), {})
            assert.is_nil(Home.shown)
            assert.equals(ffiutil.realpath(dir), fm.file_chooser.path)
        end)

        it("opens KoPanda's settings once", function()
            fm_with_home()
            local SettingsMenu = require("settings_menu")
            local open = stub(SettingsMenu, "open")
            cleanup(function()
                open:revert()
            end)
            LauncherEntries.run({ kind = "kopanda", target = "settings" }, {})
            assert.stub(open).was.called(1)
        end)
    end)

    describe("notes", function()
        -- Runs entry under ctx (default: an empty one) and returns the notes it showed, checking
        -- that it scheduled nothing and dispatched nothing.
        local function run_for_notes(entry, ctx)
            local shown = notes()
            local schedule = spy.on(UIManager, "scheduleIn")
            local execute = spy.on(Dispatcher, "execute")
            cleanup(function()
                schedule:revert()
                execute:revert()
            end)
            LauncherEntries.run(entry, ctx or {})
            assert.spy(schedule).was_not.called()
            assert.spy(execute).was_not.called()
            schedule:revert()
            execute:revert()
            return shown
        end

        it("say Series and Authors are coming with the library", function()
            fm_with_home()
            assert.same({ { text = "Series are coming with the library." } },
                run_for_notes({ kind = "kopanda", target = "series" }))
            assert.same({ { text = "Authors are coming with the library." } },
                run_for_notes({ kind = "kopanda", target = "authors" }))
        end)

        it("give a folder none: it shows its sheet, headed with its label and count", function()
            fm_with_home()
            local Sheet = require("sheet")
            for _, case in ipairs({ { 3, "Folder · 3" }, { 1, "Folder · 1" } }) do
                local shown = run_for_notes(folder_entry(case[1]), Home.shown.ctx)
                assert.equals(1, #shown)
                assert.is_nil(shown[1].text)
                local sheet = shown[1].widget
                assert.equals(Sheet.shown, sheet)
                assert.equals("folder", sheet.spec.name)
                assert.equals("Tools", sheet.spec.header.heading)
                assert.equals(case[2], sheet.spec.header.aside)
            end
        end)

        it("give each unavailable cause its note and dispatch nothing", function()
            fm_with_home()
            register_action()
            plugins_loaded({})
            assert.same({ { text = "Terminal: the terminal plugin isn't loaded." } },
                run_for_notes(plugin_entry("terminal")))
            local missing = os.getenv("KO_HOME") .. "/launcher-no-such-dir"
            assert.same({ { text = "Downloads: " .. missing .. " isn't there." } },
                run_for_notes(directory_entry(missing)))
            assert.same({ { text = "Screenshot isn't available here." } },
                run_for_notes(action_entry("kopanda_spec_no_such_action")))
        end)

        it("log a raising availability check and say the entry isn't available", function()
            fm_with_home()
            register_action()
            local s = stub(PluginLoader, "isPluginLoaded", function()
                error("spec: isPluginLoaded failed")
            end)
            local err = spy.on(logger, "err")
            cleanup(function()
                s:revert()
                err:revert()
            end)
            assert.same({ { text = "Terminal isn't available here." } },
                run_for_notes(plugin_entry("terminal")))
            assert.spy(err).was.called()
        end)

        it("say the plugin isn't loaded when it is loaded but its action is gone", function()
            fm_with_home()
            plugins_loaded({ terminal = true })
            assert.same({ { text = "Terminal: the terminal plugin isn't loaded." } },
                run_for_notes(plugin_entry("terminal", "kopanda_spec_no_such_action")))
        end)

        it("re-check a folder at tap time: removed after resolving, it gives the note, not a climb", function()
            local fm = fm_with_home()
            local dir = temp_dir("launcher-gone-dir")
            local entry = directory_entry(dir)
            assert.equals("ready", LauncherEntries.resolve(entry).state)
            assert(lfs.rmdir(dir))
            local change = spy.on(fm.file_chooser, "changeToPath")
            cleanup(function()
                change:revert()
            end)
            assert.same({ { text = "Downloads: " .. dir .. " isn't there." } }, run_for_notes(entry))
            assert.spy(change).was_not.called()
            assert.equals(Home.shown, harness.top())
        end)
    end)
end)
