-- The two clocks a settled signal's times run on. A stamp is { wall, cpu }: wall is
-- time.monotonic()'s fts time, from which paint_ms has always run; cpu is os.clock()'s seconds of
-- the process's CPU time, C clock(), which a loaded host doesn't stretch as it does wall time.
-- KOReader's ui/time reads only the system's wall clocks (frontend/ui/time.lua:234-300), so the
-- CPU clock is Lua's own. A span, from one stamp to a later one, has the same shape.
local time = require("ui/time")

local PaintClock = {}

-- Now, on both clocks.
function PaintClock.now()
    return { wall = time.monotonic(), cpu = os.clock() }
end

-- The span from stamp from to stamp to (default: now).
function PaintClock.since(from, to)
    to = to or PaintClock.now()
    return { wall = to.wall - from.wall, cpu = to.cpu - from.cpu }
end

-- Two spans' sum, as the file browser's layout and its later paint.
function PaintClock.plus(a, b)
    return { wall = a.wall + b.wall, cpu = a.cpu + b.cpu }
end

-- span's wall time and CPU time in whole milliseconds: a settled signal's paint_ms and cpu_ms.
function PaintClock.ms(span)
    return time.to_ms(span.wall), math.floor(span.cpu * 1000 + 0.5)
end

return PaintClock
