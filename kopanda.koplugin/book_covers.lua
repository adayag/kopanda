-- The book records' covers: the cached cover read for a box, and the one path that asks CoverBrowser
-- to extract covers, for a batch of records, with its bounded check for their arrival.
--
-- A book with a file has CoverBrowser's cache as its cover cache: one thumbnail per file, scaled
-- down to the box it was extracted for and replaced only when a bigger box needs a bigger one.
-- A path-less book's cover comes from its source, through Books. CoverBrowser is reached through
-- pcall(require, "bookinfomanager"): its folder joins package.path only when the plugin is enabled
-- (frontend/pluginloader.lua:283-287), so a failed require means it is disabled.
-- Module state: asked, the files extraction was asked for in this process; pending, the records of
-- the request in flight whose covers have not arrived; check, the scheduled check or nil.
local Books = require("books")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local BookCovers = {}

-- The checks while an extraction runs, one a second, before giving up.
local MAX_CHECKS = 30

local asked = {}
local pending = {}
local check

-- BookInfoManager, or nil when CoverBrowser is disabled.
local function manager()
    local ok, bim = pcall(require, "bookinfomanager")
    if ok and type(bim) == "table" then
        return bim
    end
    return nil
end

-- getBookInfo(file, get_cover) (bookinfomanager.lua:325-404), or nil on a failure, logged.
local function book_info(bim, file, get_cover)
    local ok, info = pcall(bim.getBookInfo, bim, file, get_cover)
    if not ok then
        logger.err("KoPanda: CoverBrowser's book info failed:", info)
        return nil
    end
    return info
end

-- Whether info's cover, cached or about to be read, suits a box of specs: there is one, the
-- book's cover is not ignored (CoverBrowser draws none for such rows, mosaicmenu.lua:508,
-- listmenu.lua:272), and it is not too small for the box (bookinfomanager.lua:1013-1030).
local function has_fitting_cover(bim, info, specs)
    return info ~= nil and info.has_cover and not info.ignore_cover
        and not bim.isCachedCoverInvalid(info, specs)
end

-- Whether info's cached cover bitmap can be drawn in a box of specs.
local function is_usable(bim, info, specs)
    return has_fitting_cover(bim, info, specs) and info.cover_bb ~= nil
end

-- The cached cover of file for a w by h box, or nil. An unusable bitmap is freed, as
-- mosaicmenu.lua:478-479 does.
local function read_cover(file, w, h)
    local bim = manager()
    if not bim or not file then
        return nil
    end
    local info = book_info(bim, file, true)
    if not info then
        return nil
    end
    local ok, usable = pcall(is_usable, bim, info, { max_cover_w = w, max_cover_h = h })
    if ok and usable then
        return info.cover_bb
    end
    if not ok then
        logger.err("KoPanda: CoverBrowser's cover check failed:", usable)
    end
    if info.cover_bb then
        info.cover_bb:free()
    end
    return nil
end

-- record's cover for a w by h box, a bitmap the caller owns, or nil: a book with a file from
-- CoverBrowser's cache, a path-less one from its source. Never asks for an extraction.
function BookCovers.read(record, w, h)
    if record.path == nil then
        return Books.cover(record, w, h)
    end
    return read_cover(record.path, w, h)
end

-- Whether to ask CoverBrowser to extract a cover for info, its getBookInfo row or nil, in a box
-- of specs ({ max_cover_w, max_cover_h }). Never without CoverBrowser. Otherwise in
-- mosaicmenu.lua:471-488's order: the never-ask rows come before the size test, since
-- isCachedCoverInvalid is true for any row without cover_w (bookinfomanager.lua:1014-1015).
function BookCovers.wants(info, specs)
    local bim = manager()
    if not bim then
        return false
    end
    if info == nil then
        return true
    end
    if info.unsupported or info.ignore_cover or (info.cover_fetched and not info.has_cover) then
        return false
    end
    if not info.cover_fetched then
        return true
    end
    return (info.has_cover and bim.isCachedCoverInvalid(info, specs)) and true or false
end

-- Drops the scheduled check, if any. The files asked stay asked: the extraction itself goes on.
function BookCovers.cancel()
    if check then
        UIManager:unschedule(check)
        check = nil
    end
end

