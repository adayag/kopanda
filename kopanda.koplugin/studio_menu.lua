-- Tools › KoPanda › Studio: the studio's address and the profile to pull, kept in the runtime
-- state file as studio_address and studio_profile (device-only, never in the schema), Pull,
-- which confirms, pulls the profile's bundle behind a painted note (push_pull.lua) and offers
-- the restart that applies it, and Check for update, which installs GitHub's latest release
-- (release_source.lua) the same way when it is newer than the installed version. A pull blocks
-- the UI for its duration; nothing redraws until it ends. Every callback catches its own errors.
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Event = require("ui/event")
local Guards = require("guards")
local Helpers = require("helpers")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local PushPull = require("push_pull")
local ReleaseSource = require("release_source")
local State = require("state")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local util = require("util")

local StudioMenu = {}

local ADDRESS = "studio_address"
local PROFILE = "studio_profile"

-- NetworkMgr, looked up at call time so a spec can stub it.
local function network()
    return require("ui/network/manager")
end

-- The stored value of key when it is a non-empty string.
local function stored(key)
    local value = State.get(key)
    if type(value) == "string" and value ~= "" then
        return value
    end
end

local function refresh(touchmenu)
    if touchmenu then
        touchmenu:updateItems()
    end
end

local function edit_address(touchmenu)
    local what = "Tools › KoPanda › Studio › Address"
    local dialog
    dialog = InputDialog:new{
        title = "Studio address",
        input = stored(ADDRESS) or "",
        input_hint = "192.168.1.20:4490",
        buttons = { {
            {
                text = "Cancel",
                id = "close",
                callback = Guards.guarded(what, function()
                    UIManager:close(dialog)
                end),
            },
            {
                text = "Save",
                is_enter_default = true,
                callback = Guards.guarded(what, function()
                    local address = util.trim(dialog:getInputText())
                    UIManager:close(dialog)
                    -- An empty address clears the key: saveSetting(key, nil) deletes it
                    -- (frontend/luasettings.lua:102-105).
                    if address == "" then
                        address = nil
                    end
                    if not State.set(ADDRESS, address) then
                        Helpers.note("Couldn't save the address.")
                    end
                    refresh(touchmenu)
                end),
            },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

local function choose_profile(touchmenu)
    local what = "Tools › KoPanda › Studio › Profile"
    local address = stored(ADDRESS)
    if not address then
        Helpers.note("Set the studio's address first.")
        return
    end
    network():runWhenConnected(Guards.guarded(what, function()
        local profiles, why = PushPull.fetch_profiles(address)
        if not profiles then
            Helpers.note(why)
            return
        end
        if #profiles == 0 then
            Helpers.note("The studio has no profiles.")
            return
        end
        local dialog
        local buttons = {}
        for _, profile in ipairs(profiles) do
            buttons[#buttons + 1] = { {
                text = profile.name,
                callback = Guards.guarded(what, function()
                    UIManager:close(dialog)
                    if not State.set(PROFILE, profile.id) then
                        Helpers.note("Couldn't save the profile.")
                    end
                    refresh(touchmenu)
                end),
            } }
        end
        buttons[#buttons + 1] = { {
            text = "Cancel",
            callback = Guards.guarded(what, function()
                UIManager:close(dialog)
            end),
        } }
        dialog = ButtonDialog:new{ title = "Choose a profile", buttons = buttons }
        UIManager:show(dialog)
    end))
end

-- Asks to restart now so the apply patch applies the stage, naming it as name; Later leaves it
-- armed for the next start. Restart closes the menu and the app and quits with 85
-- (frontend/device/devicelistener.lua:454-456).
local function offer_restart(name)
    UIManager:show(ConfirmBox:new{
        text = "Restart to apply " .. name .. "?",
        ok_text = "Restart",
        cancel_text = "Later",
        ok_callback = Guards.guarded("Tools › KoPanda › Studio › Restart", function()
            UIManager:broadcastEvent(Event:new("Restart"))
        end),
    })
end

-- Pulls opts behind the painted note text, then offers the restart naming name, or shows why.
local function pull_behind_note(opts, text, name)
    -- Painted now: the pull blocks the UI loop that would paint it
    -- (frontend/ui/uimanager.lua:1404).
    local busy = InfoMessage:new{ text = text }
    UIManager:show(busy)
    UIManager:forceRePaint()
    local called, ok, why = pcall(PushPull.pull, opts)
    UIManager:close(busy)
    if not called then
        logger.err("KoPanda: the pull failed:", ok)
        Helpers.note("The pull failed.")
    elseif not ok then
        Helpers.note(why)
    else
        offer_restart(name)
    end
end

local function pull(plugin)
    local what = "Tools › KoPanda › Studio › Pull"
    local profile = stored(PROFILE)
    local opts = {
        address = stored(ADDRESS),
        profile = profile,
        data_dir = DataStorage:getDataDir(),
        plugin_dir = plugin.path,
        disable = Guards.enabled_shell_names(),
    }
    local refused = PushPull.refusal(opts)
    if refused then
        Helpers.note(refused)
        return
    end
    local text = "Pull " .. profile .. " from the studio? KoPanda and its settings on this Kindle are replaced "
        .. "by the studio's; settings changed only on this Kindle are lost."
    if #opts.disable > 0 then
        text = text .. " SimpleUI, Bookshelf and ennUI are turned off at the restart."
    end
    UIManager:show(ConfirmBox:new{
        text = text,
        ok_text = "Pull",
        ok_callback = Guards.guarded(what, function()
            network():runWhenConnected(Guards.guarded(what, function()
                pull_behind_note(opts, "Pulling " .. profile .. "…", profile)
            end))
        end),
    })
end

-- Once connected, compares GitHub's latest release with the installed version and, when it is
-- newer, confirms and installs it: the plugin only, the settings file kept.
local function check_for_update(plugin)
    local what = "Tools › KoPanda › Studio › Check for update"
    network():runWhenConnected(Guards.guarded(what, function()
        -- Painted now, as the pull's note is: the request blocks the UI loop.
        local busy = InfoMessage:new{ text = "Checking for an update…" }
        UIManager:show(busy)
        UIManager:forceRePaint()
        local called, release, why = pcall(ReleaseSource.latest)
        UIManager:close(busy)
        if not called then
            error(release, 0)
        end
        if not release then
            Helpers.note(why)
            return
        end
        local installed = ReleaseSource.installed_version(plugin.path)
        if ReleaseSource.compare(release.version, installed) <= 0 then
            Helpers.note("KoPanda " .. installed .. " is the latest.")
            return
        end
        local opts = {
            profile = "release",
            source = ReleaseSource.source(release),
            data_dir = DataStorage:getDataDir(),
            plugin_dir = plugin.path,
        }
        local refused = PushPull.refusal(opts)
        if refused then
            Helpers.note(refused)
            return
        end
        local name = "v" .. release.version
        local text = "KoPanda " .. release.version .. " is out; this Kindle has " .. installed .. "."
        if release.notes ~= "" then
            text = text .. "\n\n" .. release.notes
        end
        text = text .. "\n\nInstall it? KoPanda's settings on this Kindle are kept."
        UIManager:show(ConfirmBox:new{
            text = text,
            ok_text = "Install",
            ok_callback = Guards.guarded(what, function()
                network():runWhenConnected(Guards.guarded(what, function()
                    pull_behind_note(opts, "Installing " .. name .. "…", name)
                end))
            end),
        })
    end))
end

-- The Studio sub-menu for the plugin instance plugin, whose path is its folder
-- (frontend/pluginloader.lua:248). Item texts read the state each time the menu draws.
function StudioMenu.item(plugin)
    return {
        text = "Studio",
        sub_item_table = {
            {
                text_func = function()
                    return "Address: " .. (stored(ADDRESS) or "not set")
                end,
                keep_menu_open = true,
                callback = Guards.after_menu("Tools › KoPanda › Studio › Address", edit_address),
            },
            {
                text_func = function()
                    return "Profile: " .. (stored(PROFILE) or "not chosen")
                end,
                keep_menu_open = true,
                callback = Guards.after_menu("Tools › KoPanda › Studio › Profile", choose_profile),
            },
            {
                text_func = function()
                    local profile = stored(PROFILE)
                    return profile and "Pull " .. profile or "Pull"
                end,
                enabled_func = function()
                    return stored(ADDRESS) ~= nil and stored(PROFILE) ~= nil
                end,
                callback = Guards.after_menu("Tools › KoPanda › Studio › Pull", function()
                    pull(plugin)
                end),
            },
            {
                text = "Check for update",
                callback = Guards.after_menu("Tools › KoPanda › Studio › Check for update", function()
                    check_for_update(plugin)
                end),
            },
        },
    }
end

return StudioMenu
