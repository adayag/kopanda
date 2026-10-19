# 3b Frosted Plates · Wallpaper look, translucent

Same plates, but the wallpaper shows through them, washed toward paper. Built with KOReader's lighten/dim rectangle, not opacity.

## Token table (board px)

| Token | Value |
|---|---|
| Display face | Atkinson Hyperlegible 700 |
| Text face | Atkinson Hyperlegible 400–700 + italic |
| Accent face | none |
| Paper / Ink | plate = wallpaper lightened 0.82 toward #fbfaf6 / #1b1a1f |
| Muted / Text | #4d4b55 / ink |
| Hairline | #d9d6df (sheet rows only) |
| Accents | violet #6b55c8 (progress), yellow #f2c230 (chip, lit tab) |
| Band | none; nav bar and sheet stay opaque |
| Stroke | 2 px ink keyline on every plate, no halo; 3 px ink nav edge |
| Shadow | none (sheet only: ink 5/7 beyond the halo) |
| Radius | 12 plates and tiles, 16 sheet, 999 chip/pill/progress, 0 cover |
| Tile | translucent plate: wallpaper lightened 0.82, 2 px ink keyline; 12 px gutters |
| Progress | 12 px pill, 2 px ink outline, violet on paper |
| Sheet | opaque plate inset 16, radius 16 (modal content never sits on the image) |
| Chip | yellow pill, 2 px ink, uppercase 700 |
| Labels | 11 px uppercase 700, 0.08 em |
| Date/clock | 18 px 700 / 84 px 700, on the header plate |
| Translucency | lightenRect 0.82 day, dimRect 0.84 night (toward #1d1c22), 0.85 Paperwhite. A number per mode, applied to the framebuffer under each plate before text is drawn |

## Icon sets (chosen first)

- Phosphor Bold: MIT, github.com/phosphor-icons/core, npm @phosphor-icons/core, e.g. https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/bold/NAME-bold.svg. Heavy round strokes; friendlier than the grid wants.
- Material Symbols Rounded, 700: Apache-2.0, github.com/google/material-design-icons, npm @material-symbols/svg-700, e.g. https://cdn.jsdelivr.net/npm/@material-symbols/svg-700@0.27.0/rounded/NAME.svg. A thick, rounded, inked outline, like the brush-pen lettering in comic panels.
- Tabler Outline: MIT, github.com/tabler/tabler-icons, npm @tabler/icons, e.g. https://cdn.jsdelivr.net/npm/@tabler/icons@3.24.0/icons/outline/NAME.svg. Neutral 2 px outline; the safe fallback for any look.

## Verdict

The softer version of Plates: the flowers carry on faintly behind every row, so the screen reads as one picture rather than cards on a picture. It isn't CSS opacity. Before drawing a plate's text, KoPanda lightens the framebuffer rectangle under it by 0.82 toward paper (KOReader's BlitBuffer lightenRect, or dimRect at night), so the token is a number and text is still drawn solid on top. At 0.82 the darkest flower only pulls the plate to about #d0cad6, which is still about 12:1 for ink and above 5:1 for muted labels. Below about 0.75, purple and red petals start to break up 11 px labels. The nav bar and the hold sheet stay opaque on purpose: you're acting on them, not admiring them. The e-ink risk: a lightened photo is a field of mid-greys that need waveform-heavy refreshes, so expect more ghosting than 3a and plan a full refresh on Home. On the Paperwhite the washed image dithers into a fine grain behind the text, which is why that mode uses 0.85. Before committing, check that lightenRect behaves the same on the Colorsoft's colour layer.

## Lua export (the design's own, not the plugin's token paths)

```lua
-- looks/frosted.lua
return {
  name = "frosted",
  faces = {
    display = {
      family = "Atkinson Hyperlegible",
      weight = 700,
      repo = "googlefonts/atkinson-hyperlegible",
      file = "AtkinsonHyperlegible-Bold.ttf"
    },
    text = {
      family = "Atkinson Hyperlegible",
      weight = 400,
      bold = 700,
      repo = "googlefonts/atkinson-hyperlegible",
      file = "AtkinsonHyperlegible-Regular.ttf, AtkinsonHyperlegible-Italic.ttf"
    },
    accent = "none"
  },
  palette = {
    day = {
      paper = "#fbfaf6",
      ink = "#1b1a1f",
      text = "#1b1a1f",
      muted = "#4d4b55",
      hairLight = "#d9d6df",
      a1 = "#6b55c8",
      a2 = "#f2c230",
      die = "#fbfaf6",
      card = "#fbfaf6"
    },
    night = {
      paper = "#1d1c22",
      ink = "#f3f1ec",
      text = "#f3f1ec",
      muted = "#b5b2bd",
      hairLight = "#3a3842",
      a1 = "#a593f2",
      a2 = "#8a6d10",
      die = "#1d1c22",
      card = "#1d1c22"
    },
    grey = {
      paper = "#ffffff",
      ink = "#000000",
      text = "#000000",
      muted = "#333333",
      hairLight = "#bbbbbb",
      a1 = "#000000",
      a1Fill = {
        angle = 135,
        pitch = 6,
        line = 2,
        color = "ink"
      },
      a2 = "#cccccc",
      die = "#ffffff",
      card = "#ffffff"
    }
  },
  stroke = {
    hair = 1,
    rule = 2,
    greyHair = 2
  },
  header = {
    layout = "clockRight",
    rule = 0,
    ruleColor = "none",
    tracking = -0.03,
    dateFace = "text",
    dateWeight = 700
  },
  cover = {
    w = 122,
    h = 183,
    outline = 2,
    outlineColor = "ink",
    shadow = "none",
    under = "none",
    frame = 0,
    radius = 0,
    ring = {
      w = 3,
      color = "paper"
    }
  },
  chip = {
    fill = "a2",
    color = "ink",
    border = 2,
    borderColor = "ink",
    radius = 999
  },
  title = {
    tracking = -0.015,
    mark = "none"
  },
  progress = {
    h = 12,
    outline = 2,
    outlineColor = "ink",
    fill = "a1",
    track = "paper",
    radius = 999
  },
  quote = {
    style = "plain",
    rule = 0,
    ruleColor = "none",
    face = "text",
    weight = 400,
    slant = "italic"
  },
  tile = {
    style = "plate",
    cols = 3,
    h = 74,
    border = 2,
    borderColor = "ink",
    fill = "paper",
    under = "none",
    radius = 12,
    gap = 12
  },
  nav = {
    edge = 3,
    edgeStyle = "solid",
    lit = "fill",
    litColor = "a2",
    bar = 0
  },
  sheet = {
    style = "inset",
    edge = 2,
    edgeStyle = "solid",
    inset = 16,
    border = 2,
    under = "none",
    band = "none",
    rowRule = "hairLight",
    radius = 16,
    ring = 4
  },
  picker = {
    border = 2,
    borderColor = "ink",
    fill = "paper",
    radius = 999
  },
  label = {
    size = 11,
    weight = 700,
    tracking = 0.08,
    case = "upper",
    color = "muted"
  },
  size = {
    date = 18,
    clock = 84,
    title = 32,
    author = 16,
    quote = 18,
    launcher = 19,
    label = 11,
    sheetRow = 18,
    nav = 11
  },
  misregister = "none",
  ruled = "none",
  frame = "none",
  align = "left",
  texture = "none",
  dots = "none",
  wallpaper = {
    file = "wallpaper.png",
    fit = "cover",
    position = "center",
    under_text = "never"
  },
  plate = {
    fill = "paper",
    border = 2,
    borderColor = "ink",
    ring = 0,
    ringColor = "none",
    radius = 12,
    lighten = {
      op = "lighten",
      day = 0.82,
      night = 0.84,
      grey = 0.85
    }
  },
  icons = {
    set = "Phosphor Bold",
    repo = "phosphor-icons/core",
    licence = "MIT",
    pkg = "@phosphor-icons/core",
    url_example = "https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/bold/NAME-bold.svg",
    size = 24,
    nav_size = 24,
    color = "ink",
    nav_unlit = "muted",
    files = {
      home = "house.svg",
      library = "books.svg",
      series = "stack.svg",
      authors = "user.svg",
      history = "clock-counter-clockwise.svg",
      wifi = "wifi-slash.svg",
      settings = "gear-six.svg",
      folder = "folder.svg"
    }
  }
}
```
