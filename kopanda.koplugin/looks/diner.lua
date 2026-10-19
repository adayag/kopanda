-- Diner: a heavy grotesque, ink outlines, hard shadows and flat accent fills. Pure data, typed
-- from the direction doc (.tiller/design/2026-10-13-kopanda-ui-direction.md, "The two looks",
-- the night palettes, "Greys for the Paperwhite"); where the doc leaves a value out, the line's
-- comment names where it comes from. It declares only what differs from the base look
-- (looks/base.lua), which holds every other token.
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
            teal = "#b0b0b0", -- the doc's tiles in the canvas's tile order: teal (PWRetro.dc.html)
            pink = "#e0e0e0", -- pink
            mustard = "#c8c8c8", -- mustard
            band = "#9a9a9a",
            outline = "#111111", -- implied: strokes are ink
            shadow = "#111111", -- implied: hard shadows are ink
            on_band = "#111111", -- PWRetro.dc.html:19: ink on the grey band
            on_accent = "#111111", -- ink on the grey tiles (PWRetro.dc.html:19)
            on_cover = "#f4f4f4", -- PWRetro.dc.html:28
        },
    },

    stroke = { hairline = false, hairline_grey = false, rule = false, band = 4 }, -- band edges

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide; Diner's
    -- are fills.
    shadow = {
        -- The doc: 4–8 px, pink under the cover; 6 from the canvas.
        cover = { color = "pink" },
        tile = { x = 4, y = 4, color = "shadow" }, -- 4 from the canvas (HomeRetro.dc.html)
        sheet = { x = 8 },
    },

    -- A 14 px outlined bar with a mustard fill; in grey a 135° hatch of ink on paper.
    progress = { fill_color = "mustard" },

    -- An outlined box with an 8 px ink shadow and a coloured header band; the band's colour is a
    -- token per sheet, below (pink on the book's, mustard on the home's in the canvas).
    sheet = {
        inset = { side = 22, bottom = 22 }, -- HoldBookC.dc.html:30
        padding = { bottom = 0 }, -- HoldBookC.dc.html:30
        book_band_color = "pink", -- HoldBookC.dc.html:31
        home_band_color = "mustard", -- HoldHomeC.dc.html:31
        folder_band_color = "teal", -- no board draws Diner's folder sheet
        -- No board: the nav bar's band, the Settings tab the sheet rises from (nav.fill_color)
        quick_settings_band_color = "band",
        header_rule_width = 3, -- HoldBookC.dc.html:31
        header_padding = { top = 16 }, -- HoldHomeC.dc.html:31
        book_header_padding = { bottom = 18 }, -- HoldBookC.dc.html:31
        cover_w = 60, -- HoldBookC.dc.html:32
        cover_h = 90, -- HoldBookC.dc.html:32
        line_gap = 3, -- HoldBookC.dc.html:33
        row_padding = { y = 15 }, -- HoldBookC.dc.html:39
        row_rule_color = "outline", -- HoldBookC.dc.html:39
        last_row_bottom = 15, -- HoldBookC.dc.html:65
        status_chip_color = "mustard", -- the read status (HoldBookC.dc.html:52)
        state_chip_color = "teal", -- the Wi-Fi state (HoldHomeC.dc.html:55)
        chip_padding = { y = 2 }, -- HoldBookC.dc.html:52
        -- The sort and status sheets (cover-grid "The pickers"); SortC.dc.html's heading 28 and row
        -- padding 16 are not taken, so the other sheets keep their sizes.
        selected_fill_color = "teal", -- the current choice's row (SortC.dc.html:45)
        -- The library's folder sheet (context-menu D11): its band, and the box its folder icon sits in
        -- as the header's cover, the icon tinted (TintedIcon) so night's paper doesn't hide it.
        library_folder_band_color = "pink", -- HoldFolderC.dc.html:35
        -- The library's empty-space sheet (context-menu D10) and its hidden-folders sub-sheet (D17):
        -- the band, and the sort and show chips (a chip on paper sets its text in sheet_chip_plain).
        library_empty_band_color = "mustard", -- HoldEmptyC.dc.html:35
        show_chip_color = "pink", -- HoldEmptyC.dc.html:54
    },

    -- The quick-settings sheet's body. No board draws Diner's: its own sheet's rows and rules, its
    -- progress bar for the levels, its chips' 2 px outline for the buttons and tiles, the on tile
    -- an ink fill with paper text (the direction doc's "The two looks"); the rest Editorial's
    -- (QuickSettings.dc.html).
    quick_settings = {
        section_rule_color = "outline", -- the sheet's row_rule_color
        level_fill_color = "mustard", -- progress.fill_color
        on_text_color = "paper", -- with paper text
    },

    -- An outlined box on an accent.
    chip = { fill_color = "pink" }, -- the canvas's "Now reading" chip (HomeRetro.dc.html)

    -- 11 px uppercase, 800, 0.1 em tracking.
    label = { face = "display" },

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
        margin = { top = 0, bottom = 0 },
        row_gap = 14, -- the strip's and the launcher's top padding (HomeRetro.dc.html:47, :55; was 22)
        column_gap = 14, -- the launcher grid's gap (HomeRetro.dc.html:55)
        free_space = "before_footer", -- the stripe's margin-top: auto (HomeRetro.dc.html:82)
        -- A full-width band holding row 1, padded, over a 4 px ink edge (HomeRetro.dc.html:19).
        header = {
            band_color = "band",
            edge_width = 4,
            edge_color = "ink",
            padding = { top = 22, side = 40, bottom = 17 }, -- was 36, 40, 28
        },
        -- HomeRetro.dc.html:82 draws 22 px of 2 px ink lines every 10 px on paper under a 4 px
        -- ink edge; the bar always shows on the home and NavBarC.dc.html:70 draws no stripe above
        -- it, so the stripe has no height (was 22).
        footer = {
            stripe_color = "ink",
            gap_color = "paper",
            line_width = 2,
            line_pitch = 10,
            edge_width = 4,
            edge_color = "ink",
        },
        -- The weather's sun or moon before its line, and the gap after it (HomeRetro.dc.html:48-49).
        weather_icon = { size = 20, gap = 8 },
        -- The date's lines: 1, "Tuesday, October 13" (HomeRetro.dc.html:22), or 2, the weekday over
        -- the month and day.
        date_lines = 1,
    },

    -- The home widgets' text, per part: a face role, a size in board pixels (before text_size),
    -- case, tracking in em, line height as KOReader's TextBoxWidget counts it (extra space in
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role.
    type = {
        -- Not drawn: Diner's date is one line. The look's label style, on the band.
        date_label = { face = "display", color = "on_band" },
        -- The date on the band (HomeRetro.dc.html:22).
        date = { size = 16, uppercase = true, tracking = 0.04, line_height = 0, color = "on_band" },
        -- The clock on the band, CSS line height 0.9 (HomeRetro.dc.html:24).
        clock = { size = 56, line_height = -0.1, color = "on_band" },
        -- The strip's weather (HomeRetro.dc.html:47).
        weather = { face = "strong", size = 13, uppercase = true, tracking = 0.06, color = "ink" },
        -- No board draws Diner's quote; the quote face at Editorial's size and line height.
        quote = { line_height = 0.4 },
        -- The strip's reading stats (HomeRetro.dc.html:47).
        stats = { size = 13, tracking = 0.06, color = "ink" },
        -- The typographic cover's title, CSS line height 1.05 (HomeRetro.dc.html:29). The board's
        -- Georgia is not a Diner face, so the display face stands in.
        cover_title = { size = 22 },
        -- Its authors at the foot (HomeRetro.dc.html:30).
        cover_authors = { face = "text" },
        -- "No book yet" in the first run's dashed frame. No board draws Diner's first run; Editorial's
        -- line (EmptyStates.dc.html:33) in Diner's strong face.
        cover_empty = { size = 12 },
        -- "Now reading" in its chip, in chip.text_color (HomeRetro.dc.html:34).
        featured_label = { face = "display" },
        -- The featured book's title, two lines at most, CSS line height 1.05 (HomeRetro.dc.html:35).
        featured_title = { line_height = 0.05 },
        -- "authors · chapter" (HomeRetro.dc.html:36).
        featured_authors = { size = 15, color = "muted" },
        -- Not drawn on its own: Diner's chapter joins the authors line (HomeRetro.dc.html:36), in its style.
        featured_chapter = { size = 15, color = "muted" },
        -- "62% · 2 h 10 min left" under the bar (HomeRetro.dc.html:41).
        featured_caption = { size = 13, color = "ink" },
        -- No board draws Diner's first run; Editorial's sizes and line heights
        -- (EmptyStates.dc.html:36-38) in Diner's faces, the body in muted as its authors line.
        featured_empty_title = { line_height = 0.15 },
        featured_empty_body = { size = 15, color = "muted" },
        -- A launcher tile's label (HomeRetro.dc.html:56, weight 800).
        launcher_label = { face = "display", size = 14, line_height = 0 },
        -- Its suffix, "off" or "plugin missing": no board; the look's label style (label above).
        launcher_suffix = { face = "display" },
        -- A sheet's heading on its band, "Home" (HoldHomeC.dc.html:32).
        sheet_heading = { size = 24, line_height = 0 },
        -- The heading's aside, "KoPanda" (HoldHomeC.dc.html:33).
        sheet_aside = { face = "accent", size = 22, uppercase = false, tracking = 0, color = "on_accent" },
        -- Its author (HoldBookC.dc.html:35).
        sheet_author = { size = 14 },
        -- Its meta line, "62% · Part 3 · opened yesterday" (HoldBookC.dc.html:36).
        sheet_meta = { size = 12, uppercase = true, tracking = 0.08 },
        -- A sheet row's label (HoldBookC.dc.html:39).
        sheet_row = { face = "strong" },
        -- A row's plain detail, the weather's age (HoldHomeC.dc.html:48).
        sheet_detail = { size = 12, tracking = 0.08 },
        -- A row's detail in its chip, the read status (HoldBookC.dc.html:52).
        sheet_chip = { face = "display", tracking = 0.08 },
        -- sheet_chip in ink, since on_accent is the night paper by night: a row's detail in its chip
        -- on paper, the sort's (HoldEmptyC.dc.html:47).
        sheet_chip_plain = { face = "display", tracking = 0.08 },
        -- The header's label at its right, "Library" (SortC.dc.html:43).
        sheet_label = { face = "display", tracking = 0.08, color = "on_accent" },
        -- A row's second line, "Last opened first", weight 500 in the board's ink (SortC.dc.html:48).
        sheet_sublabel = { size = 12, color = "ink" },
        -- A quick-settings bar's label and value; no board: sheet_detail's style.
        quick_label = { size = 12, tracking = 0.08 },
        -- A quick-settings tile's label; no board: sheet_chip's style.
        quick_cell = { face = "display", tracking = 0.08 },
        -- The editor screens have no Diner board: the direction doc's vocabulary ("The two looks"),
        -- the header's aside and title on the band as the home's date and clock are (HomeRetro.dc.html:22-24),
        -- the rest in the look's label style and Editorial's sizes.
        -- no board: Editorial's line height, so the default layout's five rows fit above the foot
        editor_aside = { color = "on_band" },
        -- no board: Editorial's line height
        editor_title = { size = 30, color = "on_band" },
        -- no board: Editorial's line height
        editor_button = { face = "display", tracking = 0.1 },
        -- no board: Editorial's line height
        editor_caption = { tracking = 0.1 },
        -- no board: Editorial's line height
        editor_kind = { tracking = 0.08 },
        -- A nav tab's label (NavBarC.dc.html:75, weight 700).
        nav_label = { size = 12, tracking = 0.04, color = "ink" },
        -- The active tab's label on its mustard block (NavBarC.dc.html:71, weight 800), in the dark
        -- text the look puts on mustard, so the night block keeps dark text.
        nav_label_active = { face = "display", size = 12, tracking = 0.04, color = "on_accent" },
        -- The file browser's book count over its title, in Caveat at its default weight
        -- (LibraryC.dc.html:21; CSS line height 1), in the band's dark text.
        title_bar_count = { face = "accent", size = 24, uppercase = false, tracking = 0, color = "on_accent" },
        -- Its title (LibraryC.dc.html:22, weight 800); CSS line height 0.95, as the clock's -0.1 for 0.9.
        title_bar_title = { size = 40, tracking = -0.01, color = "on_accent" },
        -- The sort chip's label, ink on paper (LibraryC.dc.html:25, weight 800).
        title_bar_sort = { face = "display", tracking = 0.08 },
        -- The status chip's label on pink (LibraryC.dc.html:26, weight 800), the dark text on accents.
        title_bar_status = { face = "display", tracking = 0.08, color = "on_accent" },
        -- The library's parts (Main.dc.html under .tiller/design/2026-10-16-kopanda-library-screens/).
        -- The count over the title, in Caveat, CSS line height 1, in the band's dark text (Main.dc.html:21).
        library_count = { face = "accent", size = 24, uppercase = false, tracking = 0, color = "on_accent" },
        -- The title (Main.dc.html:22, weight 800); CSS line height 0.95, as the clock's -0.1 for 0.9.
        library_title = { size = 40, tracking = -0.01, color = "on_accent" },
        -- A picker's label, ink on the paper chip (Main.dc.html:25, weight 800).
        library_picker = { face = "display", tracking = 0.08 },
        -- The status picker's label on its pink chip (Main.dc.html:26), the dark text on accents.
        library_picker_status = { face = "display", tracking = 0.08, color = "on_accent" },
        -- A tile's title, one line, CSS line height 1.2 (Main.dc.html:47, weight 800).
        tile_title = { face = "display", uppercase = true, tracking = 0.04 },
        -- The placeholder's title at the grid's size, CSS line height 1.1 (Main.dc.html:51). The board's
        -- Georgia is not a Diner face, so the display face stands in, as in cover_title.
        tile_cover_title = { size = 17 },
        -- A folder's book count on its pink box, in Caveat, CSS line height 1 (Main.dc.html:35).
        folder_count = { face = "accent", size = 26, line_height = 0, color = "on_accent" },
        -- Its reading count (Main.dc.html:36, weight 800).
        folder_reading = { face = "display", color = "on_accent" },
        -- "Page 1 of 24" between the pager's boxes (Main.dc.html:87, weight 800).
        pager_label = { face = "display", size = 12 },
        -- The series and authors screens' parts (SeriesC.dc.html, SeriesBooksC.dc.html and
        -- AuthorsC.dc.html under .tiller/design/2026-10-16-kopanda-library-screens/); weight 700 is the
        -- strong face and 800 the display face. Text on the mustard, pink and teal fills is on_accent.
        -- One series' title on its band, CSS line height 0.95 (SeriesBooksC.dc.html:27, weight 800).
        shelf_detail_title = { tracking = -0.01, color = "on_accent" },
        -- The back control's label, ink on its paper box (SeriesBooksC.dc.html:20, weight 800).
        shelf_back = { face = "display" },
        -- Its sub-line (SeriesC.dc.html:36, weight 500).
        series_sub = { color = "ink" },
        -- A chip's label on its mustard, teal or pink fill (SeriesC.dc.html:39, weight 800).
        shelf_chip = { face = "display" },
        -- A chip's label on its paper fill (SeriesC.dc.html:88, weight 800).
        shelf_chip_plain = { face = "display" },
        -- Its title, CSS line height 1.1 (SeriesBooksC.dc.html:37, weight 800).
        book_row_title = { size = 20 },
        -- "read this one next" in Caveat on the mustard row, CSS line height 1 (SeriesBooksC.dc.html:47).
        book_next_note = { face = "accent", size = 22, uppercase = false, tracking = 0 },
        -- "Not on the Kindle yet" (SeriesBooksC.dc.html:60, weight 500).
        book_row_note = { color = "ink" },
        -- A group's letter on its mustard column (AuthorsC.dc.html:29, weight 800).
        author_letter = { size = 24 },
        -- Their count, "4 books ›" (AuthorsC.dc.html:33, weight 800).
        author_count = { face = "display", tracking = 0.08, color = "ink" },
        -- The empty note, as the library's (pager_label, Main.dc.html:87).
        shelf_empty = { face = "display", color = "ink" },
        -- The header's static label on the band, "Under way first" (SeriesC.dc.html:24, AuthorsC.dc.html:24).
        shelf_label = { face = "display", tracking = 0.08, color = "on_accent" },
    },

    -- The launcher: a grid of outlined tiles with the tile shadow, the first three on accents.
    launcher = {
        column_gap = 14, -- HomeRetro.dc.html:55
        row_gap = 9, -- HomeRetro.dc.html:55; was 14, tightened with the home (home above)
        icon_size = 28, -- HomeRetro.dc.html:57
        padding = { x = 14, y = 12 }, -- HomeRetro.dc.html:56
        tile_height = 104, -- HomeRetro.dc.html:56
        accent_1_color = "mustard", -- HomeRetro.dc.html:56
        accent_2_color = "pink", -- HomeRetro.dc.html:60
        accent_3_color = "teal", -- HomeRetro.dc.html:64
        suffix_below = true, -- no board: "Terminal PLUGIN MISSING" doesn't fit a third on one line
    },

    -- The featured book's cover box.
    featured = {
        cover_w = 140, -- HomeRetro.dc.html:28
        cover_h = 210, -- HomeRetro.dc.html:28
        cover_padding = { x = 12, y = 16 }, -- the placeholder's padding (HomeRetro.dc.html:28)
        gap = 20, -- between the cover and the text column (HomeRetro.dc.html:27)
        column_padding_y = 6, -- the text column's padding (HomeRetro.dc.html:32)
        chip_padding = { x = 10, y = 3 }, -- HomeRetro.dc.html:34
        button_fill_color = "mustard",
    },

    -- The editor screens, edit layout and launcher management. No board draws Diner's: the
    -- direction doc's vocabulary ("The two looks"), a teal header band, 3 px ink outlines, hard
    -- 2 px shadows on cards (card_shadow) and a flat mustard fill for the selected card; spacing as
    -- Editorial's boards give it.
    editor = {
        header_band_color = "band", -- no board: the home's teal header band (HomeRetro.dc.html)
        header_text_color = "on_band", -- no board: the band's text (HomeRetro.dc.html:19)
        button_outline_width = 3, -- no board: stroke.outline
        card_shadow = { x = 2, y = 2, color = "shadow" }, -- owner: half the home tiles' 4, so the screens read lighter
        selected_fill_color = "mustard", -- no board: the doc's flat accent fills
        row_rule_color = "outline", -- no board: the doc's ink strokes
    },

    -- The nav bar: a teal band under a 4 px ink edge, five tabs of an icon over an uppercase label
    -- split by outline dividers, and the active tab a mustard block (NavBarC.dc.html:70-89).
    nav = {
        fill_color = "band", -- NavBarC.dc.html:70
        edge_width = 4, -- NavBarC.dc.html:70, as the header's edge (home.header.edge_width)
        padding_top = 14, -- a tab's (NavBarC.dc.html:71)
        padding_bottom = 16, -- NavBarC.dc.html:71
        icon_size = 28, -- NavBarC.dc.html:72
        icon_gap = 6, -- the icon to the label (NavBarC.dc.html:71)
        icon_color = "ink", -- the page's ink, inherited (NavBarC.dc.html:14, :17)
        active_icon_color = "on_accent", -- the dark text on the mustard block, ink by day (NavBarC.dc.html:71)
        active_fill_color = "mustard", -- NavBarC.dc.html:71
        divider_width = 3, -- NavBarC.dc.html:71, :75, :79, :83; none on the last tab (:87)
        divider_color = "outline", -- the doc: strokes are ink (NavBarC.dc.html:71)
    },

    -- The file browser's title bar: a mustard band over a 4 px ink edge, a handwritten count over the
    -- title, and the pickers as outlined chips, sort on paper and status on pink (LibraryC.dc.html:19-27).
    title_bar = {
        fill_color = "mustard", -- LibraryC.dc.html:19
        padding = { top = 30, bottom = 20 }, -- LibraryC.dc.html:19
        edge_width = 4, -- LibraryC.dc.html:19
        edge_color = "ink", -- LibraryC.dc.html:19
        line_gap = 2, -- the count to the title (LibraryC.dc.html:20)
        picker_gap = 10, -- LibraryC.dc.html:24
        status_fill_color = "pink", -- LibraryC.dc.html:26
        picker_padding = { y = 4 }, -- LibraryC.dc.html:25
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
            padding = { top = 28, bottom = 18 }, -- Main.dc.html:19
            edge_width = 4, -- Main.dc.html:19
            edge_color = "ink", -- Main.dc.html:19
            line_gap = 2, -- the count to the title (Main.dc.html:20)
            picker_gap = 10, -- Main.dc.html:24
            picker_padding = { y = 4 }, -- Main.dc.html:25
            status_fill_color = "pink", -- Main.dc.html:26
        },
        grid = {
            padding_top = 22, -- Main.dc.html:30
            column_gap = 22, -- Main.dc.html:30
        },
        cover = {
            shadow = { x = 5, y = 5 }, -- Main.dc.html:43
            padding = { y = 14 }, -- the placeholder's (Main.dc.html:43)
        },
        strip = { height = 14 }, -- its outline included (Main.dc.html:46, box-sizing: border-box)
        folder = {
            fill_color = "pink", -- Main.dc.html:32
            icon_size = 44, -- Main.dc.html:33
            icon_color = "on_accent", -- the board's ink on pink (Main.dc.html:33), dark by night too
            padding = { x = 12 }, -- Main.dc.html:32
        },
        badge = {
            size = 38, -- Main.dc.html:66
            outline_width = 3, -- Main.dc.html:66
            inset = -12, -- overhanging the corner (Main.dc.html:66, right: -12px; top: -12px)
        },
        -- The board's Not downloaded chip, gone (tweaks/badge-only-not-downloaded); its padding and
        -- outline colour stay as the one-author grid's Up next chip on the cover (series-and-authors D5).
        not_downloaded = { padding = { x = 6, y = 1 } }, -- Main.dc.html:73
        pager = {
            next_fill_color = "mustard", -- Main.dc.html:88
            next_icon_color = "on_accent", -- on the mustard box, dark by night too (Main.dc.html:88)
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
        detail = { padding = { top = 22, bottom = 18 } }, -- SeriesBooksC.dc.html:19
        list = {
            padding_top = 22, -- SeriesC.dc.html:27
            row_gap = 14, -- SeriesC.dc.html:27
        },
        row = {
            shadow = { x = 4, y = 4 }, -- SeriesC.dc.html:28
            rule_color = "ink", -- SeriesC.dc.html:28, unused at rule_width 0
        },
        chip = {
            padding = { x = 7, y = 1 }, -- SeriesC.dc.html:39
            under_way_fill_color = "mustard", -- SeriesC.dc.html:39
            finished_fill_color = "teal", -- SeriesC.dc.html:76
            up_next_fill_color = "paper", -- SeriesBooksC.dc.html:49
        },
        book = {
            cover_outline_width = 2, -- SeriesBooksC.dc.html:35
            bar_height = 10, -- the track inside the outline (SeriesBooksC.dc.html:38)
        },
        next = {
            fill_color = "mustard", -- SeriesBooksC.dc.html:42
            shadow = { x = 6, y = 6 }, -- SeriesBooksC.dc.html:42
        },
        groups = { padding_top = 22 }, -- AuthorsC.dc.html:27
        group = {
            shadow = { x = 4, y = 4 }, -- AuthorsC.dc.html:28
            rule_color = "ink", -- AuthorsC.dc.html:28, unused at rule_width 0
            letter_fill_color = "mustard", -- AuthorsC.dc.html:29
            letter_rule_width = 3, -- AuthorsC.dc.html:29
        },
        author = { rule_color = "outline" }, -- AuthorsC.dc.html:31
    },
}
