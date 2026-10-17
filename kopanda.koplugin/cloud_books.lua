-- cwngsync's placeholders (cwng-placeholders D12, D13, D19): the books cwngsync knows but the
-- Kindle doesn't hold yet, each a small EPUB at the book's real path. Read from the cwngsync plugin
-- instance the file manager registers under its name, through its own isConfigured and
-- getLibraryState, never by requiring its modules (HOOKS.md "cwngsync's placeholders"). Only reads,
-- and holds no state: each index is made from the state as it stands, so a download, a sync or a
-- reconfigure shows at the next one.
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local CloudBooks = {}

-- The cwngsync plugin instance on the file manager, or nil: with no file manager (in the reader)
-- or no cwngsync loaded.
local function plugin()
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    return fm and fm.cwngsync
end

-- The index of a state's books: each recorded placeholder's path to its recorded size
-- (cwng_library.lua:17-20, :420-426); an entry without a string path and a number size is skipped.
-- An error for a state with no books table.
local function index_of(state)
    if type(state) ~= "table" or type(state.books) ~= "table" then
        error("cwngsync's library state has no books table")
    end
    local index = {}
    for _, known in pairs(state.books) do
        if type(known) == "table" and known.kind == "placeholder" and type(known.path) == "string"
                and type(known.size) == "number" then
            index[known.path] = known.size
        end
    end
    return index
end

-- The index, nil when there is no cwngsync or it isn't configured; an error when a method is
-- missing or the state has no books table.
local function read()
    local cwngsync = plugin()
    if not cwngsync then
        return nil
    end
    if type(cwngsync.isConfigured) ~= "function" or type(cwngsync.getLibraryState) ~= "function" then
        error("cwngsync has no isConfigured or getLibraryState")
    end
    if not cwngsync:isConfigured() then
        return nil
    end
    return index_of(cwngsync:getLibraryState())
end

-- { [path] = size } of cwngsync's recorded placeholders, or nil: silently with no file manager, no
-- cwngsync on it or cwngsync not configured; logged when a method is missing, a call raises or the
-- state has no books table.
function CloudBooks.index()
    local ok, result = pcall(read)
    if not ok then
        logger.err("KoPanda: could not read cwngsync's placeholders:", result)
        return nil
    end
    return result
end

-- Whether the file at path is a placeholder by index (CloudBooks.index's, or nil): recorded there
-- by the same string, and its size still the recorded one, as cwngsync's own open tests it
-- (cwng_library_runtime.lua:999-1009).
function CloudBooks.is(index, path)
    return index ~= nil and index[path] ~= nil and lfs.attributes(path, "size") == index[path]
end

return CloudBooks
