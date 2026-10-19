-- Diner: a heavy grotesque, ink outlines, hard shadows and flat accent fills. Declares only what differs from
-- the base look (looks/base.lua).
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
            text = "#2f2e2b", -- Diner's text is its ink
            teal = "#6fb3ab",
            pink = "#e8a59d",
            mustard = "#e0bd6a",
            band = "#6fb3ab",
            outline = "#2f2e2b",
            shadow = "#2f2e2b",
            on_band = "#f5f1e6",
            on_accent = "#2f2e2b",
            cover = "#2b4c6f",
            on_cover = "#f5f1e6",
        },
        night = {
            paper = "#1e1c1a",
            ink = "#f1ece0",
            muted = "#bdb7a9",
            text = "#f1ece0", -- Diner's text is its ink
            teal = "#2f6b65",
            pink = "#b86f68",
            mustard = "#b8923c",
            band = "#2f6b65",
            outline = "#f1ece0",
            shadow = "#f1ece0",
            on_band = "#f1ece0",
            -- The night paper: mustard and pink tiles take dark text.
            on_accent = "#1e1c1a",
            cover = "#2b4c6f",
            on_cover = "#f5f1e6",
        },
        grey = {
            paper = "#f4f4f4",
            ink = "#111111",
            muted = "#444444",
            text = "#111111", -- Diner's text is its ink
            teal = "#b0b0b0",
            pink = "#e0e0e0",
            mustard = "#c8c8c8",
            band = "#9a9a9a",
            outline = "#111111", -- strokes are ink
            shadow = "#111111", -- hard shadows are ink
            on_band = "#111111",
            on_accent = "#111111",
            on_cover = "#f4f4f4",
        },
    },

    stroke = { hairline = false, hairline_grey = false, rule = false, band = 4 }, -- band edges

    shadow = {
        cover = { color = "pink" },
        tile = { x = 4, y = 4, color = "shadow" },
        sheet = { x = 8 },
    },

    progress = { fill_color = "mustard" },

    sheet = {
        inset = { side = 22, bottom = 22 },
        padding = { bottom = 0 },
        book_band_color = "pink",
        home_band_color = "mustard",
        folder_band_color = "teal",
        -- The nav bar's band, the Settings tab the sheet rises from (nav.fill_color).
        quick_settings_band_color = "band",
        header_rule_width = 3,
        header_padding = { top = 16 },
        book_header_padding = { bottom = 18 },
        cover_w = 60,
        cover_h = 90,
        line_gap = 3,
        row_padding = { y = 15 },
        row_rule_color = "outline",
        last_row_bottom = 15,
        status_chip_color = "mustard",
        state_chip_color = "teal",
        chip_padding = { y = 2 },
        selected_fill_color = "teal",
        -- The library's folder sheet: its band, and the box its folder icon sits in, tinted (TintedIcon) so night's
        -- paper doesn't hide it.
        library_folder_band_color = "pink",
        library_empty_band_color = "mustard",
        show_chip_color = "pink",
    },

    -- The quick-settings body: the sheet's own rows and rules, the progress bar for the levels, the chips' 2 px outline
    -- for the buttons and tiles, the on tile an ink fill with paper text; the rest Editorial's.
    quick_settings = {
        section_rule_color = "outline", -- the sheet's row_rule_color
        level_fill_color = "mustard", -- progress.fill_color
        on_text_color = "paper", -- with paper text
    },

    chip = { fill_color = "pink" },

    label = { face = "display" },

    -- The row gap, the header's padding and the launcher's row gap are tightened to 62 % of Editorial's, the least
    -- that fits the default rows above the nav bar at the small and medium text sizes on both devices. The
    -- launcher's tile height is not: 104 is its icon, label and suffix at the large text size.
    home = {
        -- The band and the stripe are full-bleed; every other row has a 40 px side gutter.
        margin = { top = 0, bottom = 0 },
        row_gap = 14,
        column_gap = 14,
        free_space = "before_footer",
        header = {
            band_color = "band",
            edge_width = 4,
            edge_color = "ink",
            padding = { top = 22, side = 40, bottom = 17 },
        },
        -- The stripe has no height: the nav bar always shows on the home and draws none above it.
        footer = {
            stripe_color = "ink",
            gap_color = "paper",
            line_width = 2,
            line_pitch = 10,
            edge_width = 4,
            edge_color = "ink",
        },
        weather_icon = { size = 20, gap = 8 },
        date_lines = 1,
    },

    type = {
        -- Not drawn: Diner's date is one line. The look's label style, on the band.
        date_label = { face = "display", color = "on_band" },
        date = { size = 16, uppercase = true, tracking = 0.04, line_height = 0, color = "on_band" },
        clock = { size = 56, line_height = -0.1, color = "on_band" },
        weather = { face = "strong", size = 13, uppercase = true, tracking = 0.06, color = "ink" },
        -- The quote face at Editorial's size and line height.
        quote = { line_height = 0.4 },
        stats = { size = 13, tracking = 0.06, color = "ink" },
        -- The display face stands in for the cover title's serif.
        cover_title = { size = 22 },
        cover_authors = { face = "text" },
        -- Editorial's line in Diner's strong face.
        cover_empty = { size = 12 },
        featured_label = { face = "display" },
        featured_title = { line_height = 0.05 },
        featured_authors = { size = 15, color = "muted" },
        -- Not drawn on its own: the chapter joins the authors line, in its style.
        featured_chapter = { size = 15, color = "muted" },
        featured_caption = { size = 13, color = "ink" },
        -- Editorial's sizes and line heights in Diner's faces, the body in muted as its authors line.
        featured_empty_title = { line_height = 0.15 },
        featured_empty_body = { size = 15, color = "muted" },
        launcher_label = { face = "display", size = 14, line_height = 0 },
        -- The look's label style.
        launcher_suffix = { face = "display" },
        sheet_heading = { size = 24, line_height = 0 },
        sheet_aside = { face = "accent", size = 22, uppercase = false, tracking = 0, color = "on_accent" },
        sheet_author = { size = 14 },
        sheet_meta = { size = 12, uppercase = true, tracking = 0.08 },
        sheet_row = { face = "strong" },
        sheet_detail = { size = 12, tracking = 0.08 },
        sheet_chip = { face = "display", tracking = 0.08 },
        -- sheet_chip in ink, since on_accent is the night paper by night.
        sheet_chip_plain = { face = "display", tracking = 0.08 },
        sheet_label = { face = "display", tracking = 0.08, color = "on_accent" },
        sheet_sublabel = { size = 12, color = "ink" },
        -- sheet_detail's style.
        quick_label = { size = 12, tracking = 0.08 },
        -- sheet_chip's style.
        quick_cell = { face = "display", tracking = 0.08 },
        -- The editor screens: the header's aside and title on the band as the home's date and clock are, the rest in
        -- the look's label style; Editorial's line height, so the default layout's five rows fit above the foot.
        editor_aside = { color = "on_band" },
        editor_title = { size = 30, color = "on_band" },
        editor_button = { face = "display", tracking = 0.1 },
        editor_caption = { tracking = 0.1 },
        editor_kind = { tracking = 0.08 },
        nav_label = { size = 12, tracking = 0.04, color = "ink" },
        -- In the dark text the look puts on mustard, so the night block keeps dark text.
        nav_label_active = { face = "display", size = 12, tracking = 0.04, color = "on_accent" },
        title_bar_count = { face = "accent", size = 24, uppercase = false, tracking = 0, color = "on_accent" },
        title_bar_title = { size = 40, tracking = -0.01, color = "on_accent" },
        title_bar_sort = { face = "display", tracking = 0.08 },
        title_bar_status = { face = "display", tracking = 0.08, color = "on_accent" },
        library_count = { face = "accent", size = 24, uppercase = false, tracking = 0, color = "on_accent" },
        library_title = { size = 40, tracking = -0.01, color = "on_accent" },
        library_picker = { face = "display", tracking = 0.08 },
        library_picker_status = { face = "display", tracking = 0.08, color = "on_accent" },
        tile_title = { face = "display", uppercase = true, tracking = 0.04 },
        -- The display face stands in for the serif, as in cover_title.
        tile_cover_title = { size = 17 },
        folder_count = { face = "accent", size = 26, line_height = 0, color = "on_accent" },
        folder_reading = { face = "display", color = "on_accent" },
        pager_label = { face = "display", size = 12 },
        -- Text on the mustard, pink and teal fills is on_accent.
        shelf_detail_title = { tracking = -0.01, color = "on_accent" },
        shelf_back = { face = "display" },
        series_sub = { color = "ink" },
        shelf_chip = { face = "display" },
        shelf_chip_plain = { face = "display" },
        book_row_title = { size = 20 },
        book_next_note = { face = "accent", size = 22, uppercase = false, tracking = 0 },
        book_row_note = { color = "ink" },
        author_letter = { size = 24 },
        author_count = { face = "display", tracking = 0.08, color = "ink" },
        -- The empty note, as the library's pager_label.
        shelf_empty = { face = "display", color = "ink" },
        shelf_label = { face = "display", tracking = 0.08, color = "on_accent" },
    },

    launcher = {
        column_gap = 14,
        row_gap = 9,
        icon_size = 28,
        padding = { x = 14, y = 12 },
        tile_height = 104,
        accent_1_color = "mustard",
        accent_2_color = "pink",
        accent_3_color = "teal",
        suffix_below = true,
    },

    featured = {
        cover_w = 140,
        cover_h = 210,
        cover_padding = { x = 12, y = 16 },
        gap = 20,
        column_padding_y = 6,
        chip_padding = { x = 10, y = 3 },
        button_fill_color = "mustard",
    },

    editor = {
        header_band_color = "band",
        header_text_color = "on_band",
        button_outline_width = 3,
        card_shadow = { x = 2, y = 2, color = "shadow" }, -- half the home tiles' 4, so the screens read lighter
        selected_fill_color = "mustard",
        row_rule_color = "outline",
    },

    nav = {
        fill_color = "band",
        edge_width = 4,
        padding_top = 14,
        padding_bottom = 16,
        icon_size = 28,
        icon_gap = 6,
        icon_color = "ink",
        active_icon_color = "on_accent",
        active_fill_color = "mustard",
        divider_width = 3,
        divider_color = "outline",
    },

    title_bar = {
        fill_color = "mustard",
        padding = { top = 30, bottom = 20 },
        edge_width = 4,
        edge_color = "ink",
        line_gap = 2,
        picker_gap = 10,
        status_fill_color = "pink",
        picker_padding = { y = 4 },
        icon_color = "on_accent",
        count_on_shelf = true,
    },

    library = {
        header = {
            fill_color = "mustard",
            padding = { top = 28, bottom = 18 },
            edge_width = 4,
            edge_color = "ink",
            line_gap = 2,
            picker_gap = 10,
            picker_padding = { y = 4 },
            status_fill_color = "pink",
        },
        grid = {
            padding_top = 22,
            column_gap = 22,
        },
        cover = {
            shadow = { x = 5, y = 5 },
            padding = { y = 14 },
        },
        strip = { height = 14 },
        folder = {
            fill_color = "pink",
            icon_size = 44,
            icon_color = "on_accent",
            padding = { x = 12 },
        },
        badge = {
            size = 38,
            outline_width = 3,
            inset = -12,
        },
        -- Its padding and outline colour are the one-author grid's Up next chip on the cover.
        not_downloaded = { padding = { x = 6, y = 1 } },
        pager = {
            next_fill_color = "mustard",
            next_icon_color = "on_accent",
        },
    },

    -- Outlines are the tile's outline role and shadows the tile's shadow role, ink by day and cream by night; covers
    -- are outlined in the library's cover role.
    shelf = {
        series_fill_color = "pink",
        authors_fill_color = "teal",
        detail = { padding = { top = 22, bottom = 18 } },
        list = {
            padding_top = 22,
            row_gap = 14,
        },
        row = {
            shadow = { x = 4, y = 4 },
            rule_color = "ink",
        },
        chip = {
            padding = { x = 7, y = 1 },
            under_way_fill_color = "mustard",
            finished_fill_color = "teal",
            up_next_fill_color = "paper",
        },
        book = {
            cover_outline_width = 2,
            bar_height = 10,
        },
        next = {
            fill_color = "mustard",
            shadow = { x = 6, y = 6 },
        },
        groups = { padding_top = 22 },
        group = {
            shadow = { x = 4, y = 4 },
            rule_color = "ink",
            letter_fill_color = "mustard",
            letter_rule_width = 3,
        },
        author = { rule_color = "outline" },
    },
}
