# Planets Asset Catalog

Companion catalog to `docs/asset-inventory.md`, `docs/asset-wiki/external-swf-catalog.md`,
`docs/asset-wiki/loose-png-catalog.md`, and `docs/asset-wiki/loose-resources-catalog.md`.

Planet-related assets were previously scattered across all four of those documents.
This page consolidates every asset for all 14 planets into one place, organized by
planet, so a modder who wants to re-skin (say) Vexx can find every file that
touches Vexx in one spot instead of cross-referencing four catalogs.

## How planet art is actually used

`internal function planet_image(param1:int, param2:int):String` (`Gazillionaire.as`
~line 49971) is the only place that builds a planet-surface asset path at runtime,
by planet index (`param1`, 0–13) and a "variant" (`param2`):

| `param2` | Path built | Where it's shown | Status |
|---|---|---|---|
| 0 / omitted | `SWF/<PLANET>.SWF` (no suffix) | Planet-arrival view | **Live** — byte-identical to the planet's main-SWF `Gazillionaire_Planet<Name>1Class` icon and to the `resources/<PLANET>1.SWF` pre-build source (see "Three-way duplicate" below) |
| 2 | `SWF/<PLANET>2.SWF` | Turn-start view, via `frm_Travel6_image` (`Gazillionaire.as:52065`, the only call site, always passes `2`) | **Live** — the one variant actually reachable in-game beyond the arrival icon |
| 3 | `PNG/<PLANET>3.PNG` | Nothing — no caller ever passes `3` | **Dead code.** A "level 3" close-up PNG that shipped on disk but is unreachable in this build. |

### Three-way duplicate: main-SWF icon = level-1 SWF = resources-folder SWF

For every one of the 14 planets, the main-SWF-embedded `Gazillionaire_Planet<Name>1Class`
icon, the loose `SWF/<PLANET>.SWF` (level-1, variant 0), and the pre-build source
`resources/<PLANET>1.SWF` are the same bytes (`cmp`-confirmed for the resources-folder
copy in `loose-resources-catalog.md`; content-duplicated per `external-swf-catalog.md`).
Only **one** thumbnail is shown per planet for this trio below — the resources-folder
and level-1-SWF copies don't need a separate override, since overriding the main-SWF
icon already covers what they'd show.

Vexx and Tilo additionally have a second, decompiler-generated wrapper class
(`Gazillionaire__embed_mxml_VEXX1_SWF_1452207462` / `..._TILO1_SWF_1460587624`)
pointing at the exact same bytes — a `mxmlc` artifact, not a fourth distinct asset
(see `asset-inventory.md` finding 4).

## Planet table

