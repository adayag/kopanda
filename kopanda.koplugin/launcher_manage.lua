-- Launcher management: launcher.entries as a list in the editor frame (editor.lua), its top level
-- headed "N of 6 on the home screen" over "Launcher" (LauncherManage.dc.html:17-106), or one
-- folder's own list headed "Folder · N" over its label (FolderOpen.dc.html:35-38). The body is a
-- row per entry: its icon, label and kind line, then up, down and remove; a tap on a folder's row
-- opens its list. The foot adds an entry by kind through the entry picker, pinned to the bottom
-- so it stays in reach when a long folder's rows don't all fit. Every change writes
-- launcher.entries once through Settings.set and repaints the screen once, and a shown home
-- refreshes once when the editor closes; a refused write shows a note and changes nothing.
local ConfirmBox = require("ui/widget/confirmbox")
local Editor = require("editor")
local EntriesEdit = require("entries_edit")
local EntryPicker = require("entry_picker")
local Icons = require("icons")
local InfoMessage = require("ui/widget/infomessage")
local Looks = require("looks")
local Paint = require("paint")
local Settings = require("settings")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local UIManager = require("ui/uimanager")
local T = require("ffi/util").template
local logger = require("logger")
local util = require("util")

local LauncherManage = {}

-- A note over the screen, closed by a tap; no timeout, so no timer
-- (frontend/ui/widget/infomessage.lua:53, :283-290).
local function note(text)
    UIManager:show(InfoMessage:new{ text = text })
end

local function scale(ctx, px)
    return ctx.screen:scaleBySize(px)
end

-- The colour of role in ctx's palette, or nil for none.
local function color_of(ctx, role)
    local palette = Looks.palette(ctx.look, ctx.variant)
    return role and palette[role] and Looks.color(palette[role])
end

-- part with its colour role replaced, as the launcher greys an entry.
local function recolored(part, role)
    local copy = {}
    for k, v in pairs(part) do
        copy[k] = v
    end
    copy.color = role
    return copy
end

local function free_all(widgets)
    for _, widget in ipairs(widgets) do
        widget:free()
    end
end

-- A row's height: its lowest control's foot, as the frame measures it.
local function row_height(row)
    local h = 0
    for _, control in ipairs(row) do
        h = math.max(h, control.rect.y + control.rect.h)
    end
    return h
end

-- The list shown: the top level, or the folder's entries.
local function list_of(screen)
    if screen.folder then
        return screen.entries[screen.folder].entries
    end
    return screen.entries
end

-- The position (entries_edit.lua) of the shown list's entry i.
local function pos_of(screen, i)
    if screen.folder then
        return { screen.folder, i }
    end
    return { i }
end

local show_top

-- The spec's header and Done for the list shown: Done on a folder's list opened from the top
-- level goes back to it; otherwise Done closes.
local function set_header(screen)
    local spec = screen.spec
    if screen.folder then
        local folder = screen.entries[screen.folder]
        spec.aside = "Folder · " .. #folder.entries
        spec.title = folder.label
        spec.done = screen.from_top and function()
            show_top(screen)
        end or nil
    else
        spec.aside = T("%1 of %2 on the home screen", EntriesEdit.count(screen.entries), EntriesEdit.max_entries)
        spec.title = "Launcher"
        spec.done = nil
    end
end

show_top = function(screen)
    screen.folder, screen.from_top = nil, false
    set_header(screen)
    screen.editor:refresh()
end

local function show_folder(screen, f)
    screen.folder, screen.from_top = f, true
    set_header(screen)
    screen.editor:refresh()
end

