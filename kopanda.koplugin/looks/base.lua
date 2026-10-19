-- The base look: every token path a look has, each with its default. A look's file
-- (looks/<id>.lua) declares only what differs from it, and Looks.get lays that file over this
-- table (looks.lua): every look has every path here, and a look file sets no other. Pure data.
--
-- A default is the value most looks share; on a tie, false where a look has none of the thing,
-- then Editorial's. The palettes hold only the colours most looks share; each look declares its
-- own. Where a look's value comes from is noted in that look's file.
--
-- Sizes are board pixels (the canvas's half size), scaled at draw time by Screen:scaleBySize;
-- font sizes go to Font:getFace unscaled. Colours are #rrggbb in the palettes only; every other
-- token names a colour by its palette role. false is a token a look doesn't have.
return {
    -- The faces type is set in, by role: a font file under fonts/ and its label, or false for none.
    faces = {
        display = { file = "fonts/newsreader/Newsreader16pt-Medium.ttf", label = "Newsreader 500" },
        text = { file = "fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf", label = "IBM Plex Sans 400" },
        accent = { file = false, label = false },
        strong = { file = "fonts/ibm-plex-sans/IBMPlexSans-Medium.ttf", label = "IBM Plex Sans 500" },
        quote = { file = "fonts/newsreader/Newsreader16pt-MediumItalic.ttf", label = "Newsreader 500 italic" },
    },

    -- The icon set: a set id under icons/, or false for the registry's default Lucide set.
    icons = {
        set = false,
    },

    -- The palettes by variant, night painted inverted (Looks.palette): a #rrggbb or false per role.
    palettes = {
        day = {
            paper = false,
            ink = false,
            muted = false,
            text = false,
            hairline = false,
            hairline_light = false,
            teal = false,
            pink = false,
            mustard = false,
            violet = false,
            yellow = false,
            tint = false,
            sun = false,
            coral = false,
            mint = false,
            die = false,
            band = false,
            outline = false,
            shadow = false,
            on_band = false,
            on_accent = false,
            cover = false,
            on_cover = false,
        },
        night = {
            paper = false,
            ink = false,
            muted = false,
            text = false,
            hairline = false,
            hairline_light = false,
            teal = false,
            pink = false,
            mustard = false,
            violet = false,
            yellow = false,
            tint = false,
            sun = false,
            coral = false,
            mint = false,
            die = false,
            band = false,
            outline = false,
            shadow = false,
            on_band = false,
            on_accent = false,
            cover = false,
            on_cover = false,
        },
        grey = {
            paper = "#ffffff",
            ink = "#000000",
            muted = "#333333",
            text = "#000000",
            hairline = false,
            hairline_light = false,
            teal = false,
            pink = false,
            mustard = false,
            violet = false,
            yellow = false,
            tint = false,
            sun = false,
            coral = false,
            mint = false,
            die = false,
            band = false,
            outline = "#000000",
            shadow = false,
            on_band = false,
            on_accent = "#000000",
            cover = "#4a4a4a",
            on_cover = "#ffffff",
        },
    },

    -- The line widths the parts share; hairline_grey is the hairline on a grey screen.
    stroke = {
        hairline = 1,
        hairline_grey = 2,
        rule = 2,
        outline = 3,
        band = false,
    },

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide.
    shadow = {
        cover = { x = 6, y = 6, color = "shadow", outline_width = false },
        tile = { x = 0, y = 0, color = false, outline_width = false },
        sheet = { x = 0, y = 8, color = "shadow", outline_width = false },
    },

    -- Display type printed twice, an offset copy in color under the part's own; 0, 0, false prints once.
    misregister = { x = 0, y = 0, color = false },

    -- The plates a look sets its home rows on; fill_color false draws none (layout.lua, home_rows.lua).
    plate = {
        fill_color = false,
        keyline = 0,
        keyline_color = false,
        radius = 0,
        lighten = { day = false, night = false, grey = false },
        slots = {
            date = { x = 0, y = 0, radius = 0 },
            clock = { x = 0, y = 0, radius = 0 },
            weather = { x = 0, y = 0, radius = 0 },
            stats = { x = 0, y = 0, radius = 0 },
            quote = { x = 0, y = 0, radius = 0 },
            featured = { x = 0, y = 0, radius = 0 },
            launcher = false, -- no plate round the launcher: its tiles are its own
        },
    },

    -- The owner's image behind the home (wallpaper.file); enabled false draws the look's paper.
    wallpaper = {
        enabled = false,
    },

    -- Corner radii: the cover's and the launcher's boxed tiles'; 0 is square.
    radius = {
        cover = 0,
        box = 0,
    },

    -- A tile: a box (box true) with its fill and outline, or a text row with a rule under it.
    tile = {
        box = true,
        fill_color = "paper",
        outline_color = "outline",
        rule_color = false,
    },

    -- The progress bar: its height, fill and track, outline, grey fill and ends.
    progress = {
        height = 14,
        fill_color = "ink",
        track_color = "paper",
        outline_color = "outline",
        outline_width = 2,
        fill_grey = "hatch_135", -- the fill's pattern on a grey screen
        radius = 0, -- 0 paints square ends through paintRect
    },

    -- The sheets from the bottom edge (the book's, the home's, a folder's, quick settings', the
    -- library's): the panel or inset box, its header and band, its rows and chips.
    sheet = {
        fill_color = "paper",
        rule_color = false,
        rule_width = 0,
        outline_color = "outline",
        outline_width = 3,
        header_band = true,
        inset = { side = 16, bottom = 16 },
        padding = { top = 0, side = 0, bottom = 8 },
        book_band_color = false,
        home_band_color = false,
        folder_band_color = false,
        quick_settings_band_color = false,
        header_rule_color = "outline",
        header_rule_width = 2,
        header_padding = { top = 18, side = 20, bottom = 16 },
        book_header_padding = { top = 18, side = 20, bottom = 16 },
        cover_gap = 16,
        cover_w = 64,
        cover_h = 96,
        line_gap = 6,
        meta_gap = 4,
        aside_gap = 12,
        row_padding = { x = 20, y = 12 },
        row_gap = 14,
        icon_size = 22,
        row_rule_color = "hairline_light",
        row_rule_width = 2,
        last_row_bottom = 12, -- the space under the last row's content, in place of row_padding.y
        status_chip_color = false,
        state_chip_color = false,
        chip_padding = { x = 8, y = 4 },
        chip_outline_width = 2,
        selected_fill_color = false, -- the sort and status sheets' current choice
        aside_above_gap = 2,
        sublabel_gap = 2,
        -- The library's folder sheet: its band and its folder icon's box.
        library_folder_band_color = false,
        folder_box = {
            size = 60,
            outline_width = 2,
            outline_color = "outline",
            fill_color = "paper",
            icon_size = 34,
            icon_color = "ink",
        },
        -- The library's empty-space sheet: its band and chips.
        library_empty_band_color = false,
        sort_chip_color = "paper",
        show_chip_color = false,
        radius = 0, -- 0 paints the box and its band square through paintRect
    },

    -- The quick-settings sheet's body: ruled sections of a label over a minus button, a level bar
    -- and a plus button, then a grid of tiles.
    quick_settings = {
        padding_x = 20,
        first_section_padding = { top = 15, bottom = 15 },
        section_padding = { top = 15, bottom = 15 },
        section_gap = 10,
        section_rule_width = 2,
        section_rule_color = "hairline_light",
        control_gap = 12,
        button_w = 44,
        button_h = 36,
        button_outline_width = 2,
        button_outline_color = "outline",
        button_fill_color = "paper",
        level_h = 14,
        level_outline_width = 2,
        level_outline_color = "outline",
        level_fill_color = "ink",
        level_track_color = "paper",
        grid_gap = 10,
        grid_padding = { top = 15, bottom = 20 },
        cell_padding = { top = 14, bottom = 12 },
        cell_gap = 8,
        cell_icon_size = 24,
        cell_outline_width = 2,
        cell_outline_color = "outline",
        cell_fill_color = "paper",
        on_fill_color = "ink",
        on_text_color = "ink",
    },

    -- A chip: its case, text, fill, outline and corners.
    chip = {
        small_caps = false,
        uppercase = true,
        text_color = "ink",
        fill_color = false,
        outline_color = "outline",
        radius = 0, -- 0 is square
    },

    -- The look's label: its size, face, case and tracking.
    label = {
        size = 11,
        face = "strong",
        small_caps = false,
        uppercase = true,
        tracking = 0.1,
    },

    -- The home's page: its margins, the gaps between rows and between columns, where the free
    -- height goes, the header drawn with row 1 and the footer, and the shapes the home widgets
    -- take.
    home = {
        margin = { top = 33, side = 40, bottom = 20 }, -- bottom: below the last row, above the nav bar
        row_gap = 21,
        column_gap = 16,
        free_space = "before_last_row", -- where the free height goes, or before_footer
        header = {
            band_color = false,
            edge_width = 0,
            edge_color = false,
            rule_color = false,
            rule_width = 0,
            rule_space = 0,
            padding = { top = 0, side = 0, bottom = 0 },
            align = "bottom",
        },
        footer = {
            height = 0, -- 0: no footer
            stripe_color = false,
            gap_color = false,
            line_width = 0,
            line_pitch = 0,
            edge_width = 0,
            edge_color = false,
        },
        weather_icon = { size = 0, gap = 0 }, -- size 0: no icon
        -- The home widgets' shapes: "61° Partly cloudy" (degrees_first) or condition_first; the
        -- weekday over the date (2) or one line (1); the stats on one line (joined) or spread;
        -- "3-day streak" (count_first) or word_first; "Now reading" or continue_reading; the
        -- featured authors and chapter, and its caption's parts, joined on one line each or split.
        weather_order = "degrees_first",
        date_lines = 2,
        stats_line = "joined",
        stats_streak = "count_first",
        featured_label = "now_reading",
        featured_details = "joined",
    },

    -- The text, per part: a face role, a size in board pixels (before text_size), case, tracking in
    -- em, line height as KOReader's TextBoxWidget counts it (extra space in em,
    -- frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role.
    type = {
        -- The weekday's label, unused while the date is one line (home.date_lines).
        date_label = { face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted" },
        date = { face = "strong", size = 18, uppercase = false, tracking = 0, line_height = 0.1, color = "ink" },
        clock = { face = "display", size = 36, uppercase = false, tracking = -0.02, line_height = -0.2, color = "ink" },
        weather = { face = "text", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text" },
        quote = { face = "quote", size = 18, uppercase = false, tracking = 0, line_height = 0.35, color = "ink" },
        stats = { face = "strong", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "text" },
        cover_title = {
            face = "display", size = 24, uppercase = true, tracking = 0.04, line_height = 0.05, color = "on_cover",
        },
        cover_authors = {
            face = "strong", size = 10, uppercase = true, tracking = 0.12, line_height = 0, color = "on_cover",
        },
        cover_empty = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        featured_label = {
            face = "text", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        featured_title = {
            face = "display", size = 28, uppercase = false, tracking = 0, line_height = 0.04, color = "ink",
        },
        featured_authors = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- Not drawn on its own: the chapter joins the authors line, in its style.
        featured_chapter = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        featured_caption = {
            face = "strong", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        featured_empty_title = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0.04, color = "ink",
        },
        featured_empty_body = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0.4, color = "text",
        },
        featured_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        launcher_label = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        launcher_suffix = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        sheet_heading = {
            face = "display", size = 26, uppercase = false, tracking = 0, line_height = 0.05, color = "on_accent",
        },
        sheet_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        sheet_title = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0.05, color = "on_accent",
        },
        sheet_author = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- "62% · Part 3 · opened yesterday".
        sheet_meta = {
            face = "strong", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        sheet_row = { face = "text", size = 17, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        sheet_detail = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        sheet_chip = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "on_accent",
        },
        sheet_chip_plain = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        sheet_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        sheet_sublabel = {
            face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted",
        },
        quick_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        quick_button = {
            face = "strong", size = 18, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        quick_cell = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        editor_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "muted",
        },
        editor_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        editor_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0.3, color = "ink",
        },
        editor_caption = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0.3, color = "muted",
        },
        editor_box = {
            face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        editor_share = {
            face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        editor_label = {
            face = "strong", size = 16, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        editor_kind = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "muted",
        },
        editor_note = {
            face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        nav_label = { face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted" },
        nav_label_active = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        title_bar_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted",
        },
        title_bar_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = -0.05, color = "ink",
        },
        title_bar_sort = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        title_bar_status = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        library_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted",
        },
        library_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = -0.05, color = "ink",
        },
        library_picker = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- As library_picker in its own colour: the header's height measures library_picker alone.
        library_picker_status = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        tile_title = { face = "strong", size = 12, uppercase = false, tracking = 0, line_height = 0.2, color = "ink" },
        -- The placeholder cover's title.
        tile_cover_title = {
            face = "display", size = 20, uppercase = false, tracking = 0, line_height = 0.1, color = "on_cover",
        },
        -- A folder's book count.
        folder_count = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- A folder's reading count.
        folder_reading = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        pager_label = { face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink" },
        shelf_detail_title = {
            face = "display", size = 36, uppercase = false, tracking = 0, line_height = -0.05, color = "ink",
        },
        shelf_back = { face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink" },
        series_name = {
            face = "display", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        series_sub = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        shelf_chip = {
            face = "strong", size = 10, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        shelf_chip_plain = {
            face = "strong", size = 10, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        book_index = { face = "display", size = 40, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        book_row_title = {
            face = "display", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        book_next_note = {
            face = "strong", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "on_accent",
        },
        book_row_note = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        author_letter = {
            face = "display", size = 28, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        author_name = { face = "strong", size = 17, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        author_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        shelf_empty = {
            face = "strong", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        shelf_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
    },

    -- The launcher: a grid of tiles or text rows, its gaps, icons, accents, suffix and badges.
    launcher = {
        columns = 3,
        column_gap = 16,
        row_gap = 0,
        icon_size = 22,
        icon_gap = false, -- false: the icon above the label, not beside it
        padding = { x = 0, y = 11 },
        tile_height = 84,
        accent_1_color = false, -- false: every tile alike
        accent_2_color = false,
        accent_3_color = false,
        suffix_gap = 6,
        suffix_below = false, -- false: the suffix on the label's line
        -- A badge behind the tile's icon; size 0 draws none, the icon bare.
        badge = {
            size = 0,
            outline_width = 0,
            outline_color = false,
            fill_1_color = false,
            fill_2_color = false,
            fill_3_color = false,
            fill_4_color = false,
            fill_5_color = false,
            fill_6_color = false,
        },
    },

    -- The quote: in the tile (no rule colour) with the tile's outline and shadow, or between rules
    -- rule_width wide; padding between the chrome and the text.
    quote = {
        padding = 18,
        rule_width = 0,
        rule_color = false,
    },

    -- The featured book's cover box, its text column, chip and first-run button.
    featured = {
        cover_w = 150,
        cover_h = 225,
        cover_padding = { x = 10, y = 10 },
        cover_outline_color = "outline",
        -- The first run's dashed frame.
        dash = 4,
        dash_gap = 4,
        gap = 24,
        column_padding_y = 2,
        title_gap = 12,
        chip_outline = 2,
        chip_padding = { x = 11, y = 4 },
        button_padding = { x = 14, y = 9 },
        button_fill_color = false, -- unfilled
        button_outline_color = "outline",
    },

    -- The editor screens, edit layout and launcher management: a header over a rule, then cards or rows.
    editor = {
        padding = { top = 40, side = 40, bottom = 28 },
        header_band_color = false,
        header_text_color = false,
        header_rule_color = "outline",
        header_rule_width = 3,
        header_gap = 16,
        body_gap = 18,
        button_outline_color = "outline",
        button_outline_width = 2,
        button_fill_color = "paper",
        button_padding = { x = 14, y = 8 },
        card_gap = 10,
        card_padding = { x = 14, y = 12 },
        card_outline_color = "outline",
        card_outline_width = 3,
        card_shadow = { x = 0, y = 0, color = false },
        selected_outline_color = "outline",
        selected_fill_color = "hairline_light",
        arrow_size = 28,
        arrow_gap = 14,
        disabled_color = "muted",
        box_padding = { x = 12, y = 10 },
        box_gap = 8,
        row_padding = { y = 14 },
        row_rule_color = "hairline_light",
        row_rule_width = 2,
        icon_size = 22,
        icon_gap = 14,
        control_size = 30,
        kind_gap = 8,
        kind_columns = 2,
    },

    -- The nav bar: five tabs of an icon over a label, a bar across the screen's bottom or a
    -- floating pill.
    nav = {
        fill_color = "paper",
        edge_width = 3,
        edge_color = "ink",
        padding_x = 0,
        padding_top = 17,
        padding_bottom = 17,
        icon_size = 24,
        icon_gap = 7,
        icon_color = "muted",
        active_icon_color = "ink",
        active_rule_width = 0,
        active_rule_color = false,
        active_fill_color = false,
        divider_width = 0,
        divider_color = false,
        -- false: a bar across the screen's bottom; true: a floating pill, with the margin, radius,
        -- fill, shadow, tab gap and lit tab outline below.
        float = false,
        margin = { side = 0, bottom = 0 },
        radius = 0,
        float_fill_color = false,
        shadow = { x = 0, y = 0, color = false },
        tab_gap = 0,
        active_outline_width = 0,
        active_outline_color = false,
    },

    -- The file browser's title bar: a count over a title, and the sort and status pickers.
    title_bar = {
        fill_color = "paper",
        padding = { top = 36, side = 40, bottom = 16 },
        edge_width = 0,
        edge_color = false,
        line_gap = 4,
        picker_gap = 8,
        sort_fill_color = "paper",
        status_fill_color = "paper",
        picker_outline_width = 2,
        picker_outline_color = "outline",
        picker_padding = { x = 10, y = 7 },
        icon_size = 16,
        icon_color = "ink",
        count_on_shelf = false,
        picker_radius = 0, -- 0 is square
    },

    -- The library: its header, the grid of covers and folders with a strip under each, badges and
    -- the pager above the nav bar.
    library = {
        header = {
            fill_color = false,
            padding = { top = 36, side = 40, bottom = 16 },
            edge_width = 0,
            edge_color = false,
            line_gap = 4,
            picker_gap = 8,
            picker_padding = { x = 10, y = 7 },
            picker_outline_width = 2,
            picker_outline_color = "outline",
            sort_fill_color = "paper",
            status_fill_color = "paper",
            picker_radius = 0, -- 0 is square
        },
        grid = {
            padding_top = 28,
            side = 40,
            row_gap = 22,
            column_gap = 20,
            cover_h = 195,
            strip_gap = 12,
            title_gap = 8,
        },
        cover = {
            outline_width = 3,
            outline_color = "outline",
            radius = 0,
            shadow = { x = 0, y = 6, color = "shadow", outline_width = false },
            padding = { x = 10, y = 10 },
        },
        strip = {
            height = 8,
            outline_width = 2,
        },
        -- The folder's block; its radius and edge are the covers' (library.cover).
        folder = {
            fill_color = "paper",
            outline_width = 3,
            outline_color = "outline",
            icon_size = 28,
            icon_color = "ink",
            padding = { x = 14, y = 14 },
            count_gap = 4,
        },
        badge = {
            size = 34,
            outline_width = 2,
            outline_color = "outline",
            fill_color = "paper",
            icon_size = 20,
            icon_color = "ink",
            inset = -10, -- below 0 overhangs the cover's corner
            align = "top",
        },
        not_downloaded = {
            outline_color = "outline",
            padding = { x = 4, y = 4 },
        },
        pager = {
            button_w = 44,
            button_h = 32,
            gap = 18,
            bottom = 16,
            outline_width = 2,
            outline_color = "outline",
            prev_fill_color = "paper",
            next_fill_color = false, -- transparent
            dead_color = false, -- false leaves a dead arrow out
            prev_icon_color = "ink",
            next_icon_color = "ink",
            label_in_words = true, -- "Page 1 of 24"
        },
    },

    -- The series and authors screens: the library's header, rows and groups, chips and the up-next
    -- book.
    shelf = {
        series_fill_color = false,
        authors_fill_color = false,
        detail = {
            padding = { top = 26, side = 40, bottom = 16 },
            back_gap = 10,
        },
        back = {
            fill_color = "paper",
            outline_width = 2,
            padding = { left = 6, right = 10, y = 4 },
            icon_size = 14,
            gap = 6,
        },
        list = {
            padding_top = 28,
            side = 40,
            row_gap = 16,
            pager_gap = 14,
        },
        row = {
            padding = { x = 16, y = 9 },
            gap = 18,
            line_gap = 3,
            outline_width = 3,
            shadow = { x = 0, y = 0 },
            rule_width = 0,
            rule_color = "outline", -- unused at rule_width 0
        },
        stack = {
            cover_w = 38,
            cover_h = 56,
            offset_x = 10,
            offset_y = 2,
            outline_width = 2,
            outline_color = "outline",
        },
        chip = {
            padding = { x = 8, y = 2 },
            outline_width = 2,
            under_way_fill_color = false,
            finished_fill_color = false,
            not_started_fill_color = "paper",
            up_next_fill_color = false,
        },
        books = {
            padding_top = 24,
            row_gap = 18,
        },
        book = {
            padding = { x = 16, y = 14 },
            index_w = 40,
            cover_w = 64,
            cover_h = 96,
            cover_outline_width = 0,
            line_gap = 6,
            bar_height = 8,
            bar_outline_width = 2,
            badge_size = 28,
            badge_outline_width = 2,
            badge_icon_size = 14,
            badge_inset = -10,
        },
        next = {
            fill_color = false,
            shadow = { x = 0, y = 0 },
            line_gap = 4,
            text_color = "on_accent",
        },
        groups = {
            padding_top = 28,
            gap = 12,
        },
        group = {
            outline_width = 3,
            shadow = { x = 0, y = 0 },
            rule_width = 0,
            rule_color = "outline", -- unused at rule_width 0
            letter_w = 48,
            letter_fill_color = false,
            letter_rule_width = 2,
        },
        author = {
            padding = { x = 16, y = 11 },
            rule_width = 2,
            rule_color = "hairline_light",
        },
        author_grid = {
            cover_h = 174,
        },
        up_next = {
            fill_color = "paper",
            outline_width = 2,
        },
    },
}
