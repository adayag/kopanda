-- The library captures' book folder, shared by library_capture_spec.lua, library_hold_capture_spec.lua and
-- library_placeholder_capture_spec.lua: copies of the three fixture books at its root and a sub-folder holding one
-- more copy, so spec/fixtures/library/ (counted by fixtures_spec.lua) is not changed. The library scenario patch
-- (scenarios/2-scenario-library.lua) reads it as KOPANDA_LIBRARY_DIR. Busted's assertions, which a required
-- module doesn't get as its global assert.
local assert = require("luassert")
local lfs = require("libs/libkoreader-lfs")

local M = {}

M.BOOKS = { "a-christmas-carol.epub", "frankenstein.epub", "the-time-machine.epub" }
M.FOLDER, M.FOLDER_BOOK = "Gothic", "frankenstein.epub"

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function copy(from, to)
    assert.equals(0, os.execute("cp " .. quote(from) .. " " .. quote(to)))
end

-- A fresh capture library under KO_HOME: the fixture books at its root and FOLDER holding a
-- copy of FOLDER_BOOK. A copy has its own path, so its CoverBrowser row and sidecar are its own.
-- Returns its path.
local made = 0
function M.make()
    made = made + 1
    local dir = string.format("%s/library-capture-%d", os.getenv("KO_HOME"), made)
    if lfs.attributes(dir, "mode") then
        assert.equals(0, os.execute("rm -rf " .. quote(dir)))
    end
    assert(lfs.mkdir(dir))
    assert(lfs.mkdir(dir .. "/" .. M.FOLDER))
    local fixtures = os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/library/"
    for _, book in ipairs(M.BOOKS) do
        copy(fixtures .. book, dir .. "/" .. book)
    end
    copy(fixtures .. M.FOLDER_BOOK, dir .. "/" .. M.FOLDER .. "/" .. M.FOLDER_BOOK)
    return dir
end

return M
