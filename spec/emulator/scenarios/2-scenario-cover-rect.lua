-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/night_golden_spec.lua for its Paperwhite captures. On the first home's
-- settled signal it finds the featured cover's ImageWidget in the shown home and reports the
-- rectangle it was painted at, which ImageWidget:paintTo keeps as its dimen
-- (frontend/ui/widget/imagewidget.lua:518-531), as a "scenario" signal with cover_x, cover_y,
-- cover_w and cover_h. That is the rectangle ImageWidget inverts again in night mode
-- (imagewidget.lua:583-593). Any failure is reported as a "scenario" signal with error.
local logger = require("logger")

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local ImageWidget = require("ui/widget/imagewidget")

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    -- The first ImageWidget under widget, depth first through the array children.
    local function find_image(widget)
        if type(widget) ~= "table" then
            return nil
        end
        if getmetatable(widget) == ImageWidget then
            return widget
        end
        for _, child in ipairs(widget) do
            local found = find_image(child)
            if found then
                return found
            end
        end
        return nil
    end

    local function cover_rect()
        local home = assert(package.loaded["home"] and package.loaded["home"].shown, "no home shown")
        for _, slot in ipairs(home.slots or {}) do
            if slot.widget == "featured" then
                local image = assert(find_image(slot.built), "the featured slot has no ImageWidget")
                local d = assert(image.dimen, "the cover ImageWidget was never painted")
                return d
            end
        end
        error("the home has no featured slot")
    end

    local reported = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if reported or not args or args.screen ~= "home" then
            return
        end
        reported = true
        local found, rect = pcall(cover_rect)
        if not found then
            logger.warn("KOPANDA_SCENARIO: " .. tostring(rect))
            report{ error = tostring(rect) }
            return
        end
        report{
            cover_x = rect.x,
            cover_y = rect.y,
            cover_w = rect.w,
            cover_h = rect.h,
            paint_ms = args.paint_ms,
        }
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
