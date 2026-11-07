-- The History and Favorites lists: a thin read of KOReader's two, ReadHistory.hist (frontend/readhistory.lua:25-35) and
-- the favorites collection (frontend/readcollection.lua:366), mapped onto KoPanda's records, and the writes to them
-- (readcollection.lua:149, :73, :188; readhistory.lua:295). Both are required at call time, so the list read is the one
-- KOReader holds now.
local Books = require("books")
local ffiutil = require("ffi/util")

local BookLists = {}

local function collection()
    local ReadCollection = require("readcollection")
    return ReadCollection, ReadCollection.default_collection_name
end

-- The history's paths, newest first, a deleted file's dim entry left out.
function BookLists.history()
    local paths = {}
    for _, entry in ipairs(require("readhistory").hist) do
        if not entry.dim then
            paths[#paths + 1] = entry.file
        end
    end
    return paths
end

-- KOReader's order, or by file name (readcollection.lua:29) under a sort set in its collection menu, whose items have
-- no order (:82-85, :137), so getOrderedCollection's sort raises (:366).
local function favorite_items(ReadCollection, name)
    if not ReadCollection.coll_settings[name].collate then
        return ReadCollection:getOrderedCollection(name)
    end
    local items = {}
    for _, item in pairs(ReadCollection.coll[name]) do
        items[#items + 1] = item
    end
    table.sort(items, function(a, b)
        return a.text < b.text
    end)
    return items
end

-- The favorites' paths, in KOReader's order when it keeps one, so its screen and this list agree.
function BookLists.favorites()
    local ReadCollection, name = collection()
    local paths = {}
    for i, item in ipairs(favorite_items(ReadCollection, name)) do
        paths[i] = item.file
    end
    return paths
end

-- The records of paths, realpaths as both lists keep them, in their order: each from library (LibraryChrome.books) by
-- id, a file's holding its realpath, or, outside it, the file's own, a path with no record dropped. History holds up
-- to 500 books (readhistory.lua:82), so a sidecar read per path at each open is what the library spares.
function BookLists.records(paths, library)
    local by_id = {}
    for _, record in ipairs(library) do
        by_id[record.id] = record
    end
    local records = {}
    for _, path in ipairs(paths) do
        records[#records + 1] = by_id["file:" .. path] or Books.for_path(path)
    end
    return records
end

function BookLists.is_favorite(file)
    local ReadCollection, name = collection()
    return ReadCollection:isFileInCollection(file, name)
end

function BookLists.add_favorite(file)
    local ReadCollection, name = collection()
    ReadCollection:addItem(file, name)
    ReadCollection:write({ [name] = true })
end

function BookLists.remove_favorite(file)
    local ReadCollection, name = collection()
    ReadCollection:removeItem(file, name)
end

-- Adds the book at file, or removes it if it is in.
function BookLists.toggle_favorite(file)
    if BookLists.is_favorite(file) then
        BookLists.remove_favorite(file)
    else
        BookLists.add_favorite(file)
    end
end

-- History holds realpaths (readhistory.lua:26).
function BookLists.remove_from_history(file)
    require("readhistory"):removeItemByPath(ffiutil.realpath(file) or file)
end

return BookLists
