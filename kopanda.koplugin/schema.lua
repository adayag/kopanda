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
    },
}
