-- The book status page on the emulator, opened from a library hold: over the capture library (capture_library.lua)
-- at its root, the reading book held and the book sheet's Book details tapped, with the book's own Statistics rows and
-- a description of three pages (2-scenario-library_status.lua), at 2026-10-13 08:42 in Chicago. Page 1 in every look
-- Looks.ids() lists, by day and by night, on the Colorsoft, and once on the Paperwhite, each within the paint budget;
-- page 2 after a west swipe; and back to the library at its folder. A night capture shows the night
-- palette's paper as written, KOReader inverting only on the panel. No golden: the owner judges the
-- captures by eye, and a capture's left margin at mid-height samples the palette's paper. With KOPANDA_CAPTURE_DIR
-- set, the PNGs are left there for the owner.
describe("the book status page", function()
    require("commonrequire")
    local capture_library = require("emulator.capture_library")
    local compare = require("emulator.compare")
    local driver = require("emulator.driver")
    local paint_budget = require("emulator.paint_budget")
    local Looks = require("looks")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenarios_dir = root .. "/spec/emulator/scenarios/"
    local patches = {
        scenarios_dir .. "2-scenario-home-fixture.lua",
        scenarios_dir .. "2-scenario-library.lua",
        scenarios_dir .. "2-scenario-library_hold.lua",
        scenarios_dir .. "2-scenario-library_status.lua",
    }
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

    -- A capture of step in look, by night or by day, on profile.
    local function capture(step, look, profile, night)
        local library = capture_library.make()
        local result = driver.capture{
            profile = profile,
            plugin_dir = plugin,
            library_dir = library,
            patches = patches,
            night_mode = night,
            out_dir = out_dir(string.format("%s-%s-%s-%s", step, look, night and "night" or "day", profile)),
            shot_screen = step == "page1" and "book_status" or "scenario",
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "empty",
                KOPANDA_HOME_LOOK = look,
                KOPANDA_LIBRARY_DIR = library,
                KOPANDA_LIBRARY_STEP = "root",
                KOPANDA_LIBRARY_HOLD = "book",
                KOPANDA_BOOK_STATUS_STEP = step,
            },
        }
        local where = "\npng " .. result.png .. "\nlog " .. result.log
        assert.is_nil(result.sidecar.error, tostring(result.sidecar.error) .. where)
        local log = read(result.log)
        assert.equals(1, count(log, "KOPANDA_SHOT: saved"), where)
        assert.equals(0, count(log, "settle cap"), where)
        assert.equals(0, count(log, "could not show the book_status"), where)
        assert.equals(0, count(log, "the book status could not read"), where)
        assert.equals(0, count(log, "doesn't fit the page"), where)
        return result, where
    end

    -- The palette's paper at the capture's left margin, at mid-height.
    local function assert_paper(result, look, variant, where)
        local paper = Looks.get(look).palettes[variant].paper
        local want = { tonumber(paper:sub(2, 3), 16), tonumber(paper:sub(4, 5), 16), tonumber(paper:sub(6, 7), 16) }
        local got = compare.pixel(result.png, 2, math.floor(result.height / 2))
        for c = 1, 3 do
            assert.truthy(math.abs(got[c] - want[c]) <= PAPER_TOLERANCE,
                string.format("paper %02x%02x%02x, want %s%s", got[1], got[2], got[3], paper, where))
        end
    end

    -- The chrome's settled signal carries paint_ms alone, as the library's: held to the paint budget's ms unless the
    -- host is loaded, which paint_budget.lua's note says instead.
    local function within_budget(label, sidecar)
        assert.is_number(sidecar.paint_ms, label .. ": no paint_ms")
        assert.truthy(sidecar.paint_ms > 0, label)
        print(string.format("%s: paint_ms=%s", label, sidecar.paint_ms))
        local host = paint_budget.host()
        local judged, line = paint_budget.judges_wall(host.load, host.cores)
        if judged then
            assert.truthy(sidecar.paint_ms <= paint_budget.MS,
                string.format("%s: paint_ms %s over the %d ms budget", label, sidecar.paint_ms, paint_budget.MS))
        else
            print("[  NOTE    ] " .. label .. ": " .. line)
        end
    end

    for _, look in ipairs(Looks.ids()) do
        for _, night in ipairs({ false, true }) do
            local variant = night and "night" or "day"
            it("renders page 1 in " .. look .. " by " .. variant .. " on the Colorsoft, within the paint budget",
                function()
                    local result, where = capture("page1", look, "colorsoft", night)
                    assert.equals("book_status", result.sidecar.screen, where)
                    assert.equals(driver.profiles.colorsoft.width, result.width, where)
                    assert.equals(driver.profiles.colorsoft.height, result.height, where)
                    assert_paper(result, look, variant, where)
                    within_budget("book-status " .. look .. " " .. variant .. " paint on colorsoft", result.sidecar)
                end)
        end
    end

    it("renders page 1 on the Paperwhite 7, within the paint budget", function()
        local result, where = capture("page1", "diner", "paperwhite7", false)
        assert.equals("book_status", result.sidecar.screen, where)
        assert.equals(driver.profiles.paperwhite7.width, result.width, where)
        assert.equals(driver.profiles.paperwhite7.height, result.height, where)
        assert_paper(result, "diner", "grey", where)
        within_budget("book-status paint on paperwhite7", result.sidecar)
    end)

    it("turns its long description to page 2 of three or more on a west swipe", function()
        local result, where = capture("page2", "editorial", "colorsoft", false)
        local s = result.sidecar
        assert.equals("scenario", s.screen, where)
        assert.equals(2, s.page, where)
        assert.is_true(s.pages >= 3, tostring(s.pages) .. where)
        assert_paper(result, "editorial", "day", where)
    end)

    it("goes back to the library at the folder it was opened from", function()
        local result, where = capture("back", "diner", "colorsoft", false)
        local s = result.sidecar
        assert.equals("scenario", s.screen, where)
        assert.is_true(s.same_dir, where)
    end)
end)
