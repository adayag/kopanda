# Font sources

Every font file under `fonts/`, downloaded on 2026-10-14 from its family's upstream repository at the
commit named, unmodified. Each family's folder holds that repository's licence as `OFL.txt` (SIL Open
Font License 1.1). The files are static instances; none has an `fvar` table.

| File | Repository | Commit | Upstream path | SHA-256 |
| --- | --- | --- | --- | --- |
| `newsreader/Newsreader16pt-Medium.ttf` | github.com/productiontype/Newsreader | `cfcb4f7af0e52c25e8df2a2431814c8e5fe2e155` | `fonts/static/ttf/Newsreader16pt-Medium.ttf` | `ee2f66ee4c6c313acf211c952211f8c6c0c0d9fa6a17cd0ec0ceba13418b1aed` |
| `newsreader/Newsreader16pt-MediumItalic.ttf` | github.com/productiontype/Newsreader | `cfcb4f7af0e52c25e8df2a2431814c8e5fe2e155` | `fonts/static/ttf/Newsreader16pt-MediumItalic.ttf` | `a7e93b7f83811d96aaf9bdb5909f4b836c0990ffea45f074868ed081056e2276` |
| `newsreader/OFL.txt` | github.com/productiontype/Newsreader | `cfcb4f7af0e52c25e8df2a2431814c8e5fe2e155` | `OFL.txt` | `fdfad38143ec470553cae82a1e45320bdd1b9ec70415d37bd0171051d8a4ded8` |
| `ibm-plex-sans/IBMPlexSans-Regular.ttf` | github.com/IBM/plex | `39276912b05f700ee1dd491950c35d8697214208` | `packages/plex-sans/fonts/complete/ttf/IBMPlexSans-Regular.ttf` | `975dcda37d80f038dcd143c22e33ca2d97a0cc5a929aace1c749153b0fe1afa5` |
| `ibm-plex-sans/IBMPlexSans-Medium.ttf` | github.com/IBM/plex | `39276912b05f700ee1dd491950c35d8697214208` | `packages/plex-sans/fonts/complete/ttf/IBMPlexSans-Medium.ttf` | `331c8639d7598b2cde62a911a71db195e30cb655cd6bdf2e324a7e984955f907` |
| `ibm-plex-sans/OFL.txt` | github.com/IBM/plex | `39276912b05f700ee1dd491950c35d8697214208` | `packages/plex-sans/LICENSE.txt` | `7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da` |
| `bricolage-grotesque/BricolageGrotesque-Medium.ttf` | github.com/ateliertriay/bricolage | `84745e5b96261ae5f8c6c856e262fe78d1d6efdd` | `fonts/ttf/BricolageGrotesque-Medium.ttf` | `1dd2a3b41e0ce8eff2d9000ce8e79e8a5d9d2f0b22f4e27dc8c59e94894fe50a` |
| `bricolage-grotesque/BricolageGrotesque-Bold.ttf` | github.com/ateliertriay/bricolage | `84745e5b96261ae5f8c6c856e262fe78d1d6efdd` | `fonts/ttf/BricolageGrotesque-Bold.ttf` | `f83cb3f1ddb91bdb02868eeddb4f817b326aef993f96fe6f8a3b40b0f31c689b` |
| `bricolage-grotesque/BricolageGrotesque-ExtraBold.ttf` | github.com/ateliertriay/bricolage | `84745e5b96261ae5f8c6c856e262fe78d1d6efdd` | `fonts/ttf/BricolageGrotesque-ExtraBold.ttf` | `20ca28c496aef07993031176c1a02da6959682abbc4cbf73776f83e63ef80c00` |
| `bricolage-grotesque/OFL.txt` | github.com/ateliertriay/bricolage | `84745e5b96261ae5f8c6c856e262fe78d1d6efdd` | `OFL.txt` | `4b5a7d8f37f5602621c8a8d7358a6a2e71317e6c231c661e15aef0275d3e07ba` |
| `caveat/Caveat-Regular.ttf` | github.com/googlefonts/caveat | `59745e818ef7973e11e70cb1358d0e902b56c5fc` | `fonts/ttf/Caveat-Regular.ttf` | `7af58d70e539c9195cc328617a68c9961ed804a4404b0b818989ba7c013e8776` |
| `caveat/OFL.txt` | github.com/googlefonts/caveat | `59745e818ef7973e11e70cb1358d0e902b56c5fc` | `OFL.txt` | `1f9d81d094273d82f3898a1ee8b598a717d050ecbf5ff7bede105b704880157b` |

IBM Plex has no `OFL.txt`; its licence file is `LICENSE.txt` (the OFL 1.1 text with IBM's reserved
font name), shipped here as `ibm-plex-sans/OFL.txt`.

Bricolage Grotesque's static set in `fonts/ttf/` carries no optical-size label; it is taken to be the
14pt optical size, inferred from advance widths, not documented upstream. Newsreader ships static
instances at 6pt, 16pt and 72pt only; the 16pt one is used at every size.
