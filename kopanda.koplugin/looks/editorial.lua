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
        strong = { file = "fonts/ibm-plex-sans/IBMPlexSans-Medium.ttf", label = "IBM Plex Sans 500" },
        quote = { file = "fonts/newsreader/Newsreader16pt-MediumItalic.ttf", label = "Newsreader 500 italic" },
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
            on_band = false, -- Editorial has no header band
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
            on_band = false,
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
            on_band = false,
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

    -- The home's page: its margins, the gaps between rows and between columns, where the free
    -- height goes, the header drawn with row 1 and the footer. Main.dc.html is the board.
    home = {
        margin = { top = 44, side = 40, bottom = 36 }, -- the page's padding (Main.dc.html:17)
        row_gap = 28, -- the quote's top margin (Main.dc.html:56)
        column_gap = 16, -- the header row's gap (Main.dc.html:19)
        free_space = "before_last_row", -- the stats row's margin-top: auto (Main.dc.html:87)
        -- The main rule under row 1, with rule_space above and below it and no row gap after.
        header = {
            band_color = false,
            edge_width = 0,
            edge_color = false,
            rule_color = "ink", -- the main rule (Main.dc.html:30)
            rule_width = 2, -- stroke.rule
            rule_space = 22, -- the rule's margin (Main.dc.html:30)
            padding = { top = 0, side = 0, bottom = 0 },
        },
        footer = {
            height = 0, -- Editorial has no footer
            stripe_color = false,
            gap_color = false,
            line_width = 0,
            line_pitch = 0,
            edge_width = 0,
            edge_color = false,
        },
    },

    -- The home widgets' text, per part: a face role, a size in board pixels (before text_size),
    -- case, tracking in em, line height as KOReader's TextBoxWidget counts it (extra space in
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role.
    type = {
        -- The weekday over the date (Main.dc.html:21).
        date_label = { face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted" },
        -- The date (Main.dc.html:22).
        date = { face = "display", size = 36, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- The clock (Main.dc.html:26).
        clock = { face = "display", size = 36, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- The weather line (Main.dc.html:25).
        weather = { face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted" },
        -- The quote, CSS line height 1.4 (Main.dc.html:56). The board draws it in #2f2e2b, which no
        -- Editorial role holds, so ink stands in for it.
        quote = { face = "quote", size = 18, uppercase = false, tracking = 0, line_height = 0.4, color = "ink" },
        -- The reading stats (Main.dc.html:87).
        stats = { face = "text", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "muted" },
    },
}
