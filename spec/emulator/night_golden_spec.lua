-- The night goldens (C6, C7): each look on the Colorsoft with night mode on from the start, the
-- populated fixture as home_golden_spec.lua has it. The PNG is what the panel shows
-- (base/ffi/framebuffer.lua:566-581), so its paper, read in the left margin at mid-height, is the
-- look's designed night paper.
-- On the Paperwhite the grey palette stays and KOReader inverts it: outside the featured cover
-- the capture is the inverse of the day golden, and inside it the day golden itself, since
-- ImageWidget inverts the cover again (frontend/ui/widget/imagewidget.lua:583-593). The cover
-- rectangle is reported by the cover-rect scenario patch. Nothing is committed for the Paperwhite.
describe("the night goldens", function()
    require("commonrequire")
    local ffi = require("ffi")
    local lfs = require("libs/libkoreader-lfs")
    local Png = require("ffi/png")
    local rapidjson = require("rapidjson")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local paint_budget = require("emulator.paint_budget")
    local compare = require("emulator.compare")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local fixture = root .. "/spec/emulator/scenarios/2-scenario-home-fixture.lua"
    local cover_rect = root .. "/spec/emulator/scenarios/2-scenario-cover-rect.lua"
    local goldens = root .. "/spec/goldens"
    local artifacts = root .. "/spec/.artifacts/goldens"

    -- The night palettes' paper, kopanda.koplugin/looks/diner.lua and looks/editorial.lua.
    local looks = {
        { name = "diner", look = "", paper = { 0x1e, 0x1c, 0x1a } },
        { name = "editorial", look = "editorial", paper = { 0x15, 0x16, 0x1a } },
    }

    local function night_capture(profile, look, extra)
        local opts = {
            profile = profile,
            plugin_dir = plugin,
            night_mode = true,
            patches = { fixture },
            env = {
                TZ = "America/Chicago",
                KOPANDA_HOME_FIXTURE = "populated",
                KOPANDA_HOME_LOOK = look.look,
            },
        }
        for key, value in pairs(extra or {}) do
            opts[key] = value
        end
        return driver.capture(opts)
    end

    local function pixel(path, x, y)
        local ok, image = Png.decodeFromFile(path, 3)
        assert(ok, image)
        local i = (y * image.width + x) * 3
        local rgb = { image.data[i], image.data[i + 1], image.data[i + 2] }
        ffi.C.free(image.data)
        return rgb
    end

    local function read_json(path)
        local f = assert(io.open(path, "r"))
        local text = f:read("*a")
        f:close()
        return rapidjson.decode(text)
    end

    local function copy(list)
        local out = {}
        for _, v in ipairs(list or {}) do
            out[#out + 1] = v
        end
        return out
    end

    local function artifact(name)
        if lfs.attributes(artifacts, "mode") ~= "directory" then
            assert.equals(0, os.execute("mkdir -p '" .. artifacts .. "'"))
        end
        return artifacts .. "/" .. name
    end

    for _, look in ipairs(looks) do
        local name = "home-night-" .. look.name

        it("match a fresh capture of " .. name .. " on colorsoft, its paper the night paper", function()
            local result = night_capture("colorsoft", look)
            assert.equals("home", result.sidecar.screen)
            -- The left margin at mid-height: Diner's teal header band fills the top-left corner.
            local corner = pixel(result.png, 2, math.floor(result.height / 2))
            for c = 1, 3 do
                assert.truthy(math.abs(corner[c] - look.paper[c]) <= compare.defaults.tolerance,
                    string.format("paper corner %02x%02x%02x, want %02x%02x%02x",
                        corner[1], corner[2], corner[3], look.paper[1], look.paper[2], look.paper[3]))
            end
            paint_budget.check(name .. " colorsoft", result.sidecar)
            local checked = golden.assert_golden(name, "colorsoft", result)
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_true(checked.ok)
            end
        end)

        it("invert home-" .. look.name .. " on paperwhite outside the cover and keep it inside", function()
            local result = night_capture("paperwhite", look, { patches = { fixture, cover_rect },
                shot_screen = "scenario" })
            -- Kept for the owner's look (bin/check deletes KO_HOME); never compared against.
            local kept = artifact(name .. "-paperwhite.png")
            assert.equals(0, os.execute("cp '" .. result.png .. "' '" .. kept .. "'"))
            local s = result.sidecar
            assert.is_nil(s.error)
            assert.is_number(s.cover_w)
            assert.truthy(s.cover_w > 0 and s.cover_h > 0, "empty cover rectangle")
            local day = goldens .. "/home-" .. look.name .. "-paperwhite"
            local day_masks = read_json(day .. ".json").masks
            local w, h = result.width, result.height
            local cover = { x = s.cover_x, y = s.cover_y, w = s.cover_w, h = s.cover_h }

            local outside_masks = copy(day_masks)
            outside_masks[#outside_masks + 1] = cover
            local outside = compare.compare(result.png, day .. ".png", { invert = true, masks = outside_masks,
                diff_png = artifact("home-night-" .. look.name .. "-paperwhite.outside.diff.png") })
            assert.is_nil(outside.reason)
            assert.truthy(outside.ok, string.format("outside the cover %.4f %% differ (%d of %d); diff %s",
                outside.fraction * 100, outside.differing, outside.compared, tostring(outside.diff_png)))

            local inside_masks = copy(day_masks)
            for _, m in ipairs{
                { x = 0, y = 0, w = w, h = cover.y },
                { x = 0, y = cover.y + cover.h, w = w, h = h - cover.y - cover.h },
                { x = 0, y = cover.y, w = cover.x, h = cover.h },
                { x = cover.x + cover.w, y = cover.y, w = w - cover.x - cover.w, h = cover.h },
            } do
                inside_masks[#inside_masks + 1] = m
            end
            local inside = compare.compare(result.png, day .. ".png", { masks = inside_masks,
                diff_png = artifact("home-night-" .. look.name .. "-paperwhite.inside.diff.png") })
            assert.equals(cover.w * cover.h, inside.compared)
            assert.truthy(inside.ok, string.format("inside the cover %.4f %% differ (%d of %d); diff %s",
                inside.fraction * 100, inside.differing, inside.compared, tostring(inside.diff_png)))
            print(string.format("%s paperwhite: outside %d of %d differ, inside %d of %d differ",
                name, outside.differing, outside.compared, inside.differing, inside.compared))
        end)
    end
end)
