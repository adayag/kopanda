-- The swatch screen: a test pattern of every look's palettes and faces and of the icon registry,
-- full screen over the file manager or the reader, for settling the token values on a real
-- panel. Six panels, the looks across and the day, night and grey palettes down, each filled
-- with its paper and holding a chip per colour role and a line per face; the icons below. A tap
-- closes it. It is not part of the shell, so it opens while another shell plugin is enabled.
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local Fonts = require("fonts")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local Icons = require("icons")
local InputContainer = require("ui/widget/container/inputcontainer")
local Looks = require("looks")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local time = require("ui/time")
local Screen = require("device").screen

-- Lengths in board pixels, scaled by Screen:scaleBySize; font sizes unscaled, since
-- Font:getFace scales them itself (frontend/ui/font.lua:276).
local MARGIN = 8
local GAP = 4
local PADDING = 6
local CHIP = 14
local CHIP_BORDER = 1
local ICON = 16
local TITLE_SIZE = 11
local NOTE_SIZE = 9
local HEADER_SIZE = 10
local LABEL_SIZE = 9
local FACE_SIZE = 13
local ICON_LABEL_SIZE = 7

local VARIANTS = { "day", "night", "grey" }

local TITLE = "KoPanda swatches. Tap to close."
local NIGHT_NOTE = "Night mode is on: KOReader inverts these colours. Turn it off to judge them."

-- A rectangle of one colour, optionally outlined, with an optional child at an inset. KOReader's
-- paintRect greys any colour by luminance (base/ffi/blitbuffer.lua:1704-1724), so a colour fill
-- and outline go through the RGB32 variants (:1827, :2118-2126); a grey through the plain ones
-- (:2096).
local ColorBox = WidgetContainer:extend{
    color = nil,
    border = 0,
    border_color = nil,
    inset = 0,
}

function ColorBox:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local w, h = self.dimen.w, self.dimen.h
    if Blitbuffer.isColor8(self.color) then
        bb:paintRect(x, y, w, h, self.color)
    else
        bb:paintRectRGB32(x, y, w, h, self.color)
    end
    if self.border > 0 then
        if Blitbuffer.isColor8(self.border_color) then
            bb:paintBorder(x, y, w, h, self.border, self.border_color)
        else
            bb:paintBorderRGB32(x, y, w, h, self.border, self.border_color)
        end
    end
    if self[1] then
        self[1]:paintTo(bb, x + self.inset, y + self.inset)
    end
end

-- The colour a palette token is drawn in: its own on a colour screen, KOReader's luminance grey
-- of it otherwise (base/ffi/blitbuffer.lua:464-467). A grey panel's 8-bit framebuffer greys an
-- RGB32 paint the same way, but the emulator's grey profile keeps an RGB32 framebuffer
-- (base/ffi/framebuffer_SDL3.lua:20-23, :85-86) where it would keep its hue.
local function drawn(hex)
    local color = Looks.color(hex)
    if Screen:isColorEnabled() then
        return color
    end
    return color:getColor8()
end

local function scaled(px)
    return Screen:scaleBySize(px)
end

-- The face for a font file of the plugin at size, KOReader's UI font when the file won't load.
local function face_or_fallback(rel, size)
    local face = Fonts.face(rel, size)
    if face then
        return face, true
    end
    return Font:getFace("cfont", size), false
end

local function sorted_keys(t)
    local keys = {}
    for key in pairs(t) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- Text in a palette's ink on its paper. TextBoxWidget keeps an RGB foreground on a colour screen
-- (frontend/ui/widget/textboxwidget.lua:854-906), where TextWidget greys it
-- (frontend/ui/widget/textwidget.lua:345-375); its buffer is filled with bgcolor, white by
-- default (textboxwidget.lua:50, :861-864), hence the paper.
local function ink_text(text, face, width, ink, paper, name)
    return TextBoxWidget:new{
        name = name,
        text = text,
        face = face,
        width = width,
        fgcolor = ink,
        bgcolor = paper,
    }
end

-- One chip: a square of the role's colour outlined in ink, then "role #hex".
local function chip(role, hex, width, ink, paper, face)
    local size = scaled(CHIP)
    local gap = scaled(GAP)
    return HorizontalGroup:new{
        ColorBox:new{
            name = "kopanda_swatch_chip",
            role = role,
            dimen = Geom:new{ w = size, h = size },
            color = drawn(hex),
            border = scaled(CHIP_BORDER),
            border_color = ink,
        },
        HorizontalSpan:new{ width = gap },
        ink_text(role .. " " .. hex, face, width - size - gap, ink, paper),
    }
