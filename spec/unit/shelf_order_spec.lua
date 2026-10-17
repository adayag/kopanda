-- What the Series and Authors screens list, in what order, in what state and on which page
-- (series-and-authors D3, D12 to D17), on hand-built records: a series' state, chip counts and
-- next unread; the series list's order, under way first; a series' author line; the authors'
-- order and letters; one author's books in cover-grid's Series order with their up-next marks;
-- and the pagings by rows that fit whole.
describe("ShelfOrder", function()
    local harness = require("plugin_harness")
    local ShelfOrder

    before_each(function()
        harness.load()
        ShelfOrder = require("shelf_order")
    end)

    after_each(function()
        harness.teardown()
    end)

    local function book(id, title, fields)
        local record = { id = id, source = "file", path = "/lib/" .. id .. ".epub", title = title, authors = {} }
        for k, v in pairs(fields or {}) do
            record[k] = v
        end
        return record
    end

    local function progress(statuses)
        return function(record)
            return { status = statuses[record.id] or "new" }
        end
    end

    local function ids(records)
        local out = {}
        for i, record in ipairs(records) do
            out[i] = record.id
        end
        return out
    end

    local function names(entries)
        local out = {}
        for i, entry in ipairs(entries) do
            out[i] = entry.name
        end
        return out
    end

    -- A series "S" of the given books, by index in the order given.
    local function series_of(...)
        local records = {}
        for i, id in ipairs({ ... }) do
            records[i] = book(id, "Book " .. id, { series = "S", series_index = i })
        end
        return records
    end

    local function one_series(records, statuses)
        local entries = ShelfOrder.series(records, progress(statuses))
        assert.equals(1, #entries)
        return entries[1]
    end

    describe("series", function()
        it("finds a series all complete finished, with no next", function()
            local entry = one_series(series_of("a", "b"), { a = "complete", b = "complete" })
            assert.equals("finished", entry.state)
            assert.is_nil(entry.next)
            assert.equals(2, entry.complete)
            assert.equals(2, entry.total)
        end)

        it("finds a series none started not started, its first book next", function()
            local entry = one_series(series_of("a", "b"), {})
            assert.equals("not_started", entry.state)
            assert.equals("a", entry.next.id)
            assert.equals(0, entry.complete)
        end)

        it("finds one complete then a new one under way, the second next", function()
            local entry = one_series(series_of("a", "b"), { a = "complete" })
            assert.equals("under_way", entry.state)
            assert.equals("b", entry.next.id)
        end)

        it("finds the first reading under way, the first next", function()
            local entry = one_series(series_of("a", "b"), { a = "reading" })
            assert.equals("under_way", entry.state)
            assert.equals("a", entry.next.id)
        end)

        it("skips an abandoned book for the next", function()
            local entry = one_series(series_of("a", "b", "c"), { a = "complete", b = "abandoned" })
            assert.equals("under_way", entry.state)
            assert.equals("c", entry.next.id)
            local alone = one_series(series_of("a", "b"), { a = "abandoned" })
            assert.equals("not_started", alone.state)
            assert.equals("b", alone.next.id)
        end)

        it("can make a path-less book the next", function()
            local records = series_of("a", "b")
            records[2].path = nil
            records[2].source = "store"
            local entry = one_series(records, { a = "complete" })
            assert.equals(records[2], entry.next)
        end)

        it("finds a single reading book under way and next", function()
            local entry = one_series(series_of("a"), { a = "reading" })
            assert.equals("under_way", entry.state)
            assert.equals("a", entry.next.id)
            assert.equals(0, entry.complete)
            assert.equals(1, entry.total)
        end)

        it("counts the complete books of the series for the chip", function()
            local entry = one_series(series_of("a", "b", "c", "d"),
                { a = "complete", b = "reading", c = "complete", d = "abandoned" })
            assert.equals(2, entry.complete)
            assert.equals(4, entry.total)
            assert.equals("b", entry.next.id)
        end)

        it("lists the books in series order, an index of 1.5 between 1 and 2, none after", function()
            local records = {
                book("n", "No Index", { series = "S" }),
                book("2", "Two", { series = "S", series_index = 2 }),
                book("h", "Half", { series = "S", series_index = 1.5 }),
                book("1", "One", { series = "S", series_index = 1 }),
            }
            assert.same({ "1", "h", "2", "n" }, ids(one_series(records, {}).books))
        end)

        it("asks each book's progress once per call", function()
            local calls = {}
            local records = series_of("a", "b", "c")
            ShelfOrder.series(records, function(record)
                calls[record.id] = (calls[record.id] or 0) + 1
                return { status = "complete" }
            end)
            assert.same({ a = 1, b = 1, c = 1 }, calls)
        end)

        it("orders the under-way series first, then the others, each part by the title order of the name", function()
            local records, statuses = {}, {}
            local function series(name, states)
                for i, status in ipairs(states) do
                    local id = name .. i
                    records[#records + 1] = book(id, "Book " .. id, { series = name, series_index = i })
                    statuses[id] = status
                end
            end
            series("Earthsea", { "complete", "new" })
            series("The Murderbot Diaries", { "complete", "complete" })
            series("Wayfarers", { "reading" })
            series("Dune", { "new", "new" })
            series("The Broken Earth", { "complete", "reading", "new" })
            series("Ancillary", { "complete" })
            local entries = ShelfOrder.series(records, progress(statuses))
            assert.same({ "The Broken Earth", "Earthsea", "Wayfarers", "Ancillary", "Dune", "The Murderbot Diaries" },
                names(entries))
            assert.same({ "under_way", "under_way", "under_way", "finished", "not_started", "finished" },
                { entries[1].state, entries[2].state, entries[3].state,
                  entries[4].state, entries[5].state, entries[6].state })
        end)

        it("keeps two series whose names differ by case apart, ordered by name", function()
            local entries = ShelfOrder.series({
                book("1", "One", { series = "earthsea" }),
                book("2", "Two", { series = "The Earthsea" }),
                book("3", "Three", { series = "Earthsea" }),
            }, progress({}))
            assert.same({ "Earthsea", "The Earthsea", "earthsea" }, names(entries))
        end)

        it("gives a series its one author, with no others", function()
            local entry = one_series({
                book("a", "A", { series = "S", series_index = 1, authors = { "N. K. Jemisin" } }),
                book("b", "B", { series = "S", series_index = 2, authors = { "N. K. Jemisin" } }),
            }, {})
            assert.equals("N. K. Jemisin", entry.author)
            assert.is_false(entry.others)
        end)

        it("takes the author from the first book that has one", function()
            local entry = one_series({
                book("a", "A", { series = "S", series_index = 1 }),
                book("b", "B", { series = "S", series_index = 2, authors = { "Martha Wells", "Someone Else" } }),
                book("c", "C", { series = "S", series_index = 3, authors = { "Martha Wells" } }),
            }, {})
            assert.equals("Martha Wells", entry.author)
            assert.is_false(entry.others)
        end)

        it("marks others when two first authors differ", function()
            local entry = one_series({
                book("a", "A", { series = "S", series_index = 1, authors = { "Frank Herbert" } }),
                book("b", "B", { series = "S", series_index = 2, authors = { "Brian Herbert", "Frank Herbert" } }),
            }, {})
            assert.equals("Frank Herbert", entry.author)
            assert.is_true(entry.others)
        end)

        it("gives a series with no author none", function()
            local entry = one_series(series_of("a", "b"), {})
            assert.is_nil(entry.author)
            assert.is_false(entry.others)
        end)
    end)

    describe("authors", function()
        it("orders by surname key, then lowercase name, then name, # after Z, with letters and counts", function()
            local entries = ShelfOrder.authors({
                book("1", "One", { authors = { "Ann Leckie" } }),
                book("2", "Two", { authors = { "Agent 47" } }),
                book("3", "Three", { authors = { "Ursula K. Le Guin" } }),
                book("4", "Four", { authors = { "Percy Bysshe Shelley" } }),
                book("5", "Five", { authors = { "Karel \196\140apek" } }),
                book("6", "Six", { authors = { "Mary Shelley" } }),
                book("7", "Seven", { authors = { "Roger Zelazny" } }),
                book("8", "Eight", { authors = { "ann leckie" } }),
                book("9", "Nine", { authors = { "Ursula K. Le Guin" } }),
            })
            assert.same({ "Ursula K. Le Guin", "Ann Leckie", "ann leckie", "Mary Shelley", "Percy Bysshe Shelley",
                "Roger Zelazny", "Agent 47", "Karel \196\140apek" }, names(entries))
            local letters, counts = {}, {}
            for i, entry in ipairs(entries) do
                letters[i], counts[i] = entry.letter, entry.count
            end
            assert.same({ "L", "L", "L", "S", "S", "Z", "#", "#" }, letters)
            assert.same({ 2, 1, 1, 1, 1, 1, 1, 1 }, counts)
            assert.same({ "9", "3" }, { entries[1].books[1].id, entries[1].books[2].id })
        end)

        it("counts a two-author book under both and a book with no author under none", function()
            local entries = ShelfOrder.authors({
                book("1", "One", { authors = { "Terry Pratchett", "Neil Gaiman" } }),
                book("2", "Two", { authors = { "Neil Gaiman" } }),
                book("3", "Three"),
            })
            assert.same({ "Neil Gaiman", "Terry Pratchett" }, names(entries))
            assert.same({ 2, 1 }, { entries[1].count, entries[2].count })
            assert.same({ "1", "2" }, ids(entries[1].books))
            assert.same({ "1" }, ids(entries[2].books))
        end)
    end)

    describe("author_books", function()
        local LE_GUIN = "Ursula K. Le Guin"

        local function library()
            return {
                book("lathe", "The Lathe of Heaven", { authors = { LE_GUIN } }),
                book("tombs", "The Tombs of Atuan", { authors = { LE_GUIN }, series = "Earthsea", series_index = 2 }),
                book("tales", "Tales from Earthsea", { authors = { LE_GUIN }, series = "Earthsea" }),
                book("wizard", "A Wizard of Earthsea",
                    { authors = { LE_GUIN }, series = "Earthsea", series_index = 1 }),
                book("gifts", "Gifts", { authors = { LE_GUIN }, series = "Annals of the Western Shore",
                    series_index = 1 }),
                book("duo1", "Duo One", { authors = { LE_GUIN, "Other Hand" }, series = "The Duo", series_index = 1 }),
                book("duo2", "Duo Two", { authors = { "Other Hand" }, series = "The Duo", series_index = 2 }),
                book("dune", "Dune", { authors = { "Frank Herbert" }, series = "Dune", series_index = 1 }),
            }
        end

        local function le_guin(records)
            for _, entry in ipairs(ShelfOrder.authors(records)) do
                if entry.name == LE_GUIN then
                    return entry
                end
            end
        end

        it("lists the author's books in the Series order, books in no series last", function()
            local records = library()
            local statuses = {}
            local books = ShelfOrder.author_books(le_guin(records), ShelfOrder.series(records, progress(statuses)),
                progress(statuses))
            assert.same({ "gifts", "duo1", "wizard", "tombs", "tales", "lathe" }, ids(books))
        end)

        it("marks a series' next unread only when it is this author's book, from the whole series", function()
            local records = library()
            local statuses = { wizard = "complete", duo1 = "complete", gifts = "complete" }
            local series = ShelfOrder.series(records, progress(statuses))
            local _, up_next = ShelfOrder.author_books(le_guin(records), series, progress(statuses))
            assert.same({ tombs = true }, up_next)
        end)
    end)

    describe("pages", function()
        local function row(h, group, group_cost, id)
            return { h = h, group = group, group_cost = group_cost, id = id }
        end

        -- Each page as { first, last, repeats }.
        local function spans(pages)
            local out = {}
            for i, page in ipairs(pages) do
                out[i] = { page.first, page.last, page.repeats }
            end
            return out
        end

        it("keeps rows that fit exactly on one page, gaps counted", function()
            local rows = { row(100), row(100), row(100) }
            assert.same({ { 1, 3, false } }, spans(ShelfOrder.pages(rows, 320, 10)))
        end)

        it("moves the row one over to the next page", function()
            local rows = { row(100), row(100), row(100) }
            assert.same({ { 1, 2, false }, { 3, 3, false } }, spans(ShelfOrder.pages(rows, 319, 10)))
        end)

        it("gives a row taller than the space a page of its own", function()
            local rows = { row(50), row(500), row(50) }
            assert.same({ { 1, 1, false }, { 2, 2, false }, { 3, 3, false } }, spans(ShelfOrder.pages(rows, 200, 0)))
            assert.same({ { 1, 1, false } }, spans(ShelfOrder.pages({ row(500) }, 200, 0)))
        end)

        it("gives each page its rows", function()
            local rows = { row(100), row(100), row(100) }
            local pages = ShelfOrder.pages(rows, 250, 0)
            assert.equals(rows[1], pages[1].rows[1])
            assert.equals(rows[2], pages[1].rows[2])
            assert.equals(rows[3], pages[2].rows[1])
            assert.equals(2, #pages[1].rows)
        end)

        it("marks a group continued from the page before as repeated", function()
            local rows = {
                row(100, "A", 20), row(100, "A", 20), row(100, "A", 20), row(100, "B", 20), row(100, "B", 20),
            }
            assert.same({ { 1, 2, false }, { 3, 4, true }, { 5, 5, true } }, spans(ShelfOrder.pages(rows, 260, 0)))
        end)

        it("counts a group's cost once per page", function()
            local rows = { row(50, "A", 30), row(50, "A", 30), row(50, "A", 30) }
            assert.same({ { 1, 3, false } }, spans(ShelfOrder.pages(rows, 180, 0)))
            assert.same({ { 1, 2, false }, { 3, 3, true } }, spans(ShelfOrder.pages(rows, 179, 0)))
        end)

        it("counts each group's cost on a page holding two", function()
            local rows = { row(50, "A", 30), row(50, "B", 30) }
            assert.same({ { 1, 2, false } }, spans(ShelfOrder.pages(rows, 160, 0)))
            assert.same({ { 1, 1, false }, { 2, 2, false } }, spans(ShelfOrder.pages(rows, 159, 0)))
        end)

        it("gives one empty page for no rows", function()
            local pages = ShelfOrder.pages({}, 200, 0)
            assert.equals(1, #pages)
            assert.same({}, pages[1].rows)
        end)

        it("finds the page holding the first row a predicate matches, 1 for none", function()
            local rows = {}
            for i = 1, 6 do
                rows[i] = row(100, nil, nil, i)
            end
            local pages = ShelfOrder.pages(rows, 200, 0)
            local function id_is(id)
                return function(r)
                    return r.id == id
                end
            end
            assert.equals(1, ShelfOrder.page_of(pages, id_is(2)))
            assert.equals(3, ShelfOrder.page_of(pages, id_is(5)))
            assert.equals(1, ShelfOrder.page_of(pages, id_is(9)))
        end)
    end)
end)
