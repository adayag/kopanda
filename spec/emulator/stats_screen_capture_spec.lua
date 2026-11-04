-- The Stats window on the emulator, opened through the plugin from the populated home at 2026-10-13 08:42 in Chicago:
-- page 1 on the Colorsoft and the Paperwhite at Medium, at the sizes that add pages, and the month bars on page 2, each
-- shot on the scenario's signal. The look is passed empty so the caller's KOPANDA_HOME_LOOK cannot leak in.
describe("the Stats window", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenarios_dir = root .. "/spec/emulator/scenarios/"

    local function read(path)
        local f = assert(io.open(path, "r"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function count(text, needle)
        local n = 0
        for _ in text:gmatch(needle:gsub("%p", "%%%0")) do
            n = n + 1
        end
        return n
    end

    -- The owner's directory for name under KOPANDA_CAPTURE_DIR, made fresh, or nil to let the driver pick one.
    local function out_dir(name)
        local dir = os.getenv("KOPANDA_CAPTURE_DIR")
        if not dir or dir == "" then
            return nil
        end
        dir = dir .. "/" .. name
        os.execute(string.format("rm -rf %q", dir))
        require("util").makePath(dir)
        return dir
    end

    -- A settings file holding text_size, removed after the test.
    local function settings_at(text_size)
        local path = os.tmpname()
        local f = assert(io.open(path, "w"))
        f:write(string.format('return { schema_version = 1, text_size = %q }\n', text_size))
        f:close()
        finally(function()
            os.remove(path)
        end)
        return path
    end

    -- A capture on profile, opts.turns west swipes in, with the checks every capture shares; returns the signal.
    local function capture(name, profile, opts)
        opts = opts or {}
        local result = driver.capture{
            profile = profile,
            plugin_dir = plugin,
            patches = {
                scenarios_dir .. "2-scenario-home-fixture.lua",
                scenarios_dir .. "2-scenario-stats-screen.lua",
            },
            out_dir = out_dir(name),
            shot_screen = "scenario",
            settings_file = opts.text_size and settings_at(opts.text_size) or nil,
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "populated",
                KOPANDA_HOME_LOOK = "",
                KOPANDA_STATS_TURNS = tostring(opts.turns or 0),
                KOPANDA_STATS_YEAR = opts.year and "1" or "",
            },
        }
        local where = "\npng " .. result.png .. "\nlog " .. result.log
        assert.is_nil(result.sidecar.error, tostring(result.sidecar.error) .. where)
        assert.equals("scenario", result.sidecar.screen, where)
        assert.equals(driver.profiles[profile].width, result.width, where)
        assert.equals(driver.profiles[profile].height, result.height, where)
        local log = read(result.log)
        assert.equals(1, count(log, "KOPANDA_SHOT: saved"), where)
        assert.equals(0, count(log, "settle cap"), where)
        assert.equals(0, count(log, "failed to build"), where)
        assert.equals(0, count(log, "failed to measure"), where)
        return result.sidecar, where
    end

    it("fits two pages on the Colorsoft", function()
        local signal, where = capture("colorsoft", "colorsoft")
        assert.equals(1, signal.page, where)
        assert.equals(2, signal.pages, where)
    end)

    it("fits two pages on the Paperwhite", function()
        local signal, where = capture("paperwhite", "paperwhite")
        assert.equals(2, signal.pages, where)
    end)

    it("runs to more pages at Extra large on the Colorsoft", function()
        local signal, where = capture("colorsoft-extra-large", "colorsoft", { text_size = "extra_large" })
        assert.truthy(signal.pages > 2, where)
    end)

    it("renders at Large on the Paperwhite", function()
        local signal, where = capture("paperwhite-large", "paperwhite", { text_size = "large" })
        assert.truthy(signal.pages > 1, where)
    end)

    it("turns to the month bars by a west swipe over a year of reading", function()
        local signal, where = capture("colorsoft-page2", "colorsoft", { turns = 1, year = true })
        assert.equals(2, signal.page, where)
    end)
end)
