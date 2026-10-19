-- plate.lua: a plate under a home row, its ground the wallpaper lightened toward paper by the
-- variant's amount (or paper when there is no wallpaper), rounded inside its keyline, the keyline
-- drawn solid after it; at night under KOReader's software inversion, the same lighten as the
-- panel sees it. Painted on real buffers and read back.
describe("plate", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Plate = require("plate")
    local frosted = require("looks/frosted")
    local diner = require("looks/diner")

    local BASE = { 32, 64, 128 }
    local INK = { 0x1b, 0x1a, 0x1f }
    local PAPER = { 0xfb, 0xfa, 0xf6 }

    local function rgb32(c)
        return Blitbuffer.ColorRGB32(c[1], c[2], c[3], 0xFF)
    end

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    local function near(want, got, tolerance)
        for i = 1, 3 do
            if math.abs(want[i] - got[i]) > tolerance then
                return false
            end
        end
        return true
    end

    -- c blended toward white at opacity by, as lightenRect blends (base/ffi/blitbuffer.lua:2273-2283).
    local function lightened(c, by)
        return { c[1] + (255 - c[1]) * by, c[2] + (255 - c[2]) * by, c[3] + (255 - c[3]) * by }
    end

    local bb
    before_each(function()
        bb = Blitbuffer.new(80, 60, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, 80, 60, rgb32(BASE))
    end)

    after_each(function()
        bb:free()
    end)

    describe("paint", function()
        it("lightens the ground under the plate by the amount, then draws the keyline solid", function()
            Plate.paint(bb, 10, 10, 50, 30, { lighten = 0.82, keyline = 2, keyline_color = rgb32(INK), radius = 0 })
            local inside = pixel(bb, 35, 25)
            assert.is_true(near(lightened(BASE, 0.82), inside, 2), table.concat(inside, ","))
            assert.same(INK, pixel(bb, 10, 25))
            assert.same(INK, pixel(bb, 11, 25))
            assert.same(INK, pixel(bb, 35, 39))
            assert.is_true(near(lightened(BASE, 0.82), pixel(bb, 12, 25), 2))
            assert.same(BASE, pixel(bb, 9, 25))
            assert.same(BASE, pixel(bb, 35, 41))
        end)

        it("leaves the corners outside a rounded keyline as they were", function()
            Plate.paint(bb, 10, 10, 50, 30, { lighten = 0.82, keyline = 2, keyline_color = rgb32(INK), radius = 10 })
            assert.same(BASE, pixel(bb, 10, 10))
            assert.same(BASE, pixel(bb, 59, 39))
            assert.same(BASE, pixel(bb, 11, 11))
            assert.is_true(near(lightened(BASE, 0.82), pixel(bb, 35, 25), 2))
            assert.is_true(near(lightened(BASE, 0.82), pixel(bb, 15, 15), 2))
        end)

        -- The keyline's arc is drawn after the ground, so a ground lightened out to the plate's own
        -- edge would show past the arc's outer side; lightened inside the keyline, it can't.
        it("lightens nothing outside a rounded keyline's outer edge", function()
            local DARK = { 16, 16, 24 }
            local function ground()
                local g = Blitbuffer.new(80, 60, Blitbuffer.TYPE_BBRGB32)
                g:paintRectRGB32(0, 0, 80, 60, rgb32(DARK))
                return g
            end
            local x, y, w, h, r = 10, 10, 50, 30, 12
            local keyline_only, plate = ground(), ground()
            Plate.paint(keyline_only, x, y, w, h, { keyline = 2, keyline_color = rgb32(INK), radius = r })
            Plate.paint(plate, x, y, w, h, { lighten = 0.82, keyline = 2, keyline_color = rgb32(INK), radius = r })
            -- Each corner's r by r box, from its outer corner: the dark pixels the keyline alone
            -- leaves outside its arc, reached from that corner without crossing the keyline.
            local corners = {
                { x, y, 1, 1 }, { x + w - 1, y, -1, 1 }, { x, y + h - 1, 1, -1 }, { x + w - 1, y + h - 1, -1, -1 },
            }
            local checked = 0
            for _, corner in ipairs(corners) do
                local cx, cy, sx, sy = corner[1], corner[2], corner[3], corner[4]
                local seen, queue = {}, { { 0, 0 } }
                while #queue > 0 do
                    local at = table.remove(queue)
                    local i, j = at[1], at[2]
                    local px, py = cx + sx * i, cy + sy * j
                    local id = i * r + j
                    if i >= 0 and j >= 0 and i < r and j < r and not seen[id]
                            and near(DARK, pixel(keyline_only, px, py), 0) then
                        seen[id] = true
                        checked = checked + 1
                        local got = pixel(plate, px, py)
                        assert.is_true(near(DARK, got, 0), px .. "," .. py .. ": " .. table.concat(got, ","))
                        queue[#queue + 1] = { i + 1, j }
                        queue[#queue + 1] = { i - 1, j }
                        queue[#queue + 1] = { i, j + 1 }
                        queue[#queue + 1] = { i, j - 1 }
                    end
                end
            end
            assert.truthy(checked > 4 * 8, checked)
            keyline_only:free()
            plate:free()
        end)

        it("rounds a pill to half its height", function()
            Plate.paint(bb, 10, 10, 50, 20, { lighten = 0.82, keyline = 2, keyline_color = rgb32(INK), radius = 999 })
            assert.same(BASE, pixel(bb, 11, 11))
            assert.same(BASE, pixel(bb, 58, 28))
            assert.is_true(near(lightened(BASE, 0.82), pixel(bb, 35, 20), 2))
            assert.same(INK, pixel(bb, 35, 10))
        end)

        it("fills paper with no wallpaper to lighten", function()
            Plate.paint(bb, 10, 10, 50, 30, { fill_color = rgb32(PAPER), keyline = 2, keyline_color = rgb32(INK),
                radius = 0 })
            assert.same(PAPER, pixel(bb, 35, 25))
            assert.same(INK, pixel(bb, 10, 25))
            assert.same(BASE, pixel(bb, 9, 25))
        end)

        -- KOReader's night mode on a panel that can't invert stores every write inverted
        -- (base/ffi/framebuffer.lua:476-488): the panel shows the stored pixels, so lightening the
        -- painted (inverted) colours toward white is the stored ones darkened toward black.
        it("at night under the screen's inversion lightens what is painted and keeps the flag", function()
            bb:setInverse(1)
            local night_ink = { 0xf3, 0xf1, 0xec }
            local painted_ink = { 255 - night_ink[1], 255 - night_ink[2], 255 - night_ink[3] }
            Plate.paint(bb, 10, 10, 50, 30, { lighten = 0.84, keyline = 2, keyline_color = rgb32(painted_ink),
                radius = 0 })
            assert.equals(1, bb:getInverse())
            bb:setInverse(0)
            local stored = pixel(bb, 35, 25)
            local want = { BASE[1] * 0.16, BASE[2] * 0.16, BASE[3] * 0.16 }
            assert.is_true(near(want, stored, 2), table.concat(stored, ","))
            assert.same(night_ink, pixel(bb, 10, 25))
            assert.same(BASE, pixel(bb, 9, 25))
        end)
    end)

    describe("spec", function()
        local function color(hex)
            return function(role)
                return role and hex[role] and rgb32(hex[role]) or nil
            end
        end
        local roles = color({ paper = PAPER, ink = INK })
        local function scale(px)
            return 2 * px
        end

        it("lightens by the variant's amount over a wallpaper", function()
            for variant, by in pairs({ day = 0.82, night = 0.84, grey = 0.85 }) do
                local spec = Plate.spec(frosted, variant, true, roles, scale)
                assert.equals(by, spec.lighten, variant)
                assert.is_nil(spec.fill_color, variant)
                assert.same({ 4, 24 }, { spec.keyline, spec.radius }, variant)
                assert.same(INK, { spec.keyline_color:getR(), spec.keyline_color:getG(), spec.keyline_color:getB() })
            end
        end)

        it("fills paper and lightens nothing with no wallpaper", function()
            local spec = Plate.spec(frosted, "day", false, roles, scale)
            assert.is_nil(spec.lighten)
            assert.same(PAPER, { spec.fill_color:getR(), spec.fill_color:getG(), spec.fill_color:getB() })
        end)

        it("is nil for a look without plates", function()
            assert.is_nil(Plate.spec(diner, "day", true, roles, scale))
        end)
    end)
end)
