-- The settings schema is pure data in the shape the device menus and the studio read (C1).
describe("schema.lua", function()
    local harness = require("plugin_harness")
    local path = harness.plugin_dir .. "/schema.lua"

    -- schema.lua run in an environment with nothing in it: no require, no globals.
    local function load_bare()
        local chunk = assert(loadfile(path))
        setfenv(chunk, {})
        return chunk()
    end

    -- The paths of every function value reachable from value.
    local function functions_in(value, at, found)
        found = found or {}
        if type(value) == "function" then
            found[#found + 1] = at
        elseif type(value) == "table" then
            for k, v in pairs(value) do
                functions_in(k, at .. "[key]", found)
                functions_in(v, at .. "." .. tostring(k), found)
            end
        end
        return found
    end

    it("loads with no require and no globals, and holds no functions", function()
        local schema = load_bare()
        assert.is_table(schema)
        assert.same({}, functions_in(schema, "schema"))
    end)

    it("reports a function hidden in the data", function()
        assert.same({ "schema.keys.1.check" }, functions_in({ keys = { { check = print } } }, "schema"))
    end)

    it("is version 1 with the nine keys of the Keys tables, in order", function()
        local schema = load_bare()
        assert.equals(1, schema.version)
        assert.same({
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
                id = "layout.rows",
                type = "rows",
                widgets = { "date", "clock", "weather", "quote", "stats", "featured" },
                max_columns = 3,
                default = {
                    { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                    { { widget = "featured", share = 1 } },
                    { { widget = "quote", share = 1 } },
                    { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
                },
                label = "Layout",
                group = "home",
            },
            {
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
                id = "featured.pinned",
                type = "path",
                default = false,
                label = "Featured book",
                group = "featured",
            },
            {
                id = "launcher.entries",
                type = "launcher",
                max_entries = 6,
                targets = {
                    kopanda = { "library", "series", "authors", "settings" },
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
        }, schema.keys)
    end)

    it("validates the path type, whose default false is allowed", function()
        local Settings = require("settings")
        assert.is_function(Settings.validators.path)
        local pinned = load_bare().keys[8]
        assert.equals("featured.pinned", pinned.id)
        assert.is_true(Settings.validators.path(pinned, pinned.default))
    end)

    it("validates the launcher type, whose default six are allowed", function()
        local Settings = require("settings")
        assert.is_function(Settings.validators.launcher)
        local launcher = load_bare().keys[9]
        assert.equals("launcher.entries", launcher.id)
        assert.is_true(Settings.validators.launcher(launcher, launcher.default))
    end)

    it("has no clock.twenty_four_hour key", function()
        for _, entry in ipairs(load_bare().keys) do
            assert.is_not.equals("clock.twenty_four_hour", entry.id)
        end
    end)

    it("gives every entry an id, type, default, label and group, with unique ids", function()
        local seen = {}
        for i, entry in ipairs(load_bare().keys) do
            for _, field in ipairs({ "id", "type", "label", "group" }) do
                assert.is_string(entry[field], "entry " .. i .. " has no " .. field)
            end
            assert.is_not_nil(entry.default, "entry " .. i .. " has no default")
            assert.is_nil(seen[entry.id], "id " .. entry.id .. " is used twice")
            seen[entry.id] = true
        end
    end)

    it("uses only types settings.lua validates, and every default passes its type", function()
        local Settings = require("settings")
        for _, entry in ipairs(load_bare().keys) do
            local validate = Settings.validators[entry.type]
            assert.is_function(validate, "no validator for type " .. entry.type)
            assert.is_true(validate(entry, entry.default), entry.id .. "'s default is not allowed")
        end
    end)

    it("lists each choice with a value and a label, and the default among the values", function()
        local Settings = require("settings")
        for _, entry in ipairs(load_bare().keys) do
            if entry.type == "choice" then
                assert.truthy(#entry.choices > 0)
                for _, choice in ipairs(entry.choices) do
                    assert.is_string(choice.value)
                    assert.is_string(choice.label)
                end
                assert.is_true(Settings.validators.choice(entry, entry.default))
            end
        end
        local look = load_bare().keys[1]
        assert.is_false(Settings.validators.choice(look, "retro"))
        assert.is_false(Settings.validators.choice(look, nil))
    end)
end)
