-- paint.lua: fills and borders that keep a colour's hue on an RGB32 buffer, square or rounded,
-- and the box under a widget's content (its shadow and fill) and over it (its outline).
describe("paint", function()
    local Blitbuffer = require("ffi/blitbuffer")
    local Paint = require("paint")

    local WHITE = { 255, 255, 255 }
    local RED = { 255, 0, 0 }
    local BLUE = { 0, 0, 255 }
    local GREEN = { 0, 128, 0 }

    local function rgb32(c)
        return Blitbuffer.ColorRGB32(c[1], c[2], c[3], 0xFF)
    end

    -- A w by h RGB32 buffer filled white. The caller frees it.
    local function buffer(w, h)
        local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
        bb:fill(Blitbuffer.COLOR_WHITE)
        return bb
    end

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    local bb
    after_each(function()
        if bb then
            bb:free()
            bb = nil
        end
    end)

    describe("fill", function()
        it("keeps a colour's hue, where the plain paintRect greys it", function()
            bb = buffer(20, 20)
            Paint.fill(bb, 2, 3, 5, 4, rgb32(RED))
            assert.same(RED, pixel(bb, 2, 3))
            assert.same(RED, pixel(bb, 6, 6))
            assert.same(WHITE, pixel(bb, 7, 6))
            assert.same(WHITE, pixel(bb, 6, 7))
            assert.same(WHITE, pixel(bb, 1, 3))
            bb:paintRect(10, 10, 2, 2, rgb32(RED))
            assert.are_not.same(RED, pixel(bb, 10, 10))
        end)

        it("paints a grey as a grey", function()
            bb = buffer(10, 10)
            Paint.fill(bb, 0, 0, 4, 4, Blitbuffer.Color8(0x40))
            assert.same({ 0x40, 0x40, 0x40 }, pixel(bb, 3, 3))
            assert.same(WHITE, pixel(bb, 4, 4))
        end)

        it("rounds its corners by a radius, in colour and in grey", function()
            bb = buffer(30, 30)
            Paint.fill(bb, 0, 0, 20, 20, rgb32(BLUE), 6)
            assert.same(WHITE, pixel(bb, 0, 0))
            assert.same(BLUE, pixel(bb, 10, 0))
            assert.same(BLUE, pixel(bb, 10, 10))
            bb:fill(Blitbuffer.COLOR_WHITE)
            Paint.fill(bb, 0, 0, 20, 20, Blitbuffer.COLOR_BLACK, 6)
            assert.same(WHITE, pixel(bb, 0, 0))
            assert.same({ 0, 0, 0 }, pixel(bb, 10, 10))
        end)

        it("fills square corners at a radius of 0", function()
            bb = buffer(10, 10)
            Paint.fill(bb, 0, 0, 6, 6, rgb32(BLUE), 0)
            assert.same(BLUE, pixel(bb, 0, 0))
            assert.same(BLUE, pixel(bb, 5, 5))
        end)
    end)

    describe("border", function()
        it("paints the edges width wide and leaves the inside, keeping the hue", function()
            bb = buffer(20, 20)
            Paint.border(bb, 1, 1, 10, 8, 2, rgb32(GREEN))
            assert.same(GREEN, pixel(bb, 1, 1))
            assert.same(GREEN, pixel(bb, 2, 2))
            assert.same(GREEN, pixel(bb, 10, 8))
            assert.same(WHITE, pixel(bb, 3, 3))
            assert.same(WHITE, pixel(bb, 8, 6))
            assert.same(WHITE, pixel(bb, 11, 9))
        end)

        it("paints a grey border as a grey", function()
            bb = buffer(10, 10)
            Paint.border(bb, 0, 0, 6, 6, 1, Blitbuffer.COLOR_BLACK)
            assert.same({ 0, 0, 0 }, pixel(bb, 0, 5))
            assert.same(WHITE, pixel(bb, 2, 2))
        end)

        it("rounds its corners by a radius", function()
            bb = buffer(30, 30)
            Paint.border(bb, 0, 0, 20, 20, 2, rgb32(GREEN), 6)
            assert.same(WHITE, pixel(bb, 0, 0))
            assert.same(GREEN, pixel(bb, 10, 0))
            assert.same(WHITE, pixel(bb, 10, 10))
        end)
    end)

    describe("a box", function()
        local function box(fields)
            local b = {
                shadow_x = 3,
                shadow_y = 2,
                outline = 0,
            }
            for k, v in pairs(fields) do
                b[k] = v
            end
            return b
        end

        it("puts its shadow below and right of it, under its fill", function()
            bb = buffer(30, 30)
            Paint.backing(bb, 2, 2, 10, 10, box{
                shadow_color = rgb32(BLUE),
                fill_color = rgb32(RED),
            })
            assert.same(RED, pixel(bb, 2, 2))
            assert.same(RED, pixel(bb, 11, 11))
            assert.same(BLUE, pixel(bb, 14, 13))
            assert.same(BLUE, pixel(bb, 12, 5))
            assert.same(WHITE, pixel(bb, 15, 13))
            assert.same(WHITE, pixel(bb, 14, 14))
            assert.same(WHITE, pixel(bb, 3, 13))
        end)

        it("paints no shadow without a shadow colour and no fill without a fill colour", function()
            bb = buffer(30, 30)
            Paint.backing(bb, 2, 2, 10, 10, box{ fill_color = rgb32(RED) })
            assert.same(RED, pixel(bb, 11, 11))
            assert.same(WHITE, pixel(bb, 14, 13))
            Paint.backing(bb, 2, 2, 10, 10, box{ shadow_color = rgb32(BLUE) })
            assert.same(RED, pixel(bb, 3, 3))
            assert.same(BLUE, pixel(bb, 14, 13))
        end)

        it("rounds its shadow by radius and its fill by fill_radius", function()
            bb = buffer(40, 40)
            Paint.backing(bb, 0, 0, 20, 20, box{
                shadow_x = 10,
                shadow_y = 10,
                shadow_color = rgb32(BLUE),
                fill_color = rgb32(RED),
                radius = 6,
                fill_radius = 0,
            })
            assert.same(RED, pixel(bb, 0, 0))
            assert.same(WHITE, pixel(bb, 29, 29))
            assert.same(BLUE, pixel(bb, 25, 25))
        end)

        it("outlines it outline wide in its outline colour, rounded by radius", function()
            bb = buffer(30, 30)
            Paint.backing(bb, 0, 0, 20, 20, box{ fill_color = rgb32(RED) })
            Paint.outline(bb, 0, 0, 20, 20, box{ outline = 2, outline_color = rgb32(GREEN), radius = 6 })
            assert.same(GREEN, pixel(bb, 10, 1))
            assert.same(RED, pixel(bb, 10, 2))
            assert.same(RED, pixel(bb, 0, 0))
        end)

        it("draws no outline at an outline of 0", function()
            bb = buffer(30, 30)
            Paint.backing(bb, 0, 0, 20, 20, box{ fill_color = rgb32(RED) })
            Paint.outline(bb, 0, 0, 20, 20, box{ outline = 0, outline_color = rgb32(GREEN) })
            assert.same(RED, pixel(bb, 0, 0))
            assert.same(RED, pixel(bb, 10, 0))
        end)
    end)
end)
