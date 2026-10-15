-- The icon registry: every icon the shell draws, by a stable id. Plugin code reaches an icon only
-- through Icons.path(id); this is the one module that names an icon file.
--
-- The default set is every distinct icon the design canvas draws, one stroke file each under
-- icons/, inked in black: NanoSVG renders a file's own colours (frontend/ui/renderimage.lua:338-393)
-- and turns an unknown colour name such as currentColor into mid-grey
-- (base/build/<target>/staging/include/nanosvg.h:1446-1457). `used_in` names the places the canvas
-- draws the icon.
local Fonts = require("fonts")

local Icons = {}

Icons.entries = {
    { id = "home", label = "Home", used_in = { "nav" }, file = "icons/home.svg" },
    { id = "library", label = "Library", used_in = { "launcher", "nav", "launcher management" },
      file = "icons/library.svg" },
    { id = "series", label = "Series", used_in = { "launcher", "launcher management" },
      file = "icons/series.svg" },
    { id = "authors", label = "Authors", used_in = { "launcher", "nav", "book sheet", "launcher management" },
      file = "icons/authors.svg" },
    { id = "history", label = "History", used_in = { "launcher", "nav", "launcher management" },
      file = "icons/history.svg" },
    { id = "wifi", label = "Wi-Fi", used_in = { "launcher", "home sheet", "quick settings" },
      file = "icons/wifi.svg" },
    { id = "wifi_off", label = "Wi-Fi off", used_in = { "launcher", "empty states" }, file = "icons/wifi_off.svg" },
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
    { id = "sun", label = "Sun (weather, refresh weather)", used_in = { "weather", "home sheet" },
      file = "icons/sun.svg" },
    { id = "moon", label = "Moon (night weather, sleep, night mode)",
      used_in = { "weather", "launcher", "home sheet", "quick settings" }, file = "icons/moon.svg" },
    { id = "open_book", label = "Open book", used_in = { "book sheet" }, file = "icons/open_book.svg" },
    { id = "info", label = "Book details", used_in = { "book sheet" }, file = "icons/info.svg" },
    { id = "bookmark", label = "Read status", used_in = { "book sheet" }, file = "icons/bookmark.svg" },
    { id = "list", label = "Feature a different book", used_in = { "book sheet" }, file = "icons/list.svg" },
    { id = "layout", label = "Edit layout", used_in = { "home sheet" }, file = "icons/layout.svg" },
    { id = "rotation_lock", label = "Rotation lock", used_in = { "quick settings" },
      file = "icons/rotation_lock.svg" },
    { id = "power", label = "Sleep (power)", used_in = { "quick settings" }, file = "icons/power.svg" },
    { id = "back", label = "Back", used_in = { "settings menu" }, file = "icons/back.svg" },
    { id = "close", label = "Close", used_in = { "settings menu" }, file = "icons/close.svg" },
    { id = "check", label = "Checked", used_in = { "settings menu" }, file = "icons/check.svg" },
}

-- The path of the icon file for id, in the form Fonts.path gives a plugin file, or nil for an
-- id the registry doesn't hold.
function Icons.path(id)
    for _, entry in ipairs(Icons.entries) do
        if entry.id == id then
            return Fonts.path(entry.file)
        end
    end
    return nil
end

return Icons
