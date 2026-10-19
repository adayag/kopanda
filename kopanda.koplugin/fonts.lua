-- Paths to files shipped in the plugin folder, and KOReader faces for its font files. Font:getFace
-- treats a name starting with / or ./ as a path, else as a name under KOReader's fonts folder
-- (frontend/ui/font.lua:307-312). The plugin folder is relative to the KOReader directory on a device
-- (frontend/pluginloader.lua:24, :204), so a plugin path is given a ./ prefix when it has neither.
local Font = require("ui/font")
local FontList = require("fontlist")
local ffiUtil = require("ffi/util")
local logger = require("logger")

local Fonts = {}

-- The plugin folder, as require found this file: an @-prefixed path from package.path, whose
-- first entry while main.lua loads is the folder the loader gave the plugin
-- (frontend/pluginloader.lua:242, :248).
local plugin_dir = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")

local function join(dir, rel)
    local path = dir .. "/" .. rel
    if path:sub(1, 1) == "/" or path:sub(1, 2) == "./" then
        return path
    end
    return "./" .. path
end

Fonts._join = join

-- The path of rel, a path relative to the plugin folder, in the form Font:getFace reads as a path.
function Fonts.path(rel)
    return join(plugin_dir, rel)
end

-- The name Fonts.face hands Font:getFace for the font file at rel. Stable KOReader (v2026.07.x,
-- frontend/ui/font.lua:306) joins every name onto FontList.fontdir, a path included; the pinned build
-- takes a name starting with / or ./ as a path (font.lua:307-312). One name works under both: a
-- relative path that climbs out of the fonts folder to the file's absolute path. A file realpath
-- can't resolve gets the plain plugin path.
function Fonts.face_name(rel)
    local path = Fonts.path(rel)
    local absolute = ffiUtil.realpath(path)
    local font_dir = ffiUtil.realpath(FontList.fontdir)
    if not absolute or not font_dir then
        return path
    end
    local _, depth = font_dir:gsub("[^/]+", "")
    return string.rep("../", depth) .. absolute:sub(2)
end

-- The KOReader face for the font file at rel at size (unscaled; getFace scales it, font.lua:276),
-- or nil, logged, when it won't load.
function Fonts.face(rel, size)
    local ok, face = pcall(function()
        return Font:getFace(Fonts.face_name(rel), size)
    end)
    if not ok then
        logger.err("KoPanda: font failed to load:", rel, face)
        return nil
    end
    -- getFace logs its own failure and returns nil (font.lua:329-332).
    return face
end

return Fonts
