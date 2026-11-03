-- The wallpaper behind the home's rows: the wallpaper.file setting's image, drawn only by a look whose
-- wallpaper.enabled token is true, scaled to cover the screen, centred and cropped. Rendered once per path,
-- screen size, palette variant and night mode and kept for its holder, the home, until that home closes or a
-- build asks for another; a painter asks for it by key at each paint (Wallpaper.current). A file that is
-- missing, too large or won't render is logged once and draws nothing. KOReader decodes the whole file at its
-- own size before it scales it (frontend/ui/renderimage.lua:115-134) and a process the device kills for memory
-- can't be caught, so a file over 12 MB, or whose PNG or JPEG header claims more than 4000 px on a side, is
-- refused before it is read; a header that is neither, or can't be read, leaves the byte cap alone.
-- Night mode inverts the whole screen, so the image is kept inverted, as ImageWidget
-- inverts a cover at night (frontend/ui/widget/imagewidget.lua:583-593); in grey it is an 8-bit grey buffer, the
-- screen's own type, which blitFrom converts it to (base/ffi/blitbuffer.lua:1281). The scaled image, before night's
-- inversion, is also kept in one file under KOReader's cache folder (datastorage.lua:96-120), in a subfolder so the
-- document cache doesn't take it for its own (frontend/cache.lua:68-77, frontend/fontlist.lua:12), as its raw pixels
-- (base/ffi/blitbuffer.lua:2623-2639), so a later home reads it back instead of decoding the file again. State: the
-- image held, { key, bb, holder }, and the files that failed, by key.
local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Device = require("device")
local RenderImage = require("ui/renderimage")
local Settings = require("settings")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local Wallpaper = {}

local held
local failed = {}

-- The largest file, and the longest side a header may claim, that is decoded.
local MAX_BYTES = 12 * 1024 * 1024
local MAX_SIDE = 4000
-- How many JPEG segments are read looking for the frame header before the header counts as unknown.
local MAX_SEGMENTS = 64

-- The cache file: CACHE_MAGIC, the key's length on a line of its own, the key, then the image's pixels.
local CACHE_DIR = DataStorage:getDataDir() .. "/cache/kopanda"
local CACHE_FILE = CACHE_DIR .. "/wallpaper"
local CACHE_MAGIC = "KoPanda wallpaper 1\n"

local function drop()
    if held then
        held.bb:free()
        held = nil
    end
end

local function u16(bytes, i)
    return bytes:byte(i) * 256 + bytes:byte(i + 1)
end

-- The width and height the open file f's header claims, or nil when it is neither a PNG's IHDR
-- (its width and height at bytes 16-23) nor a JPEG frame header (SOFn, any but the DHT, JPG and
-- DAC markers that share its range) within MAX_SEGMENTS segments, or can't be read.
local function dimensions(f)
    local head = f:read(24)
    if not head or #head < 4 then
        return nil
    end
    if #head == 24 and head:sub(1, 8) == "\137PNG\r\n\26\n" and head:sub(13, 16) == "IHDR" then
        return u16(head, 17) * 65536 + u16(head, 19), u16(head, 21) * 65536 + u16(head, 23)
    end
    if u16(head, 1) ~= 0xFFD8 then
        return nil
    end
    local pos = 2
    for _ = 1, MAX_SEGMENTS do
        f:seek("set", pos)
        local segment = f:read(9)
        if not segment or #segment < 4 or segment:byte(1) ~= 0xFF then
            return nil
        end
        local marker = segment:byte(2)
        if marker >= 0xC0 and marker <= 0xCF and marker ~= 0xC4 and marker ~= 0xC8 and marker ~= 0xCC then
            if #segment < 9 then
                return nil
            end
            return u16(segment, 8), u16(segment, 6)
        end
        local length = u16(segment, 3)
        if marker == 0xD9 or marker == 0xDA or length < 2 then
            return nil
        end
        pos = pos + 2 + length
    end
    return nil
