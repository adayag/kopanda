-- The focused panel's Find in book and Go to page: plain InputDialogs (frontend/ui/widget/inputdialog.lua:583
-- getInputText, :640 onShowKeyboard) over ReaderSearch:searchCallback (frontend/apps/reader/modules/readersearch.lua:
-- 252), ReaderPageMap's labels (readerpagemap.lua:176, :330, :364) and the GotoPage event (readergoto.lua:139-159).
local Event = require("ui/event")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local Utf8Proc = require("ffi/utf8proc")
local logger = require("logger")

local FocusedDialogs = {}

-- Shows the InputDialog fields() describes, with Cancel and a button action.text running action.run(dialog), and its
-- keyboard. A button that raises logs and closes the dialog; a dialog that can't be shown logs and sends KOReader's
-- own event, fallback, so the reader always gets one.
local function ask(ui, fields, action, fallback)
    local dialog
    local function close()
        if dialog and UIManager:isWidgetShown(dialog) then
            pcall(UIManager.close, UIManager, dialog)
        end
    end
    local function guarded(fn)
        return function()
            local ok, err = pcall(fn)
            if not ok then
                logger.err("KoPanda: the focused dialog failed:", err)
                close()
            end
        end
    end
    local ok, err = pcall(function()
        local spec = fields()
        spec.buttons = { {
            {
                text = "Cancel",
                id = "close",
                callback = guarded(function()
                    UIManager:close(dialog)
                end),
            },
            {
                text = action.text,
                is_enter_default = true,
                callback = guarded(function()
                    action.run(dialog)
                end),
            },
        } }
        dialog = InputDialog:new(spec)
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end)
    if not ok then
        logger.err("KoPanda: the focused dialog could not be shown:", err)
        close()
        ui:handleEvent(Event:new(fallback))
    end
end

-- Text goes in as the highlight dialog's does, which skips KOReader's search options
-- (frontend/apps/reader/modules/readersearch.lua:259-261) and the composing of what a keyboard typed, so that's done
-- here as its own dialog does it (:266). findAllText shows its own results (:288-291).
function FocusedDialogs.find(ui)
    ask(ui, function()
        return { title = "Find in book" }
    end, {
        text = "Find",
        run = function(dialog)
            local text = dialog:getInputText()
            UIManager:close(dialog)
            if text:match("%S") then
                ui.search:searchCallback(nil, Utf8Proc.normalize_NFC(text))
            end
        end,
    }, "ShowFulltextSearchInput")
end

local function labelled(ui)
    return ui.pagemap and ui.pagemap:wantsPageLabels()
end

-- As ReaderGoto:onShowGotoDialog reads them (frontend/apps/reader/modules/readergoto.lua:35-41).
local function hint(ui)
    if labelled(ui) then
        local map = ui.pagemap
        return string.format("Page %s (%s to %s)", map:getCurrentPageLabel(true), map:getFirstPageLabel(true),
            map:getLastPageLabel(true))
    end
    return string.format("Page %d of %d", ui:getCurrentPage(), ui.document:getPageCount())
end

-- The rendered page text names, or nil: a label the book has when it shows labels, else a plain number in range.
local function page_of(ui, text)
    if labelled(ui) then
        local _, page = ui.pagemap:getPageLabelProps(ui.pagemap:cleanPageLabel(text))
        return page
    end
    local page = tonumber(text:match("^%s*(%d+)%s*$"))
    if page and page >= 1 and page <= ui.document:getPageCount() then
        return page
    end
end

function FocusedDialogs.go_to(ui)
    ask(ui, function()
        return { title = "Go to page", input_type = "number", input_hint = hint(ui) }
    end, {
        text = "Go",
        run = function(dialog)
            local page = page_of(ui, dialog:getInputText())
            if page then
                ui.link:addCurrentLocationToStack()
                ui:handleEvent(Event:new("GotoPage", page))
                UIManager:close(dialog)
            end
        end,
    }, "ShowGotoDialog")
end

return FocusedDialogs
