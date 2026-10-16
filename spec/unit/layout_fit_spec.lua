-- bin/layout-fit runs the plugin's own fit rule, Layout.overflow, for a profile's screen and
-- settings file, and prints one count per row list (C7).
--
-- The date, the clock and the quote of the day change the home's heights with the day
-- (widgets/date.lua:40, widgets/quote.lua:75), so a comparison between this process and the
-- script's could straddle midnight and fail once; both run within the same few seconds and that
-- risk is accepted.
describe("bin/layout-fit", function()
    local harness = require("plugin_harness")
    local rapidjson = require("rapidjson")
    local root = harness.root

    local scratch

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

    -- Runs bin/layout-fit with args, stdin read from a file holding input, and TMPDIR set to a
    -- directory of this spec's own (so the scratch KO_HOME the script makes lands there), with
    -- env (a string of NAME=value words) before it. Returns stdout, stderr and the exit status.
    local function run(args, input, env)
        local stdin, stdout, stderr = scratch .. "/stdin", scratch .. "/stdout", scratch .. "/stderr"
        write(stdin, input)
        local command = string.format("cd '%s' && TMPDIR='%s' %s bin/layout-fit %s < '%s' > '%s' 2> '%s'",
            root, scratch .. "/tmp", env or "", args, stdin, stdout, stderr)
        local quoted = command:gsub("'", "'\\''")
        local pipe = assert(io.popen("sh -c '" .. quoted .. "'; echo $?"))
        local status = tonumber(pipe:read("*a"):match("(%d+)%s*$"))
        pipe:close()
        return read(stdout), read(stderr), status
    end

    local function fit(args, row_lists, env)
        local out, err, status = run(args, rapidjson.encode(row_lists), env)
        assert.equals(0, status, err)
        return rapidjson.decode(out)
    end

    local default = dofile(root .. "/kopanda.koplugin/schema.lua").keys[3].default
    local every_widget = {
        { { widget = "date", share = 1 } },
        { { widget = "clock", share = 1 } },
        { { widget = "weather", share = 1 } },
        { { widget = "quote", share = 1 } },
        { { widget = "stats", share = 1 } },
        { { widget = "featured", share = 1 } },
        { { widget = "launcher", share = 1 } },
    }

    before_each(function()
        scratch = os.tmpname()
        os.remove(scratch)
        assert.equals(0, os.execute("mkdir -p '" .. scratch .. "/tmp'"))
    end)

    after_each(function()
        os.execute("rm -rf '" .. scratch .. "'")
    end)

    it("counts what Layout.overflow counts in this process on the unit screen", function()
        harness.load()
        local Layout = require("layout")
        local Looks = require("looks")
        local Settings = require("settings")
        local Screen = require("device").screen
        local ctx = {
            look = Looks.active(),
            variant = Looks.variant(),
            text_size = Settings.get("text_size"),
            now = os.time(),
            screen = Screen,
        }
        local expected = { Layout.overflow(default, ctx), Layout.overflow(every_widget, ctx) }
        local answer = fit("600 800 160", { default, every_widget })
        assert.same({ width = 600, height = 800 }, answer.screen)
        assert.same(expected, answer.overflow)
        assert.truthy(expected[1] > 0 or expected[2] > 0, "one of the layouts overflows the unit screen")
        assert.same(answer.overflow, fit("600 800 160 '" .. scratch .. "/absent.lua'", { default, every_widget })
            .overflow, "a settings path that doesn't exist reads as no file")
    end)

    it("fits the default rows on the Colorsoft's screen", function()
        local answer = fit("1264 1680 300", { default })
        assert.same({ width = 1264, height = 1680 }, answer.screen)
        assert.same({ 0 }, answer.overflow)
    end)

    it("reads the look and the text size from the settings file", function()
        -- Every layout of one-widget rows, the widgets in the schema's order, on screens of a
        -- few heights: some sit near the edge, where the other look at the large text size
        -- leaves out a different number of rows.
        local layouts = {}
        for mask = 1, 2 ^ #every_widget - 1 do
            local rows = {}
            for i, row in ipairs(every_widget) do
                if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then
                    rows[#rows + 1] = row
                end
            end
            layouts[#layouts + 1] = rows
        end
        local text = 'return { ["look"] = "editorial", ["schema_version"] = 1, ["text_size"] = "large" }\n'
        local settings = scratch .. "/settings.lua"
        write(settings, text)
        local differs = false
        for _, h in ipairs({ 800, 900, 1000 }) do
            local without = fit("600 " .. h .. " 160", layouts).overflow
            local with = fit("600 " .. h .. " 160 '" .. settings .. "'", layouts).overflow
            assert.equals(#layouts, #with)
            differs = differs or table.concat(without, ",") ~= table.concat(with, ",")
        end
        assert.is_true(differs, "some layout's count changes with the settings file")
        assert.equals(text, read(settings), "the profile's file is not written")
    end)

    it("refuses a row list the plugin's validator refuses, naming its index", function()
        local repeated = {
            { { widget = "date", share = 1 } },
            { { widget = "clock", share = 1 }, { widget = "clock", share = 1 } },
        }
        local out, err, status = run("600 800 160", rapidjson.encode({ default, repeated }))
        assert.equals(1, status)
        assert.equals("", out)
        assert.truthy(err:find("row list 2", 1, true), err)
    end)

    it("refuses input that isn't a JSON array of row lists", function()
        for _, input in ipairs({ "not json", "{}", '{"a":1}', "[1, 2]", '"rows"' }) do
            local out, err, status = run("600 800 160", input)
            assert.equals(1, status, input)
            assert.equals("", out, input)
            assert.truthy(err:find("input is not a JSON array of row lists", 1, true), input .. ": " .. err)
        end
    end)

    it("refuses with exit 2 and the usage for a missing or non-integer size", function()
        for _, args in ipairs({ "", "600 800", "600 800 x", "600.5 800 160", "-600 800 160" }) do
            local out, err, status = run(args, "[]")
            assert.equals(2, status, args)
            assert.equals("", out, args)
            assert.truthy(err:find("usage: bin/layout-fit <width> <height> <dpi> [settings file]", 1, true),
                args .. ": " .. err)
        end
    end)

    it("refuses with exit 2 when there is no luajit at KOPANDA_EMULATOR", function()
        local out, err, status = run("600 800 160", "[]", "KOPANDA_EMULATOR=/nonexistent")
        assert.equals(2, status)
        assert.equals("", out)
        assert.truthy(err:find("/nonexistent", 1, true), err)
    end)

    it("leaves no scratch directory behind, on success or failure", function()
        fit("600 800 160", { default })
        run("600 800 160", "not json")
        local left = {}
        for entry in require("libs/libkoreader-lfs").dir(scratch .. "/tmp") do
            if entry ~= "." and entry ~= ".." then
                left[#left + 1] = entry
            end
        end
        assert.same({}, left)
    end)
end)
