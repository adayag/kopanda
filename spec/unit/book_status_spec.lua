-- The book status page's sections: what each shows of a Books record, its progress, its details (Books.details) and
-- its Statistics history, each section left out when it has nothing to show; the time left and its rounding; the
-- description as plain text; and the description's split across pages, measured by a stand-in that wraps every
-- ten characters, so no font is loaded.
describe("the book status page's sections", function()
    local harness = require("plugin_harness")
    local logger = require("logger")
    local BookStatus

    before_each(function()
        harness.load()
        BookStatus = package.loaded["book_status"]
    end)

    after_each(function()
        harness.teardown()
    end)

    local function at(year, month, day, hour)
        return os.time{ year = year, month = month, day = day, hour = hour or 12 }
    end

    local NOW = at(2026, 11, 2, 9)

    local function record(fields)
        local out = { id = "file:/books/a.epub", path = "/books/a.epub", title = "The Time Machine",
            authors = { "H. G. Wells" }, subjects = {} }
        for k, v in pairs(fields or {}) do
            out[k] = v
        end
        return out
    end

    local READING = { status = "reading", percent = 0.62, md5 = "m" }

    local function history(fields)
        local out = { seconds = 27600, days = 12, first = at(2026, 10, 3, 9), last = at(2026, 11, 1, 20) }
        for k, v in pairs(fields or {}) do
            out[k] = v
        end
        return out
    end

    local function sections(rec, progress, details, hist, now)
        return BookStatus.sections(rec or record(), progress or { status = "new" }, details or {}, hist, now or NOW)
    end

    local function kinds(list)
        local out = {}
        for i, section in ipairs(list) do
            out[i] = section.kind
        end
        return out
    end

    local function section(list, kind)
        for _, s in ipairs(list) do
            if s.kind == kind then
                return s
            end
        end
    end

    describe("sections", function()
        it("shows a new book's book block alone: no progress, no history", function()
            local got = sections()
            assert.same({ "book" }, kinds(got))
            assert.same({ kind = "book", title = "The Time Machine", author = "H. G. Wells", subjects = {} }, got[1])
        end)

        it("shows a book being read: its length, progress, time left, history and description, in that order",
            function()
                local got = sections(record(), READING, { pages = 412, description = "A tale." },
                    history({ rate = 30, rate_pages = 412 }))
                assert.same({ "book", "progress", "history", "description" }, kinds(got))
                assert.equals("412 pages", got[1].length)
                -- 412 - round(0.62 × 412) = 157 pages to go at 30 s a page: 4710 s, to the nearest 10 min.
                assert.same({ kind = "progress", shown = 62, caption = "62% · page 255 of 412",
                    left = "About 1 h 20 min left" }, got[2])
                assert.same({ kind = "history", total = "7 h 40 min over 12 days",
                    dates = "Started 3 Oct · Last read 1 Nov" }, got[3])
                assert.same({ kind = "description", text = "A tale." }, got[4])
            end)

        it("reads an abandoned book's progress as a book being read", function()
            local got = section(sections(record(), { status = "abandoned", percent = 0.5 }, { pages = 10 }), "progress")
            assert.same({ kind = "progress", shown = 50, caption = "50% · page 5 of 10" }, got)
        end)

        it("leaves the progress out of a book being read with no percent", function()
            assert.same({ "book" }, kinds(sections(record(), { status = "reading" }, { pages = 10 })))
        end)

        it("counts a book at its start as on page 1", function()
            local got = section(sections(record(), { status = "reading", percent = 0 }, { pages = 412 }), "progress")
            assert.equals("0% · page 1 of 412", got.caption)
        end)

        it("shows a finished book full, finished on its summary's modified date, and no time left", function()
            local got = sections(record(), { status = "complete", percent = 0.97, md5 = "m" },
                { pages = 412, modified = "2026-10-28" }, history({ rate = 30, rate_pages = 412 }))
            assert.same({ "book", "progress", "history" }, kinds(got))
            assert.same({ kind = "progress", shown = 100, caption = "Finished 28 Oct" }, got[2])
        end)

        it("shows Finished alone for a missing or malformed modified date", function()
            for _, modified in ipairs({ false, "", "2026-13-02", "2026-02-30", "2026-10-28 08:00", "28.10.2026",
                    "yesterday", "0000-00-00" }) do
                local got = section(sections(record(), { status = "complete" }, { modified = modified or nil }),
                    "progress")
                assert.same({ kind = "progress", shown = 100, caption = "Finished" }, got, tostring(modified))
            end
        end)

        it("adds the year to a date in another year than now's", function()
            local got = sections(record(), { status = "complete" }, { modified = "2025-12-31" },
                history({ first = at(2025, 12, 1), last = at(2026, 1, 2) }))
            assert.equals("Finished 31 Dec 2025", section(got, "progress").caption)
            assert.equals("Started 1 Dec 2025 · Last read 2 Jan", section(got, "history").dates)
        end)

        it("leaves out the history and the time left with Statistics off", function()
            local got = sections(record(), READING, { pages = 412 }, nil)
            assert.same({ "book", "progress" }, kinds(got))
            assert.is_nil(got[2].left)
        end)

        it("leaves out the time left without a rate or the pages Statistics counts", function()
            assert.is_nil(section(sections(record(), READING, { pages = 412 }, history()), "progress").left)
            assert.is_nil(section(sections(record(), READING, { pages = 412 }, history({ rate = 30 })),
                "progress").left)
        end)

        it("leaves out the description of a book with none, an empty one, or one of only markup and space", function()
            for _, description in ipairs({ false, "", "  \n\t ", "<p> </p><br/>" }) do
                local got = sections(record(), READING, { description = description or nil })
                assert.same({ "book", "progress" }, kinds(got), tostring(description))
            end
        end)

        it("leaves out the length line and the page of a book with no page count", function()
            local got = sections(record(), READING, {})
            assert.is_nil(got[1].length)
            assert.equals("62%", got[2].caption)
        end)

        it("takes the sidecar's pages where the details have none, and words one page", function()
            local got = sections(record(), { status = "reading", percent = 0.5, pages = 300 }, {})
            assert.equals("300 pages", got[1].length)
            assert.equals("50% · page 150 of 300", got[2].caption)
            assert.equals("1 page", sections(record(), READING, { pages = 1 })[1].length)
        end)

        it("leaves out the sidecar's pages when they aren't a count above 0", function()
            for _, pages in ipairs({ 0, -3, "300" }) do
                local got = sections(record(), { status = "reading", percent = 0.5, pages = pages }, {})
                assert.is_nil(got[1].length)
                assert.equals("50%", got[2].caption)
            end
        end)

        it("words the series with its index, a fraction kept, and without one", function()
            assert.equals("Sherlock Holmes · #2", sections(record{ series = "Sherlock Holmes", series_index = 2 })[1]
                .series)
            assert.equals("Sherlock Holmes · #2.5",
                sections(record{ series = "Sherlock Holmes", series_index = 2.5 })[1].series)
            assert.equals("Sherlock Holmes", sections(record{ series = "Sherlock Holmes" })[1].series)
        end)

        it("joins the authors and leaves out none, and keeps the subjects in order", function()
            local got = sections(record{ authors = { "Ann", "Bob" }, subjects = { "Fiction", "Time" } })[1]
            assert.equals("Ann, Bob", got.author)
            assert.same({ "Fiction", "Time" }, got.subjects)
            assert.is_nil(sections(record{ authors = {} })[1].author)
        end)

        it("words the history of one day, of under a minute, and with no page read", function()
            assert.equals("2 h over 1 day", section(sections(record(), READING, {},
                history({ seconds = 7200, days = 1 })), "history").total)
            assert.equals("Under a minute over 1 day", section(sections(record(), READING, {},
                history({ seconds = 59, days = 1 })), "history").total)
            local got = section(sections(record(), READING, {}, history({ seconds = 0, days = 0, first = false })),
                "history")
            assert.same({ kind = "history", dates = "Last read 1 Nov" }, got)
        end)

        it("leaves out a history with nothing to show", function()
            local got = sections(record(), READING, {}, { seconds = 0, days = 0 })
            assert.same({ "book", "progress" }, kinds(got))
        end)

        describe("the time left", function()
            -- The time left of 10 pages to go at rate seconds a page.
            local function left(rate)
                local got = sections(record(), { status = "reading", percent = 0.5 }, {},
                    history({ rate = rate, rate_pages = 20 }))
                return section(got, "progress").left
            end

            it("reads under a minute below 60 s", function()
                assert.equals("Under a minute left", left(0))
                assert.equals("Under a minute left", left(5.9))
            end)

            it("rounds to the minute below an hour", function()
                assert.equals("About 1 min left", left(6))
                assert.equals("About 42 min left", left(250))
                assert.equals("About 59 min left", left(356.9))
            end)

            it("rounds to the nearest ten minutes from an hour", function()
                assert.equals("About 1 h left", left(360))
                assert.equals("About 3 h 10 min left", left(1164))
                assert.equals("About 3 h 20 min left", left(1170))
                assert.equals("About 4 h left", left(1416))
            end)
        end)

        it("makes an HTML description plain text, one paragraph a line", function()
            local got = section(sections(record(), READING, {
                description = "<p>It was <b>dark</b>.</p>\n<p>Then light &amp; air.<br/>And more.</p>",
            }), "description")
            assert.equals("It was dark.\nThen light & air.\nAnd more.", got.text)
        end)

        it("trims a plain description's paragraphs and drops its empty lines", function()
            local got = section(sections(record(), READING, { description = "  One.  \n\n\n\tTwo.\n " }),
                "description")
            assert.equals("One.\nTwo.", got.text)
        end)

        it("leaves out the description and logs it when its conversion raises", function()
            local util = require("util")
            local real = util.htmlToPlainTextIfHtml
            local errored = spy.on(logger, "err")
            util.htmlToPlainTextIfHtml = function()
                error("conversion broke on purpose")
            end
            local ok, got = pcall(sections, record(), READING, { description = "<p>A tale.</p>" })
            util.htmlToPlainTextIfHtml = real
            logger.err:revert()
            assert(ok, got)
            assert.same({ "book", "progress" }, kinds(got))
            assert.spy(errored).was.called()
        end)
    end)

    describe("split", function()
        local WIDTH = 10
        local LINE, GAP = 20, 8

        -- The stand-in measure: a line every WIDTH characters, LINE high, GAP between paragraphs.
        local measure = {
            line_h = LINE,
            gap = GAP,
            lines = function(paragraph)
                return math.ceil(#paragraph / WIDTH)
            end,
        }

        local function wrapped(paragraph)
            local lines = {}
            for i = 1, #paragraph, WIDTH do
                lines[#lines + 1] = paragraph:sub(i, i + WIDTH - 1)
            end
            return lines
        end

        -- Every line of the text, each paragraph wrapped, as { paragraph, line } pairs and texts.
        local function all_lines(text)
            local out = {}
            local i = 0
            for paragraph in text:gmatch("[^\n]+") do
                i = i + 1
                for n, line in ipairs(wrapped(paragraph)) do
                    out[#out + 1] = { i, n, line }
                end
            end
            return out
        end

        -- The lines the pages show, in order, as all_lines gives them.
        local function shown(pages)
            local out = {}
            for _, page in ipairs(pages) do
                for _, part in ipairs(page) do
                    local lines = wrapped(part.text)
                    for n = part.first, part.first + part.count - 1 do
                        out[#out + 1] = { part.paragraph, n, lines[n] }
                    end
                end
            end
            return out
        end

        -- The height a page's parts take: their lines, and a gap above each but the first.
        local function height(page)
            local h = 0
            for i, part in ipairs(page) do
                h = h + part.count * LINE + (i > 1 and GAP or 0)
            end
            return h
        end

        local LONG = table.concat({
            string.rep("a", 95), string.rep("b", 40), string.rep("c", 7), string.rep("d", 230), string.rep("e", 61),
        }, "\n")

        it("shows every line once, in order, each page within its height", function()
            for _, heights in ipairs({ { 100, 100 }, { 45, 130 }, { 20, 20 }, { 300, 70 }, { 1000, 1000 } }) do
                local pages = BookStatus.split(LONG, heights[1], heights[2], measure)
                assert.same(all_lines(LONG), shown(pages), table.concat(heights, ","))
                for i, page in ipairs(pages) do
                    assert.is_true(#page > 0, "page " .. i .. " is empty")
                    assert.is_true(height(page) <= (i == 1 and heights[1] or heights[2]),
                        string.format("page %d at %s is %d high", i, table.concat(heights, ","), height(page)))
                end
            end
        end)

        it("fills page 1 to its height and every later page to the other", function()
            local pages = BookStatus.split(string.rep("x", 200), 60, 100, measure)
            local counts = {}
            for i, page in ipairs(pages) do
                counts[i] = page[1].count
            end
            assert.same({ 3, 5, 5, 5, 2 }, counts)
        end)

        it("starts no page with a paragraph's gap", function()
            -- Paragraph 1 fills page 1 exactly; paragraph 2 starts page 2 at its top.
            local pages = BookStatus.split(string.rep("a", 50) .. "\n" .. string.rep("b", 30), 100, 100, measure)
            assert.equals(2, #pages)
            assert.same({ { paragraph = 1, first = 1, count = 5 } }, {
                { paragraph = pages[1][1].paragraph, first = pages[1][1].first, count = pages[1][1].count } })
            assert.equals(2, pages[2][1].paragraph)
            assert.equals(1, pages[2][1].first)
            assert.equals(60, height(pages[2]))
        end)

        it("leaves page 1 empty when it holds no line, and starts the text on page 2", function()
            local pages = BookStatus.split("short", 19, 100, measure)
            assert.equals(2, #pages)
            assert.same({}, pages[1])
            assert.equals("short", pages[2][1].text)
        end)

        it("puts a line on every later page even when one is taller than the page", function()
            local pages = BookStatus.split(string.rep("x", 30), 10, 10, measure)
            assert.same(all_lines(string.rep("x", 30)), shown(pages))
            assert.equals(4, #pages)
        end)

        it("gives no pages for an empty text", function()
            assert.same({}, BookStatus.split("", 100, 100, measure))
            assert.same({}, BookStatus.split(nil, 100, 100, measure))
        end)
    end)
end)
