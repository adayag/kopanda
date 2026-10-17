-- The book records: every book KoPanda knows, by an id rather than a path. Books with a file are
-- listed from KOReader's home folder with the file browser's own filters, their metadata from
-- CoverBrowser's cache, then the sidecar, then the file name, and flagged placeholder when cwngsync
-- records the file as a book not downloaded yet (cloud_books.lua); books without one come from the
-- sources added here. Read status and progress are read on request, from the sidecar or the
-- source. Only reads: no extraction is asked, and no sidecar, settings file or CoverBrowser row
-- is written. Every read is caught; a failure is logged and that source reads as absent.
-- Module state: the sources, and the progress memo of the sidecars read.
local CloudBooks = require("cloud_books")
local DocSettings = require("docsettings")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local Books = {}

-- The statuses a sidecar's summary.status holds that KoPanda keeps (frontend/ui/widget/booklist.lua:371-378).
local STATUSES = { reading = true, abandoned = true, complete = true }

local sources = {}

-- The progress memo: a book's path to { file, modification, size, progress }, the sidecar file
-- findSidecarFile gave for it, that file's mtime and size, and the progress one open of it read,
-- { status, percent, pages, md5 } only. An entry serves while its file's path, mtime and size
-- hold; one whose book has no sidecar now is dropped when asked. One entry per book path read
-- with a sidecar in the session, a few hundred bytes each, so it isn't pruned: a book moved or
-- removed leaves one entry no path reaches for the rest of the session (Books.reset is for specs).
local reads = {}

-- { read, props }: the doc_props of the open Books.with_progress last made, and the entry of
-- reads that open made, which they serve with while it is still the book's entry; nil before any.
-- One book's, so the memo's entries hold no doc_props (their description is unbounded).
local last_props

-- f(...) caught: its result, or nil with the failure logged as what.
local function try(what, f, ...)
    local ok, result = pcall(f, ...)
    if not ok then
        logger.err("KoPanda: could not read " .. what .. ":", result)
        return nil
    end
    return result
end

local function text(value)
    if type(value) == "string" and value ~= "" then
        return value
    end
end

-- Authors text, several separated by newlines (crengine's join, epubfmt.cpp:1179-1199), as a list
-- of names: each trimmed, runs of white space made one space, empty names dropped.
local function names(value)
    local list = {}
    if type(value) ~= "string" then
        return list
    end
    for line in (value .. "\n"):gmatch("([^\n]*)\n") do
        local name = line:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
        if name ~= "" then
            list[#list + 1] = name
        end
    end
    return list
end

-- The file name without its extension.
local function file_title(path)
    local name = path:match("([^/]*)$")
    return name:match("^(.+)%.[^.]*$") or name
end

-- CoverBrowser's bookinfomanager, or nil when it is disabled: its folder joins package.path only
-- for an enabled plugin (frontend/pluginloader.lua:283-287).
local function manager()
    local ok, bim = pcall(require, "bookinfomanager")
    return ok and bim or nil
end

-- path's CoverBrowser row without a cover (bookinfomanager.lua:325-404), nil for a book not
-- indexed or being indexed; and whether CoverBrowser is enabled.
local function row(path)
    local bim = manager()
    if not bim then
        return nil, false
    end
    return try("CoverBrowser's book info for " .. path, bim.getBookInfo, bim, path, false), true
end

-- path's sidecar, opened light so nothing is written or removed: DocSettings:open removes
-- candidates it finds invalid (frontend/docsettings.lua:282-284). Returns the settings, nil when
-- there is none or it can't be read, and whether a sidecar file was found (hasSidecarFile's test,
-- :151-153), true for one found that can't be read.
local function sidecar(path)
    local file = try("the sidecar of " .. path, DocSettings.findSidecarFile, DocSettings, path)
    if not file then
        return nil, false
    end
    return try("the sidecar of " .. path, DocSettings.openSettingsFile, file), true
end

-- The cover availability of a row, in BookCovers.wants' (and mosaicmenu.lua:471-488's) order.
local function cover_state(info, enabled)
    if not enabled then
        return "none"
    end
    if info == nil then
        return "missing"
    end
    if info.unsupported or info.ignore_cover or (info.cover_fetched and not info.has_cover) then
        return "none"
    end
    if not info.cover_fetched then
        return "missing"
    end
    return "cached"
