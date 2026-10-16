-- The shared launcher-entry corpus: each case is an EntriesEdit operation, its arguments in order and
-- what it gives. result is the value returned; refused = true marks an operation that returns nil;
-- a remove also names whether a folder went with the entry (folder_removed). A position is { i } at
-- the top level or { f, i } inside the folder at top-level index f, 1-based as on the device.
-- spec/unit/studio_entries_edit_spec.lua runs each case through the plugin's EntriesEdit and
-- studio/test/core/entries-edit.test.ts through the studio's port, reading this file with the
-- studio's own reader, so it stays in that reader's subset: literals only.
return {
    -- move
    {
        op = "move", why = "up within the top level",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" } },
            { 2 }, -1,
        },
        result = { { kind = "kopanda", target = "series" }, { kind = "kopanda", target = "library" },
            { kind = "kopanda", target = "authors" } },
    },
    {
        op = "move", why = "down within the top level",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" } },
            { 2 }, 1,
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "authors" },
            { kind = "kopanda", target = "series" } },
    },
    {
        op = "move", why = "the top level's first entry up, past its start",
        args = { { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" } }, { 1 }, -1 },
        refused = true,
    },
    {
        op = "move", why = "the top level's last entry down, past its end",
        args = { { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" } }, { 2 }, 1 },
        refused = true,
    },
    {
        op = "move", why = "down within a folder",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" },
                { kind = "action", action = "c", label = "C", icon = "action" } } } },
            { 2, 1 }, 1,
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
            { kind = "action", action = "b", label = "B", icon = "action" },
            { kind = "action", action = "a", label = "A", icon = "action" },
            { kind = "action", action = "c", label = "C", icon = "action" } } } },
    },
    {
        op = "move", why = "up within a folder",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" },
                { kind = "action", action = "c", label = "C", icon = "action" } } } },
            { 2, 3 }, -1,
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
            { kind = "action", action = "a", label = "A", icon = "action" },
            { kind = "action", action = "c", label = "C", icon = "action" },
            { kind = "action", action = "b", label = "B", icon = "action" } } } },
    },
    {
        op = "move", why = "a folder's first entry up, past its start",
        args = {
            { { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" } } } },
            { 1, 1 }, -1,
        },
        refused = true,
    },
    {
        op = "move", why = "a folder's last entry down, past its end",
        args = {
            { { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" } } } },
            { 1, 2 }, 1,
        },
        refused = true,
    },

    -- remove
    {
        op = "remove", why = "a top-level entry",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" } },
            { 2 },
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "authors" } },
        folder_removed = false,
    },
    {
        op = "remove", why = "a folder, with its entries",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" } } },
                { kind = "kopanda", target = "settings" } },
            { 2 },
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "settings" } },
        folder_removed = false,
    },
    {
        op = "remove", why = "a folder's entry",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" },
                { kind = "action", action = "c", label = "C", icon = "action" } } } },
            { 2, 2 },
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
            { kind = "action", action = "a", label = "A", icon = "action" },
            { kind = "action", action = "c", label = "C", icon = "action" } } } },
        folder_removed = false,
    },
    {
        op = "remove", why = "a folder's only entry, which takes the folder",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" } } },
                { kind = "kopanda", target = "settings" } },
            { 2, 1 },
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "settings" } },
        folder_removed = true,
    },

    -- add
    {
        op = "add", why = "into a folder, at its end",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" } } } },
            { kind = "directory", path = "/mnt/us/books", label = "books" },
            2,
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
            { kind = "action", action = "a", label = "A", icon = "action" },
            { kind = "action", action = "b", label = "B", icon = "action" },
            { kind = "directory", path = "/mnt/us/books", label = "books" } } } },
    },
    {
        op = "add", why = "into a folder already holding six, past six inside it",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" }, { kind = "koreader", target = "history" },
                { kind = "koreader", target = "wifi" },
                { kind = "folder", label = "Tools", entries = {
                    { kind = "action", action = "a", label = "A", icon = "action" },
                    { kind = "action", action = "b", label = "B", icon = "action" },
                    { kind = "action", action = "c", label = "C", icon = "action" },
                    { kind = "action", action = "d", label = "D", icon = "action" },
                    { kind = "action", action = "e", label = "E", icon = "action" },
                    { kind = "action", action = "f", label = "F", icon = "action" } } } },
            { kind = "plugin", plugin = "calibre", action = "search", label = "Calibre", icon = "action" },
            6,
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
            { kind = "kopanda", target = "authors" }, { kind = "koreader", target = "history" },
            { kind = "koreader", target = "wifi" },
            { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" },
                { kind = "action", action = "c", label = "C", icon = "action" },
                { kind = "action", action = "d", label = "D", icon = "action" },
                { kind = "action", action = "e", label = "E", icon = "action" },
                { kind = "action", action = "f", label = "F", icon = "action" },
                { kind = "plugin", plugin = "calibre", action = "search", label = "Calibre", icon = "action" } } } },
    },
    {
        op = "add", why = "at the end of a top level of five",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" }, { kind = "koreader", target = "history" },
                { kind = "koreader", target = "wifi" } },
            { kind = "directory", path = "/mnt/us/books", label = "books" },
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
            { kind = "kopanda", target = "authors" }, { kind = "koreader", target = "history" },
            { kind = "koreader", target = "wifi" }, { kind = "directory", path = "/mnt/us/books", label = "books" } },
    },
    {
        op = "add", why = "to an empty top level",
        args = { {}, { kind = "kopanda", target = "library" } },
        result = { { kind = "kopanda", target = "library" } },
    },
    {
        op = "add", why = "at a top level of six with folders at 3 and 5: into the one at 3",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
                { kind = "folder", label = "Tools", entries = {
                    { kind = "action", action = "a", label = "A", icon = "action" } } },
                { kind = "koreader", target = "history" },
                { kind = "folder", label = "Games", entries = {
                    { kind = "action", action = "b", label = "B", icon = "action" } } },
                { kind = "kopanda", target = "settings" } },
            { kind = "directory", path = "/mnt/us/books", label = "books" },
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
            { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "directory", path = "/mnt/us/books", label = "books" } } },
            { kind = "koreader", target = "history" },
            { kind = "folder", label = "Games", entries = {
                { kind = "action", action = "b", label = "B", icon = "action" } } },
            { kind = "kopanda", target = "settings" } },
    },
    {
        op = "add", why = "at a top level of six with no folder: the sixth and the new one become More",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" }, { kind = "koreader", target = "history" },
                { kind = "koreader", target = "wifi" }, { kind = "kopanda", target = "settings" } },
            { kind = "plugin", plugin = "calibre", action = "search", label = "Calibre", icon = "action" },
        },
        result = { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
            { kind = "kopanda", target = "authors" }, { kind = "koreader", target = "history" },
            { kind = "koreader", target = "wifi" },
            { kind = "folder", label = "More", entries = {
                { kind = "kopanda", target = "settings" },
                { kind = "plugin", plugin = "calibre", action = "search", label = "Calibre", icon = "action" } } } },
    },
    {
        op = "add", why = "a folder, which doesn't nest",
        args = {
            { { kind = "kopanda", target = "library" } },
            { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" } } },
        },
        refused = true,
    },

    -- count
    { op = "count", why = "an empty top level", args = { {} }, result = 0 },
    {
        op = "count", why = "the top level only, not a folder's entries",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "folder", label = "Tools", entries = {
                { kind = "action", action = "a", label = "A", icon = "action" },
                { kind = "action", action = "b", label = "B", icon = "action" },
                { kind = "action", action = "c", label = "C", icon = "action" } } } },
        },
        result = 2,
    },
    {
        op = "count", why = "the default six",
        args = {
            { { kind = "kopanda", target = "library" }, { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" }, { kind = "koreader", target = "history" },
                { kind = "koreader", target = "wifi" }, { kind = "kopanda", target = "settings" } },
        },
        result = 6,
    },

    -- kind_line
    { op = "kind_line", why = "a KoPanda screen", args = { { kind = "kopanda", target = "library" } },
        result = "KoPanda · library" },
    { op = "kind_line", why = "a KOReader screen", args = { { kind = "koreader", target = "wifi" } },
        result = "KOReader · wifi" },
    {
        op = "kind_line", why = "a plugin's action",
        args = { { kind = "plugin", plugin = "calibre", action = "search", label = "Calibre", icon = "action" } },
        result = "Plugin · calibre",
    },
    {
        op = "kind_line", why = "an action",
        args = { { kind = "action", action = "history", label = "History", icon = "action" } },
        result = "Action · history",
    },
    {
        op = "kind_line", why = "a folder on disk",
        args = { { kind = "directory", path = "/mnt/us/books", label = "books" } },
        result = "Folder on disk · /mnt/us/books",
    },
    {
        op = "kind_line", why = "a folder of one entry",
        args = { { kind = "folder", label = "Tools", entries = {
            { kind = "action", action = "a", label = "A", icon = "action" } } } },
        result = "Folder · 1 entry ›",
    },
    {
        op = "kind_line", why = "a folder of three entries",
        args = { { kind = "folder", label = "Tools", entries = {
            { kind = "action", action = "a", label = "A", icon = "action" },
            { kind = "action", action = "b", label = "B", icon = "action" },
            { kind = "action", action = "c", label = "C", icon = "action" } } } },
        result = "Folder · 3 entries ›",
    },
}
