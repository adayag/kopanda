-- Small helpers several modules share: the words a count of books and a duration read in, whether a
-- point lies in a rectangle, and a note over the screen.
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")

local Helpers = {}

-- "1 book", else "N books", 0 included.
function Helpers.books_text(n)
    return n == 1 and "1 book" or n .. " books"
end

-- A header's or a folder's count: "No books" for none, else books_text, and "on the shelf" after
-- it when on_shelf (a look's title_bar.count_on_shelf).
function Helpers.count_text(n, on_shelf)
    local text = n == 0 and "No books" or Helpers.books_text(n)
    if on_shelf then
        text = text .. " on the shelf"
    end
    return text
end

-- "N min" under an hour, else "H h" or "H h M min", rounded to the minute.
function Helpers.duration(seconds)
    local minutes = math.floor(seconds / 60 + 0.5)
    if minutes < 60 then
        return minutes .. " min"
    end
    local hours, rest = math.floor(minutes / 60), minutes % 60
    if rest == 0 then
        return hours .. " h"
    end
    return hours .. " h " .. rest .. " min"
end

-- Whether pos lies in rect, its right and bottom edges outside.
function Helpers.inside(rect, pos)
    return pos.x >= rect.x and pos.x < rect.x + rect.w and pos.y >= rect.y and pos.y < rect.y + rect.h
end

-- A note over the screen, closed by a tap; no timeout, so no timer
-- (frontend/ui/widget/infomessage.lua:53, :283-290).
function Helpers.note(text)
    UIManager:show(InfoMessage:new{ text = text })
end

return Helpers
