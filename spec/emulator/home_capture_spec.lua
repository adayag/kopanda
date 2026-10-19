-- The home on the emulator, every look's smoke gate: for each id Looks.ids() lists, the populated
-- fixture (2026-10-13 08:42 in Chicago, a known weather cache, reading statistics and a featured
-- book with its real cover) on the Colorsoft by day and with night mode on from the start, and on
-- the Paperwhite by day. Each is taken on the plugin's own settled signal, within the paint
-- budget, with no row dropped, its paper, read in the left margin at mid-height, the paper of the
-- palette it is drawn in (Looks.variant): the PNG is what the panel shows
-- (base/ffi/framebuffer.lua:566-581), so a night capture's paper is the look's designed night
-- paper. Beside them, in Diner on the Colorsoft, the fixture's two other states: none of it (the
-- featured slot in its first-run state, the launcher's last entry a plugin that isn't there) and
-- the featured book with CoverBrowser disabled, its typographic cover; and Frosted with a wallpaper,
-- by day, at night and on the Paperwhite. The look is always passed
-- (empty for Diner's two) so a KOPANDA_HOME_LOOK in the caller's environment cannot leak in.
describe("capturing the KoPanda home on the emulator", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local compare = require("emulator.compare")
    local paint_budget = require("emulator.paint_budget")
    local Looks = require("looks")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    -- The paper is a flat fill, so close to exact: KOReader's own inversion of Diner's day paper,
    -- #f5f1e6, reads #0a0e19, within compare's default tolerance of its night paper, #1e1c1a, on
    -- two channels of three.
    local PAPER_TOLERANCE = 4

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

    local function has(list, value)
        for _, v in ipairs(list) do
            if v == value then
                return true
            end
        end
        return false
    end

    local function capture(profile, fixture_name, look, night_mode, settings_file)
        return driver.capture{
            profile = profile,
            plugin_dir = plugin,
            night_mode = night_mode,
            settings_file = settings_file,
            patches = { fixture },
            env = { TZ = "America/Chicago", KOPANDA_HOME_FIXTURE = fixture_name, KOPANDA_HOME_LOOK = look },
        }
    end

    -- The checks every home capture keeps: its size, the settled home signal from a run with the
    -- plugin loaded, shot once and before the settle cap, within the paint budget, and every row
    -- of the layout placed: the row engine logs each row it drops (kopanda.koplugin/layout.lua,
    -- Layout.place).
    local function assert_settled(label, profile_name, result)
        local profile = driver.profiles[profile_name]
        assert.equals(profile.width, result.width)
        assert.equals(profile.height, result.height)
        assert.equals("home", result.sidecar.screen)
        assert.truthy(has(result.sidecar.plugins, "kopanda"))
        paint_budget.check(label, result.sidecar)
        local log = read(result.log)
        assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
        assert.equals(0, count(log, "settle cap"))
        local dropped = log:match("[^\n]*doesn't fit the screen[^\n]*")
        assert.is_nil(dropped, dropped)
    end

    local function assert_paper(result, hex)
        local want = {
            tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16),
        }
        local got = compare.pixel(result.png, 2, math.floor(result.height / 2))
        for c = 1, 3 do
            assert.truthy(math.abs(got[c] - want[c]) <= PAPER_TOLERANCE,
                string.format("paper %02x%02x%02x, want %s", got[1], got[2], got[3], hex))
        end
    end

    local runs = {
        { profile = "colorsoft", variant = "day" },
        { profile = "colorsoft", variant = "night" },
        { profile = "paperwhite", variant = "grey" },
    }

    for _, id in ipairs(Looks.ids()) do
        for _, run in ipairs(runs) do
            local label = string.format("home %s %s on %s", id, run.variant, run.profile)
            it("renders the " .. label .. " on the plugin's own settled signal, within the paint budget", function()
                local result = capture(run.profile, "populated", id, run.variant == "night")
                assert_settled(label, run.profile, result)
                assert_paper(result, Looks.get(id).palettes[run.variant].paper)
            end)
        end
    end

    -- Frosted with the fixture wallpaper (spec/fixtures/wallpaper.png, written by
    -- spec/fixtures/wallpaper_png.lua) in a settings file the driver copies in: the wallpaper
    -- shows in the left margin, where the other captures read paper, and the nav bar stays opaque
    -- paper, read at its right end, under the last tab, which is unlit.
    local function wallpaper_settings()
        local dir = os.getenv("KO_HOME") .. "/home-capture-spec"
        require("util").makePath(dir)
        local path = dir .. "/frosted-wallpaper.lua"
        local f = assert(io.open(path, "w"))
        f:write(string.format('return { ["schema_version"] = 1, ["wallpaper.file"] = %q }\n',
            root .. "/spec/fixtures/wallpaper.png"))
        f:close()
        return path
    end

    for _, run in ipairs(runs) do
        local label = string.format("home frosted with a wallpaper %s on %s", run.variant, run.profile)
        it("renders the " .. label .. " within the paint budget, the wallpaper in its margins", function()
            local result = capture(run.profile, "populated", "frosted", run.variant == "night", wallpaper_settings())
            assert_settled(label, run.profile, result)
            local paper = Looks.get("frosted").palettes[run.variant].paper
            local want = { tonumber(paper:sub(2, 3), 16), tonumber(paper:sub(4, 5), 16), tonumber(paper:sub(6, 7), 16) }
            local margin = compare.pixel(result.png, 2, math.floor(result.height / 2))
            local off = 0
            for c = 1, 3 do
                off = math.max(off, math.abs(margin[c] - want[c]))
            end
            assert.truthy(off > 16, string.format("the margin %02x%02x%02x is the paper", margin[1], margin[2],
                margin[3]))
            local nav = compare.pixel(result.png, result.width - 3, result.height - 3)
            for c = 1, 3 do
                assert.truthy(math.abs(nav[c] - want[c]) <= PAPER_TOLERANCE,
                    string.format("nav %02x%02x%02x, want %s", nav[1], nav[2], nav[3], paper))
            end
        end)
    end

    for _, fixture_name in ipairs({ "empty", "typecover" }) do
        it("renders the " .. fixture_name .. " home in Diner on colorsoft, within the paint budget", function()
            local result = capture("colorsoft", fixture_name, "")
            assert_settled("home " .. fixture_name .. " on colorsoft", "colorsoft", result)
            -- The typographic cover is CoverBrowser's absence, not a missing cache entry.
            assert.equals(fixture_name ~= "typecover", has(result.sidecar.plugins, "coverbrowser"))
        end)
    end
end)
