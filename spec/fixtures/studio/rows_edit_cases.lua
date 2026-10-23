-- The shared row-operations corpus: each case is one RowsEdit operation, its arguments and either
-- its result or its refusal (the note, or true for a refusal with no note).
-- spec/unit/studio_rows_edit_spec.lua asserts the plugin's RowsEdit gives each and
-- studio/test/core/rows-edit.test.ts asserts the studio's port does, reading this file with the
-- studio's own reader, so it stays in that reader's subset: literals only. Indices are Lua's,
-- counting from 1.
return {
    -- move
    {
        op = "move",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
                { { widget = "quote", share = 1 } },
                { { widget = "launcher", share = 1 } },
                { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
            },
            2,
            -1,
        },
        result = {
            { { widget = "featured", share = 1 } },
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "quote", share = 1 } },
            { { widget = "launcher", share = 1 } },
            { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
        },
    },
    {
        op = "move",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
                { { widget = "quote", share = 1 } },
                { { widget = "launcher", share = 1 } },
                { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
            },
            3,
            1,
        },
        result = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "featured", share = 1 } },
            { { widget = "launcher", share = 1 } },
            { { widget = "quote", share = 1 } },
            { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
        },
    },
    {
        op = "move",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
            },
            1,
            -1,
        },
        refused = true,
    },
    {
        op = "move",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
            },
            2,
            1,
        },
        refused = true,
    },

    -- add_row
    {
        op = "add_row",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
            },
            "stats",
        },
        result = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "featured", share = 1 } },
            { { widget = "stats", share = 1 } },
        },
    },
    {
        op = "add_row",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
            },
            "clock",
        },
        refused = "Each widget can be on the home once.",
    },

    -- add_column
    {
        op = "add_column",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 2 } },
                { { widget = "featured", share = 1 } },
            },
            2,
            "weather",
        },
        result = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 2 } },
            { { widget = "featured", share = 1 }, { widget = "weather", share = 1 } },
        },
    },
    {
        op = "add_column",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 2 } },
                { { widget = "featured", share = 1 } },
            },
            1,
            "weather",
        },
        result = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 2 }, { widget = "weather", share = 1 } },
            { { widget = "featured", share = 1 } },
        },
    },
    {
        op = "add_column",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 }, { widget = "weather", share = 1 } },
                { { widget = "featured", share = 1 } },
            },
            1,
            "stats",
        },
        refused = "A row holds at most three columns.",
    },
    {
        op = "add_column",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
            },
            2,
            "date",
        },
        refused = "Each widget can be on the home once.",
    },

    -- change_widget
    {
        op = "change_widget",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 2 } },
                { { widget = "featured", share = 1 } },
            },
            1,
            2,
            "weather",
        },
        result = {
            { { widget = "date", share = 1 }, { widget = "weather", share = 2 } },
            { { widget = "featured", share = 1 } },
        },
    },
    {
        op = "change_widget",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
            },
            2,
            1,
            "clock",
        },
        refused = "Each widget can be on the home once.",
    },

    -- set_share
    {
        op = "set_share",
        args = { { { { widget = "date", share = 2 }, { widget = "clock", share = 3 } } }, 1, 2, 1 },
        result = { { { widget = "date", share = 2 }, { widget = "clock", share = 1 } } },
    },
    {
        op = "set_share",
        args = { { { { widget = "date", share = 1 }, { widget = "clock", share = 1 } } }, 1, 2, 2 },
        result = { { { widget = "date", share = 1 }, { widget = "clock", share = 2 } } },
    },
    {
        op = "set_share",
        args = { { { { widget = "date", share = 1 }, { widget = "clock", share = 1 } } }, 1, 1, 3 },
        result = { { { widget = "date", share = 3 }, { widget = "clock", share = 1 } } },
    },
    {
        op = "set_share",
        args = { { { { widget = "date", share = 1 }, { widget = "clock", share = 1 } } }, 1, 1, 4 },
        refused = "A column's width is 1, 2 or 3.",
    },

    -- remove_column
    {
        op = "remove_column",
        args = {
            {
                { { widget = "featured", share = 1 } },
                { { widget = "date", share = 1 }, { widget = "clock", share = 2 } },
            },
            2,
            1,
        },
        result = {
            { { widget = "featured", share = 1 } },
            { { widget = "clock", share = 2 } },
        },
    },
    {
        op = "remove_column",
        args = {
            { { { widget = "date", share = 1 }, { widget = "clock", share = 2 }, { widget = "weather", share = 3 } } },
            1,
            2,
        },
        result = { { { widget = "date", share = 1 }, { widget = "weather", share = 3 } } },
    },
    {
        op = "remove_column",
        args = { { { { widget = "featured", share = 1 } }, { { widget = "quote", share = 1 } } }, 2, 1 },
        refused = "A row keeps at least one column.",
    },

    -- remove_row
    {
        op = "remove_row",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
                { { widget = "quote", share = 1 } },
                { { widget = "launcher", share = 1 } },
                { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
            },
            3,
        },
        result = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "featured", share = 1 } },
            { { widget = "launcher", share = 1 } },
            { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
        },
    },
    {
        op = "remove_row",
        args = { { { { widget = "featured", share = 1 } } }, 1 },
        refused = "The home needs at least one row.",
    },

    -- reset: the schema's default
    {
        op = "reset",
        args = {},
        result = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "featured", share = 1 } },
            { { widget = "quote", share = 1 } },
            { { widget = "launcher", share = 1 } },
            { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
        },
    },

    -- unused
    {
        op = "unused",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
                { { widget = "quote", share = 1 } },
                { { widget = "launcher", share = 1 } },
                { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
            },
        },
        result = { "reading", "streak", "forecast", "hours", "records" },
    },
    {
        op = "unused",
        args = {
            {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
                { { widget = "quote", share = 1 } },
                { { widget = "launcher", share = 1 } },
                { { widget = "weather", share = 1 } },
            },
        },
        result = { "stats", "reading", "streak", "forecast", "hours", "records" },
    },
    {
        op = "unused",
        args = { { { { widget = "launcher", share = 1 } }, { { widget = "quote", share = 1 } } } },
        result = {
            "date", "clock", "weather", "stats", "featured", "reading", "streak", "forecast", "hours", "records",
        },
    },

    -- label
    { op = "label", args = { "date" }, result = "Date" },
    { op = "label", args = { "clock" }, result = "Clock" },
    { op = "label", args = { "weather" }, result = "Weather" },
    { op = "label", args = { "quote" }, result = "Quote" },
    { op = "label", args = { "stats" }, result = "Reading stats" },
    { op = "label", args = { "featured" }, result = "Featured book" },
    { op = "label", args = { "launcher" }, result = "Launcher" },
    { op = "label", args = { "reading" }, result = "Reading" },
    { op = "label", args = { "streak" }, result = "Streak" },
    { op = "label", args = { "forecast" }, result = "Finish by" },
    { op = "label", args = { "hours" }, result = "Reading hours" },
    { op = "label", args = { "records" }, result = "Sessions" },
    { op = "label", args = { "almanac" }, result = "almanac" },

    -- share_text
    { op = "share_text", args = { { { widget = "featured", share = 2 } }, 1 }, result = "full" },
    {
        op = "share_text",
        args = { { { widget = "date", share = 1 }, { widget = "clock", share = 1 } }, 2 },
        result = "1/2",
    },
    {
        op = "share_text",
        args = { { { widget = "date", share = 1 }, { widget = "clock", share = 2 } }, 1 },
        result = "1/3",
    },
    {
        op = "share_text",
        args = { { { widget = "date", share = 1 }, { widget = "clock", share = 2 } }, 2 },
        result = "2/3",
    },
    {
        op = "share_text",
        args = { { { widget = "date", share = 2 }, { widget = "clock", share = 2 } }, 1 },
        result = "1/2",
    },
    {
        op = "share_text",
        args = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 }, { widget = "weather", share = 1 } },
            3,
        },
        result = "1/3",
    },

    -- caption
    {
        op = "caption",
        args = {
            {
                { { widget = "featured", share = 1 } },
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "quote", share = 1 }, { widget = "launcher", share = 1 }, { widget = "stats", share = 1 } },
            },
            1,
            false,
        },
        result = "Row 1 · one column",
    },
    {
        op = "caption",
        args = {
            {
                { { widget = "featured", share = 1 } },
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "quote", share = 1 }, { widget = "launcher", share = 1 }, { widget = "stats", share = 1 } },
            },
            2,
            false,
        },
        result = "Row 2 · two columns",
    },
    {
        op = "caption",
        args = {
            {
                { { widget = "featured", share = 1 } },
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "quote", share = 1 }, { widget = "launcher", share = 1 }, { widget = "stats", share = 1 } },
            },
            3,
            false,
        },
        result = "Row 3 · three columns",
    },
    {
        op = "caption",
        args = {
            {
                { { widget = "featured", share = 1 } },
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "quote", share = 1 }, { widget = "launcher", share = 1 }, { widget = "stats", share = 1 } },
            },
            1,
            true,
        },
        result = "Row 1 · one column · selected",
    },
    {
        op = "caption",
        args = {
            {
                { { widget = "featured", share = 1 } },
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "quote", share = 1 }, { widget = "launcher", share = 1 }, { widget = "stats", share = 1 } },
            },
            2,
            true,
        },
        result = "Row 2 · two columns · selected",
    },
    {
        op = "caption",
        args = {
            {
                { { widget = "featured", share = 1 } },
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "quote", share = 1 }, { widget = "launcher", share = 1 }, { widget = "stats", share = 1 } },
            },
            3,
            true,
        },
        result = "Row 3 · three columns · selected",
    },
}
