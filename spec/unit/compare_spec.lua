describe("golden comparison", function()
    local ffi = require("ffi")
    local lfs = require("libs/libkoreader-lfs")
    local Png = require("ffi/png")
    local compare = require("emulator.compare")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local ko_home = os.getenv("KO_HOME")
    local fixtures = root .. "/spec/fixtures/png"

    require("ffi/lodepng_h")
    local lodepng = ffi.loadlib("lodepng")
    local colortypes = { [1] = lodepng.LCT_GREY, [3] = lodepng.LCT_RGB, [4] = lodepng.LCT_RGBA }

    -- Writes a w×h image with ncomp components per pixel to path. pixel(x, y) returns the
    -- component values for that pixel. Png.encodeToFile leaves lodepng's auto_convert on
    -- (base/ffi/png.lua:35), which stores an opaque grey RGBA image as grey; this encoder
    -- turns it off so each file keeps the colour type it is written with.
    local function write_png(path, w, h, ncomp, pixel)
        local mem = ffi.new("unsigned char[?]", w * h * ncomp)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local values = { pixel(x, y) }
                for c = 0, ncomp - 1 do
                    mem[(y * w + x) * ncomp + c] = values[c + 1]
                end
            end
        end
        local state = ffi.new("LodePNGState[1]")
        lodepng.lodepng_state_init(state)
        state[0].encoder.auto_convert = 0
        state[0].info_raw.colortype = colortypes[ncomp]
        state[0].info_raw.bitdepth = 8
        state[0].info_png.color.colortype = colortypes[ncomp]
        state[0].info_png.color.bitdepth = 8
        local out = ffi.new("unsigned char*[1]")
        local size = ffi.new("size_t[1]")
        local err = lodepng.lodepng_encode(out, size, mem, w, h, state)
        lodepng.lodepng_state_cleanup(state)
        assert(err == 0, ffi.string(lodepng.lodepng_error_text(err)))
        local f = assert(io.open(path, "wb"))
        f:write(ffi.string(out[0], size[0]))
        f:close()
        ffi.C.free(out[0])
    end

    -- A gradient, so every pixel is distinct and a misread offset shows up as a difference.
    local function base_rgb(x, y)
        return 40 * x, 40 * y, 100 + 10 * (x + y)
    end

    local function base_grey(x, y)
        return 30 * x + 50 * y
    end

    -- The committed 4×4 fixtures, each built from the base gradient by this table. A
    -- fixture missing from spec/fixtures/png/ is written here once and then committed.
    local builders = {
        ["base.png"] = { 4, 4, 3, base_rgb },
        ["one-pixel.png"] = { 4, 4, 3, function(x, y)
            if x == 2 and y == 1 then
                return 255, 0, 0
            end
            return base_rgb(x, y)
        end },
        ["faint-pixel.png"] = { 4, 4, 3, function(x, y)
            local r, g, b = base_rgb(x, y)
            if x == 2 and y == 1 then
                return r + 10, g, b
            end
            return r, g, b
        end },
        ["block.png"] = { 4, 4, 3, function(x, y)
            if x >= 1 and x <= 2 and y >= 1 and y <= 2 then
                return 255, 255, 255
            end
            return base_rgb(x, y)
        end },
        ["wide.png"] = { 5, 4, 3, base_rgb },
        ["grey.png"] = { 4, 4, 1, base_grey },
        ["grey-rgba.png"] = { 4, 4, 4, function(x, y)
            local v = base_grey(x, y)
            return v, v, v, 255
        end },
    }

    local function fixture(name)
        local path = fixtures .. "/" .. name
        if not lfs.attributes(path, "mode") then
            if not lfs.attributes(fixtures, "mode") then
                assert(lfs.mkdir(fixtures))
            end
            write_png(path, unpack(builders[name]))
        end
        return path
    end

    local counter = 0
    local function scratch_path(name)
        counter = counter + 1
        return string.format("%s/compare-spec-%d-%s", ko_home, counter, name)
    end

    it("passes identical images", function()
        local result = compare.compare(fixture("base.png"), fixture("base.png"))
        assert.is_true(result.ok)
        assert.equals(0, result.differing)
        assert.equals(16, result.compared)
        assert.equals(0, result.fraction)
    end)

    it("counts one pixel changed beyond the tolerance against the differing limit", function()
        local strict = compare.compare(fixture("one-pixel.png"), fixture("base.png"))
        assert.is_false(strict.ok)
        assert.equals(1, strict.differing)
        assert.equals(16, strict.compared)
        assert.equals(1 / 16, strict.fraction)
        local loose = compare.compare(fixture("one-pixel.png"), fixture("base.png"), { max_fraction = 0.1 })
        assert.is_true(loose.ok)
        assert.equals(1, loose.differing)
    end)

    it("passes a fraction exactly at the differing limit", function()
        local result = compare.compare(fixture("one-pixel.png"), fixture("base.png"), { max_fraction = 1 / 16 })
        assert.equals(1 / 16, result.fraction)
        assert.is_true(result.ok)
    end)

    it("ignores a change within the tolerance", function()
        local result = compare.compare(fixture("faint-pixel.png"), fixture("base.png"))
        assert.is_true(result.ok)
        assert.equals(0, result.differing)
        local tight = compare.compare(fixture("faint-pixel.png"), fixture("base.png"), { tolerance = 5 })
        assert.equals(1, tight.differing)
    end)

    it("skips pixels inside a mask rectangle", function()
        local masks = { { x = 1, y = 1, w = 2, h = 2 } }
        local result = compare.compare(fixture("block.png"), fixture("base.png"), { masks = masks })
        assert.is_true(result.ok)
        assert.equals(0, result.differing)
        assert.equals(16 - 4, result.compared)
        local unmasked = compare.compare(fixture("block.png"), fixture("base.png"))
        assert.equals(4, unmasked.differing)
    end)

    it("counts a pixel covered by overlapping masks once", function()
        local masks = { { x = 1, y = 1, w = 2, h = 2 }, { x = 2, y = 2, w = 1, h = 1 } }
        local result = compare.compare(fixture("block.png"), fixture("base.png"), { masks = masks })
        assert.equals(16 - 4, result.compared)
        assert.equals(0, result.differing)
    end)

    it("clips a mask reaching outside the image", function()
        local masks = { { x = 2, y = -3, w = 10, h = 5 } }
        local result = compare.compare(fixture("one-pixel.png"), fixture("base.png"), { masks = masks })
        assert.equals(16 - 4, result.compared)
        assert.equals(0, result.differing)
        local outside = compare.compare(fixture("base.png"), fixture("base.png"),
            { masks = { { x = 100, y = 100, w = 5, h = 5 } } })
        assert.equals(16, outside.compared)
    end)

    it("fails on a size mismatch naming both sizes without writing a diff", function()
        local diff = scratch_path("size.diff.png")
        local result = compare.compare(fixture("wide.png"), fixture("base.png"), { diff_png = diff })
        assert.is_false(result.ok)
        assert.equals("size", result.reason)
        assert.same({ 5, 4 }, result.actual)
        assert.same({ 4, 4 }, result.golden)
        assert.is_nil(lfs.attributes(diff, "mode"))
    end)

    it("writes a diff image of the compared size on failure", function()
        local diff = scratch_path("one-pixel.diff.png")
        local result = compare.compare(fixture("one-pixel.png"), fixture("base.png"), { diff_png = diff })
        assert.is_false(result.ok)
        assert.equals(diff, result.diff_png)
        assert.equals("file", lfs.attributes(diff, "mode"))
        local w, h = driver.png_size(diff)
        assert.equals(4, w)
        assert.equals(4, h)
        local ok, image = Png.decodeFromFile(diff, 3)
        assert.is_true(ok)
        local function rgb(x, y)
            local i = (y * image.width + x) * 3
            return image.data[i], image.data[i + 1], image.data[i + 2]
        end
        assert.same({ 255, 0, 0 }, { rgb(2, 1) })
        local r, g, b = rgb(0, 0)
        assert.truthy(r == g and g == b and r >= 128, "unchanged pixel not light grey")
        ffi.C.free(image.data)
    end)

    it("writes no diff when the images match", function()
        local diff = scratch_path("match.diff.png")
        local result = compare.compare(fixture("base.png"), fixture("base.png"), { diff_png = diff })
        assert.is_true(result.ok)
        assert.is_nil(result.diff_png)
        assert.is_nil(lfs.attributes(diff, "mode"))
    end)

    it("reads a grey PNG and an RGBA PNG of the same image as equal", function()
        local result = compare.compare(fixture("grey.png"), fixture("grey-rgba.png"), { tolerance = 0 })
        assert.is_true(result.ok)
        assert.equals(0, result.differing)
        assert.equals(16, result.compared)
    end)

    it("names the file it cannot read", function()
        local missing = scratch_path("missing.png")
        local ok, err = pcall(compare.compare, missing, fixture("base.png"))
        assert.is_false(ok)
        assert.truthy(tostring(err):find(missing, 1, true), err)
    end)

    it("names a diff image it cannot write", function()
        local diff = scratch_path("no-such-dir") .. "/one-pixel.diff.png"
        local ok, err = pcall(compare.compare, fixture("one-pixel.png"), fixture("base.png"), { diff_png = diff })
        assert.is_false(ok)
        assert.truthy(tostring(err):find(diff, 1, true), err)
    end)

    it("names a golden it cannot read", function()
        local missing = scratch_path("missing-golden.png")
        local ok, err = pcall(compare.compare, fixture("base.png"), missing)
        assert.is_false(ok)
        assert.truthy(tostring(err):find(missing, 1, true), err)
    end)

    it("compares a full-size pair in under 2 s", function()
        local w, h = 1264, 1680
        local golden = scratch_path("full-golden.png")
        local actual = scratch_path("full-actual.png")
        local function pixel(x, y)
            return (x * 7 + y) % 256, (x + y * 3) % 256, (x * y) % 256
        end
        write_png(golden, w, h, 3, pixel)
        write_png(actual, w, h, 3, function(x, y)
            if x < 10 and y < 10 then
                return 255 - (x * 7 + y) % 256, 0, 0
            end
            return pixel(x, y)
        end)
        local started = os.clock()
        local result = compare.compare(actual, golden)
        local elapsed = os.clock() - started
        assert.equals(w * h, result.compared)
        assert.truthy(result.differing > 0 and result.differing <= 100)
        assert.truthy(elapsed < 2, string.format("took %.2f s", elapsed))
    end)
end)