end

-- Raises when the file at path is too large to decode on the device: over MAX_BYTES, or a header
-- claiming more than MAX_SIDE px on a side.
local function refuse_large(path)
    local size = lfs.attributes(path, "size")
    if size and size > MAX_BYTES then
        error(string.format("it is too large to decode (%d bytes, over %d)", size, MAX_BYTES), 0)
    end
    local f = io.open(path, "rb")
    if not f then
        return
    end
    local w, h = dimensions(f)
    f:close()
    if w and (w > MAX_SIDE or h > MAX_SIDE) then
        error(string.format("it is too large to decode (%d x %d px, over %d a side)", w, h, MAX_SIDE), 0)
    end
end

-- The file at path rendered for a w by h screen into a buffer of bbtype: RenderImage:renderImageFile at the file's
-- own size (frontend/ui/renderimage.lua:28-37), scaled to cover by RenderImage:scaleBlitBuffer (:303-328, which
-- frees the render it scales), centred and cropped into a new buffer. Raises when it won't render.
local function render(path, w, h, bbtype)
    local image = RenderImage:renderImageFile(path, false)
    if not image then
        error("it didn't render", 0)
    end
    local iw, ih = image:getWidth(), image:getHeight()
    local scale = math.max(w / iw, h / ih)
    local sw, sh = math.max(w, math.ceil(iw * scale)), math.max(h, math.ceil(ih * scale))
    local scaled = RenderImage:scaleBlitBuffer(image, sw, sh)
    local bb = Blitbuffer.new(w, h, bbtype)
    bb:blitFrom(scaled, 0, 0, math.floor((sw - w) / 2), math.floor((sh - h) / 2), w, h)
    scaled:free()
    return bb
end

