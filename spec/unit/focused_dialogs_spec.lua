-- The focused panel's dialogs: Find in book and Go to page in KOReader's InputDialog over a fake reader on page 12 of
-- 300 that records what reaches it. The keyboard is checked by its call: headless, it never reports itself visible.
describe("the focused dialogs", function()
    local harness = require("plugin_harness")
    local InputDialog = require("ui/widget/inputdialog")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local FocusedDialogs

    local restores = {}
    local function replace(t, key, value)
        local old = rawget(t, key)
        restores[#restores + 1] = function()
            rawset(t, key, old)
        end
        rawset(t, key, value)
    end

    before_each(function()
        harness.load()
        FocusedDialogs = require("focused_dialogs")
    end)

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        restores = {}
        harness.teardown()
    end)

    -- A reader whose search, location stack and events land in its calls, in order; opts.labels, a map of a clean
    -- label to its rendered page, gives it a page map showing them.
    local function fake_ui(opts)
        opts = opts or {}
        local calls = {}
        local ui = {
            calls = calls,
            document = {
                getPageCount = function()
                    return 300
                end,
            },
            search = {
                searchCallback = function(_, ...)
                    calls[#calls + 1] = { "search", select("#", ...), ... }
                end,
            },
            link = {
                addCurrentLocationToStack = function()
                    calls[#calls + 1] = { "stack" }
                end,
            },
        }
        function ui:getCurrentPage()
            return 12
        end
        function ui:handleEvent(event)
            local call = { event.handler:sub(3) }
            for i = 1, event.args.n do
                call[#call + 1] = event.args[i]
            end
            calls[#calls + 1] = call
            return true
        end
        if opts.pagemap_off or opts.labels then
            ui.pagemap = {
                wantsPageLabels = function()
                    return opts.labels ~= nil
                end,
                getCurrentPageLabel = function(_, clean)
                    return clean and "xii" or "Page xii"
                end,
                getFirstPageLabel = function(_, clean)
                    return clean and "i" or "Page i"
                end,
                getLastPageLabel = function(_, clean)
                    return clean and "280" or "Page 280"
                end,
                cleanPageLabel = function(_, label)
                    return (label:gsub("^Page%s*", ""))
                end,
                getPageLabelProps = function(_, label)
                    local page = opts.labels and opts.labels[label]
                    if page then
                        return 1, page
                    end
                end,
            }
        end
        return ui
    end

    -- Every error logged for the rest of the test, each as its parts joined.
    local function logged()
        local errors = {}
        replace(logger, "err", function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[i] = tostring(select(i, ...))
            end
            errors[#errors + 1] = table.concat(parts, " ")
        end)
        return errors
    end

    -- The dialog open(ui) shows, checked to have its keyboard up.
    local function dialog_of(open, ui)
        local keyboard_for = {}
        local show_keyboard = InputDialog.onShowKeyboard
        replace(InputDialog, "onShowKeyboard", function(self, ...)
            keyboard_for[#keyboard_for + 1] = self
            return show_keyboard(self, ...)
        end)
        open(ui)
        local dialog = harness.top()
        assert.equals(InputDialog, getmetatable(dialog))
        assert.same({ dialog }, keyboard_for)
        return dialog
    end

    local function press(dialog, text)
        for _, button in ipairs(dialog.buttons[1]) do
            if button.text == text then
                return button.callback()
            end
        end
        error("no button " .. text)
    end

    local function is_shown(dialog)
        return UIManager:isWidgetShown(dialog) and true or false
    end

    describe("Find in book", function()
        local function find(ui)
            return dialog_of(FocusedDialogs.find, ui)
        end

        it("offers Cancel as its close and Find on Enter, and nothing else", function()
            local dialog = find(fake_ui())
            assert.equals("Find in book", dialog.title)
            assert.equals(1, #dialog.buttons)
            assert.equals(2, #dialog.buttons[1])
            local cancel, go = dialog.buttons[1][1], dialog.buttons[1][2]
            assert.same({ "Cancel", "close" }, { cancel.text, cancel.id })
            assert.same({ "Find", true }, { go.text, go.is_enter_default })
        end)

        it("closes the dialog, then searches with no direction for the text as typed", function()
            local ui = fake_ui()
            local dialog = find(ui)
            local open_at_search
            ui.search.searchCallback = function(_, reverse, text)
                open_at_search = is_shown(dialog)
                ui.calls[#ui.calls + 1] = { "search", reverse == nil, text }
            end
            dialog:setInputText("the whale")
            press(dialog, "Find")
            assert.is_false(is_shown(dialog))
            assert.is_false(open_at_search)
            assert.same({ { "search", true, "the whale" } }, ui.calls)
        end)

        it("searches for the keyboard's combining marks composed, as KOReader's own dialog does", function()
            local ui = fake_ui()
            local dialog = find(ui)
            local searched
            ui.search.searchCallback = function(_, _, text)
                searched = text
            end
            dialog:setInputText("e\u{301}")
            press(dialog, "Find")
            assert.equals("\u{e9}", searched)
        end)

        it("closes and searches for nothing on empty text or only spaces, or on Cancel", function()
            for _, case in ipairs({ { "", "Find" }, { "   ", "Find" }, { "whale", "Cancel" } }) do
                local ui = fake_ui()
                local dialog = find(ui)
                dialog:setInputText(case[1])
                press(dialog, case[2])
                assert.is_false(is_shown(dialog), case[2])
                assert.same({}, ui.calls, case[2])
            end
        end)

        it("logs and closes the dialog when the search raises", function()
            local ui = fake_ui()
            local dialog = find(ui)
            local errors = logged()
            ui.search.searchCallback = function()
                error("kopanda-test: the search failed")
            end
            dialog:setInputText("whale")
            assert.has_no.errors(function()
                press(dialog, "Find")
            end)
            assert.is_false(is_shown(dialog))
            assert.equals(1, #errors)
            assert.truthy(errors[1]:find("the search failed", 1, true))
        end)
    end)

    describe("Go to page", function()
        local function go_to(ui)
            return dialog_of(FocusedDialogs.go_to, ui)
        end

        it("asks for a number, hints the page and the count, and offers Cancel and Go", function()
            local dialog = go_to(fake_ui())
            assert.equals("Go to page", dialog.title)
            assert.equals("number", dialog.input_type)
            assert.equals("Page 12 of 300", dialog.input_hint)
            assert.equals(1, #dialog.buttons)
            assert.equals(2, #dialog.buttons[1])
            local cancel, go = dialog.buttons[1][1], dialog.buttons[1][2]
            assert.same({ "Cancel", "close" }, { cancel.text, cancel.id })
            assert.same({ "Go", true }, { go.text, go.is_enter_default })
        end)

        it("goes to the first and the last page, keeping the current place on the stack first", function()
            for _, page in ipairs({ 1, 300 }) do
                local ui = fake_ui()
                local dialog = go_to(ui)
                dialog:setInputText(tostring(page))
                press(dialog, "Go")
                assert.is_false(is_shown(dialog), page)
                assert.same({ { "stack" }, { "GotoPage", page } }, ui.calls, page)
            end
        end)

        it("stays open and goes nowhere for 0, one past the last page, nothing typed, or no plain number", function()
            for _, text in ipairs({ "0", "301", "", "   ", "+5", "-5", "1.5", "0x10", "1e2", "chapter" }) do
                local ui = fake_ui()
                local dialog = go_to(ui)
                dialog:setInputText(text)
                press(dialog, "Go")
                assert.is_true(is_shown(dialog), text)
                assert.same({}, ui.calls, text)
                UIManager:close(dialog)
            end
        end)

        it("closes and goes nowhere on Cancel", function()
            local ui = fake_ui()
            local dialog = go_to(ui)
            dialog:setInputText("5")
            press(dialog, "Cancel")
            assert.is_false(is_shown(dialog))
            assert.same({}, ui.calls)
        end)

        it("reads plain pages when the book has a page map that isn't shown", function()
            local ui = fake_ui{ pagemap_off = true }
            local dialog = go_to(ui)
            assert.equals("Page 12 of 300", dialog.input_hint)
            dialog:setInputText("5")
            press(dialog, "Go")
            assert.same({ { "stack" }, { "GotoPage", 5 } }, ui.calls)
        end)

        describe("with page labels", function()
            local LABELS = { xii = 30, ["7"] = 19 }

            it("hints the current, first and last labels", function()
                local dialog = go_to(fake_ui{ labels = LABELS })
                assert.equals("Page xii (i to 280)", dialog.input_hint)
            end)

            it("goes to a label's rendered page, its noise cleaned", function()
                for text, page in pairs({ ["7"] = 19, ["Page xii"] = 30 }) do
                    local ui = fake_ui{ labels = LABELS }
                    local dialog = go_to(ui)
                    dialog:setInputText(text)
                    press(dialog, "Go")
                    assert.is_false(is_shown(dialog), text)
                    assert.same({ { "stack" }, { "GotoPage", page } }, ui.calls, text)
                end
            end)

            it("stays open and goes nowhere for an unknown label or nothing typed", function()
                for _, text in ipairs({ "12", "" }) do
                    local ui = fake_ui{ labels = LABELS }
                    local dialog = go_to(ui)
                    dialog:setInputText(text)
                    press(dialog, "Go")
                    assert.is_true(is_shown(dialog), text)
                    assert.same({}, ui.calls, text)
                    UIManager:close(dialog)
                end
            end)
        end)

        it("logs and closes the dialog when the jump raises", function()
            local ui = fake_ui()
            local dialog = go_to(ui)
            local errors = logged()
            ui.link.addCurrentLocationToStack = function()
                error("kopanda-test: the stack failed")
            end
            dialog:setInputText("5")
            assert.has_no.errors(function()
                press(dialog, "Go")
            end)
            assert.is_false(is_shown(dialog))
            assert.equals(1, #errors)
            assert.truthy(errors[1]:find("the stack failed", 1, true))
        end)
    end)

    describe("a dialog that can't be shown", function()
        local CASES = {
            { "find", "ShowFulltextSearchInput" },
            { "go_to", "ShowGotoDialog" },
        }

        local function no_dialog_left()
            for _, widget in ipairs(harness.stack()) do
                assert.is_not.equals(InputDialog, getmetatable(widget))
            end
        end

        for _, case in ipairs(CASES) do
            local name, event = case[1], case[2]

            it("logs and sends " .. event .. " when " .. name .. "'s dialog raises", function()
                local errors = logged()
                replace(InputDialog, "new", function()
                    error("kopanda-test: no dialog")
                end)
                local ui = fake_ui()
                FocusedDialogs[name](ui)
                assert.same({ { event } }, ui.calls)
                assert.equals(1, #errors)
            end)

            it("closes the dialog, logs and sends " .. event .. " when " .. name .. "'s keyboard raises", function()
                local errors = logged()
                replace(InputDialog, "onShowKeyboard", function()
                    error("kopanda-test: the keyboard failed")
                end)
                local ui = fake_ui()
                FocusedDialogs[name](ui)
                no_dialog_left()
                assert.same({ { event } }, ui.calls)
                assert.equals(1, #errors)
            end)
        end

        it("sends ShowGotoDialog when the hint's read raises", function()
            logged()
            local ui = fake_ui{ labels = {} }
            ui.pagemap.getCurrentPageLabel = function()
                error("kopanda-test: no label")
            end
            FocusedDialogs.go_to(ui)
            no_dialog_left()
            assert.same({ { "ShowGotoDialog" } }, ui.calls)
        end)
    end)
end)
