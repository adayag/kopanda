-- The release source: GitHub's latest release of adayag/kopanda, and a pull's source (PushPull.pull's
-- opts.source) that downloads a release's plugin-only bundle into download/, unpacks its zip and verifies it
-- against its manifest. Synchronous and UI-free; each call returns its value, or nil and a message.
local Archiver = require("ffi/archiver")
local PushBundle = require("push_bundle")
local PushPull = require("push_pull")
local socketutil = require("socketutil")
local util = require("util")

local ReleaseSource = {}

local LATEST = "https://api.github.com/repos/adayag/kopanda/releases/latest"
local DOWNLOADS = "https://github.com/adayag/kopanda/releases/download/"
local MANIFEST = "manifest.json"
local ZIP = "kopanda.koplugin.zip"
local FOLDER = "kopanda.koplugin"
local PROFILE = "release"
local DEV = "0.0.0-dev"

-- The three numbers of a version written X.Y.Z, or nil when it isn't one.
local function parse(version)
    if type(version) ~= "string" then
        return nil
    end
    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then
        return nil
    end
    return { tonumber(major), tonumber(minor), tonumber(patch) }
end

-- Above 0 when a is newer than b, below 0 when older, 0 when equal: numbers compared one by one.
-- A version that isn't X.Y.Z is older than any that is, and equal to any other that isn't.
function ReleaseSource.compare(a, b)
    local pa, pb = parse(a), parse(b)
    if not pa or not pb then
        return (pa and 1 or 0) - (pb and 1 or 0)
    end
    for i = 1, 3 do
        if pa[i] ~= pb[i] then
            return pa[i] > pb[i] and 1 or -1
        end
    end
    return 0
end

-- The version in plugin_dir's _meta.lua, loaded with an empty environment so it can only build
-- data; 0.0.0-dev when the file is missing, doesn't load or has no string version.
function ReleaseSource.installed_version(plugin_dir)
    local f = io.open(plugin_dir .. "/_meta.lua", "rb")
    if not f then
        return DEV
    end
    local chunk = f:read("*a")
    f:close()
    local loader = chunk and load(chunk, "=_meta.lua", "t", {})
    if not loader then
        return DEV
    end
    local ok, meta = pcall(loader)
    if ok and type(meta) == "table" and type(meta.version) == "string" then
        return meta.version
    end
    return DEV
end

