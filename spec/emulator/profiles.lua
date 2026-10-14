-- Device profiles the emulator captures are taken at. Pure data: pixel size, DPI and
-- whether the panel is colour (a grey profile runs the emulator with EMULATE_BW_SCREEN).
return {
    colorsoft = { width = 1264, height = 1680, dpi = 300, color = true },
    paperwhite = { width = 1236, height = 1648, dpi = 300, color = false },
}
