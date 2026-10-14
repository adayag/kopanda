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
-- copied under plugins/, and the capture patch under patches/.
--
-- settings.reader.lua is what LuaSettings:open dofile()s (frontend/luasettings.lua:30-33).
-- color_rendering present suppresses the first-run colour notice (reader.lua:195-203); it
-- must be false on a grey profile or reader.lua:206-223 blocks on a ConfirmBox. The file
-- must not carry extra_plugin_paths: absent, KOReader adds <KO_HOME>/plugins/ itself
-- (frontend/pluginloader.lua:193-199); present, only the listed paths join KOReader's own
-- plugins/ (frontend/pluginloader.lua:177-188). The quickstart guide needs no setting: the
-- directory argument capture() passes bypasses it (reader.lua:248-251, 257-261).
--
-- The third first-run prompt is coverbrowser's: on a profile without
-- settings/bookinfo_cache.sqlite3 its createDB finds user_version 0, below
-- BOOKINFO_DB_VERSION, and shows "Book info cache database updated." for 3 s over the
-- screen (plugins/coverbrowser.koplugin/bookinfomanager.lua:166-195). Seeding the file
-- with the current user_version is enough: createDB applies its schema to an existing
-- file as a no-op and only compares the version (bookinfomanager.lua:166-169). The seed
-- runs in the emulator's own luajit: its sqlite binding ffi.cdef()s on load, so a Busted
-- process can require it once at most, and spec files are insulated from each other.
function M.write_profile(dir, profile_name, plugin_dir, emulator)
    local profile = profiles[profile_name]
    if not profile then
        error("capture: unknown profile " .. tostring(profile_name))
    end
    if not is_dir(dir) then
        assert(lfs.mkdir(dir))
    end
    local disabled = {}
    for _, name in ipairs(M.disabled_plugins) do
        disabled[#disabled + 1] = string.format("[%q] = true", name)
    end
    write_file(dir .. "/settings.reader.lua", string.format(
        "return { [\"color_rendering\"] = %s, [\"plugins_disabled\"] = { %s } }\n",
        tostring(profile.color), table.concat(disabled, ", ")))

    assert(lfs.mkdir(dir .. "/settings"))
    local seed = "require('ffi/loadlib'); local SQ3 = require('lua-ljsqlite3/init');"
        .. " local db = SQ3.open(os.getenv('KOPANDA_SEED'));"
        .. string.format(" db:exec('PRAGMA user_version=%d;'); db:close()", BOOKINFO_DB_VERSION)
    local seeded = shell("cd " .. quote(emulator or os.getenv("KOPANDA_EMULATOR"))
        .. " && env KOPANDA_SEED=" .. quote(dir .. "/settings/bookinfo_cache.sqlite3")
        .. " LUA_PATH='?.lua;common/?.lua;frontend/?.lua' LUA_CPATH='?.so;common/?.so'"
        .. " ./luajit -e " .. quote(seed) .. " >/dev/null 2>&1")
    if not seeded then
        error("capture: could not seed " .. dir .. "/settings/bookinfo_cache.sqlite3")
    end

    assert(lfs.mkdir(dir .. "/plugins"))
    local plugin_copy = dir .. "/plugins/" .. basename(plugin_dir)
    if not shell("cp -R " .. quote(plugin_dir) .. " " .. quote(plugin_copy)) then
        error("capture: could not copy " .. plugin_dir .. " to " .. plugin_copy)
    end

    assert(lfs.mkdir(dir .. "/patches"))
    local patch_src = os.getenv("KOPANDA_ROOT") .. "/spec/emulator/patches/" .. PATCH_NAME
    if not shell("cp " .. quote(patch_src) .. " " .. quote(dir .. "/patches/" .. PATCH_NAME)) then
        error("capture: could not copy " .. patch_src)
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
-- it with SIGKILL 5 s later. When the emulator exits first, pkill ends the killer's
-- sleep and its failing kill (the pid is already reaped) skips the escalation.
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
        "pkill -P $killer 2>/dev/null; kill $killer 2>/dev/null",
        "echo",
        "echo $s",
    }, "\n")
    local pipe = assert(io.popen("sh -c " .. quote(script) .. " 2>> " .. quote(log)))
    local output = pipe:read("*a")
    pipe:close()
    return tonumber(output:match("(%d+)\n$"))
end

-- opts: profile (name), plugin_dir, library_dir, out_dir (default: a fresh dir under
-- KO_HOME), cap_s (default 20), timeout_s (default 120), emulator_dir (default
-- KOPANDA_EMULATOR). Returns { png, width, height, sidecar, log, scratch }; the scratch
-- profile is removed on success and left in place on failure.
function M.capture(opts)
    local emulator = opts.emulator_dir or os.getenv("KOPANDA_EMULATOR")
    local profile_name = opts.profile
    local profile = profiles[profile_name]
    if not profile then
        error("capture: unknown profile " .. tostring(profile_name))
    end
    if not opts.plugin_dir or not is_dir(opts.plugin_dir) then
        error("capture: plugin_dir is not a directory: " .. tostring(opts.plugin_dir))
    end
    if not opts.library_dir or not is_dir(opts.library_dir) then
        error("capture: library_dir is not a directory: " .. tostring(opts.library_dir))
    end
    if lfs.attributes(emulator .. "/luajit", "mode") ~= "file" then
        error("capture: no emulator luajit at " .. emulator .. "/luajit")
    end
    local shadow = emulator .. "/plugins/kopanda.koplugin"
    if lfs.attributes(shadow, "mode") then
        error("capture: " .. shadow .. " exists; KOReader would load the plugin from both paths")
    end

    local cap_s = opts.cap_s or 20
    local timeout_s = opts.timeout_s or 120
    local out_dir = opts.out_dir or fresh_out_dir(profile_name)
    local scratch = M.write_profile(out_dir .. "/profile-" .. profile_name, profile_name, opts.plugin_dir,
        emulator)
    local png = out_dir .. "/" .. profile_name .. ".png"
    local log = out_dir .. "/" .. profile_name .. ".log"
    local marker = out_dir .. "/" .. profile_name .. ".timeout"

    local vars = {
        { "KO_HOME", scratch },
        { "XDG_DOCUMENTS_DIR", scratch },
        { "SDL_VIDEO_DRIVER", "offscreen" },
        { "EMULATE_READER_W", profile.width },
        { "EMULATE_READER_H", profile.height },
        { "EMULATE_READER_DPI", profile.dpi },
        { "EMULATE_READER_FORCE_PORTRAIT", 1 },
        { "KOPANDA_SHOT", png },
        { "KOPANDA_SHOT_CAP_S", cap_s },
    }
    if not profile.color then
        vars[#vars + 1] = { "EMULATE_BW_SCREEN", 1 }
    end

    local status = run_emulator(emulator, vars, opts.library_dir, log, timeout_s, marker)
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
    if status ~= 0 then
        fail("emulator exited with status " .. tostring(status))
    end
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
    local width, height = M.png_size(png)
    shell("rm -rf " .. quote(scratch))
    return { png = png, width = width, height = height, sidecar = sidecar, log = log, scratch = scratch }
end

return M
