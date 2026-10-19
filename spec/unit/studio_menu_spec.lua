-- Tools › KoPanda › Studio (C7), through the plugin harness: in the normal and the refused menu
-- before Swatches; its address and profile kept in state.lua as studio_address and
-- studio_profile; Pull enabled once both are set, confirming, pulling behind a painted note and
-- offering the restart; Check for update comparing GitHub's latest release with the installed
-- version and installing a newer one the same way. socket.http's request,
-- NetworkMgr:runWhenConnected, PushPull.pull and ReleaseSource are stubbed; no test touches the
-- network or stages a pull.
describe("the Studio menu", function()
    local harness = require("plugin_harness")
    local ButtonDialog = require("ui/widget/buttondialog")
    local ConfirmBox = require("ui/widget/confirmbox")
    local DataStorage = require("datastorage")
    local InfoMessage = require("ui/widget/infomessage")
    local InputDialog = require("ui/widget/inputdialog")
    local NetworkMgr = require("ui/network/manager")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local http = require("socket.http")
    local State, PushPull, ReleaseSource
    -- What the UI did, in order; the requests made; the stubs, reverted after each test.
    local events, requests, stubs

    local function enable(...)
        for _, name in ipairs{ ... } do
            table.insert(PluginLoader.enabled_plugins, { name = name })
        end
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

    -- The Studio item of an open menu.
    local function studio_of(menu)
        for _, item in ipairs(kopanda_item(menu.tab_item_table).sub_item_table) do
            if item.text == "Studio" then
                return item
            end
        end
        error("no Tools › KoPanda › Studio")
    end

    -- The Address, Profile, Pull and Check for update items of the file manager's menu.
    local function studio_items()
        local fm = harness.show_fm()
        fm.menu:onShowMenu()
        local items = studio_of(fm.menu).sub_item_table
        fm.menu:onCloseFileManagerMenu()
        return items[1], items[2], items[3], items[4]
    end

    -- A stand-in for the TouchMenu a callback gets.
    local function touchmenu()
        local menu = { updates = 0 }
        function menu:updateItems()
            self.updates = self.updates + 1
        end
        return menu
    end

    -- Taps item as TouchMenu does, then runs the tick it acts from.
    local function tap(item, menu)
        item.callback(menu or touchmenu())
        harness.tick()
    end

    local function shown(class)
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == class then
                return widget
            end
        end
    end

    local function button(button_table, text)
        for _, row in ipairs(button_table.buttons_layout) do
            for _, b in ipairs(row) do
                if b.text == text then
                    return b
                end
            end
        end
        error("no button " .. text)
    end

    local function button_texts(button_table)
        local list = {}
        for _, row in ipairs(button_table.buttons_layout) do
            for _, b in ipairs(row) do
                list[#list + 1] = b.text
            end
        end
        return list
    end

    local function has(list, value)
        for _, v in ipairs(list) do
            if v == value then
                return true
            end
        end
        return false
    end

    -- The stored state file's value of key, read from disk.
    local function stored(key)
        local ok, data = pcall(dofile, harness.state_file)
        return ok and type(data) == "table" and data[key] or nil
    end

    before_each(function()
        harness.load()
        State = require("state")
        PushPull = require("push_pull")
        ReleaseSource = require("release_source")
        events, requests = {}, {}
        local show, close, repaint = UIManager.show, UIManager.close, UIManager.forceRePaint
        stubs = {
            request = stub(http, "request", function(request)
                requests[#requests + 1] = request.url
                local body = '{"profiles":[{"id":"colorsoft","name":"Colorsoft","device":"kindle"},'
                    .. '{"id":"vector","name":"Vector","device":"kindle"}]}'
                request.sink(body)
                request.sink(nil)
                return 1, 200, {}, "HTTP/1.1 200 OK"
            end),
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
        it("comes before Swatches in the normal menu of the file manager and the reader", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.same({ "Home", "Settings", "Studio", "Swatches" },
                texts(kopanda_item(fm.menu.tab_item_table).sub_item_table))
            fm.menu:onCloseFileManagerMenu()
            fm:onClose()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            assert.same({ "Home", "Settings", "Studio", "Swatches" },
                texts(kopanda_item(reader.menu.tab_item_table).sub_item_table))
        end)

        it("comes before Swatches in the menu kept while another shell is enabled", function()
            enable("simpleui")
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.same({ "Studio", "Swatches" }, texts(kopanda_item(fm.menu.tab_item_table).sub_item_table))
        end)

        it("ends with Check for update", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local items = studio_of(fm.menu).sub_item_table
            assert.equals(4, #items)
            assert.equals("Check for update", items[4].text)
            assert.is_falsy(items[4].keep_menu_open)
        end)

        it("holds Address, Profile and Pull, read afresh each time the menu draws", function()
            local address, profile, pull = studio_items()
            assert.same({ "Address: not set", "Profile: not chosen", "Pull" }, texts{ address, profile, pull })
            assert.is_true(State.set("studio_address", "192.168.1.20:4490"))
            assert.is_true(State.set("studio_profile", "vector"))
            assert.same({ "Address: 192.168.1.20:4490", "Profile: vector", "Pull vector" },
                texts{ address, profile, pull })
            assert.is_true(address.keep_menu_open)
            assert.is_true(profile.keep_menu_open)
            assert.is_falsy(pull.keep_menu_open)
        end)
    end)

    describe("Address", function()
        it("asks with the hint and saves the address trimmed", function()
            local address = studio_items()
            local menu = touchmenu()
            tap(address, menu)
            local dialog = assert(shown(InputDialog), "no address dialog")
            assert.equals("192.168.1.20:4490", dialog.input_hint)
            dialog:setInputText("  192.168.1.20:4490 ")
            button(dialog.button_table, "Save").callback()
            assert.equals("192.168.1.20:4490", State.get("studio_address"))
            assert.equals("192.168.1.20:4490", stored("studio_address"))
            assert.is_nil(shown(InputDialog))
            assert.equals(1, menu.updates)
            assert.equals("Address: 192.168.1.20:4490", address.text_func())
        end)

        it("shows the stored address and clears it when emptied", function()
            assert.is_true(State.set("studio_address", "192.168.1.20:4490"))
            local address = studio_items()
            tap(address)
            local dialog = assert(shown(InputDialog))
            assert.equals("192.168.1.20:4490", dialog:getInputText())
            dialog:setInputText("   ")
            button(dialog.button_table, "Save").callback()
            assert.is_nil(State.get("studio_address"))
            assert.is_nil(stored("studio_address"))
            assert.equals("Address: not set", address.text_func())
        end)

        it("changes nothing on Cancel", function()
            assert.is_true(State.set("studio_address", "192.168.1.20:4490"))
            local address = studio_items()
            tap(address)
            local dialog = assert(shown(InputDialog))
            dialog:setInputText("10.0.0.2:4490")
            button(dialog.button_table, "Cancel").callback()
            assert.equals("192.168.1.20:4490", State.get("studio_address"))
            assert.is_nil(shown(InputDialog))
        end)
    end)

    describe("Profile", function()
        it("lists the studio's profiles once connected and saves the choice", function()
            assert.is_true(State.set("studio_address", "192.168.1.20:4490"))
            local _, profile = studio_items()
            local menu = touchmenu()
            tap(profile, menu)
            assert.same({ "connected" }, events)
            assert.same({ "http://192.168.1.20:4490/api/push/profiles" }, requests)
            local dialog = assert(shown(ButtonDialog), "no profile chooser")
            assert.same({ "Colorsoft", "Vector", "Cancel" }, button_texts(dialog.buttontable))
            button(dialog.buttontable, "Vector").callback()
            assert.equals("vector", State.get("studio_profile"))
            assert.equals("vector", stored("studio_profile"))
            assert.is_nil(shown(ButtonDialog))
            assert.equals(1, menu.updates)
            assert.equals("Profile: vector", profile.text_func())
        end)

        it("says so and requests nothing with no address", function()
            local _, profile = studio_items()
            tap(profile)
            assert.same({}, requests)
            assert.is_nil(shown(ButtonDialog))
            assert.equals(1, #events)
            assert.truthy(events[1]:find("address", 1, true))
        end)
    end)

    describe("Pull", function()
        local pulls

        -- PushPull.pull answers ok, message and code, recording each call's options.
        local function stub_pull(ok, message, code)
            pulls = {}
            stubs.pull = stub(PushPull, "pull", function(opts)
                pulls[#pulls + 1] = opts
                events[#events + 1] = "pull"
                return ok, message, code
            end)
        end

        local function set_both()
            assert.is_true(State.set("studio_address", "192.168.1.20:4490"))
            assert.is_true(State.set("studio_profile", "vector"))
        end

        it("is disabled until the address and the profile are set", function()
            local _, _, pull = studio_items()
            assert.is_false(pull.enabled_func())
            assert.is_true(State.set("studio_address", "192.168.1.20:4490"))
            assert.is_false(pull.enabled_func())
            assert.is_true(State.set("studio_address", nil))
            assert.is_true(State.set("studio_profile", "vector"))
            assert.is_false(pull.enabled_func())
            assert.is_true(State.set("studio_address", "192.168.1.20:4490"))
            assert.is_true(pull.enabled_func())
        end)

        it("confirms, pulls behind a painted note and offers the restart", function()
            stub_pull(true)
            set_both()
            local _, _, pull = studio_items()
            tap(pull)
            local confirm = assert(shown(ConfirmBox), "no confirm")
            assert.equals("Pull vector from the studio? KoPanda and its settings on this Kindle are replaced by "
                .. "the studio's; settings changed only on this Kindle are lost.", confirm.text)
            assert.same({}, pulls)
            confirm.ok_callback()
            UIManager:close(confirm)
            assert.same({ "connected", "show Pulling vector…", "paint", "pull", "close Pulling vector…" }, events)
            assert.same({ {
                address = "192.168.1.20:4490",
                profile = "vector",
                data_dir = DataStorage:getDataDir(),
                plugin_dir = harness.plugin_dir,
                disable = {},
            } }, pulls)
            local restart = assert(shown(ConfirmBox), "no restart offer")
            assert.equals("Restart to apply vector?", restart.text)
            assert.equals("Restart", restart.ok_text)
            assert.equals("Later", restart.cancel_text)
            restart.ok_callback()
            assert.equals("broadcast onRestart", events[#events])
        end)

        it("does nothing on Later", function()
            stub_pull(true)
            set_both()
            local _, _, pull = studio_items()
            tap(pull)
            local confirm = assert(shown(ConfirmBox))
            confirm.ok_callback()
            UIManager:close(confirm)
            local count = #events
            local restart = assert(shown(ConfirmBox))
            restart.cancel_callback()
            assert.equals(count, #events)
        end)

        it("pulls nothing when the confirm is cancelled", function()
            stub_pull(true)
            set_both()
            local _, _, pull = studio_items()
            tap(pull)
            assert(shown(ConfirmBox)).cancel_callback()
            assert.same({}, pulls)
            assert.same({}, events)
        end)

        it("shows a failed pull's message", function()
            stub_pull(nil, "kopanda-test: vector changed in the studio during the pull; pull again.", 409)
            set_both()
            local _, _, pull = studio_items()
            tap(pull)
            local confirm = assert(shown(ConfirmBox))
            confirm.ok_callback()
            UIManager:close(confirm)
            assert.equals("show kopanda-test: vector changed in the studio during the pull; pull again.",
                events[#events])
            assert.is_nil(shown(ConfirmBox))
        end)

        it("shows a refusal before the confirm, pulling nothing", function()
            stub_pull(true)
            set_both()
            local lfs = require("libs/libkoreader-lfs")
            local push = DataStorage:getSettingsDir() .. "/kopanda/push"
            lfs.mkdir(DataStorage:getSettingsDir() .. "/kopanda")
            lfs.mkdir(push)
            local f = assert(io.open(push .. "/probation.lua", "wb"))
            f:write("return {}\n")
            f:close()
            finally(function()
                os.remove(push .. "/probation.lua")
                lfs.rmdir(push)
            end)
            local _, _, pull = studio_items()
            tap(pull)
            assert.is_nil(shown(ConfirmBox))
            assert.same({}, pulls)
            assert.equals(1, #events)
            assert.truthy(events[1]:find("probation", 1, true))
        end)

        it("names the shells it turns off when one is enabled", function()
            stub_pull(true)
            set_both()
            enable("simpleui")
            local fm = harness.show_fm()
            harness.tick(2)
            UIManager:close(harness.top())
            fm.menu:onShowMenu()
            local pull = studio_of(fm.menu).sub_item_table[3]
            fm.menu:onCloseFileManagerMenu()
            tap(pull)
            local confirm = assert(shown(ConfirmBox))
            assert.truthy(confirm.text:find("SimpleUI, Bookshelf and ennUI are turned off at the restart.", 1, true))
            confirm.ok_callback()
            assert.same({ "simpleui" }, pulls[1].disable)
            assert.is_true(has(events, "pull"))
        end)
    end)

    describe("Check for update", function()
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
            local _, _, _, update = studio_items()
            tap(update)
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