-- The image the cache holds for key, w by h in bbtype, or nil when there is none or it holds another key.
-- Raises when the file is there but isn't a whole cache.
local function read_cache(key, w, h, bbtype)
    local f = io.open(CACHE_FILE, "rb")
    if not f then
        return nil
    end
    local ok, result = pcall(function()
        if f:read(#CACHE_MAGIC) ~= CACHE_MAGIC then
            error("it doesn't start as a cache", 0)
        end
        local length = tonumber(f:read("*l"))
        if not length then
            error("it has no key", 0)
        end
        if f:read(length) ~= key then
            return nil
        end
        local size = w * h * Blitbuffer.TYPE_TO_BPP[bbtype] / 8
        local pixels = f:read(size)
        if not pixels or #pixels ~= size or f:read(1) then
            error("its pixels aren't a " .. w .. " x " .. h .. " image", 0)
        end
        return Blitbuffer.fromstring(w, h, bbtype, pixels)
    end)
    f:close()
    if not ok then
        error(result, 0)
    end
    return result
end

-- Writes image to the cache for key through a temporary file renamed over the last, so a write cut short leaves
-- the last cache or none. Raises when it can't.
local function write_cache(key, image)
    lfs.mkdir(CACHE_DIR)
    local temp = CACHE_FILE .. ".part"
    local pixels = Blitbuffer.tostring(image)
    local f, err = io.open(temp, "wb")
    if not f then
        error(err, 0)
    end
    local written, write_err = f:write(CACHE_MAGIC, #key, "\n", key, pixels)
    if written then
        ffiUtil.fsyncOpenedFile(f)
    end
    local closed, close_err = f:close()
    local renamed, rename_err
    if written and closed then
        renamed, rename_err = os.rename(temp, CACHE_FILE)
    end
    if not renamed then
        os.remove(temp)
        error(write_err or close_err or rename_err, 0)
    end
end

-- The file at path, whose stamp is now, for a w by h screen in bbtype before night's inversion, from the cache
-- when it holds the same, else rendered and cached; raises when the file is too large or won't render.
local function load(path, now, w, h, bbtype)
    local key = table.concat({
        path,
        now,
        w,
        h,
        bbtype,
        -- TurboJPEG decodes grey on a grey screen (frontend/ui/renderimage.lua:120), and legacy scaling is
        -- nearest neighbour (:317).
        tostring(Device:hasColorScreen()),
        tostring(G_reader_settings:isTrue("legacy_image_scaling")),
    }, "\0")
    local read, cached = pcall(read_cache, key, w, h, bbtype)
    if read and cached then
        return cached
    end
    if not read then
        logger.warn("KoPanda: could not read the wallpaper cache", CACHE_FILE, "so it is rebuilt:", cached)
    end
    refuse_large(path)
    local image = render(path, w, h, bbtype)
    local written, err = pcall(write_cache, key, image)
    if not written then
        logger.warn("KoPanda: could not write the wallpaper cache", CACHE_FILE, ":", err)
    end
    return image
end

-- What a failed file is remembered by: its size and modification time, so a file copied there
-- later, or changed, is tried again.
local function stamp(path)
    local attributes = lfs.attributes(path)
    if not attributes then
        return "missing"
    end
    return tostring(attributes.size) .. "@" .. tostring(attributes.modification)
end

-- The image to draw behind the home's rows for look in variant on a w by h screen, held for holder, and the key
-- it is held by (for Wallpaper.current), or nil: with a look that draws none or no file set (dropping any image
-- held), or when the file is missing or won't render (logged once per file state).
function Wallpaper.get(look, variant, w, h, holder)
    local path = look.wallpaper.enabled and Settings.get("wallpaper.file")
    if not path then
        drop()
        return nil
    end
    local night = Device.screen.night_mode == true
    local key = table.concat({ path, w, h, variant, tostring(night) }, "\0")
    if held and held.key == key then
        held.holder = holder
        return held.bb, key
    end
    drop()
    local now = stamp(path)
    if failed[key] == now then
        return nil
    end
    local ok, result = pcall(function()
        if now == "missing" then
            error("there is no such file", 0)
        end
        local image = load(path, now, w, h, variant == "grey" and Blitbuffer.TYPE_BB8 or Blitbuffer.TYPE_BBRGB32)
        if night then
            image:invertRect(0, 0, w, h)
        end
        return image
    end)
    if not ok then
        failed[key] = now
        logger.warn("KoPanda: the wallpaper", path, "isn't drawn:", result)
        return nil
    end
    failed[key] = nil
    held = { key = key, bb = result, holder = holder }
    return result, key
end

-- The image held by key (from Wallpaper.get), or nil once another get or a release has freed it:
-- a painter asks at each paint, so it never paints a buffer freed since it built.
function Wallpaper.current(key)
    if held and held.key == key then
        return held.bb
    end
    return nil
end

-- Frees the image held when holder holds it.
function Wallpaper.release(holder)
    if held and held.holder == holder then
        drop()
    end
end

-- Paints image at x, y on bb. A buffer that stores its writes inverted (night mode on a panel that can't invert,
-- base/ffi/framebuffer.lua:476-488) has its flag lifted for the copy, so the C blitter takes it
-- (base/ffi/blitbuffer.lua:733-740), and the copy is inverted back in place.
function Wallpaper.paint(bb, x, y, image)
    local w, h = image:getWidth(), image:getHeight()
    if bb:getInverse() ~= 1 then
        bb:blitFrom(image, x, y, 0, 0, w, h)
        return
    end
    bb:setInverse(0)
    local ok, err = pcall(function()
        bb:blitFrom(image, x, y, 0, 0, w, h)
        bb:invertRect(x, y, w, h)
    end)
    bb:setInverse(1)
    if not ok then
        error(err, 0)
    end
end

-- For specs: free the image held and forget the failures, as in a new process.
function Wallpaper._reset()
    drop()
    failed = {}
end

return Wallpaper
