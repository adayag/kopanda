-- The Contents and Bookmarks lists' model: the reader's TOC (frontend/apps/reader/modules/readertoc.lua:160-175,
-- :383-406) and its bookmarks, the annotations with no drawer (readerbookmark.lua:417-440), read as lists; the jumps
-- and the removal go through KOReader's own calls, as its TOC and bookmark lists make them (HOOKS.md, "The focused
-- panel").
local Event = require("ui/event")

local GotoList = {}

local function paging(ui)
    return ui.document.info.has_pages and true or false
end

-- The TOC of ui as { rows, current }: rows[i] is { title, depth, page, xpointer, index, page_label, parent,
-- has_children }, depth counted from the shallowest entry's, page_label the page as the footer and the bookmark list
-- label it, which takes a rolling document's xpointer or a paging one's page (readerbookmark.lua:628-643), parent the
-- index of the nearest shallower entry before it (nil at the top), has_children whether the next entry is deeper;
-- current is the index of the entry holding the current position at any level, nil outside every entry. An empty
-- TOC gives { rows = {} }.
function GotoList.chapters(ui)
    local toc = ui.toc
    toc:fillToc()
    local items = toc.toc or {}
    if #items == 0 then
        return { rows = {} }
    end
    local top = math.huge
    for _, item in ipairs(items) do
        top = math.min(top, item.depth)
    end
    local rows, open = {}, {}
    for i, item in ipairs(items) do
        while #open > 0 and items[open[#open]].depth >= item.depth do
            open[#open] = nil
        end
        rows[i] = { title = toc:cleanUpTocTitle(item.title, true), depth = item.depth - top, page = item.page,
            xpointer = item.xpointer, index = i, parent = open[#open],
            has_children = items[i + 1] ~= nil and items[i + 1].depth > item.depth,
            page_label = ui.bookmark:getBookmarkPageString(item.xpointer or item.page) }
        open[#open + 1] = i
    end
    local where = paging(ui) and ui:getCurrentPage() or ui.document:getXPointer()
    return { rows = rows, current = toc:getTocIndexByPage(where) }
end

-- The bookmarks of ui newest first, each { item, chapter, page_label }: item is KOReader's annotation, chapter
-- "No chapter" where it has none, page_label as KOReader's bookmark list labels the page.
function GotoList.bookmarks(ui)
    local entries = {}
    for i, item in ipairs(ui.annotation.annotations) do
        if not item.drawer then
            local chapter = item.chapter
            if chapter == nil or chapter == "" then
                chapter = "No chapter"
            end
            entries[#entries + 1] = { item = item, chapter = chapter,
                page_label = ui.bookmark:getBookmarkPageString(item.page), order = i }
        end
    end
    table.sort(entries, function(a, b)
        local ad, bd = a.item.datetime or "", b.item.datetime or ""
        if ad ~= bd then
            return ad > bd
        end
        return a.order > b.order
    end)
    for _, entry in ipairs(entries) do
        entry.order = nil
    end
    return entries
end

-- Goes to row's chapter as the TOC list does (readertoc.lua:940-948), the place left pushed on the location stack.
function GotoList.jump_chapter(ui, row)
    ui.link:addCurrentLocationToStack()
    if row.xpointer then
        ui:handleEvent(Event:new("GotoXPointer", row.xpointer, row.xpointer))
    else
        ui:handleEvent(Event:new("GotoPage", row.page))
    end
end

-- Goes to entry's bookmark as the bookmark list does (readerbookmark.lua:765-766).
function GotoList.jump_bookmark(ui, entry)
    ui.link:addCurrentLocationToStack()
    ui.bookmark:gotoBookmark(entry.item.page, entry.item.pos0)
end

-- Removes entry's bookmark at its index among the annotations, the dogear updated (readerbookmark.lua:446-455);
-- nothing when it is no longer there, since removeItemByIndex(nil) would drop the last annotation (:456-457).
function GotoList.remove_bookmark(ui, entry)
    local index = ui.annotation:getItemIndex(entry.item)
    if index then
        ui.bookmark:removeItem(entry.item, index)
    end
end

return GotoList
