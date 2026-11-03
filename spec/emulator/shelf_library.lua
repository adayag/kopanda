-- The Series, Authors, Subjects and search captures' book folder, shared by series_authors_capture_spec.lua and
-- paint_budget_spec.lua: the three fixture books under their own names and copies of one of them under the names
-- the scenario's catalogue gives metadata to (scenarios/2-scenario-series-authors.lua, CATALOGUE), so
-- spec/fixtures/library/ is not changed. Busted's assertions, which a required module doesn't get as its global assert.
local assert = require("luassert")
local lfs = require("libs/libkoreader-lfs")

local M = {}

local ORIGINALS = { "a-christmas-carol.epub", "frankenstein.epub", "the-time-machine.epub" }
-- The scenario refuses a library that holds any other file or lacks one.
local COPIED = "the-time-machine.epub"
local COPIES = {
    "a-study-in-scarlet.epub", "the-sign-of-the-four.epub", "the-lost-world.epub", "micah-clarke.epub",
    "the-white-company.epub", "the-chimes.epub", "the-cricket-on-the-hearth.epub", "the-pioneers.epub",
    "the-last-of-the-mohicans.epub", "alices-adventures-in-wonderland.epub", "through-the-looking-glass.epub",
    "the-warden.epub", "barchester-towers.epub", "the-three-musketeers.epub", "twenty-years-after.epub",
    "the-wonderful-wizard-of-oz.epub", "the-marvelous-land-of-oz.epub", "the-wrong-box.epub",
}

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function copy(from, to)
    assert.equals(0, os.execute("cp " .. quote(from) .. " " .. quote(to)))
end

-- A fresh shelf library under KO_HOME. A copy has its own path, so its CoverBrowser row and sidecar are its own.
-- Returns its path.
local made = 0
function M.make()
    made = made + 1
    local dir = string.format("%s/shelf-capture-%d", os.getenv("KO_HOME"), made)
    if lfs.attributes(dir, "mode") then
        assert.equals(0, os.execute("rm -rf " .. quote(dir)))
    end
    assert(lfs.mkdir(dir))
    local fixtures = os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/library/"
    for _, book in ipairs(ORIGINALS) do
        copy(fixtures .. book, dir .. "/" .. book)
    end
    for _, name in ipairs(COPIES) do
        copy(fixtures .. COPIED, dir .. "/" .. name)
    end
    return dir
end

return M
