-- Test fixture for the capture driver. On the file manager's first Show it paints a
-- deterministic full-screen widget (the screen size as text, a square in each corner) and,
-- once that paint has happened, signals "KoPandaSettled" on UIManager.event_hook with the
-- milliseconds the paint took. Fixed strings and sizes only, so captures compare equal.
--
-- The widget's first paintTo queues the signal with nextTick. paintTo runs inside
-- UIManager:_repaint, and tasks run only from the next _checkTasks pass, after that repaint
-- (frontend/ui/uimanager.lua:1542-1564), so the shot always follows the paint. Counting ticks
-- from the show instead (tickAfterNext) lets the signal run before the first repaint whenever
-- time.now() has not advanced within a task pass (uimanager.lua:1082, :1088-1097).
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = require("device").screen
local time = require("ui/time")

local SQUARE = 40
local MARGIN = 20
local FONT_SIZE = 48

local Probe = WidgetContainer:extend{
    name = "probe",
    is_doc_only = false,
    settled = false,
}

-- The full-screen widget: a FrameContainer that calls on_first_paint once, after its first paint.
local ProbeScreen = FrameContainer:extend{
    painted = false,
}

function ProbeScreen:paintTo(bb, x, y)
    FrameContainer.paintTo(self, bb, x, y)
    if not self.painted then
        self.painted = true
        self.on_first_paint()
    end
end

local function square(x, y)
    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_BLACK,
        overlap_offset = { x, y },
        WidgetContainer:new{ dimen = Geom:new{ w = SQUARE, h = SQUARE } },
    }
end

local function build_screen(width, height, on_first_paint)
    local far_x = width - MARGIN - SQUARE
    local far_y = height - MARGIN - SQUARE
    return ProbeScreen:new{
        on_first_paint = on_first_paint,
        covers_fullscreen = true,
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        OverlapGroup:new{
            dimen = Geom:new{ w = width, h = height },
            allow_mirroring = false,
            CenterContainer:new{
                dimen = Geom:new{ w = width, h = height },
                TextWidget:new{
                    text = width .. "\u{00D7}" .. height,
                    face = Font:getFace("cfont", FONT_SIZE),
                },
            },
            square(MARGIN, MARGIN),
            square(far_x, MARGIN),
            square(MARGIN, far_y),
            square(far_x, far_y),
        },
    }
end

local function signal(paint_ms)
    UIManager.event_hook:execute("KoPandaSettled", { screen = "home", paint_ms = paint_ms })
end

-- Fires when FileManager:showFiles shows the file manager (the Show event reaches every
-- array child, the plugin instances among them). Returns nothing so the event goes on.
function Probe:onShow()
    if self.settled then
        return
    end
    self.settled = true
    local started = time.monotonic()
    UIManager:show(build_screen(Screen:getWidth(), Screen:getHeight(), function()
        UIManager:nextTick(function()
            pcall(signal, time.to_ms(time.monotonic() - started))
        end)
    end))
end

return Probe
