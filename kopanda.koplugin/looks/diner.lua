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
        -- No board: the nav bar's band, the Settings tab the sheet rises from (nav.fill_color)
        quick_settings_band_color = "band",
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
        -- The sort and status sheets (cover-grid "The pickers"); SortC.dc.html's heading 28 and row
        -- padding 16 are not taken, so the other sheets keep their sizes.
        selected_fill_color = "teal", -- the current choice's row (SortC.dc.html:45)
        aside_above_gap = 2, -- "for this folder" over "Sort" (SortC.dc.html:39)
        sublabel_gap = 2, -- a row's label over its second line (SortC.dc.html:46)
    },

    -- The quick-settings sheet's body. No board draws Diner's: its own sheet's rows and rules, its
    -- progress bar for the levels, its chips' 2 px outline for the buttons and tiles, the on tile
    -- an ink fill with paper text (the direction doc's "The two looks"); the rest Editorial's
    -- (QuickSettings.dc.html).
    quick_settings = {
        padding_x = 20, -- the sheet's row_padding.x, above
        first_section_padding = { top = 15, bottom = 15 }, -- the sheet's row_padding.y
        section_padding = { top = 15, bottom = 15 }, -- the sheet's row_padding.y
        section_gap = 10, -- no board: Editorial's (QuickSettings.dc.html:40)
        section_rule_width = 2, -- the sheet's row_rule_width
        section_rule_color = "outline", -- the sheet's row_rule_color
        control_gap = 12, -- no board: Editorial's (QuickSettings.dc.html:44)
        button_w = 44, -- no board: Editorial's (QuickSettings.dc.html:45)
        button_h = 36, -- no board: Editorial's (QuickSettings.dc.html:45)
        button_outline_width = 2, -- the sheet's chip_outline_width
        button_outline_color = "outline", -- the doc: strokes are ink
        button_fill_color = "paper", -- the sheet's fill_color
        level_h = 14, -- progress.height
        level_outline_width = 2, -- progress.outline_width
        level_outline_color = "outline", -- progress.outline_color
        level_fill_color = "mustard", -- progress.fill_color
        level_track_color = "paper", -- progress.track_color
        grid_gap = 10, -- no board: Editorial's (QuickSettings.dc.html:62)
        -- The sheet's row_padding.y above; below, its row_padding.x, since the sheet has no bottom padding
        grid_padding = { top = 15, bottom = 20 },
        cell_padding = { top = 14, bottom = 12 }, -- no board: Editorial's (QuickSettings.dc.html:63)
        cell_gap = 8, -- no board: Editorial's (QuickSettings.dc.html:63)
        cell_icon_size = 24, -- no board: Editorial's (QuickSettings.dc.html:64)
        cell_outline_width = 2, -- the owner's 2 px outlined tiles
        cell_outline_color = "outline", -- the doc: strokes are ink
        cell_fill_color = "paper", -- the sheet's fill_color
        on_fill_color = "ink", -- the owner: the on state an ink fill
        on_text_color = "paper", -- with paper text
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
    -- Its row gap, the header's padding and the launcher's row gap are tightened to 62 % of the
    -- board's, rounded, the least that fits the default rows above the nav bar at the small and
    -- medium text sizes on the Colorsoft and the Paperwhite (owner, 2026-10-16: tighten the
    -- home's spacing). The launcher's tile height is not: 104 is its icon, label and suffix at
    -- the large text size.
    home = {
        -- The band and the stripe are full-bleed; every other row has a 40 px side gutter
        -- (HomeRetro.dc.html:17-19, :26).
        margin = { top = 0, side = 40, bottom = 0 },
        row_gap = 14, -- the strip's and the launcher's top padding (HomeRetro.dc.html:47, :55; was 22)
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
            padding = { top = 22, side = 40, bottom = 17 }, -- was 36, 40, 28
            -- Its slots on its bottom, the clock's baseline level with the date
            -- (HomeRetro.dc.html:19, align-items: flex-end).
            align = "bottom",
        },
        -- HomeRetro.dc.html:82 draws 22 px of 2 px ink lines every 10 px on paper under a 4 px
        -- ink edge; the bar always shows on the home and NavBarC.dc.html:70 draws no stripe above
        -- it, so the stripe has no height (was 22).
        footer = {
            height = 0,
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
        -- The header's label at its right, "Library" (SortC.dc.html:43).
        sheet_label = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- A row's second line, "Last opened first", weight 500 in the board's ink (SortC.dc.html:48).
        sheet_sublabel = { face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- A quick-settings bar's label and value; no board: sheet_detail's style.
        quick_label = {
            face = "strong", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- The bars' minus and plus; no board: sheet_row's face at Editorial's size (QuickSettings.dc.html:45).
        quick_button = {
            face = "strong", size = 18, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- A quick-settings tile's label; no board: sheet_chip's style.
        quick_cell = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
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
        -- A nav tab's label (NavBarC.dc.html:75, weight 700).
        nav_label = { face = "strong", size = 12, uppercase = true, tracking = 0.04, line_height = 0, color = "ink" },
        -- The active tab's label on its mustard block (NavBarC.dc.html:71, weight 800), in the dark
        -- text the look puts on mustard, so the night block keeps dark text.
        nav_label_active = {
            face = "display", size = 12, uppercase = true, tracking = 0.04, line_height = 0, color = "on_accent",
        },
        -- The file browser's book count over its title, in Caveat at its default weight
        -- (LibraryC.dc.html:21; CSS line height 1), in the band's dark text.
        title_bar_count = {
            face = "accent", size = 24, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- Its title (LibraryC.dc.html:22, weight 800); CSS line height 0.95, as the clock's -0.1 for 0.9.
        title_bar_title = {
            face = "display", size = 40, uppercase = false, tracking = -0.01, line_height = -0.05,
            color = "on_accent",
        },
        -- The sort chip's label, ink on paper (LibraryC.dc.html:25, weight 800).
        title_bar_sort = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The status chip's label on pink (LibraryC.dc.html:26, weight 800), the dark text on accents.
        title_bar_status = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- The library's parts (Main.dc.html under .tiller/design/2026-10-16-kopanda-library-screens/).
        -- The count over the title, in Caveat, CSS line height 1, in the band's dark text (Main.dc.html:21).
        library_count = {
            face = "accent", size = 24, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- The title (Main.dc.html:22, weight 800); CSS line height 0.95, as the clock's -0.1 for 0.9.
        library_title = {
            face = "display", size = 40, uppercase = false, tracking = -0.01, line_height = -0.05,
            color = "on_accent",
        },
        -- A picker's label, ink on the paper chip (Main.dc.html:25, weight 800).
        library_picker = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The status picker's label on its pink chip (Main.dc.html:26), the dark text on accents.
        library_picker_status = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- A tile's title, one line, CSS line height 1.2 (Main.dc.html:47, weight 800).
        tile_title = {
            face = "display", size = 12, uppercase = true, tracking = 0.04, line_height = 0.2, color = "ink",
        },
        -- The placeholder's title at the grid's size, CSS line height 1.1 (Main.dc.html:51). The board's
        -- Georgia is not a Diner face, so the display face stands in, as in cover_title.
        tile_cover_title = {
            face = "display", size = 17, uppercase = false, tracking = 0, line_height = 0.1, color = "on_cover",
        },
        -- A folder's book count on its pink box, in Caveat, CSS line height 1 (Main.dc.html:35).
        folder_count = {
            face = "accent", size = 26, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- Its reading count (Main.dc.html:36, weight 800).
        folder_reading = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- "Not downloaded" on its pink chip (Main.dc.html:73, weight 800).
        not_downloaded = {
            face = "display", size = 10, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- "Page 1 of 24" between the pager's boxes (Main.dc.html:87, weight 800).
        pager_label = {
            face = "display", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The series and authors screens' parts (SeriesC.dc.html, SeriesBooksC.dc.html and
        -- AuthorsC.dc.html under .tiller/design/2026-10-16-kopanda-library-screens/); weight 700 is the
        -- strong face and 800 the display face. Text on the mustard, pink and teal fills is on_accent.
        -- One series' title on its band, CSS line height 0.95 (SeriesBooksC.dc.html:27, weight 800).
        shelf_detail_title = {
            face = "display", size = 36, uppercase = false, tracking = -0.01, line_height = -0.05,
            color = "on_accent",
        },
        -- The back control's label, ink on its paper box (SeriesBooksC.dc.html:20, weight 800).
        shelf_back = { face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink" },
        -- A series row's name, CSS line height 1.1 (SeriesC.dc.html:35, weight 800).
        series_name = {
            face = "display", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- Its sub-line (SeriesC.dc.html:36, weight 500).
        series_sub = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- A chip's label on its mustard, teal or pink fill (SeriesC.dc.html:39, weight 800).
        shelf_chip = {
            face = "display", size = 10, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- A chip's label on its paper fill (SeriesC.dc.html:88, weight 800).
        shelf_chip_plain = {
            face = "display", size = 10, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- A book row's series index, CSS line height 1 (SeriesBooksC.dc.html:34, weight 800).
        book_index = { face = "display", size = 40, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- Its title, CSS line height 1.1 (SeriesBooksC.dc.html:37, weight 800).
        book_row_title = {
            face = "display", size = 20, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- "read this one next" in Caveat on the mustard row, CSS line height 1 (SeriesBooksC.dc.html:47).
        book_next_note = {
            face = "accent", size = 22, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- "Not on the Kindle yet" (SeriesBooksC.dc.html:60, weight 500).
        book_row_note = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- A group's letter on its mustard column (AuthorsC.dc.html:29, weight 800).
        author_letter = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- An author's name (AuthorsC.dc.html:31, weight 700).
        author_name = { face = "strong", size = 17, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- Their count, "4 books ›" (AuthorsC.dc.html:33, weight 800).
        author_count = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The empty note, as the library's (pager_label, Main.dc.html:87).
        shelf_empty = {
            face = "display", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The header's static label on the band, "Under way first" (SeriesC.dc.html:24, AuthorsC.dc.html:24).
        shelf_label = {
            face = "display", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
    },

    -- The launcher: a grid of outlined tiles with the tile shadow, the first three on accents.
    launcher = {
        columns = 3, -- HomeRetro.dc.html:55
        column_gap = 14, -- HomeRetro.dc.html:55
        row_gap = 9, -- HomeRetro.dc.html:55; was 14, tightened with the home (home above)
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
    -- 2 px shadows on cards (card_shadow) and a flat mustard fill for the selected card; spacing as
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
        card_shadow = { x = 2, y = 2, color = "shadow" }, -- owner: half the home tiles' 4, so the screens read lighter
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
    -- The nav bar: a teal band under a 4 px ink edge, five tabs of an icon over an uppercase label
    -- split by outline dividers, and the active tab a mustard block (NavBarC.dc.html:70-89).
    nav = {
        fill_color = "band", -- NavBarC.dc.html:70
        edge_width = 4, -- NavBarC.dc.html:70, as the header's edge (home.header.edge_width)
        edge_color = "ink", -- NavBarC.dc.html:70
        padding_x = 0, -- the bar is unpadded at its sides (NavBarC.dc.html:70)
        padding_top = 14, -- a tab's (NavBarC.dc.html:71)
        padding_bottom = 16, -- NavBarC.dc.html:71
        icon_size = 28, -- NavBarC.dc.html:72
        icon_gap = 6, -- the icon to the label (NavBarC.dc.html:71)
        icon_color = "ink", -- the page's ink, inherited (NavBarC.dc.html:14, :17)
        active_icon_color = "on_accent", -- the dark text on the mustard block, ink by day (NavBarC.dc.html:71)
        active_rule_width = 0, -- the active tab has no rule (NavBarC.dc.html:71)
        active_rule_color = false,
        active_fill_color = "mustard", -- NavBarC.dc.html:71
        divider_width = 3, -- NavBarC.dc.html:71, :75, :79, :83; none on the last tab (:87)
        divider_color = "outline", -- the doc: strokes are ink (NavBarC.dc.html:71)
    },
    -- The file browser's title bar: a mustard band over a 4 px ink edge, a handwritten count over the
    -- title, and the pickers as outlined chips, sort on paper and status on pink (LibraryC.dc.html:19-27).
    title_bar = {
        fill_color = "mustard", -- LibraryC.dc.html:19
        padding = { top = 30, side = 40, bottom = 20 }, -- LibraryC.dc.html:19
        edge_width = 4, -- LibraryC.dc.html:19
        edge_color = "ink", -- LibraryC.dc.html:19
        line_gap = 2, -- the count to the title (LibraryC.dc.html:20)
        picker_gap = 10, -- LibraryC.dc.html:24
        sort_fill_color = "paper", -- LibraryC.dc.html:25
        status_fill_color = "pink", -- LibraryC.dc.html:26
        picker_outline_width = 2, -- LibraryC.dc.html:25-26
        picker_outline_color = "outline", -- the look's chip outline (chip.outline_color), ink by day
        picker_padding = { x = 10, y = 4 }, -- LibraryC.dc.html:25
        icon_size = 16, -- no board draws the plus: the pickers' size
        icon_color = "on_accent", -- no board draws the plus: the band's dark text
        count_on_shelf = true, -- "142 books on the shelf" (LibraryC.dc.html:21)
    },
    -- The library: a mustard header over a 4 px ink edge, three columns of outlined covers with hard
    -- shadows and a hatched-chip strip under each, and a pager of outlined boxes above the nav bar
    -- (Main.dc.html:19-88 under .tiller/design/2026-10-16-kopanda-library-screens/). The colours the
    -- board draws in ink are the outline role, cream by night, as the doc's strokes are.
    library = {
        header = {
            fill_color = "mustard", -- Main.dc.html:19
            padding = { top = 28, side = 40, bottom = 18 }, -- Main.dc.html:19
            edge_width = 4, -- Main.dc.html:19
            edge_color = "ink", -- Main.dc.html:19
            line_gap = 2, -- the count to the title (Main.dc.html:20)
            picker_gap = 10, -- Main.dc.html:24
            picker_padding = { x = 10, y = 4 }, -- Main.dc.html:25
            picker_outline_width = 2, -- Main.dc.html:25-26
            picker_outline_color = "outline", -- Main.dc.html:25-26
            sort_fill_color = "paper", -- Main.dc.html:25
            status_fill_color = "pink", -- Main.dc.html:26
        },
        grid = {
            padding_top = 22, -- Main.dc.html:30
            side = 40, -- Main.dc.html:30
            row_gap = 22, -- Main.dc.html:30
            column_gap = 22, -- Main.dc.html:30
            cover_h = 195, -- D2: board 200, so two rows fit (Main.dc.html:32, :43)
            strip_gap = 12, -- the tile's 8 px gap and the strip's 4 px margin (Main.dc.html:42, :46)
            title_gap = 8, -- the tile's gap (Main.dc.html:42)
        },
        cover = {
            outline_width = 3, -- Main.dc.html:43
            outline_color = "outline", -- Main.dc.html:43
            radius = 0, -- Main.dc.html:43
            shadow = { x = 5, y = 5, color = "shadow" }, -- Main.dc.html:43
            padding = { x = 10, y = 14 }, -- the placeholder's (Main.dc.html:43)
        },
        strip = {
            height = 14, -- its outline included (Main.dc.html:46, box-sizing: border-box)
            outline_width = 2, -- Main.dc.html:46
        },
        folder = {
            fill_color = "pink", -- Main.dc.html:32
            outline_width = 3, -- Main.dc.html:32
            outline_color = "outline", -- Main.dc.html:32
            icon_size = 44, -- Main.dc.html:33
            icon_color = "on_accent", -- the board's ink on pink (Main.dc.html:33), dark by night too
            padding = { x = 12, y = 14 }, -- Main.dc.html:32
            count_gap = 4, -- Main.dc.html:34
        },
        badge = {
            size = 38, -- Main.dc.html:66
            outline_width = 3, -- Main.dc.html:66
            outline_color = "outline", -- Main.dc.html:66
            fill_color = "paper", -- Main.dc.html:66
            icon_size = 20, -- Main.dc.html:67
            icon_color = "ink", -- Main.dc.html:67
            inset = -12, -- overhanging the corner (Main.dc.html:66, right: -12px; top: -12px)
            align = "top", -- Main.dc.html:66
        },
        not_downloaded = {
            fill_color = "pink", -- Main.dc.html:73
            outline_width = 2, -- Main.dc.html:73
            outline_color = "outline", -- Main.dc.html:73
            padding = { x = 6, y = 1 }, -- Main.dc.html:73
        },
        pager = {
            button_w = 44, -- Main.dc.html:86, :88
            button_h = 32, -- Main.dc.html:86, :88
            gap = 18, -- Main.dc.html:85
            bottom = 16, -- Main.dc.html:85
            outline_width = 2, -- Main.dc.html:86, :88
            outline_color = "outline", -- Main.dc.html:86, :88
            prev_fill_color = "paper", -- Main.dc.html:86
            next_fill_color = "mustard", -- Main.dc.html:88
            dead_color = false, -- Main draws no dead arrow: it is left out (cover-grid D16)
            prev_icon_color = "ink", -- on the paper box (Main.dc.html:86)
            next_icon_color = "on_accent", -- on the mustard box, dark by night too (Main.dc.html:88)
            label_in_words = true, -- "Page 1 of 24" (Main.dc.html:87)
        },
    },
    -- The series and authors screens: the library's header on a pink or teal band, outlined rows with
    -- hard shadows, stacked covers and filled chips, the up-next book on mustard, and letter groups
    -- (SeriesC.dc.html, SeriesBooksC.dc.html, AuthorsC.dc.html under
    -- .tiller/design/2026-10-16-kopanda-library-screens/). Outlines are the tile's outline role and
    -- shadows the tile's shadow role, ink by day and cream by night; covers are outlined in the
    -- library's cover role. Diner's one author is undrawn (D26).
    shelf = {
        series_fill_color = "pink", -- SeriesC.dc.html:19
        authors_fill_color = "teal", -- AuthorsC.dc.html:19
        detail = {
            padding = { top = 22, side = 40, bottom = 18 }, -- SeriesBooksC.dc.html:19
            back_gap = 10, -- SeriesBooksC.dc.html:19
        },
        back = {
            fill_color = "paper", -- SeriesBooksC.dc.html:20
            outline_width = 2, -- SeriesBooksC.dc.html:20
            padding = { left = 6, right = 10, y = 4 }, -- SeriesBooksC.dc.html:20
            icon_size = 14, -- SeriesBooksC.dc.html:21
            gap = 6, -- SeriesBooksC.dc.html:20
        },
        list = {
            padding_top = 22, -- SeriesC.dc.html:27
            side = 40, -- SeriesC.dc.html:27
            row_gap = 14, -- SeriesC.dc.html:27
        },
        row = {
            -- y: owner's fit 2026-10-17: board 12, five rows a page at the Colorsoft
            padding = { x = 16, y = 11 }, -- SeriesC.dc.html:28
            gap = 18, -- SeriesC.dc.html:28
            line_gap = 3, -- SeriesC.dc.html:34, the name to its sub-line
            outline_width = 3, -- SeriesC.dc.html:28
            shadow = { x = 4, y = 4 }, -- SeriesC.dc.html:28
            rule_width = 0, -- boxed, not ruled (SeriesC.dc.html:28)
            rule_color = "ink", -- SeriesC.dc.html:28, unused at rule_width 0
        },
        stack = {
            cover_w = 38, -- SeriesC.dc.html:30-32
            cover_h = 56, -- SeriesC.dc.html:30-32
            offset_x = 10, -- SeriesC.dc.html:30-32
            offset_y = 2, -- SeriesC.dc.html:30-32
            outline_width = 2, -- SeriesC.dc.html:30-32
            outline_color = "outline", -- SeriesC.dc.html:30-32
        },
        chip = {
            padding = { x = 7, y = 1 }, -- SeriesC.dc.html:39
            outline_width = 2, -- SeriesC.dc.html:39
            under_way_fill_color = "mustard", -- SeriesC.dc.html:39
            finished_fill_color = "teal", -- SeriesC.dc.html:76
            not_started_fill_color = "paper", -- SeriesC.dc.html:88
            up_next_fill_color = "paper", -- SeriesBooksC.dc.html:49
            not_downloaded_fill_color = "pink", -- SeriesBooksC.dc.html:62
        },
        books = {
            padding_top = 24, -- SeriesBooksC.dc.html:32
            row_gap = 18, -- SeriesBooksC.dc.html:32
        },
        book = {
            padding = { x = 16, y = 14 }, -- SeriesBooksC.dc.html:33
            index_w = 40, -- SeriesBooksC.dc.html:34
            cover_w = 64, -- the content, the outline outside it, as the board's CSS (SeriesBooksC.dc.html:35)
            cover_h = 96, -- the content, the outline outside it, as the board's CSS (SeriesBooksC.dc.html:35)
            cover_outline_width = 2, -- SeriesBooksC.dc.html:35
            line_gap = 6, -- SeriesBooksC.dc.html:36
            bar_height = 10, -- the track inside the outline (SeriesBooksC.dc.html:38)
            bar_outline_width = 2, -- SeriesBooksC.dc.html:38
            badge_size = 28, -- SeriesBooksC.dc.html:54
            badge_outline_width = 2, -- SeriesBooksC.dc.html:54
            badge_icon_size = 14, -- SeriesBooksC.dc.html:55
            badge_inset = -10, -- overhanging the corner (SeriesBooksC.dc.html:54, right: -10px; top: -10px)
        },
        next = {
            fill_color = "mustard", -- SeriesBooksC.dc.html:42
            shadow = { x = 6, y = 6 }, -- SeriesBooksC.dc.html:42
            line_gap = 4, -- SeriesBooksC.dc.html:45
            text_color = "on_accent", -- the dark text on mustard (SeriesBooksC.dc.html:42)
        },
        groups = {
            padding_top = 22, -- AuthorsC.dc.html:27
            gap = 12, -- AuthorsC.dc.html:27
        },
        group = {
            outline_width = 3, -- AuthorsC.dc.html:28
            shadow = { x = 4, y = 4 }, -- AuthorsC.dc.html:28
            rule_width = 0, -- boxed, not ruled (AuthorsC.dc.html:28)
            rule_color = "ink", -- AuthorsC.dc.html:28, unused at rule_width 0
            letter_w = 48, -- AuthorsC.dc.html:29
            letter_fill_color = "mustard", -- AuthorsC.dc.html:29
            letter_rule_width = 3, -- AuthorsC.dc.html:29
        },
        author = {
            padding = { x = 16, y = 11 }, -- AuthorsC.dc.html:31
            rule_width = 2, -- AuthorsC.dc.html:31
            rule_color = "outline", -- AuthorsC.dc.html:31
        },
        author_grid = {
            -- Main.dc.html:32's 200, less the one-author header's 26 px over the library's
            -- (SeriesBooksC.dc.html:19-30 against Main.dc.html:19-27).
            cover_h = 174, -- lead: by analogy with Main.dc.html:32
        },
        up_next = {
            fill_color = "paper", -- SeriesBooksC.dc.html:49
            outline_width = 2, -- SeriesBooksC.dc.html:49
        },
    },
}
