-- Writes spec/fixtures/wallpaper.png, the wallpaper the Frosted specs and smoke renders draw: a busy,
-- saturated 400 × 530 image (it is scaled to cover the screen), bands of colour crossed by
-- near-black diagonals, under overlapping discs in saturated colours, near-black and near-white.
-- Deterministic: the same bytes every run. Run from the emulator's koreader directory, so
-- KOReader's BlitBuffer loads:
--
--   cd "$KOPANDA_EMULATOR" && ./luajit -e 'require("setupkoenv")' \
--       <repo>/spec/fixtures/wallpaper_png.lua <repo>/spec/fixtures/wallpaper.png
local Blitbuffer = require("ffi/blitbuffer")

local W, H = 400, 530
local out = assert(arg[1], "usage: wallpaper_png.lua <out.png>")

local function rgb(hex)
    return Blitbuffer.ColorRGB32(tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16),
        tonumber(hex:sub(6, 7), 16), 0xFF)
end

local BANDS = { "#e0263a", "#f28c1c", "#f5d10a", "#2fa84f", "#12a5a5", "#2457d6", "#7b2fbf", "#d62f9a" }
local DISCS = { "#e0263a", "#f28c1c", "#f5d10a", "#2fa84f", "#12a5a5", "#2457d6", "#7b2fbf", "#d62f9a",
    "#f7f5f0", "#121016" }

local bb = Blitbuffer.new(W, H, Blitbuffer.TYPE_BBRGB32)

-- Bands of colour, 38 px each.
for i = 0, math.ceil(H / 38) - 1 do
    bb:paintRectRGB32(0, i * 38, W, 38, rgb(BANDS[i % #BANDS + 1]))
end

-- Near-black diagonals, 22 px wide, every 120 px.
local black = rgb("#141018")
for y = 0, H - 1 do
    for start = -H, W, 120 do
        local x = start + y
        bb:paintRectRGB32(math.max(0, x), y, math.max(0, math.min(W, x + 22) - math.max(0, x)), 1, black)
    end
end

-- Overlapping discs from a fixed linear congruential sequence.
local seed = 20261019
local function next_int(n)
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed % n
end
for i = 1, 18 do
    local cx, cy, r = next_int(W), next_int(H), 30 + next_int(70)
    local color = rgb(DISCS[(i - 1) % #DISCS + 1])
    for dy = -r, r do
        local half = math.floor(math.sqrt(r * r - dy * dy))
        local y = cy + dy
        if y >= 0 and y < H then
            local x0, x1 = math.max(0, cx - half), math.min(W, cx + half)
            if x1 > x0 then
                bb:paintRectRGB32(x0, y, x1 - x0, 1, color)
            end
        end
    end
end

assert(bb:writePNG(out), "could not write " .. out)
bb:free()
print(out)
