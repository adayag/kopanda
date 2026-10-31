-- The library search's match over hand-built records: every word of the query a plain, case-insensitive
-- substring of the title, an author, the series or the file name, the matches in the library's title order.
describe("BookSearch", function()
    local BookSearch = require("book_search")

    local function book(id, title, fields)
        local record = { id = id, source = "file", path = "/books/" .. id .. ".epub", title = title, authors = {} }
        for k, v in pairs(fields or {}) do
            record[k] = v
        end
        return record
    end

    local function ids(records)
        local out = {}
        for i, record in ipairs(records) do
            out[i] = record.id
        end
        return out
    end

    describe("words", function()
        it("splits on any whitespace and lowers each word", function()
            assert.same({ "good", "omens", "gaiman" }, BookSearch.words("  Good\tOMENS\n gaiman "))
        end)

        it("has none for a blank, empty, nil or non-string query", function()
            assert.same({}, BookSearch.words("   \t "))
            assert.same({}, BookSearch.words(""))
            assert.same({}, BookSearch.words(nil))
            assert.same({}, BookSearch.words(42))
        end)
    end)

    describe("match", function()
        local mort = book("m", "Mort", { authors = { "Terry Pratchett" }, series = "Discworld" })
        local omens = book("g", "Good Omens", { authors = { "Terry Pratchett", "Neil Gaiman" } })
        local gods = book("a", "American Gods", { authors = { "Neil Gaiman" } })

        it("returns every record, in title order, for a query with no words", function()
            assert.same({ "a", "g", "m" }, ids(BookSearch.match({ mort, omens, gods }, "  ")))
        end)

        it("matches a word in the title", function()
            assert.same({ "g" }, ids(BookSearch.match({ mort, omens, gods }, "omen")))
        end)

        it("matches a word in a book's second author", function()
            assert.same({ "a", "g" }, ids(BookSearch.match({ mort, omens, gods }, "gaiman")))
        end)

        it("matches a word in the series", function()
            assert.same({ "m" }, ids(BookSearch.match({ mort, omens, gods }, "discworld")))
        end)

        it("matches a word in the file name but not in the folders above it", function()
            local filed = book("f", "Untitled", { path = "/books/fantasy/xq_mort-1987.epub" })
            assert.same({ "f" }, ids(BookSearch.match({ filed }, "1987")))
            assert.same({}, ids(BookSearch.match({ filed }, "fantasy")))
            assert.same({}, ids(BookSearch.match({ filed }, "books")))
        end)

        it("matches only when every word is found", function()
            assert.same({ "g" }, ids(BookSearch.match({ mort, omens, gods }, "pratchett gaiman")))
            assert.same({}, ids(BookSearch.match({ mort, omens, gods }, "pratchett tolkien")))
        end)

        it("matches words found in different fields", function()
            assert.same({ "m" }, ids(BookSearch.match({ mort, omens, gods }, "disc mort terry")))
        end)

        it("ignores case in both the query and the fields", function()
            local shouty = book("s", "SHOUTY TITLE", { authors = { "lower case" } })
            assert.same({ "s" }, ids(BookSearch.match({ shouty }, "shouty LOWER")))
        end)

        it("matches a word as plain text, not a pattern", function()
            local dotted = book("d", "Dr. Who", {})
            local plain = book("p", "Drx Who", {})
            assert.same({ "d" }, ids(BookSearch.match({ dotted, plain }, "dr.")))
            assert.same({}, ids(BookSearch.match({ dotted, plain }, "%a")))
        end)

        it("matches a record without a path by its other fields", function()
            local cloud = { id = "c", source = "cwng", title = "Cloud Atlas", authors = { "David Mitchell" } }
            assert.same({ "c" }, ids(BookSearch.match({ cloud }, "mitchell")))
            assert.same({}, ids(BookSearch.match({ cloud }, "epub")))
        end)

        it("skips a field of the wrong type and still matches by the others", function()
            local odd = {
                id = "o",
                title = 42,
                authors = { 7, "Ursula Le Guin" },
                series = { "Earthsea" },
                path = false,
            }
            local no_authors = book("n", "Earthsea", { authors = "Le Guin", series = 3, path = 9 })
            assert.same({ "o" }, ids(BookSearch.match({ odd, no_authors }, "ursula")))
            assert.same({ "n" }, ids(BookSearch.match({ odd, no_authors }, "earthsea")))
            assert.same({}, ids(BookSearch.match({ odd, no_authors }, "42")))
        end)

        it("orders the matches by the library's title order whatever the input order", function()
            local zebra = book("z", "The Zebra", {})
            local apple = book("y", "an Apple", {})
            local twin_b = book("t2", "Twin", {})
            local twin_a = book("t1", "twin", {})
            local records = { twin_b, zebra, twin_a, apple }
            assert.same({ "y", "t1", "t2", "z" }, ids(BookSearch.match(records, "")))
            assert.same({ "y", "t1", "t2", "z" }, ids(BookSearch.match({ apple, twin_a, zebra, twin_b }, "")))
        end)

        it("returns a new list and leaves the input as it was", function()
            local records = { mort, omens, gods }
            local result = BookSearch.match(records, "")
            assert.are_not.equal(records, result)
            assert.same({ "m", "g", "a" }, ids(records))
            BookSearch.match(records, "gaiman")
            assert.same({ "m", "g", "a" }, ids(records))
        end)
    end)
end)
