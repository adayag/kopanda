-- The library search's match over book records (books.lua): every word of the query a plain,
-- case-insensitive substring of the title, an author, the series or the file name, the matches in
-- the library's title order. Pure, nothing kept; a field of the wrong type is skipped for that field.
local LibraryOrder = require("library_order")

local BookSearch = {}

-- The query's whitespace-separated words, lowered (ASCII only); none for a blank or non-string query.
function BookSearch.words(query)
    local words = {}
    if type(query) ~= "string" then
        return words
    end
    for word in query:lower():gmatch("%S+") do
        words[#words + 1] = word
    end
    return words
end

-- The record's searchable texts, lowered.
local function fields_of(record)
    local fields = {}
    local function add(value)
        if type(value) == "string" then
            fields[#fields + 1] = value:lower()
        end
    end
    add(record.title)
    if type(record.authors) == "table" then
        for _, author in ipairs(record.authors) do
            add(author)
        end
    end
    add(record.series)
    if type(record.path) == "string" then
        add(record.path:match("[^/]*$"))
    end
    return fields
end

local function has_all(fields, words)
    for _, word in ipairs(words) do
        local found = false
        for _, field in ipairs(fields) do
            if field:find(word, 1, true) then
                found = true
                break
            end
        end
        if not found then
            return false
        end
    end
    return true
end

function BookSearch.match(records, query)
    local words = BookSearch.words(query)
    local entries = {}
    for _, record in ipairs(records) do
        if has_all(fields_of(record), words) then
            local title = record.title
            entries[#entries + 1] = {
                record = record,
                title_key = type(title) == "string" and LibraryOrder.title_key(title) or nil,
            }
        end
    end
    table.sort(entries, LibraryOrder.by_title)
    local matches = {}
    for i, entry in ipairs(entries) do
        matches[i] = entry.record
    end
    return matches
end

return BookSearch
