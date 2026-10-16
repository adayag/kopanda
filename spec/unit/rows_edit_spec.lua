-- The row operations edit layout applies (device menus' C6): each returns new rows the rows
-- validator takes and leaves its input unchanged, or nil and the note it refuses with; the
-- unused widgets, the reset, the labels, the shares and the captions.
describe("RowsEdit", function()
    require("plugin_harness")
    local RowsEdit = require("rows_edit")
    local Schema = require("schema")
    local Settings = require("settings")

    local entry
    for _, key in ipairs(Schema.keys) do
        if key.id == "layout.rows" then
            entry = key
        end
    end

    local function copy(t)
        if type(t) ~= "table" then
            return t
        end
        local out = {}
        for k, v in pairs(t) do
            out[k] = copy(v)
        end
        return out
    end

    local function slot(widget, share)
        return { widget = widget, share = share or 1 }
    end

    -- Without weather and stats, so two widgets are unused.
    local function four_rows()
        return {
            { slot("date"), slot("clock") },
            { slot("featured") },
            { slot("quote") },
            { slot("launcher") },
        }
    end

    -- op(rows) on a copy of rows: its result, which the validator must take, and its note; the
    -- input must come back unchanged.
    local function apply(rows, op)
        local before = copy(rows)
        local result, note = op(rows)
        assert.same(before, rows, "the input changed")
        if result ~= nil then
            assert.is_true(Settings.validators.rows(entry, result), "the validator refuses the result")
            assert.is_nil(note)
        end
        return result, note
    end

    describe("move", function()
        it("moves a row up and down one", function()
            local up = apply(four_rows(), function(rows) return RowsEdit.move(rows, 2, -1) end)
            assert.same({ { slot("featured") }, { slot("date"), slot("clock") }, { slot("quote") },
                { slot("launcher") } }, up)
            local down = apply(four_rows(), function(rows) return RowsEdit.move(rows, 3, 1) end)
            assert.same({ { slot("date"), slot("clock") }, { slot("featured") }, { slot("launcher") },
                { slot("quote") } }, down)
        end)

        it("is nil past either end", function()
            assert.is_nil(apply(four_rows(), function(rows) return RowsEdit.move(rows, 1, -1) end))
            assert.is_nil(apply(four_rows(), function(rows) return RowsEdit.move(rows, 4, 1) end))
        end)

        it("returns rows that share no table with its input", function()
            local rows = four_rows()
            local moved = RowsEdit.move(rows, 2, -1)
            moved[2][1].share = 3
            assert.equals(1, rows[1][1].share)
        end)
    end)

    describe("add_row", function()
        it("adds a last row of the widget at share 1", function()
            local result = apply(four_rows(), function(rows) return RowsEdit.add_row(rows, "stats") end)
            local wanted = four_rows()
            wanted[5] = { slot("stats") }
            assert.same(wanted, result)
        end)

        it("refuses a widget already on the home", function()
            local result, note = apply(four_rows(), function(rows) return RowsEdit.add_row(rows, "quote") end)
            assert.is_nil(result)
            assert.equals("Each widget can be on the home once.", note)
        end)
    end)

    describe("add_column", function()
        it("adds a last column at share 1", function()
            local result = apply(four_rows(), function(rows) return RowsEdit.add_column(rows, 3, "weather") end)
            local wanted = four_rows()
            wanted[3] = { slot("quote"), slot("weather") }
            assert.same(wanted, result)
        end)

        it("refuses a fourth column", function()
            local rows = four_rows()
            rows[1][3] = slot("quote")
            table.remove(rows, 3)
            local result, note = apply(rows, function(r) return RowsEdit.add_column(r, 1, "weather") end)
            assert.is_nil(result)
            assert.equals("A row holds at most three columns.", note)
        end)

        it("refuses a widget already on the home", function()
            local result, note = apply(four_rows(), function(rows) return RowsEdit.add_column(rows, 3, "date") end)
            assert.is_nil(result)
            assert.equals("Each widget can be on the home once.", note)
        end)
    end)

    describe("change_widget", function()
        it("puts the widget in the column, keeping its share", function()
            local rows = four_rows()
            rows[1][2].share = 2
            local result = apply(rows, function(r) return RowsEdit.change_widget(r, 1, 2, "weather") end)
            local wanted = four_rows()
            wanted[1][2] = slot("weather", 2)
            assert.same(wanted, result)
        end)

        it("refuses a widget already on the home", function()
            local result, note = apply(four_rows(), function(rows)
                return RowsEdit.change_widget(rows, 2, 1, "launcher")
            end)
            assert.is_nil(result)
            assert.equals("Each widget can be on the home once.", note)
        end)
    end)

    describe("set_share", function()
        it("sets a column's share from 1 to 3", function()
            for share = 1, 3 do
                local result = apply(four_rows(), function(rows) return RowsEdit.set_share(rows, 1, 2, share) end)
                local wanted = four_rows()
                wanted[1][2].share = share
                assert.same(wanted, result)
            end
        end)

        it("refuses a share outside 1 to 3", function()
            for _, share in ipairs({ 0, 4, 1.5 }) do
                local result, note = apply(four_rows(), function(rows)
                    return RowsEdit.set_share(rows, 1, 1, share)
                end)
                assert.is_nil(result, share)
                assert.is_string(note, share)
            end
        end)
    end)

    describe("remove_column", function()
        it("removes a column from a row of two", function()
            local result = apply(four_rows(), function(rows) return RowsEdit.remove_column(rows, 1, 1) end)
            local wanted = four_rows()
            wanted[1] = { slot("clock") }
            assert.same(wanted, result)
        end)

        it("refuses the only column of a row", function()
            local result, note = apply(four_rows(), function(rows) return RowsEdit.remove_column(rows, 2, 1) end)
            assert.is_nil(result)
            assert.is_string(note)
        end)
    end)

    describe("remove_row", function()
        it("removes a row", function()
            local result = apply(four_rows(), function(rows) return RowsEdit.remove_row(rows, 2) end)
            local wanted = four_rows()
            table.remove(wanted, 2)
            assert.same(wanted, result)
        end)

        it("refuses the only row", function()
            local result, note = apply({ { slot("quote") } }, function(rows) return RowsEdit.remove_row(rows, 1) end)
            assert.is_nil(result)
            assert.equals("The home needs at least one row.", note)
        end)
    end)

    it("resets to a copy of the schema default", function()
        local before = copy(entry.default)
        local result = RowsEdit.reset()
        assert.same(entry.default, result)
        assert.is_true(Settings.validators.rows(entry, result))
        result[1][1].share = 3
        assert.same(before, entry.default)
    end)

    it("lists the schema's widgets not on the home, in schema order", function()
        assert.same({}, RowsEdit.unused(entry.default))
        local without_stats = copy(entry.default)
        without_stats[5] = { slot("weather") }
        assert.same({ "stats" }, RowsEdit.unused(without_stats))
        assert.same({ "weather", "stats" }, RowsEdit.unused(four_rows()))
    end)

    it("labels every widget, and an unknown id as itself", function()
        local labels = {}
        for _, id in ipairs(entry.widgets) do
            labels[#labels + 1] = RowsEdit.label(id)
        end
        assert.same({ "Date", "Clock", "Weather", "Quote", "Reading stats", "Featured book", "Launcher" }, labels)
        assert.equals("sundial", RowsEdit.label("sundial"))
    end)

    it("reads a share as full alone in its row, else over the row's total, reduced", function()
        assert.equals("full", RowsEdit.share_text({ slot("quote", 2) }, 1))
        assert.equals("1/2", RowsEdit.share_text({ slot("date"), slot("clock") }, 1))
        local one_two = { slot("date", 1), slot("clock", 2) }
        assert.equals("1/3", RowsEdit.share_text(one_two, 1))
        assert.equals("2/3", RowsEdit.share_text(one_two, 2))
        assert.equals("1/2", RowsEdit.share_text({ slot("date", 2), slot("clock", 2) }, 2))
        assert.equals("1/4", RowsEdit.share_text({ slot("date", 2), slot("clock", 3), slot("quote", 3) }, 1))
    end)

    it("captions a card by its row and columns, and selected", function()
        local rows = {
            { slot("date") },
            { slot("clock"), slot("quote") },
            { slot("stats"), slot("weather"), slot("launcher") },
        }
        assert.equals("Row 1 · one column", RowsEdit.caption(rows, 1))
        assert.equals("Row 2 · two columns", RowsEdit.caption(rows, 2))
        assert.equals("Row 3 · three columns", RowsEdit.caption(rows, 3, false))
        assert.equals("Row 2 · two columns · selected", RowsEdit.caption(rows, 2, true))
    end)
end)
