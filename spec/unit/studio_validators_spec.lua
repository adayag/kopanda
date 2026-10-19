-- The plugin's validators give every verdict of the corpus the studio's validators are held to
-- (studio/test/core/validators.test.ts), so the two can't drift.
describe("Settings.validators on the shared corpus", function()
    require("plugin_harness")
    local Schema = require("schema")
    local Settings = require("settings")
    local cases = dofile(os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/studio/validator_cases.lua")

    local entries = {}
    for _, entry in ipairs(Schema.keys) do
        entries[entry.id] = entry
    end

    it("covers every schema key", function()
        local covered = {}
        for _, case in ipairs(cases) do
            covered[case.key] = true
        end
        for _, entry in ipairs(Schema.keys) do
            assert.is_true(covered[entry.id] == true, entry.id .. " has no case")
        end
    end)

    for i, case in ipairs(cases) do
        it(("case %d: %s, %s"):format(i, case.key, case.why), function()
            local entry = assert(entries[case.key], "no schema key " .. tostring(case.key))
            local valid = Settings.validators[entry.type](entry, case.value)
            assert.equals(case.valid, valid, ("%s, %s: expected %s"):format(case.key, case.why,
                tostring(case.valid)))
        end)
    end
end)
