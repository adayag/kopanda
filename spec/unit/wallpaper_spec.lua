-- wallpaper.lua: the wallpaper.file setting's image behind a look that draws one, scaled to cover the screen and
-- centred, rendered once per path, size and palette variant and kept until its holder lets go or the setting, size or
-- variant changes; pre-inverted at night; a missing or unrenderable file logged once and drawn as nothing; the scaled
-- image kept on disk so a later home reads it back instead of decoding the file again. Rendered from PNGs this spec
-- writes under the scratch KO_HOME, and spec/fixtures/wallpaper.png.
describe("wallpaper", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local RenderImage = require("ui/renderimage")
    local logger = require("logger")
    local Screen = require("device").screen
    local Settings, Wallpaper, frosted, diner, night_mode
    local dir = os.getenv("KO_HOME") .. "/wallpaper-spec"
    local lfs = require("libs/libkoreader-lfs")
    local cache_dir = require("datastorage"):getDataDir() .. "/cache/kopanda"
    local cache_file = cache_dir .. "/wallpaper"

    local RED, BLUE, GREEN = { 220, 20, 30 }, { 20, 40, 220 }, { 0, 160, 0 }

    local function rgb32(c)
        return Blitbuffer.ColorRGB32(c[1], c[2], c[3], 0xFF)
    end

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

    -- A 40 × 10 PNG at name under dir: its left half red and right half blue, a 2 px green
    -- column at each edge, so a cover-fit into a square shows red and blue and no green.
    local function wide_png(name)
        local bb = Blitbuffer.new(40, 10, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, 20, 10, rgb32(RED))
        bb:paintRectRGB32(20, 0, 20, 10, rgb32(BLUE))
        bb:paintRectRGB32(0, 0, 2, 10, rgb32(GREEN))
        bb:paintRectRGB32(38, 0, 2, 10, rgb32(GREEN))
        local path = dir .. "/" .. name
        assert.is_true(bb:writePNG(path))
        bb:free()
        return path
    end

    -- The calls of a spy on logger.warn that are this module's, not a renderer's own warning.
    local function wallpaper_warnings(warn)
        local n = 0
        for _, call in ipairs(warn.calls) do
            if tostring(call.vals[1]):find("KoPanda: the wallpaper", 1, true) then
                n = n + 1
            end
        end
        return n
    end

    -- Whether one of this module's warnings on the spy says text.
    local function warned(warn, text)
        for _, call in ipairs(warn.calls) do
            for _, val in ipairs(call.vals) do
                if tostring(val):find(text, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    -- Writes bytes to name under dir and returns its path.
    local function write(name, bytes)
        local path = dir .. "/" .. name
        local f = assert(io.open(path, "wb"))
        f:write(bytes)
        f:close()
        return path
    end

    -- A big-endian 32-bit and 16-bit number, as PNG and JPEG headers store them.
    local function u16(n)
        return string.char(math.floor(n / 256) % 256, n % 256)
    end
    local function u32(n)
        return u16(math.floor(n / 65536)) .. u16(n % 65536)
    end

    -- The start of a PNG whose IHDR claims w by h: its signature, then the IHDR chunk's length,
    -- type and the width and height at bytes 16-23, 8-bit RGB, and a CRC no reader gets to.
    local function png_header(w, h)
        return "\137PNG\r\n\26\n" .. u32(13) .. "IHDR" .. u32(w) .. u32(h) .. "\8\2\0\0\0" .. u32(0)
    end

    -- The start of a JPEG whose frame header (SOF0, after an APP0 segment) claims w by h.
    local function jpeg_header(w, h)
        local app0 = "\255\224" .. u16(16) .. "JFIF\0\1\1\0\0\1\0\1\0\0"
        local sof0 = "\255\192" .. u16(17) .. "\8" .. u16(h) .. u16(w) .. "\3\1\17\0\2\17\1\3\17\1"
        return "\255\216" .. app0 .. sof0 .. "\255\217"
    end

    -- Counts RenderImage:renderImageFile calls, calling through.
    local function count_renders()
        local counter = { n = 0 }
        local render = RenderImage.renderImageFile
        RenderImage.renderImageFile = function(...)
            counter.n = counter.n + 1
            return render(...)
        end
        finally(function()
            RenderImage.renderImageFile = render
        end)
        return counter
    end

    before_each(function()
        harness.load()
        Settings = require("settings")
        Wallpaper = require("wallpaper")
        frosted = require("looks").get("frosted")
        diner = require("looks").get("diner")
        require("util").makePath(dir)
        night_mode = rawget(Screen, "night_mode")
        Screen.night_mode = false
    end)

    after_each(function()
        Screen.night_mode = night_mode
        Wallpaper._reset()
        Settings._reset()
        os.remove(harness.settings_file)
        os.remove(cache_file)
        os.remove(cache_file .. ".part")
        harness.teardown()
    end)

    it("scales the image to cover the screen, centred, cropping what overflows", function()
        Settings.set("wallpaper.file", wide_png("wide.png"))
        local image = Wallpaper.get(frosted, "day", 10, 10, "home")
        assert.same({ 10, 10 }, { image:getWidth(), image:getHeight() })
        for y = 0, 9 do
            assert.is_true(near(RED, pixel(image, 0, y)), "left " .. y)
            assert.is_true(near(BLUE, pixel(image, 9, y)), "right " .. y)
        end
    end)

    -- Day and night in colour are the same picture before night's inversion, so night reads day's from the cache.
    it("renders once per path, size and buffer type, and frees the one it replaces", function()
        local renders = count_renders()
        Settings.set("wallpaper.file", wide_png("once.png"))
        local day = Wallpaper.get(frosted, "day", 10, 10, "home")
        assert.equals(tostring(day), tostring(Wallpaper.get(frosted, "day", 10, 10, "home")))
        assert.equals(1, renders.n)
        local night = Wallpaper.get(frosted, "night", 10, 10, "home")
        assert.equals(1, renders.n)
        assert.equals(0, day:getAllocated())
        local bigger = Wallpaper.get(frosted, "night", 20, 20, "home")
        assert.equals(2, renders.n)
        assert.equals(0, night:getAllocated())
        Settings.set("wallpaper.file", wide_png("other.png"))
        Wallpaper.get(frosted, "night", 20, 20, "home")
        assert.equals(3, renders.n)
        assert.equals(0, bigger:getAllocated())
    end)

    it("pre-inverts the image at night, so the inverting panel shows the picture", function()
        Settings.set("wallpaper.file", wide_png("night.png"))
        Screen.night_mode = true
        local image = Wallpaper.get(frosted, "night", 10, 10, "home")
        assert.is_true(near({ 255 - RED[1], 255 - RED[2], 255 - RED[3] }, pixel(image, 0, 5)))
    end)

    -- Night mode on a grey screen keeps the grey variant (Looks.variant), but the screen still
    -- inverts, so the image is inverted as at night and held apart from the day's, read from the
    -- cache the day's image wrote.
    it("pre-inverts the grey image in night mode, held apart from the day's", function()
        local renders = count_renders()
        Settings.set("wallpaper.file", wide_png("grey-night.png"))
        local _, day_key = Wallpaper.get(frosted, "grey", 10, 10, "home")
        local day = pixel(Wallpaper.current(day_key), 0, 5)
        Screen.night_mode = true
        local image, night_key = Wallpaper.get(frosted, "grey", 10, 10, "home")
        assert.equals(1, renders.n)
        assert.are_not.equal(day_key, night_key)
        local got = pixel(image, 0, 5)
        assert.is_true(near({ 255 - day[1], 255 - day[2], 255 - day[3] }, got), table.concat(got, ","))
    end)

    it("renders a grey buffer in grey", function()
        Settings.set("wallpaper.file", wide_png("grey.png"))
        local image = Wallpaper.get(frosted, "grey", 10, 10, "home")
        assert.equals(Blitbuffer.TYPE_BB8, image:getType())
    end)

    it("frees the image when its holder lets go, and not for another holder", function()
        Settings.set("wallpaper.file", wide_png("held.png"))
        local image = Wallpaper.get(frosted, "day", 10, 10, "home")
        Wallpaper.release("another home")
        assert.equals(1, image:getAllocated())
        Wallpaper.release("home")
        assert.equals(0, image:getAllocated())
    end)

    it("renders nothing for a look that draws no wallpaper, freeing what it held", function()
        local renders = count_renders()
        Settings.set("wallpaper.file", wide_png("look.png"))
        local image = Wallpaper.get(frosted, "day", 10, 10, "home")
        assert.is_nil(Wallpaper.get(diner, "day", 10, 10, "home"))
        assert.equals(1, renders.n)
        assert.equals(0, image:getAllocated())
    end)

    it("draws nothing and renders nothing with no wallpaper set", function()
        local renders = count_renders()
        assert.is_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
        assert.equals(0, renders.n)
    end)

    it("logs a missing file once, draws nothing, and renders it once it is there", function()
        local path = dir .. "/later.png"
        os.remove(path)
        Settings.set("wallpaper.file", path)
        local warn = spy.on(logger, "warn")
        finally(function()
            logger.warn:revert()
        end)
        assert.is_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
        assert.is_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
        assert.equals(1, wallpaper_warnings(warn))
        wide_png("later.png")
        assert.is_not_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
    end)

    it("logs a file that won't render once and draws nothing", function()
        local path = dir .. "/broken.png"
        local f = assert(io.open(path, "wb"))
        f:write("not a png at all")
        f:close()
        Settings.set("wallpaper.file", path)
        local warn = spy.on(logger, "warn")
        finally(function()
            logger.warn:revert()
        end)
        assert.is_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
        assert.is_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
        assert.equals(1, wallpaper_warnings(warn))
    end)

    -- KOReader decodes the whole file before it scales (frontend/ui/renderimage.lua:115-134), so
    -- a file too large to decode on the device is refused before it is read.
    describe("a file too large to decode", function()
        local function refused(path)
            local renders = count_renders()
            Settings.set("wallpaper.file", path)
            local warn = spy.on(logger, "warn")
            finally(function()
                logger.warn:revert()
            end)
            assert.is_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
            assert.is_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
            assert.equals(1, wallpaper_warnings(warn))
            assert.is_true(warned(warn, "too large"))
            assert.equals(0, renders.n)
        end

        it("is refused over 12 MB, whatever its header", function()
            local path = dir .. "/huge.png"
            local f = assert(io.open(path, "wb"))
            f:write(png_header(10, 10))
            f:seek("set", 12 * 1024 * 1024)
            f:write("\0")
            f:close()
            refused(path)
        end)

        it("is refused when its PNG header is over 4000 px on a side", function()
            refused(write("tall.png", png_header(10, 9000)))
            Wallpaper._reset()
            refused(write("square.png", png_header(9000, 9000)))
        end)

        it("is refused when its JPEG frame is over 4000 px on a side", function()
            refused(write("wide.jpg", jpeg_header(5000, 100)))
        end)

        it("reaches the renderer within 4000 px a side", function()
            local renders = count_renders()
            Settings.set("wallpaper.file", write("within.jpg", jpeg_header(4000, 3000)))
            local warn = spy.on(logger, "warn")
            finally(function()
                logger.warn:revert()
            end)
            assert.is_nil(Wallpaper.get(frosted, "day", 10, 10, "home"))
            assert.equals(1, renders.n)
            assert.is_false(warned(warn, "too large"))
        end)
    end)

    it("renders the fixture wallpaper at the Colorsoft's size", function()
        Settings.set("wallpaper.file", harness.root .. "/spec/fixtures/wallpaper.png")
        local image = Wallpaper.get(frosted, "day", 1264, 1680, "home")
        assert.same({ 1264, 1680 }, { image:getWidth(), image:getHeight() })
    end)

    -- The scaled image is written under KOReader's cache folder once, and a later home reads it
    -- back instead of decoding the file; one file, rewritten whenever what it was scaled from changes.
    describe("the disk cache", function()
        local function read_file(path)
            local f = assert(io.open(path, "rb"))
            local bytes = f:read("*a")
            f:close()
            return bytes
        end

        -- A get for a home that has just opened, after the last one closed.
        local function reopen(variant, w, h)
            Wallpaper.release("home")
            return Wallpaper.get(frosted, variant or "day", w or 10, h or 10, "home")
        end

        local function shows_the_picture(image)
            assert.is_not_nil(image)
            for y = 0, image:getHeight() - 1 do
                assert.is_true(near(RED, pixel(image, 0, y)), "left " .. y)
                assert.is_true(near(BLUE, pixel(image, image:getWidth() - 1, y)), "right " .. y)
            end
        end

        before_each(function()
            if lfs.attributes(cache_dir, "mode") == "file" then
                os.remove(cache_dir)
            end
            os.remove(cache_file)
        end)

        it("reads a later home's image from the cache instead of decoding the file again", function()
            local renders = count_renders()
            Settings.set("wallpaper.file", wide_png("cached.png"))
            shows_the_picture(Wallpaper.get(frosted, "day", 10, 10, "home"))
            assert.equals("file", lfs.attributes(cache_file, "mode"))
            local image = reopen()
            assert.equals(1, renders.n)
            shows_the_picture(image)
            assert.equals(Blitbuffer.TYPE_BBRGB32, image:getType())
        end)

        it("rebuilds the cache when the file's time or size changes, or the screen's size", function()
            local renders = count_renders()
            local path = wide_png("changed.png")
            Settings.set("wallpaper.file", path)
            Wallpaper.get(frosted, "day", 10, 10, "home")
            local mtime = lfs.attributes(path, "modification")
            assert(lfs.touch(path, mtime + 10, mtime + 10))
            shows_the_picture(reopen())
            assert.equals(2, renders.n)
            reopen()
            assert.equals(2, renders.n)

            local f = assert(io.open(path, "ab"))
            f:write("\0\0\0\0")
            f:close()
            assert(lfs.touch(path, mtime + 10, mtime + 10))
            shows_the_picture(reopen())
            assert.equals(3, renders.n)

            local taller = reopen("day", 10, 12)
            assert.equals(4, renders.n)
            assert.same({ 10, 12 }, { taller:getWidth(), taller:getHeight() })
            reopen("day", 10, 12)
            assert.equals(4, renders.n)
            reopen("grey", 10, 12)
            assert.equals(5, renders.n)
        end)

        it("ignores a truncated or corrupt cache, draws from the file and rewrites the cache", function()
            local renders = count_renders()
            Settings.set("wallpaper.file", wide_png("corrupt.png"))
            Wallpaper.get(frosted, "day", 10, 10, "home")
            local good = read_file(cache_file)
            for i, bad in ipairs({ good:sub(1, #good - 7), "not a cache", good .. "extra" }) do
                local f = assert(io.open(cache_file, "wb"))
                f:write(bad)
                f:close()
                local warn = spy.on(logger, "warn")
                local image = reopen()
                logger.warn:revert()
                assert.equals(1 + i, renders.n)
                shows_the_picture(image)
                assert.is_true(warned(warn, "cache"), "warned " .. i)
                assert.equals(good, read_file(cache_file))
            end
        end)

        it("draws the wallpaper when the cache can't be written", function()
            local renders = count_renders()
            os.remove(cache_dir)
            local f = assert(io.open(cache_dir, "wb"))
            f:close()
            finally(function()
                os.remove(cache_dir)
            end)
            local warn = spy.on(logger, "warn")
            finally(function()
                logger.warn:revert()
            end)
            Settings.set("wallpaper.file", wide_png("unwritable.png"))
            shows_the_picture(Wallpaper.get(frosted, "day", 10, 10, "home"))
            assert.is_true(warned(warn, "cache"))
            shows_the_picture(reopen())
            assert.equals(2, renders.n)
        end)

        it("pre-inverts an image read from the cache at night", function()
            Settings.set("wallpaper.file", wide_png("cached-night.png"))
            Wallpaper.get(frosted, "day", 10, 10, "home")
            Screen.night_mode = true
            local renders = count_renders()
            local image = reopen("night")
            assert.equals(0, renders.n)
            assert.is_true(near({ 255 - RED[1], 255 - RED[2], 255 - RED[3] }, pixel(image, 0, 5)))
        end)

        it("a night first open caches the picture, not its inversion", function()
            local renders = count_renders()
            Settings.set("wallpaper.file", wide_png("night-first.png"))
            Screen.night_mode = true
            Wallpaper.get(frosted, "night", 10, 10, "home")
            Screen.night_mode = false
            local image = reopen("day")
            assert.equals(1, renders.n)
            shows_the_picture(image)
            Screen.night_mode = true
            image = reopen("night")
            assert.equals(1, renders.n)
            assert.is_true(near({ 255 - RED[1], 255 - RED[2], 255 - RED[3] }, pixel(image, 0, 5)))
        end)

        it("leaves no temporary file behind when the pixels can't be had", function()
            local tostring_bb = Blitbuffer.tostring
            Blitbuffer.tostring = function()
                error("no pixels", 0)
            end
            finally(function()
                Blitbuffer.tostring = tostring_bb
            end)
            Settings.set("wallpaper.file", wide_png("no-pixels.png"))
            shows_the_picture(Wallpaper.get(frosted, "day", 10, 10, "home"))
            assert.is_nil(lfs.attributes(cache_file .. ".part"))
            assert.is_nil(lfs.attributes(cache_file))
        end)

        it("flushes the cache to the disk before closing it", function()
            Settings.set("wallpaper.file", wide_png("synced.png"))
            local ffiutil = require("ffi/util")
            local fsync = ffiutil.fsyncOpenedFile
            local open_at_sync = {}
            ffiutil.fsyncOpenedFile = function(f, ...)
                table.insert(open_at_sync, io.type(f))
                return fsync(f, ...)
            end
            finally(function()
                ffiutil.fsyncOpenedFile = fsync
            end)
            Wallpaper.get(frosted, "day", 10, 10, "home")
            assert.same({ "file" }, open_at_sync)
        end)
    end)

    describe("paint", function()
        it("copies the image onto the screen", function()
            Settings.set("wallpaper.file", wide_png("paint.png"))
            local image = Wallpaper.get(frosted, "day", 10, 10, "home")
            local bb = Blitbuffer.new(12, 12, Blitbuffer.TYPE_BBRGB32)
            Wallpaper.paint(bb, 1, 1, image)
            assert.is_true(near(RED, pixel(bb, 1, 5)))
            assert.is_true(near(BLUE, pixel(bb, 10, 5)))
            bb:free()
        end)

        -- On a buffer that stores its writes inverted (night mode on a panel that can't invert,
        -- base/ffi/framebuffer.lua:476-488), the stored pixels are the picture.
        it("leaves the picture itself in a buffer that stores its writes inverted, keeping the flag", function()
            Settings.set("wallpaper.file", wide_png("paint-night.png"))
            Screen.night_mode = true
            local image = Wallpaper.get(frosted, "night", 10, 10, "home")
            local bb = Blitbuffer.new(10, 10, Blitbuffer.TYPE_BBRGB32)
            bb:setInverse(1)
            Wallpaper.paint(bb, 0, 0, image)
            assert.equals(1, bb:getInverse())
            bb:setInverse(0)
            assert.is_true(near(RED, pixel(bb, 0, 5)), table.concat(pixel(bb, 0, 5), ","))
            bb:free()
        end)
    end)
end)
