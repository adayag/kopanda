-- The plugin's row operations give every result and refusal of the corpus the studio's port is held
-- to (studio/test/core/rows-edit.test.ts), so the two can't drift.
describe("RowsEdit on the shared corpus", function()
    require("plugin_harness")
    local RowsEdit = require("rows_edit")
    local cases = dofile(os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/studio/rows_edit_cases.lua")

    it("covers every operation", function()
        local covered = {}
        for _, case in ipairs(cases) do
            covered[case.op] = true
        end
        for _, op in ipairs({ "move", "add_row", "add_column", "change_widget", "set_share", "remove_column",
            "remove_row", "reset", "unused", "label", "share_text", "caption" }) do
            assert.is_true(covered[op] == true, op .. " has no case")
        end
    end)

    for i, case in ipairs(cases) do
        it(("case %d: %s"):format(i, case.op), function()
            local op = assert(RowsEdit[case.op], "no operation " .. tostring(case.op))
            local result, note = op(unpack(case.args))
            if case.refused ~= nil then
                assert.is_nil(result)
                if case.refused == true then
                    assert.is_nil(note)
                else
                    assert.equals(case.refused, note)
                end
            else
                assert.same(case.result, result)
                assert.is_nil(note)
            end
        end)
    end
end)
