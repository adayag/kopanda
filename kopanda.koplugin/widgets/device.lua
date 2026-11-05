-- The device's own readings in an insight tile, read at each build: the storage free and the memory KOReader uses, each
-- value over its caption in equal columns, from DeviceStats. A reading the device can't give drops out and the rest
-- fill the row.
local DeviceStats = require("device_stats")
local InsightTile = require("insight_tile")
local Paint = require("paint")
local Typeset = require("typeset")
local util = require("util")

local LABEL = "Device"

local Device = {
    id = "device",
}

function Device.readings()
    return {
        storage = DeviceStats.storage(),
        memory = DeviceStats.memory(),
    }
end

-- The { value, caption } cells in reading order for readings (Device.readings's shape), each nil reading left out.
function Device.cells(readings)
    local cells = {}
    if readings.storage then
        cells[#cells + 1] = { value = util.getFriendlySize(readings.storage), caption = "storage free" }
    end
    if readings.memory then
        cells[#cells + 1] = { value = util.getFriendlySize(readings.memory), caption = "KOReader memory" }
    end
    return cells
end

local function compose(width, ctx)
    local texts = Device.cells(Device.readings())
    if #texts == 0 then
        return InsightTile.compose(width, ctx, LABEL, "Nothing to report", 0, function() end)
    end
    local look = ctx.look
    local scale = Paint.scaler(ctx)
    local caption_part = look.type.insight_caption
    local column_gap, value_gap = scale(look.home.column_gap), scale(look.insights.value_gap)
    local column_w = math.floor((InsightTile.inner_width(width, ctx) - (#texts - 1) * column_gap) / #texts)

    local values = {}
    for i, text in ipairs(texts) do
        values[i] = text.value
    end
    local lines, value_part = Typeset.fitted(look.type.insight_value, values, column_w, ctx)
    local value_h = Typeset.line_height(value_part, ctx)
    local cells = {}
    for i, text in ipairs(texts) do
        cells[i] = {
            value = lines[i],
            caption = Typeset.line(caption_part, text.caption, column_w, ctx),
            x = (i - 1) * (column_w + column_gap),
        }
    end

    local function paint(bb, x, y)
        for _, cell in ipairs(cells) do
            cell.value:paintTo(bb, x + cell.x, y)
            cell.caption:paintTo(bb, x + cell.x, y + value_h + value_gap)
        end
    end

    local content_h = value_h + value_gap + Typeset.line_height(caption_part, ctx)
    local tile = InsightTile.compose(width, ctx, LABEL, "when you opened Stats", content_h, paint)
    tile.cells, tile.value_size = cells, value_part.size
    local free_tile = tile.free
    function tile:free()
        for _, cell in ipairs(self.cells) do
            cell.value:free()
            cell.caption:free()
        end
        self.cells = {}
        free_tile(self)
    end
    return tile
end

Device.height, Device.build = Typeset.measured(compose)

return Device
