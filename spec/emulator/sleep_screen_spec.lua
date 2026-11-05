-- The sleep screen on the emulator, through a simulated sleep: the card over the cover from a book and from the home,
-- night's card in the look's night paper, a landscape book's screen in portrait, no card with sleep.on off, and the
-- tiles on the card over the populated home's reading history. The capture is what the panel shows
-- (base/ffi/framebuffer.lua:566-581).
describe("the sleep screen on the emulator", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local compare = require("emulator.compare")
    local driver = require("emulator.driver")
    local Looks = require("looks")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-sleep-screen.lua"
    local home_fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local PAPER_TOLERANCE = 16

    -- Opening a book writes its .sdr sidecar beside it (document_metadata_folder defaults to
    -- "doc", frontend/docsettings.lua:102), so the book is copied out of spec/fixtures/library/.
    local function library_with_one_book()
        local dir = os.getenv("KO_HOME") .. "/sleep-screen-library"
        if lfs.attributes(dir, "mode") then
            assert.equals(0, os.execute("rm -rf '" .. dir .. "'"))
        end
        assert(lfs.mkdir(dir))
        assert.equals(0, os.execute("cp '" .. root .. "/spec/fixtures/library/frankenstein.epub' '" .. dir .. "/'"))
        return dir
    end

    -- A settings file for the plugin holding values, written under KO_HOME.
    local function settings_file(name, values)
        local path = os.getenv("KO_HOME") .. "/sleep-screen-" .. name .. ".lua"
        local lines = { "return {", "    [\"schema_version\"] = 1," }
        for key, value in pairs(values) do
            lines[#lines + 1] = string.format("    [%q] = %s,", key, type(value) == "string"
                and string.format("%q", value) or tostring(value))
        end
        lines[#lines + 1] = "}"
        local f = assert(io.open(path, "w"))
        f:write(table.concat(lines, "\n") .. "\n")
        f:close()
        return path
    end

    local function sleep(step, opts)
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library_with_one_book(),
            patches = { scenario },
            shot_screen = "scenario",
            env = { KOPANDA_SLEEP_STEP = step },
            night_mode = opts and opts.night_mode,
            settings_file = opts and opts.settings_file,
        }
        assert.is_nil(result.sidecar.error)
        return result, result.sidecar
    end

    -- Whether got, a { r, g, b }, is within tolerance of want, a #rrggbb.
    local function near(got, want)
        local rgb = { tonumber(want:sub(2, 3), 16), tonumber(want:sub(4, 5), 16), tonumber(want:sub(6, 7), 16) }
        for c = 1, 3 do
            if math.abs(got[c] - rgb[c]) > PAPER_TOLERANCE then
                return false
            end
        end
        return true
    end

    -- The middle of the card's bottom padding.
    local function card_pixel(result, s)
        return compare.pixel(result.png, math.floor(s.width / 2), s.height - s.margin - s.outline - 3)
    end

    local function assert_card_paper(result, s, want)
        local got = card_pixel(result, s)
        assert.truthy(near(got, want), string.format("paper %02x%02x%02x, want %s", got[1], got[2], got[3], want))
    end

    -- The cover at a point above the card and KOReader's message box, which sits at half height.
    local function assert_cover(result, s, paper)
        local got = compare.pixel(result.png, math.floor(s.width / 2), math.floor(s.height / 3))
        assert.is_false(near(got, paper), string.format("%02x%02x%02x above the card is paper", got[1], got[2], got[3]))
    end

    local function diner(variant)
        return Looks.get("diner").palettes[variant].paper
    end

    it("shows the card over the cover from a book", function()
        local result, s = sleep("book")
        assert.equals("cover", s.screensaver_type)
        assert.is_true(s.widget_shown)
        assert_card_paper(result, s, diner("day"))
        assert_cover(result, s, diner("day"))
    end)

    it("shows the last book from the home", function()
        local result, s = sleep("home")
        assert_card_paper(result, s, diner("day"))
        assert_cover(result, s, diner("day"))
    end)

    it("shows the look's night paper at night", function()
        local result, s = sleep("book", { night_mode = true })
        assert_card_paper(result, s, diner("night"))
        assert_cover(result, s, diner("night"))
    end)

    it("keeps a landscape book's screen in portrait", function()
        local result, s = sleep("landscape")
        assert.is_true(s.height > s.width)
        assert.is_true(result.height > result.width)
        assert_card_paper(result, s, diner("day"))
        assert_cover(result, s, diner("day"))
    end)

    -- As the Stats window's capture seeds its reading (stats_screen_capture_spec.lua), its book open.
    local function sleep_with_history()
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            patches = { home_fixture, scenario },
            shot_screen = "scenario",
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "populated",
                KOPANDA_HOME_LOOK = "",
                KOPANDA_SLEEP_BOOK = "frankenstein.epub",
                KOPANDA_SLEEP_STEP = "book",
            },
        }
        assert.is_nil(result.sidecar.error)
        return result, result.sidecar
    end

    it("shows the tiles on the card, the cover keeping half the screen", function()
        local result, s = sleep_with_history()
        local look = Looks.get("diner")
        local palette = look.palettes.day
        assert.is_number(s.tile_y, "no tile painted")
        assert.is_true(s.tile_y > s.height / 2)
        local edge = compare.pixel(result.png, s.tile_x + 1, s.tile_y + math.floor(s.tile_h / 2))
        assert.truthy(near(edge, palette.outline), string.format("%02x%02x%02x", edge[1], edge[2], edge[3]))
        assert_card_paper(result, s, palette.paper)
        assert_cover(result, s, palette.paper)
    end)

    it("shows no card with sleep.on off", function()
        local result, s = sleep("book", { settings_file = settings_file("off", { ["sleep.on"] = false }) })
        assert.is_not.equals("cover", s.screensaver_type)
        assert.is_false(near(card_pixel(result, s), diner("day")))
    end)
end)
