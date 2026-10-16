std = "luajit"
-- ignore implicit self
self = false
unused_args = false
max_line_length = 120

globals = {
    "G_reader_settings",
    "G_defaults",
}

exclude_files = {
    "spec/fixtures/**",
    "studio/node_modules/**",
    "studio/dist/**",
}

-- don't balk on busted stuff in spec
files["spec/**"].std = "+busted"
