-- The shared validator corpus: each case is a schema key, a value and whether the key's validator
-- allows it. spec/unit/studio_validators_spec.lua asserts the plugin's Settings.validators give
-- each verdict and studio/test/core/validators.test.ts asserts the studio's do, reading this file
-- with the studio's own reader, so it stays in that reader's subset: literals only.
return {
    -- look
    { key = "look", value = "diner", valid = true, why = "a listed choice" },
    { key = "look", value = "editorial", valid = true, why = "a listed choice" },
    { key = "look", value = "Diner", valid = false, why = "a choice's label, not its value" },
    { key = "look", value = "bistro", valid = false, why = "an unlisted string" },
    { key = "look", value = 1, valid = false, why = "a number" },

    -- text_size
    { key = "text_size", value = "small", valid = true, why = "a listed choice" },
    { key = "text_size", value = "medium", valid = true, why = "a listed choice" },
    { key = "text_size", value = "large", valid = true, why = "a listed choice" },
    { key = "text_size", value = "huge", valid = false, why = "an unlisted string" },
    { key = "text_size", value = 2, valid = false, why = "a number" },

    -- weather.units
    { key = "weather.units", value = "fahrenheit", valid = true, why = "a listed choice" },
    { key = "weather.units", value = "celsius", valid = true, why = "a listed choice" },
    { key = "weather.units", value = "kelvin", valid = false, why = "an unlisted string" },
    { key = "weather.units", value = 0, valid = false, why = "a number" },

    -- quote.source
    { key = "quote.source", value = "builtin", valid = true, why = "a listed choice" },
    { key = "quote.source", value = "web", valid = false, why = "an unlisted string" },
    { key = "quote.source", value = 1, valid = false, why = "a number" },
    { key = "quote.source", value = { "builtin" }, valid = false, why = "a table holding a choice" },

    -- stats.show
    { key = "stats.show", value = true, valid = true, why = "true" },
    { key = "stats.show", value = false, valid = true, why = "false" },
    { key = "stats.show", value = 1, valid = false, why = "a number" },
    { key = "stats.show", value = "true", valid = false, why = "a string" },

    -- layout.rows
    {
        key = "layout.rows",
        value = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "featured", share = 1 } },
            { { widget = "quote", share = 1 } },
            { { widget = "launcher", share = 1 } },
            { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
        },
        valid = true,
        why = "the default",
    },
    { key = "layout.rows", value = {}, valid = false, why = "no rows" },
    {
        key = "layout.rows",
        value = {
            [1] = { { widget = "date", share = 1 } },
            [3] = { { widget = "clock", share = 1 } },
        },
        valid = false,
        why = "a sparse list of rows",
    },
    { key = "layout.rows", value = { top = { { widget = "date", share = 1 } } }, valid = false, why = "a keyed table" },
    {
        key = "layout.rows",
        value = { {
            { widget = "date", share = 1 },
            { widget = "clock", share = 1 },
            { widget = "weather", share = 1 },
        } },
        valid = true,
        why = "a row of three, the most a row holds",
    },
    {
        key = "layout.rows",
        value = { {
            { widget = "date", share = 1 },
            { widget = "clock", share = 1 },
            { widget = "weather", share = 1 },
            { widget = "quote", share = 1 },
        } },
        valid = false,
        why = "a row of four",
    },
    { key = "layout.rows", value = { {} }, valid = false, why = "an empty row" },
    { key = "layout.rows", value = { { { widget = "date", share = 0 } } }, valid = false, why = "a share of 0" },
    { key = "layout.rows", value = { { { widget = "date", share = 3 } } }, valid = true, why = "a share of 3" },
    { key = "layout.rows", value = { { { widget = "date", share = 4 } } }, valid = false, why = "a share of 4" },
    { key = "layout.rows", value = { { { widget = "date", share = 1.5 } } }, valid = false, why = "a share of 1.5" },
    { key = "layout.rows", value = { { { widget = "date", share = "1" } } }, valid = false, why = "a string share" },
    {
        key = "layout.rows",
        value = { { { widget = "date", share = 1, align = "left" } } },
        valid = false,
        why = "a slot with an extra field",
    },
    { key = "layout.rows", value = { { { widget = "date" } } }, valid = false, why = "a slot with no share" },
    {
        key = "layout.rows",
        value = { { { widget = "date", share = 1 } }, { { widget = "date", share = 1 } } },
        valid = false,
        why = "a widget repeated across rows",
    },
    {
        key = "layout.rows",
        value = { { { widget = "date", share = 1 }, { widget = "date", share = 2 } } },
        valid = false,
        why = "a widget repeated in a row",
    },
    { key = "layout.rows", value = { { { widget = "almanac", share = 1 } } }, valid = false, why = "an unknown widget" },
    { key = "layout.rows", value = "date", valid = false, why = "a string" },

    -- layout.rows_2
    {
        key = "layout.rows_2",
        value = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "reading", share = 1 } },
            { { widget = "streak", share = 1 }, { widget = "forecast", share = 1 } },
            { { widget = "hours", share = 1 }, { widget = "records", share = 1 } },
        },
        valid = true,
        why = "the default",
    },
    {
        key = "layout.rows_2",
        value = { { { widget = "reading", share = 1 } }, { { widget = "reading", share = 1 } } },
        valid = false,
        why = "a widget repeated across rows",
    },

    -- weather.location
    {
        key = "weather.location",
        value = { name = "Chicago, Illinois", latitude = 41.85003, longitude = -87.65005 },
        valid = true,
        why = "the default",
    },
    {
        key = "weather.location",
        value = { name = "Seattle", latitude = 47.60621, longitude = -122.33207, country = "US" },
        valid = false,
        why = "an extra field",
    },
    {
        key = "weather.location",
        value = { name = "", latitude = 47.60621, longitude = -122.33207 },
        valid = false,
        why = "an empty name",
    },
    {
        key = "weather.location",
        value = { name = "North Pole", latitude = 90, longitude = -180 },
        valid = true,
        why = "latitude 90 and longitude -180, the edges",
    },
    {
        key = "weather.location",
        value = { name = "Nowhere", latitude = 91, longitude = 0 },
        valid = false,
        why = "latitude 91",
    },
    {
        key = "weather.location",
        value = { name = "Nowhere", latitude = 0, longitude = -181 },
        valid = false,
        why = "longitude -181",
    },
    {
        key = "weather.location",
        value = { name = "Chicago", latitude = "41.85003", longitude = -87.65005 },
        valid = false,
        why = "a string coordinate",
    },
    {
        key = "weather.location",
        value = { name = "Chicago", latitude = 41.85003 },
        valid = false,
        why = "a missing longitude",
    },
    { key = "weather.location", value = "Chicago", valid = false, why = "a string" },

    -- featured.pinned
    { key = "featured.pinned", value = false, valid = true, why = "false, the most recent book" },
    { key = "featured.pinned", value = true, valid = false, why = "true" },
    { key = "featured.pinned", value = "/a", valid = true, why = "an absolute path" },
    { key = "featured.pinned", value = "/", valid = false, why = "the root alone" },
    { key = "featured.pinned", value = "a/b", valid = false, why = "a relative path" },
    { key = "featured.pinned", value = "", valid = false, why = "an empty string" },

    -- wallpaper.file
    { key = "wallpaper.file", value = false, valid = true, why = "false, no wallpaper" },
    { key = "wallpaper.file", value = "/mnt/us/flowers.png", valid = true, why = "an absolute path" },
    { key = "wallpaper.file", value = "flowers.png", valid = false, why = "a relative path" },
    { key = "wallpaper.file", value = "/", valid = false, why = "the root alone" },

    -- launcher.entries
    {
        key = "launcher.entries",
        value = {
            { kind = "kopanda", target = "library" },
            { kind = "kopanda", target = "series" },
            { kind = "kopanda", target = "authors" },
            { kind = "koreader", target = "history" },
            { kind = "koreader", target = "wifi" },
            { kind = "kopanda", target = "settings" },
        },
        valid = true,
        why = "the default",
    },
    { key = "launcher.entries", value = {}, valid = true, why = "an empty list" },
    {
        key = "launcher.entries",
        value = {
            { kind = "kopanda", target = "library" },
            { kind = "kopanda", target = "series" },
            { kind = "kopanda", target = "authors" },
            { kind = "koreader", target = "history" },
            { kind = "koreader", target = "wifi" },
            { kind = "kopanda", target = "settings" },
            { kind = "koreader", target = "favorites" },
        },
        valid = false,
        why = "seven entries",
    },
    {
        key = "launcher.entries",
        value = { top = { kind = "kopanda", target = "library" } },
        valid = false,
        why = "a keyed table",
    },
    { key = "launcher.entries", value = { { kind = "kopanda", target = "library" } }, valid = true, why = "a kopanda entry" },
    { key = "launcher.entries", value = { { kind = "kopanda" } }, valid = false, why = "a kopanda entry with no target" },
    {
        key = "launcher.entries",
        value = { { kind = "kopanda", target = "library", label = "Library" } },
        valid = false,
        why = "a kopanda entry with a label",
    },
    { key = "launcher.entries", value = { { kind = "koreader", target = "history" } }, valid = true, why = "a koreader entry" },
    { key = "launcher.entries", value = { { kind = "koreader" } }, valid = false, why = "a koreader entry with no target" },
    {
        key = "launcher.entries",
        value = { { kind = "koreader", target = "history", icon = "history" } },
        valid = false,
        why = "a koreader entry with an icon",
    },
    {
        key = "launcher.entries",
        value = { { kind = "plugin", plugin = "calibre", action = "search", label = "Calibre", icon = "calibre" } },
        valid = true,
        why = "a plugin entry",
    },
    {
        key = "launcher.entries",
        value = { { kind = "plugin", plugin = "calibre", action = "search", label = "Calibre" } },
        valid = false,
        why = "a plugin entry with no icon",
    },
    {
        key = "launcher.entries",
        value = { {
            kind = "plugin", plugin = "calibre", action = "search", label = "Calibre", icon = "calibre", path = "/x",
        } },
        valid = false,
        why = "a plugin entry with a path",
    },
    {
        key = "launcher.entries",
        value = { { kind = "plugin", plugin = "", action = "search", label = "Calibre", icon = "calibre" } },
        valid = false,
        why = "a plugin entry with an empty plugin",
    },
    {
        key = "launcher.entries",
        value = { { kind = "action", action = "wifi_toggle", label = "Wi-Fi", icon = "action" } },
        valid = true,
        why = "an action entry",
    },
    {
        key = "launcher.entries",
        value = { { kind = "action", action = "wifi_toggle", icon = "action" } },
        valid = false,
        why = "an action entry with no label",
    },
    {
        key = "launcher.entries",
        value = { { kind = "action", action = "wifi_toggle", label = "Wi-Fi", icon = "action", plugin = "x" } },
        valid = false,
        why = "an action entry with a plugin",
    },
    {
        key = "launcher.entries",
        value = { { kind = "action", action = "wifi_toggle", label = "", icon = "action" } },
        valid = false,
        why = "an action entry with an empty label",
    },
    {
        key = "launcher.entries",
        value = { { kind = "action", action = "wifi_toggle", label = "Wi-Fi", icon = 1 } },
        valid = false,
        why = "an action entry with a number icon",
    },
    {
        key = "launcher.entries",
        value = { { kind = "directory", path = "/mnt/us/documents", label = "Documents" } },
        valid = true,
        why = "a directory entry",
    },
    {
        key = "launcher.entries",
        value = { { kind = "directory", path = "/mnt/us/documents" } },
        valid = false,
        why = "a directory entry with no label",
    },
    {
        key = "launcher.entries",
        value = { { kind = "directory", path = "/mnt/us/documents", label = "Documents", icon = "folder" } },
        valid = false,
        why = "a directory entry with an icon",
    },
    {
        key = "launcher.entries",
        value = { { kind = "directory", path = "/mnt/us/documents", label = "" } },
        valid = false,
        why = "a directory entry with an empty label",
    },
    {
        key = "launcher.entries",
        value = { { kind = "directory", path = "documents", label = "Documents" } },
        valid = false,
        why = "a relative directory path",
    },
    {
        key = "launcher.entries",
        value = { { kind = "directory", path = "/", label = "Root" } },
        valid = false,
        why = "the root directory path",
    },
    {
        key = "launcher.entries",
        value = { { kind = "folder", label = "Tools", entries = { { kind = "koreader", target = "wifi" } } } },
        valid = true,
        why = "a folder entry",
    },
    {
        key = "launcher.entries",
        value = { { kind = "folder", label = "Tools" } },
        valid = false,
        why = "a folder entry with no entries",
    },
    {
        key = "launcher.entries",
        value = { {
            kind = "folder", label = "Tools", icon = "folder", entries = { { kind = "koreader", target = "wifi" } },
        } },
        valid = false,
        why = "a folder entry with an icon",
    },
    {
        key = "launcher.entries",
        value = { { kind = "folder", label = "Tools", entries = {} } },
        valid = false,
        why = "an empty folder",
    },
    {
        key = "launcher.entries",
        value = { {
            kind = "folder",
            label = "Tools",
            entries = { { kind = "folder", label = "Inner", entries = { { kind = "koreader", target = "wifi" } } } },
        } },
        valid = false,
        why = "a folder inside a folder",
    },
    {
        key = "launcher.entries",
        value = { {
            kind = "folder",
            label = "More",
            entries = {
                { kind = "kopanda", target = "library" },
                { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" },
                { kind = "koreader", target = "history" },
                { kind = "koreader", target = "wifi" },
                { kind = "kopanda", target = "settings" },
                { kind = "koreader", target = "favorites" },
            },
        } },
        valid = true,
        why = "a folder of seven entries, which has no limit",
    },
    {
        key = "launcher.entries",
        value = { {
            kind = "folder",
            label = "Tools",
            entries = { [1] = { kind = "koreader", target = "wifi" }, [3] = { kind = "koreader", target = "history" } },
        } },
        valid = false,
        why = "a folder with a sparse list of entries",
    },
    {
        key = "launcher.entries",
        value = { { kind = "kopanda", target = "history" } },
        valid = false,
        why = "a kopanda entry naming a koreader screen",
    },
    {
        key = "launcher.entries",
        value = { { kind = "koreader", target = "library" } },
        valid = false,
        why = "a koreader entry naming a kopanda screen",
    },
    { key = "launcher.entries", value = { { kind = "shortcut", target = "library" } }, valid = false, why = "an unknown kind" },
    {
        key = "launcher.entries",
        value = { { kind = "toString", target = "library" } },
        valid = false,
        why = "a kind named like a JavaScript object's method",
    },
    { key = "launcher.entries", value = { { target = "library" } }, valid = false, why = "an entry with no kind" },
    { key = "launcher.entries", value = { "library" }, valid = false, why = "an entry that is a string" },
}
