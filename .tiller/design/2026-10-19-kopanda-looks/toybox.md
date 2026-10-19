# 2c Toybox · Chunky toy blocks

Rounded blocks with a solid edge beneath, round coloured icon badges and a floating pill nav. Baloo 2 with Nunito.

## Token table (board px)

| Token | Value |
|---|---|
| Display face | Baloo 2 800 |
| Text face | Nunito 700–800, 600 italic for the quote |
| Accent face | none |
| Paper / Ink | #fbf5ec / #2b2934 |
| Muted / Text | #5b5867 / ink |
| Hairline | #e7ddcd (sheet rows) |
| Accents | sun #ffc94a, coral #ff8f75, mint #86d3b4 |
| Band | mint band on the sheet only |
| Stroke | 3 px ink blocks, cover, progress, nav; 2.5 px ink icon badges |
| Shadow | solid block edge: ink 0 right 6 down (tiles, cover, nav), 8 under the sheet |
| Radius | 18 tiles, 24 sheet, 6 cover, 999 badges/pills/progress/nav |
| Tile | paper block with a 42 px round icon badge cycling sun/coral/mint |
| Progress | 18 px pill, 3 px ink outline, coral on paper |
| Sheet | inset 16, radius 24, ink 0/8 edge, mint header band |
| Chip | mint pill, 2 px ink, uppercase 800 |
| Labels | 11 px uppercase 800, 0.1 em |
| Date/clock | 18 px 800 / 100 px 800, clock left; floating pill nav, 6 px edge |

## Icon sets (chosen first)

- MingCute Line: Apache-2.0, github.com/Richard9394/MingCute, npm mingcute_icon, e.g. https://cdn.jsdelivr.net/npm/mingcute_icon@2.9.6/svg/NAME.svg. Soft, round and toy-like, with even 1.5 px lines that sit well inside coloured badges.
- Material Symbols Rounded, 700: Apache-2.0, github.com/google/material-design-icons, npm @material-symbols/svg-700, e.g. https://cdn.jsdelivr.net/npm/@material-symbols/svg-700@0.27.0/rounded/NAME.svg. A thick, rounded, inked outline, like the brush-pen lettering in comic panels.
- Phosphor Bold: MIT, github.com/phosphor-icons/core, npm @phosphor-icons/core, e.g. https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/bold/NAME-bold.svg. Heavy round strokes; friendlier than the grid wants.

## Verdict

Toy blocks: everything you can press has a solid edge under it, as if it would click down, and the colour lives in small round badges so the blocks themselves stay calm. It's for someone who wants friendly, maybe a shared or family Kindle, and finds Diner's full-colour tiles too much. Without colour it's nearly unchanged, because the 6 px edge and round badges carry the identity, not the hue. The risk: large rounded corners and pill shapes are all anti-aliased curves, which ghost more than straight edges on partial refreshes, and the floating nav's rounded ends may leave a faint outline after page turns. Make sure KOReader does a full refresh when returning home.

## Lua export (the design's own, not the plugin's token paths)

```lua
-- looks/toybox.lua
return {
  name = "toybox",
  faces = {
    display = {
      family = "Baloo 2",
      weight = 800,
      repo = "EkType/Baloo2",
      file = "Baloo2-ExtraBold.ttf"
    },
    text = {
      family = "Nunito",
      weight = 700,
      bold = 800,
      repo = "googlefonts/nunito",
      file = "Nunito-Bold.ttf, Nunito-ExtraBold.ttf, Nunito-SemiBoldItalic.ttf"
    },
    accent = "none"
  },
  palette = {
    day = {
      paper = "#fbf5ec",
      ink = "#2b2934",
      text = "#2b2934",
      muted = "#5b5867",
      hairLight = "#e7ddcd",
      a1 = "#ffc94a",
      a2 = "#ff8f75",
      a3 = "#86d3b4",
      die = "#ffffff",
      card = "#fbf5ec"
    },
    night = {
      paper = "#1e1d26",
      ink = "#f4f0ea",
      text = "#f4f0ea",
      muted = "#b4b1c0",
      hairLight = "#383645",
      a1 = "#8a6a12",
      a2 = "#a2493a",
      a3 = "#2f7a5c",
      die = "#282733",
      card = "#24232e"
    },
    grey = {
      paper = "#ffffff",
      ink = "#000000",
      text = "#000000",
      muted = "#333333",
      hairLight = "#cccccc",
      a1 = "#dddddd",
      a2 = "#999999",
      a3 = "#bbbbbb",
      die = "#ffffff",
      card = "#ffffff"
    }
  },
  stroke = {
    hair = 2,
    rule = 3,
    greyHair = 2
  },
  header = {
    layout = "clockLeft",
    rule = 0,
    ruleColor = "none",
    tracking = -0.02,
    dateFace = "text",
    dateWeight = 800
  },
  cover = {
    w = 140,
    h = 210,
    outline = 3,
    outlineColor = "ink",
    shadow = {
      x = 0,
      y = 6,
      color = "ink"
    },
    under = "none",
    frame = 0,
    radius = 6
  },
  chip = {
    fill = "a3",
    color = "ink",
    border = 2,
    borderColor = "ink",
    radius = 999
  },
  title = {
    tracking = -0.01,
    mark = "none"
  },
  progress = {
    h = 18,
    outline = 3,
    outlineColor = "ink",
    fill = "a2",
    track = "paper",
    radius = 999
  },
  quote = {
    style = "plain",
    rule = 0,
    ruleColor = "none",
    face = "text",
    weight = 600,
    slant = "italic"
  },
  tile = {
    style = "block",
    cols = 3,
    h = 84,
    border = 3,
    borderColor = "ink",
    fill = "paper",
    under = "none",
    fills = { "a1", "a2", "a3", "a2", "a3", "a1" },
    radius = 18,
    edge = 6,
    gap = 16
  },
  nav = {
    edge = 3,
    edgeStyle = "solid",
    lit = "pill",
    litColor = "a1",
    bar = 0,
    radius = 999,
    float = 6
  },
  sheet = {
    style = "inset",
    edge = 3,
    edgeStyle = "solid",
    inset = 16,
    border = 3,
    under = {
      x = 0,
      y = 8,
      fill = "ink"
    },
    band = "a3",
    rowRule = "hairLight",
    radius = 24
  },
  picker = {
    border = 2,
    borderColor = "ink",
    fill = "paper",
    radius = 999
  },
  label = {
    size = 11,
    weight = 800,
    tracking = 0.1,
    case = "upper",
    color = "muted"
  },
  size = {
    date = 18,
    clock = 100,
    title = 36,
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
  wallpaper = "none",
  plate = "none",
  icons = {
    set = "MingCute Line",
    repo = "Richard9394/MingCute",
    licence = "Apache-2.0",
    pkg = "mingcute_icon",
    url_example = "https://cdn.jsdelivr.net/npm/mingcute_icon@2.9.6/svg/NAME.svg",
    size = 24,
    nav_size = 24,
    color = "ink",
    nav_unlit = "muted",
    files = {
      home = "building/home_3_line.svg",
      library = "education/book_2_line.svg",
      series = "design/layer_line.svg",
      authors = "user/user_3_line.svg",
      history = "system/history_line.svg",
      wifi = "device/wifi_off_line.svg",
      settings = "system/settings_3_line.svg",
      folder = "file/folder_2_line.svg"
    }
  }
}
```
