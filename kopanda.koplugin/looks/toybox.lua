-- Toybox: chunky toy blocks, rounded paper blocks standing on a solid ink edge, the colour kept to round badges,
-- and a floating pill nav. Declares only what differs from the base look (looks/base.lua).
return {
    -- Baloo 2 800, Nunito 700 and 800, Nunito 600 italic for the quote, no accent face.
    faces = {
        display = { file = "fonts/baloo-2/Baloo2-ExtraBold.ttf", label = "Baloo 2 800" },
        text = { file = "fonts/nunito/Nunito-Bold.ttf", label = "Nunito 700" },
        strong = { file = "fonts/nunito/Nunito-ExtraBold.ttf", label = "Nunito 800" },
        quote = { file = "fonts/nunito/Nunito-SemiBoldItalic.ttf", label = "Nunito 600 italic" },
    },

    icons = { set = "mingcute-line" },

    -- Structure and the block edge are the ink, so outline, shadow, on_band and on_accent are the ink, and the band
    -- is the mint (the sheet's header band). The card is its paper by day and in grey; the night card (#24232e) has
    -- no part here that draws it.
    palettes = {
        day = {
            paper = "#fbf5ec",
            ink = "#2b2934",
            muted = "#5b5867",
            text = "#2b2934",
            hairline_light = "#e7ddcd",
            sun = "#ffc94a",
            coral = "#ff8f75",
            mint = "#86d3b4",
            die = "#ffffff",
            band = "#86d3b4",
            outline = "#2b2934",
            shadow = "#2b2934",
            on_band = "#2b2934",
            on_accent = "#2b2934",
            -- A solid block of the ink, paper text on it.
            cover = "#2b2934",
            on_cover = "#fbf5ec",
        },
        night = {
            paper = "#1e1d26",
            ink = "#f4f0ea",
            muted = "#b4b1c0",
            text = "#f4f0ea",
            hairline_light = "#383645",
            sun = "#8a6a12",
            coral = "#a2493a",
            mint = "#2f7a5c",
            die = "#282733",
            band = "#2f7a5c",
            outline = "#f4f0ea",
            shadow = "#f4f0ea",
            on_band = "#f4f0ea",
            on_accent = "#f4f0ea",
            cover = "#2b2934",
            on_cover = "#fbf5ec",
        },
        grey = {
            hairline_light = "#cccccc",
            sun = "#dddddd",
            coral = "#999999",
            mint = "#bbbbbb",
            band = "#bbbbbb",
            shadow = "#000000",
            on_band = "#000000",
        },
    },

    stroke = {
        hairline = 2,
        rule = 3,
    },

    -- A solid block edge: ink 0 right 6 down under the tiles and the cover, 8 under the sheet.
    shadow = {
        cover = { x = 0 },
        tile = { y = 6, color = "shadow" },
    },

    radius = {
        cover = 6,
        box = 18,
    },

    progress = {
        -- The 18 px pill less its 3 px outline above and below (the bar is border-box).
        height = 12,
        fill_color = "coral",
        outline_width = 3,
        radius = 999,
    },

    sheet = {
        -- 10 ends a lit last row's fill 13 px above the box's foot, inside the 24 px corners' outer curve (12.4 at
        -- the 3 px outline), so no sun shows in their ring.
        padding = { bottom = 10 },
        book_band_color = "mint",
        home_band_color = "mint",
        folder_band_color = "mint",
        quick_settings_band_color = "mint",
        status_chip_color = "mint",
        state_chip_color = "mint",
        chip_padding = { x = 11 },
        selected_fill_color = "sun",
        library_folder_band_color = "mint",
        folder_box = { outline_width = 3 },
        library_empty_band_color = "mint",
        sort_chip_color = "mint",
        show_chip_color = "mint",
        radius = 24,
    },

    -- The quick-settings body: the sheet's rows and hairline rules, its progress pill for the levels, the pickers' 2
    -- px ink outline for the buttons, the block's 3 px ink outline for the tiles, and the on tile filled sun with ink
    -- text as the lit nav tab.
    quick_settings = {
        level_h = 12,
        level_outline_width = 3,
        level_fill_color = "coral",
        cell_outline_width = 3,
        on_fill_color = "sun",
    },

    chip = {
        fill_color = "mint",
        radius = 999,
    },

    home = {
        -- The bottom margin is 98 px less the floating nav's 68 and the 20 under it, so the rows stop 10 above the
        -- pill.
        margin = { top = 36, bottom = 10 },
        row_gap = 18,
        date_lines = 1,
    },

    -- The 700 weight is the text face, the 800 the strong face; 500 and 600 are the text face too, the lightest Nunito
    -- vendored.
    type = {
        clock = { size = 100 },
        stats = { tracking = 0.1 },
        cover_authors = { tracking = 0.1 },
        featured_title = { size = 36, tracking = -0.01 },
        featured_caption = { face = "text" },
        -- The title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = { size = 31, tracking = -0.01 },
        -- The look's label in ink, as the chip's.
        featured_button = { tracking = 0.1 },
        launcher_label = { face = "text" },
        sheet_title = { size = 26 },
        sheet_meta = { face = "text" },
        sheet_row = { size = 18 },
        quick_label = { tracking = 0.1 },
        -- The look's label in ink.
        editor_button = { tracking = 0.1 },
        editor_caption = { tracking = 0.1 },
        -- Diner's and Editorial's.
        editor_box = { face = "text" },
        -- Diner's and Editorial's.
        editor_share = { face = "text" },
        -- Diner's and Editorial's, so six rows fit above the add-an-entry foot.
        editor_label = { face = "text" },
        nav_label = { tracking = 0.1 },
        nav_label_active = { tracking = 0.1 },
        -- The file browser's title bar takes the library's parts.
        title_bar_count = { tracking = 0.1 },
        title_bar_title = { size = 36, tracking = -0.01 },
        title_bar_sort = { face = "text", tracking = 0.1 },
        title_bar_status = { face = "text", tracking = 0.1 },
        library_count = { tracking = 0.1 },
        library_title = { size = 36, tracking = -0.01 },
        library_picker = { face = "text", tracking = 0.1 },
        library_picker_status = { face = "text", tracking = 0.1 },
        -- The text face at Diner's size and line height.
        tile_title = { face = "text" },
        folder_count = { face = "text" },
        folder_reading = { tracking = 0.1 },
        pager_label = { tracking = 0.1 },
        -- The series and authors screens take the library's header and the home's blocks, by analogy; the detail
        -- title is the featured title's size.
        shelf_detail_title = { tracking = -0.01 },
        -- A picker's label in ink.
        shelf_back = { face = "text", tracking = 0.1 },
        -- As the library folder's name.
        series_name = { face = "text" },
        -- A chip's label, ink on its mint.
        shelf_chip = { tracking = 0.1 },
        shelf_chip_plain = { tracking = 0.1 },
        -- As the library folder's name.
        book_row_title = { face = "text" },
        -- "read this one next" in the look's label on the sun row; Toybox has no accent face.
        book_next_note = { tracking = 0.1 },
        -- Diner's.
        author_name = { face = "text" },
        -- The look's label.
        author_count = { tracking = 0.1 },
        shelf_empty = { tracking = 0.1 },
        shelf_label = { tracking = 0.1 },
    },

    -- The badge would stack over the label, but at KOReader's line heights the two overrun an 84 px block, so the label
    -- sits beside the badge.
    launcher = {
        row_gap = 16,
        icon_gap = 10,
        padding = { x = 11, y = 9 },
        -- Under the label: "Terminal PLUGIN MISSING" doesn't fit beside a badge on one line.
        suffix_below = true,
        badge = {
            size = 42,
            outline_width = 2.5,
            outline_color = "outline",
            fill_1_color = "sun",
            fill_2_color = "coral",
            fill_3_color = "mint",
            fill_4_color = "coral",
            fill_5_color = "mint",
            fill_6_color = "sun",
        },
    },

    quote = {
        padding = 0,
        -- A rule colour sets the quote between rules, of no width here, rather than in a tile.
        rule_color = "hairline_light",
    },

    featured = {
        cover_w = 140,
        cover_h = 210,
        button_fill_color = "sun",
    },

    editor = {
        card_gap = 12,
        card_shadow = { y = 6, color = "shadow" },
        selected_fill_color = "sun",
    },

    nav = {
        padding_x = 5,
        -- The pill's 68 px less its outline and padding, a lit tab's 2 px outline, the icon, the gap and the label
        -- line, shared above and below the tab's centred content.
        padding_top = 9,
        padding_bottom = 9, -- as padding_top
        icon_gap = 4,
        active_fill_color = "sun",
        float = true,
        margin = { side = 22, bottom = 20 },
        radius = 999,
        float_fill_color = "die",
        shadow = { y = 6, color = "shadow" },
        tab_gap = 4,
        active_outline_width = 2,
        active_outline_color = "outline",
    },

    title_bar = {
        picker_padding = { x = 12 },
        picker_radius = 999,
    },

    library = {
        header = {
            picker_padding = { x = 12 },
            picker_radius = 999,
        },
        grid = { strip_gap = 14 },
        -- At Diner's 195 a cover is fitted in its box on paper, so the box takes the cover's 3 px ink outline and its
        -- ink edge.
        cover = { radius = 6 },
        badge = { fill_color = "sun" },
        not_downloaded = { padding = { x = 11 } },
        pager = { next_fill_color = "sun" },
    },

    shelf = {
        detail = { padding = { top = 36 } },
        row = { shadow = { y = 6 } },
        chip = {
            under_way_fill_color = "mint",
            finished_fill_color = "mint",
            up_next_fill_color = "sun",
        },
        book = { cover_outline_width = 3 },
        next = {
            fill_color = "sun",
            shadow = { y = 6 },
        },
        groups = { gap = 16 },
        group = {
            shadow = { y = 6 },
            letter_fill_color = "mint",
        },
        up_next = { fill_color = "sun" },
    },
}
