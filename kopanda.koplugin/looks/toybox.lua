-- Toybox: chunky toy blocks, rounded paper blocks standing on a solid ink edge, the colour kept to
-- round badges, and a floating pill nav. Pure data, typed from the design's token table and Lua
-- export (.tiller/design/2026-10-19-kopanda-looks/toybox.md) and its boards in the design file
-- (`KoPanda Looks.dc.html` beside it, cited "Looks.dc.html:<line>"); where neither gives a value,
-- the line's comment says "no board" and names the analogy. It declares only what differs from
-- the base look (looks/base.lua), which holds every other token.
return {
    -- toybox.md: Baloo 2 800, Nunito 700 and 800, Nunito 600 italic for the quote, no accent face.
    faces = {
        display = { file = "fonts/baloo-2/Baloo2-ExtraBold.ttf", label = "Baloo 2 800" }, -- toybox.md
        text = { file = "fonts/nunito/Nunito-Bold.ttf", label = "Nunito 700" }, -- toybox.md: text 700
        strong = { file = "fonts/nunito/Nunito-ExtraBold.ttf", label = "Nunito 800" }, -- toybox.md: bold 800
        quote = { file = "fonts/nunito/Nunito-SemiBoldItalic.ttf", label = "Nunito 600 italic" }, -- toybox.md
    },

    icons = { set = "mingcute-line" }, -- toybox.md: MingCute Line, chosen first

    -- toybox.md's export palettes: its hairLight is hairline_light, its a1, a2 and a3 the sun,
    -- coral and mint, its die the nav pill's white. Structure and the block edge are the ink, so
    -- outline, shadow, on_band and on_accent are the ink, and the band is the mint (the sheet's
    -- header band, toybox.md "Band"). Its card is its paper by day and in grey; the night card
    -- (#24232e) has no part here that draws it.
    palettes = {
        day = {
            paper = "#fbf5ec", -- toybox.md
            ink = "#2b2934", -- toybox.md
            muted = "#5b5867", -- toybox.md
            text = "#2b2934", -- toybox.md: text is the ink
            hairline_light = "#e7ddcd", -- toybox.md: the sheet's row rules
            sun = "#ffc94a", -- toybox.md: a1
            coral = "#ff8f75", -- toybox.md: a2
            mint = "#86d3b4", -- toybox.md: a3
            die = "#ffffff", -- toybox.md: the floating nav's white
            band = "#86d3b4", -- toybox.md: the mint band on the sheet
            outline = "#2b2934", -- toybox.md: 3 px ink blocks
            shadow = "#2b2934", -- toybox.md: the solid ink edge
            on_band = "#2b2934", -- no board: the ink on the mint band (Looks.dc.html:724)
            on_accent = "#2b2934", -- toybox.md: chips are ink on mint
            -- No board draws a typographic cover: a solid block of the ink, paper text on it.
            cover = "#2b2934",
            on_cover = "#fbf5ec", -- no board: the paper, as above
        },
        night = {
            paper = "#1e1d26", -- toybox.md
            ink = "#f4f0ea", -- toybox.md
            muted = "#b4b1c0", -- toybox.md
            text = "#f4f0ea", -- toybox.md
            hairline_light = "#383645", -- toybox.md
            sun = "#8a6a12", -- toybox.md
            coral = "#a2493a", -- toybox.md
            mint = "#2f7a5c", -- toybox.md
            die = "#282733", -- toybox.md
            band = "#2f7a5c", -- toybox.md: the mint
            outline = "#f4f0ea", -- toybox.md: structure is the ink
            shadow = "#f4f0ea", -- toybox.md: the edge is the ink
            on_band = "#f4f0ea", -- no board: the night ink on the night mint
            on_accent = "#f4f0ea", -- no board: the night ink on the night mint
            cover = "#2b2934", -- no board: the day's ink block, as Diner keeps its cover by night
            on_cover = "#fbf5ec", -- no board: the day's paper on it
        },
        grey = {
            hairline_light = "#cccccc", -- toybox.md
            sun = "#dddddd", -- toybox.md
            coral = "#999999", -- toybox.md: a2, hatched where it fills a bar (progress.fill_grey)
            mint = "#bbbbbb", -- toybox.md
            band = "#bbbbbb", -- toybox.md: the mint
            shadow = "#000000", -- toybox.md: the edge is the ink
            on_band = "#000000", -- no board: the ink on the grey mint
        },
    },

    -- toybox.md: 3 px ink blocks, cover, progress and nav, 2 px hairlines.
    stroke = {
        hairline = 2, -- toybox.md: stroke.hair
        rule = 3, -- toybox.md: stroke.rule
    },

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide. toybox.md:
    -- a solid block edge, ink 0 right 6 down under the tiles and the cover, 8 under the sheet.
    shadow = {
        cover = { x = 0 }, -- toybox.md: cover.shadow
        tile = { y = 6, color = "shadow" }, -- toybox.md: tile.edge 6
    },

    radius = {
        cover = 6, -- toybox.md: cover.radius
        box = 18, -- toybox.md: tile.radius, the launcher's blocks
    },

    -- toybox.md: an 18 px pill in a 3 px ink outline, coral on paper; in grey a 135° hatch.
    progress = {
        -- The 18 px pill less its 3 px outline above and below: the board's bar is border-box
        -- (Looks.dc.html:664).
        height = 12,
        fill_color = "coral", -- toybox.md: progress.fill a2
        outline_width = 3, -- toybox.md: progress.outline
        radius = 999, -- toybox.md: progress.radius, round ends
    },

    -- toybox.md: inset 16, a 3 px ink outline rounded 24 on an 8 px ink edge (shadow.sheet), a mint
    -- header band under a 2 px ink rule, rows ruled in the hairline.
    sheet = {
        -- Looks.dc.html:720, the head spanning the box (:724). The board's foot is 8; 10 ends a lit
        -- last row's fill 13 px above the box's foot, inside the 24 px corners' outer curve (12.4 at
        -- the 3 px outline), so no sun shows in their ring.
        padding = { bottom = 10 },
        book_band_color = "mint", -- toybox.md: sheet.band a3
        home_band_color = "mint", -- no board: the book sheet's band
        folder_band_color = "mint", -- no board: the book sheet's band
        quick_settings_band_color = "mint", -- no board: the book sheet's band
        status_chip_color = "mint", -- toybox.md: chips are a mint fill
        state_chip_color = "mint", -- toybox.md: chips are a mint fill
        chip_padding = { x = 11 }, -- Looks.dc.html:659, a round chip's padding
        selected_fill_color = "sun", -- no board: the lit nav tab's sun (toybox.md nav.litColor a1)
        library_folder_band_color = "mint", -- no board: the book sheet's band
        folder_box = { outline_width = 3 }, -- no board: the block's 3 px ink outline (toybox.md)
        library_empty_band_color = "mint", -- no board: the book sheet's band
        sort_chip_color = "mint", -- no board: toybox.md's chips are a mint fill
        show_chip_color = "mint", -- no board: toybox.md's chips are a mint fill
        radius = 24, -- toybox.md: sheet.radius
    },

    -- The quick-settings sheet's body. No board draws Toybox's: the sheet's rows and hairline
    -- rules, its progress pill for the levels, the pickers' 2 px ink outline for the buttons, the
    -- block's 3 px ink outline for the tiles, and the on tile filled sun with ink text as the lit
    -- nav tab; the rest Diner's and Editorial's.
    quick_settings = {
        level_h = 12, -- no board: progress.height
        level_outline_width = 3, -- no board: progress.outline_width
        level_fill_color = "coral", -- no board: progress.fill_color
        cell_outline_width = 3, -- no board: the block's outline
        on_fill_color = "sun", -- no board: the lit nav tab's fill (toybox.md nav.litColor a1)
    },

    -- toybox.md: a mint pill, ink uppercase 800, a 2 px ink border.
    chip = {
        fill_color = "mint", -- toybox.md: chip.fill a3
        radius = 999, -- toybox.md: chip.radius, a pill
    },

    -- The home's page (Looks.dc.html:607, :641-697): its margins, the gaps between rows and between
    -- columns, where the free height goes, the header drawn with row 1 and the footer.
    home = {
        -- The body's padding, 36 above and 40 at the sides (Looks.dc.html:607); below, the 98 px
        -- the board leaves above its foot less the floating nav's 68 and the 20 under it, so the
        -- rows stop 10 above the pill.
        margin = { top = 36, bottom = 10 },
        row_gap = 18, -- toybox.md: bodyGap 18 (Looks.dc.html:550, :607)
        -- The date's lines: 1, toybox.md's 18 px 800 date, "Tuesday, October 13" (Looks.dc.html:56, :651).
        date_lines = 1,
    },

    -- The home widgets' text, per part: a face role, a size in board pixels (before text_size),
    -- case, tracking in em, line height as KOReader's TextBoxWidget counts it (extra space in
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role. The
    -- board's 700 is the text face, its 800 the strong face; its 500 and 600 the text face too,
    -- the lightest Nunito vendored.
    type = {
        -- toybox.md: 100 px 800, -0.02 em, CSS line height 0.8 (Looks.dc.html:653).
        clock = { size = 100 },
        stats = { tracking = 0.1 },
        cover_authors = { tracking = 0.1 },
        -- toybox.md: the title 36 px 800, -0.01 em, CSS line height 1.04 (Looks.dc.html:660).
        featured_title = { size = 36, tracking = -0.01 },
        -- 14 px, weight 600, the text colour (Looks.dc.html:666).
        featured_caption = { face = "text" },
        -- No board draws Toybox's first run: the title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = { size = 31, tracking = -0.01 },
        -- no board: the look's label in ink, as the chip's
        featured_button = { tracking = 0.1 },
        -- toybox.md: launcher 19 px Nunito 700, CSS line height 1.1 (Looks.dc.html:683).
        launcher_label = { face = "text" },
        -- The title 0.72 of 36 px, CSS line height 1.05 (Looks.dc.html:728).
        sheet_title = { size = 26 },
        sheet_meta = { face = "text" },
        -- toybox.md: sheet rows 18 px Nunito, ink (Looks.dc.html:735).
        sheet_row = { size = 18 },
        quick_label = { tracking = 0.1 },
        -- no board: the look's label in ink
        editor_button = { tracking = 0.1 },
        editor_caption = { tracking = 0.1 },
        -- no board: Diner's and Editorial's
        editor_box = { face = "text" },
        -- no board: Diner's and Editorial's
        editor_share = { face = "text" },
        -- no board: Diner's and Editorial's, so six rows fit above the add-an-entry foot
        editor_label = { face = "text" },
        -- toybox.md: nav labels 11 px, the look's label, muted unlit (Looks.dc.html:620, :622).
        nav_label = { tracking = 0.1 },
        -- The lit tab's label in ink, 800 (Looks.dc.html:622).
        nav_label_active = { tracking = 0.1 },
        -- No board draws Toybox's file browser: the library's (Looks.dc.html:744-749).
        -- The book count, the look's label (Looks.dc.html:747).
        title_bar_count = { tracking = 0.1 },
        -- The library's title, 36 px, -0.01 em, CSS line height 0.95 (Looks.dc.html:746).
        title_bar_title = { size = 36, tracking = -0.01 },
        title_bar_sort = { face = "text", tracking = 0.1 },
        title_bar_status = { face = "text", tracking = 0.1 },
        -- The library's parts (Looks.dc.html:744-790). The count, the look's label (:747).
        library_count = { tracking = 0.1 },
        -- The title, 36 px, -0.01 em, CSS line height 0.95 (Looks.dc.html:746).
        library_title = { size = 36, tracking = -0.01 },
        library_picker = { face = "text", tracking = 0.1 },
        library_picker_status = { face = "text", tracking = 0.1 },
        -- no board: a tile's title, one line, the text face at Diner's size and line height
        tile_title = { face = "text" },
        folder_count = { face = "text" },
        folder_reading = { tracking = 0.1 },
        pager_label = { tracking = 0.1 },
        -- The series and authors screens have no Toybox board: the library's header and the home's
        -- blocks, by analogy.
        -- no board: the featured title's size, CSS line height 0.95 as the library's title
        shelf_detail_title = { tracking = -0.01 },
        -- no board: a picker's label in ink
        shelf_back = { face = "text", tracking = 0.1 },
        -- no board: the library folder's name (Looks.dc.html:766)
        series_name = { face = "text" },
        -- no board: a chip's label, ink on its mint
        shelf_chip = { tracking = 0.1 },
        shelf_chip_plain = { tracking = 0.1 },
        -- no board: the library folder's name (Looks.dc.html:766)
        book_row_title = { face = "text" },
        -- no board: "read this one next" in the look's label on the sun row; Toybox has no accent face
        book_next_note = { tracking = 0.1 },
        -- no board: Diner's
        author_name = { face = "text" },
        -- no board: the look's label
        author_count = { tracking = 0.1 },
        shelf_empty = { tracking = 0.1 },
        shelf_label = { tracking = 0.1 },
    },

    -- toybox.md: three columns of 84 px paper blocks, each with a 42 px round badge under its 22 px
    -- icon (Looks.dc.html:674-694). The board stacks the badge over the label; at KOReader's line
    -- heights the two overrun an 84 px block, so the label sits beside the badge.
    launcher = {
        row_gap = 16, -- toybox.md: tile.gap
        icon_gap = 10, -- no board: the badge to the label beside it, the board's text gap (Looks.dc.html:685)
        padding = { x = 11, y = 9 }, -- Looks.dc.html:694
        -- Under the label: "Terminal PLUGIN MISSING" doesn't fit beside a badge on one line.
        suffix_below = true,
        -- toybox.md: a 42 px round badge, a 2.5 px ink ring, filled sun, coral, mint, coral, mint,
        -- sun in tile order, then again (Looks.dc.html:544, :694).
        badge = {
            size = 42, -- Looks.dc.html:694
            outline_width = 2.5, -- Looks.dc.html:694
            outline_color = "outline", -- Looks.dc.html:694, ink
            fill_1_color = "sun", -- toybox.md: tile.fills a1
            fill_2_color = "coral", -- toybox.md: tile.fills a2
            fill_3_color = "mint", -- toybox.md: tile.fills a3
            fill_4_color = "coral", -- toybox.md: tile.fills a2
            fill_5_color = "mint", -- toybox.md: tile.fills a3
            fill_6_color = "sun", -- toybox.md: tile.fills a1
        },
    },

    -- toybox.md: quote.style plain, no rules and no tile (Looks.dc.html:668).
    quote = {
        padding = 0, -- Looks.dc.html:668, a plain quote's padding
        -- A rule colour sets the quote between rules, of no width here, rather than in a tile.
        rule_color = "hairline_light",
    },

    -- The featured book's cover box (toybox.md: 140 × 210, a 3 px ink outline, radius 6).
    featured = {
        cover_w = 140, -- toybox.md: cover.w
        cover_h = 210, -- toybox.md: cover.h
        button_fill_color = "sun", -- no board: the lit nav tab's sun, a block to press
    },

    -- The editor screens, edit layout and launcher management. No board draws Toybox's: the header
    -- on paper over a 3 px ink rule (no band, toybox.md: "mint band on the sheet only"), cards as
    -- the home's blocks in a 3 px ink outline on their ink edge, the selected card sun; spacing as
    -- Editorial's boards give it.
    editor = {
        card_gap = 12, -- no board: Diner's 10 and the block's 6 px edge less its 4, so the edge clears the next card
        card_shadow = { y = 6, color = "shadow" }, -- no board: the block's ink edge (shadow.tile)
        selected_fill_color = "sun", -- no board: the lit nav tab's sun
    },

    -- The nav bar: a white pill floating 22 px in from the sides and 20 up from the bottom, in a
    -- 3 px ink outline on a 6 px ink edge, five tabs of an icon over a label, the lit tab a sun pill
    -- in a 2 px ink outline, its icon and label ink and the rest muted (toybox.md; Looks.dc.html:608,
    -- :620).
    nav = {
        padding_x = 5, -- the pill's padding (Looks.dc.html:608), round the tabs on every side
        -- The pill's 68 px less its outline and padding, a lit tab's 2 px outline, the icon, the gap
        -- and the label line, shared above and below the tab's centred content (Looks.dc.html:608, :620).
        padding_top = 9,
        padding_bottom = 9, -- as padding_top
        icon_gap = 4, -- Looks.dc.html:620, a pill tab's gap
        active_fill_color = "sun", -- toybox.md: nav.lit pill, litColor a1
        float = true, -- toybox.md: nav.float, a floating pill
        margin = { side = 22, bottom = 20 }, -- Looks.dc.html:608
        radius = 999, -- toybox.md: nav.radius, the pill and its lit tab
        float_fill_color = "die", -- Looks.dc.html:608, the pill's white
        shadow = { y = 6, color = "shadow" }, -- toybox.md: nav.float 6, the ink edge
        tab_gap = 4, -- Looks.dc.html:608, the gap between tabs
        active_outline_width = 2, -- Looks.dc.html:620, the lit pill's ink border
        active_outline_color = "outline", -- Looks.dc.html:620, ink
    },

    -- The file browser's title bar. No board draws Toybox's: the library's header (Looks.dc.html:744-749),
    -- a count and a 36 px title on paper with no rule, the pickers 2 px ink pills on paper.
    title_bar = {
        picker_padding = { x = 12 }, -- no board: Looks.dc.html:749, 2 px wider for the round ends
        picker_radius = 999, -- no board: toybox.md's picker radius, a pill
    },

    -- The library (Looks.dc.html:740-790): a 36 px title and count on paper with no rule, the
    -- pickers 2 px ink pills on paper, three columns of covers rounded 6 in a 3 px ink outline on
    -- their ink edge, a coral pill strip under each, and a pager above the nav.
    library = {
        header = {
            picker_padding = { x = 12 }, -- Looks.dc.html:749, 2 px wider for the round ends
            picker_radius = 999, -- toybox.md: picker.radius
        },
        grid = { strip_gap = 14 }, -- the item's 8 px gap below the cover's 6 px edge (Looks.dc.html:752)
        -- The board's 2:3 covers fill their box (Looks.dc.html:750); at Diner's 195 a cover is fitted
        -- in its box on paper, so the box takes the cover's 3 px ink outline and its ink edge.
        cover = { radius = 6 }, -- toybox.md: cover.radius
        badge = { fill_color = "sun" }, -- no board: the launcher's first badge
        not_downloaded = { padding = { x = 11 } }, -- no board: the chip's padding (Looks.dc.html:659)
        pager = { next_fill_color = "sun" }, -- no board: the lit nav tab's sun
    },

    -- The series and authors screens. No board draws Toybox's: the library's header on paper, rows
    -- and groups as the home's blocks (3 px ink on paper on their ink edge), mint chips and letters,
    -- the up-next book on sun.
    shelf = {
        detail = { padding = { top = 36 } }, -- no board: the library header's
        row = { shadow = { y = 6 } }, -- no board: the block's ink edge (shadow.tile)
        chip = {
            under_way_fill_color = "mint", -- no board: toybox.md's chips are a mint fill
            finished_fill_color = "mint", -- no board: toybox.md's chips are a mint fill
            up_next_fill_color = "sun", -- no board: the lit nav tab's sun
        },
        book = { cover_outline_width = 3 }, -- no board: toybox.md's cover outline
        next = {
            fill_color = "sun", -- no board: the lit nav tab's sun
            shadow = { y = 6 }, -- no board: the block's ink edge
        },
        groups = { gap = 16 }, -- no board: the launcher's row gap
        group = {
            shadow = { y = 6 }, -- no board: the block's ink edge
            letter_fill_color = "mint", -- no board: toybox.md's mint fill
        },
        up_next = { fill_color = "sun" }, -- no board: the lit nav tab's sun
    },
}