end

-- The doc_props of path's sidecar, or nil.
local function sidecar_props(path)
    local doc = sidecar(path)
    return doc and doc:readSetting("doc_props")
end

-- The record of the file at path, from one getBookInfo call, then the sidecar, then the file name.
-- The sidecar's doc_props are read always with always_sidecar, else only when the row gives no
-- title or no authors, by props_of(path), sidecar_props when not given; CoverBrowser's fields come
-- first either way, so the record is the same. placeholder = true when CloudBooks.is(index, path),
-- index being CloudBooks.index()'s, and left out otherwise.
local function record(path, always_sidecar, props_of, index)
    local info, enabled = row(path)
    local title = info and text(info.title)
    local authors = names(info and info.authors)
    if always_sidecar or not title or #authors == 0 then
        local props = (props_of or sidecar_props)(path)
        if type(props) == "table" then
            title = title or text(props.title)
            if #authors == 0 then
                authors = names(props.authors)
            end
        end
    end
    return {
        id = "file:" .. (ffiutil.realpath(path) or path),
        source = "file",
        path = path,
        title = title or file_title(path),
        authors = authors,
        series = info and text(info.series),
        series_index = info and tonumber(info.series_index),
        cover = cover_state(info, enabled),
        placeholder = CloudBooks.is(index, path) or nil,
    }
end

