-- Served bundles for push_server.lua, written by a spec under a root: <root>/profiles.json, <root>/<id>/tree/plugin/...
-- (the plugin folder, with the spec's own files over it), <root>/<id>/tree/settings.lua and <root>/<id>/manifest.json
-- ({ format, profile, hash, files = { { path, size, sha256 } } }). The manifest's hashes come from the plugin's own
-- push_bundle.lua. The format is pinned against the studio by the shared vectors (spec/fixtures/push/,
-- push_bundle_spec.lua and the studio's bundle test), so hashing here with the device's code only drives the flow.
local PushBundle = require("push_bundle")
local lfs = require("libs/libkoreader-lfs")
local rapidjson = require("rapidjson")

local M = {}

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function write_file(path, bytes)
    local f = assert(io.open(path, "wb"))
    f:write(bytes)
    f:close()
end

-- Every regular file under dir as a path relative to it prefixed with prefix, dot-entries
-- skipped as the studio skips them.
local function list_files(dir, prefix, found)
    for entry in lfs.dir(dir) do
        if entry:sub(1, 1) ~= "." then
            local path = dir .. "/" .. entry
            local mode = lfs.symlinkattributes(path, "mode")
            if mode == "directory" then
                list_files(path, prefix .. entry .. "/", found)
            elseif mode == "file" then
                found[#found + 1] = prefix .. entry
            else
                error("push_bundles: " .. path .. " is neither a file nor a folder")
            end
        end
    end
    return found
end

-- Writes bundle { id, plugin_dir, settings, files } under root, files mapping paths under
-- plugin/ to the bytes that replace or join the plugin folder's, and profiles.json listing it.
-- Returns the manifest.
function M.write(root, bundle)
    local base = root .. "/" .. bundle.id
    local tree = base .. "/tree"
    assert(lfs.mkdir(base))
    assert(lfs.mkdir(tree))
    assert(os.execute("cp -R " .. quote(bundle.plugin_dir) .. " " .. quote(tree .. "/plugin")) == 0,
        "push_bundles: could not copy " .. bundle.plugin_dir)
    for path, bytes in pairs(bundle.files or {}) do
        write_file(tree .. "/plugin/" .. path, bytes)
    end
    write_file(tree .. "/settings.lua", bundle.settings)

    local paths = list_files(tree, "", {})
    table.sort(paths)
    local files = {}
    for i, path in ipairs(paths) do
        local source = tree .. "/" .. path
        files[i] = {
            path = path,
            size = lfs.attributes(source, "size"),
            sha256 = assert(PushBundle.sha256_file(source)),
        }
    end
    local manifest = {
        format = 1,
        profile = bundle.id,
        hash = assert(PushBundle.bundle_hash(tree, files)),
        files = files,
    }
    write_file(base .. "/manifest.json", rapidjson.encode(manifest))
    write_file(root .. "/profiles.json", rapidjson.encode({
        profiles = { { id = bundle.id, name = bundle.id, device = bundle.id } },
    }))
    return manifest
end

return M
