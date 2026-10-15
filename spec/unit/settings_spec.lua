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