-- The download URL of the asset named name in assets, or nil and why. Only the repo's own
-- release downloads are taken.
local function asset_url(assets, name)
    for _, asset in ipairs(assets) do
        if type(asset) == "table" and asset.name == name then
            local url = asset.browser_download_url
            if type(url) ~= "string" or url:sub(1, #DOWNLOADS) ~= DOWNLOADS then
                return nil, "The release's " .. name .. " is not one of the repo's release downloads."
            end
            return url
        end
    end
    return nil, "The release has no " .. name .. "."
end

-- The latest release as { version, notes, manifest_url, zip_url }, or nil and why. GitHub wants
-- a user agent; KOReader's is sent.
function ReleaseSource.latest()
    local doc, why, code = PushPull.fetch_json(LATEST, { ["User-Agent"] = socketutil.USER_AGENT })
    if doc == nil then
        if code == 404 then
            return nil, "No release yet."
        end
        return nil, "Couldn't check GitHub for a release: " .. tostring(why) .. "."
    end
    if type(doc) ~= "table" or type(doc.tag_name) ~= "string" then
        return nil, "GitHub's answer names no release."
    end
    local version = doc.tag_name:match("^v(%d+%.%d+%.%d+)$")
    if not version then
        return nil, "The latest release's tag " .. doc.tag_name .. " is not vX.Y.Z."
    end
    if type(doc.assets) ~= "table" then
        return nil, "The release lists no files."
    end
    local manifest_url, manifest_why = asset_url(doc.assets, MANIFEST)
    if not manifest_url then
        return nil, manifest_why
    end
    local zip_url, zip_why = asset_url(doc.assets, ZIP)
    if not zip_url then
        return nil, zip_why
    end
    return {
        version = version,
        notes = type(doc.body) == "string" and doc.body or "",
        manifest_url = manifest_url,
        zip_url = zip_url,
    }
end

-- Unpacks the zip at zip_path into download/plugin: every entry under kopanda.koplugin/ with a safe path, each
-- file one the manifest names, once, of the manifest's size. Each file is read into memory and written here,
-- never through libarchive's disk writer, which would follow a hard link out of download/. Returns true, or
-- nil and why.
local function unzip(zip_path, download, manifest)
    local sizes = {}
    for _, file in ipairs(manifest.files) do
        sizes[file.path] = file.size
    end
    local reader = Archiver.Reader:new()
    if not reader:open(zip_path) then
        return nil, "the zip doesn't open: " .. tostring(reader.err)
    end
    local function refuse(why)
        reader:close()
        return nil, why
    end
    local seen = {}
    -- ffi/archiver.lua:93-99 (iterate), :59-91 (next: each entry's path and mode, nil at the end
    -- or on an error, with err set).
    for entry in reader:iterate() do
        local path = entry.path
        local trimmed = path:gsub("/+$", "")
        local rel = trimmed:sub(#FOLDER + 2)
        local inside = trimmed:sub(1, #FOLDER + 1) == FOLDER .. "/" and PushBundle.safe_path(rel)
        if entry.mode == "directory" then
            if trimmed ~= FOLDER and not inside then
                return refuse(path .. " is not under " .. FOLDER .. "/")
            end
        elseif entry.mode ~= "file" then
            return refuse(path .. " is not a regular file")
        elseif not inside then
            return refuse(path .. " is not under " .. FOLDER .. "/")
        else
            local target = "plugin/" .. rel
            if not sizes[target] then
                return refuse(path .. " is not in the manifest")
            end
            -- The Kindle's storage is FAT, where names that differ only in case are one file.
            if seen[target:lower()] then
                return refuse(path .. " is in the zip twice")
            end
            seen[target:lower()] = true
            -- entry.size is libarchive's int64 (ffi/archiver.lua:81), equal to a number of the
            -- same value.
            if entry.size ~= sizes[target] then
                return refuse(path .. "'s size is " .. tostring(tonumber(entry.size)) .. ", not the manifest's "
                    .. sizes[target])
            end
            local destination = download .. "/" .. target
            local made, make_err = util.makePath(destination:match("^(.*)/[^/]+$"))
            if not made then
                return refuse("couldn't make the folder for " .. path .. ": " .. tostring(make_err))
            end
            -- ffi/archiver.lua:116-133: the current entry's bytes, a regular file's only; nil
            -- with err set on a short read.
            local bytes = reader:extractToMemory(entry.index)
            if not bytes then
                return refuse("couldn't unpack " .. path .. ": " .. tostring(reader.err))
            end
            local handle, open_err = io.open(destination, "wb")
            if not handle then
                return refuse("couldn't write " .. path .. ": " .. tostring(open_err))
            end
            local written, write_err = handle:write(bytes)
            handle:close()
            if not written then
                return refuse("couldn't write " .. path .. ": " .. tostring(write_err))
            end
        end
    end
    if reader.err then
        return refuse("the zip is damaged: " .. tostring(reader.err))
    end
    reader:close()
    return true
end

-- A pull's source for release (latest's): fetches its manifest, which must be a plugin-only
-- manifest for the release profile, then its zip into download/, unpacks it into download/plugin,
-- removes the zip and verifies the files. Returns the manifest, or nil and why.
function ReleaseSource.source(release)
    return function(paths)
        local doc, why = PushPull.fetch_json(release.manifest_url)
        if doc == nil then
            return nil, "Couldn't download the release's manifest: " .. tostring(why) .. "."
        end
        local manifest, invalid = PushBundle.check_manifest(doc, PROFILE)
        if not manifest then
            return nil, "The release's manifest is refused: " .. invalid .. "."
        end
        if manifest.settings ~= false then
            return nil, "The release's manifest carries settings; a release is the plugin only."
        end
        local zip_path = paths.download .. "/" .. ZIP
        local fetched, zip_why = PushPull.fetch_file(release.zip_url, zip_path)
        if not fetched then
            return nil, "Couldn't download the release: " .. tostring(zip_why) .. "."
        end
        local unpacked, unpack_why = unzip(zip_path, paths.download, manifest)
        if not unpacked then
            return nil, "The release's zip is refused: " .. unpack_why .. "."
        end
        local removed, remove_err = os.remove(zip_path)
        if not removed then
            return nil, "Couldn't remove the release's zip: " .. tostring(remove_err) .. "."
        end
        local verified, mismatch = PushBundle.verify_files(paths.download, manifest)
        if not verified then
            return nil, "The release is refused: " .. mismatch .. "."
        end
        return manifest
    end
end

return ReleaseSource
