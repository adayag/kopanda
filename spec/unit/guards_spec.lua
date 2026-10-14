-- The two safety nets around the shell: KoPanda refuses its home while another shell plugin is
-- enabled (C11), and a home that did not finish drawing last time is skipped once (C12).
describe("KoPanda's guards", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local InfoMessage = require("ui/widget/infomessage")
    local LuaSettings = require("luasettings")
    local PluginLoader = require("pluginloader")
    local lfs = require("libs/libkoreader-lfs")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Home, messages, log, settled_listener
    local original_show = UIManager.show

    local function homes_on_stack()
        local count = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_home" then
                count = count + 1
            end
        end
        return count
    end

    local function contains(list, value)
        for _, v in ipairs(list) do
            if v == value then
                return true
            end
        end
        return false
    end

    before_each(function()
        harness.load()
        Home = require("home")
        -- Every InfoMessage shown, whether or not its timeout has closed it since.
        messages = {}
        -- The order of state writes, home shows and settled signals.
        log = {}
        UIManager.show = function(self, widget, ...)
            if getmetatable(widget) == InfoMessage then
                messages[#messages + 1] = widget.text
            elseif widget.name == "kopanda_home" then
                log[#log + 1] = "show home"
            end
            return original_show(self, widget, ...)
        end
    end)

    after_each(function()
        if settled_listener then
            UIManager.event_hook:unregister("KoPandaSettled", settled_listener)
            settled_listener = nil
        end
        UIManager.show = original_show
        harness.teardown()
    end)

    describe("coexistence", function()
        local function enable(...)
            for _, name in ipairs{ ... } do
                table.insert(PluginLoader.enabled_plugins, { name = name })
            end
        end

        it("refuses the home and names SimpleUI", function()
            enable("simpleui")
            harness.show_fm()
            harness.tick(2)
            assert.equals(0, homes_on_stack())
            assert.is_nil(Home.shown)
            assert.equals(1, #messages)
            assert.truthy(messages[1]:find("SimpleUI", 1, true))
        end)

        it("matches ennUI's folder name in any case", function()
            enable("ennUI")
            harness.show_fm()
            harness.tick(2)
            assert.equals(0, homes_on_stack())
            assert.equals(1, #messages)
            assert.truthy(messages[1]:find("ennUI", 1, true))
        end)

        it("names every conflicting plugin in one message", function()
            enable("bookshelf", "simpleui")
            harness.show_fm()
            harness.tick(2)
            assert.equals(0, homes_on_stack())
            assert.equals(1, #messages)
            assert.truthy(messages[1]:find("Bookshelf", 1, true))
            assert.truthy(messages[1]:find("SimpleUI", 1, true))
        end)

        it("raises the message once per process", function()
            enable("simpleui")
            harness.show_fm()
            harness.tick(2)
            FileManager.instance:onClose()
            harness.show_fm()
            harness.tick(2)
            assert.equals(0, homes_on_stack())
            assert.equals(1, #messages)
        end)

        it("leaves no pending home from a reader made while refused", function()
            enable("simpleui")
            local reader = harness.open_reader()
            harness.tick(2)
            reader:onClose()
            assert.is_nil(Home.pending)
            harness.show_fm()
            harness.tick(2)
            assert.equals(0, homes_on_stack())
        end)

        it("adds no Home tab, Tools entry or action", function()
            local Dispatcher = require("dispatcher")
            local register = spy.on(Dispatcher, "registerAction")
            finally(function()
                Dispatcher.registerAction:revert()
            end)
            enable("simpleui")
            local fm = harness.show_fm()
            -- The broadcast Dispatcher:init sends (frontend/dispatcher.lua:645).
            UIManager:broadcastEvent(Event:new("DispatcherRegisterActions"))
            fm.menu:onShowMenu()
            local ids = {}
            for _, tab in ipairs(fm.menu.tab_item_table) do
                ids[#ids + 1] = tab.id
                for _, item in ipairs(tab) do
                    ids[#ids + 1] = item.id
                end
            end
            local registered = {}
            for _, call in ipairs(register.calls) do
                registered[#registered + 1] = call.vals[2]
            end
            assert.truthy(#ids > 0)
            assert.is_false(contains(ids, "kopanda_home"))
            assert.is_false(contains(ids, "kopanda"))
            assert.is_false(contains(registered, "kopanda_home"))
        end)

        it("shows the home when no other shell is enabled", function()
            enable("hello")
            harness.show_fm()
            harness.tick(2)
            assert.equals(1, homes_on_stack())
            assert.same({}, messages)
        end)

        it("shows the home and logs when an enabled plugin has no name", function()
            local logged = spy.on(logger, "err")
            table.insert(PluginLoader.enabled_plugins, {})
            harness.show_fm()
            harness.tick(2)
            local found = false
            for _, call in ipairs(logged.calls) do
                if tostring(call.vals[1]):find("KoPanda: could not check", 1, true) then
                    found = true
                end
            end
            logger.err:revert()
            assert.equals(1, homes_on_stack())
            assert.is_true(found)
        end)
    end)

    describe("boot guard", function()
        local function stored()
            return LuaSettings:open(harness.state_file):readSetting("boot_pending")
        end

        local function read(path)
            local f = assert(io.open(path, "r"))
            local text = f:read("*a")
            f:close()
            return text
        end

        it("sets the flag before the first show and clears it from the settled callback", function()
            local State = require("state")
            local set = State.set
            State.set = function(key, value)
                log[#log + 1] = "set " .. key .. " " .. tostring(value)
                return set(key, value)
            end
            settled_listener = function()
                log[#log + 1] = "settled"
            end
            UIManager.event_hook:register("KoPandaSettled", settled_listener)
            harness.show_fm()
            harness.tick(2)
            assert.same({ "set boot_pending true", "show home", "settled", "set boot_pending false" }, log)
            assert.equals(1, homes_on_stack())
            assert.is_false(stored())
        end)

        it("skips the home once with a notice when the last show did not finish", function()
            lfs.mkdir(harness.state_dir)
            LuaSettings:open(harness.state_file):saveSetting("boot_pending", true):flush()
            local State = require("state")
            local set = State.set
            State.set = function(key, value)
                log[#log + 1] = "set " .. key .. " " .. tostring(value)
                return set(key, value)
            end
            harness.show_fm()
            harness.tick(2)
            assert.equals(0, homes_on_stack())
            assert.equals(1, #messages)
            assert.is_false(stored())
            -- The skipped show was the guarded one: the next show writes nothing.
            FileManager.instance:onClose()
            harness.show_fm()
            harness.tick(2)
            assert.equals(1, homes_on_stack())
            assert.equals(1, #messages)
            assert.same({ "set boot_pending false", "show home" }, log)
        end)

        it("leaves the file alone on later shows in the process", function()
            local fm = harness.show_fm()
            harness.tick(2)
            local before = read(harness.state_file)
            local long_ago = os.time() - 3600
            assert.truthy(lfs.touch(harness.state_file, long_ago, long_ago))
            Home.close()
            fm:handleEvent(Event:new("Show"))
            harness.tick(2)
            FileManager.instance:onClose()
            harness.show_fm()
            harness.tick(2)
            assert.equals(1, homes_on_stack())
            assert.equals(long_ago, lfs.attributes(harness.state_file, "modification"))
            assert.equals(before, read(harness.state_file))
        end)

        it("creates settings/kopanda and the file on the first show", function()
            assert.is_nil(lfs.attributes(harness.state_dir, "mode"))
            harness.show_fm()
            harness.tick(2)
            assert.equals("directory", lfs.attributes(harness.state_dir, "mode"))
            assert.equals("file", lfs.attributes(harness.state_file, "mode"))
        end)

        it("clears the flag when the home's build fails", function()
            Home.init = function()
                error("kopanda-test: build failed")
            end
            harness.show_fm()
            harness.tick(2)
            assert.equals(0, homes_on_stack())
            assert.is_false(stored())
        end)

        it("clears the flag when the home's paint fails", function()
            local InputContainer = require("ui/widget/container/inputcontainer")
            local paint = InputContainer.paintTo
            finally(function()
                InputContainer.paintTo = paint
            end)
            InputContainer.paintTo = function(self, ...)
                if self.name == "kopanda_home" then
                    error("kopanda-test: paint failed")
                end
                return paint(self, ...)
            end
            harness.show_fm()
            harness.tick(3)
            assert.equals(0, homes_on_stack())
            assert.is_false(stored())
        end)
    end)
end)
