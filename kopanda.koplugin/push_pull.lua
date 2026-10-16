-- The pull: fetches a profile's bundle from the studio over the LAN, verifies it, stages it in
-- settings/kopanda/push/ and arms the apply patch (push_apply.lua) for the next start.
-- Synchronous and UI-free; each call returns its value or true, or nil, a message and, for a
-- request the studio answered with another status, that status.
local PushApply = require("push_apply")
local PushBundle = require("push_bundle")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local rapidjson = require("rapidjson")
local socketutil = require("socketutil")
local util = require("util")

local PushPull = {}

local FORMAT = 1
local PLUGIN_FOLDER = "kopanda.koplugin"

-- The studio's base URL for an address typed as host:port: trimmed, http:// added when it has no
-- scheme, trailing slashes dropped.
function PushPull.base_url(address)
    local base = util.trim(address or ""):gsub("/+$", "")
    if not base:find("://", 1, true) then
        base = "http://" .. base
    end
    return base
end

-- GETs url into the sink make_sink returns, which is made once the timeouts are set: socketutil's
-- sinks read the total timeout when they are made (frontend/socketutil.lua:98-140). socket.http
-- is looked up here, not at load, so a spec can stub it, and the timeouts are reset on every
-- path, a raising request included. Returns true, or nil, why and the status.
local function request(url, make_sink)
    local http = require("socket.http")
    socketutil:set_timeout(socketutil.FILE_BLOCK_TIMEOUT, socketutil.FILE_TOTAL_TIMEOUT)
    local ok, result, code, headers = pcall(function()
        return http.request{
            url = url,
            method = "GET",
            headers = { ["Accept-Encoding"] = "identity" },
            sink = make_sink(),
        }
    end)
    socketutil:reset_timeout()
    if not ok then
        return nil, "the request raised: " .. tostring(result)
    end
    if result == nil then
        return nil, tostring(code)
    end
    if headers == nil then
        return nil, "no response: " .. tostring(code)
    end
    if code ~= 200 then
        return nil, "HTTP status " .. tostring(code), code
    end
    return true
end

-- The decoded JSON body of url, or nil, why and the status. A refusal's own { error } is added
-- to why.
local function fetch_json(url)
    local chunks = {}
    local ok, why, code = request(url, function()
        return socketutil.table_sink(chunks)
    end)
    local decoded_ok, decoded = pcall(rapidjson.decode, table.concat(chunks))
    if not decoded_ok then
        decoded = nil
    end
    if not ok then
        if type(decoded) == "table" and type(decoded.error) == "string" then
            why = why .. " (" .. decoded.error .. ")"
        end
        return nil, why, code
    end
    if decoded == nil then
        return nil, "the answer is not JSON"
    end
    return decoded
end

-- GETs url into the file at path. Returns true, or nil, why and the status.
local function fetch_file(url, path)
    local handle, open_err = io.open(path, "wb")
    if not handle then
        return nil, "could not write it: " .. tostring(open_err)
    end
    local ok, why, code = request(url, function()
        return socketutil.file_sink(handle)
    end)
    -- The sink closes the file at the body's end; a failed request may not get there.
    if io.type(handle) == "file" then
        handle:close()
    end
    return ok, why, code
end

-- The studio's profiles as { id, name } in its order, or nil and why.
function PushPull.fetch_profiles(address)
    local doc, why = fetch_json(PushPull.base_url(address) .. "/api/push/profiles")
    if not doc then
        return nil, "Couldn't get the studio's profiles: " .. why
    end
    if type(doc) ~= "table" or type(doc.profiles) ~= "table" then
        return nil, "The studio's answer lists no profiles."
    end
    local profiles = {}
    for _, profile in ipairs(doc.profiles) do
        if type(profile) == "table" and type(profile.id) == "string" then
            profiles[#profiles + 1] = {
                id = profile.id,
                name = type(profile.name) == "string" and profile.name or profile.id,
            }
        end
    end
    return profiles
end

