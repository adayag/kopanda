-- The row operations edit layout applies to a value of a rows key (layout.rows or layout.rows_2,
-- schema.lua), with the labels, shares and captions its cards show. Pure: every operation deep-copies
-- the rows it is given and returns new rows, or nil and the note to show; none changes its input.
local Schema = require("schema")
local util = require("util")

local RowsEdit = {}

-- The schema entry of key, layout.rows when nil.
function RowsEdit.entry(key)
    key = key or "layout.rows"
    for _, entry in ipairs(Schema.keys) do
        if entry.id == key then
            return entry
        end
    end
end

-- The most columns a row holds, the same for both rows keys.
RowsEdit.max_columns = RowsEdit.entry().max_columns

-- A widget is on the home at most once (settings.lua's rows validator).
local ONCE = "Each widget can be on the home once."

local LABELS = {
    date = "Date",
    clock = "Clock",
    weather = "Weather",
    quote = "Quote",
    stats = "Reading stats",
    featured = "Featured book",
    launcher = "Launcher",
    heatmap = "Reading heatmap",
    calendar = "Calendar",
    forecast = "Finish by",
    hours = "Reading hours",
    records = "Sessions",
}

local COLUMNS = { "one column", "two columns", "three columns" }

local function on_home(rows, widget)
    for _, row in ipairs(rows) do
        for _, slot in ipairs(row) do
            if slot.widget == widget then
                return true
            end
        end
    end
    return false
end

-- Row i moved delta places; nil when that is past either end.
function RowsEdit.move(rows, i, delta)
    local to = i + delta
    if to < 1 or to > #rows then
        return nil
    end
    local new = util.tableDeepCopy(rows)
    table.insert(new, to, table.remove(new, i))
    return new
end

-- A new last row of widget alone.
function RowsEdit.add_row(rows, widget)
    if on_home(rows, widget) then
        return nil, ONCE
    end
    local new = util.tableDeepCopy(rows)
    new[#new + 1] = { { widget = widget, share = 1 } }
    return new
end

-- A new last column of row i, of widget at share 1; refused at the schema's max_columns.
function RowsEdit.add_column(rows, i, widget)
    if #rows[i] >= RowsEdit.max_columns then
        return nil, "A row holds at most three columns."
    end
    if on_home(rows, widget) then
        return nil, ONCE
    end
    local new = util.tableDeepCopy(rows)
    new[i][#new[i] + 1] = { widget = widget, share = 1 }
    return new
end

-- Column j of row i shows widget, at its share.
function RowsEdit.change_widget(rows, i, j, widget)
    if on_home(rows, widget) then
        return nil, ONCE
    end
    local new = util.tableDeepCopy(rows)
    new[i][j].widget = widget
    return new
end

-- Column j of row i takes share, a whole number from 1 to 3, of its row's width.
function RowsEdit.set_share(rows, i, j, share)
    if type(share) ~= "number" or share ~= math.floor(share) or share < 1 or share > 3 then
        return nil, "A column's width is 1, 2 or 3."
    end
    local new = util.tableDeepCopy(rows)
    new[i][j].share = share
    return new
end

-- Row i without column j; refused for a row's only column.
function RowsEdit.remove_column(rows, i, j)
    if #rows[i] < 2 then
        return nil, "A row keeps at least one column."
    end
    local new = util.tableDeepCopy(rows)
    table.remove(new[i], j)
    return new
end

-- The rows without row i; refused for the only row, since the home needs one.
function RowsEdit.remove_row(rows, i)
    if #rows < 2 then
        return nil, "The home needs at least one row."
    end
    local new = util.tableDeepCopy(rows)
    table.remove(new, i)
    return new
end

-- A copy of key's schema default (layout.rows when nil). The looks hold no layout of their own,
-- so it is the default in each.
function RowsEdit.reset(key)
    return util.tableDeepCopy(RowsEdit.entry(key).default)
end

-- Key's schema widgets (layout.rows when nil) not on the home, in schema order.
function RowsEdit.unused(rows, key)
    local unused = {}
    for _, widget in ipairs(RowsEdit.entry(key).widgets) do
        if not on_home(rows, widget) then
            unused[#unused + 1] = widget
        end
    end
    return unused
end

-- A widget's label, or its id for one with none.
function RowsEdit.label(id)
    return LABELS[id] or id
end

local function gcd(a, b)
    while b ~= 0 do
        a, b = b, a % b
    end
    return a
end

-- Column j's share of row: "full" alone in its row, else its share over the row's total,
-- reduced.
function RowsEdit.share_text(row, j)
    if #row == 1 then
        return "full"
    end
    local total = 0
    for _, slot in ipairs(row) do
        total = total + slot.share
    end
    local share = row[j].share
    local d = gcd(share, total)
    return (share / d) .. "/" .. (total / d)
end

-- Row i's caption: its number and its columns, then " · selected" when selected.
function RowsEdit.caption(rows, i, selected)
    local caption = "Row " .. i .. " · " .. COLUMNS[#rows[i]]
    if selected then
        caption = caption .. " · selected"
    end
    return caption
end

return RowsEdit
