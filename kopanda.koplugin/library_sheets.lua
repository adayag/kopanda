-- The hold's dispatch on the library's windows (context-menu "Holds"): the chrome's hold step
-- (library_chrome.lua) hands it the window held on and what lies under the hold, the window's
-- hit(x, y), and it opens that thing's sheet over the window. A book, on the library and on the
-- one-series and one-author screens, opens the book sheet (D3, D13); a folder tile, on the
-- library alone, the folder sheet ("The folder sheet"); every other kind opens nothing.
local BookSheet = require("book_sheet")
local FeaturedCover = require("featured_cover")
local Geom = require("ui/geometry")
local Icons = require("icons")
local LibraryOrder = require("library_order")
local LibraryTiles = require("library_tiles")
local Looks = require("looks")
local Sheet = require("sheet")
local TintedIcon = require("tinted_icon")
local logger = require("logger")

local LibrarySheets = {}

local JOIN = " · "

-- The folder sheet's header cover under ctx (HoldFolderC.dc.html:36-37): a sheet.folder_box box
-- in its fill and outline with the registry's folder icon centred, tinted in its icon colour, as
-- the folder tile tints its own, since the registry's files are inked black (icons.lua) and night's
-- paper would hide them. The sheet frees it.
local function folder_box(ctx)
    local tokens = ctx.look.sheet.folder_box
    local palette = Looks.palette(ctx.look, ctx.variant)
    local function color(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
    local function scale(px)
        return ctx.screen:scaleBySize(px)
    end
    local size = scale(tokens.size)
    local outline_color = color(tokens.outline_color)
    local box = FeaturedCover.Box:new{
        dimen = Geom:new{ w = size, h = size },
        box_w = size,
        box_h = size,
        fill_color = color(tokens.fill_color),
        outline = outline_color and scale(tokens.outline_width) or 0,
        outline_color = outline_color,
        places = {},
    }
    local icon = TintedIcon:new{ file = Icons.path("folder"), size = scale(tokens.icon_size),
        color = color(tokens.icon_color) }
    local at = math.floor((size - icon.size) / 2)
    box[1] = icon
    box.places[1] = { x = at, y = at }
    return box
end

-- The folder sheet's meta (D12, HoldFolderC.dc.html:41): the book count as the tile words it,
-- then the reading and finished counts, each only when not zero.
local function folder_meta(counts)
    local parts = { LibraryTiles.books_text(counts.books or 0) }
    if (counts.reading or 0) > 0 then
        parts[#parts + 1] = counts.reading .. " reading"
    end
    if (counts.finished or 0) > 0 then
        parts[#parts + 1] = counts.finished .. " finished"
    end
    return table.concat(parts, JOIN)
end

-- A row's run, its failure logged with the window as it was (C8): the sheet's own tap would
-- otherwise close the window beneath.
local function guarded(what, fn)
    return function()
        local ok, err = pcall(fn)
        if not ok then
            logger.err("KoPanda: the library's folder sheet could not " .. what .. ":", err)
        end
    end
end

-- Shows the sheet of folder ({ name, path }, a tile's) held on window, the library, with counts
-- ({ books, reading, finished }, the tile's) and opts passed on to Sheet.show (its beneath the
-- library): Open, the folder at its remembered page, as a tap on its tile; Set as library root,
-- KOReader's own confirm (FileManager:setHome, D6), whose OK the library's root check follows on
-- its next paint; Hide, the folder stored as hidden (D1) and the library re-listed at its page.
function LibrarySheets.folder(window, folder, counts, opts)
    local rows = {
        {
            icon = "folder_open",
            label = "Open",
            run = guarded("open the folder", function()
                window:open_folder(folder)
            end),
        },
        {
            icon = "library",
            label = "Set as library root",
            sublabel = "The Library tab opens here",
            run = guarded("set the library root", function()
                local FileManager = package.loaded["apps/filemanager/filemanager"]
                local fm = FileManager and FileManager.instance
                if not fm then
                    logger.warn("KoPanda: no file manager to set the library root from")
                    return
                end
                fm:setHome(folder.path)
            end),
        },
        {
            icon = "eye_off",
            label = "Hide",
            sublabel = "Still on the Kindle, gone from the grid",
            run = guarded("hide the folder", function()
                LibraryOrder.hide(folder.path)
                window:refresh()
            end),
        },
    }
    local ctx = window.ctx
    local header = { title = folder.name, meta = folder_meta(counts or {}) }
    -- The cover last, so nothing raising after it leaves it unfreed: from here the sheet frees it.
    header.cover = folder_box(ctx)
    Sheet.show({ name = "library_folder", band = "library_folder", header = header, rows = rows }, ctx, opts)
end

-- The counts window's tile for folder was built with, or nil.
local function tile_counts(window, folder)
    for _, tile in ipairs(window.tiles or {}) do
        if tile.folder == folder then
            return tile.counts
        end
    end
end

-- The sheet each hit kind opens on every window, as open(window, hit, opts).
local SHEETS = {
    book = function(window, hit, opts)
        BookSheet.open_record(hit.record, window, window.ctx, opts)
    end,
}

-- The sheets only the library's own holds open (D3: on the Series and Authors windows only a
-- book's opens).
local LIBRARY_SHEETS = {
    folder = function(window, hit, opts)
        LibrarySheets.folder(window, hit.folder, tile_counts(window, hit.folder), opts)
    end,
}

local function sheet_for(window, kind)
    return SHEETS[kind] or window.screen == "library" and LIBRARY_SHEETS[kind] or nil
end

-- Opens the sheet of hit ({ kind, ... } from the window's hit, or nil) over window, with window as
-- its screen beneath, so a sheet's failure closes that window and not the home, and its paint_ms
-- from started (a PaintClock stamp the hold took). A kind with no sheet on that window, or no hit,
-- opens nothing. A sheet that raises before it shows is logged, the window left as it was.
function LibrarySheets.hold(window, hit, started)
    local open = hit and sheet_for(window, hit.kind)
    if not open then
        return
    end
    local ok, err = pcall(open, window, hit, { started = started, beneath = window })
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s " .. hit.kind .. " sheet failed:", err)
    end
end

return LibrarySheets