-- The records of source, each a copy with the source's name and no path, its cover cached or
-- none; one without an id or title is dropped and logged. A raising books() is logged and gives none.
local function source_books(source)
    local books = try("the books of source " .. tostring(source.name), source.books)
    local records = {}
    if type(books) ~= "table" then
        return records
    end
    for _, book in ipairs(books) do
        if type(book) == "table" and text(book.id) and text(book.title) then
            local copy = {}
            for k, v in pairs(book) do
                copy[k] = v
            end
            copy.source = source.name
            copy.path = nil
            copy.authors = book.authors or {}
            copy.cover = book.cover == "cached" and "cached" or "none"
            records[#records + 1] = copy
        else
            logger.warn("KoPanda: dropped a book of source", tostring(source.name), "without an id or a title:",
                type(book) == "table" and (tostring(book.id) .. " " .. tostring(book.title)) or tostring(book))
        end
    end
    return records
end

-- Every source's records, in the order the sources were added.
local function all_source_books()
    local records = {}
    for _, source in ipairs(sources) do
        for _, book in ipairs(source_books(source)) do
            records[#records + 1] = book
        end
    end
    return records
end

local function home_folder()
    return require("apps/filemanager/filemanagerutil").getHomeFolder()
end

local function trimmed(dir)
    local stripped = dir:gsub("/+$", "")
    return stripped == "" and "/" or stripped
end

local function join(dir, name)
    return dir == "/" and "/" .. name or dir .. "/" .. name
end

local function same_dir(a, b)
    if a == b then
        return true
    end
    local real_a = ffiutil.realpath(a)
    return real_a ~= nil and real_a == ffiutil.realpath(b)
end

-- dir's entries the file browser would list (frontend/ui/widget/filechooser.lua:114-143), as two
-- lists of { name, path } in byte order of name: the folders show_dir keeps, and the files no
-- exclude_files pattern or "._" rule drops that DocumentRegistry:hasProvider accepts, asked with
-- the name as the file manager's filter asks (frontend/apps/filemanager/filemanager.lua:143).
-- Dot names only with FileChooser.show_hidden, read now so the toggle is followed. A folder that
-- can't be read gives nothing, logged.
local function scan(dir)
    local FileChooser = require("ui/widget/filechooser")
    local DocumentRegistry = require("document/documentregistry")
    local folders, files = {}, {}
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if not ok then
        logger.err("KoPanda: could not read the folder", dir, ":", iter)
        return folders, files
    end
    local listed, err = pcall(function()
        for name in iter, dir_obj do
            if name ~= "." and name ~= ".." and (FileChooser.show_hidden or name:sub(1, 1) ~= ".") then
                local path = join(dir, name)
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    if FileChooser:show_dir(name) then
                        folders[#folders + 1] = { name = name, path = path }
                    end
                elseif mode == "file" and name:sub(1, 2) ~= "._" then
                    local excluded = false
                    for _, pattern in ipairs(FileChooser.exclude_files) do
                        if name:match(pattern) then
                            excluded = true
                            break
                        end
                    end
                    if not excluded and DocumentRegistry:hasProvider(name) then
                        files[#files + 1] = { name = name, path = path }
                    end
                end
            end
        end
    end)
    if not listed then
        logger.err("KoPanda: could not list the folder", dir, ":", err)
    end
    local function by_name(a, b)
        return a.name < b.name
    end
    table.sort(folders, by_name)
    table.sort(files, by_name)
    return folders, files
end

-- { books, folders }: the records of the files directly in dir and a { name, path } per sub-folder
-- the filters keep, each in byte order of name; the library root's source records after its own.
function Books.folder(dir)
    dir = trimmed(dir)
    local folders, files = scan(dir)
    local books, index = {}, CloudBooks.index()
    for _, file in ipairs(files) do
        books[#books + 1] = record(file.path, false, nil, index)
    end
    if same_dir(dir, trimmed(home_folder())) then
        for _, book in ipairs(all_source_books()) do
            books[#books + 1] = book
        end
    end
    local kept = {}
    for _, folder in ipairs(folders) do
        kept[#kept + 1] = { name = folder.name, path = folder.path }
    end
    return { books = books, folders = kept }
end

-- The books directly in dir as Books.folder lists them, without their records, for counting: each
-- file a { path }, which Books.progress takes, in byte order of name; the library root's source
-- records after its own. No CoverBrowser row, sidecar or realpath is read for a file.
function Books.files(dir)
    dir = trimmed(dir)
    local _, files = scan(dir)
    local books = {}
    for _, file in ipairs(files) do
        books[#books + 1] = { path = file.path }
    end
    if same_dir(dir, trimmed(home_folder())) then
        for _, book in ipairs(all_source_books()) do
            books[#books + 1] = book
        end
    end
    return books
end

-- Every book under the library root: each folder's books, then its sub-folders in turn, then the
-- sources' books. Each folder is visited once by its realpath and each id listed once.
function Books.all()
    local list, visited, seen, index = {}, {}, {}, CloudBooks.index()
    local function add(book)
        if not seen[book.id] then
            seen[book.id] = true
            list[#list + 1] = book
        end
    end
    local function walk(dir)
        local real = ffiutil.realpath(dir) or dir
        if visited[real] then
            return
        end
        visited[real] = true
        local folders, files = scan(dir)
        for _, file in ipairs(files) do
            add(record(file.path, false, nil, index))
        end
        for _, folder in ipairs(folders) do
            walk(folder.path)
        end
    end
    walk(trimmed(home_folder()))
    for _, book in ipairs(all_source_books()) do
        add(book)
    end
    return list
end

-- The record of the file at path, or nil when path is not a file. Its sidecar is always read, so
-- a sidecar that can't be read is logged even when CoverBrowser's row is complete.
function Books.for_path(path)
    if type(path) ~= "string" or lfs.attributes(path, "mode") ~= "file" then
        return nil
    end
    return record(path, true, nil, CloudBooks.index())
end

-- The record with id, or nil: a file's by its path, a source's from that source.
function Books.get(id)
    if type(id) ~= "string" then
        return nil
    end
    local path = id:match("^file:(.+)$")
    if path then
        return Books.for_path(path)
    end
    for _, source in ipairs(sources) do
        if type(source.name) == "string" and id:sub(1, #source.name + 1) == source.name .. ":" then
            for _, book in ipairs(source_books(source)) do
                if book.id == id then
                    return book
                end
            end
        end
    end
    return nil
end

-- The pages the sidecar records, in BookList's order (frontend/ui/widget/booklist.lua:298-306):
-- pagemap_doc_pages with page labels on, else doc_pages, else stats.pages unless 0.
local function sidecar_pages(doc)
    local pages = doc:isTrue("pagemap_use_page_labels") and doc:readSetting("pagemap_doc_pages")
        or doc:readSetting("doc_pages")
    if pages == nil then
        local stats = doc:readSetting("stats")
        if type(stats) == "table" and stats.pages and stats.pages ~= 0 then
            pages = stats.pages
        end
    end
    return tonumber(pages)
end

-- The progress of a book whose sidecar's settings are doc, exists whether a sidecar file was found,
-- as sidecar() gives them.
local function sidecar_progress(doc, exists)
    if not exists then
        return { status = "new" }
    end
    if not doc then
        return { status = "reading" }
    end
    local summary = doc:readSetting("summary")
    local status = type(summary) == "table" and summary.status
    local percent = doc:readSetting("percent_finished")
    local md5 = doc:readSetting("partial_md5_checksum")
    return {
        status = STATUSES[status] and status or "reading",
        percent = type(percent) == "number" and math.max(0, math.min(1, percent)) or nil,
        pages = sidecar_pages(doc),
        md5 = type(md5) == "string" and md5 or nil,
    }
end

local function copy(progress)
    local out = {}
    for k, v in pairs(progress) do
        out[k] = v
    end
    return out
end

-- path's entry of reads, its sidecar opened only when the entry is missing or its file's path,
-- mtime or size changed, or when with_props asks for the doc_props and last_props aren't the
-- entry's; and with with_props, those doc_props. A book with no sidecar gives { progress = new }
-- and drops its entry. A read whose open raised, or whose file has no mtime, is not kept, so the
-- next call retries it.
local function sidecar_read(path, with_props)
    local file = try("the sidecar of " .. path, DocSettings.findSidecarFile, DocSettings, path)
    if not file then
        reads[path] = nil
        return { progress = sidecar_progress(nil, false) }
    end
    local attributes = lfs.attributes(file) or {}
    local read = reads[path]
    if read and read.file == file and read.modification == attributes.modification
            and read.size == attributes.size then
        if not with_props then
            return read
        end
        if last_props and last_props.read == read then
            return read, last_props.props
        end
    end
    local doc = try("the sidecar of " .. path, DocSettings.openSettingsFile, file)
    read = {
        file = file,
        modification = attributes.modification,
        size = attributes.size,
        progress = try("the progress of " .. path, sidecar_progress, doc, true) or { status = "reading" },
    }
    reads[path] = doc and attributes.modification and read or nil
    if not with_props then
        return read
    end
    local props = doc and doc:readSetting("doc_props")
    last_props = { read = read, props = props }
    return read, props
end

-- { status, percent, pages, md5 }. status is new, reading, abandoned or complete; percent 0 to 1
-- or nil; pages and md5 may be nil. For a book with a file, from its sidecar, through the progress
-- memo: opened again only once the sidecar file's path, mtime or size changed, a copy each call so
-- the caller may change it; for a source's book, its source's progress, or new.
function Books.progress(book)
    if book.path then
        local read = try("the progress of " .. book.path, sidecar_read, book.path)
        return read and copy(read.progress) or { status = "reading" }
    end
    for _, source in ipairs(sources) do
        if source.name == book.source and source.progress then
            local progress = try("the progress of " .. tostring(book.id), source.progress, book)
            if type(progress) == "table" then
                return progress
            end
        end
    end
    return { status = "new" }
end

-- The record of the file at path and its progress, as Books.for_path and Books.progress give them,
-- with its sidecar opened once; nil when path is not a file. A sidecar file whose path, mtime and
-- size are the last open's isn't opened again: its doc_props and progress are that open's, the
-- progress through the memo Books.progress reads.
function Books.with_progress(path)
    if type(path) ~= "string" or lfs.attributes(path, "mode") ~= "file" then
        return nil
    end
    local read, props = sidecar_read(path, true)
    local book = record(path, true, function()
        return props
    end, CloudBooks.index())
    return book, copy(read.progress)
end

-- A path-less book's cover for a w by h box, a bitmap the caller owns, from its source's cover, or
-- nil when the source has none or its cover raises, logged.
function Books.cover(book, w, h)
    for _, source in ipairs(sources) do
        if source.name == book.source and source.cover then
            return try("the cover of " .. tostring(book.id), source.cover, book, w, h)
        end
    end
    return nil
end

-- Adds a source of books without a path: { name, books, cover, progress }.
function Books.add_source(source)
    sources[#sources + 1] = source
end

-- For specs: forget every source and the progress memo.
function Books.reset()
    sources = {}
    reads = {}
    last_props = nil
end

return Books