| Planet | Lore | Icon (main-SWF class, = level-1 SWF, = resources-folder SWF) | Level-2 SWF (turn-start view) | Level-3 PNG (dead code) |
|---|---|---|---|---|
| **Vexx** (`planet_0`) | Capital planet, seat of the Imperial Magistrate | ![thumb](thumbnails/main-swf-embeds/139.png)<br>`Gazillionaire_PlanetVexx1Class` (char 139) | ![thumb](thumbnails/external-swf/vexx2.swf.png)<br>`VEXX2.SWF` | ![thumb](thumbnails/loose-png/vexx3.png)<br>`VEXX3.PNG` — ringed rocky/metallic planet |
| **Pyke** (`planet_1`) | L-Tech engine manufacturer world | ![thumb](thumbnails/main-swf-embeds/171_Gazillionaire_PlanetPyke1Class_dataClass.png)<br>`Gazillionaire_PlanetPyke1Class` (char 171) | ![thumb](thumbnails/external-swf/pyke2.swf.png)<br>`PYKE2.SWF` | ![thumb](thumbnails/loose-png/pyke3.png)<br>`PYKE3.PNG` |
| **Mira** (`planet_2`) | Capital of the Kukubian religion | ![thumb](thumbnails/main-swf-embeds/173_Gazillionaire_PlanetMira1Class_dataClass.png)<br>`Gazillionaire_PlanetMira1Class` (char 173) | ![thumb](thumbnails/external-swf/mira2.swf.png)<br>`MIRA2.SWF` | ![thumb](thumbnails/loose-png/mira3.png)<br>`MIRA3.PNG` |
| **Stye** (`planet_3`) | Financial hub, home of the Traders' Union | ![thumb](thumbnails/main-swf-embeds/105_Gazillionaire_PlanetStye1Class_dataClass.png)<br>`Gazillionaire_PlanetStye1Class` (char 105) | ![thumb](thumbnails/external-swf/stye2.swf.png)<br>`STYE2.SWF` | ![thumb](thumbnails/loose-png/stye3.png)<br>`STYE3.PNG` |
| **Loro** (`planet_4`) | Vacation / pleasure planet | ![thumb](thumbnails/main-swf-embeds/88_Gazillionaire_PlanetLoro1Class_dataClass.png)<br>`Gazillionaire_PlanetLoro1Class` (char 88) | ![thumb](thumbnails/external-swf/loro2.swf.png)<br>`LORO2.SWF` | ![thumb](thumbnails/loose-png/loro3.png)<br>`LORO3.PNG` |
| **Zile** (`planet_5`) | Mr. Zinn's home planet | ![thumb](thumbnails/main-swf-embeds/92_Gazillionaire_PlanetZile1Class_dataClass.png)<br>`Gazillionaire_PlanetZile1Class` (char 92) | ![thumb](thumbnails/external-swf/zile2.swf.png)<br>`ZILE2.SWF` | ![thumb](thumbnails/loose-png/zile3.png)<br>`ZILE3.PNG` |
| **Frac** (`planet_6`) | Voyager's Insurance headquarters | ![thumb](thumbnails/main-swf-embeds/133_Gazillionaire_PlanetFrac1Class_dataClass.png)<br>`Gazillionaire_PlanetFrac1Class` (char 133) | ![thumb](thumbnails/external-swf/frac2.swf.png)<br>`FRAC2.SWF` | ![thumb](thumbnails/loose-png/frac3.png)<br>`FRAC3.PNG` |
| **Tilo** (`planet_7`) | Gambler's planet | ![thumb](thumbnails/main-swf-embeds/148.png)<br>`Gazillionaire_PlanetTilo1Class` (char 148, + duplicate wrapper `Gazillionaire__embed_mxml_TILO1_SWF_1460587624`) | ![thumb](thumbnails/external-swf/tilo2.swf.png)<br>`TILO2.SWF` | ![thumb](thumbnails/loose-png/tilo3.png)<br>`TILO3.PNG` |
| **Queg** (`planet_8`) | Smuggler's haven | ![thumb](thumbnails/main-swf-embeds/125_Gazillionaire_PlanetQueg1Class_dataClass.png)<br>`Gazillionaire_PlanetQueg1Class` (char 125) | ![thumb](thumbnails/external-swf/queg2.swf.png)<br>`QUEG2.SWF` | ![thumb](thumbnails/loose-png/queg3.png)<br>`QUEG3.PNG` |
| **Xeen** (`planet_9`) | Junkyard / mechanic's planet | ![thumb](thumbnails/main-swf-embeds/138_Gazillionaire_PlanetXeen1Class_dataClass.png)<br>`Gazillionaire_PlanetXeen1Class` (char 138) | ![thumb](thumbnails/external-swf/xeen2.swf.png)<br>`XEEN2.SWF` | ![thumb](thumbnails/loose-png/xeen3.png)<br>`XEEN3.PNG` |
| **Ooom** (`planet_10`) | Fortune-teller's planet | ![thumb](thumbnails/main-swf-embeds/110_Gazillionaire_PlanetOoom1Class_dataClass.png)<br>`Gazillionaire_PlanetOoom1Class` (char 110) | ![thumb](thumbnails/external-swf/ooom2.swf.png)<br>`OOOM2.SWF` | ![thumb](thumbnails/loose-png/ooom3.png)<br>`OOOM3.PNG` |
| **Hork** (`planet_11`) | Media capital | ![thumb](thumbnails/main-swf-embeds/115_Gazillionaire_PlanetHork1Class_dataClass.png)<br>`Gazillionaire_PlanetHork1Class` (char 115) | ![thumb](thumbnails/external-swf/hork2.swf.png)<br>`HORK2.SWF` | ![thumb](thumbnails/loose-png/hork3.png)<br>`HORK3.PNG` |
| **Bass** (`planet_12`) | Stock-analyst playground | ![thumb](thumbnails/main-swf-embeds/85_Gazillionaire_PlanetBass1Class_dataClass.png)<br>`Gazillionaire_PlanetBass1Class` (char 85) | ![thumb](thumbnails/external-swf/bass2.swf.png)<br>`BASS2.SWF` | ![thumb](thumbnails/loose-png/bass3.png)<br>`BASS3.PNG` |
| **Nosh** (`planet_13`) | Fuel depot planet | ![thumb](thumbnails/main-swf-embeds/166_Gazillionaire_PlanetNosh1Class_dataClass.png)<br>`Gazillionaire_PlanetNosh1Class` (char 166) | ![thumb](thumbnails/external-swf/nosh2.swf.png)<br>`NOSH2.SWF` | ![thumb](thumbnails/loose-png/nosh3.png)<br>`NOSH3.PNG` |

### Resources-folder duplicates (not shown above — identical, no separate override)

Every planet also has a `resources/<PLANET>1.SWF` pre-build source file
(`BASS1.SWF`, `FRAC1.SWF`, `HORK1.SWF`, `LORO1.SWF`, `MIRA1.SWF`, `NOSH1.SWF`,
`OOOM1.SWF`, `PYKE1.SWF`, `QUEG1.SWF`, `STYE1.SWF`, `TILO1.SWF`, `VEXX1.SWF`,
`XEEN1.SWF`, `ZILE1.SWF`), `cmp`-confirmed byte-identical to the "Icon" column
above. Overriding the main-SWF icon class already covers these — there's no
separate asset here for a modder to touch.

### Overriding planet art

To re-skin a planet, a mod needs to replace at least:

1. The main-SWF icon class (`Gazillionaire_Planet<Name>1Class`, and for Tilo/Vexx
   also the duplicate wrapper class) — the arrival-view icon.
2. The level-2 `SWF/<PLANET>2.SWF` file — the turn-start view.

The level-3 `PNG/<PLANET>3.PNG` files are dead code in the current build and can
be left alone (or replaced for completeness/future-proofing, since they're real,
distinct art — just unreachable today).
