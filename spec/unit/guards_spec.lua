-- The two safety nets around the shell: KoPanda refuses its home while another shell plugin is
-- enabled (C11), and a home that did not finish drawing last time is skipped once (C12).
describe("KoPanda's guards", function()
    local harness = require("plugin_harness")
    local FileManager = require("apps/filemanager/filemanager")
    local InfoMessage = require("ui/widget/infomessage")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Home, messages
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

    before_each(function()
        harness.load()
        Home = require("home")
        -- Every InfoMessage shown, whether or not its timeout has closed it since.
        messages = {}
        UIManager.show = function(self, widget, ...)
            if getmetatable(widget) == InfoMessage then
                messages[#messages + 1] = widget.text
            end
            return original_show(self, widget, ...)
        end
    end)

    after_each(function()
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
end)
