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
                { value = "riso", label = "Riso" },
                { value = "toybox", label = "Toybox" },
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
            widgets = { "date", "clock", "weather", "quote", "stats", "featured", "launcher" },
            max_columns = 3,
            default = {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "featured", share = 1 } },
                { { widget = "quote", share = 1 } },
                { { widget = "launcher", share = 1 } },
                { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
            },
            label = "Layout",
            group = "home",
        },
        {
            -- Where the weather is for, as coordinates; the device menus and the studio geocode a
            -- typed place into them.
            id = "weather.location",
            type = "location",
            default = { name = "Chicago, Illinois", latitude = 41.85003, longitude = -87.65005 },
            label = "Weather location",
            group = "weather",
        },
        {
            id = "weather.units",
            type = "choice",
            choices = {
                { value = "fahrenheit", label = "Fahrenheit" },
                { value = "celsius", label = "Celsius" },
            },
            default = "fahrenheit",
            label = "Units",
            group = "weather",
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
        {
            -- A book to feature on the home in place of the last one opened; false features the
            -- last one.
            id = "featured.pinned",
            type = "path",
            default = false,
            label = "Featured book",
            group = "featured",
        },
        {
            -- The home's launcher, in order: KoPanda and KOReader screens, plugin and dispatcher
            -- actions, folders on disk and folders of entries. max_entries is the most the
            -- launcher holds; targets lists the screens a kopanda or koreader entry may name.
            id = "launcher.entries",
            type = "launcher",
            max_entries = 6,
            targets = {
                kopanda = { "library", "series", "authors", "settings", "quick_settings" },
                koreader = { "history", "favorites", "collections", "wifi" },
            },
            default = {
                { kind = "kopanda", target = "library" },
                { kind = "kopanda", target = "series" },
                { kind = "kopanda", target = "authors" },
                { kind = "koreader", target = "history" },
                { kind = "koreader", target = "wifi" },
                { kind = "kopanda", target = "settings" },
            },
            label = "Launcher",
            group = "launcher",
        },
    },
}