end

-- The panel of look id's variant palette, w by h.
local function panel(id, variant, w, h)
    local look = Looks.get(id)
    local palette = look.palettes[variant]
    local paper, ink = drawn(palette.paper), drawn(palette.ink)
    local inset = scaled(PADDING)
    local gap = scaled(GAP)
    local content_w = w - 2 * inset
    local label_face = face_or_fallback(look.faces.text.file, LABEL_SIZE)
    local header_face = face_or_fallback(look.faces.text.file, HEADER_SIZE)
    local content = VerticalGroup:new{ align = "left" }
    local name = id:gsub("^%l", string.upper)
    content[#content + 1] = ink_text(name .. " · " .. variant, header_face, content_w, ink, paper)
    content[#content + 1] = VerticalSpan:new{ width = gap }

    -- The chips in two columns, in role order down the first and then the second.
    local roles = {}
    for _, role in ipairs(sorted_keys(palette)) do
        if palette[role] then
            roles[#roles + 1] = role
        end
    end
    local column_w = math.floor((content_w - gap) / 2)
    local rows = math.ceil(#roles / 2)
    local columns = HorizontalGroup:new{ align = "top" }
    for c = 1, 2 do
        local column = VerticalGroup:new{ align = "left" }
        for r = 1, rows do
            local role = roles[(c - 1) * rows + r]
            if role then
                if r > 1 then
                    column[#column + 1] = VerticalSpan:new{ width = gap }
                end
                column[#column + 1] = chip(role, palette[role], column_w, ink, paper, label_face)
            end
        end
        if c > 1 then
            columns[#columns + 1] = HorizontalSpan:new{ width = gap }
        end
        columns[#columns + 1] = column
    end
    content[#content + 1] = columns

    content[#content + 1] = VerticalSpan:new{ width = gap * 2 }
    for _, role in ipairs(sorted_keys(look.faces)) do
        local face = look.faces[role]
        if face.file then
            local loaded_face, loaded = face_or_fallback(face.file, FACE_SIZE)
            local text = face.label .. " · " .. role
            if not loaded then
                text = text .. " (did not load)"
            end
            content[#content + 1] = ink_text(text, loaded_face, content_w, ink, paper, "kopanda_swatch_face")
        end
    end

    return ColorBox:new{
        name = "kopanda_swatch_panel",
        look = id,
        variant = variant,
        dimen = Geom:new{ w = w, h = h },
        color = paper,
        inset = inset,
        content,
    }
end

-- Every registered icon in ink with its id beneath, in rows as wide as width, wrapping as the
-- widest id needs.
local function icon_rows(width)
    local gap = scaled(GAP)
    local size = scaled(ICON)
    local face = Font:getFace("cfont", ICON_LABEL_SIZE)
    local labels = {}
    local widest = size
    for i, entry in ipairs(Icons.entries) do
        labels[i] = TextWidget:new{ text = entry.id, face = face }
        widest = math.max(widest, labels[i]:getSize().w)
    end
    local per_row = math.max(1, math.floor(width / (widest + gap)))
    local cell_w = math.floor(width / per_row)
    local rows = VerticalGroup:new{ align = "left" }
    local row
    for i, entry in ipairs(Icons.entries) do
        local cell = VerticalGroup:new{
            name = "kopanda_swatch_icon",
            icon_id = entry.id,
            -- alpha keeps the transparent ground; without it an icon is flattened onto white
            -- (frontend/ui/widget/imagewidget.lua:202-226).
            IconWidget:new{ file = Icons.path(entry.id), width = size, height = size, alpha = true },
            VerticalSpan:new{ width = gap },
            labels[i],
        }
        if not row then
            row = HorizontalGroup:new{ align = "top" }
            rows[#rows + 1] = row
        end
        row[#row + 1] = CenterContainer:new{
            dimen = Geom:new{ w = cell_w, h = cell:getSize().h },
            cell,
        }
        if #row == per_row then
            row = nil
            if i < #Icons.entries then
                rows[#rows + 1] = VerticalSpan:new{ width = gap }
            end
        end
    end
    return rows
end

local FULL_SCREEN = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 }

local Swatch = InputContainer:extend{
    name = "kopanda_swatch",
    -- UIManager:_repaint skips paintTo beneath the topmost such widget.
    covers_fullscreen = true,
}

function Swatch:init()
    self.dimen = Screen:getSize()
    -- A touch zone rather than an onGesture test, so KOReader's touch lock filters it.
    self:registerTouchZones({
        {
            id = "kopanda_swatch_tap",
            ges = "tap",
            screen_zone = FULL_SCREEN,
            handler = function()
                self:close()
                return true
            end,
        },
    })
    local margin = scaled(MARGIN)
    local gap = scaled(GAP)
    local inner_w = self.dimen.w - 2 * margin
    local header = VerticalGroup:new{
        align = "left",
        TextWidget:new{ text = TITLE, face = Font:getFace("cfont", TITLE_SIZE) },
        VerticalSpan:new{ width = gap },
    }
    -- G_reader_settings' night_mode is KOReader's own toggle (frontend/device/devicelistener.lua:14-27).
    if G_reader_settings:isTrue("night_mode") then
        header[#header + 1] = TextBoxWidget:new{
            text = NIGHT_NOTE,
            face = Font:getFace("cfont", NOTE_SIZE),
            width = inner_w,
        }
        header[#header + 1] = VerticalSpan:new{ width = gap }
    end
    local icons = icon_rows(inner_w)
    -- The panels take what the header and the icons leave; getSize fixes a group's layout, so
    -- each is measured once complete (frontend/ui/widget/verticalgroup.lua:15-31).
    local used = header:getSize().h + gap + icons:getSize().h
    local column = VerticalGroup:new{ align = "left", header }
    local panel_h = math.floor((self.dimen.h - 2 * margin - used - 2 * gap) / #VARIANTS)
    local panel_w = math.floor((inner_w - gap) / 2)
    local ids = Looks.ids()
    for v, variant in ipairs(VARIANTS) do
        column[#column + 1] = HorizontalGroup:new{
            align = "top",
            panel(ids[1], variant, panel_w, panel_h),
            HorizontalSpan:new{ width = gap },
            panel(ids[2], variant, panel_w, panel_h),
        }
        if v < #VARIANTS then
            column[#column + 1] = VerticalSpan:new{ width = gap }
        end
    end
    column[#column + 1] = VerticalSpan:new{ width = gap }
    column[#column + 1] = icons
    self[1] = FrameContainer:new{
        width = self.dimen.w,
        height = self.dimen.h,
        bordersize = 0,
        padding = margin,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        column,
    }
end

local function close_swatch(swatch)
    local ok, err = pcall(UIManager.close, UIManager, swatch, "full")
    if not ok then
        logger.err("KoPanda: could not close the swatch screen:", err)
    end
end

function Swatch:close()
    close_swatch(self)
end

-- The dev loop's settled signal after the first paint, unless that paint failed.
local function settle(swatch)
    if swatch.paint_failed then
        return
    end
    local ok, err = pcall(function()
        local now = time.monotonic()
        UIManager.event_hook:execute("KoPandaSettled", {
            screen = "swatch",
            paint_ms = time.to_ms((swatch.painted_at or now) - swatch.started),
        })
    end)
    if not ok then
        logger.err("KoPanda: the swatch settled signal failed:", err)
    end
end

-- Shows the swatch screen over whatever is on top. On any error it is taken off the stack and
-- what was beneath is left as it was.
function Swatch.show()
    local swatch
    local ok, err = pcall(function()
        swatch = Swatch:new{ started = time.monotonic() }
        UIManager:show(swatch, "full")
        -- Lands past the next repaint, so the signal follows the paint.
        UIManager:tickAfterNext(function()
            settle(swatch)
        end)
    end)
    if not ok then
        logger.err("KoPanda: could not show the swatch screen:", err)
        if swatch and UIManager:isWidgetShown(swatch) then
            close_swatch(swatch)
        end
    end
end

-- A widget can't be closed from inside the repaint, so a failed paint closes the swatch from
-- the next tick.
function Swatch:paintTo(bb, x, y)
    local ok, err = pcall(InputContainer.paintTo, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = time.monotonic()
    end
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the swatch screen failed to paint:", err)
        UIManager:nextTick(function()
            close_swatch(self)
        end)
    end
end

-- Not a plugin handler, so KOReader does not sandbox it: a failure closes the swatch and
-- consumes the gesture.
function Swatch:onGesture(ges)
    local ok, consumed = pcall(InputContainer.onGesture, self, ges)
    if ok then
        return consumed
    end
    logger.err("KoPanda: the swatch screen failed to handle a gesture:", consumed)
    close_swatch(self)
    return true
end

return Swatch
