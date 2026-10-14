-- Goldens: committed reference captures under spec/goldens/, one PNG and one JSON sidecar
-- per name and profile. check() compares a capture against its golden with the sidecar's
-- masks; with KOPANDA_UPDATE_GOLDENS=1 it writes the capture as the golden instead.
local lfs = require("libs/libkoreader-lfs")
local rapidjson = require("rapidjson")
local compare = require("emulator.compare")

local M = {}

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local data = f:read("*a")
    f:close()
    return data
end

local function write_file(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

local function dirname(path)
    return path:match("^(.*)/[^/]+$") or "."
end

local function make_dir(path)
    if lfs.attributes(path, "mode") == "directory" then
        return
    end
    make_dir(dirname(path))
    assert(lfs.mkdir(path))
end

-- The spec file that called into this module, relative to the repo root, for the
-- regeneration command a missing golden prints.
local function calling_spec()
    local root = (os.getenv("KOPANDA_ROOT") or "") .. "/"
    local level = 2
    while true do
        local info = debug.getinfo(level, "S")
        if not info then
            return "<spec file>"
        end
        local source = info.source:match("^@(.*_spec%.lua)$")
        if source then
            if source:sub(1, #root) == root then
                return source:sub(#root + 1)
            end
            return source
        end
        level = level + 1
    end
end

local function update(name, profile, capture_result, png_path, json_path)
    local png = read_file(capture_result.png)
    if not png then
        error("golden: cannot read capture " .. capture_result.png, 0)
    end
    write_file(png_path, png)
    local old = rapidjson.decode(read_file(json_path) or "null")
    old = type(old) == "table" and old or {}
    local capture_sidecar = capture_result.sidecar or {}
    write_file(json_path, rapidjson.encode({
        name = name,
        profile = profile,
        width = capture_result.width,
        height = capture_result.height,
        paint_ms = capture_sidecar.paint_ms,
        koreader = capture_sidecar.koreader,
        captured_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        masks = old.masks or rapidjson.array({}),
        notes = old.notes,
    }, { pretty = true, sort_keys = true }) .. "\n")
    print("golden written: " .. png_path)
    print("golden written: " .. json_path)
    return { updated = true }
end

-- opts: golden_dir (default <KOPANDA_ROOT>/spec/goldens), update (default true only when
-- KOPANDA_UPDATE_GOLDENS is "1"), artifact_dir (default <KOPANDA_ROOT>/spec/.artifacts/goldens,
-- where a pixel failure leaves a copy of the capture and the diff image, since bin/check
-- deletes KO_HOME on exit). Returns { updated = true } after writing the golden, or
-- compare's result on a match; raises an error naming the files on any failure.
function M.check(name, profile, capture_result, opts)
    opts = opts or {}
    local golden_dir = opts.golden_dir or (os.getenv("KOPANDA_ROOT") .. "/spec/goldens")
    local artifact_dir = opts.artifact_dir or (os.getenv("KOPANDA_ROOT") .. "/spec/.artifacts/goldens")
    local do_update = opts.update
    if do_update == nil then
        do_update = os.getenv("KOPANDA_UPDATE_GOLDENS") == "1"
    end
    local base = golden_dir .. "/" .. name .. "-" .. profile
    local png_path, json_path = base .. ".png", base .. ".json"

    if do_update then
        if lfs.attributes(golden_dir, "mode") ~= "directory" then
            assert(lfs.mkdir(golden_dir))
        end
        return update(name, profile, capture_result, png_path, json_path)
    end

    if lfs.attributes(png_path, "mode") ~= "file" then
        error(string.format("no golden at %s; run KOPANDA_UPDATE_GOLDENS=1 bin/check %s to create it,"
            .. " then look at it before committing", png_path, calling_spec()), 0)
    end
    local sidecar = rapidjson.decode(read_file(json_path) or "null")
    local masks = type(sidecar) == "table" and sidecar.masks or nil
    make_dir(artifact_dir)
    local artifact = artifact_dir .. "/" .. name .. "-" .. profile
    local actual_png, diff_png = artifact .. ".actual.png", artifact .. ".diff.png"
    local result = compare.compare(capture_result.png, png_path, { masks = masks, diff_png = diff_png })
    if result.reason == "size" then
        error(string.format("golden %s-%s: the capture is %d×%d but the golden is %d×%d;"
            .. " check profile %s in spec/emulator/profiles.lua\ncapture: %s\ngolden: %s",
            name, profile, result.actual[1], result.actual[2], result.golden[1], result.golden[2],
            profile, capture_result.png, png_path), 0)
    end
    if not result.ok then
        write_file(actual_png, assert(read_file(capture_result.png)))
        error(string.format("golden %s-%s: %.2f %% of compared pixels differ (%d of %d)"
            .. "\ngolden: %s\nactual: %s\ndiff: %s",
            name, profile, result.fraction * 100, result.differing, result.compared,
            png_path, actual_png, result.diff_png), 0)
    end
    os.remove(actual_png)
    os.remove(diff_png)
    return result
end

-- check() under the regeneration flag's default, as one line in a spec.
function M.assert_golden(name, profile, capture_result)
    return M.check(name, profile, capture_result)
end

return M
