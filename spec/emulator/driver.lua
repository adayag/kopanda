-- Headless emulator capture per device profile. capture{} builds a scratch KO_HOME, runs
-- the KOReader emulator offscreen with the plugin under test and the capture userpatch,
-- and returns the PNG the patch saved once the plugin signalled "KoPandaSettled".
local lfs = require("libs/libkoreader-lfs")
local profiles = require("emulator.profiles")

local M = {}

M.profiles = profiles

local PATCH_NAME = "2-kopanda-capture.lua"
-- BOOKINFO_DB_VERSION in the emulator's plugins/coverbrowser.koplugin/bookinfomanager.lua:22.
local BOOKINFO_DB_VERSION = 20201210
local LOG_TAIL_LINES = 40

-- Plugins the scratch profile disables, by folder name without .koplugin
-- (frontend/pluginloader.lua:210-215): the shells KoPanda replaces, and their icon pack.
M.disabled_plugins = { "simpleui", "bookshelf", "ennUI", "solariconpack" }

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function is_dir(path)
    return lfs.attributes(path, "mode") == "directory"
end

local function basename(path)
    return path:gsub("/+$", ""):match("([^/]+)$")
end

local function write_file(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

local function shell(command)
    return os.execute(command) == 0
end

local function log_tail(path)
    local text = read_file(path)
    if not text or text == "" then
        return "(empty log)"
    end
    local lines = {}
    for line in text:gmatch("[^\n]*\n?") do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    local first = math.max(1, #lines - LOG_TAIL_LINES + 1)
    return table.concat(lines, "", first)
end

-- Writes a scratch KO_HOME at dir for the named profile: settings.reader.lua, the plugin
-- copied under plugins/, and the capture patch under patches/ with each extra patch (a list
-- of paths) beside it. An extra patch's name must start with "2-", KOReader's late priority
-- (frontend/userpatch.lua:13), which reader.lua:190 applies before any plugin code runs, in
-- natural-sort order of the names (frontend/userpatch.lua:82).
--
-- settings.reader.lua is what LuaSettings:open dofile()s (frontend/luasettings.lua:30-33).
-- color_rendering present suppresses the first-run colour notice (reader.lua:195-203); it
-- must be false on a grey profile or reader.lua:206-223 blocks on a ConfirmBox. The file
-- must not carry extra_plugin_paths: absent, KOReader adds <KO_HOME>/plugins/ itself
-- (frontend/pluginloader.lua:193-199); present, only the listed paths join KOReader's own
-- plugins/ (frontend/pluginloader.lua:177-188). The quickstart guide needs no setting: the
-- directory argument capture() passes bypasses it (reader.lua:248-251, 257-261).
-- emulator_fake_wifi_connected false makes the emulator's NetworkMgr:isConnected() false
-- (frontend/device/sdl/device.lua:478-500), so no capture fetches the weather. With
-- opts.night_mode the file also sets night_mode, which the device turns on before any UI
-- exists (frontend/device/generic/device.lua:344-347); without it the file is unchanged.
--
-- The third first-run prompt is coverbrowser's: on a profile without
-- settings/bookinfo_cache.sqlite3 its createDB finds user_version 0, below
-- BOOKINFO_DB_VERSION, and shows "Book info cache database updated." for 3 s over the
-- screen (plugins/coverbrowser.koplugin/bookinfomanager.lua:166-195). Seeding the file
-- with the current user_version is enough: createDB applies its schema to an existing
-- file as a no-op and only compares the version (bookinfomanager.lua:166-169). The seed
-- runs in the emulator's own luajit: its sqlite binding ffi.cdef()s on load, so a Busted
-- process can require it once at most, and spec files are insulated from each other.
function M.write_profile(dir, profile_name, plugin_dir, emulator, patches, opts)
    local profile = profiles[profile_name]
    if not profile then
        error("capture: unknown profile " .. tostring(profile_name))
    end
    for _, patch in ipairs(patches or {}) do
        if not basename(patch):match("^2%-") then
            error("capture: extra patch " .. patch .. " must be named 2-*.lua (late priority)")
        end
    end
    if not is_dir(dir) then
        assert(lfs.mkdir(dir))
    end
    local disabled = {}
    for _, name in ipairs(M.disabled_plugins) do
        disabled[#disabled + 1] = string.format("[%q] = true", name)
    end
    local night = opts and opts.night_mode and " [\"night_mode\"] = true," or ""
    write_file(dir .. "/settings.reader.lua", string.format(
        "return { [\"color_rendering\"] = %s, [\"emulator_fake_wifi_connected\"] = false,%s"
            .. " [\"plugins_disabled\"] = { %s } }\n",
        tostring(profile.color), night, table.concat(disabled, ", ")))

    assert(lfs.mkdir(dir .. "/settings"))
    local seed = "require('ffi/loadlib'); local SQ3 = require('lua-ljsqlite3/init');"
        .. " local db = SQ3.open(os.getenv('KOPANDA_SEED'));"
        .. string.format(" db:exec('PRAGMA user_version=%d;'); db:close()", BOOKINFO_DB_VERSION)
    local seed_db = dir .. "/settings/bookinfo_cache.sqlite3"
    local pipe = assert(io.popen("cd " .. quote(emulator or os.getenv("KOPANDA_EMULATOR"))
        .. " && env KOPANDA_SEED=" .. quote(seed_db)
        .. " LUA_PATH='?.lua;common/?.lua;frontend/?.lua' LUA_CPATH='?.so;common/?.so'"
        .. " ./luajit -e " .. quote(seed) .. " 2>&1; echo $?"))
    local seed_output = pipe:read("*a")
    pipe:close()
    if tonumber(seed_output:match("(%d+)\n$")) ~= 0 then
        error("capture: could not seed " .. seed_db .. ":\n" .. seed_output)
    end

    assert(lfs.mkdir(dir .. "/plugins"))
    local plugin_copy = dir .. "/plugins/" .. basename(plugin_dir)
    if not shell("cp -R " .. quote(plugin_dir) .. " " .. quote(plugin_copy)) then
        error("capture: could not copy " .. plugin_dir .. " to " .. plugin_copy)
    end

    assert(lfs.mkdir(dir .. "/patches"))
    local root = assert(os.getenv("KOPANDA_ROOT"), "capture: KOPANDA_ROOT unset")
    local patch_src = root .. "/spec/emulator/patches/" .. PATCH_NAME
    if not shell("cp " .. quote(patch_src) .. " " .. quote(dir .. "/patches/" .. PATCH_NAME)) then
        error("capture: could not copy " .. patch_src)
    end
    for _, patch in ipairs(patches or {}) do
        if not shell("cp " .. quote(patch) .. " " .. quote(dir .. "/patches/" .. basename(patch))) then
            error("capture: could not copy " .. patch)
        end
    end
    return dir
end

-- Width and height from a PNG's IHDR chunk: the 8-byte signature, then the chunk length
-- and type, then width and height as big-endian 32-bit integers at bytes 17-24.
function M.png_size(path)
    local f = io.open(path, "rb")
    if not f then
        error("capture: cannot open " .. path)
    end
    local head = f:read(24)
    f:close()
    if not head or #head < 24 or head:sub(1, 8) ~= "\137PNG\r\n\26\n" or head:sub(13, 16) ~= "IHDR" then
        error("capture: not a PNG: " .. path)
    end
    local function be32(offset)
        local a, b, c, d = head:byte(offset, offset + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    return be32(17), be32(21)
end

local out_counter = 0
local function fresh_out_dir(profile_name)
    local base = os.getenv("KO_HOME")
    if not base then
        error("capture: out_dir not given and KO_HOME is unset")
    end
    local dir
    repeat
        out_counter = out_counter + 1
        dir = string.format("%s/capture-%s-%d", base, profile_name, out_counter)
    until lfs.attributes(dir, "mode") == nil
    assert(lfs.mkdir(dir))
    return dir
end

local function env_assignments(vars)
    local parts = {}
    for _, pair in ipairs(vars) do
        parts[#parts + 1] = pair[1] .. "=" .. quote(pair[2])
    end
    return table.concat(parts, " ")
end

-- Runs the emulator in the background, killing it after timeout_s. The wrapper's last
-- output line is the emulator's exit status; a "timeout" marker file records a kill.
-- SIGTERM alone cannot stop a hung emulator: SDL3 turns it into SDL_EVENT_QUIT
-- (base/ffi/SDL3.lua:719-723), serviced only by the input loop, so the killer follows
-- it with SIGKILL 5 s later. When the emulator exits first, the killer is stopped
-- (so it cannot fork another sleep), its sleep is reaped with pkill, and it is killed.
-- The wrapper's own stderr (the shell's "Terminated"/"Killed" lines) goes to the log.
local function run_emulator(emulator, vars, library_dir, log, timeout_s, marker)
    local script = table.concat({
        "cd " .. quote(emulator) .. " || exit 127",
        "env -u EMULATE_BB_TYPE " .. env_assignments(vars) .. " ./luajit reader.lua " .. quote(library_dir)
            .. " > " .. quote(log) .. " 2>&1 &",
        "pid=$!",
        "(sleep " .. timeout_s .. "; kill $pid 2>/dev/null && { : > " .. quote(marker)
            .. "; sleep 5; kill -9 $pid 2>/dev/null; }) >/dev/null 2>&1 &",
        "killer=$!",
        "wait $pid",
        "s=$?",
        "kill -STOP $killer 2>/dev/null; pkill -P $killer 2>/dev/null; kill -9 $killer 2>/dev/null",
        "echo",
        "echo $s",
    }, "\n")
    local pipe = assert(io.popen("sh -c " .. quote(script) .. " 2>> " .. quote(log)))
    local output = pipe:read("*a")
    pipe:close()
    return tonumber(output:match("(%d+)\n$"))
end

-- The checks capture and run_starts make before writing anything: a known profile, the
-- plugin folder, the library and the emulator's luajit, and no copy of KoPanda in the
-- emulator's own plugins/. Errors start with who. Returns emulator, profile_name, profile and
-- library_dir.
local function preflight(who, opts)
    local emulator = opts.emulator_dir or os.getenv("KOPANDA_EMULATOR")
    local profile_name = opts.profile
    local profile = profiles[profile_name]
    if not profile then
        error(who .. ": unknown profile " .. tostring(profile_name))
    end
    if not opts.plugin_dir or not is_dir(opts.plugin_dir) then
        error(who .. ": plugin_dir is not a directory: " .. tostring(opts.plugin_dir))
    end
    local library_dir = opts.library_dir
        or assert(os.getenv("KOPANDA_ROOT"), who .. ": KOPANDA_ROOT unset") .. "/spec/fixtures/library"
    if not is_dir(library_dir) then
        error(who .. ": library_dir is not a directory: " .. tostring(library_dir))
    end
    if lfs.attributes(emulator .. "/luajit", "mode") ~= "file" then
        error(who .. ": no emulator luajit at " .. emulator .. "/luajit")
    end
    local shadow = emulator .. "/plugins/kopanda.koplugin"
    if lfs.attributes(shadow, "mode") then
        error(who .. ": " .. shadow .. " exists; KOReader would load the plugin from both paths")
    end
    return emulator, profile_name, profile, library_dir
end

-- The emulator's variables for one run on the scratch profile: the screen, then, with png, the
-- capture patch's (KOPANDA_SHOT unset leaves the patch inactive), then env in name order.
local function emulator_vars(scratch, profile, png, cap_s, shot_screen, env)
    local vars = {
        { "KO_HOME", scratch },
        { "XDG_DOCUMENTS_DIR", scratch },
        { "SDL_VIDEO_DRIVER", "offscreen" },
        { "EMULATE_READER_W", profile.width },
        { "EMULATE_READER_H", profile.height },
        { "EMULATE_READER_DPI", profile.dpi },
        { "EMULATE_READER_FORCE_PORTRAIT", 1 },
    }
    if png then
        vars[#vars + 1] = { "KOPANDA_SHOT", png }
        vars[#vars + 1] = { "KOPANDA_SHOT_CAP_S", cap_s }
        vars[#vars + 1] = { "KOPANDA_SHOT_SCREEN", shot_screen or "home" }
    end
    if not profile.color then
        vars[#vars + 1] = { "EMULATE_BW_SCREEN", 1 }
    end
    local names = {}
    for name in pairs(env or {}) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        vars[#vars + 1] = { name, env[name] }
    end
    return vars
end

-- The PNG a settled run left and its sidecar, decoded; fail(message) raises otherwise.
local function read_shot(png, fail)
    if lfs.attributes(png, "mode") ~= "file" then
        fail("emulator exited 0 without writing " .. png)
    end
    local sidecar_text = read_file(png .. ".json")
    if not sidecar_text then
        fail("no sidecar at " .. png .. ".json")
    end
    local sidecar = require("rapidjson").decode(sidecar_text)
    if type(sidecar) ~= "table" then
        fail("sidecar is not a JSON object: " .. sidecar_text)
    end
    return sidecar
end

-- opts: profile (name), plugin_dir, library_dir (default: the fixture library,
-- spec/fixtures/library/; pass an empty dir for no books), out_dir (default: a fresh dir
-- under KO_HOME), cap_s (default 20), timeout_s (default 120), emulator_dir (default
-- KOPANDA_EMULATOR), patches (extra userpatches, see write_profile), shot_screen (the
-- KoPandaSettled screen the capture is taken on, default "home"), env (a table of extra
-- environment variables for the emulator, name to value, passed after the driver's own in
-- name order, so a scenario patch can read its options), night_mode (start the emulator with
-- night mode on, see write_profile). Returns { png, width,
-- height, sidecar, log, scratch }; the scratch profile is removed on success and left in place
-- on failure.
function M.capture(opts)
    local emulator, profile_name, profile, library_dir = preflight("capture", opts)

    local cap_s = opts.cap_s or 20
    local timeout_s = opts.timeout_s or 120
    local out_dir = opts.out_dir or fresh_out_dir(profile_name)
    local scratch = M.write_profile(out_dir .. "/profile-" .. profile_name, profile_name, opts.plugin_dir,
        emulator, opts.patches, { night_mode = opts.night_mode })
    local png = out_dir .. "/" .. profile_name .. ".png"
    local log = out_dir .. "/" .. profile_name .. ".log"
    local marker = out_dir .. "/" .. profile_name .. ".timeout"

    local vars = emulator_vars(scratch, profile, png, cap_s, opts.shot_screen, opts.env)
    local status = run_emulator(emulator, vars, library_dir, log, timeout_s, marker)
    local function fail(message)
        error(string.format("capture %s: %s\nscratch profile: %s\nlog %s, last lines:\n%s",
            profile_name, message, scratch, log, log_tail(log)))
    end
    -- The marker is the only evidence of a kill: a responsive KOReader exits 0 on SIGTERM, so
    -- the exit status cannot tell a kill from a clean quit, and an emulator that exits
    -- normally in the sub-millisecond window between the timer firing and `wait` reaping it
    -- is reported as timed out.
    if lfs.attributes(marker, "mode") then
        fail("timed out after " .. timeout_s .. " s")
    end
    if status == 3 then
        fail("settle cap: no KoPandaSettled signal within " .. cap_s .. " s (exit 3)")
    end
    if status ~= 0 then
        fail("emulator exited with status " .. tostring(status))
    end
    local sidecar = read_shot(png, fail)
    local width, height = M.png_size(png)
    shell("rm -rf " .. quote(scratch))
    return { png = png, width = width, height = height, sidecar = sidecar, log = log, scratch = scratch }
end

local function listed(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

-- Several starts of the emulator on one scratch profile, written once, as a device restarts
-- KOReader: what one start leaves in KO_HOME (settings, patches, a moved plugin folder) is
-- what the next one starts from. opts: capture's profile, plugin_dir, library_dir, out_dir,
-- timeout_s (per start), emulator_dir and patches; extra_plugins, folders copied into the
-- scratch's plugins/ beside the plugin, refused before anything is written when the emulator's
-- own plugins/ holds a folder of the same name (KOReader would load both); and starts, a list
-- of { env, shot, cap_s, accept, after }: env as capture's, for that start only; shot runs
-- the capture patch (KOPANDA_SHOT set, the settle cap cap_s, default 20, on the home's signal),
-- and a shot start that exits 0 must leave its PNG and sidecar; accept lists the exit statuses
-- the start may end with (default { 0 }); after(result, scratch), when given, runs once the
-- start has passed and before the next, so a spec can look at what that start left. A
-- timed-out start or a status outside accept raises, naming the start. Returns
-- { scratch, starts = { { status, log, png, sidecar } } } (png when the start wrote one,
-- sidecar for a shot start that exited 0) and leaves the scratch, on success too, for the spec
-- to inspect and remove.
function M.run_starts(opts)
    local emulator, profile_name, profile, library_dir = preflight("run_starts", opts)
    for _, extra in ipairs(opts.extra_plugins or {}) do
        if not is_dir(extra) then
            error("run_starts: extra plugin is not a directory: " .. tostring(extra))
        end
        local shadow = emulator .. "/plugins/" .. basename(extra)
        if lfs.attributes(shadow, "mode") then
            error("run_starts: " .. shadow .. " exists; KOReader would load " .. basename(extra)
                .. " from both paths")
        end
    end

    local timeout_s = opts.timeout_s or 120
    local out_dir = opts.out_dir or fresh_out_dir(profile_name)
    local scratch = M.write_profile(out_dir .. "/profile-" .. profile_name, profile_name, opts.plugin_dir,
        emulator, opts.patches)
    for _, extra in ipairs(opts.extra_plugins or {}) do
        local copy = scratch .. "/plugins/" .. basename(extra)
        if not shell("cp -R " .. quote(extra) .. " " .. quote(copy)) then
            error("run_starts: could not copy " .. extra .. " to " .. copy)
        end
    end

    local results = {}
    for i, start in ipairs(opts.starts) do
        local name = string.format("%s-%d", profile_name, i)
        local png = start.shot and out_dir .. "/" .. name .. ".png" or nil
        local log = out_dir .. "/" .. name .. ".log"
        local marker = out_dir .. "/" .. name .. ".timeout"
        local cap_s = start.cap_s or 20
        local vars = emulator_vars(scratch, profile, png, cap_s, nil, start.env)
        local status = run_emulator(emulator, vars, library_dir, log, timeout_s, marker)
        local function fail(message)
            error(string.format("run_starts %s start %d: %s\nscratch profile: %s\nlog %s, last lines:\n%s",
                profile_name, i, message, scratch, log, log_tail(log)))
        end
        if lfs.attributes(marker, "mode") then
            fail("timed out after " .. timeout_s .. " s")
        end
        local accept = start.accept or { 0 }
        if not listed(accept, status) then
            local accepted = {}
            for k, value in ipairs(accept) do
                accepted[k] = tostring(value)
            end
            local why = string.format("emulator exited with status %s, not %s", tostring(status),
                table.concat(accepted, " or "))
            if start.shot and status == 3 then
                why = why .. " (settle cap: no KoPandaSettled signal within " .. cap_s .. " s)"
            end
            fail(why)
        end
        local result = { status = status, log = log }
        if png and status == 0 then
            result.sidecar = read_shot(png, fail)
        end
        if png and lfs.attributes(png, "mode") == "file" then
            result.png = png
        end
        results[i] = result
        if start.after then
            start.after(result, scratch)
        end
    end
    return { scratch = scratch, starts = results }
end

return M
