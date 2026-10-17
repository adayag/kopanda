-- The library's sort and status pickers (cover-grid "The pickers", D8, D9, D11): a tap on a picker
-- in the library's header shows its sheet over the library (SortC.dc.html), "for this folder"
-- above the heading and "Library" at its right, a row for each choice with its second line, the
-- folder's current one selected. A tap on a row stores that choice for the folder (the one already
-- chosen stores nothing new), and the sheet, closed by the tap, leaves the folder's first page
-- under the new choice. A sheet's failure closes the library, its screen beneath. Loading this
-- module fills Library.on_picker.
local Library = require("library")
local LibraryOrder = require("library_order")
local Sheet = require("sheet")

local LibraryPickers = {}

-- Each picker's heading and its rows, { value, label, sublabel } (SortC.dc.html:40-69; the
-- feature's status rows).
local PICKERS = {
    sort = {
        heading = "Sort",
        rows = {
            { "recent", "Recent", "Last opened first" },
            { "title", "Title", "A to Z, ignoring “The” and “A”" },
            { "author", "Author", "By surname" },
            { "series", "Series", "Series together, in series order" },
        },
    },
    status = {
        heading = "Show",
        rows = {
            { "reading", "Reading", "Books under way" },
            { "finished", "Finished", "Read to the end" },
            { "all", "All", "Every book in this folder" },
        },
    },
}

-- Shows the kind ("sort" or "status") picker's sheet over library at its folder.
local function show(kind, library)
    local picker = PICKERS[kind]
    local dir = library.dir
    local current = LibraryOrder.choice(dir)[kind]
    local rows = {}
    for i, entry in ipairs(picker.rows) do
        local value = entry[1]
        local selected = value == current
        rows[i] = {
            label = entry[2],
            sublabel = entry[3],
            selected = selected,
            run = function()
                if not selected then
                    LibraryOrder.choose(dir, kind == "sort" and value or nil, kind == "status" and value or nil)
                end
                library:go(dir, 1)
            end,
        }
    end
    Sheet.show({
        name = kind,
        band = "home",
        header = { heading = picker.heading, aside = "for this folder", aside_above = true, label = "Library" },
        rows = rows,
        flush = true,
    }, library.ctx, { beneath = Library })
end

-- The sort sheet over library.
function LibraryPickers.sort(library)
    show("sort", library)
end

-- The status sheet over library.
function LibraryPickers.status(library)
    show("status", library)
end

-- The library's tap on a picker shows that picker's sheet over the library shown.
function Library.on_picker(kind)
    local library = Library.shown
    if library and LibraryPickers[kind] then
        LibraryPickers[kind](library)
    end
end

return LibraryPickers
