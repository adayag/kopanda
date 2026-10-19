-- The reading stats widget: the streak, minutes today and books this month from reading_stats.lua,
-- on one line in the look's type.stats. The look's home.stats_line chooses the line: spread
-- across the column (Editorial, Main.dc.html:87) or joined with " · ", right-aligned (Diner,
-- HomeRetro.dc.html:52); its home.stats_streak the streak's wording, word_first ("Streak 4 days")
-- or count_first ("4-day streak"). Parts drop from the end while the line is wider than the
-- column; the first always shows, ending in an ellipsis if it must. stats.show false draws
-- nothing at height 0.
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ReadingStats = require("reading_stats")
local Settings = require("settings")
local Typeset = require("typeset")

local Stats = {
    id = "stats",
    settings_prefix = "stats",
}

local JOIN = " · "

local function plural(n, one, many)
    if n == 1 then
        return one
    end
    return many
end

-- The parts to draw for stats, in order, the streak worded count first when count_first is true,
-- word first otherwise.
local function parts(stats, count_first)
    if stats.state == "off" then
        return { "Reading stats are off" }
    elseif stats.state == "empty" then
        return { "No streak yet", "0 min today", "Read something and this fills in" }
    end
    local streak
    if count_first then
        streak = stats.streak .. "-day streak"
    else
        streak = "Streak " .. stats.streak .. plural(stats.streak, " day", " days")
    end
    return {
        streak,
        stats.minutes_today .. " min today",
        stats.books_month .. plural(stats.books_month, " book in ", " books in ") .. stats.month_name,
    }
end

-- text set in the look's stats type under ctx (Typeset.line), cut with an ellipsis at max_width
-- when given and untracked; with no max_width it is never cut, so its width can be measured.
local function set(text, ctx, max_width)
    return Typeset.line(ctx.look.type.stats, text, max_width or math.huge, ctx)
end

local function free_all(widgets, from)
    for i = from, #widgets do
        widgets[i]:free()
    end
end

-- The joined line: the parts joined, as many as fit, right-aligned in width.
local function joined_line(texts, width, ctx)
    local widget
    for n = #texts, 2, -1 do
        widget = set(table.concat(texts, JOIN, 1, n), ctx)
        if widget:getSize().w <= width then
            break
        end
        widget:free()
        widget = nil
    end
    widget = widget or set(texts[1], ctx, width)
    return HorizontalGroup:new{
        HorizontalSpan:new{ width = width - widget:getSize().w },
        widget,
    }
end

-- The spread line: as many parts as fit with at least the look's column gap between them,
-- spread across width with equal space between; one part sits on the left.
local function spread_line(texts, width, ctx)
    local min_gap = ctx.screen:scaleBySize(ctx.look.home.column_gap)
    local widgets, widths = {}, {}
    for i, text in ipairs(texts) do
        widgets[i] = set(text, ctx)
        widths[i] = widgets[i]:getSize().w
    end
    local n, used = #widgets, 0
    for i = 1, n do
        used = used + widths[i]
    end
    while n > 1 and used + (n - 1) * min_gap > width do
        used = used - widths[n]
        n = n - 1
    end
    free_all(widgets, n + 1)
    if n == 1 then
        if widths[1] > width then
            widgets[1]:free()
            widgets[1] = set(texts[1], ctx, width)
        end
        return HorizontalGroup:new{
            widgets[1],
            HorizontalSpan:new{ width = width - widgets[1]:getSize().w },
        }
    end
    local free_space = width - used
    local gap = math.floor(free_space / (n - 1))
    local group = HorizontalGroup:new{}
    for i = 1, n do
        if i > 1 then
            -- The last gap takes the remainder, so the line is exactly width.
            local w = i == n and free_space - gap * (n - 2) or gap
            group[#group + 1] = HorizontalSpan:new{ width = w }
        end
        group[#group + 1] = widgets[i]
    end
    return group
end

local function line(width, ctx)
    local home = ctx.look.home
    local texts = parts(ReadingStats.read(ctx.now), home.stats_streak == "count_first")
    if home.stats_line == "joined" then
        return joined_line(texts, width, ctx)
    end
    return spread_line(texts, width, ctx)
end

-- The height of one line of the stats type; 0 when stats.show is false.
function Stats.height(_, ctx)
    if not Settings.get("stats.show") then
        return 0
    end
    local probe = set("0", ctx)
    local h = probe:getSize().h
    probe:free()
    return h
end

-- The stats line in a container exactly width wide, or an empty one of height 0 when
-- stats.show is false.
function Stats.build(width, ctx)
    if not Settings.get("stats.show") then
        return WidgetContainer:new{ dimen = Geom:new{ w = width, h = 0 } }
    end
    return WidgetContainer:new{
        dimen = Geom:new{ w = width, h = Stats.height(width, ctx) },
        line(width, ctx),
    }
end

return Stats
