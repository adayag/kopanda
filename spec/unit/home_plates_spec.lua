-- The home in a look with plates at the Colorsoft's size, its real widgets in the default layout: the wallpaper
-- (spec/fixtures/wallpaper.png) in the margins and gutters, each plate the wallpaper lightened toward paper under a
-- solid ink keyline, the launcher's tiles plates too, the nav bar opaque paper; plain paper with no wallpaper; the
-- panel showing the picture at night; the wallpaper freed when the home closes. Painted into a buffer and read back.
describe("the home on plates", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local fixture = harness.root .. "/spec/fixtures/wallpaper.png"
    local Home, Settings, Wallpaper
    local had_color, color_rendering, night_mode

    local PAPER = { 0xfb, 0xfa, 0xf6 }
    local INK = { 0x1b, 0x1a, 0x1f }

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    local function near(want, got, tolerance)
        for i = 1, 3 do
            if math.abs(want[i] - got[i]) > (tolerance or 2) then
                return false
            end
        end
        return true
    end

    local function show(c)
        return table.concat(c, ",")
    end

    local function lightened(c, by)
        return { c[1] + (255 - c[1]) * by, c[2] + (255 - c[2]) * by, c[3] + (255 - c[3]) * by }
    end

    local function slot_of(home, id)
        for _, slot in ipairs(home.slots) do
            if slot.widget == id then
                return slot
            end
        end
    end

    before_each(function()
        harness.load()
        Home = require("home")
        Settings = require("settings")
        Wallpaper = require("wallpaper")
        had_color = G_reader_settings:has("color_rendering")
        color_rendering = G_reader_settings:readSetting("color_rendering")
        night_mode = rawget(Screen, "night_mode")
        G_reader_settings:saveSetting("color_rendering", true)
        Screen.night_mode = false
        Settings.set("look", "frosted")
    end)

    after_each(function()
        Screen.night_mode = night_mode
        if had_color then
            G_reader_settings:saveSetting("color_rendering", color_rendering)
        else
            G_reader_settings:delSetting("color_rendering")
        end
        Wallpaper._reset()
        Settings._reset()
        os.remove(harness.settings_file)
        os.remove(harness.settings_file .. ".old")
        harness.teardown()
    end)

    -- Builds a home at the Colorsoft's size and paints it into a buffer (its inverse flag set at
    -- night, as night mode leaves the screen's), then calls fn(home, bb, wallpaper image or nil).
    local function painted(night, fn)
        harness.at_colorsoft(function()
            Screen.night_mode = night
            local home = Home:new{}
            local bb = Blitbuffer.new(1264, 1680, Blitbuffer.TYPE_BBRGB32)
            if night then
                bb:setInverse(1)
            end
            home:paintTo(bb, 0, 0)
            bb:setInverse(0)
            local key = home[1].wallpaper_key
            local ok, err = pcall(fn, home, bb, key and Wallpaper.current(key))
            home:free()
            bb:free()
            if not ok then
                error(err, 0)
            end
        end)
    end

    it("draws the wallpaper in the margins and keeps the nav bar opaque paper", function()
        Settings.set("wallpaper.file", fixture)
        painted(false, function(home, bb, image)
            assert.is_not_nil(image)
            for _, y in ipairs({ 300, 840, 1200 }) do
                local got = pixel(bb, 2, y)
                assert.is_true(near(pixel(image, 2, y), got, 1), show(got))
                assert.is_false(near(PAPER, got, 8), show(got))
            end
            local nav = home.nav.dimen
            -- The last tab is unlit (the first, Home, is lit yellow).
            assert.same(PAPER, pixel(bb, nav.x + nav.w - 3, nav.y + nav.h - 3))
        end)
    end)

    it("lightens the wallpaper under each plate by 0.82 inside its solid ink keyline", function()
        Settings.set("wallpaper.file", fixture)
        painted(false, function(home, bb, image)
            local keyline = Screen:scaleBySize(2)
            for _, id in ipairs({ "featured", "quote", "stats" }) do
                local rect = slot_of(home, id).rect
                local y = rect.y + math.floor(rect.h / 2)
                assert.same(INK, pixel(bb, rect.x, y), id)
                local x = rect.x + keyline + 3
                local got = pixel(bb, x, y)
                assert.is_true(near(lightened(pixel(image, x, y), 0.82), got, 2), id .. " " .. show(got))
            end
        end)
    end)

    it("draws the quote's text solid on its plate", function()
        Settings.set("wallpaper.file", fixture)
        painted(false, function(home, bb)
            local rect = slot_of(home, "quote").rect
            local inset = Screen:scaleBySize(2) + Screen:scaleBySize(18)
            local darkest = { 255, 255, 255 }
            for y = rect.y + inset, rect.y + rect.h - inset, 2 do
                for x = rect.x + inset, rect.x + rect.w - inset, 2 do
                    local p = pixel(bb, x, y)
                    if p[1] + p[2] + p[3] < darkest[1] + darkest[2] + darkest[3] then
                        darkest = p
                    end
                end
            end
            assert.is_true(near(INK, darkest, 3), show(darkest))
        end)
    end)

    -- The quote's text box and the featured column's (the first run's title and body) are
    -- TextBoxWidgets, which fill their box (frontend/ui/widget/textboxwidget.lua:855-865): on a
    -- plate they print through a mask instead, so no paper box shows inside it.
    it("prints the quote and the featured text with no paper box of their own", function()
        Settings.set("wallpaper.file", fixture)
        -- The first run's column: its title and body are text boxes, and it has no progress
        -- track, which is paper by design. The plugin's modules load afresh for the next case.
        require("featured_book").current = function()
            return nil
        end
        painted(false, function(home, bb)
            for _, id in ipairs({ "quote", "featured" }) do
                local slot = slot_of(home, id)
                local rect = slot.rect
                local inset = Screen:scaleBySize(2) + Screen:scaleBySize(14)
                -- The featured text column, right of its cover box.
                local left = rect.x + inset
                if id == "featured" then
                    left = left + slot.built.box_w + Screen:scaleBySize(20)
                end
                local papers, total = 0, 0
                for y = rect.y + inset, rect.y + rect.h - inset, 3 do
                    for x = left, rect.x + rect.w - inset, 3 do
                        total = total + 1
                        if near(PAPER, pixel(bb, x, y), 0) then
                            papers = papers + 1
                        end
                    end
                end
                assert.truthy(papers < total / 100, id .. ": " .. papers .. " of " .. total .. " are paper")
            end
        end)
    end)

    it("makes each launcher tile a plate", function()
        Settings.set("wallpaper.file", fixture)
        painted(false, function(home, bb, image)
            local slot = slot_of(home, "launcher")
            local grid = slot.built
            local origin = grid.painted_at
            local tile = grid.rects[1]
            local keyline = Screen:scaleBySize(2)
            local x, y = origin.x + tile.x, origin.y + tile.y + math.floor(tile.h / 2)
            assert.same(INK, pixel(bb, x, y))
            local got = pixel(bb, x + keyline + 3, y)
            assert.is_true(near(lightened(pixel(image, x + keyline + 3, y), 0.82), got, 2), show(got))
        end)
    end)

    it("draws paper margins and paper plates with no wallpaper", function()
        painted(false, function(home, bb, image)
            assert.is_nil(image)
            assert.same(PAPER, pixel(bb, 2, 840))
            local rect = slot_of(home, "featured").rect
            local y = rect.y + math.floor(rect.h / 2)
            assert.same(INK, pixel(bb, rect.x, y))
            assert.same(PAPER, pixel(bb, rect.x + Screen:scaleBySize(2) + 3, y))
        end)
    end)

    it("shows the picture, not its negative, in the margins at night", function()
        Settings.set("wallpaper.file", fixture)
        painted(true, function(_, bb, image)
            local inverted = pixel(image, 2, 840)
            local want = { 255 - inverted[1], 255 - inverted[2], 255 - inverted[3] }
            local got = pixel(bb, 2, 840)
            assert.is_true(near(want, got, 1), show(got))
        end)
    end)

    -- wallpaper.lua holds one image: a get for another size or holder frees the one this home
    -- built with. The home then paints paper, never the freed buffer.
    it("paints paper, not a freed buffer, once another get has replaced its wallpaper", function()
        Settings.set("wallpaper.file", fixture)
        local paint = Wallpaper.paint
        local painted_from = {}
        Wallpaper.paint = function(bb, x, y, image)
            painted_from[#painted_from + 1] = image:getAllocated()
            if image:getAllocated() ~= 1 then
                error("painted a freed wallpaper", 0)
            end
            return paint(bb, x, y, image)
        end
        finally(function()
            Wallpaper.paint = paint
        end)
        harness.at_colorsoft(function()
            local home = Home:new{}
            Wallpaper.get(require("looks").get("frosted"), "day", 600, 800, "another home")
            local bb = Blitbuffer.new(1264, 1680, Blitbuffer.TYPE_BBRGB32)
            local ok, err = pcall(function()
                home:paintTo(bb, 0, 0)
                assert.same(PAPER, pixel(bb, 2, 840))
                for _, allocated in ipairs(painted_from) do
                    assert.equals(1, allocated)
                end
            end)
            home:free()
            bb:free()
            if not ok then
                error(err, 0)
            end
        end)
    end)

    it("frees the wallpaper when the home closes", function()
        Settings.set("wallpaper.file", fixture)
        painted(false, function(home, _, image)
            assert.equals(1, image:getAllocated())
            home:onCloseWidget()
            assert.equals(0, image:getAllocated())
        end)
    end)
end)
