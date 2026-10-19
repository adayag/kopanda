-- The home's own sheet, opened by a hold on empty space (home_gestures.lua): Edit layout, Open the file
-- browser, Refresh weather, Wi-Fi, KoPanda settings and Sleep. Wi-Fi and Sleep are launcher entries,
-- resolved and run as the launcher runs them. Each row's detail is read when the sheet opens.
local EditLayout = require("edit_layout")
local Home = require("home")
local LauncherEntries = require("launcher_entries")
local PaintClock = require("paint_clock")
local SettingsMenu = require("settings_menu")
local Sheet = require("sheet")
local Weather = require("weather")

local HomeSheet = {}

local WIFI = { kind = "koreader", target = "wifi" }
local SLEEP = { kind = "action", action = "suspend", label = "Sleep", icon = "moon" }

-- The row for a launcher entry: its icon and run from the launcher, greyed with the reason when
-- it can't run here.
local function entry_row(entry, label, ctx)
    local view = LauncherEntries.resolve(entry)
    local row = {
        icon = view.icon,
        label = label,
        run = function()
            LauncherEntries.run(entry, ctx)
        end,
    }
    if view.state == "unavailable" then
        row.muted = true
        row.detail = view.suffix
    end
    return row, view
end

-- "Wi-Fi" with a plain hyphen, as the launcher writes it: Diner's row face, Bricolage Grotesque
-- Bold, has no U+2011.
local function wifi_row(ctx)
    local row, view = entry_row(WIFI, "Wi-Fi", ctx)
    if view.state ~= "unavailable" then
        row.detail = view.state == "off" and "Off" or "On"
        row.chip = "state"
    end
    return row
end

-- The spec of the home sheet under ctx (the home's).
local function spec(ctx)
    return {
        name = "home",
        band = "home",
        header = { heading = "Home", aside = "KoPanda" },
        rows = {
            {
                icon = "layout",
                label = "Edit layout",
                run = function()
                    EditLayout.open{ started = PaintClock.now() }
                end,
            },
            {
                icon = "folder",
                label = "Open the file browser",
                run = function()
                    Home.close()
                end,
            },
            {
                icon = "sun",
                label = "Refresh weather",
                -- os.time() rather than ctx.now, the home's build time, so an old home shows the
                -- true age.
                detail = Weather.age(Weather.reading(), os.time()),
                run = function()
                    Weather.tap(ctx.home)
                end,
            },
            wifi_row(ctx),
            {
                icon = "settings",
                label = "KoPanda settings",
                run = function()
                    SettingsMenu.open()
                end,
            },
            (entry_row(SLEEP, "Sleep", ctx)),
        },
    }
end

-- Shows the home sheet over the home. opts.started, the PaintClock stamp the hold took, is
-- passed to Sheet.show, which counts paint_ms and cpu_ms from it.
function HomeSheet.open(ctx, opts)
    Sheet.show(spec(ctx), ctx, opts)
end

return HomeSheet
