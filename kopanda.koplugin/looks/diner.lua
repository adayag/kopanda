-- Diner: a heavy grotesque, ink outlines, hard shadows and flat accent fills. Pure data, typed
-- from the direction doc (.tiller/design/2026-10-13-kopanda-ui-direction.md, "The two looks",
-- the night palettes, "Greys for the Paperwhite"); where the doc leaves a value out, the line's
-- comment names where it comes from. Editorial (looks/editorial.lua) declares the same paths.
--
-- Sizes are board pixels (the canvas's half size), scaled at draw time by Screen:scaleBySize;
-- font sizes go to Font:getFace unscaled. Colours are #rrggbb in the palettes only; every other
-- token names a colour by its palette role. false is a token this look doesn't have.
return {
    faces = {
        display = { file = "fonts/bricolage-grotesque/BricolageGrotesque-ExtraBold.ttf",
            label = "Bricolage Grotesque 800" },
        text = { file = "fonts/bricolage-grotesque/BricolageGrotesque-Medium.ttf", label = "Bricolage Grotesque 500" },
        accent = { file = "fonts/caveat/Caveat-Regular.ttf", label = "Caveat 400" },
    },

    palettes = {
        day = {
            paper = "#f5f1e6",
            ink = "#2f2e2b",
            muted = "#5a5750",
            text = "#2f2e2b", -- implied: Diner's text is its ink
            hairline = false,
            hairline_light = false,
            teal = "#6fb3ab",
            pink = "#e8a59d",
            mustard = "#e0bd6a",
            band = "#6fb3ab", -- the canvas's header band is teal (HomeRetro.dc.html)
            outline = "#2f2e2b", -- the doc: strokes are ink
            shadow = "#2f2e2b", -- the doc: hard shadows are ink
        },
        night = {
            paper = "#1e1c1a",
            ink = "#f1ece0",
            muted = "#bdb7a9",
            text = "#f1ece0", -- implied: Diner's text is its ink
            hairline = false,
            hairline_light = false,
            teal = "#2f6b65",
            pink = "#b86f68",
            mustard = "#b8923c",
            band = "#2f6b65", -- the canvas's night band is the night teal (NightC.dc.html)
            outline = "#f1ece0", -- the doc: outlines turn cream, the night ink
            shadow = "#f1ece0", -- the doc: hard shadows turn cream, the night ink
        },
        grey = {
            paper = "#f4f4f4",
            ink = "#111111",
            muted = "#444444", -- the darker of the doc's two muted greys (PWRetro.dc.html)
            text = "#111111", -- implied: Diner's text is its ink
            hairline = false,
            hairline_light = false,
            teal = "#b0b0b0", -- the doc's tiles in the canvas's tile order: teal (PWRetro.dc.html)
            pink = "#e0e0e0", -- pink
            mustard = "#c8c8c8", -- mustard
            band = "#9a9a9a",
            outline = "#111111", -- implied: strokes are ink
            shadow = "#111111", -- implied: hard shadows are ink
        },
    },

    stroke = {
        hairline = false,
        hairline_grey = false,
        rule = false,
        outline = 3,
        band = 4, -- band edges
    },

    shadow = {
        cover = { x = 6, y = 6, color = "pink" }, -- the doc: 4–8 px, pink under the cover; 6 from the canvas
        tile = { x = 4, y = 4, color = "shadow" }, -- 4 from the canvas (HomeRetro.dc.html)
        sheet = { x = 8, y = 8, color = "shadow" },
    },

    radius = {
        cover = 0,
        box = 0,
    },

    -- A filled box with an outline and a hard shadow.
    tile = {
        box = true,
        fill_color = "paper",
        outline_color = "outline",
        rule_color = false,
    },

    -- A 14 px outlined bar with a mustard fill; in grey a 135° hatch of ink on paper.
    progress = {
        height = 14,
        fill_color = "mustard",
        track_color = "paper", -- the canvas's track (HomeRetro.dc.html)
        outline_color = "outline",
        outline_width = 2, -- the canvas's bar outline (HomeRetro.dc.html)
        fill_grey = "hatch_135",
    },

    -- An outlined box with an 8 px ink shadow and a coloured header band; the band's colour is
    -- the sheet's own (pink on the book's, mustard on the home's in the canvas).
    sheet = {
        fill_color = "paper",
        rule_color = false,
        rule_width = 0,
        outline_color = "outline",
        header_band = true,
    },

    -- An outlined box on an accent.
    chip = {
        small_caps = false,
        uppercase = true, -- the canvas's chips are uppercase labels (HomeRetro.dc.html)
        text_color = "ink",
        fill_color = "pink", -- the canvas's "Now reading" chip (HomeRetro.dc.html)
        outline_color = "outline",
    },

    -- 11 px uppercase, 800, 0.1 em tracking.
    label = {
        size = 11,
        face = "display",
        small_caps = false,
        uppercase = true,
        tracking = 0.1,
    },
}
