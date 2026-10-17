-- Helpers shared by the library window's specs (spec/unit/library_screen_spec.lua,
-- library_gestures_spec.lua, library_lifecycle_spec.lua and the library cases of failsafe_spec.lua):
-- listings given to Books.folder in place of the disk, under a library root that exists nowhere,
-- and the library shown over a file manager. Each reads the plugin's modules at call time, so it
-- sees the ones the spec's harness.load() left loaded.
-- Busted gives a spec file its assert; a module required from one takes luassert, the same table.
local assert = require("luassert")
local harness = require("plugin_harness")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextWidget = require("ui/widget/textwidget")

local M = {}

M.ROOT = "/kopanda-spec/library"

-- A book with a file in dir (default: the root), titled title.
function M.book(title, dir)
    local path = (dir or M.ROOT) .. "/" .. title:lower():gsub("[^%w]+", "-") .. ".epub"
    return { id = "file:" .. path, path = path, title = title, authors = {} }
end

-- A path-less book, as a source registers one.
function M.remote(title)
    return { id = "shelf:" .. title:lower():gsub("[^%w]+", "-"), title = title, authors = {}, source = "shelf" }
end

-- A sub-folder name of dir (default: the root).
function M.folder(name, dir)
    return { name = name, path = (dir or M.ROOT) .. "/" .. name }
end

-- Books.folder gives listings[dir] (default: nothing), Books.files that listing's books, and
-- Books.progress progress[id] (default: new), each a copy so the library can't change the spec's
-- tables; the root is KOReader's home folder. Returns the calls Books.folder had, by dir. Undone by
-- the next harness.load() and M.restore().
function M.install(listings, progress)
    local Books = package.loaded["books"]
    local calls = {}
    Books.folder = function(dir)
        calls[#calls + 1] = dir
        local listing = listings[dir] or {}
        local books, folders = {}, {}
        for i, book in ipairs(listing.books or {}) do
            books[i] = book
        end
        for i, folder in ipairs(listing.folders or {}) do
            folders[i] = folder
        end
        return { books = books, folders = folders }
    end
    Books.files = function(dir)
        local books = {}
        for i, book in ipairs((listings[dir] or {}).books or {}) do
            books[i] = book
        end
        return books
    end
    Books.progress = function(book)
        return (progress or {})[book.id] or { status = "new" }
    end
    G_reader_settings:saveSetting("home_dir", M.ROOT)
    return calls
end

function M.restore()
    G_reader_settings:delSetting("home_dir")
end

-- n books titled "Book 01" to "Book n" in dir (default: the root), which the title order keeps
-- in that order.
function M.books(n, dir)
    local list = {}
    for i = 1, n do
        list[i] = M.book(("Book %02d"):format(i), dir)
    end
    return list
end

-- A file manager with the home closed and the library shown at dir and page, painted and settled.
function M.show(dir, page)
    local fm = harness.show_fm()
    harness.tick(2)
    require("home").close()
    local library = require("library").show{ dir = dir or M.ROOT, page = page }
    assert.is_not_nil(library)
    harness.tick(2)
    assert.equals(library, harness.top())
    return library, fm
end

-- Every line of text in widget, top first by tree order: a text widget's text, or a tracked
-- line's characters joined.
function M.texts(widget)
    local out = {}
    local function line_of(node)
        if type(node.text) == "string" then
            return node.text
        end
        local chars = {}
        for _, child in ipairs(node) do
            if getmetatable(child) == TextWidget then
                chars[#chars + 1] = child.text
            elseif getmetatable(child) ~= HorizontalSpan then
                return nil
            end
        end
        return #chars > 0 and table.concat(chars) or nil
    end
    local function walk(node)
        local line = line_of(node)
        if line then
            out[#out + 1] = line
            return
        end
        for _, child in ipairs(node) do
            walk(child)
        end
    end
    walk(widget)
    return out
end

-- The one line of text in widget, or nil.
function M.text(widget)
    local lines = widget and M.texts(widget) or {}
    return lines[1]
end

-- The centre of rect, a point a gesture can be made at.
function M.centre(rect)
    return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
end

return M
