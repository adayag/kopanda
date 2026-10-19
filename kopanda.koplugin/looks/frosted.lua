-- Frosted Plates: the owner's wallpaper behind the home, every row on a plate washed toward paper
-- with a 2 px ink keyline, violet and yellow accents. Pure data, typed from the design's token
-- table and Lua export (.tiller/design/2026-10-19-kopanda-looks/frosted.md, and plates.md, which
-- it inherits) and its boards in the design file (`KoPanda Looks.dc.html` beside them, cited
-- "Looks.dc.html:<line>"); where neither gives a value, the line's comment says "no board" and
-- names the analogy. It declares only what differs from the base look (looks/base.lua), which
-- holds every other token.
return {
    -- frosted.md: Atkinson Hyperlegible 700 for display, 400 and 700 and italic for text, no accent face.
    faces = {
        display = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Bold.ttf", -- frosted.md
            label = "Atkinson Hyperlegible 700" }, -- frosted.md
        text = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Regular.ttf", -- frosted.md
            label = "Atkinson Hyperlegible 400" }, -- frosted.md
        strong = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Bold.ttf", -- frosted.md: text bold 700
            label = "Atkinson Hyperlegible 700" }, -- frosted.md
        quote = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Italic.ttf", -- frosted.md: quote italic
            label = "Atkinson Hyperlegible 400 italic" }, -- frosted.md
    },

    icons = { set = "phosphor-bold" }, -- frosted.md: Phosphor Bold, chosen first

    -- frosted.md's export palettes: its hairLight is hairline_light, its a1 the violet, its a2 the
    -- yellow. Structure is the ink, so outline, shadow and on_accent are the ink.
    palettes = {
        day = {
            paper = "#fbfaf6", -- frosted.md
            ink = "#1b1a1f", -- frosted.md
            muted = "#4d4b55", -- frosted.md
            text = "#1b1a1f", -- frosted.md: text is the ink
            hairline_light = "#d9d6df", -- frosted.md: sheet rows only
            violet = "#6b55c8", -- frosted.md: a1, the progress
            yellow = "#f2c230", -- frosted.md: a2, the chip and the lit tab
            outline = "#1b1a1f", -- frosted.md: keylines are ink
            shadow = "#1b1a1f", -- frosted.md: the sheet's shadow is ink
            on_accent = "#1b1a1f", -- frosted.md: chip.color ink, on the yellow
            -- No board draws a typographic cover: a solid violet block, paper text on it.
            cover = "#6b55c8",
            on_cover = "#fbfaf6", -- no board: the paper, as above
        },
        night = {
            paper = "#1d1c22", -- frosted.md
            ink = "#f3f1ec", -- frosted.md
            muted = "#b5b2bd", -- frosted.md
            text = "#f3f1ec", -- frosted.md
            hairline_light = "#3a3842", -- frosted.md
            violet = "#a593f2", -- frosted.md: a1
            yellow = "#8a6d10", -- frosted.md: a2
            outline = "#f3f1ec", -- frosted.md: structure is the ink
            shadow = "#f3f1ec", -- frosted.md: structure is the ink
            on_accent = "#f3f1ec", -- no board: the night ink on the night yellow
            cover = "#6b55c8", -- no board: the day's violet block, as Diner keeps its cover by night
            on_cover = "#fbfaf6", -- no board: the day's paper on it
        },
        grey = {
            hairline_light = "#bbbbbb", -- frosted.md
            -- frosted.md's a1 is #000000 under a hatch, which progress.fill_grey draws in ink; an
            -- unhatched violet fill takes the cover's grey, so violet stays apart from the ink.
            violet = "#4a4a4a",
            yellow = "#cccccc", -- frosted.md: a2
            shadow = "#000000", -- frosted.md: structure is the ink
        },
    },

    -- frosted.md: 1 px hairlines (2 in grey), 2 px ink keylines; the nav edge and the sheet's
    -- outline have their own tokens (nav.edge_width, sheet.outline_width).
    stroke = { outline = 2 }, -- frosted.md: 2 px ink keyline on every plate

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide. frosted.md:
    -- shadow none, but the sheet's ink 5/7.
    shadow = {
        cover = { x = 0, y = 0, color = false }, -- frosted.md: cover.shadow none
        sheet = { x = 5, y = 7 }, -- frosted.md: sheet only, ink 5/7
    },

    -- The plates every home row sits on (frosted.md "Tile", "Translucency"; Looks.dc.html:594-598,
    -- :698-705): a 2 px ink keyline at radius 12 over the wallpaper lightened toward paper, by day
    -- 0.82, at night 0.84 and in grey 0.85; with no wallpaper, filled paper. Row 1 is one header
    -- plate padded by home.header.padding; every other row's widgets each sit on their own plate,
    -- padded and rounded by slots. The launcher's tiles are plates themselves.
    plate = {
        fill_color = "paper", -- frosted.md: plate.fill paper
        keyline = 2, -- frosted.md: plate.border
        keyline_color = "ink", -- frosted.md: plate.borderColor
        radius = 12, -- frosted.md: plate.radius
        -- A named deviation (plate.lua): KOReader's lightenRect blends toward white, and at night
        -- the stored pixels toward black, not toward the paper frosted.md names (#fbfaf6 by day,
        -- #1d1c22 at night), so night plates show about 24 levels darker than the night paper.
        lighten = {
            day = 0.82, -- frosted.md: plate.lighten.day
            night = 0.84, -- frosted.md: plate.lighten.night
            grey = 0.85, -- frosted.md: plate.lighten.grey
        },
        slots = {
            -- no board puts the date or clock off the header: the header plate's padding (Looks.dc.html:700)
            date = { x = 18, y = 14, radius = 12 },
            clock = { x = 18, y = 14, radius = 12 }, -- no board: as the date
            -- no board puts the weather off the header: the stats' pill (Looks.dc.html:704)
            weather = { x = 14, y = 8, radius = 999 },
            stats = { x = 14, y = 8, radius = 999 }, -- Looks.dc.html:704, a pill
            quote = { x = 18, y = 12, radius = 12 }, -- Looks.dc.html:703
            featured = { x = 14, y = 14, radius = 12 }, -- Looks.dc.html:702
        },
    },

    -- The owner's image behind the home's rows (wallpaper.file), scaled to cover the screen.
    wallpaper = { enabled = true }, -- frosted.md: the wallpaper look

    -- frosted.md: a 12 px pill, 2 px ink outline, violet on paper; in grey a 135° hatch, as Diner's.
    progress = {
        height = 12, -- frosted.md: progress.h
        fill_color = "violet", -- frosted.md: progress.fill a1
        radius = 999, -- frosted.md: progress.radius 999, round ends
    },

    -- frosted.md: an opaque inset plate, 16 in, a 2 px ink outline, the ink shadow 5/7 behind it
    -- (shadow.sheet), no band, the head under a 2 px ink rule, rows ruled in the light hairline.
    sheet = {
        outline_width = 2, -- frosted.md: sheet.border 2
        header_band = false, -- frosted.md: sheet.band none
        row_rule_width = 1, -- Looks.dc.html:735, the look's hairline (stroke.hairline)
        status_chip_color = "yellow", -- no board: frosted.md's chip is yellow
        state_chip_color = "yellow", -- no board: frosted.md's chip is yellow
        chip_padding = { x = 11 }, -- Looks.dc.html:659, a rounded chip's padding
        selected_fill_color = "yellow", -- no board: the lit nav tab's yellow (frosted.md nav.litColor)
        show_chip_color = "yellow", -- no board: frosted.md's chip is yellow
        radius = 16, -- frosted.md: sheet.radius 16
    },

    -- The quick-settings sheet's body. No board draws Frosted's: the sheet's rows and light rules,
    -- its progress bar for the levels, the plates' 2 px ink keyline for the buttons and tiles, and
    -- the on tile filled yellow with ink text as the lit nav tab; the rest Diner's and Editorial's.
    quick_settings = {
        section_rule_width = 1, -- no board: the sheet's row_rule_width
        level_h = 12, -- no board: progress.height
        level_fill_color = "violet", -- no board: progress.fill_color
        on_fill_color = "yellow", -- no board: the lit nav tab's fill (frosted.md nav.litColor)
    },

    -- frosted.md: a yellow pill, ink uppercase 700, a 2 px ink border.
    chip = {
        fill_color = "yellow", -- frosted.md: chip.fill a2
        radius = 999, -- frosted.md: chip.radius 999, a pill
    },

    -- frosted.md: 11 px uppercase 700, 0.08 em, muted.
    label = { tracking = 0.08 }, -- frosted.md: label.tracking

    -- The home's page (Looks.dc.html:583, :607, :641-705): the wallpaper's margins, the gutters
    -- between plates, where the free height goes, the header plate and no footer.
    home = {
        -- The body's padding for a plate look: 26 above, 24 at the sides and 14 above the bar
        -- (Looks.dc.html:583, :607).
        margin = { top = 26, side = 24, bottom = 14 },
        row_gap = 12, -- frosted.md: 12 px gutters between plates (Looks.dc.html:444)
        column_gap = 12, -- frosted.md: 12 px gutters, the tiles' (Looks.dc.html:444)
        -- frosted.md: the header plate, no band and no rule; the date and weather left, the clock
        -- right, padded 14 by 18 inside the keyline (Looks.dc.html:700).
        header = { padding = { top = 14, side = 18, bottom = 14 } }, -- Looks.dc.html:700
    },

    -- The home widgets' text, per part: a face role, a size in board pixels (before text_size),
    -- case, tracking in em, line height as KOReader's TextBoxWidget counts it (extra space in
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role. The
    -- labels are the strong face, frosted.md's 700.
    type = {
        -- The weekday over the date, the look's label (Looks.dc.html:650).
        date_label = { tracking = 0.08 },
        -- frosted.md: 84 px 700, -0.03 em, CSS line height 0.8 (Looks.dc.html:653).
        clock = { size = 84, tracking = -0.03 },
        cover_authors = { tracking = 0.08 },
        cover_empty = { tracking = 0.08 },
        -- "Now reading" in its chip: the label, ink, 700 (Looks.dc.html:659).
        featured_label = { face = "strong", tracking = 0.08 },
        -- frosted.md: the title 32 px 700, -0.015 em, CSS line height 1.04 (Looks.dc.html:660).
        featured_title = { size = 32, tracking = -0.015 },
        -- No board draws Frosted's first run: the title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = { size = 27, tracking = -0.015 },
        -- no board: the look's label in ink, as the chip's
        featured_button = { tracking = 0.08 },
        -- Its suffix, "Off", the look's label (Looks.dc.html:694).
        launcher_suffix = { tracking = 0.08 },
        -- No board draws Frosted's home sheet: the book sheet's title (Looks.dc.html:728) in ink.
        sheet_heading = { size = 23, tracking = -0.015, color = "ink" },
        -- no board: the look's label (Looks.dc.html:733's last-opened line)
        sheet_aside = { tracking = 0.08 },
        -- The title 0.72 of 32 px, CSS line height 1.05 (Looks.dc.html:728).
        sheet_title = { size = 23, tracking = -0.015, color = "ink" },
        -- 15 px Atkinson in the text colour (Looks.dc.html:729).
        sheet_author = { color = "text" },
        sheet_meta = { color = "text" },
        -- frosted.md: sheet rows 18 px, weight 500 (Atkinson 400 here), ink (Looks.dc.html:735).
        sheet_row = { size = 18 },
        sheet_detail = { tracking = 0.08 },
        -- frosted.md: a chip's label, ink on its yellow
        sheet_chip = { tracking = 0.08 },
        sheet_chip_plain = { tracking = 0.08 },
        sheet_label = { tracking = 0.08 },
        quick_label = { tracking = 0.08 },
        -- no board: a quick-settings tile's label, the look's label in ink
        quick_cell = { tracking = 0.08 },
        -- The editor screens have no Frosted board: the header on paper over an ink rule, its title
        -- in the display face, the rest in the look's label, at Editorial's sizes and line height 0.3.
        -- no board: the look's label at Editorial's line height
        editor_aside = { tracking = 0.08 },
        -- no board: Editorial's size and line height in the display face
        editor_title = { tracking = -0.015 },
        -- no board: the look's label in ink
        editor_button = { tracking = 0.08 },
        editor_caption = { tracking = 0.08 },
        editor_kind = { tracking = 0.08 },
        -- frosted.md: nav labels 11 px, the look's label, muted unlit (Looks.dc.html:617, :622).
        nav_label = { tracking = 0.08 },
        -- The lit tab's label in ink (Looks.dc.html:617); the board's 800 is Atkinson 700 here.
        nav_label_active = { tracking = 0.08 },
        -- No board draws Frosted's file browser: the library's (Looks.dc.html:744-749).
        -- The book count, the look's label (Looks.dc.html:747).
        title_bar_count = { tracking = 0.08 },
        -- The library's title, 32 px, -0.015 em, CSS line height 0.95 (Looks.dc.html:746).
        title_bar_title = { size = 32, tracking = -0.015 },
        title_bar_sort = { tracking = 0.08 },
        title_bar_status = { tracking = 0.08 },
        -- The library's parts (Looks.dc.html:744-790). The count, the look's label (:747).
        library_count = { tracking = 0.08 },
        -- The title, 32 px, -0.015 em, CSS line height 0.95 (Looks.dc.html:746).
        library_title = { size = 32, tracking = -0.015 },
        library_picker = { tracking = 0.08 },
        library_picker_status = { tracking = 0.08 },
        -- The series and authors screens have no Frosted board: the library's header and the
        -- home's plates, by analogy.
        -- no board: the featured title's size, CSS line height 0.95 as the library's title
        shelf_detail_title = { size = 32, tracking = -0.015 },
        -- no board: the library folder's name (Looks.dc.html:766)
        series_name = { face = "strong" },
        -- no board: the library folder's name (Looks.dc.html:766)
        book_row_title = { face = "strong" },
        -- no board: "read this one next" in the look's label on the yellow row; Frosted has no accent face
        book_next_note = { tracking = 0.08 },
        -- no board: the look's label
        author_count = { tracking = 0.08 },
        shelf_label = { tracking = 0.08 },
    },

    -- frosted.md: three columns of 74 px plates 12 apart, the icon at the top and the label at
    -- the foot (Looks.dc.html:690-692).
    launcher = {
        column_gap = 12, -- frosted.md: tile.gap (Looks.dc.html:444, :684)
        row_gap = 12, -- frosted.md: tile.gap (Looks.dc.html:444, :684)
        icon_size = 24, -- frosted.md: icons 24 px
        padding = { x = 13 }, -- Looks.dc.html:692
        tile_height = 74, -- frosted.md: tile.h
        suffix_gap = 8, -- Looks.dc.html:685, the label's row gap
    },

    -- The quote plain on its plate (frosted.md: quote.style plain, no rules; the plate's padding is
    -- plate.slots.quote).
    quote = { padding = 0 }, -- frosted.md: quote.style plain

    -- The featured book's cover box (frosted.md: 122 × 183, a 2 px ink outline, radius 0, no shadow).
    featured = {
        cover_w = 122, -- frosted.md: cover.w
        cover_h = 183, -- frosted.md: cover.h
        gap = 20, -- Looks.dc.html:702, the plate's gap
        button_fill_color = "yellow", -- no board: frosted.md's chip yellow
    },

    -- The editor screens, edit layout and launcher management. No board draws Frosted's: the header
    -- on paper over a 3 px ink rule (the nav's edge), cards outlined in the plates' 2 px ink with
    -- no shadow, the selected card yellow; spacing as Editorial's boards give it.
    editor = {
        card_outline_width = 2, -- no board: the plate's keyline
        selected_fill_color = "yellow", -- no board: the lit nav tab's yellow
        row_rule_width = 1, -- no board: the sheet's row rules
    },

    -- The nav bar, opaque on purpose: a 3 px ink edge over paper, five tabs of an icon over a
    -- label, the lit tab filled yellow, its icon and label ink and the rest muted (frosted.md;
    -- Looks.dc.html:608-622).
    nav = { active_fill_color = "yellow" }, -- frosted.md: nav.lit fill, litColor a2

    -- The file browser's title bar. No board draws Frosted's: the library's header (Looks.dc.html:744-749,
    -- :761-764), a count and a 32 px title on paper with no rule, the pickers outlined in 2 px ink on paper.
    title_bar = {
        padding = { top = 26, side = 24 }, -- no board: the home's top margin and the sides
        picker_radius = 999, -- no board: frosted.md's picker.radius 999, a pill
    },

    -- The library (Looks.dc.html:740-790), on paper: the wallpaper is the home's alone. A 32 px
    -- title and count with no rule, the pickers outlined in 2 px ink on paper, three columns of
    -- covers each in its 2 px ink outline, a violet strip under each, and a pager above the nav.
    library = {
        header = {
            padding = { top = 26, side = 24 }, -- the body's padding (Looks.dc.html:583, :607)
            picker_radius = 999, -- frosted.md: picker.radius 999, a pill
        },
        grid = {
            side = 24, -- Looks.dc.html:583
            strip_gap = 8, -- the item's 8 px gap (Looks.dc.html:752)
        },
        -- The covers in their 2 px ink outline (frosted.md cover.outline), square, no shadow.
        cover = {
            outline_width = 2, -- frosted.md: cover.outline
            shadow = { y = 0, color = false }, -- frosted.md: cover.shadow none
        },
        -- The folder's tile (Looks.dc.html:754-766): a plate's 2 px ink keyline on paper (:764).
        folder = { outline_width = 2 }, -- Looks.dc.html:764, the plate's keyline
        badge = { fill_color = "yellow" }, -- no board: frosted.md's chip yellow
        not_downloaded = { padding = { x = 10, y = 5 } }, -- Looks.dc.html:778, the missing label's pill
        pager = { next_fill_color = "yellow" }, -- no board: the lit nav tab's yellow
    },

    -- The series and authors screens. No board draws Frosted's: the library's header on paper,
    -- rows and groups outlined as the home's plates (2 px ink, no shadow), yellow chips and letters,
    -- the up-next book on yellow.
    shelf = {
        detail = { padding = { side = 24 } }, -- no board: the library header's
        list = {
            side = 24, -- no board: the library grid's
            row_gap = 12, -- no board: the plates' gutter
        },
        row = { outline_width = 2 }, -- no board: the plate's keyline
        chip = {
            under_way_fill_color = "yellow", -- no board: frosted.md's chips are yellow
            finished_fill_color = "yellow", -- no board: frosted.md's chips are yellow
            up_next_fill_color = "yellow", -- no board: frosted.md's chips are yellow
        },
        book = { cover_outline_width = 2 }, -- no board: frosted.md's cover outline
        next = { fill_color = "yellow" }, -- no board: frosted.md's yellow fill
        group = {
            outline_width = 2, -- no board: the plate's keyline
            letter_fill_color = "yellow", -- no board: frosted.md's yellow fill
        },
        author = { rule_width = 1 }, -- no board: the sheet's row rules
        up_next = { fill_color = "yellow" }, -- no board: frosted.md's chips are yellow
    },
}
