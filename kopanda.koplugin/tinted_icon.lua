-- An icon file drawn in a colour: TintedIcon:new{ file, size, color }, size × size. The icons are
-- black stroke files and ImageWidget's dim only lightens on a white ground
-- (frontend/ui/widget/imagewidget.lua:570-579), so this takes the method that note proposes: the
-- rendered icon blended onto white and inverted is an alpha mask whose ink is white, built once,
-- and each paint colours the target through it.
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

-- Renders the file (an RGB32 buffer with straight alpha, frontend/ui/renderimage.lua:338-344,
-- :390-393) and keeps the mask: white filled, the render alpha-blitted on, then inverted
-- (base/ffi/blitbuffer.lua:1506, :1318, :1567). A file that won't render leaves no mask, so the
-- widget paints nothing.
function TintedIcon:init()
    local size = self.size
    self.dimen = Geom:new{ w = size, h = size }
    local ok, rendered = pcall(RenderImage.renderSVGImageFile, RenderImage, self.file, size, size)
    if not (ok and rendered) then
        logger.warn("KoPanda: could not render the icon", self.file, ok and "" or rendered)
        return
    end
    local mask = Blitbuffer.new(size, size, Blitbuffer.TYPE_BB8)
    mask:fill(Blitbuffer.COLOR_WHITE)
    mask:alphablitFrom(rendered, 0, 0, 0, 0, size, size)
    mask:invertRect(0, 0, size, size)
    rendered:free()
    self.mask = mask
end

-- The mask's 8-bit value as the colour's alpha (base/ffi/blitbuffer.lua:1405-1437, :990-1006); a
-- grey through colorblitFrom, a colour through colorblitFromRGB32, as home.lua fills.
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

function TintedIcon:free()
    if self.mask then
        self.mask:free()
        self.mask = nil
    end
end

return TintedIcon
