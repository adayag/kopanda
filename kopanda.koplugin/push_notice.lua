-- The plugin's side of a pull's apply: the first painted home of a process ends probation, and
-- the apply patch's result (push_apply.lua) is shown once, over the home or, while another shell
-- refuses the home, from the file manager. Every step catches and logs its own errors.
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local PushApply = require("push_apply")
local ReleaseSource = require("release_source")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local PushNotice = {}

-- The notice's text for a release's result: the plugin only, from GitHub, the version read from
-- the running plugin's _meta.lua in plugin_dir. Nil for a kind it words as any pull's.
local function release_text(outcome, message, plugin_dir)
    if outcome.kind == "applied" then
        return string.format("KoPanda updated to %s from GitHub.", ReleaseSource.installed_version(plugin_dir))
    elseif outcome.kind == "rolled_back" then
        return "KoPanda's home didn't draw after the update from GitHub, so the previous KoPanda is back."
    elseif outcome.kind == "failed" then
        return string.format("KoPanda couldn't apply the update from GitHub: %s. Nothing changed.", message)
    end
end

-- The notice's text for a result, or nil for a kind it doesn't know.
local function text(outcome, plugin_dir)
    local profile = tostring(outcome.profile or "a profile")
    local message = tostring(outcome.message or "no reason given")
    if outcome.profile == "release" then
        local worded = release_text(outcome, message, plugin_dir)
        if worded then
            return worded
        end
    end
    if outcome.kind == "applied" then
        return string.format("KoPanda pulled %s from the studio (bundle %s).", profile,
            tostring(outcome.hash or ""):sub(1, 12))
    elseif outcome.kind == "rolled_back" then
        return string.format("KoPanda's home didn't draw after the pull of %s, so the previous KoPanda and its "
            .. "settings are back.", profile)
    elseif outcome.kind == "failed" then
        return string.format("KoPanda couldn't apply the pull of %s: %s. Nothing changed.", profile, message)
    elseif outcome.kind == "restore_failed" then
        return string.format("KoPanda couldn't restore the previous version: %s.", message)
    end
end

-- Takes the result and shows its notice from the next tick.
local function show_result(data_dir, plugin_dir)
    local ok, outcome = pcall(PushApply.take_result, data_dir)
    if not ok then
        logger.err("KoPanda: could not take the pull's result:", outcome)
        return
    end
    if not outcome then
        return
    end
    local notice = text(outcome, plugin_dir)
    if not notice then
        logger.err("KoPanda: the pull's result has an unknown kind:", outcome.kind)
        return
    end
    UIManager:nextTick(function()
        local shown, err = pcall(function()
            UIManager:show(InfoMessage:new{ text = notice })
        end)
        if not shown then
            logger.err("KoPanda: could not show the pull's notice:", err)
        end
    end)
end

-- The first home of the process painted: probation ends first, then the result is shown.
-- plugin_dir is the running plugin's folder (frontend/pluginloader.lua:248).
function PushNotice.on_painted(plugin_dir)
    local data_dir = DataStorage:getDataDir()
    local ok, err = pcall(function()
        if PushApply.probation(data_dir) then
            local cleared, clear_err = PushApply.clear_probation(data_dir)
            if not cleared then
                error(clear_err, 0)
            end
        end
    end)
    if not ok then
        logger.err("KoPanda: could not end the pull's probation:", err)
    end
    local shown, show_err = pcall(show_result, data_dir, plugin_dir)
    if not shown then
        logger.err("KoPanda: could not report the pull:", show_err)
    end
end

-- The home is refused: the result is shown in its place, unless an install is on probation,
-- whose restore at the next start reports instead. plugin_dir as on_painted's.
function PushNotice.on_refused(plugin_dir)
    local data_dir = DataStorage:getDataDir()
    local ok, on_probation = pcall(PushApply.probation, data_dir)
    if not ok then
        logger.err("KoPanda: could not check the pull's probation:", on_probation)
        return
    end
    if on_probation then
        return
    end
    local shown, show_err = pcall(show_result, data_dir, plugin_dir)
    if not shown then
        logger.err("KoPanda: could not report the pull:", show_err)
    end
end

return PushNotice
