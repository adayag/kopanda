-- The library's gestures: its own touch zones and the order a gesture on the library runs in
-- (cover-grid "Gestures"). The library's onGesture (library.lua) calls route through a pcall; the
-- parts a tap or a swipe acts on, and what they do, are the library's.
local BD = require("ui/bidi")
local HomeGestures = require("home_gestures")
local InputContainer = require("ui/widget/container/inputcontainer")

local LibraryGestures = {}

-- As the home's (home_gestures.lua): the library's own steps are touch zones on it, matched through
-- InputContainer.onGesture, so KOReader's touch lock filters them
-- (frontend/ui/widget/container/inputcontainer.lua:297-350). A zone's handler only names its step,
-- which route runs in its place in the order.
local FULL_SCREEN = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 }

-- The zones the library registers on itself at init.
function LibraryGestures.own_zones(library)
    local zones = {}
    for _, ges in ipairs({ "tap", "hold", "swipe" }) do
        zones[#zones + 1] = {
            id = "kopanda_library_" .. ges,
            ges = ges,
            screen_zone = FULL_SCREEN,
            handler = function()
                library.own_step = ges
                return true
            end,
        }
    end
    return zones
end

-- The library's gestures, in order, each step stopping at the first that consumes: a tap or a
-- hold in the nav bar's band, which the bar takes; a tap on a part of the library that acts on
-- taps (library:tap); a west or east swipe outside the top and bottom edge bands turns the page,
-- mirrored as Menu:onSwipe reads it (frontend/ui/widget/menu.lua:1518-1523); a hold runs nothing;
-- then the home's forward step (HomeGestures.forward), so the top menu, Gestures' corner zones and
-- its edge-band swipes still work. Whatever none of them takes is consumed.
function LibraryGestures.route(library, ges)
    library.own_step = nil
    InputContainer.onGesture(library, ges)
    local own_step = library.own_step
    library.own_step = nil
    if (own_step == "tap" or own_step == "hold") and library.nav and library.nav:handle(ges) then
        return true
    end
    if own_step == "tap" and library:tap(ges.pos) then
        return true
    end
    if own_step == "swipe" and HomeGestures.is_page_swipe(ges) then
        library:turn(BD.flipDirectionIfMirroredUILayout(ges.direction) == "west" and 1 or -1)
        return true
    end
    if own_step == "hold" then
        return true
    end
    HomeGestures.forward(ges)
    return true
end

return LibraryGestures
