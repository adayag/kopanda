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
        quick_settings_band_color = false,
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
        -- The sort and status sheets (cover-grid "The pickers"): no board draws Editorial's, so its
        -- gaps are Diner's (SortC.dc.html:39, :46) and its current choice has no fill.
        selected_fill_color = false,
        aside_above_gap = 2,
        sublabel_gap = 2,
    },

    -- The quick-settings sheet's body: two ruled sections of a label row over a minus button, a
    -- level bar and a plus button, then a three-column grid of outlined tiles, the on tile in ink
    -- (QuickSettings.dc.html:40-87).
    quick_settings = {
        padding_x = 0, -- QuickSettings.dc.html:34; the sheet's 40 side padding holds it
        first_section_padding = { top = 18, bottom = 16 }, -- QuickSettings.dc.html:40
        section_padding = { top = 16, bottom = 16 }, -- QuickSettings.dc.html:51
        section_gap = 10, -- QuickSettings.dc.html:40
        section_rule_width = 1, -- QuickSettings.dc.html:40, :51
        section_rule_color = "hairline", -- QuickSettings.dc.html:40, :51
        control_gap = 12, -- QuickSettings.dc.html:44
        button_w = 44, -- QuickSettings.dc.html:45
        button_h = 36, -- QuickSettings.dc.html:45
        button_outline_width = 1, -- QuickSettings.dc.html:45
        button_outline_color = "ink", -- QuickSettings.dc.html:45
        button_fill_color = false, -- QuickSettings.dc.html:45, transparent
        level_h = 10, -- QuickSettings.dc.html:46, inside its outline
        level_outline_width = 1, -- QuickSettings.dc.html:46
        level_outline_color = "ink", -- QuickSettings.dc.html:46
        level_fill_color = "ink", -- QuickSettings.dc.html:46
        level_track_color = false, -- QuickSettings.dc.html:46, no track
        grid_gap = 10, -- QuickSettings.dc.html:62
        grid_padding = { top = 18, bottom = 0 }, -- QuickSettings.dc.html:62; the sheet's 28 bottom padding follows
        cell_padding = { top = 14, bottom = 12 }, -- QuickSettings.dc.html:63
        cell_gap = 8, -- QuickSettings.dc.html:63
        cell_icon_size = 24, -- QuickSettings.dc.html:64
        cell_outline_width = 1, -- QuickSettings.dc.html:63
        cell_outline_color = "ink", -- QuickSettings.dc.html:63
        cell_fill_color = false, -- QuickSettings.dc.html:67, transparent
        on_fill_color = "ink", -- QuickSettings.dc.html:63
        on_text_color = "paper", -- QuickSettings.dc.html:63
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
    -- Its top margin, row gap, the rule's space and the launcher's row padding are tightened to
    -- 76 % of the board's, rounded, the least that fits the default rows above the nav bar at
    -- the small and medium text sizes on the Colorsoft and the Paperwhite (owner, 2026-10-16:
    -- tighten the home's spacing).
    home = {
        -- The page's padding (Main.dc.html:17; top was 44); 20 below the last row, above the bar
        -- (NavBar.dc.html:19, :61; was 36).
        margin = { top = 33, side = 40, bottom = 20 },
        row_gap = 21, -- the quote's top margin (Main.dc.html:56; was 28)
        column_gap = 16, -- the header row's gap (Main.dc.html:19)
        free_space = "before_last_row", -- the stats row's margin-top: auto (Main.dc.html:87)
        -- The main rule under row 1, with rule_space above and below it and no row gap after.
        header = {
            band_color = false,
            edge_width = 0,
            edge_color = false,
            rule_color = "ink", -- the main rule (Main.dc.html:30)
            rule_width = 2, -- stroke.rule
            rule_space = 17, -- the rule's margin (Main.dc.html:30; was 22)
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
        -- The header's label at its right, "Library": no board draws it here; the aside's style.
        sheet_label = { face = "text", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "muted" },
        -- A row's second line: no board draws it here; the detail's face in sentence case.
        sheet_sublabel = {
            face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0, color = "muted",
        },
        -- A quick-settings bar's label and value, "Brightness" and "12" (QuickSettings.dc.html:41).
        quick_label = {
            face = "text", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- The bars' minus and plus, the button's inherited Plex 400 (QuickSettings.dc.html:45).
        quick_button = {
            face = "text", size = 18, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- A quick-settings tile's label, "Wi-Fi on" (QuickSettings.dc.html:63); the board's weight 600 is
        -- the strong face's 500, the heaviest Plex this look ships.
        quick_cell = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
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
        -- A nav tab's label (NavBar.dc.html:73); the board's weight 500 is the strong face.
        nav_label = { face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "text" },
        -- The active tab's label (NavBar.dc.html:69); the board's weight 600 is the strong face's 500.
        nav_label_active = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- The file browser's book count over its title (Library.dc.html:21); the board's 400 is the text face.
        title_bar_count = {
            face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted",
        },
        -- Its title (Library.dc.html:22, weight 500); CSS line height 1, as the date's 0.
        title_bar_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- The sort picker (Library.dc.html:24-25); the board's weight 600 is the strong face's 500.
        title_bar_sort = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "text",
        },
        -- The status picker (Library.dc.html:24, :26), as the sort picker.
        title_bar_status = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "text",
        },
        -- The library's parts (GridA.dc.html under .tiller/design/2026-10-16-kopanda-library-screens/).
        -- The count over the title (GridA.dc.html:21); the board's 400 is the text face.
        library_count = {
            face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted",
        },
        -- The title (GridA.dc.html:22, weight 500); CSS line height 1.
        library_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- A picker's label (GridA.dc.html:25-26); the board's weight 600 is the strong face's 500.
        library_picker = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "text",
        },
        -- The status picker's label, as the sort's (GridA.dc.html:26).
        library_picker_status = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "text",
        },
        -- A tile's title, one line, CSS line height 1.25 (GridA.dc.html:47); weight 500, the strong face.
        tile_title = { face = "strong", size = 12, uppercase = false, tracking = 0, line_height = 0.25, color = "ink" },
        -- The placeholder's title at the grid's size, CSS line height 1.1 (GridA.dc.html:51).
        tile_cover_title = {
            face = "display", size = 18, uppercase = false, tracking = 0, line_height = 0.1, color = "on_cover",
        },
        -- A folder's book count, CSS line height 1.05 (GridA.dc.html:35, weight 500).
        folder_count = {
            face = "display", size = 22, uppercase = false, tracking = 0, line_height = 0.05, color = "ink",
        },
        -- Its reading count (GridA.dc.html:36).
        folder_reading = {
            face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted",
        },
        -- "Not downloaded" (GridA.dc.html:73), now on its paper chip on the cover (cover-grid D13).
        -- Untracked: the owner's tightening so the label fits beside the badge on both profiles
        -- (board tracking 0.14).
        not_downloaded = {
            face = "text", size = 10, uppercase = true, tracking = 0, line_height = 0, color = "muted",
        },
        -- "1 / 24" between the pager's arrows (GridA.dc.html:85, :87).
        pager_label = { face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted" },
        -- The series and authors screens' parts (AuthorBooksA.dc.html and GridA.dc.html under
        -- .tiller/design/2026-10-16-kopanda-library-screens/); Editorial's series list, one series and
        -- authors list are undrawn, so theirs are the lead's by analogy (D26). Weights 500 and 600 are
        -- the strong face.
        -- One author's name under the count, CSS line height 1 (AuthorBooksA.dc.html:26).
        shelf_detail_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- The back control's label (AuthorBooksA.dc.html:20, weight 600).
        shelf_back = { face = "strong", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "text" },
        -- lead: by analogy with SeriesC.dc.html:35, in the display face as a tile's placeholder title.
        series_name = {
            face = "display", size = 20, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- lead: by analogy with SeriesC.dc.html:36, in the muted text of GridA.dc.html:25.
        series_sub = { face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        -- A chip's label, plain small caps (AuthorBooksA.dc.html:79).
        shelf_chip = {
            face = "strong", size = 10, uppercase = true, tracking = 0.14, line_height = 0, color = "muted",
        },
        -- A marked chip's label in ink (AuthorBooksA.dc.html:52, weight 600).
        shelf_chip_plain = {
            face = "strong", size = 10, uppercase = true, tracking = 0.14, line_height = 0, color = "ink",
        },
        -- lead: by analogy with SeriesBooksC.dc.html:34, in the display face.
        book_index = { face = "display", size = 30, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- lead: by analogy with SeriesBooksC.dc.html:37, in the display face.
        book_row_title = {
            face = "display", size = 18, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- "Read this one next" in small caps: Editorial has no accent face (AuthorBooksA.dc.html:52).
        book_next_note = {
            face = "strong", size = 10, uppercase = true, tracking = 0.14, line_height = 0, color = "ink",
        },
        -- lead: by analogy with SeriesBooksC.dc.html:60, in series_sub's style.
        book_row_note = { face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        -- lead: by analogy with AuthorsC.dc.html:29, in the display face.
        author_letter = {
            face = "display", size = 24, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- lead: by analogy with AuthorsC.dc.html:31.
        author_name = { face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- lead: by analogy with AuthorsC.dc.html:33, in the pickers' small caps (GridA.dc.html:25).
        author_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- The empty note, as the library's (pager_label, GridA.dc.html:85).
        shelf_empty = { face = "text", size = 11, uppercase = true, tracking = 0.14, line_height = 0, color = "muted" },
        -- The header's static label, "Under way first", as the pickers (GridA.dc.html:25).
        shelf_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "text",
        },
    },

    -- The launcher: a grid of text rows, each under a hairline in tile.rule_color.
    launcher = {
        columns = 2, -- Main.dc.html:60
        column_gap = 32, -- Main.dc.html:60
        row_gap = 0, -- Main.dc.html:60
        icon_size = 22, -- Main.dc.html:62
        icon_gap = 14, -- Main.dc.html:61
        padding = { x = 0, y = 11 }, -- Main.dc.html:61; y was 15, tightened with the home (home above)
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
    -- The nav bar: a hairline over paper, five tabs of an icon over an uppercase label, and a 3 px
    -- ink rule over the active tab, laid from the bar's top over the edge (NavBar.dc.html:68-87).
    nav = {
        fill_color = "paper", -- NavBar.dc.html:68
        edge_width = 1, -- NavBar.dc.html:68
        edge_color = "ink", -- NavBar.dc.html:68
        padding_x = 24, -- the bar's side padding (NavBar.dc.html:68)
        padding_top = 16, -- a tab's (NavBar.dc.html:69)
        padding_bottom = 18, -- NavBar.dc.html:69
        icon_size = 26, -- NavBar.dc.html:70
        icon_gap = 7, -- the icon to the label (NavBar.dc.html:69)
        icon_color = "text", -- NavBar.dc.html:73
        active_icon_color = "ink", -- the page's ink, inherited (NavBar.dc.html:14, :17)
        active_rule_width = 3, -- NavBar.dc.html:69
        active_rule_color = "ink", -- NavBar.dc.html:69
        active_fill_color = false, -- the active tab has no fill (NavBar.dc.html:69)
        divider_width = 0, -- no dividers between tabs (NavBar.dc.html:69-87)
        divider_color = false,
    },
    -- The file browser's title bar: a count over a serif title, and the sort and status pickers as
    -- plain text, above a 1 px ink edge on paper (Library.dc.html:17-27).
    title_bar = {
        fill_color = "paper", -- the page under the header (Library.dc.html:17)
        padding = { top = 40, side = 40, bottom = 16 }, -- Library.dc.html:19
        edge_width = 1, -- Library.dc.html:19
        edge_color = "ink", -- Library.dc.html:19
        line_gap = 2, -- the count to the title (Library.dc.html:20)
        picker_gap = 20, -- Library.dc.html:24
        sort_fill_color = false, -- the pickers are plain text (Library.dc.html:25-26)
        status_fill_color = false,
        picker_outline_width = 0, -- no box (Library.dc.html:25-26)
        picker_outline_color = false,
        picker_padding = { x = 0, y = 0 }, -- no box (Library.dc.html:25-26)
        icon_size = 16, -- no board draws the plus: the pickers' size
        icon_color = "text", -- no board draws the plus: the pickers' colour (Library.dc.html:24)
        count_on_shelf = false, -- "142 books" (Library.dc.html:21)
    },
    -- The library: a count over a serif title and plain small-caps pickers above a 2 px ink rule,
    -- three columns of covers with soft shadows and a hairline strip under each, and borderless
    -- arrows round the page label above the nav bar (GridA.dc.html:19-88 under
    -- .tiller/design/2026-10-16-kopanda-library-screens/).
    library = {
        header = {
            fill_color = false, -- the page under the header (GridA.dc.html:19)
            padding = { top = 40, side = 40, bottom = 16 }, -- GridA.dc.html:19
            edge_width = 2, -- GridA.dc.html:19
            edge_color = "ink", -- GridA.dc.html:19
            line_gap = 2, -- the count to the title (GridA.dc.html:20)
            picker_gap = 20, -- GridA.dc.html:24
            picker_padding = { x = 0, y = 0 }, -- no box (GridA.dc.html:25-26)
            picker_outline_width = 0, -- no box (GridA.dc.html:25-26)
            picker_outline_color = false,
            sort_fill_color = false, -- the pickers are plain text (GridA.dc.html:25-26)
            status_fill_color = false,
        },
        grid = {
            padding_top = 22, -- GridA.dc.html:30
            side = 40, -- GridA.dc.html:30
            row_gap = 22, -- GridA.dc.html:30
            column_gap = 20, -- GridA.dc.html:30
            cover_h = 208, -- D2: board 218, so two rows fit (GridA.dc.html:32, :43)
            strip_gap = 10, -- the tile's 8 px gap and the strip's 2 px margin (GridA.dc.html:42, :46)
            title_gap = 8, -- the tile's gap (GridA.dc.html:42)
        },
        cover = {
            -- The hairline outline the look's cover takes at night and in grey (the direction doc :65,
            -- :74), as FeaturedCover.build frames the featured cover; the role is false by day, so
            -- GridA.dc.html:43 draws none (the owner's choice over the feature's token table).
            outline_width = 1,
            outline_color = "outline",
            radius = 3, -- GridA.dc.html:43
            shadow = { x = 2, y = 3, color = "shadow" }, -- GridA.dc.html:43
            padding = { x = 12, y = 16 }, -- the placeholder's (GridA.dc.html:43)
        },
        strip = {
            height = 4, -- GridA.dc.html:46
            outline_width = 0, -- GridA.dc.html:46
        },
        folder = {
            fill_color = "paper", -- GridA.dc.html:32
            outline_width = 1, -- GridA.dc.html:32
            outline_color = "hairline", -- GridA.dc.html:32
            icon_size = 36, -- GridA.dc.html:33
            icon_color = "ink", -- GridA.dc.html:33
            padding = { x = 14, y = 16 }, -- GridA.dc.html:32
            count_gap = 4, -- GridA.dc.html:34
        },
        badge = {
            size = 30, -- GridA.dc.html:66
            outline_width = 1, -- GridA.dc.html:66
            outline_color = "ink", -- GridA.dc.html:66
            fill_color = "paper", -- GridA.dc.html:66
            icon_size = 16, -- GridA.dc.html:67
            icon_color = "ink", -- GridA.dc.html:67
            inset = 8, -- inside the corner (GridA.dc.html:66, right: 8px; bottom: 8px)
            align = "bottom", -- GridA.dc.html:66
        },
        not_downloaded = {
            -- No board: the board's plain text (GridA.dc.html:73) would sit on the artwork, so a paper
            -- chip on the cover (cover-grid D13).
            fill_color = "paper",
            outline_width = 0,
            outline_color = false,
            -- No board: as above. x is the owner's tightening from 6 so "Not downloaded" fits beside the
            -- badge on both profiles.
            padding = { x = 4, y = 2 },
        },
        pager = {
            button_w = 44, -- GridA.dc.html:86, :88
            button_h = 32, -- GridA.dc.html:86, :88
            gap = 22, -- GridA.dc.html:85
            bottom = 16, -- GridA.dc.html:85
            outline_width = 0, -- borderless (GridA.dc.html:86, :88)
            outline_color = false,
            prev_fill_color = false, -- transparent (GridA.dc.html:86)
            next_fill_color = false, -- transparent (GridA.dc.html:88)
            dead_color = "hairline", -- the first page's previous arrow (GridA.dc.html:86)
            prev_icon_color = "ink", -- a live arrow, as the next one (GridA.dc.html:88)
            next_icon_color = "ink", -- GridA.dc.html:88
            label_in_words = false, -- "1 / 24" (GridA.dc.html:87)
        },
    },
    -- The series and authors screens: the library's header on paper, rows and groups ruled in
    -- hairlines rather than boxed, unoutlined covers, plain small-caps chips, and the up-next book
    -- marked by type (AuthorBooksA.dc.html and GridA.dc.html under
    -- .tiller/design/2026-10-16-kopanda-library-screens/). Editorial's series list, one series and
    -- authors list are undrawn: their tokens are the lead's by analogy (D26).
    shelf = {
        series_fill_color = false, -- lead: by analogy with GridA.dc.html:19, no band
        authors_fill_color = false, -- lead: by analogy with GridA.dc.html:19, no band
        detail = {
            padding = { top = 26, side = 40, bottom = 16 }, -- AuthorBooksA.dc.html:19
            back_gap = 14, -- AuthorBooksA.dc.html:19
        },
        back = {
            fill_color = false, -- plain text (AuthorBooksA.dc.html:20)
            outline_width = 0, -- AuthorBooksA.dc.html:20
            padding = { left = 0, right = 0, y = 0 }, -- AuthorBooksA.dc.html:20
            icon_size = 14, -- AuthorBooksA.dc.html:21
            gap = 6, -- AuthorBooksA.dc.html:20
        },
        list = {
            padding_top = 22, -- lead: by analogy with SeriesC.dc.html:27
            side = 40, -- lead: by analogy with SeriesC.dc.html:27
            row_gap = 0, -- lead: by analogy with SeriesC.dc.html:27, rows ruled not boxed
        },
        row = {
            padding = { x = 0, y = 14 }, -- lead: by analogy with GridA.dc.html's hairline rows
            gap = 18, -- lead: by analogy with SeriesC.dc.html:28
            line_gap = 3, -- lead: by analogy with SeriesC.dc.html:34
            outline_width = 0, -- lead: by analogy with GridA.dc.html's hairline rows
            shadow = { x = 0, y = 0 }, -- lead: by analogy with GridA.dc.html's hairline rows
            rule_width = 1, -- lead: by analogy with GridA.dc.html's hairline rows
            rule_color = "hairline", -- lead: by analogy with GridA.dc.html's hairline rows
        },
        stack = {
            cover_w = 38, -- lead: by analogy with SeriesC.dc.html:30-32
            cover_h = 56, -- lead: by analogy with SeriesC.dc.html:30-32
            offset_x = 10, -- lead: by analogy with SeriesC.dc.html:30-32
            offset_y = 2, -- lead: by analogy with SeriesC.dc.html:30-32
            outline_width = 1, -- lead: an edge to part the overlapped covers
            outline_color = "paper", -- lead: an edge to part the overlapped covers
        },
        chip = {
            padding = { x = 0, y = 0 }, -- lead: small caps, as GridA.dc.html:73
            outline_width = 0, -- lead: small caps, as GridA.dc.html:73
            under_way_fill_color = false, -- lead: small caps, as GridA.dc.html:73
            finished_fill_color = false, -- lead: small caps, as GridA.dc.html:73
            not_started_fill_color = false, -- lead: small caps, as GridA.dc.html:73
            up_next_fill_color = false, -- lead: small caps, as GridA.dc.html:73
            not_downloaded_fill_color = false, -- lead: small caps, as GridA.dc.html:73
        },
        books = {
            padding_top = 24, -- lead: by analogy with SeriesBooksC.dc.html:32
            row_gap = 0, -- lead: by analogy with SeriesBooksC.dc.html:32, ruled rows
        },
        book = {
            padding = { x = 0, y = 14 }, -- lead: by analogy with SeriesBooksC.dc.html:33
            index_w = 40, -- lead: by analogy with SeriesBooksC.dc.html:34
            cover_w = 64, -- lead: by analogy with SeriesBooksC.dc.html:35
            cover_h = 96, -- lead: by analogy with SeriesBooksC.dc.html:35
            cover_outline_width = 0, -- lead: Editorial's covers unoutlined, GridA.dc.html:43
            line_gap = 6, -- lead: by analogy with SeriesBooksC.dc.html:36
            bar_height = 4, -- GridA.dc.html:46's strip
            bar_outline_width = 0, -- GridA.dc.html:46's strip
            badge_size = 24, -- lead: GridA.dc.html:66 scaled to the cover
            badge_outline_width = 1, -- lead: GridA.dc.html:66 scaled to the cover
            badge_icon_size = 14, -- lead: GridA.dc.html:66 scaled to the cover
            badge_inset = 6, -- lead: GridA.dc.html:66 scaled to the cover, inside the corner
        },
        next = {
            fill_color = false, -- lead: Editorial marks by type, AuthorBooksA.dc.html:52
            shadow = { x = 0, y = 0 }, -- lead: Editorial marks by type, AuthorBooksA.dc.html:52
            line_gap = 4, -- lead: by analogy with SeriesBooksC.dc.html:45
            text_color = "ink", -- lead: Editorial marks by type, AuthorBooksA.dc.html:52
        },
        groups = {
            padding_top = 22, -- lead: by analogy with AuthorsC.dc.html:27
            gap = 0, -- lead: by analogy with AuthorsC.dc.html:27, ruled groups
        },
        group = {
            outline_width = 0, -- lead: ruled groups, by analogy with AuthorsC.dc.html:28
            shadow = { x = 0, y = 0 }, -- lead: ruled groups, by analogy with AuthorsC.dc.html:28
            rule_width = 1, -- lead: ruled groups, by analogy with AuthorsC.dc.html:28
            rule_color = "hairline", -- lead: ruled groups, by analogy with AuthorsC.dc.html:28
            letter_w = 48, -- lead: by analogy with AuthorsC.dc.html:29
            letter_fill_color = false, -- lead: by analogy with AuthorsC.dc.html:29, no fill
            letter_rule_width = 0, -- lead: by analogy with AuthorsC.dc.html:29, no rule
        },
        author = {
            padding = { x = 16, y = 11 }, -- lead: by analogy with AuthorsC.dc.html:31
            rule_width = 1, -- lead: Editorial's row rules, by analogy with AuthorsC.dc.html:31
            rule_color = "hairline_light", -- lead: Editorial's row rules, by analogy with AuthorsC.dc.html:31
        },
        author_grid = {
            cover_h = 198, -- D14: board 206 (AuthorBooksA.dc.html:32), so two rows fit
        },
        up_next = {
            fill_color = "paper", -- lead: as the library's not-downloaded chip (library.not_downloaded)
            outline_width = 0, -- lead: as the library's not-downloaded chip (library.not_downloaded)
        },
    },
}
