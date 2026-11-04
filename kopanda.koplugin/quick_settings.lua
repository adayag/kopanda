-- The quick-settings sheet: the device's light and toggles, opened over the home or the bare file browser, read
-- from the device when the sheet lays out; each area acts as KOReader's own menus do, and one that can't run or
-- whose read raised is inert. Its bars and cells are drawn by steppers.lua.
local Device = require("device")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local LauncherEntries = require("launcher_entries")
local Looks = require("looks")
local NetworkMgr = require("ui/network/manager")
local Settings = require("settings")
local Sheet = require("sheet")
local Steppers = require("steppers")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local Screen = Device.screen

local QuickSettings = {}

-- A bar whose read failed shows this in place of its value.
local DASH = "\u{2013}"

-- The launcher's entries whose availability greys a cell (launcher_entries.lua:86).
local WIFI = { kind = "koreader", target = "wifi" }
local SYNC = { kind = "plugin", plugin = "cwngsync", action = "cwngsync_sync_now", label = "Sync books" }
local SLEEP = { kind = "action", action = "suspend", label = "Sleep" }
local SCREENSHOT = { kind = "action", action = "screenshot", label = "Screenshot" }

-- f()'s value, or nil and true when it raises, which is logged as reading what.
local function read(what, f)
    local ok, value = pcall(f)
    if not ok then
        logger.err("KoPanda: quick settings could not read " .. what .. ":", value)
        return nil, true
    end
    return value, false
end

-- Whether the launcher could run entry here; a check that raises reads as no.
local function can_run(entry, what)
    local available = read("whether " .. what .. " can run", function()
        return (LauncherEntries.available(entry))
    end)
    return available == true
end

-- The battery's capacity in percent, or nil without a battery or when the read raises.
local function battery()
    return (read("the battery", function()
        if Device:hasBattery() then
            return Device:getPowerDevice():getCapacity()
        end
    end))
end

-- The radio: on or off, then true when the read raised.
local function radio()
    return read("the radio", function()
        return NetworkMgr:isWifiOn() and true or false
    end)
end

-- The radio as the sheet's last layout read it: true, false or "failed", for stale.
local shown_radio

-- Whether the radio reads otherwise than at the sheet's last layout, so a NetworkConnected or
-- NetworkDisconnected that changes nothing the sheet shows doesn't lay it out again.
local function stale()
    local on, failed = radio()
    return (failed and "failed" or on) ~= shown_radio
end

-- A bar's reading: nil when hidden, { greyed = true } when f raises, else f's { value, min, max }.
local function reading(what, f)
    local value, failed = read(what, f)
    if failed then
        return { greyed = true }
    end
    return value or nil
end

-- The light as the sheet shows it: { brightness, warmth }, each nil when hidden, { greyed = true } when its read
-- raised, else { value, min, max } in native steps.
function QuickSettings.light()
    local powerd = Device:getPowerDevice()
    return {
        brightness = reading("the frontlight", function()
            if Device:hasFrontlight() then
                return { value = powerd:frontlightIntensity(), min = 0, max = powerd.fl_max }
            end
        end),
        warmth = reading("the warmth", function()
            if Device:hasFrontlight() and Device:hasNaturalLight() then
                return { value = powerd:toNativeWarmth(powerd:frontlightWarmth()), min = powerd.fl_warmth_min,
                    max = powerd.fl_warmth_max }
            end
        end),
    }
end

QuickSettings.battery = battery

-- The device's state as the sheet shows it: { battery, brightness, warmth, cells }. battery is a percent or
-- nil; brightness and warmth are QuickSettings.light()'s; cells are the six in order, each { id, label, icon,
-- on, greyed, failed }. Each read is guarded: one that raises is logged and greys its control.
function QuickSettings.state()
    local light = QuickSettings.light()
    local wifi, wifi_failed = radio()
    local night, night_failed = read("night mode", function()
        return G_reader_settings:isTrue("night_mode")
    end)
    local lock, lock_failed = read("the rotation lock", function()
        return G_reader_settings:isTrue("lock_rotation")
    end)
    return {
        battery = battery(),
        brightness = light.brightness,
        warmth = light.warmth,
        cells = {
            { id = "wifi", label = wifi and "Wi-Fi on" or "Wi-Fi off", icon = wifi and "wifi" or "wifi_off",
                on = wifi == true, greyed = wifi_failed or not can_run(WIFI, "Wi-Fi"), failed = wifi_failed },
            { id = "night", label = night and "Night on" or "Night off", icon = "moon", on = night == true,
                greyed = night_failed, failed = night_failed },
            { id = "rotation_lock", label = "Rotation lock", icon = "rotation_lock", on = lock == true,
                greyed = lock_failed, failed = lock_failed },
            { id = "sync_books", label = "Sync books", icon = "sync", on = false,
                greyed = not can_run(SYNC, "Sync books") },
            { id = "screenshot", label = "Screenshot", icon = "screenshot", on = false, greyed = false },
            { id = "sleep", label = "Sleep", icon = "power", on = false, greyed = not can_run(SLEEP, "Sleep") },
        },
    }
