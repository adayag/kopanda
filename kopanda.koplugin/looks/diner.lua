-- Diner: a heavy grotesque, ink outlines, hard shadows and flat accent fills. Pure data, typed
-- from the direction doc (.tiller/design/2026-10-13-kopanda-ui-direction.md, "The two looks",
-- the night palettes, "Greys for the Paperwhite"); where the doc leaves a value out, the line's
-- comment names where it comes from. Editorial (looks/editorial.lua) declares the same paths.
--
-- Sizes are board pixels (the canvas's half size), scaled at draw time by Screen:scaleBySize;
-- font sizes go to Font:getFace unscaled. Colours are #rrggbb in the palettes only; every other
-- token names a colour by its palette role. false is a token this look doesn't have.
return {
    faces = {
        display = { file = "fonts/bricolage-grotesque/BricolageGrotesque-ExtraBold.ttf",
            label = "Bricolage Grotesque 800" },
        text = { file = "fonts/bricolage-grotesque/BricolageGrotesque-Medium.ttf", label = "Bricolage Grotesque 500" },
        accent = { file = "fonts/caveat/Caveat-Regular.ttf", label = "Caveat 400" },
        strong = { file = "fonts/bricolage-grotesque/BricolageGrotesque-Bold.ttf", label = "Bricolage Grotesque 700" },
        quote = { file = "fonts/bricolage-grotesque/BricolageGrotesque-Medium.ttf", label = "Bricolage Grotesque 500" },
    },

    palettes = {
        day = {
            paper = "#f5f1e6",
            ink = "#2f2e2b",
            muted = "#5a5750",
            text = "#2f2e2b", -- implied: Diner's text is its ink
            hairline = false,
            hairline_light = false,
            teal = "#6fb3ab",
            pink = "#e8a59d",
            mustard = "#e0bd6a",
            band = "#6fb3ab", -- the canvas's header band is teal (HomeRetro.dc.html)
            outline = "#2f2e2b", -- the doc: strokes are ink
            shadow = "#2f2e2b", -- the doc: hard shadows are ink
            on_band = "#f5f1e6", -- the header band's text (HomeRetro.dc.html:19)
            on_accent = "#2f2e2b", -- the text on the sheets' bands and chips, the boards' ink (HoldBookC.dc.html:31-36)
            cover = "#2b4c6f", -- the typographic cover's fill (HomeRetro.dc.html:28)
            on_cover = "#f5f1e6", -- its title and authors (HomeRetro.dc.html:28)
        },
        night = {
            paper = "#1e1c1a",
            ink = "#f1ece0",
            muted = "#bdb7a9",
            text = "#f1ece0", -- implied: Diner's text is its ink
            hairline = false,
            hairline_light = false,
            teal = "#2f6b65",
            pink = "#b86f68",
            mustard = "#b8923c",
            band = "#2f6b65", -- the canvas's night band is the night teal (NightC.dc.html)
            outline = "#f1ece0", -- the doc: outlines turn cream, the night ink
            shadow = "#f1ece0", -- the doc: hard shadows turn cream, the night ink
            on_band = "#f1ece0", -- NightC.dc.html:19
            -- No board gives it: the night paper, since the doc has mustard and pink tiles take dark text.
            on_accent = "#1e1c1a",
            cover = "#2b4c6f", -- NightC.dc.html:28
            on_cover = "#f5f1e6", -- NightC.dc.html:28
        },
        grey = {
            paper = "#f4f4f4",
            ink = "#111111",
            muted = "#444444", -- the darker of the doc's two muted greys (PWRetro.dc.html)
            text = "#111111", -- implied: Diner's text is its ink
            hairline = false,
            hairline_light = false,
            teal = "#b0b0b0", -- the doc's tiles in the canvas's tile order: teal (PWRetro.dc.html)
            pink = "#e0e0e0", -- pink
            mustard = "#c8c8c8", -- mustard
            band = "#9a9a9a",
            outline = "#111111", -- implied: strokes are ink
            shadow = "#111111", -- implied: hard shadows are ink
            on_band = "#111111", -- PWRetro.dc.html:19: ink on the grey band
            on_accent = "#111111", -- ink on the grey tiles (PWRetro.dc.html:19)
            cover = "#4a4a4a", -- PWRetro.dc.html:28
            on_cover = "#f4f4f4", -- PWRetro.dc.html:28
        },
    },

    stroke = {
        hairline = false,
        hairline_grey = false,
        rule = false,
        outline = 3,
        band = 4, -- band edges
    },

    shadow = {
        cover = { x = 6, y = 6, color = "pink" }, -- the doc: 4–8 px, pink under the cover; 6 from the canvas
        tile = { x = 4, y = 4, color = "shadow" }, -- 4 from the canvas (HomeRetro.dc.html)
        sheet = { x = 8, y = 8, color = "shadow" },
    },

    radius = {
        cover = 0,
        box = 0,
    },

    -- A filled box with an outline and a hard shadow.
    tile = {
        box = true,
        fill_color = "paper",
        outline_color = "outline",
        rule_color = false,
    },

    -- A 14 px outlined bar with a mustard fill; in grey a 135° hatch of ink on paper.
    progress = {
        height = 14,
        fill_color = "mustard",
        track_color = "paper", -- the canvas's track (HomeRetro.dc.html)
        outline_color = "outline",
        outline_width = 2, -- the canvas's bar outline (HomeRetro.dc.html)
        fill_grey = "hatch_135",
    },

    -- An outlined box with an 8 px ink shadow and a coloured header band; the band's colour is a
    -- token per sheet, below (pink on the book's, mustard on the home's in the canvas).
    sheet = {
        fill_color = "paper",
        rule_color = false,
        rule_width = 0,
        outline_color = "outline",
        header_band = true,
        inset = { side = 22, bottom = 22 }, -- HoldBookC.dc.html:30
        padding = { top = 0, side = 0, bottom = 0 }, -- HoldBookC.dc.html:30
        book_band_color = "pink", -- HoldBookC.dc.html:31
        home_band_color = "mustard", -- HoldHomeC.dc.html:31
        folder_band_color = "teal", -- no board draws Diner's folder sheet
        header_rule_color = "outline", -- HoldBookC.dc.html:31
        header_rule_width = 3, -- HoldBookC.dc.html:31
        header_padding = { top = 16, side = 20, bottom = 16 }, -- HoldHomeC.dc.html:31
        book_header_padding = { top = 18, side = 20, bottom = 18 }, -- HoldBookC.dc.html:31
        cover_gap = 16, -- HoldBookC.dc.html:31
        cover_w = 60, -- HoldBookC.dc.html:32
        cover_h = 90, -- HoldBookC.dc.html:32
        line_gap = 3, -- HoldBookC.dc.html:33
        meta_gap = 4, -- HoldBookC.dc.html:36
        aside_gap = 12, -- no board: Editorial's (FolderOpen.dc.html:36)
        row_padding = { x = 20, y = 15 }, -- HoldBookC.dc.html:39
        row_gap = 14, -- HoldBookC.dc.html:39
        icon_size = 22, -- HoldBookC.dc.html:40
        row_rule_color = "outline", -- HoldBookC.dc.html:39
        row_rule_width = 2, -- HoldBookC.dc.html:39
        last_row_bottom = 15, -- HoldBookC.dc.html:65
        status_chip_color = "mustard", -- the read status (HoldBookC.dc.html:52)
        state_chip_color = "teal", -- the Wi-Fi state (HoldHomeC.dc.html:55)
        chip_padding = { x = 8, y = 2 }, -- HoldBookC.dc.html:52
        chip_outline_width = 2, -- HoldBookC.dc.html:52
    },

    -- An outlined box on an accent.
    chip = {
        small_caps = false,
        uppercase = true, -- the canvas's chips are uppercase labels (HomeRetro.dc.html)
        text_color = "ink",
        fill_color = "pink", -- the canvas's "Now reading" chip (HomeRetro.dc.html)
        outline_color = "outline",
    },

    -- 11 px uppercase, 800, 0.1 em tracking.
    label = {
        size = 11,
        face = "display",
        small_caps = false,
        uppercase = true,
        tracking = 0.1,
    },

    -- The home's page: its margins, the gaps between rows and between columns, where the free
    -- height goes, the header drawn with row 1 and the footer. HomeRetro.dc.html is the board.
    home = {
        -- The band and the stripe are full-bleed; every other row has a 40 px side gutter
        -- (HomeRetro.dc.html:17-19, :26).
        margin = { top = 0, side = 40, bottom = 0 },
        row_gap = 22, -- the strip's and the launcher's top padding (HomeRetro.dc.html:47, :55)
        column_gap = 14, -- the launcher grid's gap (HomeRetro.dc.html:55)
        free_space = "before_footer", -- the stripe's margin-top: auto (HomeRetro.dc.html:82)
        -- A full-width band holding row 1, padded, over a 4 px ink edge (HomeRetro.dc.html:19).
        header = {
            band_color = "band",
            edge_width = 4,
            edge_color = "ink",
            rule_color = false,
            rule_width = 0,
            rule_space = 0,
            padding = { top = 36, side = 40, bottom = 28 },
            -- Its slots on its bottom, the clock's baseline level with the date
            -- (HomeRetro.dc.html:19, align-items: flex-end).
            align = "bottom",
        },
        -- 22 px of 2 px ink lines every 10 px on paper, under a 4 px ink edge (HomeRetro.dc.html:82).
        footer = {
            height = 22,
            stripe_color = "ink",
            gap_color = "paper",
            line_width = 2,
            line_pitch = 10,
            edge_width = 4,
            edge_color = "ink",
        },
        -- The weather's sun or moon before its line, and the gap after it (HomeRetro.dc.html:48-49).
        weather_icon = { size = 20, gap = 8 },
    },

    -- The home widgets' text, per part: a face role, a size in board pixels (before text_size),
    -- case, tracking in em, line height as KOReader's TextBoxWidget counts it (extra space in
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role.
    type = {
        -- Not drawn: Diner's date is one line. The look's label style, on the band.
        date_label = {
            face = "display", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "on_band",
        },
        -- The date on the band (HomeRetro.dc.html:22).
        date = { face = "strong", size = 16, uppercase = true, tracking = 0.04, line_height = 0, color = "on_band" },
        -- The clock on the band, CSS line height 0.9 (HomeRetro.dc.html:24).
        clock = {
            face = "display", size = 56, uppercase = false, tracking = -0.02, line_height = -0.1, color = "on_band",
        },
        -- The strip's weather (HomeRetro.dc.html:47).
        weather = { face = "strong", size = 13, uppercase = true, tracking = 0.06, line_height = 0, color = "ink" },
        -- No board draws Diner's quote; the quote face at Editorial's size and line height.
        quote = { face = "quote", size = 18, uppercase = false, tracking = 0, line_height = 0.4, color = "ink" },
        -- The strip's reading stats (HomeRetro.dc.html:47).
        stats = { face = "strong", size = 13, uppercase = true, tracking = 0.06, line_height = 0, color = "ink" },
        -- The typographic cover's title, CSS line height 1.05 (HomeRetro.dc.html:29). The board's
        -- Georgia is not a Diner face, so the display face stands in.
        cover_title = {
            face = "display", size = 22, uppercase = true, tracking = 0.04, line_height = 0.05, color = "on_cover",
        },
        -- Its authors at the foot (HomeRetro.dc.html:30).
        cover_authors = {
            face = "text", size = 10, uppercase = true, tracking = 0.12, line_height = 0, color = "on_cover",
        },
        -- "No book yet" in the first run's dashed frame. No board draws Diner's first run; Editorial's
        -- line (EmptyStates.dc.html:33) in Diner's strong face.
        cover_empty = {
            face = "strong", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- "Now reading" in its chip, in chip.text_color (HomeRetro.dc.html:34).
        featured_label = {
            face = "display", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- The featured book's title, two lines at most, CSS line height 1.05 (HomeRetro.dc.html:35).
        featured_title = {
            face = "display", size = 28, uppercase = false, tracking = 0, line_height = 0.05, color = "ink",
        },
        -- "authors · chapter" (HomeRetro.dc.html:36).
        featured_authors = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "muted",
        },
        -- Not drawn on its own: Diner's chapter joins the authors line (HomeRetro.dc.html:36), in its style.
        featured_chapter = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "muted",
        },
        -- "62% · 2 h 10 min left" under the bar (HomeRetro.dc.html:41).
        featured_caption = {
            face = "strong", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- No board draws Diner's first run; Editorial's sizes and line heights
        -- (EmptyStates.dc.html:36-38) in Diner's faces, the body in muted as its authors line.
        featured_empty_title = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0.15, color = "ink",
        },
        featured_empty_body = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0.4, color = "muted",
        },
        featured_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- A launcher tile's label (HomeRetro.dc.html:56, weight 800).
        launcher_label = {
            face = "display", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- Its suffix, "off" or "plugin missing": no board; the look's label style (label above).
        launcher_suffix = {
            face = "display", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- A sheet's heading on its band, "Home" (HoldHomeC.dc.html:32).
        sheet_heading = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- The heading's aside, "KoPanda" (HoldHomeC.dc.html:33).
        sheet_aside = {
            face = "accent", size = 22, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- The book header's title, CSS line height 1.05 (HoldBookC.dc.html:34).
        sheet_title = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0.05, color = "on_accent",
        },
        -- Its author (HoldBookC.dc.html:35).
        sheet_author = {
            face = "text", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- Its meta line, "62% · Part 3 · opened yesterday" (HoldBookC.dc.html:36).
        sheet_meta = {
            face = "strong", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- A sheet row's label (HoldBookC.dc.html:39).
        sheet_row = { face = "strong", size = 17, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- A row's plain detail, the weather's age (HoldHomeC.dc.html:48).
        sheet_detail = {
            face = "strong", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- A row's detail in its chip, the read status (HoldBookC.dc.html:52).
        sheet_chip = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- The editor screens have no Diner board: the direction doc's vocabulary ("The two looks"),
        -- the header's aside and title on the band as the home's date and clock are (HomeRetro.dc.html:22-24),
        -- the rest in the look's label style and Editorial's sizes.
        -- no board: Editorial's line height, so the default layout's five rows fit above the foot
        editor_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "on_band",
        },
        -- no board: Editorial's line height
        editor_title = {
            face = "display", size = 30, uppercase = false, tracking = 0, line_height = 0.3, color = "on_band",
        },
        -- no board: Editorial's line height
        editor_button = {
            face = "display", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "ink",
        },
        -- no board: Editorial's line height
        editor_caption = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "muted",
        },
        -- no board: Editorial's line height
        editor_box = {
            face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- no board: Editorial's line height
        editor_share = {
            face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        -- no board: Editorial's line height, so six rows fit above the add-an-entry foot
        editor_label = {
            face = "strong", size = 16, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- no board: Editorial's line height
        editor_kind = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0.3, color = "muted",
        },
        -- no board: Editorial's line height
        editor_note = {
            face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
    },

    -- The launcher: a grid of outlined tiles with the tile shadow, the first three on accents.
    launcher = {
        columns = 3, -- HomeRetro.dc.html:55
        column_gap = 14, -- HomeRetro.dc.html:55
        row_gap = 14, -- HomeRetro.dc.html:55
        icon_size = 28, -- HomeRetro.dc.html:57
        icon_gap = false, -- the icon sits above the label, not beside it
        padding = { x = 14, y = 12 }, -- HomeRetro.dc.html:56
        tile_height = 104, -- HomeRetro.dc.html:56
        accent_1_color = "mustard", -- HomeRetro.dc.html:56
        accent_2_color = "pink", -- HomeRetro.dc.html:60
        accent_3_color = "teal", -- HomeRetro.dc.html:64
        suffix_gap = 6, -- no board; unused while the suffix is below
        suffix_below = true, -- no board: "Terminal PLUGIN MISSING" doesn't fit a third on one line
    },

    -- The featured book's cover box.
    featured = {
        cover_w = 140, -- HomeRetro.dc.html:28
        cover_h = 210, -- HomeRetro.dc.html:28
        cover_padding = { x = 12, y = 16 }, -- the placeholder's padding (HomeRetro.dc.html:28)
        dash = 4, -- the first run's dashed frame, as Editorial's: 4 px dashes
        dash_gap = 4, -- with 4 px gaps (EmptyStates.dc.html:33)
        gap = 20, -- between the cover and the text column (HomeRetro.dc.html:27)
        column_padding_y = 6, -- the text column's padding (HomeRetro.dc.html:32)
        title_gap = 12, -- the column's 6 px gap and the title's 6 px margin (HomeRetro.dc.html:33, :35)
        chip_outline = 2, -- the "Now reading" chip's border (HomeRetro.dc.html:34)
        chip_padding = { x = 10, y = 3 }, -- HomeRetro.dc.html:34
        -- No board draws Diner's first run: the button takes Editorial's padding
        -- (EmptyStates.dc.html:38) and the Library tile's fill, outline and tile shadow (HomeRetro.dc.html:56).
        button_padding = { x = 14, y = 9 },
        button_fill_color = "mustard",
        button_outline_color = "outline",
    },
    -- The editor screens, edit layout and launcher management. No board draws Diner's: the
    -- direction doc's vocabulary ("The two looks"), a teal header band, 3 px ink outlines, hard
    -- 4 px shadows on cards (shadow.tile) and a flat mustard fill for the selected card; spacing as
    -- Editorial's boards give it.
    editor = {
        padding = { top = 40, side = 40, bottom = 28 }, -- no board: Editorial's
        header_band_color = "band", -- no board: the home's teal header band (HomeRetro.dc.html)
        header_text_color = "on_band", -- no board: the band's text (HomeRetro.dc.html:19)
        header_rule_color = "outline", -- no board: the doc's ink strokes
        header_rule_width = 3, -- no board: stroke.outline
        header_gap = 16, -- no board: Editorial's
        body_gap = 18, -- no board: Editorial's
        button_outline_color = "outline", -- no board: the doc's ink strokes
        button_outline_width = 3, -- no board: stroke.outline
        button_fill_color = "paper", -- no board: a paper button on the band
        button_padding = { x = 14, y = 8 }, -- no board: Editorial's
        card_gap = 10, -- no board: 10, so the default layout's five rows fit with one selected (owner decision)
        card_padding = { x = 14, y = 12 }, -- no board: Editorial's
        card_outline_color = "outline", -- no board: the doc's ink outlines
        card_outline_width = 3, -- no board: stroke.outline
        selected_outline_color = "outline", -- no board: the doc's ink outlines
        selected_fill_color = "mustard", -- no board: the doc's flat accent fills
        arrow_size = 28, -- no board: Editorial's
        arrow_gap = 14, -- no board: Editorial's
        disabled_color = "muted", -- no board: Diner has no hairline
        box_padding = { x = 12, y = 10 }, -- no board: Editorial's
        box_gap = 8, -- no board: Editorial's
        row_padding = { y = 14 }, -- no board: Editorial's
        row_rule_color = "outline", -- no board: the doc's ink strokes
        row_rule_width = 2, -- no board: the sheets' row rules (sheet.row_rule_width)
        icon_size = 22, -- no board: Editorial's
        icon_gap = 14, -- no board: Editorial's
        control_size = 30, -- no board: Editorial's
        kind_gap = 8, -- no board: Editorial's
        kind_columns = 2, -- no board: Editorial's
    },
}
