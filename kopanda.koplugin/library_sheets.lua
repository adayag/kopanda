-- The hold's dispatch on the library's windows (context-menu "Holds"): the chrome's hold step
-- (library_chrome.lua) hands it the window held on and what lies under the hold, the window's
-- hit(x, y), and it opens that thing's sheet over the window. A book, on the library and on the
-- one-series and one-author screens, opens the book sheet (D3, D13); every other kind opens
-- nothing.
local BookSheet = require("book_sheet")
local logger = require("logger")

local LibrarySheets = {}

-- The sheet each hit kind opens, as open(window, hit, opts).
local SHEETS = {
    book = function(window, hit, opts)
        BookSheet.open_record(hit.record, window, window.ctx, opts)
    end,
}

-- Opens the sheet of hit ({ kind, ... } from the window's hit, or nil) over window, with window as
-- its screen beneath, so a sheet's failure closes that window and not the home, and its paint_ms
-- from started (a PaintClock stamp the hold took). A kind with no sheet, or no hit, opens nothing.
-- A sheet that raises before it shows is logged, the window left as it was.
function LibrarySheets.hold(window, hit, started)
    local open = hit and SHEETS[hit.kind]
    if not open then
        return
    end
    local ok, err = pcall(open, window, hit, { started = started, beneath = window })
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s " .. hit.kind .. " sheet failed:", err)
    end
end

return LibrarySheets
