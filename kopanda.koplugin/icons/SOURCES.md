# Vendored icon sets

A look may draw its own icon set, one file per registry id (`icons.lua`) under
`icons/<set id>/<registry id>.svg`, beside the pack's licence as `LICENSE.txt`. The default
set is the Lucide files at the top of `icons/` (`LICENSE-lucide.txt`).

Files were recoloured to explicit black and nothing else changed: NanoSVG renders a file's own
colours and turns `currentColor` into mid-grey, and `TintedIcon` colours an icon through its
black ink. Each set's section says what its files changed. The hash is the SHA-256 of the file
as shipped here, not the pack's.

## phosphor-bold

- Set: Phosphor Bold, for Frosted
- Pack: `@phosphor-icons/core` 2.1.1 (https://github.com/phosphor-icons/core), the `bold` weight, `assets/bold/<name>-bold.svg`
- Source: `https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/<pack file>`
- Tarball: https://registry.npmjs.org/@phosphor-icons/core/-/core-2.1.1.tgz, SHA-256 `313332be6190b724da24107addd781799b48bf76b13963f24501112ffe1baadd`
- Licence: MIT, `phosphor-bold/LICENSE.txt` (the pack's `LICENSE`)
- Changes: The root's `fill="currentColor"` became `fill="#000000"`; nothing else changed.

| Registry id | Pack file | SHA-256 |
|---|---|---|
| action | `assets/bold/lightning-bold.svg` | e615d39f20ca5fa2155d707a785f438efa378bc46ba8226402aed1c6fd5ff82a |
| authors | `assets/bold/user-bold.svg` | 2c153cf5b7e9a78004f5c803b818202f1ab15e2979eca9af92acb00754b4f2fd |
| back | `assets/bold/caret-left-bold.svg` | 9c49b6f98a484fefe6d9fe21a21e25704ccc8bde155ce865daeae0301411429d |
| bookmark | `assets/bold/bookmark-simple-bold.svg` | bee0fe599023d4d5ed7b49740b8836c994f9ea456948d817c2b7d84473184e72 |
| check | `assets/bold/check-bold.svg` | 562c5510a51802d5a173e95cb59bfba896e45ba3daa36669b8909684c81b4e4e |
| chevron_down | `assets/bold/caret-down-bold.svg` | 19c9f4ed070223db009cc0fb057cb28d67960240ba7b52abb169906c0a217dfc |
| chevron_up | `assets/bold/caret-up-bold.svg` | 62b370a8c2466cce50d6e10837e33451289d414bb1b8692f9d4a1d85db877932 |
| close | `assets/bold/x-bold.svg` | 9be3875db68d9a6aaa349e637347ad5c50ca0128fd8b49521373be25d9cce1df |
| download | `assets/bold/arrow-line-down-bold.svg` | 72bea6812691944608b97f80058285421b2029789a951583579ad683b634ddf2 |
| eye_off | `assets/bold/eye-slash-bold.svg` | bf8dfda26748f3f890e433f61b034cd98a09e9caed57ab1665fc59e112ff264e |
| filter | `assets/bold/funnel-bold.svg` | 3b943fa7784d968e4aa5b23766d580d7c8f7b29a77c21bd48d0061bd517e32ec |
| folder | `assets/bold/folder-bold.svg` | e45da40b75f63083537dfe0413e32e9d96584df2fd75244fd196e291fb0e8128 |
| folder_open | `assets/bold/folder-open-bold.svg` | 4458d94c614127a896f994b91594f1ba477c515c20a6f7da7bef8cfc6a4fccc9 |
| forward | `assets/bold/caret-right-bold.svg` | 5ff259bb3665656e24903d4fd0a01e9113365ab6e410ff9163b7342593107cfb |
| history | `assets/bold/clock-counter-clockwise-bold.svg` | 4557a0f851947cf08f6e85fa6e44b4ec3803b65de3c0748bf0435845c62981b4 |
| home | `assets/bold/house-bold.svg` | 76e786eea8f49d69b735b195aba3411dfdeaedf5d2afb9a1290fe954b9ae3885 |
| home_plus | `assets/bold/push-pin-bold.svg` | e02e54767dc3af374e0154e01bc2bf2782e622697dba549835912ea61c456dce |
| info | `assets/bold/info-bold.svg` | b4121261e2e7397235b4c590852fc9b2e05279e68b5bfb59c2affc9c76979ff9 |
| library | `assets/bold/books-bold.svg` | 88ede18953e74243191a15bc4477e3d34d38b3581b3a29f5848f2a39a50fec8c |
| list | `assets/bold/list-bullets-bold.svg` | 5ba18bf500ab3d9bbce4ca6567531a05e97e33166592ee5df97d300e9a6ec43b |
| moon | `assets/bold/moon-bold.svg` | b6016b0b4fa9c668b7b331b655204030aedefc4a52de8f3c596ad442cdfae79c |
| open_book | `assets/bold/book-open-bold.svg` | 79ce827aa4ba459e523e0e836bffa17a1f462760ad176fa3f076602643ba4b68 |
| plugin_missing | `assets/bold/selection-bold.svg` | 7bf0e00613ccdd922038f181d5f619e258e249bb3854bb3edf9e5adad1cb631d |
| plus | `assets/bold/plus-bold.svg` | cb4562fc7b5ef868694b9ffc4caf21231c723692ff65e5a6049b58c99fae7574 |
| power | `assets/bold/power-bold.svg` | 9273628c7bb7410d87a17701bb50e560ec194b06665a99528865f60ed82e0068 |
| quick_settings | `assets/bold/sliders-horizontal-bold.svg` | ae589d517b756f673f6533d16da4b01e2ae1130563aca597911251b678ff9993 |
| refresh | `assets/bold/arrow-clockwise-bold.svg` | f1739ec6d2153220a3cdf75ab17d67c44b3cecafb86a52555efddb402765c523 |
| rotation_lock | `assets/bold/device-rotate-bold.svg` | fc1a162ce5f504860545a2dc98b83019d86b975f0fc900e7fc281ca79ff44e2f |
| screenshot | `assets/bold/camera-bold.svg` | 8aa03eeb7f8dddba034d67ac4656bc7b8f3ef479f737bcc3bf8a68d3c2a02055 |
| search | `assets/bold/magnifying-glass-bold.svg` | 408b0e315bc54f82ae101179e92a5789da1d009bc4a8787fb866def4aef3e736 |
| series | `assets/bold/stack-bold.svg` | 26d72b817b11fb398c857c4780128c51a3a664d0d8a1ce48c4aa2e0aea7926df |
| settings | `assets/bold/gear-six-bold.svg` | 11f4c359cd45d67e8f4721593199a6f3f9f7c5749ab47e0219a17e93fa450ada |
| sort | `assets/bold/sort-ascending-bold.svg` | 5187954195c65154d345fd01ac670bce637858efec066ba98fccff33d11646e3 |
| stats | `assets/bold/chart-bar-bold.svg` | 6c9fe23a7e831fc2adc6be9fa03615f31bf73765adf85e0ac07c890585187147 |
| subjects | `assets/bold/tag-bold.svg` | 6ef3a3af0b3d96a7d168dfa24f4bfc1b1811fe9d0b1670e2d626d07d9a4c77af |
| sun | `assets/bold/sun-bold.svg` | 62578d5184297e7b5ed04b59a549aade5bc814d9364413cb5d3e23c47094e13f |
| sync | `assets/bold/cloud-arrow-down-bold.svg` | 320a93def6d327981f52ac87ace22b338e42a4e48b321738a957a7305512be54 |
| terminal | `assets/bold/terminal-window-bold.svg` | bdef5db73431e002bd90286412300b7d4c0ea55fa3a96d66f05934ec8525fec0 |
| trash | `assets/bold/trash-bold.svg` | ecbe3b7ce4d8edf1e08e295b4800afcf1e42e4dfa965a74a44e819f7ac43c3b3 |
| wifi | `assets/bold/wifi-high-bold.svg` | 754e3f2e3173f56045c6c51ccd8c77f1594f0ef6eddefdcec2a13c210d6e9f40 |
| wifi_off | `assets/bold/wifi-slash-bold.svg` | 5a72353f80a7e092c9da235bf3eed21dadf50c2739b254f1342cb448ef77aa71 |
