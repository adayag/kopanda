-- The library chrome over something other than the file manager: a window whose foot names no nav-bar tab builds no
-- nav bar and puts its pager at the screen's foot; a window with its own hold_sheet takes its holds, and one
-- without hands them to LibrarySheets.hold; the header chip lays its widgets side by side inside the picker padding.
describe("the library chrome", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local LibraryChrome, LibrarySheets, Typeset

    local restores = {}

    before_each(function()
        restores = {}
        harness.load()
        LibraryChrome = package.loaded["library_chrome"]
        LibrarySheets = package.loaded["library_sheets"]
        Typeset = package.loaded["typeset"]
    end)

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        harness.teardown()
    end)

    -- Replaces t[name] with a recorder of each call's arguments.
    local function spy(t, name)
        local calls, original = {}, rawget(t, name)
        restores[#restores + 1] = function()
            t[name] = original
        end
        t[name] = function(...)
            calls[#calls + 1] = { ... }
        end
        return calls
    end

    -- A window of one page with a plain header, its foot built for where, and hold_sheet when given.
    local function window_class(where, hold_sheet)
        local cls = LibraryChrome.Window:extend{
            name = "kopanda_spec_window",
            screen = "spec",
        }
        function cls:view()
            return {}
        end
        function cls:action_at()
            return nil
        end
        function cls.hit(x, y)
            return { kind = "spot", x = x, y = y }
        end
        cls.hold_sheet = hold_sheet
        function cls:build()
            return LibraryChrome.build({ page = 1 }, function(built, frame, w)
                built.pages = 1
                local box
                box, built.header = LibraryChrome.header(built.ctx, w, {
                    height = 100,
                    right = {},
                    aside = { part = built.ctx.look.type.library_count, text = "Aside" },
                    title = { part = built.ctx.look.type.library_title, text = "Title" },
                })
                LibraryChrome.add(frame, box, 0, 0)
                LibraryChrome.foot(built, frame, where)
            end)
        end
        return cls
    end

    local function hold_at(x, y)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("hold", x, y)))
    end

    describe("a foot with no nav-bar tab", function()
        it("builds no nav bar and puts the pager at the screen's foot", function()
            local window = LibraryChrome.show(window_class(nil), {}, {})
            assert.is_not_nil(window)
            assert.is_nil(window.nav)
            local h = Screen:getHeight()
            local prev = window.pager.prev.rect
            assert.is_true(prev.y + prev.h <= h, "the pager runs past the screen")
            assert.is_true(prev.y >= h - require("library_tiles").pager_height(window.ctx),
                "the pager sits above the screen's foot")
        end)

        it("still builds the nav bar for a named tab", function()
            local window = LibraryChrome.show(window_class("library"), {}, {})
            assert.is_not_nil(window.nav)
            assert.is_true(window.pager.prev.rect.y + window.pager.prev.rect.h <= window.nav.dimen.y)
        end)
    end)

    describe("a hold", function()
        it("goes to the window's own hold_sheet with what lies under it, and not to LibrarySheets.hold", function()
            local sheets = spy(LibrarySheets, "hold")
            local got = {}
            local window = LibraryChrome.show(window_class(nil, function(self, hit, started)
                got[#got + 1] = { self = self, hit = hit, started = started }
            end), {}, {})
            hold_at(300, 400)
            assert.equals(1, #got)
            assert.equals(window, got[1].self)
            assert.same({ kind = "spot", x = 300, y = 400 }, got[1].hit)
            assert.is_not_nil(got[1].started)
            assert.equals(0, #sheets)
        end)

        it("goes to LibrarySheets.hold for a window without hold_sheet", function()
            local sheets = spy(LibrarySheets, "hold")
            local window = LibraryChrome.show(window_class(nil), {}, {})
            hold_at(300, 400)
            assert.equals(1, #sheets)
            assert.equals(window, sheets[1][1])
            assert.same({ kind = "spot", x = 300, y = 400 }, sheets[1][2])
        end)
    end)

    describe("the header chip", function()
        it("lays its widgets side by side, top-aligned, inside the picker padding and outline", function()
            local window = LibraryChrome.show(window_class(nil), {}, {})
            local ctx = window.ctx
            local part = ctx.look.type.library_picker
            local a = Typeset.line(part, "Chapters", Screen:getWidth(), ctx)
            local b = Typeset.line(part, "Two", Screen:getWidth(), ctx)
            local chip = LibraryChrome.chip({ a, b }, ctx.look.library.header.sort_fill_color, ctx)
            local tokens = ctx.look.library.header
            local outline = Screen:scaleBySize(tokens.picker_outline_width)
            local pad_x = outline + Screen:scaleBySize(tokens.picker_padding.x)
            local pad_y = outline + Screen:scaleBySize(tokens.picker_padding.y)
            assert.same({ x = pad_x, y = pad_y }, chip.places[1])
            assert.same({ x = pad_x + a:getSize().w, y = pad_y }, chip.places[2])
            assert.equals(a:getSize().w + b:getSize().w + 2 * pad_x, chip:getSize().w)
            chip:free()
        end)
    end)
end)
