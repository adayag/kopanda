-- The home's second page on the emulator: the populated fixture in Diner by day, on the Colorsoft and on the
-- Paperwhite, after the home-page scenario sends a mid-screen west swipe. The capture is taken on the scenario's
-- signal, past the turn's repaint, so it shows page 2 with every row placed and the palette's paper in the left
-- margin at mid-height. With KOPANDA_CAPTURE_DIR set, the PNGs are left there for the owner to look at.
describe("turning the home to its second page", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local compare = require("emulator.compare")
    local Looks = require("looks")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-home-page.lua"
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

    -- The owner's directory, made if missing and cleared of this profile's last run: the driver writes the
    -- scratch profile with mkdir and would otherwise read a stale PNG.
    local function out_dir(profile_name)
        local dir = os.getenv("KOPANDA_CAPTURE_DIR")
        if not dir or dir == "" then
            return nil
        end
        require("util").makePath(dir)
        os.execute(string.format("rm -rf %q %q %q %q", dir .. "/profile-" .. profile_name,
            dir .. "/" .. profile_name .. ".png", dir .. "/" .. profile_name .. ".png.json",
            dir .. "/" .. profile_name .. ".log"))
        return dir
    end

    local runs = {
        { profile = "colorsoft", variant = "day" },
        { profile = "paperwhite", variant = "grey" },
    }

    for _, run in ipairs(runs) do
        it("shows page 2 in Diner " .. run.variant .. " on the " .. run.profile .. " after a west swipe", function()
            local result = driver.capture{
                profile = run.profile,
                plugin_dir = plugin,
                out_dir = out_dir(run.profile),
                patches = { fixture, scenario },
                shot_screen = "scenario",
                env = { TZ = "America/Chicago", KOPANDA_HOME_FIXTURE = "populated", KOPANDA_HOME_LOOK = "" },
            }
            local where = "\npng " .. result.png .. "\nlog " .. result.log
            local s = result.sidecar
            assert.is_nil(s.error, tostring(s.error) .. where)
            assert.equals("scenario", s.screen, where)
            assert.equals(2, s.page, where)
            local profile = driver.profiles[run.profile]
            assert.equals(profile.width, result.width, where)
            assert.equals(profile.height, result.height, where)
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"), where)
            local dropped = log:match("[^\n]*doesn't fit the screen[^\n]*")
            assert.is_nil(dropped, tostring(dropped) .. where)
            local paper = Looks.get("diner").palettes[run.variant].paper
            local want = { tonumber(paper:sub(2, 3), 16), tonumber(paper:sub(4, 5), 16), tonumber(paper:sub(6, 7), 16) }
            local got = compare.pixel(result.png, 2, math.floor(result.height / 2))
            for c = 1, 3 do
                assert.truthy(math.abs(got[c] - want[c]) <= PAPER_TOLERANCE,
                    string.format("paper %02x%02x%02x, want %s%s", got[1], got[2], got[3], paper, where))
            end
        end)
    end
end)
