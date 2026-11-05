-- The wall of the year's finished covers: how many covers fit a page, the pages they run to, the month over a month's
-- first cover and over a page's first, and the tile's count, page and freeing.
describe("the wall widget", function()
    require("plugin_harness")
    local fixture_text = require("library_fixture").text
    local Screen = require("device").screen
    local FeaturedCover = require("featured_cover")
    local FinishedBooks = require("finished_books")
    local Helpers = require("helpers")
    local InsightTile = require("insight_tile")
    local Looks = require("looks")
    local Wall = require("widgets/wall")
    local Widget = require("ui/widget/widget")

    local real_list, real_framed = FinishedBooks.list, FeaturedCover.framed
    local WIDTH = 1040
    local ROOM = 1300
    local fixture, framed

    -- n books a day apart from 1 January.
    local function books(n)
        local list = {}
        for i = 1, n do
            list[i] = {
                day = os.date("%Y-%m-%d", os.time{ year = 2026, month = 1, day = i, hour = 12 }),
                record = { path = "/books/" .. i .. ".epub", title = "Book " .. i },
            }
        end
        return list
    end

    local function ctx_for(look_id, text_size)
        return {
            look = Looks.get(look_id or "diner"),
            variant = "day",
            text_size = text_size or "medium",
            now = os.time{ year = 2026, month = 10, day = 13, hour = 20, min = 42 },
            screen = Screen,
            boxed = true,
            room = ROOM,
        }
    end

    before_each(function()
        fixture = {}
        framed = {}
        FinishedBooks.list = function()
            return fixture
        end
        FeaturedCover.framed = function(record, w, h)
            local cover = Widget:new{ dimen = { w = w, h = h }, record = record }
            cover.free = function(self)
                self.freed = true
            end
            framed[#framed + 1] = cover
            return cover
        end
    end)

    after_each(function()
        FinishedBooks.list = real_list
        FeaturedCover.framed = real_framed
    end)

    describe("months", function()
        it("labels the first book of each month and leaves the rest blank", function()
            assert.same({ "JAN", "", "FEB" },
                Wall.months({ { day = "2026-01-02" }, { day = "2026-01-20" }, { day = "2026-02-01" } }))
        end)

        it("is empty with no books", function()
            assert.same({}, Wall.months({}))
        end)
    end)

    describe("grid", function()
        -- Seven 136 wide across 1000 with gaps of 8, each 194 tall under a month line of 20: a row of 214.
        it("makes a cover 10:7 in its column", function()
            local grid = Wall.grid(1000, 500, 7, 8, 20)
            assert.equals(7, grid.columns)
            assert.equals(136, grid.cover_w)
            assert.equals(194, grid.cover_h)
        end)

        it("fits N rows exactly at their height and N - 1 a pixel under", function()
            assert.equals(2, Wall.grid(1000, 2 * 214 + 8, 7, 8, 20).rows)
            assert.equals(1, Wall.grid(1000, 2 * 214 + 7, 7, 8, 20).rows)
        end)

        it("gives one row in any room", function()
            assert.equals(1, Wall.grid(1000, 10, 7, 8, 20).rows)
        end)
    end)

    describe("split", function()
        it("gives one page for none, one and exactly a page, and two for one more", function()
            assert.equals(1, #Wall.split(books(0), 4))
            assert.equals(1, #Wall.split(books(1), 4))
            assert.equals(1, #Wall.split(books(4), 4))
            local pages = Wall.split(books(5), 4)
            assert.equals(2, #pages)
            assert.equals(4, #pages[1])
            assert.equals(1, #pages[2])
        end)

        it("keeps each book's record and its month's label", function()
            local list = { { day = "2026-01-02", record = "a" }, { day = "2026-01-03", record = "b" },
                { day = "2026-02-01", record = "c" } }
            local page = Wall.split(list, 3)[1]
            assert.same({ "a", "b", "c" }, { page[1].record, page[2].record, page[3].record })
            assert.same({ "JAN", "", "FEB" }, { page[1].month, page[2].month, page[3].month })
        end)

        it("labels the first cover of a later page with its month", function()
            local list = { { day = "2026-01-02" }, { day = "2026-01-03" }, { day = "2026-01-04" } }
            assert.equals("JAN", Wall.split(list, 2)[2][1].month)
        end)
    end)

    describe("page_count", function()
        local function per_page(ctx)
            local tile = Wall.build(WIDTH, ctx)
            local columns, rows = tile.grid.columns, tile.grid.rows
            tile:free()
            return columns * rows
        end

        it("matches split at the page's edge", function()
            local ctx = ctx_for()
            fixture = books(1)
            local count = per_page(ctx)
            fixture = books(count)
            assert.equals(1, Wall.page_count(WIDTH, ctx_for()))
            fixture = books(count + 1)
            assert.equals(2, Wall.page_count(WIDTH, ctx_for()))
        end)

        it("gives one page with no books", function()
            assert.equals(1, Wall.page_count(WIDTH, ctx_for()))
        end)

        it("takes fewer covers a row at Extra large", function()
            fixture = books(1)
            local tokens = Looks.get("diner").insights
            local medium = Wall.build(WIDTH, ctx_for())
            local large = Wall.build(WIDTH, ctx_for(nil, "extra_large"))
            assert.equals(tokens.wall_columns, medium.grid.columns)
            assert.equals(tokens.wall_columns_extra_large, large.grid.columns)
            medium:free()
            large:free()
        end)

        it("reads the books once across a ctx and the copies of it that follow", function()
            fixture = books(3)
            local list = spy.on(FinishedBooks, "list")
            finally(function()
                list:revert()
            end)
            local ctx = ctx_for()
            Wall.page_count(WIDTH, ctx)
            local copy = {}
            for key, value in pairs(ctx) do
                copy[key] = value
            end
            Wall.build(WIDTH, copy):free()
            assert.spy(list).was.called(1)
        end)
    end)

    describe("the tile", function()
        it("reads Nothing finished yet this year, with no covers, and asks for none", function()
            local tile = Wall.build(WIDTH, ctx_for())
            assert.equals("Nothing finished yet this year", fixture_text(tile.aside))
            assert.equals(0, #framed)
            assert.is_nil(tile.covers)
            tile:free()
        end)

        it("counts the books across all pages and draws the page wall_page picks", function()
            fixture = books(1)
            local one = Wall.build(WIDTH, ctx_for())
            local per = one.grid.columns * one.grid.rows
            one:free()
            fixture = books(per + 2)
            framed = {}
            local ctx = ctx_for()
            ctx.wall_page = 2
            local tile = Wall.build(WIDTH, ctx)
            assert.equals(Helpers.books_text(per + 2), fixture_text(tile.aside))
            assert.equals(2, #framed)
            assert.equals("Book " .. (per + 1), framed[1].record.title)
            tile:free()
        end)

        it("draws page 1 with no wall_page", function()
            fixture = books(2)
            local tile = Wall.build(WIDTH, ctx_for())
            assert.equals("Book 1", framed[1].record.title)
            tile:free()
        end)

        it("names the page's records and the cover box to ask for", function()
            fixture = books(2)
            local tile = Wall.build(WIDTH, ctx_for())
            assert.same({ fixture[1].record, fixture[2].record }, tile.covers.records)
            assert.same({ max_cover_w = tile.grid.cover_w, max_cover_h = tile.grid.cover_h }, tile.covers.box)
            tile:free()
        end)

        it("stays within the room with a full page, in each look at each size", function()
            for _, id in ipairs(Looks.ids()) do
                for _, size in ipairs({ "medium", "extra_large" }) do
                    fixture = books(1)
                    local one = Wall.build(WIDTH, ctx_for(id, size))
                    fixture = books(one.grid.columns * one.grid.rows)
                    one:free()
                    local tile = Wall.build(WIDTH, ctx_for(id, size))
                    assert.is_true(tile:getSize().h <= ROOM, id .. " " .. size)
                    tile:free()
                end
            end
        end)

        it("frees each cover with the tile", function()
            fixture = books(3)
            local tile = Wall.build(WIDTH, ctx_for())
            assert.equals(3, #framed)
            tile:free()
            for _, cover in ipairs(framed) do
                assert.is_true(cover.freed)
            end
        end)

        it("takes the insight tile's width", function()
            fixture = books(1)
            local ctx = ctx_for()
            local tile = Wall.build(WIDTH, ctx)
            assert.equals(WIDTH, tile:getSize().w)
            assert.is_true(tile.grid.cover_w * tile.grid.columns <= InsightTile.inner_width(WIDTH, ctx))
            tile:free()
        end)
    end)
end)
