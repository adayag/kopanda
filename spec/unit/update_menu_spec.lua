-- Check for update, through the plugin harness: in Tools › KoPanda's normal and refused menus before Swatches, on the
-- plugin's own folder; comparing GitHub's latest release with the installed version and installing a newer one behind
-- a painted note, then offering the restart. NetworkMgr:runWhenConnected, PushPull.pull and ReleaseSource are stubbed;
-- no test touches the network.
describe("Check for update", function()
    local harness = require("plugin_harness")
    local ConfirmBox = require("ui/widget/confirmbox")
    local DataStorage = require("datastorage")
    local InfoMessage = require("ui/widget/infomessage")
    local NetworkMgr = require("ui/network/manager")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local PushPull, ReleaseSource, UpdateMenu
    -- What the UI did, in order; the stubs, reverted after each test.
    local events, stubs

    -- Another shell enabled, so KoPanda refuses.
    local function refuse()
        table.insert(PluginLoader.enabled_plugins, { name = "simpleui" })
    end

    -- Tools › KoPanda in a menu's tabs.
    local function kopanda_item(tabs)
        for _, tab in ipairs(tabs) do
            if tab.id == "tools" then
                for _, item in ipairs(tab) do
                    if item.id == "kopanda" then
                        return item
                    end
                end
            end
        end
        error("no Tools › KoPanda")
    end

    local function texts(items)
        local list = {}
        for _, item in ipairs(items) do
            list[#list + 1] = item.text or item.text_func()
        end
        return list
    end

    -- The Check for update item of the file manager's menu.
    local function update_item()
        local fm = harness.show_fm()
        fm.menu:onShowMenu()
        local items = kopanda_item(fm.menu.tab_item_table).sub_item_table
        fm.menu:onCloseFileManagerMenu()
        for _, item in ipairs(items) do
            if item.text == "Check for update" then
                return item
            end
        end
        error("no Tools › KoPanda › Check for update")
    end

    -- Taps item as TouchMenu does, then runs the tick it acts from.
    local function tap(item)
        item.callback()
        harness.tick()
    end

    local function shown(class)
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == class then
                return widget
            end
        end
    end

    before_each(function()
        harness.load()
        PushPull = require("push_pull")
        ReleaseSource = require("release_source")
        UpdateMenu = require("update_menu")
        events = {}
        local show, close, repaint = UIManager.show, UIManager.close, UIManager.forceRePaint
        stubs = {
            run_when_connected = stub(NetworkMgr, "runWhenConnected", function(_, callback)
                events[#events + 1] = "connected"
                callback()
            end),
            show = stub(UIManager, "show", function(self, widget, ...)
                if getmetatable(widget) == InfoMessage then
                    events[#events + 1] = "show " .. widget.text
                end
                return show(self, widget, ...)
            end),
            close = stub(UIManager, "close", function(self, widget, ...)
                if getmetatable(widget) == InfoMessage then
                    events[#events + 1] = "close " .. widget.text
                end
                return close(self, widget, ...)
            end),
            repaint = stub(UIManager, "forceRePaint", function(self, ...)
                events[#events + 1] = "paint"
                return repaint(self, ...)
            end),
            broadcast = stub(UIManager, "broadcastEvent", function(_, event)
                events[#events + 1] = "broadcast " .. event.handler
            end),
        }
    end)

    after_each(function()
        for _, s in pairs(stubs) do
            s:revert()
        end
        harness.teardown()
    end)

    describe("in Tools › KoPanda", function()
        it("comes before Swatches, with no Studio row, in the file manager's and the reader's normal menu", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.same({ "Home", "Settings", "Check for update", "Swatches" },
                texts(kopanda_item(fm.menu.tab_item_table).sub_item_table))
            fm.menu:onCloseFileManagerMenu()
            fm:onClose()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            assert.same({ "Home", "Settings", "Check for update", "Swatches" },
                texts(kopanda_item(reader.menu.tab_item_table).sub_item_table))
        end)

        it("comes before Swatches, with no Studio row, in the menu kept while another shell is enabled", function()
            refuse()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.same({ "Check for update", "Swatches" }, texts(kopanda_item(fm.menu.tab_item_table).sub_item_table))
        end)

        it("closes the menu when tapped, having no submenu", function()
            local item = update_item()
            assert.is_falsy(item.keep_menu_open)
            assert.is_nil(item.sub_item_table)
        end)

        for name, setup in pairs{ normal = function() end, refused = refuse } do
            it("runs the check on the plugin's folder, a tick after the tap, in the " .. name .. " menu", function()
                setup()
                local checked = {}
                stubs.check = stub(UpdateMenu, "check_for_update", function(plugin, what)
                    checked[#checked + 1] = { path = plugin.path, what = what }
                end)
                local item = update_item()
                item.callback()
                assert.same({}, checked)
                harness.tick()
                assert.same({ { path = harness.plugin_dir, what = "Tools › KoPanda › Check for update" } }, checked)
            end)
        end
    end)

    describe("the check", function()
        local pulls, sources, installed_from
        local RELEASE = {
            version = "0.2.0",
            notes = "- home: a quieter clock",
            manifest_url = "https://github.com/adayag/kopanda/releases/download/v0.2.0/manifest.json",
            zip_url = "https://github.com/adayag/kopanda/releases/download/v0.2.0/kopanda.koplugin.zip",
        }
        local function source_of() end

        -- ReleaseSource answers latest with latest and why, and installed with installed;
        -- PushPull.pull answers ok and message.
        local function stub_release(latest, why, installed, ok, message)
            pulls, sources, installed_from = {}, {}, {}
            stubs.latest = stub(ReleaseSource, "latest", function()
                events[#events + 1] = "latest"
                return latest, why
            end)
            stubs.installed = stub(ReleaseSource, "installed_version", function(plugin_dir)
                installed_from[#installed_from + 1] = plugin_dir
                return installed or "0.1.3"
            end)
            stubs.source = stub(ReleaseSource, "source", function(release)
                sources[#sources + 1] = release
                return source_of
            end)
            stubs.pull = stub(PushPull, "pull", function(opts)
                pulls[#pulls + 1] = opts
                events[#events + 1] = "pull"
                return ok, message
            end)
        end

        local function check()
            tap(update_item())
        end

        -- The events of a check: connected, then latest behind its painted note, then rest.
        local function checked(...)
            return { "connected", "show Checking for an update…", "paint", "latest", "close Checking for an update…",
                ... }
        end

        it("says the installed version is the latest when no release is newer", function()
            for _, latest in ipairs{ "0.1.3", "0.1.2" } do
                stub_release({ version = latest, notes = "", manifest_url = "m", zip_url = "z" }, nil, "0.1.3")
                events = {}
                check()
                assert.same(checked("show KoPanda 0.1.3 is the latest."), events)
                assert.same({ harness.plugin_dir }, installed_from)
                assert.is_nil(shown(ConfirmBox))
                assert.same({}, pulls)
                UIManager:close(harness.top())
                for _, name in ipairs{ "latest", "installed", "source", "pull" } do
                    stubs[name]:revert()
                end
            end
        end)

        it("shows why when the latest release can't be read, installing nothing", function()
            stub_release(nil, "kopanda-test: No release yet.")
            check()
            assert.same(checked("show kopanda-test: No release yet."), events)
            assert.is_nil(shown(ConfirmBox))
            assert.same({}, pulls)
        end)

        it("offers a newer release with its notes, installs it behind a painted note and offers the restart",
            function()
            stub_release(RELEASE, nil, "0.1.3", true)
            check()
            local confirm = assert(shown(ConfirmBox), "no install confirm")
            assert.truthy(confirm.text:find("0.2.0", 1, true))
            assert.truthy(confirm.text:find("0.1.3", 1, true))
            assert.truthy(confirm.text:find("- home: a quieter clock", 1, true))
            assert.equals("Install", confirm.ok_text)
            assert.same({}, pulls)
            confirm.ok_callback()
            UIManager:close(confirm)
            assert.same(checked("connected", "show Installing v0.2.0…", "paint", "pull", "close Installing v0.2.0…"),
                events)
            assert.same({ RELEASE }, sources)
            assert.same({ {
                profile = "release",
                source = source_of,
                data_dir = DataStorage:getDataDir(),
                plugin_dir = harness.plugin_dir,
            } }, pulls)
            local restart = assert(shown(ConfirmBox), "no restart offer")
            assert.equals("Restart to apply v0.2.0?", restart.text)
            assert.equals("Restart", restart.ok_text)
            assert.equals("Later", restart.cancel_text)
            restart.ok_callback()
            assert.equals("broadcast onRestart", events[#events])
        end)

        it("doesn't restart on the restart offer's Later button", function()
            stub_release(RELEASE, nil, "0.1.3", true)
            check()
            local confirm = assert(shown(ConfirmBox))
            confirm.ok_callback()
            UIManager:close(confirm)
            assert(shown(ConfirmBox), "no restart offer").cancel_callback()
            assert.same(checked("connected", "show Installing v0.2.0…", "paint", "pull", "close Installing v0.2.0…"),
                events)
        end)

        it("names its menu path for a restart that fails", function()
            stub_release(RELEASE, nil, "0.1.3", true)
            check()
            local confirm = assert(shown(ConfirmBox))
            confirm.ok_callback()
            UIManager:close(confirm)
            local restart = assert(shown(ConfirmBox), "no restart offer")
            stubs.broadcast:revert()
            stubs.broadcast = stub(UIManager, "broadcastEvent", function()
                error("kopanda-test: no restart")
            end)
            local logged = {}
            stubs.err = stub(logger, "err", function(...)
                logged[#logged + 1] = table.concat({ ... }, " ")
            end)
            restart.ok_callback()
            assert.equals(1, #logged, table.concat(logged, "\n"))
            assert.truthy(logged[1]:find("Tools › KoPanda › Check for update › Restart failed", 1, true), logged[1])
            assert.truthy(logged[1]:find("kopanda-test: no restart", 1, true), logged[1])
        end)

        it("installs a release over a version that isn't one", function()
            stub_release(RELEASE, nil, "0.0.0-dev", true)
            check()
            assert.truthy(assert(shown(ConfirmBox)).text:find("0.2.0", 1, true))
        end)

        it("installs nothing when the confirm is cancelled", function()
            stub_release(RELEASE, nil, "0.1.3", true)
            check()
            assert(shown(ConfirmBox)).cancel_callback()
            assert.same({}, pulls)
            assert.same(checked(), events)
        end)

        it("shows a failed install's message", function()
            stub_release(RELEASE, nil, "0.1.3", nil, "kopanda-test: The release is refused.")
            check()
            local confirm = assert(shown(ConfirmBox))
            confirm.ok_callback()
            UIManager:close(confirm)
            assert.equals("show kopanda-test: The release is refused.", events[#events])
            assert.is_nil(shown(ConfirmBox))
        end)

        it("closes the note and says so when the pull raises", function()
            stub_release(RELEASE, nil, "0.1.3", true)
            stubs.pull:revert()
            stubs.pull = stub(PushPull, "pull", function()
                error("kopanda-test: no pull")
            end)
            local logged = {}
            stubs.err = stub(logger, "err", function(...)
                logged[#logged + 1] = table.concat({ ... }, " ")
            end)
            check()
            local confirm = assert(shown(ConfirmBox))
            confirm.ok_callback()
            UIManager:close(confirm)
            assert.same(checked("connected", "show Installing v0.2.0…", "paint", "close Installing v0.2.0…",
                "show The pull failed."), events)
            assert.is_nil(shown(ConfirmBox))
            assert.equals(1, #logged, table.concat(logged, "\n"))
            assert.truthy(logged[1]:find("kopanda-test: no pull", 1, true), logged[1])
        end)

        it("shows a refusal before the confirm, installing nothing", function()
            stub_release(RELEASE, nil, "0.1.3", true)
            local lfs = require("libs/libkoreader-lfs")
            local push = DataStorage:getSettingsDir() .. "/kopanda/push"
            local made = lfs.mkdir(DataStorage:getSettingsDir() .. "/kopanda")
            lfs.mkdir(push)
            local f = assert(io.open(push .. "/probation.lua", "wb"))
            f:write("return {}\n")
            f:close()
            finally(function()
                os.remove(push .. "/probation.lua")
                lfs.rmdir(push)
                if made then
                    lfs.rmdir(DataStorage:getSettingsDir() .. "/kopanda")
                end
            end)
            check()
            assert.is_nil(shown(ConfirmBox))
            assert.same({}, pulls)
            assert.truthy(events[#events]:find("probation", 1, true))
        end)
    end)
end)
