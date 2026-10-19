# Vendored icon sets

Each new look draws its own icon set, one file per registry id (`icons.lua`) under
`icons/<set id>/<registry id>.svg`, beside the pack's licence as `LICENSE.txt`. The default
set is the Lucide files at the top of `icons/` (`LICENSE-lucide.txt`).

Files were recoloured to explicit black and nothing else changed: NanoSVG renders a file's own
colours and turns `currentColor` into mid-grey, and `TintedIcon` colours an icon through its
black ink. Each set's section says what its files changed. The hash is the SHA-256 of the file
as shipped here, not the pack's.

## phosphor-fill

- Set: Phosphor Fill, for Riso
- Pack: `@phosphor-icons/core` 2.1.1 (https://github.com/phosphor-icons/core), the `fill` weight, `assets/fill/<name>-fill.svg`
- Source: `https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/<pack file>`
- Tarball: https://registry.npmjs.org/@phosphor-icons/core/-/core-2.1.1.tgz, SHA-256 `313332be6190b724da24107addd781799b48bf76b13963f24501112ffe1baadd`
- Licence: MIT, `phosphor-fill/LICENSE.txt` (the pack's `LICENSE`)
- Changes: The root's `fill="currentColor"` became `fill="#000000"`; nothing else changed.

| Registry id | Pack file | SHA-256 |
|---|---|---|
| action | `assets/fill/lightning-fill.svg` | 5d930611736398e3439ef50fca64dbe156b489ecccef75f655ce1c0612d37354 |
| authors | `assets/fill/user-fill.svg` | 369b7757410a08d60fe88bcc4919c64192f3bc1c05ca5f7cbec5342d233cb165 |
| back | `assets/fill/caret-left-fill.svg` | 3d430443491cc4a2676499e78f1c39bdebf6cde2a9181fdf223fe2e150e80e55 |
| bookmark | `assets/fill/bookmark-simple-fill.svg` | 4d173414926b69276e1313f9ddde5d4083694a9a23fa1077ea74ecaac6c0ff2f |
| check | `assets/fill/check-fill.svg` | 2933a64866df83209d2b2ab82e79e173b81dfdf3fdc94a3e9a024f5b241c1840 |
| chevron_down | `assets/fill/caret-down-fill.svg` | 812fd2819b2ecd41508b99eaaaf17b9967fa362b321a4e21f3a4f9d199dfd92f |
| chevron_up | `assets/fill/caret-up-fill.svg` | 8c5245072d5d1db22e9e1ffd7bb5b49ca6e022fdbe55464305aa50256315041e |
| close | `assets/fill/x-fill.svg` | c38cbe97f588240353c30cfab06997a2c74e77b7db440f47e9237daf432d04af |
| download | `assets/fill/arrow-line-down-fill.svg` | d7e1235ea71f875f5bc46897ecf382639fa3abff55d1a2edd5014aa7483ddbcf |
| eye_off | `assets/fill/eye-slash-fill.svg` | 8057b1591f3deec5aa40842b4943ca993bf46ba1720c42cb2a80f56ad55c54b3 |
| filter | `assets/fill/funnel-fill.svg` | 93318058196472dea21f23940e0c208523e6dbfd6cda73ef4d4e4765af514473 |
| folder | `assets/fill/folder-fill.svg` | aaac9770baebb628162b0b4f3cc431eab6f9e74e15c06ad8215c7c42ed7b5013 |
| folder_open | `assets/fill/folder-open-fill.svg` | 3c1de3dfd226202c8057c863a3115a92251018a56405520c57604f7ec9b01ff6 |
| forward | `assets/fill/caret-right-fill.svg` | 8bab7941e5e6cdfdbae8930215de293f2dd93d5be2f8a06c3fe5a9937c25930a |
| history | `assets/fill/clock-counter-clockwise-fill.svg` | 7b045eaf09f98940f72e2a331d6365bf7fbb258722b32a6ff44cd4651d463aac |
| home | `assets/fill/house-fill.svg` | 8f12446bfbdec35b1173d017b533d8931684c54ad021dbbae0324f22580f4257 |
| home_plus | `assets/fill/push-pin-fill.svg` | 5cef9b52c9c3aab26b9cc3b28df25649c6725b6e65964425eecd8ce2e93fb1b0 |
| info | `assets/fill/info-fill.svg` | cb37cf5bfba85cd6fc5f7237a0cf5f74184a273587ef9343e33d550bdd8c085f |
| layout | `assets/fill/layout-fill.svg` | 3f6e8094ae9031325cba7b16b831ff8b61df5beae34c3934db1c71fe15b371af |
| library | `assets/fill/books-fill.svg` | 2eed56a1d8752987c3b34034acfa824f0823672c520df24955d89631e906cf86 |
| list | `assets/fill/list-bullets-fill.svg` | 4134edeb323a154e13bf9bc1fc825518c32018d24b422ddc646c8421179780ec |
| moon | `assets/fill/moon-fill.svg` | 22d65a5c123d3e515d19756488a1958d1874930bf9c11f5dd033ff91ef7b0058 |
| open_book | `assets/fill/book-open-fill.svg` | a218cc9897333e84438df2f7c81347f6eb71ddf121f63efeab551e16482a014e |
| plugin_missing | `assets/fill/question-fill.svg` | 22248820000e1f5fcd5c9a26a7c07c9e672ffd5cb03af4e0d6afe04058048943 |
| plus | `assets/fill/plus-fill.svg` | b21c16cd793ebcfe80fd06c102c8fd7abf4a56309749a3ba3ba5cea6fad21e7c |
| power | `assets/fill/power-fill.svg` | 4c2915ec6fe73cc71801c90237dea28930fc862f0b7f9db9d297e672ef2cdb0c |
| quick_settings | `assets/fill/sliders-horizontal-fill.svg` | 089fdedcdbd0c712201a7ac3dcc553b1da0e9908a5a9a8cec1897cae0ee4c08a |
| refresh | `assets/fill/arrow-clockwise-fill.svg` | 3bd547af1e2f86de299c20cfb484079cdb8be69a9894503ca58c859688a4b690 |
| rotation_lock | `assets/fill/device-rotate-fill.svg` | 763726c9113887516d3346db3f4a61dffe1db0db8f2c98d8d10991b61fa39063 |
| screenshot | `assets/fill/camera-fill.svg` | 7dfb177061eb3d870a6b972c3b4cc18824296300b4a30014d27823826c88ba76 |
| series | `assets/fill/stack-fill.svg` | 36218018848bc80ed1bb7239ed26d8b6b4208355068d3285b8c510fd5596b3a4 |
| settings | `assets/fill/gear-six-fill.svg` | fb7988bcc52bc8f4d2229d7365d37c3d1a4d98f703b690684325af32f863635a |
| sort | `assets/fill/sort-ascending-fill.svg` | 8d49f3dca28158f1182e9c7821f7404cfbb6c348f4fd534c4d5874521375ca0a |
| sun | `assets/fill/sun-fill.svg` | 1019ae02cdb08886da9a9bd06d367ff97cfd0834844135cf4b2adb856e95406c |
| sync | `assets/fill/cloud-arrow-down-fill.svg` | 18d12311cd77cfb5c8a2b5c423d9b1fb8472c8e0b43ff73bb45eca996c195992 |
| terminal | `assets/fill/terminal-window-fill.svg` | df9620f1b3f811d4efd0d286f50945ae1f30abed82496c584541177af4d34001 |
| trash | `assets/fill/trash-fill.svg` | b6e0674122719343f02049e52e63d47df84c87d41139a16bcaed07a8873fa93e |
| wifi | `assets/fill/wifi-high-fill.svg` | b3791fe9d178408f328ddf43a2e4d7c2d6838310bbbd3e99fc5bea5872fde11e |
| wifi_off | `assets/fill/wifi-slash-fill.svg` | bb153857f168275651add73d2b114752c5ce78c4fdb5b76503045f0f1c85e12b |

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
| layout | `assets/bold/layout-bold.svg` | 84e9c90c3197fbdf70dca244a286444c5e6bbeb661b4bf21478d104a2cf682ba |
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
| series | `assets/bold/stack-bold.svg` | 26d72b817b11fb398c857c4780128c51a3a664d0d8a1ce48c4aa2e0aea7926df |
| settings | `assets/bold/gear-six-bold.svg` | 11f4c359cd45d67e8f4721593199a6f3f9f7c5749ab47e0219a17e93fa450ada |
| sort | `assets/bold/sort-ascending-bold.svg` | 5187954195c65154d345fd01ac670bce637858efec066ba98fccff33d11646e3 |
| sun | `assets/bold/sun-bold.svg` | 62578d5184297e7b5ed04b59a549aade5bc814d9364413cb5d3e23c47094e13f |
| sync | `assets/bold/cloud-arrow-down-bold.svg` | 320a93def6d327981f52ac87ace22b338e42a4e48b321738a957a7305512be54 |
| terminal | `assets/bold/terminal-window-bold.svg` | bdef5db73431e002bd90286412300b7d4c0ea55fa3a96d66f05934ec8525fec0 |
| trash | `assets/bold/trash-bold.svg` | ecbe3b7ce4d8edf1e08e295b4800afcf1e42e4dfa965a74a44e819f7ac43c3b3 |
| wifi | `assets/bold/wifi-high-bold.svg` | 754e3f2e3173f56045c6c51ccd8c77f1594f0ef6eddefdcec2a13c210d6e9f40 |
| wifi_off | `assets/bold/wifi-slash-bold.svg` | 5a72353f80a7e092c9da235bf3eed21dadf50c2739b254f1342cb448ef77aa71 |

## mingcute-line

- Set: MingCute Line, for Toybox
- Pack: `mingcute_icon` 2.9.6 (https://github.com/Richard9394/MingCute), the line style, `svg/<group>/<name>_line.svg`
- Source: `https://cdn.jsdelivr.net/npm/mingcute_icon@2.9.6/<pack file>`
- Tarball: https://registry.npmjs.org/mingcute_icon/-/mingcute_icon-2.9.6.tgz, SHA-256 `5acc721d0326646e7ce60af28e020a47befc35f8d1a3983c260f33601debb73e`
- Licence: Apache-2.0, `mingcute-line/LICENSE.txt` (the pack's `LICENSE`)
- Changes: Each drawn path's `fill="#09244B"` became `fill="#000000"`, and the pack's first path, unfilled (it sits in the file's `<g fill="none">`) and drawing the 24 × 24 bounding square with a few sub-pixel marks, was dropped from every file; nothing else changed. The files keep the pack's `width="24" height="24"` and, like the pack, carry no viewBox.

| Registry id | Pack file | SHA-256 |
|---|---|---|
| action | `svg/device/flash_line.svg` | d0dbb847a903cb389a4061eea88dcb4c160680ab8057e1da93bd5c2d5a193b08 |
| authors | `svg/user/user_3_line.svg` | f65e74405906915ffcc74f967230d0455b9550cb9d3fb37baa30f66113940b04 |
| back | `svg/arrow/left_line.svg` | 21fc6455ec8f1a983c6d4f29e4f8596a38e5f92a1a43e3474fdf8c7506ab8c3e |
| bookmark | `svg/education/bookmark_line.svg` | b98bb0ca0a62864e8b0bb5c07357af21e946dd74d4f4ae080199c476f7b97f2e |
| check | `svg/system/check_line.svg` | b4046cadcd95d36ee78e8483993feb64a40104ac321963fc18eb7333ea53f527 |
| chevron_down | `svg/arrow/down_line.svg` | 119a1489593c9b8b4734c2cd9f6d4ad8fecc836b75a260184dee02c0f21a3733 |
| chevron_up | `svg/arrow/up_line.svg` | a02723d222c745cad5fa056ed046d474d702c57ffe6fd5d6627568adb56d9cfb |
| close | `svg/system/close_line.svg` | 1df696de405d227e55903d9e0a9993498e2ade56b753e721a07b1f546fcf9356 |
| download | `svg/arrow/arrow_to_down_line.svg` | e900789d498fa09dcbc44d3cfb8a83d5620ea2ee34b87aa3b3349d8a44e32870 |
| eye_off | `svg/system/eye_close_line.svg` | 16d86efac4e506390ed874428c44bd94fc838290d652683fcf4ddc8ab8817747 |
| filter | `svg/business/filter_line.svg` | 1b400d824025eee330cea0de4e507e34d4a7419a2dd71426156bfad7e46b9617 |
| folder | `svg/file/folder_2_line.svg` | 44b3344eacbd44ffeb25a44c56319ea06375dd3f4159c5c86e0a73dfa2bc6653 |
| folder_open | `svg/file/folder_open_line.svg` | f2d7c33a2b1b74bc242342071c6891d75ee61b920cb8bfc5ca3449cd2aee88fc |
| forward | `svg/arrow/right_line.svg` | f6c3944adb3e0a38318d37847be68aa483fe7bcff92a10259e76c36f05d755c3 |
| history | `svg/system/history_line.svg` | a8931865ced101b5e36acaed72f87ed2b3615e0664b79298694b6f4177f01f00 |
| home | `svg/building/home_3_line.svg` | 94ace508cea12bcbc5dc915635c9b2bd79f96e53eabfd8e4d1fc924f9b3fd551 |
| home_plus | `svg/file/pin_line.svg` | 9a30ac2e16b99049a996b60e7ee33544c6dab93ca4a1bbe48d6cb05a6c2ee8ee |
| info | `svg/system/information_line.svg` | 25fda94cd35fb5212a76f89877528101e5cc232b2c32197155967322f010db73 |
| layout | `svg/design/layout_2_line.svg` | bc428356441461834b9dd47581a6a3c507c4257100e8c623bfd5174d9e89bbc2 |
| library | `svg/education/book_2_line.svg` | 138e4c8e6ff26e2eebb2e6502c4bdf2a9b5a296c72aba98a3c649aaf537600e1 |
| list | `svg/editor/list_check_line.svg` | 9c5d07040d11f066514fd693daac7f399625afca7fa1f525d17e057bea4f510e |
| moon | `svg/weather/moon_line.svg` | 10fa027cf055bb860f75bfe9517dc2645c1a38c1d0471df9759f159fc750e4d1 |
| open_book | `svg/education/book_6_line.svg` | fc12ec86722b2aa8bada494dcc2773ebccbcc922794eb3c0f9d00f9d0a72cd9f |
| plugin_missing | `svg/design/border_blank_line.svg` | e53f82c65338cef62aed2b15c4e91b05e123de270a09966440bc948fc8ae5dc6 |
| plus | `svg/system/add_line.svg` | 070176b6dcebe8da0f462c65be1cbcd4a6b0530ed4a42c5810e41ce769e9a547 |
| power | `svg/system/power_line.svg` | 38ee1bb1690f55dd19012fae197c6bc76d1177b1b63b64914797d52aae3e23c0 |
| quick_settings | `svg/system/settings_6_line.svg` | aaf6d81476785b2c02bbec5b40fe9f3460948dc83accd5378d1a567e8ccd8759 |
| refresh | `svg/system/refresh_1_line.svg` | 557bc1d00ba9174a05ad3ed559f78bd819fb381d4aba6f7a3f00543a10e787e4 |
| rotation_lock | `svg/media/rotate_to_vertical_line.svg` | 4fc45c920b065decec47870cd9dd44ee3eef30773d69906789e65605627213f5 |
| screenshot | `svg/media/camera_2_line.svg` | 77d2a86ef119f1c02ba718972a92766a959c4c5a4e91c4b2653efe23530e137c |
| series | `svg/design/layer_line.svg` | 2ed9381ec7e00be3e260efc49d2338a8ee75d9ce231f20ebcfa6bdc9de1c8684 |
| settings | `svg/system/settings_3_line.svg` | 5e785a13c6a2fd98c41153d1ea68bc12c531f2eb476e7e9509c23397bd2ef584 |
| sort | `svg/editor/sort_descending_line.svg` | 64ccb1dfad92c897ed6d2b5dfb49b04c9188f7a2a90802a6739f2cf7eb4679d2 |
| sun | `svg/weather/sun_line.svg` | 1ba4a67eaf199777990db225e6f4f30688d2cbc00dbcbfad7e45e6d90a4a0b5f |
| sync | `svg/file/download_3_line.svg` | bf4fe330db2a0102f0b5ffc259933857a7a12cfe1bac3120f38cd362b752d928 |
| terminal | `svg/development/terminal_box_line.svg` | dfedad0bf8c773649792af2791e0e6ee075f1e3560d7491924020f7c43103eb6 |
| trash | `svg/system/delete_2_line.svg` | 3c400ece68be0be1d7600790c7271ebc5a32afe95005a5f4e1fde98efc61f266 |
| wifi | `svg/device/wifi_line.svg` | 8e253c13814b7571fb583f9b4ece4d8811b4b4040b83a862fc627c04b6d11a25 |
| wifi_off | `svg/device/wifi_off_line.svg` | f3961ea2ccaa5e8174873f46ca2c06528e5684bd0c9be8515eecd49f41558ba4 |
