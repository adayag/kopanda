-- The focused panel: KoPanda's sheet over a book in place of KOReader's reader menus. It reads the reader's page,
-- chapter, bookmark and configurable (frontend/apps/reader/readerui.lua:1007, readertoc.lua:446,
-- readerbookmark.lua:403) and acts through KOReader's own reader events (HOOKS.md, "The focused panel").
local Clock = require("widgets/clock")
local Device = require("device")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local GotoScreen = require("goto_screen")
local Looks = require("looks")
local QuickSettings = require("quick_settings")
local Sheet = require("sheet")
local Steppers = require("steppers")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local FocusedPanel = {}

local HINT = "Hold here for all settings"

-- The text size the panel always draws at, whatever the text_size setting: one size that fits on every screen.
FocusedPanel.TEXT_SIZE = "medium"

-- A bar whose read failed shows this in place of its value, as in quick settings.
local DASH = "\u{2013}"

-- The reader stays under the panel when it closes.
local NOOP = { close = function() end }

-- The events of a screen turned under the panel, which is laid out for the old size: a G-sensor's rotation, sent to
-- the top window (frontend/device/input.lua:1466-1471, frontend/ui/uimanager.lua:962-990), and a resize, broadcast
-- (frontend/device/sdl/device.lua:313).
local TURNED = { "SetRotationMode", "SetDimensions" }

-- Contrast as KOReader's config panel steps it: an EPUB's font_gamma (frontend/ui/data/creoptions.lua:571-579),
-- a PDF's or comic's contrast (frontend/ui/data/koptoptions.lua:489-498).
local CONTRAST = {
    rolling = { name = "font_gamma", event = "SetFontGamma", values = { 10, 15, 25, 30, 36, 43, 49, 56 } },
    paging = { name = "contrast", event = "GammaUpdate", values = { 0.8, 1.0, 1.5, 2.0, 4.0, 6.0, 10.0, 50.0 } },
}

-- f()'s value, or fallback when it raises, which is logged as reading what.
local function read(what, f, fallback)
    local ok, value = pcall(f)
    if not ok then
        logger.err("KoPanda: the focused panel could not read " .. what .. ":", value)
        return fallback
    end
    return value
end

local function paging(ui)
    return ui.document.info.has_pages and true or false
end

-- The document's contrast option with the position of its stored value among the steps, else of the nearest.
local function contrast(ui)
    local option = CONTRAST[paging(ui) and "paging" or "rolling"]
    local stored = tonumber(ui.document.configurable[option.name])
    local index = 1
    if stored then
        for i, value in ipairs(option.values) do
            if math.abs(value - stored) < math.abs(option.values[index] - stored) then
                index = i
            end
        end
    end
    return { name = option.name, event = option.event, values = option.values, index = index }
end

