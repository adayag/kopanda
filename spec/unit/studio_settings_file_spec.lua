-- The studio writes the settings file as the plugin would and the plugin reads it key for key
-- (C1): spec/fixtures/studio/settings_written.lua is the studio's writer's output, held to it byte
-- for byte by studio/test/core/settings-written.test.ts.
describe("a studio-written settings file", function()
    local harness = require("plugin_harness")
    local LuaSettings = require("luasettings")
    local Schema = require("schema")
    local Settings = require("settings")
    local lfs = require("libs/libkoreader-lfs")
    local fixture = os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/studio/settings_written.lua"

    local function read(path)
        local f = assert(io.open(path, "rb"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function clear()
        os.remove(harness.settings_file)
        os.remove(harness.settings_file .. ".old")
        os.remove(harness.state_dir)
    end

    before_each(function()
        clear()
        Settings._reset()
    end)

    after_each(function()
        Settings._reset()
        clear()
    end)

    it("is what LuaSettings:flush writes for its data, but for the header's path", function()
        local path = os.tmpname()
        os.remove(path)
        LuaSettings:open(path):reset(dofile(fixture)):flush()
        local written = read(path)
        os.remove(path)
        local expected = read(fixture)

        assert.equals("-- " .. path .. "\n", written:match("^[^\n]*\n"))
        local body = written:gsub("^[^\n]*\n", "", 1)
        assert.equals(expected, expected:match("^[^\n]*\n") .. body)
    end)

    it("reads through Settings.get as written, every key but quote.source off its default", function()
        local data = dofile(fixture)
        lfs.mkdir(harness.state_dir)
        write(harness.settings_file, read(fixture))

        for _, entry in ipairs(Schema.keys) do
            local value = Settings.get(entry.id)
            assert.same(data[entry.id], value)
            if entry.id == "quote.source" then
                assert.same(entry.default, value)
            else
                assert.are_not.same(entry.default, value)
            end
        end
    end)
end)
