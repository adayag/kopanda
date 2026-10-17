-- Helpers shared by the Series window's specs (spec/unit/series_screen_spec.lua,
-- shelf_gestures_spec.lua, shelf_lifecycle_spec.lua and the series cases of failsafe_spec.lua and
-- nav_bar_spec.lua): records given to Books.all in place of the disk, under a root that exists
-- nowhere, and the window shown over a file manager. Each reads the plugin's modules at call time,
-- so it sees the ones the spec's harness.load() left loaded.
-- Busted gives a spec file its assert; a module required from one takes luassert, the same table.
local assert = require("luassert")
local harness = require("plugin_harness")

local M = {}

M.ROOT = "/kopanda-spec/shelf"

local function slug(title)
    return (title:lower():gsub("[^%w]+", "-"))
end

-- A book with a file, titled title, with fields (series, series_index, authors, ...) over the
-- defaults.
function M.book(title, fields)
    local path = M.ROOT .. "/" .. slug(title) .. ".epub"
    local record = { id = "file:" .. path, path = path, title = title, authors = {} }
    for k, v in pairs(fields or {}) do
        record[k] = v
    end
    return record
end

-- A path-less book, as a source registers one.
function M.remote(title, fields)
    local record = M.book(title, fields)
    record.id, record.path, record.source = "shelf:" .. slug(title), nil, "shelf"
    return record
end

-- n books of the series name by author (default "Ann Author"), titled "<name> 1" to "<name> n"
-- and indexed 1 to n.
function M.series(name, n, author)
    local list = {}
    for i = 1, n do
        list[i] = M.book(name .. " " .. i, { series = name, series_index = i, authors = { author or "Ann Author" } })
    end
    return list
end

-- Books.all gives a copy of records, read at each call so a spec can add to it; Books.progress
-- progress[id] (default: new); Books.get the record of records with id, or nil. Returns the calls:
-- all, the count of Books.all's, and progress, the ids Books.progress was asked for. Undone by the
-- next harness.load().
function M.install(records, progress)
    local Books = package.loaded["books"]
    local calls = { all = 0, progress = {} }
    Books.all = function()
        calls.all = calls.all + 1
        local copy = {}
        for i, record in ipairs(records) do
            copy[i] = record
        end
        return copy
    end
    Books.progress = function(record)
        calls.progress[#calls.progress + 1] = record.id
        return (progress or {})[record.id] or { status = "new" }
    end
    Books.get = function(id)
        for _, record in ipairs(records) do
            if record.id == id then
                return record
            end
        end
        return nil
    end
    return calls
end

-- A file manager with the home closed and the Series window shown at view (default: the list) and
-- page, painted and settled.
function M.show(view, page)
    local fm = harness.show_fm()
    harness.tick(2)
    require("home").close()
    local screen = require("series_screen").show{ view = view, page = page }
    assert.is_not_nil(screen)
    harness.tick(2)
    assert.equals(screen, harness.top())
    return screen, fm
end

-- The series names of the window's rows on its page, or the titles of its book rows.
function M.names(screen)
    local out = {}
    for i, row in ipairs(screen.rows) do
        out[i] = row.entry and row.entry.name or row.record.title
    end
    return out
end

return M
