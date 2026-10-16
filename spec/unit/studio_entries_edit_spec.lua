-- The plugin's EntriesEdit gives every result of the corpus the studio's port is held to
-- (studio/test/core/entries-edit.test.ts), so the two can't drift (C12).
describe("EntriesEdit on the shared corpus", function()
    require("plugin_harness")
    local EntriesEdit = require("entries_edit")
    local util = require("util")
    local cases = dofile(os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/studio/entries_edit_cases.lua")

    it("covers every operation", function()
        local covered = {}
        for _, case in ipairs(cases) do
            covered[case.op] = true
        end
        for _, op in ipairs({ "move", "remove", "add", "count", "kind_line" }) do
            assert.is_true(covered[op] == true, op .. " has no case")
        end
    end)

    for i, case in ipairs(cases) do
        it(("case %d: %s, %s"):format(i, case.op, case.why), function()
            local before = util.tableDeepCopy(case.args)
            local result, folder_removed = EntriesEdit[case.op](unpack(case.args))
            if case.refused then
                assert.is_nil(result)
            else
                assert.same(case.result, result)
            end
            if case.op == "remove" then
                assert.equals(case.folder_removed, folder_removed)
            end
            assert.same(before, case.args)
        end)
    end
end)
