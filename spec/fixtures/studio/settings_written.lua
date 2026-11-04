-- /mnt/us/koreader/settings/kopanda/settings.lua
return {
    ["featured.pinned"] = "/mnt/us/documents/Frankenstein.epub",
    ["focused.on"] = false,
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
            ["kind"] = "directory",
            ["label"] = "Say \"hi\" \\ back\
then\9Café “quoted”",
            ["path"] = "/mnt/us/documents/Café",
        },
        [4] = {
            ["entries"] = {
                [1] = {
                    ["action"] = "search",
                    ["icon"] = "calibre",
                    ["kind"] = "plugin",
                    ["label"] = "Calibre",
                    ["plugin"] = "calibre",
                },
                [2] = {
                    ["icon"] = "action",
                    ["item"] = "rakuyomi",
                    ["kind"] = "plugin_menu",
                    ["label"] = "Manga",
                    ["plugin"] = "rakuyomi",
                },
                [3] = {
                    ["action"] = "wifi_toggle",
                    ["icon"] = "action",
                    ["kind"] = "action",
                    ["label"] = "Wi-Fi",
                },
                [4] = {
                    ["kind"] = "koreader",
                    ["target"] = "collections",
                },
                [5] = {
                    ["kind"] = "kopanda",
                    ["target"] = "settings",
                },
            },
            ["kind"] = "folder",
            ["label"] = "Tools",
        },
    },
    ["look"] = "editorial",
    ["schema_version"] = 1,
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
