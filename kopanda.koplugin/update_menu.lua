-- Check for update, the row under Tools › KoPanda and in the settings menu: installs GitHub's latest release
-- (release_source.lua) when it is newer, pulling it behind a painted note (push_pull.lua), and offers the restart that
-- applies it. A pull blocks the UI; nothing redraws until it ends. Every callback catches its own errors.
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Event = require("ui/event")
local Guards = require("guards")
local Helpers = require("helpers")
local InfoMessage = require("ui/widget/infomessage")
local PushPull = require("push_pull")
local ReleaseSource = require("release_source")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local UpdateMenu = {}

-- NetworkMgr, looked up at call time so a spec can stub it.
local function network()
    return require("ui/network/manager")
end

-- Asks to restart now so the apply patch applies the stage, naming it as name; Later leaves it
-- armed for the next start. Restart closes the menu and the app and quits with 85
-- (frontend/device/devicelistener.lua:454-456).
local function offer_restart(name)
    UIManager:show(ConfirmBox:new{
        text = "Restart to apply " .. name .. "?",
        ok_text = "Restart",
        cancel_text = "Later",
        ok_callback = Guards.guarded("Tools › KoPanda › Check for update › Restart", function()
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

-- Once connected, compares GitHub's latest release with the version installed in plugin.path and, when
-- it is newer, confirms and installs it: the plugin only, the settings file kept. A failure is logged as
-- what's, the menu path it ran from.
function UpdateMenu.check_for_update(plugin, what)
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

local CHECK = "Tools › KoPanda › Check for update"

-- The Check for update row for the plugin instance plugin, whose path is its folder
-- (frontend/pluginloader.lua:248).
function UpdateMenu.item(plugin)
    return {
        text = "Check for update",
        callback = Guards.after_menu(CHECK, function()
            UpdateMenu.check_for_update(plugin, CHECK)
        end),
    }
end

return UpdateMenu
