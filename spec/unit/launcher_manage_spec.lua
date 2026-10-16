-- Launcher management (device menus' C9): launcher.entries as a list in the editor frame over a
-- shown home, its rows, arrows and remove, a folder's own list, adding by kind, a list too long
-- for another entry and a refused write. Each case stores the board's six (Library, Series,
-- Authors, History, a Tools folder of three actions, Settings) in a real settings file first;
-- EntryPicker.pick is stubbed where a case adds.
describe("launcher management", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local ConfirmBox = require("ui/widget/confirmbox")
    local Dispatcher = require("dispatcher")
    local Event = require("ui/event")
    local InfoMessage = require("ui/widget/infomessage")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local Editor, EntryPicker, Home, LauncherManage, Looks, Settings

    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
    end

    local ACTIONS = { "kopanda_spec_manage_a", "kopanda_spec_manage_b", "kopanda_spec_manage_c" }

    local function action(id, label)
        return { kind = "action", action = id, label = label or id, icon = "action" }
    end

    local LIBRARY = { kind = "kopanda", target = "library" }
    local SERIES = { kind = "kopanda", target = "series" }
    local AUTHORS = { kind = "kopanda", target = "authors" }
    local HISTORY = { kind = "koreader", target = "history" }
    local SETTINGS = { kind = "kopanda", target = "settings" }
    -- What the stubbed picker hands back.
    local PICKED = { kind = "action", action = "kopanda_spec_manage_a", label = "Picked", icon = "action" }

    local function tools()
        return { kind = "folder", label = "Tools", entries = {
            action(ACTIONS[1], "Terminal"), action(ACTIONS[2], "Sync"), action(ACTIONS[3], "Screenshot"),
        } }
    end

    local function board()
        return { LIBRARY, SERIES, AUTHORS, HISTORY, tools(), SETTINGS }
    end

    local function settings_bytes()
        local f = io.open(harness.settings_file, "rb")
        if not f then
            return false
        end
        local bytes = f:read("*a")
        f:close()
        return bytes
    end

    -- launcher.entries as the file holds it now, read afresh.
    local function stored()
        Settings._reset()
        return Settings.get("launcher.entries")
    end

    local function centre(rect)
        return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
    end

    local function tap_rect(rect)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", centre(rect))))
    end

    -- The editor's place for the control named name (with index i when given), or nil.
    local function place(name, i)
        for _, p in ipairs(Editor.shown.places) do
            if p.control.name == name and (i == nil or p.control.index == i) then
                return p
            end
        end
    end

    local function tap(name, i)
        local p = place(name, i)
        assert.is_table(p, "no control " .. name .. " " .. tostring(i))
        tap_rect(p.rect)
    end

    -- The kind button for kind.
    local function kind_button(kind)
        for _, p in ipairs(Editor.shown.places) do
            if p.control.name == "kind" and p.control.entry_kind == kind then
                return p
            end
        end
    end

    -- The rows' controls, in order.
    local function rows()
        local out = {}
        for _, p in ipairs(Editor.shown.places) do
            if p.control.name == "entry" then
                out[#out + 1] = p.control
            end
        end
        return out
    end

    local function labels()
        local out = {}
        for i, row in ipairs(rows()) do
            out[i] = row.label
        end
        return out
    end

    local function tap_done()
        tap_rect(Editor.shown.done)
    end

    -- The widget on the stack whose class is class, or nil.
    local function shown(class)
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == class then
                return widget
            end
        end
    end

    -- Stores entries, shows the file manager with its home and opens launcher management with
    -- opts. Returns the editor.
    local function open(entries, opts)
        assert.is_true(Settings.set("launcher.entries", entries))
        harness.show_fm()
        harness.tick(2)
        assert.equals(Home.shown, harness.top())
        LauncherManage.open(opts or {})
        local editor = Editor.shown
        assert.is_not_nil(editor)
        assert.equals(editor, harness.top())
        return editor
    end

    -- Counts, from now until the case ends: writes through Settings.set, the shown home's
    -- refreshes and the editor's repaints asked through setDirty.
    local function counters(editor)
        local counts = { writes = 0, refreshes = 0, repaints = 0 }
        local set, refresh, dirty = Settings.set, Home.shown.refresh, UIManager.setDirty
        Settings.set = function(...)
            counts.writes = counts.writes + 1
            return set(...)
        end
        local home = Home.shown
        home.refresh = function(...)
            counts.refreshes = counts.refreshes + 1
            return refresh(...)
        end
        UIManager.setDirty = function(self, widget, ...)
            if widget == editor then
                counts.repaints = counts.repaints + 1
            end
            return dirty(self, widget, ...)
        end
        cleanup(function()
            Settings.set = set
            home.refresh = nil
            UIManager.setDirty = dirty
        end)
        return counts
    end

    -- EntryPicker.pick stubbed to hand back PICKED at once; returns its calls.
    local function stub_pick()
        local calls = {}
        local pick = EntryPicker.pick
        EntryPicker.pick = function(kind, ctx, on_entry)
            calls[#calls + 1] = { kind = kind, ctx = ctx }
            on_entry(PICKED)
        end
        cleanup(function()
            EntryPicker.pick = pick
        end)
        return calls
    end

    before_each(function()
        harness.load()
        Editor = require("editor")
        EntryPicker = require("entry_picker")
        Home = require("home")
        LauncherManage = require("launcher_manage")
        Looks = require("looks")
        Settings = require("settings")
        for _, id in ipairs(ACTIONS) do
            Dispatcher:registerAction(id, { category = "none", event = "KoPandaSpecManage", title = id,
                general = true })
        end
    end)

    after_each(function()
        for i = #cleanups, 1, -1 do
            cleanups[i]()
        end
        cleanups = {}
        for _, id in ipairs(ACTIONS) do
            Dispatcher:removeAction(id)
        end
        harness.teardown()
    end)

    describe("the top level", function()
        it("heads the screen N of 6 on the home screen over Launcher", function()
            local editor = open(board())
            assert.equals("launcher", editor.spec.screen)
            assert.equals("6 of 6 on the home screen", editor.spec.aside)
            assert.equals("Launcher", editor.spec.title)
            -- All six rows fit on the unit screen above the pinned foot, Settings included.
            assert.equals(0, editor.left_out)
            assert.equals(6, #rows())
        end)

        it("shows a row per entry with its resolved icon, label and kind line", function()
            open(board())
            local got = {}
            for i, row in ipairs(rows()) do
                got[i] = { row.icon, row.label, row.line, row.muted }
            end
            assert.same({
                { "library", "Library", "KoPanda · library", false },
                { "series", "Series", "KoPanda · series", false },
                { "authors", "Authors", "KoPanda · authors", false },
                { "history", "History", "KOReader · history", false },
                { "folder", "Tools", "Folder · 3 entries ›", false },
                { "settings", "Settings", "KoPanda · settings", false },
            }, got)
        end)

        it("greys the first entry's up and the last entry's down, and no other arrow", function()
            open(board())
            for i = 1, 6 do
                assert.equals(i == 1, place("up", i).control.disabled == true, "up " .. i)
                assert.equals(i == 6, place("down", i).control.disabled == true, "down " .. i)
                assert.is_falsy(place("remove", i).control.disabled, "remove " .. i)
            end
        end)

        it("offers the five kinds, two to a row, and the folder note", function()
            open(board())
            local kinds, at = {}, {}
            for _, p in ipairs(Editor.shown.places) do
                if p.control.name == "kind" then
                    kinds[#kinds + 1] = p.control.entry_kind
                    at[#at + 1] = p.rect
                end
            end
            assert.same({ "kopanda", "koreader", "directory", "action", "plugin" }, kinds)
            assert.equals(at[1].y, at[2].y)
            assert.truthy(at[3].y > at[1].y)
            assert.equals(at[1].x, at[3].x)
            assert.is_table(place("note"))
            assert.equals("The seventh entry and beyond go into a folder.", place("note").control.text)
        end)

        it("greys an entry whose plugin is missing, with plugin missing for its detail", function()
            open({ LIBRARY, { kind = "plugin", plugin = "kopanda_absent", action = ACTIONS[1], label = "Gone",
                icon = "terminal" } })
            local row = rows()[2]
            assert.same({ "plugin_missing", "Gone", "Plugin · plugin missing", true },
                { row.icon, row.label, row.line, row.muted })
        end)

        it("draws an available row's text in ink and an unavailable one's in none, and greyed arrows", function()
            local editor = open({ LIBRARY, { kind = "plugin", plugin = "kopanda_absent", action = ACTIONS[1],
                label = "Gone", icon = "terminal" } })
            local size = Screen:getSize()
            local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
            finally(function()
                bb:free()
            end)
            bb:fill(Blitbuffer.COLOR_WHITE)
            editor:paintTo(bb, 0, 0)
            local look = Looks.active()
            local palette = Looks.palette(look, Looks.variant())
            local ink = Blitbuffer.colorFromString(palette.ink):getColor8().a
            -- Ink in rect left of right, above the row's rule (Diner's rule is in outline).
            local rule = Screen:scaleBySize(look.editor.row_rule_width)
            local function inked(rect, right)
                local n = 0
                for y = rect.y, rect.y + rect.h - rule - 1 do
                    for x = rect.x, right - 1 do
                        local c = bb:getPixel(x, y):getColorRGB32()
                        if math.abs(c:getR() - ink) <= 8 and math.abs(c:getG() - ink) <= 8
                                and math.abs(c:getB() - ink) <= 8 then
                            n = n + 1
                        end
                    end
                end
                return n
            end
            local first, second = place("entry", 1).rect, place("entry", 2).rect
            assert.truthy(inked(first, place("up", 1).rect.x) > 0, "Library's text in ink")
            assert.equals(0, inked(second, place("up", 2).rect.x))
            -- The greyed up arrow's outline is disabled_color; the live down arrow's is ink.
            local up, down = place("up", 1).rect, place("down", 1).rect
            local function rgb_at(x, y)
                local c = bb:getPixel(x, y):getColorRGB32()
                return { c:getR(), c:getG(), c:getB() }
            end
            local function rgb_of(role)
                local c = Looks.color(palette[role]):getColorRGB32()
                return { c:getR(), c:getG(), c:getB() }
            end
            assert.are_not.same(rgb_of(look.editor.disabled_color), rgb_of(look.editor.button_outline_color))
            assert.same(rgb_of(look.editor.disabled_color), rgb_at(up.x, up.y + math.floor(up.h / 2)))
            assert.same(rgb_of(look.editor.button_outline_color), rgb_at(down.x, down.y + math.floor(down.h / 2)))
        end)

        it("reads an empty launcher as 0 of 6 with no rows, and adds to it", function()
            local editor = open({})
            assert.equals("0 of 6 on the home screen", editor.spec.aside)
            assert.same({}, rows())
            stub_pick()
            tap_rect(kind_button("action").rect)
            assert.same({ PICKED }, stored())
            assert.equals("1 of 6 on the home screen", Editor.shown.spec.aside)
        end)

        it("closes on Done", function()
            open(board())
            tap_done()
            assert.is_nil(Editor.shown)
            assert.equals(Home.shown, harness.top())
        end)
    end)

    describe("moving and removing", function()
        it("moves an entry up with one write, one home refresh and one repaint", function()
            local editor = open(board())
            local counts = counters(editor)
            tap("up", 2)
            assert.same({ writes = 1, refreshes = 1, repaints = 1 }, counts)
            assert.same({ SERIES, LIBRARY, AUTHORS, HISTORY, tools(), SETTINGS }, stored())
            assert.same({ "Series", "Library", "Authors", "History", "Tools", "Settings" }, labels())
            assert.equals(editor, Editor.shown)
        end)

        it("moves an entry down", function()
            local editor = open(board())
            local counts = counters(editor)
            tap("down", 5)
            assert.same({ writes = 1, refreshes = 1, repaints = 1 }, counts)
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS, tools() }, stored())
        end)

        it("does nothing on a greyed arrow", function()
            local editor = open(board())
            local before = settings_bytes()
            local counts = counters(editor)
            tap("up", 1)
            tap("down", 6)
            assert.same({ writes = 0, refreshes = 0, repaints = 0 }, counts)
            assert.equals(before, settings_bytes())
        end)

        it("removes an entry with one write, one home refresh and one repaint, and no question", function()
            local editor = open(board())
            local counts = counters(editor)
            tap("remove", 3)
            assert.same({ writes = 1, refreshes = 1, repaints = 1 }, counts)
            assert.is_nil(shown(ConfirmBox))
            assert.same({ LIBRARY, SERIES, HISTORY, tools(), SETTINGS }, stored())
            assert.equals("5 of 6 on the home screen", Editor.shown.spec.aside)
        end)

        it("asks before removing a folder: Cancel leaves the file as it was", function()
            local editor = open(board())
            local before = settings_bytes()
            local counts = counters(editor)
            tap("remove", 5)
            local box = shown(ConfirmBox)
            assert.is_not_nil(box)
            assert.equals(box, harness.top())
            assert.equals("Remove Tools and its 3 entries?", box.text)
            assert.equals("Remove", box.ok_text)
            assert.equals(0, counts.writes)
            box:onClose()
            assert.is_nil(shown(ConfirmBox))
            assert.equals(0, counts.writes)
            assert.equals(before, settings_bytes())
            assert.equals(editor, harness.top())
        end)

        it("asks before removing a folder: Remove removes it with its entries", function()
            local editor = open(board())
            local counts = counters(editor)
            tap("remove", 5)
            local box = shown(ConfirmBox)
            -- As its Remove button does (frontend/ui/widget/confirmbox.lua:116-121); the box's
            -- own close then marks the editor under it dirty, as any dialog's does.
            box.ok_callback()
            assert.same({ writes = 1, refreshes = 1, repaints = 1 }, counts)
            UIManager:close(box)
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS }, stored())
            assert.same({ "Library", "Series", "Authors", "History", "Settings" }, labels())
        end)
    end)

    describe("a folder's list", function()
        it("opens from a tap on the folder's row, headed Folder · N over its label", function()
            local editor = open(board())
            tap("entry", 5)
            assert.equals(editor, Editor.shown)
            assert.equals("Folder · 3", editor.spec.aside)
            assert.equals("Tools", editor.spec.title)
            assert.same({ "Terminal", "Sync", "Screenshot" }, labels())
            assert.equals("Action · " .. ACTIONS[2], rows()[2].line)
            assert.is_nil(place("note"))
            assert.is_table(kind_button("plugin"))
        end)

        it("does nothing on a tap on another entry's row", function()
            local editor = open(board())
            local counts = counters(editor)
            tap("entry", 1)
            assert.equals("Launcher", editor.spec.title)
            assert.same({ writes = 0, refreshes = 0, repaints = 0 }, counts)
        end)

        it("returns to the top level on Done", function()
            local editor = open(board())
            tap("entry", 5)
            tap_done()
            assert.equals(editor, Editor.shown)
            assert.equals("Launcher", editor.spec.title)
            assert.equals("6 of 6 on the home screen", editor.spec.aside)
            assert.equals(6, #rows())
            tap_done()
            assert.is_nil(Editor.shown)
        end)

        it("moves within the folder", function()
            open(board())
            tap("entry", 5)
            tap("down", 1)
            local folder = stored()[5]
            assert.same({ "Sync", "Terminal", "Screenshot" },
                { folder.entries[1].label, folder.entries[2].label, folder.entries[3].label })
            assert.same({ "Sync", "Terminal", "Screenshot" }, labels())
        end)

        it("removes its entries one at a time, the last taking the folder and showing the top level", function()
            local editor = open(board())
            tap("entry", 5)
            local counts = counters(editor)
            tap("remove", 1)
            assert.equals("Folder · 2", editor.spec.aside)
            tap("remove", 1)
            assert.equals("Folder · 1", editor.spec.aside)
            assert.same({ "Screenshot" }, labels())
            tap("remove", 1)
            assert.same({ writes = 3, refreshes = 3, repaints = 3 }, counts)
            assert.is_nil(shown(ConfirmBox))
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS }, stored())
            assert.equals("Launcher", editor.spec.title)
            assert.equals("5 of 6 on the home screen", editor.spec.aside)
            assert.same({ "Library", "Series", "Authors", "History", "Settings" }, labels())
            tap_done()
            assert.is_nil(Editor.shown)
        end)

        it("opens from opts.folder, and its Done then closes", function()
            local editor = open(board(), { folder = 5 })
            assert.equals("Tools", editor.spec.title)
            tap_done()
            assert.is_nil(Editor.shown)
        end)

        it("opens the top level for an opts.folder past the list or not a folder", function()
            assert.equals("Launcher", open(board(), { folder = 9 }).spec.title)
            harness.teardown()
            harness.load()
            Settings = require("settings")
            Editor = require("editor")
            Home = require("home")
            LauncherManage = require("launcher_manage")
            assert.equals("Launcher", open(board(), { folder = 2 }).spec.title)
        end)
    end)

    describe("adding", function()
        it("puts the entry at the end of the first folder of a full top level", function()
            local editor = open(board())
            local calls = stub_pick()
            local counts = counters(editor)
            local ctx = editor.ctx
            tap_rect(kind_button("action").rect)
            assert.equals(1, #calls)
            assert.equals("action", calls[1].kind)
            assert.equals(ctx, calls[1].ctx)
            assert.same({ writes = 1, refreshes = 1, repaints = 1 }, counts)
            local folder = stored()[5]
            assert.equals(4, #folder.entries)
            assert.same(PICKED, folder.entries[4])
            assert.equals("Folder · 4 entries ›", rows()[5].line)
        end)

        it("adds a sixth at the end, then makes the sixth and a seventh a folder More", function()
            open(board())
            tap("remove", 5)
            local box = shown(ConfirmBox)
            box.ok_callback()
            UIManager:close(box)
            stub_pick()
            tap_rect(kind_button("koreader").rect)
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS, PICKED }, stored())
            tap_rect(kind_button("koreader").rect)
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS,
                { kind = "folder", label = "More", entries = { PICKED, PICKED } } }, stored())
            assert.equals("6 of 6 on the home screen", Editor.shown.spec.aside)
        end)

        it("adds inside a folder's list into that folder", function()
            local editor = open({ LIBRARY, { kind = "folder", label = "Mine", entries = { SERIES } }, tools() })
            tap("entry", 3)
            stub_pick()
            tap_rect(kind_button("plugin").rect)
            local entries = stored()
            assert.same({ SERIES }, entries[2].entries)
            assert.equals(4, #entries[3].entries)
            assert.same(PICKED, entries[3].entries[4])
            assert.equals("Folder · 4", editor.spec.aside)
            assert.equals("Tools", editor.spec.title)
        end)
    end)

    describe("a list with no room", function()
        local function long(n)
            local entries = {}
            for i = 1, n do
                entries[i] = action(ACTIONS[1], "Entry " .. i)
            end
            return { kind = "folder", label = "Long", entries = entries }
        end

        -- How many rows a folder's list holds on this screen: the rows a 40-entry folder keeps.
        local function capacity()
            local editor = open({ long(40) }, { folder = 1 })
            assert.truthy(editor.left_out > 0)
            local kept = 40 - editor.left_out
            harness.teardown()
            harness.load()
            Settings = require("settings")
            Editor = require("editor")
            EntryPicker = require("entry_picker")
            Home = require("home")
            LauncherManage = require("launcher_manage")
            return kept
        end

        -- Opens the folder's list of n entries, taps a kind button and returns pick's calls.
        local function add_to(n)
            open({ long(n) }, { folder = 1 })
            local before = settings_bytes()
            local calls = stub_pick()
            tap_rect(kind_button("action").rect)
            return calls, before
        end

        it("refuses another entry with its note when the frame left a row out", function()
            local calls, before = add_to(40)
            assert.truthy(Editor.shown.left_out > 0)
            assert.same({}, calls)
            local top = harness.top()
            assert.equals(InfoMessage, getmetatable(top))
            assert.equals("There's no room for another entry here.", top.text)
            assert.equals(before, settings_bytes())
        end)

        it("refuses when every row fits but one more wouldn't, and takes one when it would", function()
            local n = capacity()
            local calls, before = add_to(n)
            assert.equals(0, Editor.shown.left_out)
            assert.same({}, calls)
            assert.equals("There's no room for another entry here.", harness.top().text)
            assert.equals(before, settings_bytes())
            harness.teardown()
            harness.load()
            Settings = require("settings")
            Editor = require("editor")
            EntryPicker = require("entry_picker")
            Home = require("home")
            LauncherManage = require("launcher_manage")
            calls = add_to(n - 1)
            assert.equals(1, #calls)
            assert.equals(n, #stored()[1].entries)
        end)

        it("refuses the overflow into a full first folder from the top level", function()
            local n = capacity()
            open({ LIBRARY, SERIES, long(n), AUTHORS, HISTORY, SETTINGS })
            local before = settings_bytes()
            local calls = stub_pick()
            tap_rect(kind_button("action").rect)
            assert.same({}, calls)
            assert.equals("There's no room for another entry here.", harness.top().text)
            assert.equals(before, settings_bytes())
        end)
    end)

    it("shows its note and changes nothing when the write is refused", function()
        local editor = open(board())
        local before = settings_bytes()
        local home = Home.shown
        local refresh = spy.on(home, "refresh")
        local set = Settings.set
        Settings.set = function()
            return false, "kopanda-test: refused"
        end
        cleanup(function()
            Settings.set = set
        end)
        tap("up", 2)
        local top = harness.top()
        assert.equals(InfoMessage, getmetatable(top))
        assert.equals("Couldn't save the launcher.", top.text)
        assert.equals(before, settings_bytes())
        assert.spy(refresh).was_not.called()
        assert.equals("Library", rows()[1].label)
        assert.equals(editor, Editor.shown)
    end)
end)
