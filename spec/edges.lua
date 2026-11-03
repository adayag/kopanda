-- For specs that would sweep a range of sizes: the points where an outcome changes, found by halving, so a spec
-- tests each edge and the values either side instead of every value. Busted gives a spec file its assert; a module
-- required from one takes luassert, the same table.
local assert = require("luassert")

local M = {}

-- The integers n from lo to hi at which f(n) differs from f(n - 1), each with n - 1 and n + 1, ascending. f
-- never returns to a value it has left as n grows, so a stretch whose ends agree holds no change. Fails when
-- f(lo) equals f(hi): a range with no change has no edge to test.
function M.around_changes(lo, hi, f)
    local points, kept = {}, {}
    local function search(a, b, at_a, at_b)
        if at_a == at_b then
            return
        end
        if b - a == 1 then
            for n = b - 1, b + 1 do
                if not kept[n] then
                    kept[n] = true
                    points[#points + 1] = n
                end
            end
            return
        end
        local mid = math.floor((a + b) / 2)
        local at_mid = f(mid)
        search(a, mid, at_a, at_mid)
        search(mid, b, at_mid, at_b)
    end
    search(lo, hi, f(lo), f(hi))
    assert.is_true(#points > 0, ("the outcome changes between %d and %d"):format(lo, hi))
    table.sort(points)
    return points
end

return M
