-- The launcher's list operations on a launcher.entries value (schema.lua's launcher.entries):
-- pure, each working on a deep copy and returning it, the input left unchanged. A position is
-- { i } at the top level or { f, i } inside the folder at top-level index f. Nothing here
-- writes a setting; launcher management stores what it gets.
local Schema = require("schema")
local T = require("ffi/util").template
local util = require("util")

local EntriesEdit = {}

for _, key in ipairs(Schema.keys) do
    if key.id == "launcher.entries" then
        -- The most the top level holds (schema.lua's max_entries).
        EntriesEdit.max_entries = key.max_entries
    end
end

-- The copy of entries and, in it, the list pos names and the entry's index there.
local function locate(entries, pos)
    local copy = util.tableDeepCopy(entries)
    if #pos == 1 then
        return copy, copy, pos[1]
    end
    return copy, copy[pos[1]].entries, pos[2]
end

-- entries with the entry at pos moved by delta within its list; nil when that passes an end.
function EntriesEdit.move(entries, pos, delta)
    local copy, list, i = locate(entries, pos)
    local j = i + delta
    if j < 1 or j > #list then
        return nil
    end
    local entry = table.remove(list, i)
    table.insert(list, j, entry)
    return copy
end

-- entries without the entry at pos, a folder with its entries, and whether a folder went with
-- it: a folder holds one entry or more (settings.lua's is_entry), so removing its only entry
-- removes the folder.
function EntriesEdit.remove(entries, pos)
    local copy, list, i = locate(entries, pos)
    table.remove(list, i)
    if #pos == 2 and #list == 0 then
        table.remove(copy, pos[1])
        return copy, true
    end
    return copy, false
end

-- entries with entry added (decision D3): into the folder at top-level index f, at its end;
-- else at the end of a top level under max_entries; else at the end of the first top-level
-- folder; else the last entry and the new one become a folder labelled More in its place.
-- Folders don't nest, so a folder entry is never added: nil.
function EntriesEdit.add(entries, entry, f)
    if entry.kind == "folder" then
        return nil
    end
    local copy = util.tableDeepCopy(entries)
    local new = util.tableDeepCopy(entry)
    if f then
        table.insert(copy[f].entries, new)
        return copy
    end
    local max = EntriesEdit.max_entries
    if #copy < max then
        copy[#copy + 1] = new
        return copy
    end
    for _, e in ipairs(copy) do
        if e.kind == "folder" then
            table.insert(e.entries, new)
            return copy
        end
    end
    copy[max] = { kind = "folder", label = "More", entries = { copy[max], new } }
    return copy
end

-- The top level's length.
function EntriesEdit.count(entries)
    return #entries
end

-- Each kind's name, as the folder sheet names it, and the field its detail reads.
local KINDS = {
    kopanda = { name = "KoPanda", detail = "target" },
    koreader = { name = "KOReader", detail = "target" },
    plugin = { name = "Plugin", detail = "plugin" },
    action = { name = "Action", detail = "action" },
    directory = { name = "Folder on disk", detail = "path" },
}

-- The entry's kind line, "<kind> · <detail>", the detail suffix when given (an entry that is off
-- or can't run here); a folder's is "Folder · N entries ›".
function EntriesEdit.kind_line(entry, suffix)
    if entry.kind == "folder" then
        local n = #entry.entries
        return T(n == 1 and "Folder · %1 entry ›" or "Folder · %1 entries ›", n)
    end
    local kind = KINDS[entry.kind]
    return kind.name .. " · " .. (suffix or entry[kind.detail])
end

return EntriesEdit
