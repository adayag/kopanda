-- TintedIcon: a registry icon's ink painted in a given colour, grey or RGB32, every pixel a
-- blend from the white ground to that colour and the ground left white; its mask rendered once per
-- file and size and kept when the widget is freed; a file that won't render gives a blank widget of
-- its size, logged, and is tried again by the next icon of it.
describe("TintedIcon", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local logger = require("logger")
    local TintedIcon, Icons

    local SIZE = 48

    before_each(function()
        harness.load()
        TintedIcon = package.loaded["tinted_icon"]
        Icons = package.loaded["icons"]
    end)

    after_each(function()
        harness.teardown()
    end)

    -- A size × size buffer of type, filled white.
    local function white(bbtype)
        local bb = Blitbuffer.new(SIZE, SIZE, bbtype)
        bb:fill(Blitbuffer.COLOR_WHITE)
        return bb
    end

    it("is loaded with the plugin", function()
        assert.is_table(TintedIcon)
    end)

    it("paints the wifi icon's ink in a grey, no pixel darker than it and some inked", function()
        local icon = TintedIcon:new{ file = Icons.path("wifi"), size = SIZE, color = Blitbuffer.Color8(0x80) }
        assert.same({ SIZE, SIZE }, { icon:getSize().w, icon:getSize().h })
        local bb = white(Blitbuffer.TYPE_BB8)
        icon:paintTo(bb, 0, 0)
        local inked, full, ground = 0, 0, 0
        for y = 0, SIZE - 1 do
            for x = 0, SIZE - 1 do
                local v = bb:getPixel(x, y):getColor8().a
                assert.is_true(v >= 0x80 and v <= 0xFF, ("pixel %d,%d is %d"):format(x, y, v))
                if v < 0xFF then
                    inked = inked + 1
                else
                    ground = ground + 1
                end
                if v == 0x80 then
                    full = full + 1
                end
            end
        end
        assert.is_true(inked > 0, "no pixel inked")
        assert.is_true(full > 0, "no pixel at the full colour")
        assert.is_true(ground > SIZE * SIZE / 2, "the ground is inked")
        icon:free()
        bb:free()
    end)

    it("paints the wifi icon's ink in an RGB32 colour, every inked pixel between white and it", function()
        local color = Blitbuffer.colorFromString("#e0bd6a")
        local target = color:getColorRGB32()
        local icon = TintedIcon:new{ file = Icons.path("wifi"), size = SIZE, color = color }
        local bb = white(Blitbuffer.TYPE_BBRGB32)
        icon:paintTo(bb, 0, 0)
        local inked, ground = 0, 0
        for y = 0, SIZE - 1 do
            for x = 0, SIZE - 1 do
                local c = bb:getPixel(x, y):getColorRGB32()
                local where = ("pixel %d,%d is %d,%d,%d"):format(x, y, c.r, c.g, c.b)
                if c.r ~= 0xFF or c.g ~= 0xFF or c.b ~= 0xFF then
                    inked = inked + 1
                    -- On the line from white to the colour: each channel within its range, and the
                    -- three at one blend, to a rounding step.
                    local ts = {}
                    for i, channel in ipairs({ "r", "g", "b" }) do
                        local v, t = c[channel], target[channel]
                        assert.is_true(v >= t and v <= 0xFF, where)
                        ts[i] = (0xFF - v) / (0xFF - t)
                    end
                    assert.is_true(math.abs(ts[1] - ts[3]) < 0.05 and math.abs(ts[2] - ts[3]) < 0.05, where)
                else
                    ground = ground + 1
                end
            end
        end
        assert.is_true(inked > 0, "no pixel inked")
        assert.is_true(ground > SIZE * SIZE / 2, "the ground is inked")
        icon:free()
        bb:free()
    end)

    -- The mask is cached by file and size, so the widget drops its reference when freed and
    -- leaves the mask to the cache.
    it("keeps its cached mask when freed", function()
        local icon = TintedIcon:new{ file = Icons.path("wifi"), size = SIZE, color = Blitbuffer.Color8(0x80) }
        -- A cdata blitbuffer takes no spy, so the mask is wrapped by a recorder of frees.
        local mask, freed = icon.mask, 0
        assert.is_not_nil(mask)
        icon.mask = {
            free = function()
                freed = freed + 1
            end,
        }
        icon:free()
        assert.equals(0, freed)
        assert.is_nil(icon.mask)
    end)

    it("renders a file at a size once, the mask outliving a freed icon, and another file or size again", function()
        local RenderImage = require("ui/renderimage")
        local rendered = spy.on(RenderImage, "renderSVGImageFile")
        finally(function()
            RenderImage.renderSVGImageFile:revert()
        end)
        local file = Icons.path("wifi")
        local first = TintedIcon:new{ file = file, size = SIZE, color = Blitbuffer.Color8(0x80) }
        local second = TintedIcon:new{ file = file, size = SIZE, color = Blitbuffer.Color8(0x40) }
        assert.spy(rendered).was.called(1)
        local home_path = Icons.path("home")
        local home = TintedIcon:new{ file = home_path, size = SIZE, color = Blitbuffer.Color8(0x80) }
        assert.spy(rendered).was.called(2)
        assert.spy(rendered).was.called_with(RenderImage, home_path, SIZE, SIZE)
        assert.is_false(rawequal(home.mask, second.mask), "the home icon took the wifi icon's mask")
        first:free()
        -- BB:free frees the data and keeps the pointer (base/ffi/blitbuffer.lua:1472-1478), so a
        -- paint can't tell a freed mask; its allocated flag can (:696-698).
        assert.equals(1, second.mask:getAllocated())
        local bb = white(Blitbuffer.TYPE_BB8)
        second:paintTo(bb, 0, 0)
        local inked = 0
        for y = 0, SIZE - 1 do
            for x = 0, SIZE - 1 do
                if bb:getPixel(x, y):getColor8().a < 0xFF then
                    inked = inked + 1
                end
            end
        end
        assert.is_true(inked > 0, "the second icon paints nothing once the first is freed")
        local smaller = TintedIcon:new{ file = file, size = SIZE / 2, color = Blitbuffer.Color8(0x80) }
        assert.spy(rendered).was.called(3)
        assert.spy(rendered).was.called_with(RenderImage, file, SIZE / 2, SIZE / 2)
        second:free()
        home:free()
        smaller:free()
        bb:free()
    end)

    it("leaves a failed render uncached, so the next icon of the file tries again", function()
        local RenderImage = require("ui/renderimage")
        local rendered = spy.on(RenderImage, "renderSVGImageFile")
        finally(function()
            RenderImage.renderSVGImageFile:revert()
        end)
        local path = harness.root .. "/spec/no-such-icon.svg"
        TintedIcon:new{ file = path, size = SIZE, color = Blitbuffer.Color8(0x80) }:free()
        local again = TintedIcon:new{ file = path, size = SIZE, color = Blitbuffer.Color8(0x80) }
        assert.spy(rendered).was.called(2)
        assert.is_nil(again.mask)
    end)

    -- A wake rebuilds the home under the same look and settings; its launcher and nav bar icons
    -- come from the cache the second time.
    it("renders each of the home's icons once over two builds", function()
        local Geom = require("ui/geometry")
        local RenderImage = require("ui/renderimage")
        local HomeRows = package.loaded["home_rows"]
        local Screen = require("device").screen
        local counts, total = {}, 0
        local render = RenderImage.renderSVGImageFile
        RenderImage.renderSVGImageFile = function(self, file, w, h, ...)
            local key = ("%s@%dx%d"):format(file, w, h)
            counts[key] = (counts[key] or 0) + 1
            total = total + 1
            return render(self, file, w, h, ...)
        end
        finally(function()
            RenderImage.renderSVGImageFile = render
        end)
        local first
        harness.at_colorsoft(function()
            local home = { dimen = Geom:new{ w = Screen:getWidth(), h = Screen:getHeight() } }
            for _ = 1, 2 do
                HomeRows.build(home):free()
                first = first or total
            end
        end)
        assert.is_true(first > 0, "the first build rendered no icon")
        assert.equals(first, total, "the second build rendered again")
        for key, n in pairs(counts) do
            assert.equals(1, n, key)
        end
    end)

    it("gives a blank widget of its size, logged, for a file that won't render", function()
        local warned = spy.on(logger, "warn")
        finally(function()
            logger.warn:revert()
        end)
        local path = harness.root .. "/spec/no-such-icon.svg"
        local icon = TintedIcon:new{ file = path, size = SIZE, color = Blitbuffer.Color8(0x80) }
        assert.same({ SIZE, SIZE }, { icon:getSize().w, icon:getSize().h })
        local bb = white(Blitbuffer.TYPE_BB8)
        icon:paintTo(bb, 0, 0)
        for y = 0, SIZE - 1 do
            for x = 0, SIZE - 1 do
                assert.equals(0xFF, bb:getPixel(x, y):getColor8().a)
            end
        end
        local logged = false
        for _, call in ipairs(warned.calls) do
            for _, arg in ipairs(call.vals) do
                logged = logged or tostring(arg):find(path, 1, true) ~= nil
            end
        end
        assert.is_true(logged, "no log line names the file")
        icon:free()
        bb:free()
    end)

    it("gives a blank widget of its size for a nil file", function()
        local icon = TintedIcon:new{ file = nil, size = SIZE, color = Blitbuffer.Color8(0x80) }
        assert.same({ SIZE, SIZE }, { icon:getSize().w, icon:getSize().h })
        assert.is_nil(icon.mask)
        icon:free()
    end)
end)
