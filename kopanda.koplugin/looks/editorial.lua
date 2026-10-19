-- Editorial: a serif display face, hairlines and soft shadows on warm paper. Declares only what differs from
-- the base look (looks/base.lua).
return {
    palettes = {
        day = {
            paper = "#f3f1ea",
            ink = "#1c1b19",
            muted = "#6b6861",
            text = "#4a4843",
            hairline = "#c9c5b8",
            hairline_light = "#e2dfd4",
            shadow = "#c9c5b8",
            cover = "#2b4c6f",
            on_cover = "#f3f1ea",
        },
        night = {
            paper = "#15161a",
            ink = "#e8e6df",
            muted = "#9b988f",
            text = "#c4c1b8",
            hairline = "#3a3b40",
            hairline_light = "#2a2b30",
            outline = "#3a3b40",
            cover = "#2b4c6f",
            on_cover = "#f3f1ea",
        },
        grey = {
            paper = "#f4f4f4",
            ink = "#111111",
            muted = "#555555",
            -- The nearest grey on the Paperwhite palette to #333333.
            text = "#444444",
            hairline = "#8c8c8c",
            hairline_light = "#d0d0d0",
            outline = "#8c8c8c", -- the Paperwhite cover gains an outline, Editorial's is a hairline
            shadow = "#8c8c8c", -- the shadow is the hairline colour
            on_accent = false, -- Editorial has no accent fills
            on_cover = "#f4f4f4",
        },
    },

    stroke = { outline = 1 }, -- Editorial's outlines are hairlines

    shadow = { cover = { x = 2, y = 3 }, sheet = { y = 0, color = false } },

    radius = { cover = 3 },

    tile = {
        box = false,
        fill_color = false,
        outline_color = false,
        rule_color = "hairline_light",
    },

    progress = { height = 4, track_color = "hairline", outline_color = false, outline_width = 0, fill_grey = false },

    sheet = {
        rule_color = "ink",
        rule_width = 2,
        outline_color = false,
        outline_width = 1, -- stroke.outline; unused, the sheet has no outline colour
        header_band = false,
        inset = { side = 0, bottom = 0 },
        padding = { side = 40, bottom = 28 },
        header_rule_color = "ink",
        header_rule_width = 1,
        header_padding = { top = 22, side = 0 },
        book_header_padding = { top = 24, side = 0, bottom = 20 },
        cover_gap = 18,
        cover_w = 60,
        cover_h = 90,
        line_gap = 3,
        row_padding = { x = 0, y = 15 },
        row_gap = 16,
        row_rule_color = "hairline",
        row_rule_width = 1,
        last_row_bottom = 0,
        chip_padding = { x = false, y = false },
        chip_outline_width = 0,
        folder_box = {
            outline_width = 1,
            outline_color = "hairline",
        },
        sort_chip_color = false,
    },

    -- The quick-settings body: two ruled sections of a label row over a minus button, a level bar and a plus button,
    -- then a three-column grid of outlined tiles, the on tile in ink.
    quick_settings = {
        padding_x = 0,
        first_section_padding = { top = 18, bottom = 16 },
        section_padding = { top = 16, bottom = 16 },
        section_rule_width = 1,
        section_rule_color = "hairline",
        button_outline_width = 1,
        button_outline_color = "ink",
        button_fill_color = false,
        level_h = 10,
        level_outline_width = 1,
        level_outline_color = "ink",
        level_track_color = false,
        grid_padding = { top = 18, bottom = 0 },
        cell_outline_width = 1,
        cell_outline_color = "ink",
        cell_fill_color = false,
        on_text_color = "paper",
    },

    chip = { small_caps = true, uppercase = false, text_color = "muted", outline_color = false },

    label = { face = "text", small_caps = true, uppercase = false, tracking = 0.14 },

    -- The top margin, row gap, the rule's space and the launcher's row padding are tightened, the least that fits the
    -- default rows above the nav bar at the small and medium text sizes on both devices.
    home = {
        -- The main rule under row 1, with rule_space above and below it and no row gap after.
        header = {
            rule_color = "ink",
            rule_width = 2, -- stroke.rule
            rule_space = 17,
        },
        weather_order = "condition_first",
        stats_line = "spread",
        stats_streak = "word_first",
        featured_label = "continue_reading",
        featured_details = "split",
    },

    type = {
        date_label = { face = "text", tracking = 0.14 },
        date = { face = "display", size = 36, line_height = 0 },
        clock = { tracking = 0, line_height = 0 },
        weather = { size = 11, uppercase = true, tracking = 0.14, color = "muted" },
        -- Ink stands in for the quote's colour, which no Editorial role holds.
        quote = { line_height = 0.4 },
        stats = { face = "text", color = "muted" },
        cover_authors = { face = "text", size = 11 },
        cover_empty = { face = "text", size = 12 },
        featured_label = { tracking = 0.14, color = "muted" },
        featured_title = { line_height = 0.1 },
        featured_authors = { size = 15 },
        featured_chapter = { size = 14 },
        featured_caption = { face = "text", size = 13 },
        featured_empty_title = { line_height = 0.15 },
        featured_empty_body = { size = 15 },
        launcher_label = { size = 16, line_height = 0 },
        sheet_heading = { line_height = 0, color = "ink" },
        sheet_aside = { face = "text", size = 12 },
        sheet_title = { line_height = 0.1, color = "ink" },
        sheet_author = { size = 14, color = "text" },
        sheet_meta = { face = "text", size = 12, uppercase = true, tracking = 0.1, color = "muted" },
        sheet_row = { face = "strong" },
        sheet_detail = { face = "text", size = 12 },
        -- Not drawn: Editorial has no chips. Its plain detail's style.
        sheet_chip = { face = "text", size = 12, color = "muted" },
        -- Not drawn: as sheet_chip.
        sheet_chip_plain = { face = "text", size = 12, color = "muted" },
        -- The aside's style.
        sheet_label = { face = "text", size = 12 },
        -- The detail's face in sentence case.
        sheet_sublabel = { size = 12 },
        quick_label = { face = "text" },
        quick_button = { face = "text" },
        -- Every editor part takes a line height of 0.3, so the default layout's five rows fit above the foot.
        editor_aside = { face = "text", tracking = 0.14 },
        editor_caption = { face = "text" },
        editor_kind = { face = "text" },
        nav_label = { color = "text" },
        title_bar_count = { face = "text" },
        title_bar_title = { line_height = 0 },
        title_bar_sort = { color = "text" },
        title_bar_status = { color = "text" },
        library_count = { face = "text" },
        library_title = { line_height = 0 },
        library_picker = { color = "text" },
        library_picker_status = { color = "text" },
        tile_title = { line_height = 0.25 },
        tile_cover_title = { size = 18 },
        folder_count = { face = "display", size = 22, line_height = 0.05 },
        folder_reading = { face = "text", tracking = 0.14 },
        pager_label = { face = "text", tracking = 0.14, color = "muted" },
        -- Series and authors parts: set by analogy with the library's.
        shelf_detail_title = { size = 34, line_height = 0 },
        shelf_back = { tracking = 0.14, color = "text" },
        series_name = { size = 20 },
        series_sub = { size = 12 },
        shelf_chip = { tracking = 0.14, color = "muted" },
        shelf_chip_plain = { tracking = 0.14 },
        book_index = { size = 30 },
        book_row_title = { size = 18 },
        -- "Read this one next" in small caps: Editorial has no accent face.
        book_next_note = { size = 10, color = "ink" },
        book_row_note = { size = 12 },
        author_letter = { size = 24, color = "ink" },
        author_name = { size = 15 },
        shelf_empty = { face = "text", size = 11, tracking = 0.14 },
        shelf_label = { color = "text" },
    },

    launcher = {
        columns = 2,
        column_gap = 32,
        icon_gap = 14,
        tile_height = false, -- Editorial's entries are rows, not tiles
    },

    quote = {
        rule_width = 1,
        rule_color = "hairline",
    },

    featured = {
        cover_padding = { x = 14, y = 18 },
        column_padding_y = 0,
        title_gap = 6,
        chip_outline = false,
        chip_padding = { x = false, y = false },
        button_outline_color = "ink",
    },

    -- Cards cast card_shadow, none here.
    editor = {
        header_rule_color = "ink",
        header_rule_width = 1,
        button_outline_color = "ink",
        button_outline_width = 1,
        button_fill_color = false,
        card_gap = 12,
        card_outline_color = "hairline",
        card_outline_width = 1,
        selected_outline_color = "ink",
        disabled_color = "hairline",
        row_rule_color = "hairline",
        row_rule_width = 1,
    },

    nav = {
        edge_width = 1,
        padding_x = 24,
        padding_top = 16,
        padding_bottom = 18,
        icon_size = 26,
        icon_color = "text",
        active_rule_width = 3,
        active_rule_color = "ink",
    },

    title_bar = {
        padding = { top = 40 },
        edge_width = 1,
        edge_color = "ink",
        line_gap = 2,
        picker_gap = 20,
        sort_fill_color = false,
        status_fill_color = false,
        picker_outline_width = 0,
        picker_outline_color = false,
        picker_padding = { x = 0, y = 0 },
        icon_color = "text",
    },

    library = {
        header = {
            padding = { top = 40 },
            edge_width = 2,
            edge_color = "ink",
            line_gap = 2,
            picker_gap = 20,
            picker_padding = { x = 0, y = 0 },
            picker_outline_width = 0,
            picker_outline_color = false,
            sort_fill_color = false,
            status_fill_color = false,
        },
        grid = {
            padding_top = 22,
            cover_h = 208,
            strip_gap = 10,
        },
        cover = {
            -- The hairline outline the look's cover takes at night and in grey, as FeaturedCover.build frames the
            -- featured cover; the role is false by day, so none is drawn.
            outline_width = 1,
            radius = 3,
            shadow = { x = 2, y = 3 },
            padding = { x = 12, y = 16 },
        },
        strip = {
            height = 4,
            outline_width = 0,
        },
        folder = {
            outline_width = 1,
            outline_color = "hairline",
            icon_size = 36,
            padding = { y = 16 },
        },
        badge = {
            size = 30,
            outline_width = 1,
            outline_color = "ink",
            icon_size = 16,
            inset = 8,
            align = "bottom",
        },
        -- Its padding and outline colour are the one-author grid's Up next chip on the cover.
        not_downloaded = {
            -- A paper chip on the cover: plain text would sit on the artwork.
            outline_color = false,
            -- x is tightened from 6 so a chip fits beside the badge.
            padding = { y = 2 },
        },
        pager = {
            gap = 22,
            outline_width = 0,
            outline_color = false,
            prev_fill_color = false,
            dead_color = "hairline",
            label_in_words = false,
        },
    },

    -- Rows and groups ruled in hairlines rather than boxed, unoutlined covers, plain small-caps chips, and the up-next
    -- book marked by type; set by analogy with the library's.
    shelf = {
        detail = { back_gap = 14 },
        back = {
            fill_color = false,
            outline_width = 0,
            padding = { left = 0, right = 0, y = 0 },
        },
        list = {
            padding_top = 22,
            row_gap = 0,
        },
        row = {
            padding = { x = 0, y = 14 },
            outline_width = 0,
            rule_width = 1,
            rule_color = "hairline",
        },
        stack = {
            outline_width = 1, -- an edge to part the overlapped covers
            outline_color = "paper",
        },
        chip = {
            padding = { x = 0, y = 0 },
            outline_width = 0,
            not_started_fill_color = false,
        },
        books = { row_gap = 0 },
        book = {
            padding = { x = 0 },
            bar_height = 4,
            bar_outline_width = 0,
            badge_size = 24,
            badge_outline_width = 1,
            badge_inset = 6,
        },
        next = { text_color = "ink" },
        groups = {
            padding_top = 22,
            gap = 0,
        },
        group = {
            outline_width = 0,
            rule_width = 1,
            rule_color = "hairline",
            letter_rule_width = 0,
        },
        author = { rule_width = 1 },
        author_grid = { cover_h = 198 },
        up_next = { outline_width = 0 },
    },
}
