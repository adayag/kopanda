-- The icon registry: every icon the shell draws, by a stable id. Plugin code reaches an icon only
-- through Icons.path(id); this is the one module that names an icon file.
--
-- The default set is every distinct icon the design canvas draws, one stroke file each under
-- icons/, inked in black: NanoSVG renders a file's own colours (frontend/ui/renderimage.lua:338-393)
-- and turns an unknown colour name such as currentColor into mid-grey
-- (base/build/<target>/staging/include/nanosvg.h:1446-1457). `used_in` names the places the canvas
-- draws the icon.
--
-- A look may draw another set, named by its `icons.set` token: one file per registry id under the
-- set's folder, vendored from a pack and recoloured to black (icons/SOURCES.md).
local Fonts = require("fonts")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local Icons = {}

-- The vendored sets by id: Riso draws Phosphor Fill, Frosted Phosphor Bold and Toybox MingCute Line.
Icons.sets = {
    ["phosphor-fill"] = { label = "Phosphor Fill", licence = "MIT", dir = "icons/phosphor-fill" },
    ["phosphor-bold"] = { label = "Phosphor Bold", licence = "MIT", dir = "icons/phosphor-bold" },
    ["mingcute-line"] = { label = "MingCute Line", licence = "Apache-2.0", dir = "icons/mingcute-line" },
}

