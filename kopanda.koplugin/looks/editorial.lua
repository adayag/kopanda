-- Editorial: a serif display face, hairlines and soft shadows on warm paper. Pure data, typed
-- from the direction doc (.tiller/design/2026-10-13-kopanda-ui-direction.md, "The two looks",
-- the night palettes, "Greys for the Paperwhite"); where the doc leaves a value out, the line's
-- comment names where it comes from. It declares only what differs from the base look
-- (looks/base.lua), which holds every other token.
return {
    palettes = {
        day = {
            paper = "#f3f1ea",
            ink = "#1c1b19",
            muted = "#6b6861",
            text = "#4a4843", -- the canvas: Main.dc.html:41 draws it where NightA.dc.html:41 draws the night text
            hairline = "#c9c5b8",
            hairline_light = "#e2dfd4", -- the doc gives none by day; the canvas's row rules (Main.dc.html)
            shadow = "#c9c5b8", -- the doc: shadow in the hairline colour
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
            outline = "#3a3b40", -- the doc: the cover gets a hairline outline instead of a shadow
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
            outline = "#8c8c8c", -- implied: the Paperwhite cover gains an outline, Editorial's is a hairline
            shadow = "#8c8c8c", -- implied: the shadow is the hairline colour
            on_accent = false, -- Editorial has no accent fills
            on_cover = "#f4f4f4", -- PWEditorial.dc.html:33
        },
    },

    stroke = { outline = 1 }, -- implied: Editorial's outlines are hairlines

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide; Editorial's
    -- are fills.
    shadow = { cover = { x = 2, y = 3 }, sheet = { y = 0, color = false } },

    radius = { cover = 3 },

    -- A text row with a hairline under it.
    tile = {
        box = false,
        fill_color = false,
        outline_color = false,
        rule_color = "hairline_light", -- the canvas's launcher rows (Main.dc.html, NightA.dc.html)
    },

    -- A 4 px bar, ink on hairline.
    progress = { height = 4, track_color = "hairline", outline_color = false, outline_width = 0, fill_grey = false },

    -- A paper panel from the bottom edge under a 2 px rule.
    sheet = {
        rule_color = "ink", -- the canvas's sheet rule (HoldBook.dc.html)
        rule_width = 2,
        outline_color = false,
        outline_width = 1, -- stroke.outline; unused, the sheet has no outline colour
        header_band = false,
        inset = { side = 0, bottom = 0 }, -- full width, on the bottom edge (HoldBook.dc.html:34)
        padding = { side = 40, bottom = 28 }, -- HoldBook.dc.html:34
        header_rule_color = "ink", -- HoldBook.dc.html:35
        header_rule_width = 1, -- HoldBook.dc.html:35
        header_padding = { top = 22, side = 0 }, -- HoldHome.dc.html:35
        book_header_padding = { top = 24, side = 0, bottom = 20 }, -- HoldBook.dc.html:35
        cover_gap = 18, -- HoldBook.dc.html:35
        cover_w = 60, -- HoldBook.dc.html:36
        cover_h = 90, -- HoldBook.dc.html:36
        line_gap = 3, -- HoldBook.dc.html:37
        row_padding = { x = 0, y = 15 }, -- HoldBook.dc.html:43
        row_gap = 16, -- HoldBook.dc.html:43
        row_rule_color = "hairline", -- HoldBook.dc.html:43
        row_rule_width = 1, -- HoldBook.dc.html:43
        last_row_bottom = 0, -- HoldBook.dc.html:69
        chip_padding = { x = false, y = false },
        chip_outline_width = 0,
        folder_box = {
            outline_width = 1, -- lead: by analogy with the folder tile, GridA.dc.html:32
            outline_color = "hairline", -- lead: by analogy with the folder tile, GridA.dc.html:32
        },
        sort_chip_color = false, -- lead: by analogy with status_chip_color, HoldBook.dc.html:56
    },

    -- The quick-settings sheet's body: two ruled sections of a label row over a minus button, a
    -- level bar and a plus button, then a three-column grid of outlined tiles, the on tile in ink
    -- (QuickSettings.dc.html:40-87).
    quick_settings = {
        padding_x = 0, -- QuickSettings.dc.html:34; the sheet's 40 side padding holds it
        first_section_padding = { top = 18, bottom = 16 }, -- QuickSettings.dc.html:40
        section_padding = { top = 16, bottom = 16 }, -- QuickSettings.dc.html:51
        section_rule_width = 1, -- QuickSettings.dc.html:40, :51
        section_rule_color = "hairline", -- QuickSettings.dc.html:40, :51
        button_outline_width = 1, -- QuickSettings.dc.html:45
        button_outline_color = "ink", -- QuickSettings.dc.html:45
        button_fill_color = false, -- QuickSettings.dc.html:45, transparent
        level_h = 10, -- QuickSettings.dc.html:46, inside its outline
        level_outline_width = 1, -- QuickSettings.dc.html:46
        level_outline_color = "ink", -- QuickSettings.dc.html:46
        level_track_color = false, -- QuickSettings.dc.html:46, no track
        grid_padding = { top = 18, bottom = 0 }, -- QuickSettings.dc.html:62; the sheet's 28 bottom padding follows
        cell_outline_width = 1, -- QuickSettings.dc.html:63
        cell_outline_color = "ink", -- QuickSettings.dc.html:63
        cell_fill_color = false, -- QuickSettings.dc.html:67, transparent
        on_text_color = "paper", -- QuickSettings.dc.html:63
    },

    -- Small caps, muted.
    chip = { small_caps = true, uppercase = false, text_color = "muted", outline_color = false },

    -- 11 px small caps, 0.14 em tracking.
    label = { face = "text", small_caps = true, uppercase = false, tracking = 0.14 },

    -- The home's page: its margins, the gaps between rows and between columns, where the free
    -- height goes, the header drawn with row 1 and the footer. Main.dc.html is the board.
    -- Its top margin, row gap, the rule's space and the launcher's row padding are tightened to
    -- 76 % of the board's, rounded, the least that fits the default rows above the nav bar at
    -- the small and medium text sizes on the Colorsoft and the Paperwhite (owner, 2026-10-16:
    -- tighten the home's spacing).
    home = {
        -- The main rule under row 1, with rule_space above and below it and no row gap after.
        header = {
            rule_color = "ink", -- the main rule (Main.dc.html:30)
            rule_width = 2, -- stroke.rule
            rule_space = 17, -- the rule's margin (Main.dc.html:30; was 22)
        },
        -- The weather line's order: condition_first ("Partly cloudy, 61°", Main.dc.html:25) or
        -- degrees_first ("61° partly cloudy").
        weather_order = "condition_first",
        -- The stats: spread across the column with equal space between, or joined on one line;
        -- the streak word_first, "Streak 4 days", or count_first, "4-day streak" (Main.dc.html:87).
        stats_line = "spread",
        stats_streak = "word_first",
        -- The featured book: its label continue_reading, "Continue reading", or now_reading; its
        -- authors and chapter on their own lines and its caption's percent and the rest apart,
        -- split, or joined (Main.dc.html:32-52).
        featured_label = "continue_reading",
        featured_details = "split",
    },

    -- The home widgets' text, per part: a face role, a size in board pixels (before text_size),
    -- case, tracking in em, line height as KOReader's TextBoxWidget counts it (extra space in
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role.
    type = {
        -- The weekday over the date (Main.dc.html:21).
        date_label = { face = "text", tracking = 0.14 },
        -- The date (Main.dc.html:22).
        date = { face = "display", size = 36, line_height = 0 },
        -- The clock (Main.dc.html:26).
        clock = { tracking = 0, line_height = 0 },
        -- The weather line (Main.dc.html:25).
        weather = { size = 11, uppercase = true, tracking = 0.14, color = "muted" },
        -- The quote, CSS line height 1.4 (Main.dc.html:56). The board draws it in #2f2e2b, which no
        -- Editorial role holds, so ink stands in for it.
        quote = { line_height = 0.4 },
        -- The reading stats (Main.dc.html:87).
        stats = { face = "text", color = "muted" },
        -- Its authors at the foot (Main.dc.html:35).
        cover_authors = { face = "text", size = 11 },
        -- "No book yet" in the first run's dashed frame (EmptyStates.dc.html:33).
        cover_empty = { face = "text", size = 12 },
        -- "Continue reading" over the featured book (Main.dc.html:39).
        featured_label = { tracking = 0.14, color = "muted" },
        -- The featured book's title, two lines at most, CSS line height 1.1 (Main.dc.html:40).
        featured_title = { line_height = 0.1 },
        -- Its authors (Main.dc.html:41).
        featured_authors = { size = 15 },
        -- Its chapter (Main.dc.html:42).
        featured_chapter = { size = 14 },
        -- The percent and the time left under the bar (Main.dc.html:48).
        featured_caption = { face = "text", size = 13 },
        -- "Nothing open yet.", CSS line height 1.15 (EmptyStates.dc.html:36).
        featured_empty_title = { line_height = 0.15 },
        -- The first run's line under it, CSS line height 1.4 (EmptyStates.dc.html:37).
        featured_empty_body = { size = 15 },
        -- A launcher entry's label (Main.dc.html:61, weight 500, the strong face).
        launcher_label = { size = 16, line_height = 0 },
        -- A sheet's heading, "Home" (HoldHome.dc.html:36).
        sheet_heading = { line_height = 0, color = "ink" },
        -- The heading's aside, "KoPanda" (HoldHome.dc.html:37).
        sheet_aside = { face = "text", size = 12 },
        -- The book header's title, CSS line height 1.1 (HoldBook.dc.html:38).
        sheet_title = { line_height = 0.1, color = "ink" },
        -- Its author (HoldBook.dc.html:39).
        sheet_author = { size = 14, color = "text" },
        -- Its meta line, "62% · Part 3 · opened yesterday" (HoldBook.dc.html:40).
        sheet_meta = { face = "text", size = 12, uppercase = true, tracking = 0.1, color = "muted" },
        -- A sheet row's label (HoldBook.dc.html:43).
        sheet_row = { face = "strong" },
        -- A row's detail, "Reading ›" (HoldBook.dc.html:56).
        sheet_detail = { face = "text", size = 12 },
        -- Not drawn: Editorial has no chips. Its plain detail's style.
        sheet_chip = { face = "text", size = 12, color = "muted" },
        -- lead: by analogy with HoldEmptyC.dc.html:47, its sheet_chip; Editorial draws no chips.
        sheet_chip_plain = { face = "text", size = 12, color = "muted" },
        -- The header's label at its right, "Library": no board draws it here; the aside's style.
        sheet_label = { face = "text", size = 12 },
        -- A row's second line: no board draws it here; the detail's face in sentence case.
        sheet_sublabel = { size = 12 },
        -- A quick-settings bar's label and value, "Brightness" and "12" (QuickSettings.dc.html:41).
        quick_label = { face = "text" },
        -- The bars' minus and plus, the button's inherited Plex 400 (QuickSettings.dc.html:45).
        quick_button = { face = "text" },
        -- The editor screens' aside over the title, "Home" (EditLayout.dc.html:21), at the editor's line
        -- height of 0.3, which every editor part takes so the default layout's five rows fit above the
        -- foot (owner decision).
        editor_aside = { face = "text", tracking = 0.14 },
        -- A card's caption, "Row 1 · two columns" (EditLayout.dc.html:35), at the same line height.
        editor_caption = { face = "text" },
        -- Its kind line (LauncherManage.dc.html:33), at the same line height.
        editor_kind = { face = "text" },
        -- A nav tab's label (NavBar.dc.html:73); the board's weight 500 is the strong face.
        nav_label = { color = "text" },
        -- The file browser's book count over its title (Library.dc.html:21); the board's 400 is the text face.
        title_bar_count = { face = "text" },
        -- Its title (Library.dc.html:22, weight 500); CSS line height 1, as the date's 0.
        title_bar_title = { line_height = 0 },
        -- The sort picker (Library.dc.html:24-25); the board's weight 600 is the strong face's 500.
        title_bar_sort = { color = "text" },
        -- The status picker (Library.dc.html:24, :26), as the sort picker.
        title_bar_status = { color = "text" },
        -- The library's parts (GridA.dc.html under .tiller/design/2026-10-16-kopanda-library-screens/).
        -- The count over the title (GridA.dc.html:21); the board's 400 is the text face.
        library_count = { face = "text" },
        -- The title (GridA.dc.html:22, weight 500); CSS line height 1.
        library_title = { line_height = 0 },
        -- A picker's label (GridA.dc.html:25-26); the board's weight 600 is the strong face's 500.
        library_picker = { color = "text" },
        -- The status picker's label, as the sort's (GridA.dc.html:26).
        library_picker_status = { color = "text" },
        -- A tile's title, one line, CSS line height 1.25 (GridA.dc.html:47); weight 500, the strong face.
        tile_title = { line_height = 0.25 },
        -- The placeholder's title at the grid's size, CSS line height 1.1 (GridA.dc.html:51).
        tile_cover_title = { size = 18 },
        -- A folder's book count, CSS line height 1.05 (GridA.dc.html:35, weight 500).
        folder_count = { face = "display", size = 22, line_height = 0.05 },
        -- Its reading count (GridA.dc.html:36).
        folder_reading = { face = "text", tracking = 0.14 },
        -- "1 / 24" between the pager's arrows (GridA.dc.html:85, :87).
        pager_label = { face = "text", tracking = 0.14, color = "muted" },
        -- The series and authors screens' parts (AuthorBooksA.dc.html and GridA.dc.html under
        -- .tiller/design/2026-10-16-kopanda-library-screens/); Editorial's series list, one series and
        -- authors list are undrawn, so theirs are the lead's by analogy (D26). Weights 500 and 600 are
        -- the strong face.
        -- One author's name under the count, CSS line height 1 (AuthorBooksA.dc.html:26).
        shelf_detail_title = { size = 34, line_height = 0 },
        -- The back control's label (AuthorBooksA.dc.html:20, weight 600).
        shelf_back = { tracking = 0.14, color = "text" },
        -- lead: by analogy with SeriesC.dc.html:35, in the display face as a tile's placeholder title.
        series_name = { size = 20 },
        -- lead: by analogy with SeriesC.dc.html:36, in the muted text of GridA.dc.html:25.
        series_sub = { size = 12 },
        -- A chip's label, plain small caps (AuthorBooksA.dc.html:79).
        shelf_chip = { tracking = 0.14, color = "muted" },
        -- A marked chip's label in ink (AuthorBooksA.dc.html:52, weight 600).
        shelf_chip_plain = { tracking = 0.14 },
        -- lead: by analogy with SeriesBooksC.dc.html:34, in the display face.
        book_index = { size = 30 },
        -- lead: by analogy with SeriesBooksC.dc.html:37, in the display face.
        book_row_title = { size = 18 },
        -- "Read this one next" in small caps: Editorial has no accent face (AuthorBooksA.dc.html:52).
        book_next_note = { size = 10, color = "ink" },
        -- lead: by analogy with SeriesBooksC.dc.html:60, in series_sub's style.
        book_row_note = { size = 12 },
        -- lead: by analogy with AuthorsC.dc.html:29, in the display face.
        author_letter = { size = 24, color = "ink" },
        -- lead: by analogy with AuthorsC.dc.html:31.
        author_name = { size = 15 },
        -- The empty note, as the library's (pager_label, GridA.dc.html:85).
        shelf_empty = { face = "text", size = 11, tracking = 0.14 },
        -- The header's static label, "Under way first", as the pickers (GridA.dc.html:25).
        shelf_label = { color = "text" },
    },

    -- The launcher: a grid of text rows, each under a hairline in tile.rule_color.
    launcher = {
        columns = 2, -- Main.dc.html:60
        column_gap = 32, -- Main.dc.html:60
        icon_gap = 14, -- Main.dc.html:61
        tile_height = false, -- Editorial's entries are rows, not tiles
    },

    -- The quote between hairline rules (Main.dc.html:56).
    quote = {
        rule_width = 1, -- stroke.hairline (Main.dc.html:56)
        rule_color = "hairline", -- Main.dc.html:56
    },

    -- The featured book's cover box.
    featured = {
        cover_padding = { x = 14, y = 18 }, -- the placeholder's padding (Main.dc.html:33)
        column_padding_y = 0, -- the text column is unpadded (Main.dc.html:37)
        title_gap = 6, -- the column's gap between the label and the title (Main.dc.html:38)
        chip_outline = false, -- the label is plain text, no chip (Main.dc.html:39)
        chip_padding = { x = false, y = false },
        button_outline_color = "ink", -- its 1 px ink border, stroke.outline (EmptyStates.dc.html:38)
    },

    -- The editor screens, edit layout and launcher management: a header of an aside over a title
    -- and a Done button above an ink rule, then hairline cards or rows (EditLayout.dc.html,
    -- LauncherManage.dc.html). Cards cast card_shadow, none here.
    editor = {
        header_rule_color = "ink", -- EditLayout.dc.html:19
        header_rule_width = 1, -- EditLayout.dc.html:19
        button_outline_color = "ink", -- EditLayout.dc.html:24
        button_outline_width = 1, -- EditLayout.dc.html:24
        button_fill_color = false, -- transparent (EditLayout.dc.html:24)
        card_gap = 12, -- EditLayout.dc.html:27
        card_outline_color = "hairline", -- EditLayout.dc.html:29
        card_outline_width = 1, -- EditLayout.dc.html:29
        selected_outline_color = "ink", -- EditLayout.dc.html:43
        disabled_color = "hairline", -- EditLayout.dc.html:90
        row_rule_color = "hairline", -- LauncherManage.dc.html:29
        row_rule_width = 1, -- LauncherManage.dc.html:29
    },

    -- The nav bar: a hairline over paper, five tabs of an icon over an uppercase label, and a 3 px
    -- ink rule over the active tab, laid from the bar's top over the edge (NavBar.dc.html:68-87).
    nav = {
        edge_width = 1, -- NavBar.dc.html:68
        padding_x = 24, -- the bar's side padding (NavBar.dc.html:68)
        padding_top = 16, -- a tab's (NavBar.dc.html:69)
        padding_bottom = 18, -- NavBar.dc.html:69
        icon_size = 26, -- NavBar.dc.html:70
        icon_color = "text", -- NavBar.dc.html:73
        active_rule_width = 3, -- NavBar.dc.html:69
        active_rule_color = "ink", -- NavBar.dc.html:69
    },

    -- The file browser's title bar: a count over a serif title, and the sort and status pickers as
    -- plain text, above a 1 px ink edge on paper (Library.dc.html:17-27).
    title_bar = {
        padding = { top = 40 }, -- Library.dc.html:19
        edge_width = 1, -- Library.dc.html:19
        edge_color = "ink", -- Library.dc.html:19
        line_gap = 2, -- the count to the title (Library.dc.html:20)
        picker_gap = 20, -- Library.dc.html:24
        sort_fill_color = false, -- the pickers are plain text (Library.dc.html:25-26)
        status_fill_color = false,
        picker_outline_width = 0, -- no box (Library.dc.html:25-26)
        picker_outline_color = false,
        picker_padding = { x = 0, y = 0 }, -- no box (Library.dc.html:25-26)
        icon_color = "text", -- no board draws the plus: the pickers' colour (Library.dc.html:24)
    },

    -- The library: a count over a serif title and plain small-caps pickers above a 2 px ink rule,
    -- three columns of covers with soft shadows and a hairline strip under each, and borderless
    -- arrows round the page label above the nav bar (GridA.dc.html:19-88 under
    -- .tiller/design/2026-10-16-kopanda-library-screens/).
    library = {
        header = {
            padding = { top = 40 }, -- GridA.dc.html:19
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
            cover_h = 208, -- D2: board 218, so two rows fit (GridA.dc.html:32, :43)
            strip_gap = 10, -- the tile's 8 px gap and the strip's 2 px margin (GridA.dc.html:42, :46)
        },
        cover = {
            -- The hairline outline the look's cover takes at night and in grey (the direction doc :65,
            -- :74), as FeaturedCover.build frames the featured cover; the role is false by day, so
            -- GridA.dc.html:43 draws none (the owner's choice over the feature's token table).
            outline_width = 1,
            radius = 3, -- GridA.dc.html:43
            shadow = { x = 2, y = 3 }, -- GridA.dc.html:43
            padding = { x = 12, y = 16 }, -- the placeholder's (GridA.dc.html:43)
        },
        strip = {
            height = 4, -- GridA.dc.html:46
            outline_width = 0, -- GridA.dc.html:46
        },
        folder = {
            outline_width = 1, -- GridA.dc.html:32
            outline_color = "hairline", -- GridA.dc.html:32
            icon_size = 36, -- GridA.dc.html:33
            padding = { y = 16 }, -- GridA.dc.html:32
        },
        badge = {
            size = 30, -- GridA.dc.html:66
            outline_width = 1, -- GridA.dc.html:66
            outline_color = "ink", -- GridA.dc.html:66
            icon_size = 16, -- GridA.dc.html:67
            inset = 8, -- inside the corner (GridA.dc.html:66, right: 8px; bottom: 8px)
            align = "bottom", -- GridA.dc.html:66
        },
        -- The Not downloaded chip, gone (tweaks/badge-only-not-downloaded); its padding and outline
        -- colour stay as the one-author grid's Up next chip on the cover (series-and-authors D5).
        not_downloaded = {
            -- No board: the board's plain text (GridA.dc.html:73) would sit on the artwork, so a paper
            -- chip on the cover (cover-grid D13).
            outline_color = false,
            -- No board: as above. x is the owner's tightening from 6 so "Not downloaded" fit beside the
            -- badge on both profiles.
            padding = { y = 2 },
        },
        pager = {
            gap = 22, -- GridA.dc.html:85
            outline_width = 0, -- borderless (GridA.dc.html:86, :88)
            outline_color = false,
            prev_fill_color = false, -- transparent (GridA.dc.html:86)
            dead_color = "hairline", -- the first page's previous arrow (GridA.dc.html:86)
            label_in_words = false, -- "1 / 24" (GridA.dc.html:87)
        },
    },

    -- The series and authors screens: the library's header on paper, rows and groups ruled in
    -- hairlines rather than boxed, unoutlined covers, plain small-caps chips, and the up-next book
    -- marked by type (AuthorBooksA.dc.html and GridA.dc.html under
    -- .tiller/design/2026-10-16-kopanda-library-screens/). Editorial's series list, one series and
    -- authors list are undrawn: their tokens are the lead's by analogy (D26).
    shelf = {
        detail = { back_gap = 14 }, -- AuthorBooksA.dc.html:19
        back = {
            fill_color = false, -- plain text (AuthorBooksA.dc.html:20)
            outline_width = 0, -- AuthorBooksA.dc.html:20
            padding = { left = 0, right = 0, y = 0 }, -- AuthorBooksA.dc.html:20
        },
        list = {
            padding_top = 22, -- lead: by analogy with SeriesC.dc.html:27
            row_gap = 0, -- lead: by analogy with SeriesC.dc.html:27, rows ruled not boxed
        },
        row = {
            padding = { x = 0, y = 14 }, -- lead: by analogy with GridA.dc.html's hairline rows
            outline_width = 0, -- lead: by analogy with GridA.dc.html's hairline rows
            rule_width = 1, -- lead: by analogy with GridA.dc.html's hairline rows
            rule_color = "hairline", -- lead: by analogy with GridA.dc.html's hairline rows
        },
        stack = {
            outline_width = 1, -- lead: an edge to part the overlapped covers
            outline_color = "paper", -- lead: an edge to part the overlapped covers
        },
        chip = {
            padding = { x = 0, y = 0 }, -- lead: small caps, as GridA.dc.html:73
            outline_width = 0, -- lead: small caps, as GridA.dc.html:73
            not_started_fill_color = false, -- lead: small caps, as GridA.dc.html:73
        },
        books = { row_gap = 0 }, -- lead: by analogy with SeriesBooksC.dc.html:32, ruled rows
        book = {
            padding = { x = 0 }, -- lead: by analogy with SeriesBooksC.dc.html:33
            bar_height = 4, -- GridA.dc.html:46's strip
            bar_outline_width = 0, -- GridA.dc.html:46's strip
            badge_size = 24, -- lead: GridA.dc.html:66 scaled to the cover
            badge_outline_width = 1, -- lead: GridA.dc.html:66 scaled to the cover
            badge_inset = 6, -- lead: GridA.dc.html:66 scaled to the cover, inside the corner
        },
        next = { text_color = "ink" }, -- lead: Editorial marks by type, AuthorBooksA.dc.html:52
        groups = {
            padding_top = 22, -- lead: by analogy with AuthorsC.dc.html:27
            gap = 0, -- lead: by analogy with AuthorsC.dc.html:27, ruled groups
        },
        group = {
            outline_width = 0, -- lead: ruled groups, by analogy with AuthorsC.dc.html:28
            rule_width = 1, -- lead: ruled groups, by analogy with AuthorsC.dc.html:28
            rule_color = "hairline", -- lead: ruled groups, by analogy with AuthorsC.dc.html:28
            letter_rule_width = 0, -- lead: by analogy with AuthorsC.dc.html:29, no rule
        },
        author = { rule_width = 1 }, -- lead: Editorial's row rules, by analogy with AuthorsC.dc.html:31
        author_grid = { cover_h = 198 }, -- D14: board 206 (AuthorBooksA.dc.html:32), so two rows fit
        up_next = { outline_width = 0 }, -- lead: as the Not downloaded chip had it (cover-grid D13)
    },
}