-- The header: title · chapter on a line above, page and percent as the heading, time and battery at its right,
-- and the hint on a line under.
local function header(ui, now)
    local page = read("the page", function() return ui:getCurrentPage() end)
    local pages = read("the page count", function() return ui.document:getPageCount() end)
    local title = read("the title", function() return ui.doc_props.display_title end)
    local chapter = page and read("the chapter", function() return ui.toc:getTocTitleByPage(page) end)
    local where = {}
    for _, part in ipairs({ title, chapter }) do
        if type(part) == "string" and part ~= "" then
            where[#where + 1] = part
        end
    end
    local heading
    if page and pages and pages > 0 then
        heading = string.format("Page %d of %d · %d%%", page, pages, math.floor(page / pages * 100))
    end
    local battery = QuickSettings.battery()
    return {
        aside = #where > 0 and table.concat(where, " · ") or nil,
        aside_above = true,
        heading = heading,
        label = Clock.text(now) .. (battery and (" · " .. battery .. "%") or ""),
        hint = HINT,
        hint_below = true,
    }
end

-- What the panel shows for ui at now (default the time): { header, text_size, contrast, light, night, bookmarked }.
-- text_size is { value } for a rolling document, nil for a paging one (frontend/dispatcher.lua:245-246); contrast is
-- { name, event, values, index }; light is quick settings' { brightness, warmth }, nil without a frontlight.
function FocusedPanel.state(ui, now)
    local light = QuickSettings.light()
    return {
        header = header(ui, now or os.time()),
        text_size = not paging(ui) and { value = ui.document.configurable.font_size } or nil,
        contrast = contrast(ui),
        light = (light.brightness or light.warmth) and light or nil,
        night = G_reader_settings:isTrue("night_mode"),
        bookmarked = read("the bookmark", function() return ui.bookmark:isPageBookmarked() end, false),
    }
end

-- The contrast step by delta from the stored one, as ConfigDialog:onConfigChoose sends it: ConfigChange, then the
-- option's event with the value (frontend/ui/widget/configdialog.lua:981-1016). Past either end it sends nothing.
local function step_contrast(ui, delta)
    local c = contrast(ui)
    local value = c.values[c.index + delta]
    if value == nil then
        return
    end
    ui:handleEvent(Event:new("ConfigChange", c.name, value))
    ui:handleEvent(Event:new(c.event, value))
end

-- The panel's actions for ui, by control: each sends KOReader's own event as its own menus send it.
function FocusedPanel.actions(ui)
    return {
        -- A number is the step itself (frontend/apps/reader/modules/readerfont.lua:377-380, :400-411).
        text_minus = function()
            ui:handleEvent(Event:new("DecreaseFontSize", 1))
        end,
        text_plus = function()
            ui:handleEvent(Event:new("IncreaseFontSize", 1))
        end,
        contrast_minus = function()
            step_contrast(ui, -1)
        end,
        contrast_plus = function()
            step_contrast(ui, 1)
        end,
        night = function()
            UIManager:broadcastEvent(Event:new("ToggleNightMode"))
        end,
        bookmark = function()
            ui:handleEvent(Event:new("ToggleBookmark"))
        end,
        -- As the reader menu's file browser icon does (frontend/apps/reader/modules/readermenu.lua:65-73).
        home = function()
            local file = ui.document.file
            ui:onClose()
            ui:showFileManager(file)
        end,
        -- The Go to screen, else KOReader's own table of contents, so the reader always gets a contents list.
        go_to = function()
            local ok, shown = pcall(GotoScreen.show, { ui = ui })
            if not ok then
                logger.err("KoPanda: the focused panel could not show the Go to screen:", shown)
            end
            if not (ok and shown) then
                ui:handleEvent(Event:new("ShowToc"))
            end
        end,
        -- As ReaderMenu:onTapShowMenu does, without its tab from the tap's place (readermenu.lua:495-503).
        admin = function()
            if G_reader_settings:nilOrTrue("show_bottom_menu") then
                ui:handleEvent(Event:new("ShowConfigMenu"))
            end
            ui.menu:onShowMenu()
        end,
    }
end

-- A body area for a cell at rect running tap, closing the panel first unless it stays open.
local function cell_area(id, rect, tap, stays_open)
    return { id = id, rect = rect, tap = tap, close_first = not stays_open or nil }
end

-- The sheet's body under bctx (the sheet's build ctx, with the reader as bctx.ui) content_w wide: { widget, areas }.
-- Night, Bookmark and Go to first, then the steppers (Text size for a rolling document, Contrast, the light's), then
-- Home on a row of its own. Areas are { id, rect, tap, close_first }, with no holds, so a hold on them runs nothing.
-- repaged, when given, runs after each Text size step.
function FocusedPanel.body(bctx, content_w, repaged)
    local ui = bctx.ui
    local qs = bctx.look.quick_settings
    local state = FocusedPanel.state(ui, bctx.now)
    local actions = FocusedPanel.actions(ui)
    local body = Steppers.Body:new{ name = "kopanda_focused_panel", fills = {}, places = {} }
    local scale = Steppers.pen(body, bctx).scale

    local areas = {}
    local y = scale(qs.grid_padding.top)
    local rects
    y, rects = Steppers.cells(body, bctx, content_w, y, {
        { label = state.night and "Night on" or "Night off", icon = "moon", on = state.night },
        { label = state.bookmarked and "Remove bookmark" or "Bookmark", icon = "bookmark", on = state.bookmarked },
        { label = "Go to", icon = "list" },
    })
    areas[1] = cell_area("night", rects[1], actions.night, true)
    areas[2] = cell_area("bookmark", rects[2], actions.bookmark)
    areas[3] = cell_area("go_to", rects[3], actions.go_to)

    local bars = {}
    if state.text_size then
        local function step(action)
            return function()
                action()
                if repaged then
                    repaged()
                end
            end
        end
        bars[#bars + 1] = { id = "text", label = "Text size", value_text = tostring(state.text_size.value),
            minus = { tap = step(actions.text_minus) }, plus = { tap = step(actions.text_plus) } }
    end
    local c = state.contrast
    bars[#bars + 1] = { id = "contrast", label = "Contrast", value_text = tostring(c.index),
        level = { value = c.index, min = 1, max = #c.values },
        minus = { tap = actions.contrast_minus }, plus = { tap = actions.contrast_plus } }
    local buttons = QuickSettings.light_buttons
    for _, bar in ipairs({ { id = "brightness", label = "Brightness" }, { id = "warmth", label = "Warmth" } }) do
        local r = state.light and state.light[bar.id]
        if r then
            bars[#bars + 1] = { id = bar.id, label = bar.label, value_text = r.greyed and DASH or tostring(r.value),
                greyed = r.greyed, level = r, minus = { tap = buttons[bar.id .. "_minus"].tap },
                plus = { tap = buttons[bar.id .. "_plus"].tap } }
        end
    end
    local bar_areas
    y, bar_areas = Steppers.draw(body, bctx, content_w, y, bars)
    for _, a in ipairs(bar_areas) do
        areas[#areas + 1] = a
    end

    y = y + scale(qs.grid_padding.top)
    y, rects = Steppers.cells(body, bctx, content_w, y, { { label = "Home", icon = "home" } })
    areas[#areas + 1] = cell_area("home", rects[1], actions.home)
    y = y + scale(qs.grid_padding.bottom)

    body.dimen = Geom:new{ w = content_w, h = y }
    return { widget = body, areas = areas }
end

-- The sheet's spec for ui. It redraws on no event: none of the reader's font, contrast and bookmark events is
-- broadcast to other windows (frontend/apps/reader/modules/readerfont.lua:217-224, :291-297, readerbookmark.lua:
-- 347-359), so a stepper's tap redraws the panel itself (sheet.lua, act), and a Text size step, which repaginates
-- before it returns (readerrolling.lua:993-1019), heads it again first.
function FocusedPanel.spec(ui)
    local spec = {
        name = "focused_panel",
        band = "quick_settings",
        header = FocusedPanel.state(ui).header,
        header_hold = true,
        hold = FocusedPanel.actions(ui).admin,
        close_on = TURNED,
    }
    function spec.body(bctx, content_w)
        return FocusedPanel.body(bctx, content_w, function()
            spec.header = header(ui, os.time())
        end)
    end
    return spec
end

-- Shows the panel over ui's book, its ctx built as QuickSettings.open builds it but at the panel's own text size,
-- with the reader as ctx.ui. opts.started is the PaintClock stamp the opener took. Raises when the panel isn't
-- shown, which Sheet.show logs.
function FocusedPanel.open(ui, opts)
    local ctx = {
        look = Looks.active(),
        variant = Looks.variant(),
        text_size = FocusedPanel.TEXT_SIZE,
        now = os.time(),
        screen = Device.screen,
        ui = ui,
    }
    Sheet.show(FocusedPanel.spec(ui), ctx, { started = opts and opts.started, beneath = NOOP })
    if not Sheet.shown then
        error("the focused panel was not shown")
    end
end

return FocusedPanel
