-- The plugin's place search gives every URL and every parse of the corpus the studio's server is
-- held to (studio/test/server/geocoding.test.ts), so the two can't drift (C6).
describe("LocationSearch on the shared geocoding corpus", function()
    local harness = require("plugin_harness")
    local cases = dofile(harness.root .. "/spec/fixtures/studio/geocoding_cases.lua")
    local LocationSearch

    local function fixture(name)
        local f = assert(io.open(harness.root .. "/spec/fixtures/geocoding/" .. name, "rb"))
        local text = f:read("*a")
        f:close()
        return text
    end

    before_each(function()
        harness.load()
        LocationSearch = require("location_search")
    end)

    after_each(function()
        harness.teardown()
    end)

    for i, case in ipairs(cases.urls) do
        it(("url case %d: %q"):format(i, case.query), function()
            assert.equals(case.url, LocationSearch.url(case.query))
        end)
    end

    for _, case in ipairs(cases.parses) do
        it("parse case: " .. case.fixture, function()
            assert.same(case.candidates, LocationSearch.parse(fixture(case.fixture)))
        end)
    end
end)
