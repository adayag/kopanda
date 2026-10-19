-- Frosted Plates: the owner's wallpaper behind the home, every row on a plate washed toward paper with a 2 px ink
-- keyline, violet and yellow accents. Declares only what differs from the base look (looks/base.lua).
return {
    -- Atkinson Hyperlegible 700 for display, 400 and 700 and italic for text, no accent face.
    faces = {
        display = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Bold.ttf",
            label = "Atkinson Hyperlegible 700" },
        text = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Regular.ttf",
            label = "Atkinson Hyperlegible 400" },
        strong = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Bold.ttf",
            label = "Atkinson Hyperlegible 700" },
        quote = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Italic.ttf",
            label = "Atkinson Hyperlegible 400 italic" },
    },

    icons = { set = "phosphor-bold" },

    -- Structure is the ink, so outline, shadow and on_accent are the ink.
    palettes = {
        day = {
            paper = "#fbfaf6",
            ink = "#1b1a1f",
            muted = "#4d4b55",
            text = "#1b1a1f",
            hairline_light = "#d9d6df",
            violet = "#6b55c8",
            yellow = "#f2c230",
            outline = "#1b1a1f",
            shadow = "#1b1a1f",
            on_accent = "#1b1a1f",
            -- A solid violet block, paper text on it.
            cover = "#6b55c8",
            on_cover = "#fbfaf6",
        },
        night = {
            paper = "#1d1c22",
            ink = "#f3f1ec",
            muted = "#b5b2bd",
            text = "#f3f1ec",
            hairline_light = "#3a3842",
            violet = "#a593f2",
            yellow = "#8a6d10",
            outline = "#f3f1ec",
            shadow = "#f3f1ec",
            on_accent = "#f3f1ec",
            cover = "#6b55c8",
            on_cover = "#fbfaf6",
        },
        grey = {
            hairline_light = "#bbbbbb",
            -- An unhatched violet fill takes the cover's grey, so violet stays apart from the ink that
            -- progress.fill_grey hatches in.
            violet = "#4a4a4a",
            yellow = "#cccccc",
            shadow = "#000000",
        },
    },

    -- The nav edge and the sheet's outline have their own tokens (nav.edge_width, sheet.outline_width).
    stroke = { outline = 2 },

    shadow = {
        cover = { x = 0, y = 0, color = false },
        sheet = { x = 5, y = 7 },
    },

    -- The plates every home row sits on: a 2 px ink keyline at radius 12 over the wallpaper lightened toward paper, by
    -- day 0.82, at night 0.84 and in grey 0.85; with no wallpaper, filled paper. Row 1 is one header plate padded by
    -- home.header.padding; every other row's widgets each sit on their own plate, padded and rounded by slots. The
    -- launcher's tiles are plates themselves.
    plate = {
        fill_color = "paper",
        keyline = 2,
        keyline_color = "ink",
        radius = 12,
        -- lightenRect blends toward white, and at night the stored pixels toward black (plate.lua), not toward the
        -- paper, so night plates show about 24 levels darker than the night paper.
        lighten = {
            day = 0.82,
            night = 0.84,
            grey = 0.85,
        },
        slots = {
            -- The header plate's padding.
            date = { x = 18, y = 14, radius = 12 },
            clock = { x = 18, y = 14, radius = 12 },
            -- The stats' pill.
            weather = { x = 14, y = 8, radius = 999 },
            stats = { x = 14, y = 8, radius = 999 },
            quote = { x = 18, y = 12, radius = 12 },
            featured = { x = 14, y = 14, radius = 12 },
        },
    },

    wallpaper = { enabled = true },

    progress = {
        height = 12,
        fill_color = "violet",
        radius = 999,
    },

    sheet = {
        outline_width = 2,
        header_band = false,
        row_rule_width = 1,
        status_chip_color = "yellow",
        state_chip_color = "yellow",
        chip_padding = { x = 11 },
        selected_fill_color = "yellow",
        show_chip_color = "yellow",
        radius = 16,
    },

    -- The quick-settings body: the sheet's rows and light rules, its progress bar for the levels, the plates' 2 px ink
    -- keyline for the buttons and tiles, and the on tile filled yellow with ink text as the lit nav tab.
    quick_settings = {
        section_rule_width = 1,
        level_h = 12,
        level_fill_color = "violet",
        on_fill_color = "yellow",
    },

    chip = {
        fill_color = "yellow",
        radius = 999,
    },

    label = { tracking = 0.08 },

    home = {
        margin = { top = 26, side = 24, bottom = 14 },
        row_gap = 12,
        column_gap = 12,
        header = { padding = { top = 14, side = 18, bottom = 14 } },
    },

    type = {
        date_label = { tracking = 0.08 },
        clock = { size = 84, tracking = -0.03 },
        cover_authors = { tracking = 0.08 },
        cover_empty = { tracking = 0.08 },
        featured_label = { face = "strong", tracking = 0.08 },
        featured_title = { size = 32, tracking = -0.015 },
        -- The title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = { size = 27, tracking = -0.015 },
        -- The look's label in ink, as the chip's.
        featured_button = { tracking = 0.08 },
        launcher_suffix = { tracking = 0.08 },
        -- The book sheet's title in ink.
        sheet_heading = { size = 23, tracking = -0.015, color = "ink" },
        -- The look's label.
        sheet_aside = { tracking = 0.08 },
        sheet_title = { size = 23, tracking = -0.015, color = "ink" },
        sheet_author = { color = "text" },
        sheet_meta = { color = "text" },
        sheet_row = { size = 18 },
        sheet_detail = { tracking = 0.08 },
        sheet_chip = { tracking = 0.08 },
        sheet_chip_plain = { tracking = 0.08 },
        sheet_label = { tracking = 0.08 },
        quick_label = { tracking = 0.08 },
        -- The look's label in ink.
        quick_cell = { tracking = 0.08 },
        -- The editor screens: the header on paper over an ink rule, its title in the display face, the rest in the
        -- look's label, at Editorial's sizes and line height 0.3.
        editor_aside = { tracking = 0.08 },
        -- Editorial's size and line height in the display face.
        editor_title = { tracking = -0.015 },
        -- The look's label in ink.
        editor_button = { tracking = 0.08 },
        editor_caption = { tracking = 0.08 },
        editor_kind = { tracking = 0.08 },
        nav_label = { tracking = 0.08 },
        nav_label_active = { tracking = 0.08 },
        -- The file browser's title bar takes the library's parts.
        title_bar_count = { tracking = 0.08 },
        title_bar_title = { size = 32, tracking = -0.015 },
        title_bar_sort = { tracking = 0.08 },
        title_bar_status = { tracking = 0.08 },
        library_count = { tracking = 0.08 },
        library_title = { size = 32, tracking = -0.015 },
        library_picker = { tracking = 0.08 },
        library_picker_status = { tracking = 0.08 },
        -- The series and authors screens take the library's header and the home's plates, by analogy; the detail
        -- title is the featured title's size.
        shelf_detail_title = { size = 32, tracking = -0.015 },
        -- As the library folder's name.
        series_name = { face = "strong" },
        -- As the library folder's name.
        book_row_title = { face = "strong" },
        -- "read this one next" in the look's label on the yellow row; Frosted has no accent face.
        book_next_note = { tracking = 0.08 },
        -- The look's label.
        author_count = { tracking = 0.08 },
        shelf_label = { tracking = 0.08 },
    },

    launcher = {
        column_gap = 12,
        row_gap = 12,
        icon_size = 24,
        padding = { x = 13 },
        tile_height = 74,
        suffix_gap = 8,
    },

    -- The quote plain on its plate, no rules; the plate's padding is plate.slots.quote.
    quote = { padding = 0 },

    featured = {
        cover_w = 122,
        cover_h = 183,
        gap = 20,
        button_fill_color = "yellow",
    },

    editor = {
        card_outline_width = 2,
        selected_fill_color = "yellow",
        row_rule_width = 1,
    },

    -- The nav bar is opaque on purpose: a 3 px ink edge over paper, the lit tab filled yellow.
    nav = { active_fill_color = "yellow" },

    title_bar = {
        padding = { top = 26, side = 24 },
        picker_radius = 999,
    },

    library = {
        header = {
            padding = { top = 26, side = 24 },
            picker_radius = 999,
        },
        grid = {
            side = 24,
            strip_gap = 8,
        },
        cover = {
            outline_width = 2,
            shadow = { y = 0, color = false },
        },
        folder = { outline_width = 2 },
        badge = { fill_color = "yellow" },
        not_downloaded = { padding = { x = 10, y = 5 } },
        pager = { next_fill_color = "yellow" },
    },

    shelf = {
        detail = { padding = { side = 24 } },
        list = {
            side = 24,
            row_gap = 12,
        },
        row = { outline_width = 2 },
        chip = {
            under_way_fill_color = "yellow",
            finished_fill_color = "yellow",
            up_next_fill_color = "yellow",
        },
        book = { cover_outline_width = 2 },
        next = { fill_color = "yellow" },
        group = {
            outline_width = 2,
            letter_fill_color = "yellow",
        },
        author = { rule_width = 1 },
        up_next = { fill_color = "yellow" },
    },
}
