-- An icon file drawn in a colour: TintedIcon:new{ file, size, color }, size × size. The icons are
-- black stroke files and ImageWidget's dim only lightens on a white ground
-- (frontend/ui/widget/imagewidget.lua:570-579), so this takes the method that note proposes: the
-- rendered icon blended onto white and inverted is an alpha mask whose ink is white, built once per
-- file and size and kept for the process (the widget's free lets go of it without freeing it),
-- and each paint colours the target through it. A render that fails is not cached, and the icon
-- then draws nothing.
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local RenderImage = require("ui/renderimage")
local Widget = require("ui/widget/widget")
local logger = require("logger")

local TintedIcon = Widget:extend{
    name = "kopanda_tinted_icon",
    file = nil,
    size = nil,
    color = nil,
}

-- Masks by file and size: the colour is applied at paint, so one mask serves every icon of that
-- file at that size for the process, as ImageWidget keeps its renders in ImageCache by file and
-- size (frontend/ui/widget/imagewidget.lua:147-160). Bounded by the icon registry times the few
-- sizes the plugin draws at.
local masks = {}

-- Renders the file (an RGB32 buffer with straight alpha, frontend/ui/renderimage.lua:338-344,
-- :390-393) into the mask: white filled, the render alpha-blitted on, then inverted
-- (base/ffi/blitbuffer.lua:1506, :1318, :1567), or takes it from the cache. A file that won't
-- render leaves no mask and nothing cached, so the widget paints nothing and the next icon of the
-- file tries again.
function TintedIcon:init()
    local size = self.size
    self.dimen = Geom:new{ w = size, h = size }
    local key = tostring(self.file) .. "\0" .. size
    local mask = masks[key]
    if not mask then
        local ok, rendered = pcall(RenderImage.renderSVGImageFile, RenderImage, self.file, size, size)
        if not (ok and rendered) then
            logger.warn("KoPanda: could not render the icon", self.file, ok and "" or rendered)
            return
        end
        mask = Blitbuffer.new(size, size, Blitbuffer.TYPE_BB8)
        mask:fill(Blitbuffer.COLOR_WHITE)
        mask:alphablitFrom(rendered, 0, 0, 0, 0, size, size)
        mask:invertRect(0, 0, size, size)
        rendered:free()
        masks[key] = mask
    end
    self.mask = mask
end

-- The mask's 8-bit value as the colour's alpha (base/ffi/blitbuffer.lua:1405-1437, :990-1006); a
-- grey through colorblitFrom, a colour through colorblitFromRGB32, as home_rows.lua fills.
function TintedIcon:paintTo(bb, x, y)
    local mask, size = self.mask, self.size
    if not mask then
        return
    end
    if Blitbuffer.isColor8(self.color) then
        bb:colorblitFrom(mask, x, y, 0, 0, size, size, self.color)
    else
        bb:colorblitFromRGB32(mask, x, y, 0, 0, size, size, self.color)
    end
end

-- The mask belongs to the cache, so the widget only lets go of it.
function TintedIcon:free()
    self.mask = nil
end

return TintedIcon
