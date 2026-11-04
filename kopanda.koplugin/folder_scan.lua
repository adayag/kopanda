-- One folder's entries as the file browser would list them, for books.lua. Reads ui/widget/filechooser
-- (frontend/ui/widget/filechooser.lua:114-143) and document/documentregistry
-- (frontend/document/documentregistry.lua:63-85), each required at call time.
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local FolderScan = {}

function FolderScan.trimmed(dir)
    local stripped = dir:gsub("/+$", "")
    return stripped == "" and "/" or stripped
end

local function join(dir, name)
    return dir == "/" and "/" .. name or dir .. "/" .. name
end

function FolderScan.same_dir(a, b)
    if a == b then
        return true
    end
    local real_a = ffiutil.realpath(a)
    return real_a ~= nil and real_a == ffiutil.realpath(b)
end

-- dir's entries the file browser would list (frontend/ui/widget/filechooser.lua:114-143): the folders
-- show_dir keeps, and the files no exclude_files pattern or "._" rule drops that
-- DocumentRegistry:hasProvider accepts, asked as the file manager's filter asks
-- (frontend/apps/filemanager/filemanager.lua:143). Dot names only with FileChooser.show_hidden.
function FolderScan.scan(dir)
    local FileChooser = require("ui/widget/filechooser")
    local DocumentRegistry = require("document/documentregistry")
    local folders, files = {}, {}
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if not ok then
        logger.err("KoPanda: could not read the folder", dir, ":", iter)
        return folders, files
    end
    local listed, err = pcall(function()
        for name in iter, dir_obj do
            if name ~= "." and name ~= ".." and (FileChooser.show_hidden or name:sub(1, 1) ~= ".") then
                local path = join(dir, name)
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    if FileChooser:show_dir(name) then
                        folders[#folders + 1] = { name = name, path = path }
                    end
                elseif mode == "file" and name:sub(1, 2) ~= "._" then
                    local excluded = false
                    for _, pattern in ipairs(FileChooser.exclude_files) do
                        if name:match(pattern) then
                            excluded = true
                            break
                        end
                    end
                    if not excluded and DocumentRegistry:hasProvider(name) then
                        files[#files + 1] = { name = name, path = path }
                    end
                end
            end
        end
    end)
    if not listed then
        logger.err("KoPanda: could not list the folder", dir, ":", err)
    end
    local function by_name(a, b)
        return a.name < b.name
    end
    table.sort(folders, by_name)
    table.sort(files, by_name)
    return folders, files
end

return FolderScan
