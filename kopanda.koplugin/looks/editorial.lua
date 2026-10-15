-- Editorial: a serif display face, hairlines and soft shadows on warm paper. Pure data, typed
-- from the direction doc (.tiller/design/2026-10-13-kopanda-ui-direction.md, "The two looks",
-- the night palettes, "Greys for the Paperwhite"); where the doc leaves a value out, the line's
-- comment names where it comes from. Diner (looks/diner.lua) declares the same paths.
--
-- Sizes are board pixels (the canvas's half size), scaled at draw time by Screen:scaleBySize;
-- font sizes go to Font:getFace unscaled. Colours are #rrggbb in the palettes only; every other
-- token names a colour by its palette role. false is a token this look doesn't have.
return {
    faces = {
        display = { file = "fonts/newsreader/Newsreader16pt-Medium.ttf", label = "Newsreader 500" },
        text = { file = "fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf", label = "IBM Plex Sans 400" },
        accent = { file = false, label = false },
    },

    palettes = {
        day = {
            paper = "#f3f1ea",
            ink = "#1c1b19",
            muted = "#6b6861",
            text = "#4a4843", -- the canvas: Main.dc.html:41 draws it where NightA.dc.html:41 draws the night text
            hairline = "#c9c5b8",
            hairline_light = "#e2dfd4", -- the doc gives none by day; the canvas's row rules (Main.dc.html)
            teal = false,
            pink = false,
            mustard = false,
            band = false,
            outline = false, -- implied: by day the cover takes a shadow, not an outline
            shadow = "#c9c5b8", -- the doc: shadow in the hairline colour
        },
        night = {
            paper = "#15161a",
            ink = "#e8e6df",
            muted = "#9b988f",
            text = "#c4c1b8",
            hairline = "#3a3b40",
            hairline_light = "#2a2b30",
            teal = false,
            pink = false,
            mustard = false,
            band = false,
            outline = "#3a3b40", -- the doc: the cover gets a hairline outline instead of a shadow
            shadow = false, -- the doc: at night the outline replaces the shadow
        },
        grey = {
            paper = "#f4f4f4",
            ink = "#111111",
            muted = "#555555", -- the lighter of the doc's two muted greys; Diner takes #444444
            -- The canvas's #333333 (PWEditorial.dc.html:41) is not on the doc's list; the nearest list grey.
            text = "#444444",
            hairline = "#8c8c8c",
            hairline_light = "#d0d0d0",
            teal = false,
            pink = false,
            mustard = false,
            band = false,
            outline = "#8c8c8c", -- implied: the Paperwhite cover gains an outline, Editorial's is a hairline
            shadow = "#8c8c8c", -- implied: the shadow is the hairline colour
        },
    },

    stroke = {
        hairline = 1,
        hairline_grey = 2, -- the doc: on the Paperwhite hairlines thicken to 2 px
        rule = 2, -- the main rule
        outline = 1, -- implied: Editorial's outlines are hairlines
        band = false,
    },

    shadow = {
        cover = { x = 2, y = 3, color = "shadow" },
        tile = { x = 0, y = 0, color = false },
        sheet = { x = 0, y = 0, color = false },
    },

    radius = {
        cover = 3,
        box = 0,
    },

    -- A text row with a hairline under it.
    tile = {
        box = false,
        fill_color = false,
        outline_color = false,
        rule_color = "hairline_light", -- the canvas's launcher rows (Main.dc.html, NightA.dc.html)
    },

    -- A 4 px bar, ink on hairline.
    progress = {
        height = 4,
        fill_color = "ink",
        track_color = "hairline",
        outline_color = false,
        outline_width = 0,
        fill_grey = false,
    },

    -- A paper panel from the bottom edge under a 2 px rule.
    sheet = {
        fill_color = "paper",
        rule_color = "ink", -- the canvas's sheet rule (HoldBook.dc.html)
        rule_width = 2,
        outline_color = false,
        header_band = false,
    },

    -- Small caps, muted.
    chip = {
        small_caps = true,
        uppercase = false,
        text_color = "muted",
        fill_color = false,
        outline_color = false,
    },

    -- 11 px small caps, 0.14 em tracking.
    label = {
        size = 11,
        face = "text",
        small_caps = true,
        uppercase = false,
        tracking = 0.14,
    },
}
