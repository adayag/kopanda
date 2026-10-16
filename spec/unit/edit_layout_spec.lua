-- Edit layout (device menus' C7), over a shown home with a real settings file: a card per row
-- with its caption, boxes and arrows; a tap selects a row and shows its buttons; each change
-- writes layout.rows once, refreshes the home once and repaints the screen once; refusals show
-- their note and leave the file's bytes alone; the widget pickers list only unused widgets.
-- Every control is tapped where the editor placed it.
describe("edit layout", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local InfoMessage = require("ui/widget/infomessage")
    local UIManager = require("ui/uimanager")
    local Editor, EditLayout, Home, Layout, Schema, Settings, Sheet

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

    local function default_rows()
        for _, key in ipairs(Schema.keys) do
            if key.id == "layout.rows" then
                return key.default
            end
        end
    end

    -- Undo steps for the running test, run last first after it.
    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
    end

    local function replace(t, name, fn)
        local original = t[name]
        t[name] = fn
        cleanup(function()
            t[name] = original
        end)
    end

    local function read_file()
        local f = assert(io.open(harness.settings_file, "rb"))
        local bytes = f:read("*a")
        f:close()
        return bytes
    end

    local function stored()
        return dofile(harness.settings_file)["layout.rows"]
    end

    local function tap_at(x, y)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", x, y)))
    end

    local function tap(rect)
        tap_at(rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))
    end

    -- The editor's places whose control matches every field of want.
    local function find(want)
        local found = {}
        for _, place in ipairs(Editor.shown.places) do
            local match = true
            for k, v in pairs(want) do
                if place.control[k] ~= v then
                    match = false
                end
            end
            if match then
                found[#found + 1] = place
            end
        end
        return found
    end

    local function one(want)
        local found = find(want)
        assert.equals(1, #found)
        return found[1]
    end

    -- A tap inside card i, beside its caption, on none of its other controls.
    local function tap_card(i)
        local rect = one({ kind = "card", row = i }).rect
        tap_at(rect.x + rect.w - 3, rect.y + 3)
    end

    local function tap_button(label)
        tap(one({ kind = "button", label = label }).rect)
    end

    local function button_labels(row)
        local labels = {}
        for _, place in ipairs(find({ kind = "button", row = row })) do
            labels[#labels + 1] = place.control.label
        end
        return labels
    end

    -- The shown sheet's row labels, a ticked one as "label ✓".
    local function sheet_rows()
        local rows = {}
        for _, row in ipairs(Sheet.shown.spec.rows) do
            rows[#rows + 1] = row.label .. (row.tick and " ✓" or "")
        end
        return rows
    end

    local function pick(label)
        for _, place in ipairs(Sheet.shown.rows) do
            if place.row.label == label then
                tap(place.rect)
                return
            end
        end
        error("no picker row " .. label)
    end

    -- The InfoMessage on the stack, or nil.
    local function message()
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == InfoMessage then
                return widget
            end
        end
    end

    -- Stores rows when given, shows the home and opens edit layout over it.
    local function open(rows, opts)
        if rows then
            assert.is_true(Settings.set("layout.rows", rows))
        end
        harness.show_fm()
        harness.tick(4)
        assert.equals(Home.shown, harness.top())
        EditLayout.open(opts)
        assert.is_not_nil(Editor.shown)
        assert.equals(Editor.shown, harness.top())
        return Editor.shown
    end

    before_each(function()
        harness.load()
        Editor = require("editor")
        EditLayout = require("edit_layout")
        Home = require("home")
        Layout = require("layout")
        Schema = require("schema")
        Settings = require("settings")
        Sheet = require("sheet")
    end)

    after_each(function()
        for i = #cleanups, 1, -1 do
            cleanups[i]()
        end
        cleanups = {}
        harness.teardown()
    end)

    it("is the edit_layout screen headed Home over Edit layout", function()
        local editor = open()
        assert.same({ "edit_layout", "Home", "Edit layout" },
            { editor.spec.screen, editor.spec.aside, editor.spec.title })
    end)

    describe("cards", function()
        it("show the default's five rows with captions, labelled boxes with shares, and arrows greyed at the ends",
            function()
                open()
                assert.equals(5, #find({ kind = "card" }))
                assert.equals("Row 1 · two columns", one({ kind = "card", row = 1 }).control.caption)
                assert.equals("Row 2 · one column", one({ kind = "card", row = 2 }).control.caption)
                local date = one({ kind = "box", row = 1, column = 1 }).control
                assert.same({ "Date", "1/2" }, { date.label, date.share })
                local featured = one({ kind = "box", row = 2, column = 1 }).control
                assert.same({ "Featured book", "full" }, { featured.label, featured.share })
                assert.is_true(one({ kind = "arrow", row = 1, direction = "up" }).control.disabled)
                assert.is_true(one({ kind = "arrow", row = 5, direction = "down" }).control.disabled)
                assert.is_falsy(one({ kind = "arrow", row = 1, direction = "down" }).control.disabled)
                assert.is_falsy(one({ kind = "arrow", row = 5, direction = "up" }).control.disabled)
                assert.same({}, button_labels(1))
            end)

        it("start with the given row selected", function()
            open(nil, { selected = 2 })
            assert.equals("Row 2 · one column · selected", one({ kind = "card", row = 2 }).control.caption)
        end)
    end)

    it("paints in both looks, the selected card in the selected fill and the others on paper", function()
        local Blitbuffer = require("ffi/blitbuffer")
        local Looks = require("looks")
        local logger = require("logger")
        local Screen = require("device").screen
        local function pixel(bb, x, y)
            local c = bb:getPixel(x, y):getColorRGB32()
            return { c:getR(), c:getG(), c:getB() }
        end
        local function rgb(hex)
            local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
            return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
        end
        for _, id in ipairs({ "editorial", "diner" }) do
            assert.is_true(Settings.set("look", id))
            local errors = spy.on(logger, "err")
            local editor = open(four_rows(), { selected = 1 })
            local size = Screen:getSize()
            local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
            editor:paintTo(bb, 0, 0)
            local look = Looks.get(id)
            local palette = Looks.palette(look, "day")
            local inset = Screen:scaleBySize(look.editor.card_outline_width) + 1
            local first = one({ kind = "card", row = 1 }).rect
            local second = one({ kind = "card", row = 2 }).rect
            local selected = pixel(bb, first.x + first.w - inset - 1, first.y + inset)
            local plain = pixel(bb, second.x + second.w - inset - 1, second.y + inset)
            bb:free()
            errors:revert()
            assert.spy(errors).was_not.called()
            assert.equals(editor, Editor.shown, id)
            assert.same(rgb(palette[look.editor.selected_fill_color]), selected, id)
            assert.same(rgb(palette.paper), plain, id)
            Editor.close()
            harness.teardown()
        end
    end)

    describe("a tap on a card", function()
        it("selects its row and shows its buttons, Width and Remove column on a row of two", function()
            open()
            tap_card(2)
            assert.equals("Row 2 · one column · selected", one({ kind = "card", row = 2 }).control.caption)
            assert.same({ "Add column", "Change widget", "Remove row" }, button_labels(2))
            tap_card(1)
            assert.equals("Row 2 · one column", one({ kind = "card", row = 2 }).control.caption)
            assert.same({}, button_labels(2))
            assert.same({ "Add column", "Change widget", "Width", "Remove column", "Remove row" }, button_labels(1))
            -- Every widget is on the default home.
            assert.is_true(one({ kind = "button", label = "Add column" }).control.disabled)
        end)

        it("writes nothing", function()
            open()
            tap_card(2)
            local f = io.open(harness.settings_file, "rb")
            assert.is_nil(f)
        end)
    end)

    describe("each change", function()
        -- Opens rows (four_rows when nil), runs steps, then checks the file holds wanted, the
        -- home refreshed once and the editor asked for one ui repaint, counted from the change's
        -- last step.
        local function change(select, act, wanted, rows)
            local editor = open(rows or four_rows())
            if select then
                select()
            end
            local refreshed = spy.on(Home.shown, "refresh")
            local repaints = 0
            local set_dirty = UIManager.setDirty
            replace(UIManager, "setDirty", function(self, widget, mode, ...)
                if widget == editor and mode == "ui" then
                    repaints = repaints + 1
                end
                return set_dirty(self, widget, mode, ...)
            end)
            act()
            assert.same(wanted, stored())
            assert.spy(refreshed).was.called(1)
            assert.equals(1, repaints)
            assert.equals(editor, Editor.shown)
            assert.is_nil(message())
        end

        it("moves row 2 up, the selection following it", function()
            change(function() tap_card(2) end, function()
                tap(one({ kind = "arrow", row = 2, direction = "up" }).rect)
            end, { { slot("featured") }, { slot("date"), slot("clock") }, { slot("quote") }, { slot("launcher") } })
            assert.equals("Row 1 · one column · selected", one({ kind = "card", row = 1 }).control.caption)
        end)

        it("moves row 2 up past the selected row 1, the selection following row 1 down", function()
            change(function() tap_card(1) end, function()
                tap(one({ kind = "arrow", row = 2, direction = "up" }).rect)
            end, { { slot("featured") }, { slot("date"), slot("clock") }, { slot("quote") }, { slot("launcher") } })
            assert.equals("Row 1 · one column", one({ kind = "card", row = 1 }).control.caption)
            assert.equals("Row 2 · two columns · selected", one({ kind = "card", row = 2 }).control.caption)
        end)

        it("adds a column to row 3 picked from the unused widgets", function()
            change(function() tap_card(3) end, function()
                tap_button("Add column")
                assert.equals("picker", Sheet.shown.spec.name)
                assert.equals("home", Sheet.shown.spec.band)
                assert.equals("Add a widget", Sheet.shown.spec.header.heading)
                assert.same({ "Weather", "Reading stats" }, sheet_rows())
                pick("Weather")
            end, { { slot("date"), slot("clock") }, { slot("featured") }, { slot("quote"), slot("weather") },
                { slot("launcher") } })
            assert.is_nil(Sheet.shown)
        end)

        it("changes row 2's widget", function()
            change(function() tap_card(2) end, function()
                tap_button("Change widget")
                assert.equals("Change widget", Sheet.shown.spec.header.heading)
                pick("Reading stats")
            end, { { slot("date"), slot("clock") }, { slot("stats") }, { slot("quote") }, { slot("launcher") } })
        end)

        it("sets the selected column's width to 2, ticking that column's own width", function()
            local rows = four_rows()
            rows[1] = { slot("date", 2), slot("clock", 1) }
            change(function()
                tap_card(1)
                tap(one({ kind = "box", row = 1, column = 2 }).rect)
            end, function()
                tap_button("Width")
                assert.equals("Width", Sheet.shown.spec.header.heading)
                assert.same({ "1 ✓", "2", "3" }, sheet_rows())
                pick("2")
            end, { { slot("date", 2), slot("clock", 2) }, { slot("featured") }, { slot("quote") },
                { slot("launcher") } }, rows)
            assert.equals("1/2", one({ kind = "box", row = 1, column = 2 }).control.share)
        end)

        it("removes the selected column", function()
            change(function()
                tap_card(1)
                tap(one({ kind = "box", row = 1, column = 2 }).rect)
            end, function()
                tap_button("Remove column")
            end, { { slot("date") }, { slot("featured") }, { slot("quote") }, { slot("launcher") } })
            -- The selection moves to the column that remains.
            tap_button("Change widget")
            assert.equals("Date ✓", sheet_rows()[1])
        end)

        it("removes the selected row and clears the selection", function()
            change(function() tap_card(2) end, function()
                tap_button("Remove row")
            end, { { slot("date"), slot("clock") }, { slot("quote") }, { slot("launcher") } })
            assert.equals(0, #find({ kind = "button", row = 2 }))
            assert.equals(0, #find({ kind = "button", label = "Remove row" }))
        end)

        it("adds a row picked from the unused widgets", function()
            change(nil, function()
                tap_button("Add row")
                assert.equals("Add a widget", Sheet.shown.spec.header.heading)
                pick("Reading stats")
            end, { { slot("date"), slot("clock") }, { slot("featured") }, { slot("quote") }, { slot("launcher") },
                { slot("stats") } })
        end)

        it("resets to the schema default", function()
            change(nil, function()
                tap_button("Reset to the look's default")
            end, default_rows())
        end)
    end)

    describe("refusals", function()
        -- Opens rows over a written file, runs prepare when given, then act, and checks note is
        -- shown with no timeout and the file is byte for byte as it was.
        local function refused(rows, act, note, prepare)
            open(rows)
            if prepare then
                prepare()
            end
            local before = read_file()
            local refreshed = spy.on(Home.shown, "refresh")
            act()
            local shown = message()
            assert.is_not_nil(shown)
            assert.equals(note, shown.text)
            assert.is_nil(shown.timeout)
            assert.equals(before, read_file())
            assert.spy(refreshed).was_not.called()
        end

        it("won't add a row that leaves out more home rows", function()
            replace(Layout, "overflow", function(rows)
                return #rows
            end)
            refused(four_rows(), function()
                tap_button("Add row")
                pick("Weather")
            end, "That won't fit on the home.")
        end)

        it("lets a too-tall layout shrink", function()
            replace(Layout, "overflow", function(rows)
                return #rows
            end)
            open(four_rows())
            tap_card(2)
            tap_button("Remove row")
            assert.equals(3, #stored())
            assert.is_nil(message())
        end)

        it("won't remove the only row", function()
            refused({ { slot("quote") } }, function()
                tap_card(1)
                tap_button("Remove row")
            end, "The home needs at least one row.")
        end)

        it("shows a note, logs and changes nothing when the write fails", function()
            local logger = require("logger")
            local errors = spy.on(logger, "err")
            cleanup(function()
                errors:revert()
            end)
            refused(four_rows(), function()
                tap(one({ kind = "arrow", row = 2, direction = "up" }).rect)
            end, "Couldn't save the layout.", function()
                replace(Settings, "set", function()
                    return false, "kopanda-test: disk full"
                end)
            end)
            assert.spy(errors).was.called()
            assert.equals("Row 1 · two columns", one({ kind = "card", row = 1 }).control.caption)
        end)
    end)

    describe("pickers", function()
        it("grey Add column on a row of three columns, though a widget is unused", function()
            open({ { slot("date"), slot("clock"), slot("weather") }, { slot("featured") }, { slot("quote") },
                { slot("launcher") } })
            tap_card(1)
            assert.is_true(one({ kind = "button", label = "Add column" }).control.disabled)
        end)

        it("grey Add row on a home with every widget, and a tap on it opens nothing", function()
            open()
            local add = one({ kind = "button", label = "Add row" })
            assert.is_true(add.control.disabled)
            tap(add.rect)
            assert.is_nil(Sheet.shown)
            assert.equals(Editor.shown, harness.top())
        end)

        it("list the column's widget ticked, then the unused ones, to change a widget", function()
            open(four_rows())
            tap_card(2)
            tap_button("Change widget")
            assert.same({ "Featured book ✓", "Weather", "Reading stats" }, sheet_rows())
            -- The ticked row closes the sheet and changes nothing.
            pick("Featured book")
            assert.is_nil(Sheet.shown)
            assert.same(four_rows(), stored())
        end)
    end)

    it("closes on Done onto the home", function()
        local editor = open()
        tap(editor.done)
        assert.is_nil(Editor.shown)
        assert.equals(Home.shown, harness.top())
    end)
end)
