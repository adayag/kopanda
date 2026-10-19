-- A pulled bundle's format on the device: the manifest's checks, the paths it may name, each
-- file's sha256 and the bundle hash, the studio's hashTree (studio/src/server/bundle.ts). Pure
-- over files and tables; every check returns a value or true, or nil and why.
local lfs = require("libs/libkoreader-lfs")
local sha2 = require("ffi/sha2")

local PushBundle = {}

local FORMAT = 1
local READ_BYTES = 65536
local REQUIRED = { "plugin/main.lua", "plugin/_meta.lua" }
local SETTINGS = "settings.lua"

-- A path the device writes under download/: relative, with / separators, every segment made
-- of letters, digits, '.', '_' and '-', and none empty, '.' or '..'.
function PushBundle.safe_path(path)
    if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or path:find("\\", 1, true) then
        return false
    end
    for segment in (path .. "/"):gmatch("([^/]*)/") do
        if segment == "." or segment == ".." or not segment:match("^[A-Za-z0-9._%-]+$") then
            return false
        end
    end
    return true
end

-- A decoded JSON object or array is a table either way; an array has only its items 1..n, so a
-- table with items is taken for an array and one with other keys for an object.
local function is_object(value)
    return type(value) == "table" and #value == 0
end

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end
    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end
    return count == #value
end

local function is_hex64(value)
    return type(value) == "string" and #value == 64 and value:match("^[0-9a-f]+$") ~= nil
end

local function is_size(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
end

-- The manifest as plain tables when doc is a valid manifest for profile_id, or nil and why. A
-- manifest whose settings is false is plugin-only (a release's): it names no settings.lua, and
-- the result's settings is false. Any other value, or none (the studio's), carries settings.lua.
function PushBundle.check_manifest(doc, profile_id)
    if not is_object(doc) then
        return nil, "the manifest is not a JSON object"
    end
    if doc.format ~= FORMAT then
        return nil, "the manifest's format is " .. tostring(doc.format) .. ", not " .. FORMAT
    end
    if doc.profile ~= profile_id then
        return nil, "the manifest is for " .. tostring(doc.profile) .. ", not " .. tostring(profile_id)
    end
    if not is_hex64(doc.hash) then
        return nil, "the manifest's hash is not 64 lowercase hex digits"
    end
    if not is_array(doc.files) or #doc.files == 0 then
        return nil, "the manifest lists no files"
    end
    local files, seen, previous = {}, {}, nil
    for _, file in ipairs(doc.files) do
        if not is_object(file) or type(file.path) ~= "string" then
            return nil, "the manifest lists a file without a path"
        end
        local path = file.path
        if not is_size(file.size) then
            return nil, "the manifest's size for " .. path .. " is not a non-negative integer"
        end
        if not is_hex64(file.sha256) then
            return nil, "the manifest's sha256 for " .. path .. " is not 64 lowercase hex digits"
        end
        if not PushBundle.safe_path(path) then
            return nil, "the manifest names an unsafe path: " .. path
        end
        if path ~= SETTINGS and path:sub(1, 7) ~= "plugin/" then
            return nil, "the manifest names " .. path .. ", neither settings.lua nor under plugin/"
        end
        -- The Kindle's storage is FAT, where names that differ only in case are one file.
        local folded = path:lower()
        if seen[folded] then
            return nil, "the manifest names " .. seen[folded] .. " and " .. path .. ", the same file on FAT"
        end
        seen[folded] = path
        if previous and previous >= path then
            return nil, "the manifest's paths are out of byte order at " .. path
        end
        previous = path
        files[#files + 1] = { path = path, size = file.size, sha256 = file.sha256 }
    end
    local settings = doc.settings ~= false
    if not settings and seen[SETTINGS] then
        return nil, "a plugin-only manifest names " .. SETTINGS
    end
    for _, path in ipairs(REQUIRED) do
        if not seen[path] or seen[path] ~= path then
            return nil, "the manifest has no " .. path
        end
    end
    if settings and seen[SETTINGS] ~= SETTINGS then
        return nil, "the manifest has no " .. SETTINGS
    end
    return { format = FORMAT, profile = doc.profile, hash = doc.hash, settings = settings, files = files }
end

-- Feeds the file at path to update in blocks; false when it can't be opened.
local function feed(update, path)
    local f = io.open(path, "rb")
    if not f then
        return false
    end
    while true do
        local bytes = f:read(READ_BYTES)
        if not bytes then
            break
        end
        update(bytes)
    end
    f:close()
    return true
end

-- The lowercase hex sha256 of the file at path, streamed (base/ffi/sha2.lua:4356-4410); nil when
-- it can't be read.
function PushBundle.sha256_file(path)
    local update = sha2.sha256()
    if not feed(update, path) then
        return nil
    end
    return update()
end

-- n as a big-endian unsigned integer of width bytes.
local function big_endian(n, width)
    local bytes = {}
    for i = width, 1, -1 do
        bytes[i] = string.char(n % 256)
        n = math.floor(n / 256)
    end
    return table.concat(bytes)
end

-- A file's frame in the bundle hash: the path's length (u32 big-endian), the file's size (u64
-- big-endian), then the path; the file's bytes follow it.
local function frame(path, size)
    return big_endian(#path, 4) .. big_endian(size, 8) .. path
end

-- The bundle hash of files ({ path } entries) under dir: sha256 over the files in byte order of
-- their paths, each framed, then its bytes. nil when a file can't be read.
function PushBundle.bundle_hash(dir, files)
    local sorted = {}
    for i, file in ipairs(files) do
        sorted[i] = file.path
    end
    table.sort(sorted)
    local update = sha2.sha256()
    for _, path in ipairs(sorted) do
        local source = dir .. "/" .. path
        local size = lfs.attributes(source, "size")
        if not size then
            return nil
        end
        update(frame(path, size))
        if not feed(update, source) then
            return nil
        end
    end
    return update()
end

-- true when every file of the manifest under dir is a regular file with one link, of its size and sha256, and
-- the files recompute the manifest's hash; nil and why otherwise. Reads each file once, feeding its blocks to
-- its own sha256 and to the bundle hash, so the manifest's files must be in check_manifest's byte order.
function PushBundle.verify_files(dir, manifest)
    local bundle, previous = sha2.sha256(), nil
    for _, file in ipairs(manifest.files) do
        if previous and previous >= file.path then
            return nil, "the manifest's paths are out of byte order at " .. file.path
        end
        previous = file.path
        local path = dir .. "/" .. file.path
        local attributes = lfs.symlinkattributes(path)
        if not attributes or attributes.mode ~= "file" or attributes.nlink ~= 1 then
            return nil, file.path .. " is not a regular file"
        end
        if attributes.size ~= file.size then
            return nil, file.path .. " is " .. tostring(attributes.size) .. " bytes, not " .. file.size
        end
        local own = sha2.sha256()
        bundle(frame(file.path, attributes.size))
        local read = feed(function(bytes)
            own(bytes)
            bundle(bytes)
        end, path)
        if not read or own() ~= file.sha256 then
            return nil, file.path .. " doesn't match its sha256"
        end
    end
    if bundle() ~= manifest.hash then
        return nil, "the files don't recompute the bundle hash"
    end
    return true
end

return PushBundle
