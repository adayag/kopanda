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
            on_accent = false, -- Editorial has no accent fills
            cover = "#2b4c6f", -- the typographic cover's fill (Main.dc.html:33)
            on_cover = "#f3f1ea", -- its title and authors (Main.dc.html:33)
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
            on_accent = false, -- Editorial has no accent fills
            cover = "#2b4c6f", -- NightA.dc.html:33
            on_cover = "#f3f1ea", -- NightA.dc.html:33
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
            on_accent = false, -- Editorial has no accent fills
            cover = "#4a4a4a", -- PWEditorial.dc.html:33, the doc's cover grey
            on_cover = "#f4f4f4", -- PWEditorial.dc.html:33
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
        inset = { side = 0, bottom = 0 }, -- full width, on the bottom edge (HoldBook.dc.html:34)
        padding = { top = 0, side = 40, bottom = 28 }, -- HoldBook.dc.html:34
        book_band_color = false, -- Editorial's headers have no band
        home_band_color = false,
        folder_band_color = false,
        header_rule_color = "ink", -- HoldBook.dc.html:35
        header_rule_width = 1, -- HoldBook.dc.html:35
        header_padding = { top = 22, side = 0, bottom = 16 }, -- HoldHome.dc.html:35
        book_header_padding = { top = 24, side = 0, bottom = 20 }, -- HoldBook.dc.html:35
        cover_gap = 18, -- HoldBook.dc.html:35
        cover_w = 60, -- HoldBook.dc.html:36
        cover_h = 90, -- HoldBook.dc.html:36
        line_gap = 3, -- HoldBook.dc.html:37
        meta_gap = 4, -- HoldBook.dc.html:40
        aside_gap = 12, -- "Folder · 3" after the heading (FolderOpen.dc.html:36)
        row_padding = { x = 0, y = 15 }, -- HoldBook.dc.html:43
        row_gap = 16, -- HoldBook.dc.html:43
        icon_size = 22, -- HoldBook.dc.html:44
        row_rule_color = "hairline", -- HoldBook.dc.html:43
        row_rule_width = 1, -- HoldBook.dc.html:43
        last_row_bottom = 0, -- HoldBook.dc.html:69
        status_chip_color = false, -- Editorial's details are plain (HoldBook.dc.html:56)
        state_chip_color = false,
        chip_padding = { x = false, y = false },
        chip_outline_width = 0,
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
            -- Its slots on its bottom, the clock's baseline level with the date's last line
            -- (Main.dc.html:19, align-items: flex-end).
            align = "bottom",
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
        weather_icon = { size = 0, gap = 0 }, -- Editorial's weather has no icon (Main.dc.html:25)
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
        -- The typographic cover's title, CSS line height 1.05 (Main.dc.html:34).
        cover_title = {
            face = "display", size = 24, uppercase = true, tracking = 0.04, line_height = 0.05, color = "on_cover",
        },
        -- Its authors at the foot (Main.dc.html:35).
        cover_authors = {
            face = "text", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "on_cover",
        },
        -- "No book yet" in the first run's dashed frame (EmptyStates.dc.html:33).
        cover_empty = { face = "text", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "muted" },
        -- "Continue reading" over the featured book (Main.dc.html:39).
        featured_label = {
            face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted",
        },
        -- The featured book's title, two lines at most, CSS line height 1.1 (Main.dc.html:40).
        featured_title = {
            face = "display", size = 28, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- Its authors (Main.dc.html:41).
        featured_authors = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- Its chapter (Main.dc.html:42).
        featured_chapter = {
            face = "text", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- The percent and the time left under the bar (Main.dc.html:48).
        featured_caption = {
            face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- "Nothing open yet.", CSS line height 1.15 (EmptyStates.dc.html:36).
        featured_empty_title = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0.15, color = "ink",
        },
        -- The first run's line under it, CSS line height 1.4 (EmptyStates.dc.html:37).
        featured_empty_body = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0.4, color = "text",
        },
        -- "Open the Library" (EmptyStates.dc.html:38); the board's weight 600 is the strong face's 500.
        featured_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- A launcher entry's label (Main.dc.html:61, weight 500, the strong face).
        launcher_label = {
            face = "strong", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- Its suffix, "off" or "plugin missing" (EmptyStates.dc.html:65).
        launcher_suffix = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- A sheet's heading, "Home" (HoldHome.dc.html:36).
        sheet_heading = {
            face = "display", size = 26, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- The heading's aside, "KoPanda" (HoldHome.dc.html:37).
        sheet_aside = { face = "text", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "muted" },
        -- The book header's title, CSS line height 1.1 (HoldBook.dc.html:38).
        sheet_title = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- Its author (HoldBook.dc.html:39).
        sheet_author = { face = "text", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text" },
        -- Its meta line, "62% · Part 3 · opened yesterday" (HoldBook.dc.html:40).
        sheet_meta = { face = "text", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "muted" },
        -- A sheet row's label (HoldBook.dc.html:43).
        sheet_row = { face = "strong", size = 17, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- A row's detail, "Reading ›" (HoldBook.dc.html:56).
        sheet_detail = {
            face = "text", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- Not drawn: Editorial has no chips. Its plain detail's style.
        sheet_chip = { face = "text", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "muted" },
        -- The editor screens' aside over the title, "Home" (EditLayout.dc.html:21), at the editor's line
        -- height of 0.3, which every editor part takes so the default layout's five rows fit above the
        -- foot (owner decision).
        editor_aside = {
            face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0.3, color = "muted",
        },
        -- Their title, "Edit layout" (EditLayout.dc.html:22), at the same line height.
        editor_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- A button's text, "Done"; the board's weight 600 is the strong face's 500 (EditLayout.dc.html:24),
        -- at the same line height.
        editor_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0.3, color = "ink",
        },
        -- A card's caption, "Row 1 · two columns" (EditLayout.dc.html:35), at the same line height.
        editor_caption = {
            face = "text", size = 11, uppercase = true, tracking = 0.12, line_height = 0.3, color = "muted",
        },
        -- A column box's widget (EditLayout.dc.html:37), at the same line height.
        editor_box = {
            face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- Its share, "1/2" (EditLayout.dc.html:37), at the same line height.
        editor_share = {
            face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        -- A launcher entry's label (LauncherManage.dc.html:32), at the browser's normal line height
        -- of about 1.3, so six rows fit above the add-an-entry foot (owner decision).
        editor_label = {
            face = "strong", size = 16, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- Its kind line (LauncherManage.dc.html:33), at the same line height.
        editor_kind = {
            face = "text", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "muted",
        },
        -- The note under the kinds (LauncherManage.dc.html:103), at the same line height.
        editor_note = {
            face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
    },

    -- The launcher: a grid of text rows, each under a hairline in tile.rule_color.
    launcher = {
        columns = 2, -- Main.dc.html:60
        column_gap = 32, -- Main.dc.html:60
        row_gap = 0, -- Main.dc.html:60
        icon_size = 22, -- Main.dc.html:62
        icon_gap = 14, -- Main.dc.html:61
        padding = { x = 0, y = 15 }, -- Main.dc.html:61
        tile_height = false, -- Editorial's entries are rows, not tiles
        accent_1_color = false, -- Editorial's rows have no fill
        accent_2_color = false,
        accent_3_color = false,
        suffix_gap = 6, -- the suffix's margin-left (EmptyStates.dc.html:65)
        suffix_below = false, -- the suffix sits on the label's line (EmptyStates.dc.html:65)
    },

    -- The featured book's cover box.
    featured = {
        cover_w = 150, -- Main.dc.html:33
        cover_h = 225, -- Main.dc.html:33
        cover_padding = { x = 14, y = 18 }, -- the placeholder's padding (Main.dc.html:33)
        dash = 4, -- the first run's dashed frame: KOReader has no dashed border, so 4 px dashes
        dash_gap = 4, -- with 4 px gaps (EmptyStates.dc.html:33)
        gap = 24, -- between the cover and the text column (Main.dc.html:32)
        column_padding_y = 0, -- the text column is unpadded (Main.dc.html:37)
        title_gap = 6, -- the column's gap between the label and the title (Main.dc.html:38)
        chip_outline = false, -- the label is plain text, no chip (Main.dc.html:39)
        chip_padding = { x = false, y = false },
        button_padding = { x = 14, y = 9 }, -- "Open the Library" (EmptyStates.dc.html:38)
        button_fill_color = false, -- unfilled (EmptyStates.dc.html:38)
        button_outline_color = "ink", -- its 1 px ink border, stroke.outline (EmptyStates.dc.html:38)
    },
    -- The editor screens, edit layout and launcher management: a header of an aside over a title
    -- and a Done button above an ink rule, then hairline cards or rows (EditLayout.dc.html,
    -- LauncherManage.dc.html). Cards cast card_shadow, none here.
    editor = {
        padding = { top = 40, side = 40, bottom = 28 }, -- EditLayout.dc.html:19, :101
        header_band_color = false, -- Editorial's header is on paper
        header_text_color = false,
        header_rule_color = "ink", -- EditLayout.dc.html:19
        header_rule_width = 1, -- EditLayout.dc.html:19
        header_gap = 16, -- the header's padding above the rule (EditLayout.dc.html:19)
        body_gap = 18, -- the rule to the first card (EditLayout.dc.html:27)
        button_outline_color = "ink", -- EditLayout.dc.html:24
        button_outline_width = 1, -- EditLayout.dc.html:24
        button_fill_color = false, -- transparent (EditLayout.dc.html:24)
        button_padding = { x = 14, y = 8 }, -- EditLayout.dc.html:24
        card_gap = 12, -- EditLayout.dc.html:27
        card_padding = { x = 14, y = 12 }, -- EditLayout.dc.html:29
        card_outline_color = "hairline", -- EditLayout.dc.html:29
        card_outline_width = 1, -- EditLayout.dc.html:29
        card_shadow = { x = 0, y = 0, color = false }, -- the boards draw none (EditLayout.dc.html:29)
        selected_outline_color = "ink", -- EditLayout.dc.html:43
        -- The board's #e9e6dc is in no palette; hairline_light (#e2dfd4) is the nearest role (EditLayout.dc.html:43).
        selected_fill_color = "hairline_light",
        arrow_size = 28, -- EditLayout.dc.html:30-32
        arrow_gap = 14, -- EditLayout.dc.html:29
        disabled_color = "hairline", -- EditLayout.dc.html:90
        box_padding = { x = 12, y = 10 }, -- EditLayout.dc.html:37
        box_gap = 8, -- EditLayout.dc.html:36
        row_padding = { y = 14 }, -- LauncherManage.dc.html:29
        row_rule_color = "hairline", -- LauncherManage.dc.html:29
        row_rule_width = 1, -- LauncherManage.dc.html:29
        icon_size = 22, -- LauncherManage.dc.html:30
        icon_gap = 14, -- LauncherManage.dc.html:29
        control_size = 30, -- LauncherManage.dc.html:35
        kind_gap = 8, -- LauncherManage.dc.html:97
        kind_columns = 2, -- LauncherManage.dc.html:97
    },
}
