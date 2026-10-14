-- The emulator's fixture library. Every title is public domain in the United States; these
-- are Standard Ebooks releases, which are CC0. sha256 is the file's plain SHA-256 hex, as
-- `shasum -a 256` prints it. cover = true: the EPUB embeds a cover image, checked by hand.
return {
    {
        file = "a-christmas-carol.epub",
        title = "A Christmas Carol",
        author = "Charles Dickens",
        source = "https://standardebooks.org/ebooks/charles-dickens/a-christmas-carol",
        sha256 = "5362a33b41bc353b415e28c339303dae02dcc016fb4f706e3078df6425369cf9",
        cover = true,
    },
    {
        file = "frankenstein.epub",
        title = "Frankenstein",
        author = "Mary Shelley",
        source = "https://standardebooks.org/ebooks/mary-shelley/frankenstein",
        sha256 = "0b5c070e2cde4d8bb36ef707f9d024465b00d0c49c078f0a148270f55b8c8780",
        cover = true,
    },
    {
        file = "the-time-machine.epub",
        title = "The Time Machine",
        author = "H. G. Wells",
        source = "https://standardebooks.org/ebooks/h-g-wells/the-time-machine",
        sha256 = "3931b56fecfb0b0d00737f5fabcd00a46a96c26a6b1c9b8a60751d154057d9a6",
        cover = true,
    },
}