end

-- The light at n native steps, clamped to [0, fl_max]; DeviceListener:onSetFlIntensity turns it off at 0
-- (frontend/device/devicelistener.lua:116-125). Broadcast, as KOReader's own menus reach the file manager's
-- DeviceListener: under the sheet it is no active widget (frontend/ui/uimanager.lua:962-1035, :1042-1061).
local function set_brightness(n)
    local powerd = Device:getPowerDevice()
    UIManager:broadcastEvent(Event:new("SetFlIntensity", math.max(0, math.min(n, powerd.fl_max))))
end

-- The warmth at n native steps, clamped to [fl_warmth_min, fl_warmth_max]: onSetFlWarmth
-- clamps only to 0-100 before converting from native (devicelistener.lua:156-165).
local function set_warmth(n)
    local powerd = Device:getPowerDevice()
    UIManager:broadcastEvent(Event:new("SetFlWarmth",
        math.max(powerd.fl_warmth_min, math.min(n, powerd.fl_warmth_max))))
end

-- The native intensity, 0 with the light off, so a plus from off turns it on at 1.
local function brightness()
    return Device:getPowerDevice():frontlightIntensity()
end

local function warmth()
    local powerd = Device:getPowerDevice()
    return powerd:toNativeWarmth(powerd:frontlightWarmth())
end

-- The buttons' taps (one native step) and holds (the bounds), by area id; each reads the
-- device when it runs.
local BUTTONS = {
    brightness_minus = {
        tap = function() set_brightness(brightness() - 1) end,
        hold = function() set_brightness(0) end,
    },
    brightness_plus = {
        tap = function() set_brightness(brightness() + 1) end,
        hold = function() set_brightness(Device:getPowerDevice().fl_max) end,
    },
    warmth_minus = {
        tap = function() set_warmth(warmth() - 1) end,
        hold = function() set_warmth(Device:getPowerDevice().fl_warmth_min) end,
    },
    warmth_plus = {
        tap = function() set_warmth(warmth() + 1) end,
        hold = function() set_warmth(Device:getPowerDevice().fl_warmth_max) end,
    },
}

QuickSettings.light_buttons = BUTTONS

-- KOReader's Wi-Fi menu item's toggle, interactive (frontend/ui/network/manager.lua:899-915): off when fully
-- connected, its prompt when on and not connected, else on. It passes no callback: NetworkMgr runs one only
-- just after broadcasting NetworkConnected (:109, :116) or NetworkDisconnected (:408-410), on which the
-- sheet redraws if the radio changed. The tap's own redraw shows a toggle that broadcasts nothing.
local function toggle_wifi()
    NetworkMgr:queryNetworkState()
    if NetworkMgr.is_wifi_on and NetworkMgr.is_connected then
        NetworkMgr:toggleWifiOff(nil, true)
    elseif NetworkMgr.is_wifi_on then
        NetworkMgr:promptWifi(nil, false, true)
    else
        NetworkMgr:toggleWifiOn(nil, false, true)
    end
end

-- A close-first action running the launcher's entry, which checks availability again and
-- shows the launcher's note when it can't run (launcher_entries.lua:221-265).
local function run(entry)
    return { close_first = true, tap = function() LauncherEntries.run(entry) end }
end