-- The records of records CoverBrowser should extract a cover for in a box of specs, or an empty
-- list when none is new: each with a path not asked for in this process, or still pending, whose
-- row wants says yes to. A pending file is asked again because a new batch ends its extraction;
-- with no new file there is no new batch and it goes on. A failing test is logged and its record
-- left out.
local function wanted(bim, records, specs)
    local in_flight = {}
    for _, record in ipairs(pending) do
        in_flight[record.path] = true
    end
    local list, new = {}, false
    for _, record in ipairs(records) do
        local path = record.path
        if path and (not asked[path] or in_flight[path]) then
            local ok, wants = pcall(BookCovers.wants, book_info(bim, path, false), specs)
            if not ok then
                logger.err("KoPanda: the cover extraction test failed:", wants)
            elseif wants then
                list[#list + 1] = record
                new = new or not in_flight[path]
            end
        end
    end
    return new and list or {}
end

-- Asks CoverBrowser to extract, in one batch, the covers of the records that want one for a box
-- of specs, once per file per process, then checks each second while the extraction runs, at most
-- 30 times. CoverBrowser has no completion event, and polls the same way itself
-- (covermenu.lua:164-175). Each check calls on_arrival(records) once with the records whose cover
-- arrived since the last, and stops at once when alive() is false. One request is in flight at a
-- time: extractInBackground terminates the one before (bookinfomanager.lua:695), so a new request
-- drops its check, forgets its files that hadn't arrived and asks again for those it repeats. The
-- 30th check, the cap, forgets in the same way the files that had not arrived, which the extraction
-- going on may not have reached, so a later request asks for them again; once the extraction has
-- ended, a file that did not arrive stays asked. The home's featured cover, the library and the
-- Series and Authors windows ask through here.
function BookCovers.request(records, specs, on_arrival, alive)
    local bim = manager()
    if not bim then
        return
    end
    local batch = wanted(bim, records, specs)
    if #batch == 0 then
        return
    end
    BookCovers.cancel()
    for _, record in ipairs(pending) do
        asked[record.path] = nil
    end
    pending = {}
    local files = {}
    for i, record in ipairs(batch) do
        asked[record.path] = true
        files[i] = { filepath = record.path, cover_specs = specs }
    end
    local started, launched = pcall(bim.extractInBackground, bim, files)
    if not started or not launched then
        logger.err("KoPanda: CoverBrowser's extraction didn't start:", launched)
        return
    end
    pending = batch
    local runs = 0
    local this_check
    this_check = function()
        if check ~= this_check then
            return
        end
        check = nil
        local done, err = pcall(function()
            runs = runs + 1
            if not alive() then
                return
            end
            -- Each row read without its bitmap: once it holds a cover that fits, it has arrived,
            -- rather than wait for the extraction to end, which is noticed only when CoverBrowser
            -- reaps the process every 10 s (bookinfomanager.lua:139, :627-650).
            local arrived, still = {}, {}
            for _, record in ipairs(pending) do
                if has_fitting_cover(bim, book_info(bim, record.path, false), specs) then
                    arrived[#arrived + 1] = record
                else
                    still[#still + 1] = record
                end
            end
            pending = still
            if #pending > 0 and runs < MAX_CHECKS and bim:isExtractingInBackground() then
                -- Scheduled before on_arrival, so a request it makes replaces this one cleanly.
                check = this_check
                UIManager:scheduleIn(1, this_check)
                if #arrived > 0 then
                    on_arrival(arrived)
                end
                return
            end
            -- The last check: each file still pending read with its cover, its bitmap freed, and at
            -- the cap one that did not arrive forgotten as asked.
            for _, record in ipairs(pending) do
                local info = book_info(bim, record.path, true)
                local usable = info ~= nil and is_usable(bim, info, specs)
                if info and info.cover_bb then
                    info.cover_bb:free()
                end
                if usable then
                    arrived[#arrived + 1] = record
                elseif runs >= MAX_CHECKS then
                    asked[record.path] = nil
                end
            end
            pending = {}
            if #arrived > 0 then
                on_arrival(arrived)
            end
        end)
        if not done then
            if check == this_check then
                UIManager:unschedule(check)
                check = nil
            end
            logger.err("KoPanda: the cover check failed:", err)
        end
    end
    check = this_check
    UIManager:scheduleIn(1, this_check)
end

-- Forgets the files asked for and drops the check, as in a new process. For specs.
function BookCovers.reset()
    BookCovers.cancel()
    asked = {}
    pending = {}
end

return BookCovers
