-- Riso: a two-drum Risograph, blue ink and fluoro pink on cream, no black anywhere, the pink always a few pixels
-- out of register. Declares only what differs from the base look (looks/base.lua).
return {
    -- Big Shoulders Display 900, Work Sans 500 and 700, no accent face.
    faces = {
        display = { file = "fonts/big-shoulders-display/BigShouldersDisplay-Black.ttf",
            label = "Big Shoulders Display 900" },
        text = { file = "fonts/work-sans/WorkSans-Medium.ttf", label = "Work Sans 500" },
        strong = { file = "fonts/work-sans/WorkSans-Bold.ttf", label = "Work Sans 700" },
        -- The quote is Work Sans 500 italic; no Work Sans italic is vendored, so it is set upright.
        quote = { file = "fonts/work-sans/WorkSans-Medium.ttf", label = "Work Sans 500" },
    },

    icons = { set = "phosphor-fill" },

    -- Structure is the ink, so outline, on_band and on_accent are the ink, and the band is the tint (the sheet's
    -- header band).
    palettes = {
        day = {
            paper = "#f3eee2",
            ink = "#22509f",
            muted = "#3d5b9a",
            text = "#22509f",
            hairline_light = "#f2a9c4",
            pink = "#e9508a",
            tint = "#f6c6d8",
            band = "#f6c6d8",
            outline = "#22509f",
            on_band = "#22509f",
            on_accent = "#22509f",
            -- A solid block of the blue drum, paper text on it.
            cover = "#22509f",
            on_cover = "#f3eee2",
        },
        night = {
            paper = "#141a2e",
            ink = "#f1ece0",
            muted = "#b8bfd8",
            text = "#f1ece0",
            hairline_light = "#6e3557",
            pink = "#f0729f",
            tint = "#4a2643",
            band = "#4a2643",
            outline = "#f1ece0",
            on_band = "#f1ece0",
            on_accent = "#f1ece0",
            cover = "#22509f",
            on_cover = "#f3eee2",
        },
        grey = {
            hairline_light = "#bbbbbb",
            pink = "#999999",
            tint = "#dddddd",
            band = "#dddddd",
            on_band = "#000000",
        },
    },

    -- The nav edge and the sheet's outline have their own tokens (nav.edge_width, sheet.outline_width).
    stroke = {
        hairline = 2,
        outline = 2,
    },

    -- Misregistration, not shadow: tint 5/4 under tiles, pink 8/8 under the sheet, a 2 px ink outline 6/6 behind the
    -- cover.
    shadow = {
        cover = { color = "outline", outline_width = 2 },
        tile = { x = 5, y = 4, color = "tint" },
        sheet = { x = 8, color = "pink" },
    },

    -- Pink 3 right and 2 down under display type; in grey the pink's grey, a light ghost.
    misregister = { x = 3, y = 2, color = "pink" },

    tile = { fill_color = false },

    progress = { fill_color = "pink" },

    sheet = {
        inset = { side = 20, bottom = 20 },
        book_band_color = "tint",
        home_band_color = "tint",
        folder_band_color = "tint",
        quick_settings_band_color = "tint",
        status_chip_color = "tint",
        state_chip_color = "tint",
        chip_outline_width = 0,
        selected_fill_color = "tint",
        library_folder_band_color = "tint",
        library_empty_band_color = "tint",
        sort_chip_color = "tint",
        show_chip_color = "tint",
    },

    -- The quick-settings body: the sheet's rows and pink rules, its progress bar for the levels, the tiles' 2 px ink
    -- outline for the buttons and tiles, and the on tile filled tint with ink text as the lit nav tab.
    quick_settings = {
        button_fill_color = "tint",
        level_fill_color = "pink",
        on_fill_color = "tint",
    },

    chip = {
        fill_color = "tint",
        outline_color = false,
    },

    label = { tracking = 0.12 },

    -- The page's top and bottom margins, its row gap, the quote's padding and the launcher's row gap are tightened, the
    -- least that fits the default rows above the nav bar at the medium text size on both devices with the 124 px clock
    -- (a smaller clock alone doesn't: at 60 px the stats still don't fit).
    home = {
        margin = { top = 23, bottom = 9 },
        row_gap = 16,
    },

    -- Display type (the display face) is misregistered; the labels are the strong face.
    type = {
        date_label = { tracking = 0.12 },
        date = { size = 15 },
        clock = { size = 124, tracking = -0.01 },
        stats = { tracking = 0.12 },
        cover_empty = { tracking = 0.12 },
        featured_label = { face = "strong", tracking = 0.12 },
        featured_title = { size = 46 },
        -- The title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = { size = 39 },
        launcher_suffix = { tracking = 0.12 },
        -- The book sheet's title on the band.
        sheet_heading = { size = 33 },
        sheet_aside = { tracking = 0.12 },
        sheet_title = { size = 33 },
        sheet_row = { size = 19 },
        sheet_detail = { tracking = 0.12 },
        sheet_chip = { tracking = 0.12 },
        sheet_chip_plain = { tracking = 0.12 },
        sheet_label = { tracking = 0.12 },
        -- The look's label in ink.
        quick_cell = { tracking = 0.12 },
        -- The editor screens: the header on paper over an ink rule, its title in the display face, the rest in the
        -- look's label, at Editorial's sizes and line height 0.3.
        editor_aside = { tracking = 0.12 },
        editor_kind = { tracking = 0.12 },
        -- The file browser's title bar takes the library's parts.
        title_bar_count = { tracking = 0.12 },
        title_bar_title = { size = 56 },
        library_count = { tracking = 0.12 },
        library_title = { size = 56 },
        folder_reading = { tracking = 0.12 },
        pager_label = { tracking = 0.12 },
        -- The series and authors screens take the library's header and the home's tiles, by analogy; the detail title
        -- is the featured title's size.
        shelf_detail_title = { size = 46 },
        shelf_back = { tracking = 0.12 },
        -- As the library folder's name.
        series_name = { face = "strong" },
        -- A chip's label, ink on its tint.
        shelf_chip = { tracking = 0.12 },
        shelf_chip_plain = { tracking = 0.12 },
        -- As the library folder's name.
        book_row_title = { face = "strong" },
        -- "read this one next" in the look's label on the tint row; Riso has no accent face.
        book_next_note = { tracking = 0.12 },
        shelf_empty = { tracking = 0.12 },
    },

    launcher = {
        row_gap = 10,
        icon_size = 24,
        padding = { x = 12 },
    },

    -- The quote between 2 px pink rules, tightened with the home.
    quote = {
        padding = 9,
        rule_width = 2,
        rule_color = "hairline_light",
    },

    featured = {
        cover_outline_color = false,
        chip_outline = 0,
        chip_padding = { x = 8 },
        button_fill_color = "tint",
    },

    editor = {
        button_fill_color = "tint",
        card_outline_width = 2,
        card_shadow = { x = 5, y = 4, color = "tint" },
        selected_fill_color = "tint",
    },

    nav = { active_fill_color = "tint" },

    title_bar = {
        sort_fill_color = "tint",
        status_fill_color = "tint",
    },

    library = {
        header = {
            sort_fill_color = "tint",
            status_fill_color = "tint",
        },
        -- At Diner's 195 a cover is fitted in its box on paper, so the box takes the tiles' 2 px ink outline and the
        -- offset outline reads against it rather than standing off the artwork.
        cover = {
            outline_width = 2,
            shadow = { x = 6, color = "outline", outline_width = 2 },
        },
        -- Its shadow is the covers' (library.cover.shadow).
        folder = {
            fill_color = false,
            outline_width = 2,
        },
        badge = { fill_color = "tint" },
        not_downloaded = {
            outline_color = false,
            padding = { x = 8 },
        },
        pager = { next_fill_color = "tint" },
    },

    shelf = {
        detail = { padding = { top = 36 } },
        back = { fill_color = "tint" },
        row = {
            outline_width = 2,
            shadow = { x = 5, y = 4 },
        },
        chip = {
            outline_width = 0,
            under_way_fill_color = "tint",
            finished_fill_color = "tint",
            up_next_fill_color = "tint",
        },
        next = {
            fill_color = "tint",
            shadow = { x = 5, y = 4 },
        },
        groups = { gap = 16 },
        group = {
            outline_width = 2,
            shadow = { x = 5, y = 4 },
            letter_fill_color = "tint",
        },
        up_next = {
            fill_color = "tint",
            outline_width = 0,
        },
    },
}
