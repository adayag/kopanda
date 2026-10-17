-- The author and series index over a list of book records (books.lua). Both lists are derived
-- from the records given, on each call, so they are as current as the listing they came from;
-- nothing is kept between calls. The orders here only make the output deterministic: the
-- screens apply their own (surname order, letter dividers, series under way first).
-- A record field of the wrong type, from a source's record that passed books.lua's id and title
-- check, is skipped for that part alone, logged once per call.
local logger = require("logger")

local BookIndex = {}

local function is_name(value)
    return type(value) == "string" and value ~= ""
end

-- A number usable in a sort: not NaN, which compares false both ways.
local function is_index(value)
    return type(value) == "number" and value == value
end

local function by_name(a, b)
    local la, lb = a.name:lower(), b.name:lower()
    if la ~= lb then
        return la < lb
    end
    return a.name < b.name
end

local function by_title(a, b)
    local ta, tb = a.title:lower(), b.title:lower()
    if ta ~= tb then
        return ta < tb
    end
    return a.id < b.id
end

-- Series order: ascending index, books with no index after those with one, then by title.
local function by_series_index(a, b)
    local ia = is_index(a.series_index) and a.series_index or nil
    local ib = is_index(b.series_index) and b.series_index or nil
    if ia ~= ib then
        if ia == nil or ib == nil then
            return ib == nil
        end
        return ia < ib
    end
    return by_title(a, b)
end

-- The entries { name, books } of the groups, sorted, each one's books sorted by order.
local function entries_of(groups, order)
    local entries = {}
    for name, books in pairs(groups) do
        table.sort(books, order)
        entries[#entries + 1] = { name = name, books = books }
    end
    table.sort(entries, by_name)
    return entries
end

local function warn(what, count, first)
    if count > 0 then
        logger.warn("KoPanda: the " .. what .. " index skipped malformed fields of", count, "books, first", first)
    end
end

-- One entry { name, books } per distinct author name as written; a book is in the entry of each
-- of its authors once, so a two-author book counts for both, and a book with no authors is in
-- none. Entries by lowercase name, then name; books by lowercase title, then id.
function BookIndex.authors(records)
    local groups = {}
    local bad, first = 0, nil
    for _, record in ipairs(records) do
        local malformed = type(record.authors) ~= "table"
        local seen = {}
        for _, name in ipairs(malformed and {} or record.authors) do
            if not is_name(name) then
                malformed = true
            elseif not seen[name] then
                seen[name] = true
                groups[name] = groups[name] or {}
                table.insert(groups[name], record)
            end
        end
        if malformed then
            bad = bad + 1
            first = first or record.id
        end
    end
    warn("author", bad, first)
    return entries_of(groups, by_title)
end

-- One entry { name, books } per distinct series; books by ascending series_index, books with no
-- index after those with one, then by lowercase title, then id. Entries by lowercase name, then
-- name. A book without a series is in none.
function BookIndex.series(records)
    local groups = {}
    local bad, first = 0, nil
    for _, record in ipairs(records) do
        local series, index = record.series, record.series_index
        if (series ~= nil and not is_name(series)) or (index ~= nil and not is_index(index)) then
            bad = bad + 1
            first = first or record.id
        end
        if is_name(series) then
            groups[series] = groups[series] or {}
            table.insert(groups[series], record)
        end
    end
    warn("series", bad, first)
    return entries_of(groups, by_series_index)
end

-- The particles kept with the last word of a name (library direction doc, "Authors").
local PARTICLES = {
    de = true, du = true, da = true, di = true, del = true, della = true,
    der = true, den = true, van = true, von = true, le = true, la = true,
}

-- The surname key of an author's name, lowercased: its last word, joined with the words before
-- it while each is a particle, so "Ursula K. Le Guin" keys as "le guin" and "Plato" as "plato".
-- Words are split on runs of spaces. nil for a name with no word or one that is not a string.
function BookIndex.surname(name)
    if type(name) ~= "string" then
        return nil
    end
    local words = {}
    for word in name:lower():gmatch("[^ ]+") do
        words[#words + 1] = word
    end
    local first = #words
    if first == 0 then
        return nil
    end
    while first > 1 and PARTICLES[words[first - 1]] do
        first = first - 1
    end
    return table.concat(words, " ", first)
end

return BookIndex