-- The cells' taps, by area id; no cell has a hold. Wi-Fi, Night and Rotation lock act with the
-- sheet open; the rest close it first.
local CELLS = {
    wifi = { tap = toggle_wifi },
    night = {
        tap = function()
            UIManager:broadcastEvent(Event:new("ToggleNightMode"))
        end,
    },
    rotation_lock = {
        tap = function()
            G_reader_settings:flipNilOrFalse("lock_rotation")
        end,
    },
    sync_books = run(SYNC),
    -- The close only marks the screen beneath dirty, so it is painted before the shot, which
    -- shoots the framebuffer as it is (frontend/ui/widget/screenshoter.lua:50-70).
    screenshot = {
        close_first = true,
        tap = function()
            UIManager:forceRePaint()
            LauncherEntries.run(SCREENSHOT)
        end,
    },
    sleep = run(SLEEP),
}

-- A cell greyed because its entry can't run runs that entry after the close, for the
-- launcher's note.
local GREYED = { wifi = run(WIFI), sync_books = run(SYNC), sleep = run(SLEEP) }

-- The area for cell at rect: its id, rect and actions; a cell whose read raised has none.
local function cell_area(cell, rect)
    if cell.failed then
        return { id = cell.id, rect = rect }
    end
    local actions = cell.greyed and GREYED[cell.id] or CELLS[cell.id]
    return { id = cell.id, rect = rect, tap = actions.tap, close_first = actions.close_first }
end

-- The sheet's body under bctx (the sheet's build ctx) content_w wide, from look.quick_settings: { widget,
-- areas }, areas { id, rect, tap, hold, close_first } with rect from the widget's top-left, the bars' minus
-- and plus then the cells, in order.
function QuickSettings.body(bctx, content_w)
    local look = bctx.look
    local qs = look.quick_settings
    local state = QuickSettings.state()
    local wifi = state.cells[1]
    shown_radio = wifi.failed and "failed" or wifi.on
    local body = Steppers.Body:new{ name = "kopanda_quick_settings", fills = {}, places = {} }
    local scale = Steppers.pen(body, bctx).scale

    -- The bars, each a section closed by a rule.
    local bars = {}
    for _, bar in ipairs({ { id = "brightness", label = "Brightness" }, { id = "warmth", label = "Warmth" } }) do
        local r = state[bar.id]
        if r then
            bars[#bars + 1] = { id = bar.id, label = bar.label, value_text = r.greyed and DASH or tostring(r.value),
                greyed = r.greyed, level = r, minus = BUTTONS[bar.id .. "_minus"], plus = BUTTONS[bar.id .. "_plus"] }
        end
    end
    local y, areas = Steppers.draw(body, bctx, content_w, 0, bars)

    -- The grid: three columns, two rows.
    y = y + scale(qs.grid_padding.top)
    for row = 0, 1 do
        if row > 0 then
            y = y + scale(qs.grid_gap)
        end
        local cells = { state.cells[row * 3 + 1], state.cells[row * 3 + 2], state.cells[row * 3 + 3] }
        local rects
        y, rects = Steppers.cells(body, bctx, content_w, y, cells)
        for c, rect in ipairs(rects) do
            areas[#areas + 1] = cell_area(cells[c], rect)
        end
    end
    y = y + scale(qs.grid_padding.bottom)

    body.dimen = Geom:new{ w = content_w, h = y }
    return { widget = body, areas = areas }
end

-- The sheet's header. SheetLayout reads header.aside at each layout (sheet_layout.lua:161-162),
-- so the battery is read there, each time.
local function header()
    return setmetatable({ heading = "Quick settings" }, {
        __index = function(_, key)
            if key == "aside" then
                local capacity = battery()
                return capacity and ("Battery " .. capacity .. "%") or nil
            end
        end,
    })
end

-- Shows the sheet over whatever is on top, the home, the library or the bare file browser: it needs
-- no home. opts.started, the PaintClock stamp the opener took, and opts.beneath, the screen it is
-- shown over when that is not the home, are passed to Sheet.show.
function QuickSettings.open(opts)
    local ctx = {
        look = Looks.active(),
        variant = Looks.variant(),
        text_size = Settings.get("text_size"),
        now = os.time(),
        screen = Screen,
    }
    Sheet.show({
        name = "quick_settings",
        band = "quick_settings",
        header = header(),
        body = QuickSettings.body,
        refresh_on = { "NetworkConnected", "NetworkDisconnected" },
        stale = stale,
    }, ctx, opts)
end

return QuickSettings