-- Stores new (an operation's result; nil, a refused one, does nothing): on a refused write a
-- note and no change; otherwise the screen takes it, a shown home's refresh is deferred to the
-- editor's close, a removed folder's list gives way to the top level, and the screen repaints
-- once. home and launcher_entries are required at call time: launcher_entries requires home,
-- whose gestures reach the settings menu, which may open this screen.
local function apply(screen, new, folder_removed)
    if new == nil then
        return
    end
    local ok, err = Settings.set("launcher.entries", new)
    if not ok then
        logger.err("KoPanda: could not save the launcher:", err)
        note("Couldn't save the launcher.")
        return
    end
    screen.entries = new
    local Home = require("home")
    if Home.shown then
        Home.shown:defer_refresh()
    end
    if folder_removed then
        screen.folder, screen.from_top = nil, false
    end
    set_header(screen)
    screen.editor:refresh()
end

-- Removes the shown list's entry at pos; a top-level folder only after KOReader's ConfirmBox
-- (frontend/ui/widget/confirmbox.lua:45-51, :107-122), whose Remove runs guarded.
local function remove(screen, pos)
    local entry = #pos == 1 and screen.entries[pos[1]]
    if not (entry and entry.kind == "folder") then
        apply(screen, EntriesEdit.remove(screen.entries, pos))
        return
    end
    local n = #entry.entries
    UIManager:show(ConfirmBox:new{
        text = T(n == 1 and "Remove %1 and its %2 entry?" or "Remove %1 and its %2 entries?", entry.label, n),
        ok_text = "Remove",
        ok_callback = function()
            local ok, err = pcall(function()
                apply(screen, EntriesEdit.remove(screen.entries, pos))
            end)
            if not ok then
                logger.err("KoPanda: launcher management could not remove a folder:", err)
            end
        end,
    })
end

-- An entry row's sizes under ctx: the text lines of every entry are one height, so every row is.
local function row_metrics(ctx)
    local look, tokens = ctx.look, ctx.look.editor
    local m = {
        pad = scale(ctx, tokens.row_padding.y),
        icon = scale(ctx, tokens.icon_size),
        gap = scale(ctx, tokens.icon_gap),
        control = scale(ctx, tokens.control_size),
        rule = scale(ctx, tokens.row_rule_width),
    }
    local label = Typeset.line(look.type.editor_label, "Entry", ctx.screen:getWidth(), ctx)
    local kind = Typeset.line(look.type.editor_kind, "Kind", ctx.screen:getWidth(), ctx)
    m.label = label:getSize().h
    m.text = m.label + kind:getSize().h
    label:free()
    kind:free()
    m.content = math.max(m.icon, m.text, m.control)
    m.row = 2 * m.pad + m.content + m.rule
    return m
end

-- A square control at x, y in its row (LauncherManage.dc.html:35-37): an outlined button around
-- the icon, outline and icon in disabled_color when disabled. Its widgets go into made.
local function icon_control(ctx, made, spec)
    local tokens = ctx.look.editor
    local size = scale(ctx, tokens.control_size)
    local outline = scale(ctx, tokens.button_outline_width)
    local icon_px = size - 2 * scale(ctx, tokens.button_padding.y)
    local edge = color_of(ctx, spec.disabled and tokens.disabled_color or tokens.button_outline_color)
    local fill = color_of(ctx, tokens.button_fill_color)
    local file = Icons.path(spec.icon)
    local icon = file and TintedIcon:new{ file = file, size = icon_px,
        color = color_of(ctx, spec.disabled and tokens.disabled_color or "ink") }
    if icon then
        made[#made + 1] = icon
    end
    local inset = math.floor((size - icon_px) / 2)
    return {
        kind = spec.kind,
        name = spec.name,
        index = spec.index,
        disabled = spec.disabled,
        run = spec.run,
        rect = { x = spec.x, y = spec.y, w = size, h = size },
        draw = function(bb, x, y)
            if fill then
                Paint.fill(bb, x, y, size, size, fill)
            end
            if icon then
                icon:paintTo(bb, x + inset, y + inset)
            end
            if outline > 0 and edge then
                Paint.border(bb, x, y, size, size, outline, edge)
            end
        end,
    }
end

-- The body: a row per entry of the shown list (LauncherManage.dc.html:29-38), each its controls
-- first, so a tap on one runs it, then the row itself, which on a folder opens its list.
local function body(screen, ctx, width)
    free_all(screen.made_body)
    local made = {}
    screen.made_body = made
    local LauncherEntries = require("launcher_entries")
    local look, tokens = ctx.look, ctx.look.editor
    local m = row_metrics(ctx)
    local rule_color = color_of(ctx, tokens.row_rule_color)
    local text_x = m.icon + m.gap
    local text_w = math.max(1, width - m.icon - 3 * m.control - 4 * m.gap)
    local controls_x = width - 3 * m.control - 2 * m.gap
    local control_y = m.pad + math.floor((m.content - m.control) / 2)
    local list = list_of(screen)
    local rows = {}
    for i, entry in ipairs(list) do
        local view = LauncherEntries.resolve(entry)
        local muted = view.state == "unavailable"
        local blocked = muted or view.state == "off"
        local line = EntriesEdit.kind_line(entry, blocked and view.suffix or nil)
        local label = Typeset.line(muted and recolored(look.type.editor_label, "muted") or look.type.editor_label,
            view.label, text_w, ctx)
        local kind = Typeset.line(look.type.editor_kind, line, text_w, ctx)
        made[#made + 1] = label
        made[#made + 1] = kind
        local file = Icons.path(view.icon)
        local icon = file and TintedIcon:new{ file = file, size = m.icon,
            color = color_of(ctx, muted and "muted" or "ink") }
        if icon then
            made[#made + 1] = icon
        end
        local pos = pos_of(screen, i)
        local function arrow(name, icon_id, x, disabled, delta)
            return icon_control(ctx, made, {
                kind = "arrow", name = name, index = i, icon = icon_id, x = x, y = control_y, disabled = disabled,
                run = function()
                    apply(screen, EntriesEdit.move(screen.entries, pos, delta))
                end,
            })
        end
        rows[i] = {
            arrow("up", "chevron_up", controls_x, i == 1, -1),
            arrow("down", "chevron_down", controls_x + m.control + m.gap, i == #list, 1),
            icon_control(ctx, made, {
                kind = "button", name = "remove", index = i, icon = "close", x = controls_x + 2 * (m.control + m.gap),
                y = control_y,
                run = function()
                    remove(screen, pos)
                end,
            }),
            {
                kind = "row",
                name = "entry",
                index = i,
                icon = view.icon,
                label = view.label,
                line = line,
                muted = muted,
                rect = { x = 0, y = 0, w = width, h = m.row },
                run = entry.kind == "folder" and function()
                    show_folder(screen, i)
                end or nil,
                draw = function(bb, x, y)
                    if icon then
                        icon:paintTo(bb, x, y + m.pad + math.floor((m.content - m.icon) / 2))
                    end
                    local text_y = y + m.pad + math.floor((m.content - m.text) / 2)
                    label:paintTo(bb, x + text_x, text_y)
                    kind:paintTo(bb, x + text_x, text_y + m.label)
                    if m.rule > 0 and rule_color then
                        Paint.fill(bb, x, y + m.row - m.rule, width, m.rule, rule_color)
                    end
                end,
            },
        }
    end
    return rows
end

local add_kind

-- The foot (LauncherManage.dc.html:95-104): body_gap above "Add an entry" (the board's 18), the
-- kinds as buttons kind_columns to a row, and on the top level the folder note; kind_gap between
-- them. Its widgets go into made.
local function foot_rows(screen, ctx, width, made, in_folder)
    local look, tokens = ctx.look, ctx.look.editor
    local gap = scale(ctx, tokens.kind_gap)
    local function text_control(kind, part, text, top)
        local line = Typeset.line(part, text, width, ctx)
        made[#made + 1] = line
        local size = line:getSize()
        return { {
            kind = kind,
            name = kind,
            text = text,
            rect = { x = 0, y = top, w = size.w, h = size.h },
            draw = function(bb, x, y)
                line:paintTo(bb, x, y)
            end,
        } }
    end
    local rows = { text_control("caption", look.type.editor_caption, "Add an entry", scale(ctx, tokens.body_gap)) }

    local columns = tokens.kind_columns
    local outline = scale(ctx, tokens.button_outline_width)
    local pad_x, pad_y = scale(ctx, tokens.box_padding.x), scale(ctx, tokens.box_padding.y)
    local button_w = math.floor((width - (columns - 1) * gap) / columns)
    local edge, fill = color_of(ctx, tokens.button_outline_color), color_of(ctx, tokens.button_fill_color)
    local row
    for i, kind in ipairs(EntryPicker.KINDS) do
        local column = (i - 1) % columns
        if column == 0 then
            row = {}
            rows[#rows + 1] = row
        end
        local label = Typeset.line(look.type.editor_box, kind.label .. " ›",
            math.max(1, button_w - 2 * (pad_x + outline)), ctx)
        made[#made + 1] = label
        local h = label:getSize().h + 2 * (pad_y + outline)
        row[#row + 1] = {
            kind = "kind_button",
            name = "kind",
            entry_kind = kind.kind,
            rect = { x = column * (button_w + gap), y = gap, w = button_w, h = h },
            run = function()
                add_kind(screen, kind.kind)
            end,
            draw = function(bb, x, y)
                if fill then
                    Paint.fill(bb, x, y, button_w, h, fill)
                end
                label:paintTo(bb, x + outline + pad_x, y + outline + pad_y)
                if outline > 0 and edge then
                    Paint.border(bb, x, y, button_w, h, outline, edge)
                end
            end,
        }
    end
    if not in_folder then
        rows[#rows + 1] = text_control("note", look.type.editor_note, "The seventh entry and beyond go into a folder.",
            gap)
    end
    return rows
end

local function foot(screen, ctx, width)
    free_all(screen.made_foot)
    screen.made_foot = {}
    return foot_rows(screen, ctx, width, screen.made_foot, screen.folder ~= nil)
end

-- Whether a list of n entries, shown as a folder's list (in_folder) or the top level, has room
-- for one more row: the rows that fit between body_gap below the editor's rule and that list's
-- foot, as the frame places them.
local function has_room(screen, n, in_folder)
    local editor = screen.editor
    local ctx = editor.ctx
    local tokens = ctx.look.editor
    local size = ctx.screen:getSize()
    local made = {}
    local foot_h = 0
    for _, row in ipairs(foot_rows(screen, ctx, size.w - 2 * scale(ctx, tokens.padding.side), made, in_folder)) do
        foot_h = foot_h + row_height(row)
    end
    free_all(made)
    local foot_top = size.h - scale(ctx, tokens.padding.bottom) - foot_h
    local body_top = editor.rule.y + editor.rule.h + scale(ctx, tokens.body_gap)
    return n + 1 <= math.floor((foot_top - body_top) / row_metrics(ctx).row)
end

-- A kind button: the list the entry would go into (decision D3: the shown folder; the top level
-- under max_entries; else its first folder; else a new More of two) checked for room, then the
-- picker, whose entry is added.
add_kind = function(screen, kind)
    local entries = screen.entries
    local n, in_folder
    if screen.folder then
        n, in_folder = #entries[screen.folder].entries, true
    elseif #entries < EntriesEdit.max_entries then
        n, in_folder = #entries, false
    else
        n, in_folder = 1, true
        for _, entry in ipairs(entries) do
            if entry.kind == "folder" then
                n = #entry.entries
                break
            end
        end
    end
    if not has_room(screen, n, in_folder) then
        note("There's no room for another entry here.")
        return
    end
    EntryPicker.pick(kind, screen.editor.ctx, function(entry)
        apply(screen, EntriesEdit.add(screen.entries, entry, screen.folder))
    end)
end

-- Opens launcher management on a copy of the stored launcher: opts.folder, a top-level index,
-- opens that folder's list, whose Done then closes; an index past the list or not a folder opens
-- the top level. opts.started is the PaintClock stamp the opener took, which paint_ms runs from.
-- A failure is logged and leaves no screen.
function LauncherManage.open(opts)
    opts = opts or {}
    local ok, err = pcall(function()
        local screen = {
            entries = util.tableDeepCopy(Settings.get("launcher.entries")),
            from_top = false,
            made_body = {},
            made_foot = {},
        }
        local at = opts.folder and screen.entries[opts.folder]
        if type(at) == "table" and at.kind == "folder" then
            screen.folder = opts.folder
        end
        screen.spec = {
            screen = "launcher",
            body = function(ctx, width)
                return body(screen, ctx, width)
            end,
            foot = function(ctx, width)
                return foot(screen, ctx, width)
            end,
        }
        set_header(screen)
        screen.editor = Editor.show(screen.spec, { started = opts.started })
    end)
    if not ok then
        logger.err("KoPanda: could not open launcher management:", err)
    end
end

return LauncherManage
