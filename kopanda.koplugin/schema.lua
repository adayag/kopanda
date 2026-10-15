-- KoPanda's settings schema: every settings key, in the order the device menus and the studio
-- form show them. Pure data (no require, no functions) so a plain dofile loads it on the device
-- and in bin/schema-json. settings.lua holds one validator per type; a key of a new type brings
-- its validator. version changes only when stored values must change shape, with a step in
-- migrations.lua.
return {
    version = 1,
    keys = {
        {
            id = "look",
            type = "choice",
            choices = {
                { value = "diner", label = "Diner" },
                { value = "editorial", label = "Editorial" },
            },
            default = "diner",
            label = "Look",
            group = "appearance",
        },
        {
            id = "text_size",
            type = "choice",
            choices = {
                { value = "small", label = "Small" },
                { value = "medium", label = "Medium" },
                { value = "large", label = "Large" },
            },
            default = "medium",
            label = "Text size",
            group = "appearance",
        },
        {
            -- The home's rows, top to bottom; each row's slots, left to right, take the row's
            -- width by share. widgets lists the ids a slot may name, max_columns the slots a row
            -- may hold.
            id = "layout.rows",
            type = "rows",
            widgets = { "date", "clock", "weather", "quote", "stats" },
            max_columns = 3,
            default = {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "quote", share = 1 } },
                { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
            },
            label = "Layout",
            group = "home",
        },
        {
            -- Where the quote of the day comes from: builtin is quotes.lua.
            id = "quote.source",
            type = "choice",
            choices = {
                { value = "builtin", label = "Built-in" },
            },
            default = "builtin",
            label = "Quote source",
            group = "quote",
        },
        {
            id = "stats.show",
            type = "boolean",
            default = true,
            label = "Show reading stats",
            group = "stats",
        },
    },
}
