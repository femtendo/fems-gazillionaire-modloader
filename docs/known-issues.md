# Known issues

Tracks classes or systems that don't survive the decompile/recompile
round-trip cleanly, and any workarounds in place for them.

## HUMAN REQUIRED: Windows installer path is untested

`tools/installer/install.sh` hardcodes a macOS `DEFAULT_TARGET` (Steam's
`Gazillionaire.app/Contents/Resources/Gazillionaire.swf` layout) but
accepts `--target <path>` to point at any SWF, so it should work on
Windows by passing the Windows Steam install path. This has **never been
run against a real Windows install** — no Windows machine/Steam install is
available in this environment to verify it. Someone with a Windows machine
needs to: run `install.sh install --target "<path>\Gazillionaire.swf"`
against a real Windows Gazillionaire install, confirm hash verification /
backup / patch all work, then `install.sh restore --target ...` to confirm
restore. Until that happens, treat Windows support as unverified, not
broken.

## Resolved: Zero-mod baseline compiles

The full 156-file decompiled tree recompiles cleanly with `node
tools/modloader/build.js` (Apache Flex 4.6.0 SDK, which bundles its own
AIR profile — `-load-config+=air-config.xml -target-player=11.1`, not
`-target-player=AIR`). Two real code issues found and fixed along the way:

- `GradientBarSkin.as` / `GradientTrackSkin.as` used the `mx_internal`
  namespace without importing/declaring it (`import mx.core.mx_internal;`
  + `use namespace mx_internal;`) — JPEXS doesn't reconstruct that
  automatically.
- Assets referenced by `Embed(source="assets/...")` must live under
  `engine/src/assets/`, not a sibling `engine/assets/` — Flex resolves
  relative Embed paths against the source file's directory.

## Resolved: "Unresolved Asset Embeds" (formerly below)

The 42 classes below carried a class-level
`[Embed(source="/_assets/assets.swf", symbol="symbolNN")]` tag that
mxmlc couldn't resolve (no `assets.swf` library exists). Turned out to be
harmless: every one of these wrapper classes overrides `movieClipData`
(or is a no-op `SpriteAsset`) and loads its real bytes from a sibling
`_dataClass` companion class instead — that companion already embeds an
individually-exported, standalone per-symbol SWF/PNG from
`engine/src/assets/`. The class-level `assets.swf` tag was vestigial
metadata from the original compiled symbol registration, not something
the runtime path actually used. Fix: deleted that one metadata line from
each of the 42 wrapper classes; no behavior change for classes with a
`_dataClass` companion.

Exception: a handful of `_class_embed_css_f_*` classes (solid-color fill
sprites, e.g. `_class_embed_css_f_fillblue_png__944102544_696470983.as`)
have no `_dataClass` companion and no logic at all — they're now
functionally blank placeholder `SpriteAsset`s (minor color-fill UI
element, not game logic). Revisit with real asset content if it turns out
visible in-game.

Originally affected files (kept for reference):

- `Gazillionaire_PlanetBass1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetFrac1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetHork1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetLoro1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetMira1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetNosh1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetOoom1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetPyke1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetQueg1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetStye1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetTilo1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetVexx1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetXeen1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire_PlanetZile1Class.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_Frame_help3_swf_987142362.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_TILO1_SWF_1460587624.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_VEXX1_SWF_1452207462.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_b_circle_swf_437016774.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_i_arrow_swf_203146964.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_i_planet_swf_630432904.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_i_target_swf_976591674.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_stars_bg_main_swf_835323288.as` — embeds `symbol90` from `assets.swf`
- `Gazillionaire__embed_mxml_stars_main_swf_1623989498.as` — embeds `symbol90` from `assets.swf`
- `_class_embed_css_Assets_swf_976127064___brokenImage_658189327.as` — embeds `symbol10` from `assets.swf`
- `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_BusyCursor_487872263.as` — embeds `symbol47` from `assets.swf`
- `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_DragCopy_806051697.as` — embeds `symbol22` from `assets.swf`
- `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_DragLink_806313702.as` — embeds `symbol28` from `assets.swf`
- `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_DragMove_806339277.as` — embeds `symbol34` from `assets.swf`
- `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_DragReject_681200837.as` — embeds `symbol33` from `assets.swf`
- `_class_embed_css_b_x2_dn_swf_77392359_80761093.as` — embeds `symbol100` from `assets.swf`
- `_class_embed_css_b_x2_mo_swf_335978239_175555539.as` — embeds `symbol140` from `assets.swf`
- `_class_embed_css_b_x2_up_swf_565934968_340354117.as` — embeds `symbol103` from `assets.swf`
- `_class_embed_css_b_x2_up_swf_565934968_340354118.as` — embeds `symbol102` from `assets.swf`
- `_class_embed_css_b_x3_dn_swf_1820202694_745722986.as` — embeds `symbol89` from `assets.swf`
- `_class_embed_css_b_x3_mo_swf_2078788574_683813778.as` — embeds `symbol157` from `assets.swf`
- `_class_embed_css_b_x3_up_swf__1986221993_1815107817.as` — embeds `symbol160` from `assets.swf`
- `_class_embed_css_f_empty_swf__416068855_1574736089.as` — embeds `symbol151` from `assets.swf`
- `_class_embed_css_f_endblue_swf_1667013489_1828896639.as` — embeds `symbol150` from `assets.swf`
- `_class_embed_css_f_endred_swf_735613634_1127775762.as` — embeds `symbol116` from `assets.swf`
- `_class_embed_css_f_fillblue_png__944102544_696470983.as` — embeds `symbol7` from `assets.swf`
- `_class_embed_css_f_fillred_png_97191697_987149254.as` — embeds `symbol4` from `assets.swf`
- `_class_embed_css_f_full_swf_392505595_2100659351.as` — embeds `symbol146` from `assets.swf`