Icons.entries = {
    { id = "home", label = "Home", used_in = { "nav" }, file = "icons/home.svg" },
    { id = "library", label = "Library",
      used_in = { "launcher", "nav", "launcher management", "library folder sheet" },
      file = "icons/library.svg" },
    { id = "series", label = "Series", used_in = { "launcher", "launcher management" },
      file = "icons/series.svg" },
    { id = "authors", label = "Authors", used_in = { "launcher", "nav", "book sheet", "launcher management" },
      file = "icons/authors.svg" },
    { id = "history", label = "History", used_in = { "launcher", "nav", "launcher management" },
      file = "icons/history.svg" },
    { id = "wifi", label = "Wi-Fi", used_in = { "launcher", "home sheet", "quick settings" },
      file = "icons/wifi.svg" },
    { id = "wifi_off", label = "Wi-Fi off", used_in = { "launcher", "empty states", "home sheet", "quick settings" },
      file = "icons/wifi_off.svg" },
    { id = "settings", label = "Settings",
      used_in = { "launcher", "nav", "book sheet", "home sheet", "launcher management" },
      file = "icons/settings.svg" },
    { id = "folder", label = "Folder", used_in = { "home sheet", "launcher management" },
      file = "icons/folder.svg" },
    { id = "terminal", label = "Terminal", used_in = { "launcher folder" }, file = "icons/terminal.svg" },
    { id = "sync", label = "Sync", used_in = { "launcher folder", "quick settings" }, file = "icons/sync.svg" },
    { id = "screenshot", label = "Screenshot", used_in = { "launcher folder", "quick settings" },
      file = "icons/screenshot.svg" },
    { id = "plugin_missing", label = "Plugin missing", used_in = { "launcher", "empty states" },
      file = "icons/plugin_missing.svg" },
    -- Lucide's `sun` icon, coordinates rounded (ISC; see icons/LICENSE-lucide.txt).
    { id = "sun", label = "Sun (weather, refresh weather)", used_in = { "weather", "home sheet" },
      file = "icons/sun.svg" },
    { id = "moon", label = "Moon (night weather, sleep, night mode)",
      used_in = { "weather", "launcher", "home sheet", "quick settings" }, file = "icons/moon.svg" },
    { id = "open_book", label = "Open book", used_in = { "book sheet" }, file = "icons/open_book.svg" },
    { id = "info", label = "Book details", used_in = { "book sheet" }, file = "icons/info.svg" },
    { id = "bookmark", label = "Read status", used_in = { "book sheet", "launcher" }, file = "icons/bookmark.svg" },
    { id = "list", label = "Feature a different book", used_in = { "book sheet", "launcher" },
      file = "icons/list.svg" },
    { id = "layout", label = "Edit layout", used_in = { "home sheet" }, file = "icons/layout.svg" },
    { id = "rotation_lock", label = "Rotation lock", used_in = { "quick settings" },
      file = "icons/rotation_lock.svg" },
    { id = "power", label = "Sleep (power)", used_in = { "quick settings" }, file = "icons/power.svg" },
    { id = "back", label = "Back", used_in = { "settings menu", "library", "series", "authors" },
      file = "icons/back.svg" },
    { id = "close", label = "Close", used_in = { "settings menu", "edit layout", "launcher management" },
      file = "icons/close.svg" },
    { id = "check", label = "Checked", used_in = { "settings menu", "sheets", "title bar" },
      file = "icons/check.svg" },
    -- Lucide's `chevron-up` icon (ISC; see icons/LICENSE-lucide.txt).
    { id = "chevron_up", label = "Move up", used_in = { "edit layout", "launcher management" },
      file = "icons/chevron_up.svg" },
    -- Lucide's `chevron-down` icon (ISC; see icons/LICENSE-lucide.txt).
    { id = "chevron_down", label = "Move down", used_in = { "edit layout", "launcher management", "library" },
      file = "icons/chevron_down.svg" },
    -- Lucide's `zap` icon, coordinates rounded (ISC; see icons/LICENSE-lucide.txt).
    { id = "action", label = "Action or plugin entry", used_in = { "launcher", "launcher management" },
      file = "icons/action.svg" },
    -- Lucide's `plus` icon (ISC; see icons/LICENSE-lucide.txt).
    { id = "plus", label = "Plus", used_in = { "title bar" }, file = "icons/plus.svg" },
    -- Lucide's `chevron-right` drawn as back's mirror, so the pager's arrows match (ISC; see
    -- icons/LICENSE-lucide.txt).
    { id = "forward", label = "Forward", used_in = { "library", "series", "authors" },
      file = "icons/forward.svg" },
    -- Lucide's `arrow-down-to-line` as the library boards draw it (Main.dc.html:67), not Lucide's
    -- `download`, which has a tray (ISC; see icons/LICENSE-lucide.txt).
    { id = "download", label = "Not downloaded", used_in = { "library", "series", "authors" },
      file = "icons/download.svg" },
    -- Lucide's `sliders-horizontal` icon (ISC; see icons/LICENSE-lucide.txt).
    { id = "quick_settings", label = "Quick settings", used_in = { "launcher" }, file = "icons/quick_settings.svg" },
    { id = "home_plus", label = "Add to the home", used_in = { "book sheet" }, file = "icons/home_plus.svg" },
    { id = "trash", label = "Delete", used_in = { "book sheet" }, file = "icons/trash.svg" },
    { id = "folder_open", label = "Open folder", used_in = { "library folder sheet" },
      file = "icons/folder_open.svg" },
    { id = "eye_off", label = "Hide, hidden folders", used_in = { "library folder sheet", "library sheet" },
      file = "icons/eye_off.svg" },
    { id = "sort", label = "Sort", used_in = { "library sheet" }, file = "icons/sort.svg" },
    { id = "filter", label = "Show (filter)", used_in = { "library sheet" }, file = "icons/filter.svg" },
    { id = "refresh", label = "Refresh covers", used_in = { "library sheet" }, file = "icons/refresh.svg" },
}

-- The set ids already logged as unknown, so a screen of icons logs one line.
local warned = {}

-- The active look's icons.set token, or false when the look names none. Looks is required here,
-- not at load, as it is the module that knows the look; it doesn't require this one.
local function active_set()
    local look = require("looks").active()
    return look and look.icons and look.icons.set or false
end

-- The path of the icon file for id, in the form Fonts.path gives a plugin file: set's file when
-- the set has one, otherwise the default Lucide file. set is a set id, false for the default
-- files, or nil for the active look's set. nil for an id the registry doesn't hold; a set it
-- doesn't hold gives the default file, logged once per set, so a look with a bad token still draws.
function Icons.path(id, set)
    local file
    for _, entry in ipairs(Icons.entries) do
        if entry.id == id then
            file = entry.file
            break
        end
    end
    if not file then
        return nil
    end
    if set == nil then
        set = active_set()
    end
    if set then
        local spec = Icons.sets[set]
        if spec then
            local path = Fonts.path(spec.dir .. "/" .. id .. ".svg")
            if lfs.attributes(path, "mode") == "file" then
                return path
            end
        elseif not warned[set] then
            warned[set] = true
            logger.warn("KoPanda: no icon set", set)
        end
    end
    return Fonts.path(file)
end

return Icons
