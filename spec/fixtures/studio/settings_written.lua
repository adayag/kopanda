-- /mnt/us/koreader/settings/kopanda/settings.lua
return {
    ["featured.pinned"] = "/mnt/us/documents/Frankenstein.epub",
    ["launcher.entries"] = {
        [1] = {
            ["kind"] = "koreader",
            ["target"] = "favorites",
        },
        [2] = {
            ["kind"] = "kopanda",
            ["target"] = "library",
        },
        [3] = {
            ["action"] = "search",
            ["icon"] = "calibre",
            ["kind"] = "plugin",
            ["label"] = "Calibre",
            ["plugin"] = "calibre",
        },
        [4] = {
            ["action"] = "wifi_toggle",
            ["icon"] = "action",
            ["kind"] = "action",
            ["label"] = "Wi-Fi",
        },
        [5] = {
            ["kind"] = "directory",
            ["label"] = "Say \"hi\" \\ back\
then\9Café “quoted”",
            ["path"] = "/mnt/us/documents/Café",
        },
        [6] = {
            ["entries"] = {
                [1] = {
                    ["kind"] = "koreader",
                    ["target"] = "collections",
                },
                [2] = {
                    ["kind"] = "kopanda",
                    ["target"] = "settings",
                },
            },
            ["kind"] = "folder",
            ["label"] = "Tools",
        },
    },
    ["layout.rows"] = {
        [1] = {
            [1] = {
                ["share"] = 2,
                ["widget"] = "clock",
            },
            [2] = {
                ["share"] = 1,
                ["widget"] = "date",
            },
        },
        [2] = {
            [1] = {
                ["share"] = 1,
                ["widget"] = "featured",
            },
        },
        [3] = {
            [1] = {
                ["share"] = 3,
                ["widget"] = "launcher",
            },
        },
        [4] = {
            [1] = {
                ["share"] = 1,
                ["widget"] = "weather",
            },
            [2] = {
                ["share"] = 1,
                ["widget"] = "quote",
            },
            [3] = {
                ["share"] = 1,
                ["widget"] = "stats",
            },
        },
    },
    ["look"] = "editorial",
    ["quote.source"] = "builtin",
    ["schema_version"] = 1,
    ["stats.show"] = false,
    ["studio.note"] = {
        [1] = 3,
        [10] = true,
        ["x"] = "y",
    },
    ["text_size"] = "large",
    ["wallpaper.file"] = "/mnt/us/images/flowers.png",
    ["weather.location"] = {
        ["latitude"] = 47.60621,
        ["longitude"] = -122.33207,
        ["name"] = "Seattle, Washington",
    },
    ["weather.units"] = "celsius",
}
