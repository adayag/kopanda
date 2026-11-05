-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile by
-- spec/emulator/stats_screen_capture_spec.lua and paint_budget_spec.lua after the home fixture patch. It writes
-- nothing. On the first home's settled signal, from the next tick, it opens the Stats window through the plugin, as the
-- nav bar does, with ReadingStats.insights first stubbed to a year of steady reading when KOPANDA_STATS_YEAR is 1, and
-- FinishedBooks.list to the fixture library's books repeated to KOPANDA_STATS_FINISHED when that is set, at the page
-- KOPANDA_STATS_PAGE when that is. On the window's own settled signal it sends KOPANDA_STATS_TURNS mid-screen west
-- swipes and, past the next repaint (UIManager:tickAfterNext), a "scenario" signal with the page shown, the page count
-- and the window's paint_ms; the window's settled signal carries only screen and paint_ms. Any failure is reported as
-- a "scenario" signal with error, so the spec fails with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local time = require("ui/time")

    local turns = tonumber(os.getenv("KOPANDA_STATS_TURNS")) or 0
    local finished = tonumber(os.getenv("KOPANDA_STATS_FINISHED"))
    local page = tonumber(os.getenv("KOPANDA_STATS_PAGE"))

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local function attempt(fn)
        local run_ok, run_err = pcall(fn)
        if not run_ok then
            logger.warn("KOPANDA_SCENARIO: " .. tostring(run_err))
            report{ error = tostring(run_err) }
        end
    end

    -- ReadingStats.insights as read, its days a year of steady reading.
    local function stub_a_year()
        local ReadingStats = package.loaded["reading_stats"]
        local real = ReadingStats.insights
        ReadingStats.insights = function(now)
            local insights = {}
            for key, value in pairs(real(now)) do
                insights[key] = value
            end
            insights.state = "ok"
            insights.days = {}
            for day = 1, ReadingStats.INSIGHT_DAYS do
                insights.days[day] = day % 6 == 0 and 0 or 1200 + (day * 397) % 3600
            end
            return insights
        end
    end

    -- FinishedBooks.list as count finished books, a few a month from January, the fixture's three in turn.
    local function stub_finished(count)
        local root = os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/library/"
        local files = { "a-christmas-carol.epub", "frankenstein.epub", "the-time-machine.epub" }
        local books = {}
        for i = 1, count do
            local path = root .. files[(i - 1) % #files + 1]
            books[i] = {
                record = package.loaded["books"].for_path(path),
                day = string.format("2026-%02d-%02d", math.floor((i - 1) / 4) % 9 + 1, (i - 1) % 4 + 1),
            }
        end
        package.loaded["finished_books"].list = function()
            return books
        end
    end

    local function west_swipe()
        UIManager:sendEvent(Event:new("Gesture", {
            ges = "swipe",
            direction = "west",
            pos = Geom:new{
                x = math.floor(Screen:getWidth() / 2),
                y = math.floor(Screen:getHeight() / 2),
                w = 0,
                h = 0,
            },
            time = time.now(),
        }))
    end

    local opened, turned = false, false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if not args then
            return
        end
        if args.screen == "home" and not opened then
            opened = true
            UIManager:nextTick(function()
                attempt(function()
                    if os.getenv("KOPANDA_STATS_YEAR") == "1" then
                        stub_a_year()
                    end
                    if finished then
                        stub_finished(finished)
                    end
                    require("apps/filemanager/filemanager").instance.kopanda:showStats{ page = page }
                end)
            end)
        elseif args.screen == "stats" and not turned then
            turned = true
            local paint_ms = args.paint_ms
            UIManager:nextTick(function()
                attempt(function()
                    for _ = 1, turns do
                        west_swipe()
                    end
                    UIManager:tickAfterNext(function()
                        attempt(function()
                            local window = package.loaded["library_chrome"].shown
                            report{ page = window.page, pages = window.pages, paint_ms = paint_ms }
                        end)
                    end)
                end)
            end)
        end
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
