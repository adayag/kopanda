-- helpers.lua: the words a count of books reads in, whether a point lies in a rectangle, and a note.
describe("helpers", function()
    require("plugin_harness") -- KOReader's commonrequire, for the note's widgets
    local Helpers = require("helpers")

    describe("books_text", function()
        it("words one book singular and any other count plural, 0 too", function()
            assert.equals("1 book", Helpers.books_text(1))
            assert.equals("14 books", Helpers.books_text(14))
            assert.equals("0 books", Helpers.books_text(0))
        end)
    end)

    describe("count_text", function()
        it("words no books as \"No books\", then as books_text", function()
            assert.equals("No books", Helpers.count_text(0))
            assert.equals("1 book", Helpers.count_text(1))
            assert.equals("3 books", Helpers.count_text(3))
        end)

        it("adds \"on the shelf\" when asked", function()
            assert.equals("No books on the shelf", Helpers.count_text(0, true))
            assert.equals("1 book on the shelf", Helpers.count_text(1, true))
            assert.equals("3 books", Helpers.count_text(3, false))
        end)
    end)

    describe("inside", function()
        local rect = { x = 10, y = 20, w = 5, h = 4 }

        it("holds its top-left corner and the pixels up to its right and bottom edges", function()
            assert.is_true(Helpers.inside(rect, { x = 10, y = 20 }))
            assert.is_true(Helpers.inside(rect, { x = 14, y = 23 }))
        end)

        it("leaves its right and bottom edges, and anything before its left and top, outside", function()
            assert.is_false(Helpers.inside(rect, { x = 15, y = 21 }))
            assert.is_false(Helpers.inside(rect, { x = 11, y = 24 }))
            assert.is_false(Helpers.inside(rect, { x = 9, y = 21 }))
            assert.is_false(Helpers.inside(rect, { x = 11, y = 19 }))
        end)
    end)

    describe("note", function()
        local InfoMessage = require("ui/widget/infomessage")
        local UIManager = require("ui/uimanager")

        it("shows its text in an InfoMessage with no timeout, so no timer", function()
            local shown = {}
            local show = UIManager.show
            finally(function()
                UIManager.show = show
            end)
            UIManager.show = function(_, widget)
                shown[#shown + 1] = widget
            end
            Helpers.note("Nothing to pull.")
            assert.equals(1, #shown)
            assert.equals(InfoMessage, getmetatable(shown[1]))
            assert.equals("Nothing to pull.", shown[1].text)
            assert.is_nil(shown[1].timeout)
        end)
    end)
end)
