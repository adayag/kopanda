-- The settings store: reads fall back to the schema default, writes outside the schema are
-- refused (C3), and the file's schema_version drives migration and protects newer files (C4).
describe("Settings", function()
    local harness = require("plugin_harness")
    local lfs = require("libs/libkoreader-lfs")
    local dir = harness.state_dir
    local file = harness.settings_file
    local Settings

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function read(path)
        local f = assert(io.open(path, "rb"))
        local text = f:read("*a")
        f:close()
        return text
    end

    -- Writes the settings file with text, making its directory first.
    local function store(text)
        lfs.mkdir(dir)
        write(file, text)
    end

    local function clear()
        os.remove(file)
        os.remove(file .. ".old")
        os.remove(dir .. "/state.lua")
        os.remove(dir .. "/state.lua.old")
        os.remove(dir)
    end

    before_each(function()
        clear()
        Settings = require("settings")
        Settings._reset()
    end)

    after_each(function()
        Settings._reset()
        clear()
    end)

    describe("get", function()
        it("returns the default with no file", function()
            assert.is_nil(lfs.attributes(dir, "mode"))
            assert.equals("diner", Settings.get("look"))
        end)

        it("returns the default with a corrupt file and no backup", function()
            store("this is not lua {{{")
            assert.equals("diner", Settings.get("look"))
            Settings._reset()
            store("return 5")
            assert.equals("diner", Settings.get("look"))
        end)

        it("reads KOReader's .old backup beside a corrupt file", function()
            store("this is not lua {{{")
            write(file .. ".old", 'return { look = "editorial" }')
            assert.equals("editorial", Settings.get("look"))
        end)

        it("returns the default for a stored value the schema doesn't allow", function()
            store('return { look = "retro" }')
            assert.equals("diner", Settings.get("look"))
        end)

        it("returns the stored value when it is valid", function()
            store('return { look = "editorial" }')
            assert.equals("editorial", Settings.get("look"))
        end)

        it("returns nil for a key the schema doesn't define", function()
            store('return { look = "editorial", colour = "red" }')
            assert.is_nil(Settings.get("colour"))
        end)
    end)

    describe("set", function()
        it("refuses a key the schema doesn't define and leaves the file as it was", function()
            local text = 'return { look = "editorial" }'
            store(text)
            local ok, reason = Settings.set("colour", "red")
            assert.is_false(ok)
            assert.is_string(reason)
            assert.equals(text, read(file))
            assert.is_nil(Settings.get("colour"))
        end)

        it("refuses a value the key's type doesn't allow and leaves the file as it was", function()
            local text = 'return { look = "editorial" }'
            store(text)
            local ok, reason = Settings.set("look", "retro")
            assert.is_false(ok)
            assert.is_string(reason)
            assert.equals(text, read(file))
            assert.equals("editorial", Settings.get("look"))
        end)

        it("creates the directory, writes at once and survives a reopen", function()
            assert.is_nil(lfs.attributes(dir, "mode"))
            assert.is_true(Settings.set("look", "editorial"))
            assert.equals("directory", lfs.attributes(dir, "mode"))
            assert.equals("editorial", dofile(file).look)
            Settings._reset()
            assert.equals("editorial", Settings.get("look"))
        end)

        it("returns false and keeps reading the default when the directory is a file", function()
            lfs.mkdir(require("datastorage"):getSettingsDir())
            write(dir, "not a directory")
            local ok, reason = Settings.set("look", "editorial")
            assert.is_false(ok)
            assert.is_string(reason)
            assert.equals("diner", Settings.get("look"))
        end)
        it("returns false and keeps reading what the file holds when the file won't take the write", function()
            local text = 'return { look = "editorial" }'
            store(text)
            assert.equals(0, os.execute("chmod 444 '" .. file .. "'"))
            local ok, reason = Settings.set("look", "diner")
            os.execute("chmod 644 '" .. file .. "'")
            assert.is_false(ok)
            assert.is_string(reason)
            assert.equals(text, read(file))
            assert.equals("editorial", Settings.get("look"))
        end)
    end)

    describe("layout.rows", function()
        local Schema = require("schema")
        local default
        for _, entry in ipairs(Schema.keys) do
            if entry.id == "layout.rows" then
                default = entry.default
            end
        end

        local function slot(widget, share)
            return { widget = widget, share = share }
        end

        -- Every layout the rows type refuses, by what is wrong with it.
        local refused = {
            ["a string"] = "date",
            ["a number"] = 1,
            ["a boolean"] = true,
            ["no rows"] = {},
            ["rows under string keys"] = { top = { slot("date", 1) } },
            ["a row with a hole"] = { { slot("date", 1) }, nil, { slot("quote", 1) } },
            ["a row that is a string"] = { "date" },
            ["a row with no slot"] = { {} },
            ["a row of four"] = { { slot("date", 1), slot("clock", 1), slot("weather", 1), slot("quote", 1) } },
            ["a slot that is a string"] = { { "date" } },
            ["a widget not in the list"] = { { slot("calendar", 1) } },
            ["a widget that is not a string"] = { { slot(1, 1) } },
            ["a widget twice in a row"] = { { slot("date", 1), slot("date", 1) } },
            ["a widget twice across rows"] = { { slot("date", 1) }, { slot("date", 2) } },
            ["share 0"] = { { slot("date", 0) } },
            ["share 4"] = { { slot("date", 4) } },
            ["share 1.5"] = { { slot("date", 1.5) } },
            ["share as a string"] = { { slot("date", "1") } },
            ["share infinite"] = { { slot("date", math.huge) } },
            ["share NaN"] = { { slot("date", 0 / 0) } },
            ["a slot with no share"] = { { { widget = "date" } } },
            ["a slot with no widget"] = { { { share = 1 } } },
            ["a slot with an extra field"] = { { { widget = "date", share = 1, align = "left" } } },
        }

        local accepted = {
            ["the default"] = default,
            ["two columns"] = { { slot("date", 2), slot("clock", 1) } },
            ["one column"] = { { slot("quote", 1) }, { slot("stats", 3) } },
            ["three columns"] = { { slot("date", 1), slot("clock", 2), slot("weather", 3) }, { slot("quote", 1) } },
        }

        it("refuses every malformed layout and leaves the file byte-identical", function()
            local text = 'return { look = "editorial" }'
            store(text)
            for what, value in pairs(refused) do
                local ok, reason = Settings.set("layout.rows", value)
                assert.is_false(ok, what)
                assert.is_string(reason, what)
                assert.equals(text, read(file), what)
            end
        end)

        it("never raises in its validator", function()
            local validate = Settings.validators.rows
            local entry = Schema.keys[3]
            for what, value in pairs(refused) do
                local ok, valid = pcall(validate, entry, value)
                assert.is_true(ok, what .. ": " .. tostring(valid))
                assert.is_false(valid, what)
            end
        end)

        it("accepts the default and one, two and three column layouts, which survive a reopen", function()
            for what, value in pairs(accepted) do
                assert.is_true(Settings.set("layout.rows", value), what)
                Settings._reset()
                assert.same(value, Settings.get("layout.rows"), what)
            end
        end)

        it("reads a stored malformed layout as the default without raising", function()
            local stored = {
                ["a string"] = '"date"',
                ["a row of four"] = '{ { { widget = "date", share = 1 }, { widget = "clock", share = 1 }, '
                    .. '{ widget = "weather", share = 1 }, { widget = "quote", share = 1 } } }',
                ["an unknown id"] = '{ { { widget = "calendar", share = 1 } } }',
                ["a repeated id"] = '{ { { widget = "date", share = 1 } }, { { widget = "date", share = 1 } } }',
                ["share 0"] = '{ { { widget = "date", share = 0 } } }',
                ["share 1.5"] = '{ { { widget = "date", share = 1.5 } } }',
            }
            for what, lua in pairs(stored) do
                Settings._reset()
                store('return { ["layout.rows"] = ' .. lua .. ' }')
                local ok, value = pcall(Settings.get, "layout.rows")
                assert.is_true(ok, what .. ": " .. tostring(value))
                assert.equals(default, value, what)
            end
        end)

        it("writes a table value that a reopen reads back", function()
            local value = { { slot("weather", 1), slot("stats", 2) } }
            assert.is_true(Settings.set("layout.rows", value))
            assert.same(value, dofile(file)["layout.rows"])
            Settings._reset()
            assert.same(value, Settings.get("layout.rows"))
        end)
    end)

    describe("text_size", function()
        it("is medium by default and takes small and large", function()
            assert.equals("medium", Settings.get("text_size"))
            assert.is_true(Settings.set("text_size", "small"))
            assert.is_true(Settings.set("text_size", "large"))
            Settings._reset()
            assert.equals("large", Settings.get("text_size"))
            assert.is_false((Settings.set("text_size", "huge")))
        end)
    end)

    describe("schema_version", function()
        it("reads a file with no version as version 1 and stamps it on the first write", function()
            local text = 'return { look = "editorial" }'
            store(text)
            assert.equals("editorial", Settings.get("look"))
            assert.equals(text, read(file))
            assert.is_true(Settings.set("look", "diner"))
            assert.same({ look = "diner", schema_version = 1 }, dofile(file))
        end)

        it("runs each migration step in order and stamps the target version", function()
            local order = {}
            local steps = {
                [2] = function(data)
                    order[#order + 1] = 2
                    data.colour = data.color
                    data.color = nil
                    return data
                end,
                [3] = function(data)
                    order[#order + 1] = 3
                    data.look = data.colour == "red" and "diner" or "editorial"
                    data.colour = nil
                    return data
                end,
            }
            local migrated = Settings._migrate({ color = "red" }, steps, 3)
            assert.same({ 2, 3 }, order)
            assert.same({ look = "diner", schema_version = 3 }, migrated)
        end)

        it("starts migration from the stored version", function()
            local order = {}
            local steps = {
                [2] = function(data)
                    order[#order + 1] = 2
                    return data
                end,
                [3] = function(data)
                    order[#order + 1] = 3
                    return data
                end,
            }
            assert.same({ schema_version = 3 }, Settings._migrate({ schema_version = 2 }, steps, 3))
            assert.same({ 3 }, order)
        end)

        describe("on open of an older file", function()
            local Schema = require("schema")
            local Migrations = require("migrations")

            after_each(function()
                Schema.version = 1
                Migrations[2] = nil
            end)

            it("migrates it, stamps the version and writes it at once", function()
                Schema.version = 2
                Migrations[2] = function(data)
                    data.look = "editorial"
                    return data
                end
                store('return { look = "diner" }')
                Settings._reset()
                assert.equals("editorial", Settings.get("look"))
                assert.same({ look = "editorial", schema_version = 2 }, dofile(file))
            end)

            it("leaves the file untouched and refuses writes when a step raises", function()
                Schema.version = 2
                Migrations[2] = function()
                    error("step failed")
                end
                local text = 'return { look = "diner" }'
                store(text)
                Settings._reset()
                assert.equals("diner", Settings.get("look"))
                assert.is_false((Settings.set("look", "editorial")))
                assert.equals(text, read(file))
            end)
        end)

        it("reads a newer file with per-key fallback and refuses every write to it", function()
            local text = 'return { schema_version = 99, look = "editorial" }'
            store(text)
            assert.equals("editorial", Settings.get("look"))
            local ok, reason = Settings.set("look", "diner")
            assert.is_false(ok)
            assert.is_string(reason)
            assert.equals(text, read(file))
            assert.equals("editorial", Settings.get("look"))

            Settings._reset()
            text = 'return { schema_version = 99, look = "retro" }'
            store(text)
            assert.equals("diner", Settings.get("look"))
            assert.is_false((Settings.set("look", "editorial")))
            assert.equals(text, read(file))
        end)
    end)
end)
