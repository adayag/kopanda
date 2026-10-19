-- The author and series index over hand-built records: one entry per distinct name as written, a two-author book in
-- both entries, series books in series-index order with the unindexed last, ties by id, and nothing kept between calls.
describe("BookIndex", function()
    local BookIndex = require("book_index")
    local logger = require("logger")

    local logged, saved_warn

    before_each(function()
        logged = {}
        saved_warn = logger.warn
        logger.warn = function(...)
            logged[#logged + 1] = { ... }
        end
    end)

    after_each(function()
        logger.warn = saved_warn
    end)

    local function book(id, title, fields)
        local record = { id = id, source = "file", title = title, authors = {} }
        for k, v in pairs(fields or {}) do
            record[k] = v
        end
        return record
    end

    -- Each entry as { name, ids of its books }, in order.
    local function shape(entries)
        local out = {}
        for i, entry in ipairs(entries) do
            local ids = {}
            for j, record in ipairs(entry.books) do
                ids[j] = record.id
            end
            out[i] = { entry.name, ids }
        end
        return out
    end

    describe("authors", function()
        it("lists a two-author book in both entries, each counting it", function()
            local good_omens = book("g", "Good Omens", { authors = { "Terry Pratchett", "Neil Gaiman" } })
            local entries = BookIndex.authors({ good_omens })
            assert.same({ { "Neil Gaiman", { "g" } }, { "Terry Pratchett", { "g" } } }, shape(entries))
            assert.equals(1, #entries[1].books)
            assert.equals(1, #entries[2].books)
            assert.equals(good_omens, entries[1].books[1])
            assert.equals(good_omens, entries[2].books[1])
        end)

        it("counts each author's books, a shared book in every author's count", function()
            local entries = BookIndex.authors({
                book("a", "American Gods", { authors = { "Neil Gaiman" } }),
                book("g", "Good Omens", { authors = { "Terry Pratchett", "Neil Gaiman" } }),
                book("m", "Mort", { authors = { "Terry Pratchett" } }),
                book("c", "Coraline", { authors = { "Neil Gaiman" } }),
            })
            assert.same({
                { "Neil Gaiman", { "a", "c", "g" } },
                { "Terry Pratchett", { "g", "m" } },
            }, shape(entries))
        end)

        it("puts a book with no authors in no entry", function()
            local entries = BookIndex.authors({
                book("x", "Anonymous"),
                book("f", "Frankenstein", { authors = { "Mary Shelley" } }),
            })
            assert.same({ { "Mary Shelley", { "f" } } }, shape(entries))
        end)

        it("keeps each name as written", function()
            local entries = BookIndex.authors({
                book("e", "The Left Hand of Darkness", { authors = { "Ursula K. Le Guin" } }),
                book("f", "Frankenstein", { authors = { "Mary Shelley" } }),
            })
            assert.same({ { "Mary Shelley", { "f" } }, { "Ursula K. Le Guin", { "e" } } }, shape(entries))
        end)

        it("counts a name listed twice in one book once", function()
            local entries = BookIndex.authors({
                book("f", "Frankenstein", { authors = { "Mary Shelley", "Mary Shelley" } }),
            })
            assert.same({ { "Mary Shelley", { "f" } } }, shape(entries))
        end)

        it("lists a book under each case variant of a name it gives", function()
            local entries = BookIndex.authors({
                book("f", "Frankenstein", { authors = { "Mary Shelley", "mary shelley" } }),
            })
            assert.same({ { "Mary Shelley", { "f" } }, { "mary shelley", { "f" } } }, shape(entries))
        end)

        it("keeps case variants of a name as two entries, by lowercase name then name", function()
            local entries = BookIndex.authors({
                book("l", "The Last Man", { authors = { "mary shelley" } }),
                book("f", "Frankenstein", { authors = { "Mary Shelley" } }),
                book("v", "Valperga", { authors = { "MARY SHELLEY" } }),
                book("m", "Mathilda", { authors = { "Mary shelley" } }),
                book("p", "Proserpine", { authors = { "mary Shelley" } }),
                book("d", "Dracula", { authors = { "Bram Stoker" } }),
            })
            assert.same({
                { "Bram Stoker", { "d" } },
                { "MARY SHELLEY", { "v" } },
                { "Mary Shelley", { "f" } },
                { "Mary shelley", { "m" } },
                { "mary Shelley", { "p" } },
                { "mary shelley", { "l" } },
            }, shape(entries))
        end)

        it("orders entries by lowercase name, not byte order", function()
            local entries = BookIndex.authors({
                book("1", "One", { authors = { "Zola" } }),
                book("2", "Two", { authors = { "austen" } }),
                book("3", "Three", { authors = { "Brontë" } }),
            })
            assert.same({ { "austen", { "2" } }, { "Brontë", { "3" } }, { "Zola", { "1" } } }, shape(entries))
        end)

        it("orders an entry's books by lowercase title, then id", function()
            local entries = BookIndex.authors({
                book("3", "persuasion", { authors = { "Jane Austen" } }),
                book("2", "Emma", { authors = { "Jane Austen" } }),
                book("1", "emma", { authors = { "Jane Austen" } }),
                book("4", "Mansfield Park", { authors = { "Jane Austen" } }),
            })
            assert.same({ { "Jane Austen", { "1", "2", "4", "3" } } }, shape(entries))
        end)
    end)

    describe("series", function()
        it("orders indexes 2, 1, 1.5 and nil as 1, 1.5, 2, nil", function()
            local entries = BookIndex.series({
                book("two", "B", { series = "Dune", series_index = 2 }),
                book("one", "C", { series = "Dune", series_index = 1 }),
                book("half", "D", { series = "Dune", series_index = 1.5 }),
                book("none", "A", { series = "Dune" }),
            })
            assert.same({ { "Dune", { "one", "half", "two", "none" } } }, shape(entries))
        end)

        it("orders an index of 0 or a negative as a number, before 1", function()
            local entries = BookIndex.series({
                book("one", "A", { series = "S", series_index = 1 }),
                book("none", "B", { series = "S" }),
                book("zero", "C", { series = "S", series_index = 0 }),
                book("neg", "D", { series = "S", series_index = -1 }),
            })
            assert.same({ { "S", { "neg", "zero", "one", "none" } } }, shape(entries))
        end)

        it("orders two unindexed books by lowercase title", function()
            local entries = BookIndex.series({
                book("2", "zeta", { series = "S" }),
                book("1", "Alpha", { series = "S" }),
            })
            assert.same({ { "S", { "1", "2" } } }, shape(entries))
        end)

        it("orders equal indexes by lowercase title, and equal titles by id", function()
            local entries = BookIndex.series({
                book("b", "Same", { series = "S", series_index = 1 }),
                book("c", "Earlier", { series = "S", series_index = 1 }),
                book("a", "same", { series = "S", series_index = 1 }),
                book("e", "Same", { series = "S" }),
                book("d", "Same", { series = "S" }),
            })
            assert.same({ { "S", { "c", "a", "b", "d", "e" } } }, shape(entries))
        end)

        it("puts a book without a series in no entry, and gives one entry per series", function()
            local entries = BookIndex.series({
                book("x", "Standalone", { series_index = 3 }),
                book("f2", "Foundation and Empire", { series = "Foundation", series_index = 2 }),
                book("d1", "Dune", { series = "dune", series_index = 1 }),
                book("f1", "Foundation", { series = "Foundation", series_index = 1 }),
                book("D1", "Dune", { series = "Dune", series_index = 1 }),
            })
            assert.same({
                { "Dune", { "D1" } },
                { "dune", { "d1" } },
                { "Foundation", { "f1", "f2" } },
            }, shape(entries))
        end)
    end)

    describe("currency", function()
        it("follows a changed list on the next call and leaves the first result untouched", function()
            local frankenstein = book("f", "Frankenstein", { authors = { "Mary Shelley" }, series = "Gothic",
                series_index = 1 })
            local dracula = book("d", "Dracula", { authors = { "Bram Stoker" } })
            local records = { frankenstein, dracula }
            local first_authors = BookIndex.authors(records)
            local first_series = BookIndex.series(records)
            local authors_before, series_before = shape(first_authors), shape(first_series)

            records[#records + 1] = book("c", "Carmilla", { authors = { "Sheridan Le Fanu" }, series = "Gothic",
                series_index = 2 })
            dracula.authors = { "Bram Stoker", "Mary Shelley" }

            assert.same({
                { "Bram Stoker", { "d" } },
                { "Mary Shelley", { "d", "f" } },
                { "Sheridan Le Fanu", { "c" } },
            }, shape(BookIndex.authors(records)))
            assert.same({ { "Gothic", { "f", "c" } } }, shape(BookIndex.series(records)))
            assert.same(authors_before, shape(first_authors))
            assert.same(series_before, shape(first_series))
            assert.same({ { "Bram Stoker", { "d" } }, { "Mary Shelley", { "f" } } }, authors_before)
        end)

        it("gives a fresh table on each call", function()
            local records = { book("f", "Frankenstein", { authors = { "Mary Shelley" }, series = "Gothic" }) }
            local a, b = BookIndex.authors(records), BookIndex.authors(records)
            assert.are_not.equal(a, b)
            assert.are_not.equal(a[1], b[1])
            assert.are_not.equal(a[1].books, b[1].books)
            local s, t = BookIndex.series(records), BookIndex.series(records)
            assert.are_not.equal(s, t)
            assert.are_not.equal(s[1].books, t[1].books)
        end)

        it("gives no entries for no records", function()
            assert.same({}, BookIndex.authors({}))
            assert.same({}, BookIndex.series({}))
        end)
    end)

    describe("a malformed record", function()
        it("skips authors that aren't a list of names, logged once per call", function()
            local entries = BookIndex.authors({
                book("s", "String authors", { authors = "Mary Shelley" }),
                book("n", "Odd names", { authors = { 42, "", "Bram Stoker", false } }),
                book("f", "Frankenstein", { authors = { "Mary Shelley" } }),
            })
            assert.same({ { "Bram Stoker", { "n" } }, { "Mary Shelley", { "f" } } }, shape(entries))
            assert.equals(1, #logged)
            assert.equals(2, logged[1][2])
            logged = {}
            BookIndex.authors({ book("n", "Odd names", { authors = { "Mary Shelley", 42 } }) })
            assert.equals(1, #logged)
            assert.equals(1, logged[1][2])
            logged = {}
            BookIndex.authors({ book("f", "Frankenstein", { authors = { "Mary Shelley" } }) })
            assert.equals(0, #logged)
        end)

        it("skips a series that isn't a name and an index that isn't a number, logged once per call", function()
            local entries = BookIndex.series({
                book("t", "Table series", { series = { "Dune" }, series_index = 1 }),
                book("e", "Empty series", { series = "", series_index = 1 }),
                book("s", "String index", { series = "Dune", series_index = "1" }),
                book("n", "Not a number", { series = "Dune", series_index = 0 / 0 }),
                book("d", "Dune", { series = "Dune", series_index = 1 }),
                book("m", "Messiah", { series = "Dune", series_index = 2 }),
            })
            assert.same({ { "Dune", { "d", "m", "n", "s" } } }, shape(entries))
            assert.equals(1, #logged)
            assert.equals(4, logged[1][2])
            logged = {}
            BookIndex.series({ book("n", "Not a number", { series = "Dune", series_index = 0 / 0 }) })
            assert.equals(1, #logged)
            assert.equals(1, logged[1][2])
            logged = {}
            BookIndex.series({ book("d", "Dune", { series = "Dune", series_index = 1 }) })
            assert.equals(0, #logged)
        end)

        it("orders a book whose index is not a number as one without an index", function()
            local entries = BookIndex.series({
                book("n", "A first title", { series = "Dune", series_index = 0 / 0 }),
                book("d", "Dune", { series = "Dune", series_index = 1 }),
                book("m", "Messiah", { series = "Dune", series_index = 2 }),
                book("c", "Children", { series = "Dune", series_index = 3 }),
                book("z", "Zzz", { series = "Dune" }),
            })
            assert.same({ { "Dune", { "d", "m", "c", "n", "z" } } }, shape(entries))
        end)
    end)

    -- The last word, lowercased, with the particles before it kept.
    describe("surname", function()
        it("keys a two-word name by its last word, lowercased", function()
            assert.equals("shelley", BookIndex.surname("Mary Shelley"))
        end)

        it("keeps a particle before the last word", function()
            assert.equals("le guin", BookIndex.surname("Ursula K. Le Guin"))
            assert.equals("de gaulle", BookIndex.surname("Charles de Gaulle"))
            assert.equals("van beethoven", BookIndex.surname("Ludwig van Beethoven"))
        end)

        it("keeps every particle in a run before the last word, and no word before them", function()
            assert.equals("van der waals", BookIndex.surname("Johannes Diderik van der Waals"))
            assert.equals("de la cruz", BookIndex.surname("Juana Inés de la Cruz"))
        end)

        it("keys a one-word name as itself", function()
            assert.equals("plato", BookIndex.surname("Plato"))
        end)

        it("splits on any run of spaces", function()
            assert.equals("le guin", BookIndex.surname("  Ursula  K.   Le  Guin "))
        end)

        it("gives nil for an empty name or one that is not a string", function()
            assert.is_nil(BookIndex.surname(""))
            assert.is_nil(BookIndex.surname("   "))
            assert.is_nil(BookIndex.surname(nil))
            assert.is_nil(BookIndex.surname(42))
        end)
    end)
end)