-- The running plugin's folder made absolute (on the Kindle the loader's path is relative,
-- frontend/pluginloader.lua:24, :204), with doubled slashes collapsed (under KO_HOME it is
-- <KO_HOME>/plugins//kopanda.koplugin, :196, :204) and trailing ones dropped.
function PushPull.absolute_plugin_dir(plugin_dir)
    local path = plugin_dir
    if path:sub(1, 1) ~= "/" then
        path = lfs.currentdir() .. "/" .. path
    end
    path = path:gsub("//+", "/"):gsub("(.)/$", "%1")
    return path
end

local function present(value)
    return type(value) == "string" and util.trim(value) ~= ""
end

-- Why a pull with opts can't start, before anything is fetched or written; nil when it can.
function PushPull.refusal(opts)
    if not present(opts.address) then
        return "Set the studio's address first."
    end
    if not present(opts.profile) then
        return "Choose a profile first."
    end
    local paths = PushApply.paths(opts.data_dir)
    if lfs.symlinkattributes(paths.patches .. "/.patches_disabled", "mode") then
        return "User patches are disabled (patches/.patches_disabled), so a pull would never be applied."
    end
    if PushApply.probation(opts.data_dir) then
        return "The last pull is on probation: its home hasn't drawn yet."
    end
    if type(opts.plugin_dir) ~= "string" or opts.plugin_dir == "" then
        return "KoPanda can't tell which folder it runs from, so a pull can't replace it."
    end
    local folder = PushPull.absolute_plugin_dir(opts.plugin_dir):match("[^/]+$")
    if folder ~= PLUGIN_FOLDER then
        return "KoPanda runs from " .. tostring(folder) .. ", not a folder named " .. PLUGIN_FOLDER
            .. ", so a pull can't replace it."
    end
end

-- Raises err unless ok, so a helper that returns nil, err can stop the pull.
local function must(ok, err)
    if not ok then
        error(tostring(err), 0)
    end
    return ok
end

-- Fetches the manifest and every file into download/ and verifies them. Returns the manifest,
-- or nil, why and the status.
local function download(paths, base, profile)
    local doc, why, code = fetch_json(base .. "/api/push/" .. profile .. "/manifest")
    if doc == nil then
        return nil, "Couldn't get " .. profile .. "'s manifest from the studio: " .. why .. ".", code
    end
    local manifest, invalid = PushBundle.check_manifest(doc, profile)
    if not manifest then
        return nil, "The studio's manifest for " .. profile .. " is refused: " .. invalid .. "."
    end
    for _, file in ipairs(manifest.files) do
        local target = paths.download .. "/" .. file.path
        local folder = target:match("^(.*)/[^/]+$")
        local made, make_err = util.makePath(folder)
        if not made then
            return nil, "Couldn't download " .. file.path .. ": " .. tostring(make_err) .. "."
        end
        local url = base .. "/api/push/" .. profile .. "/files/" .. manifest.hash .. "/" .. file.path
        local ok, file_why, file_code = fetch_file(url, target)
        if file_code == 409 then
            return nil, profile .. " changed in the studio during the pull; pull again.", 409
        end
        if not ok then
            return nil, "Couldn't download " .. file.path .. ": " .. file_why .. ".", file_code
        end
    end
    local verified, mismatch = PushBundle.verify_files(paths.download, manifest)
    if not verified then
        return nil, "The pulled bundle is refused: " .. mismatch .. "."
    end
    return manifest
end

-- Replaces any earlier stage with download/: the record removed first, written last.
local function stage(paths, manifest, opts)
    must(PushApply._purge(paths.staged_record))
    must(PushApply._purge(paths.staged))
    local ok, err = os.rename(paths.download, paths.staged)
    if not ok then
        error("could not move the download into place: " .. tostring(err), 0)
    end
    PushApply._write_record(paths.staged_record, {
        format = FORMAT,
        profile = manifest.profile,
        hash = manifest.hash,
        plugin_dir = PushPull.absolute_plugin_dir(opts.plugin_dir),
        disable = opts.disable or {},
        at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
end

-- Pulls opts.profile from the studio at opts.address into opts.data_dir for the plugin running
-- from opts.plugin_dir, recording opts.disable (runtime plugin names) to be disabled at the
-- apply. Returns true once staged and armed; nil, a message and maybe a status otherwise, with
-- download/ purged and an earlier stage as it was unless staging itself failed.
function PushPull.pull(opts)
    local refused = PushPull.refusal(opts)
    if refused then
        return nil, refused
    end
    local paths = PushApply.paths(opts.data_dir)
    local profile = opts.profile
    local ok, result, why, code = pcall(function()
        must(PushApply._purge(paths.download))
        must(util.makePath(paths.download))
        local manifest, download_why, download_code = download(paths, PushPull.base_url(opts.address), profile)
        if not manifest then
            return nil, download_why, download_code
        end
        stage(paths, manifest, opts)
        local armed, arm_err = PushApply.arm(PushPull.absolute_plugin_dir(opts.plugin_dir), opts.data_dir)
        if not armed then
            must(PushApply._purge(paths.staged_record))
            return nil, "Couldn't arm the apply patch: " .. tostring(arm_err) .. "."
        end
        return true
    end)
    if not ok then
        result, why, code = nil, "The pull failed: " .. tostring(result) .. ".", nil
    end
    if not result then
        local purged, purge_err = pcall(function()
            must(PushApply._purge(paths.download))
        end)
        if not purged then
            logger.err("KoPanda: could not remove the pull's download:", purge_err)
        end
        return nil, why, code
    end
    return true
end

return PushPull
