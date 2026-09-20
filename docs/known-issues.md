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

## Resolved: Zero-mod baseline compiles AND boots

The full 156-file decompiled tree recompiles cleanly with `node
tools/modloader/build.js` (Apache Flex 4.16.1 SDK — the exact version the
original shipped SWF was itself built with, confirmed via its
`ProductInfo` tag — with the HARMAN AIR SDK overlaid on top per
`tools/fetch-sdk.sh`; `-load-config+=air-config.xml -target-player=11.1`,
not `-target-player=AIR`). Two real code issues found and fixed along the
way:

- `GradientBarSkin.as` / `GradientTrackSkin.as` used the `mx_internal`
  namespace without importing/declaring it (`import mx.core.mx_internal;`
  + `use namespace mx_internal;`) — JPEXS doesn't reconstruct that
  automatically.
- Assets referenced by `Embed(source="assets/...")` must live under
  `engine/src/assets/`, not a sibling `engine/assets/` — Flex resolves
  relative Embed paths against the source file's directory.

**"Compiles cleanly" was true long before "boots" was.** For several
sessions, every recompiled build produced a valid SWF that opened a
correctly-sized native window and then either stayed permanently blank
or hung indefinitely — no crash, no error, nothing in any log. Three
unrelated real bugs, found and fixed together, all had to be present at
once to fully resolve it:

1. `engine/src/_Gazillionaire_FlexInit.as` — a `[Mixin]` class whose
   `init()` constructs `mx.managers.systemClasses.ChildManager`, which
   `SystemManager` requires before it will ever construct the document
   class — was missing (deleted during an earlier, since-abandoned
   approach and never restored), so the document class was never
   instantiated at all.
2. Compiling from a plain `.as` entry point (instead of `.mxml`) silently
   breaks Flex's SWF frame1/frame2 splitting — the app's own preloader
   (`CustomPreloader`) ended up compiled into the same huge frame as the
   ~106K-line `Gazillionaire` class instead of the small frame that loads
   first, a chicken-and-egg deadlock where the preloader can't run until
   the frame it's meant to show progress for has already fully loaded.
   Fixed with `[Frame(factoryClass="_Gazillionaire_mx_managers_SystemManager")]`
   metadata directly on the `Gazillionaire` class (a real, non-MXML-only
   AS3 compiler feature) — `factoryClass` must point at the decompiled,
   hand-maintained per-app `SystemManager` subclass (which already
   references `CustomPreloader` in its `info()`), not the generic
   `mx.managers.SystemManager`.
3. `mx.core.TextFieldFactory` is referenced only reflectively inside the
   Flex framework's own `SystemManager.kickOff()`
   (`getDefinitionByName(...)`), so `mxmlc`'s dead-code elimination
   silently dropped it from every build since nothing in this project's
   source imports it statically. At runtime this threw inside an
   `Event.ENTER_FRAME` handler — a dispatch context where AIR does not
   surface exceptions via `UncaughtErrorEvent` — permanently stalling
   Flex's `LayoutManager` with zero visible symptom besides steady CPU
   and no progress. Fixed with `-includes=mx.core.TextFieldFactory` in
   `tools/modloader/build.js`'s `mxmlc` invocation.

Confirmed working end-to-end on the real Steam install, both with zero
mods and with a mod enabled: full boot to the actual game menu, and the
mod loader's status overlay (mod count / build hash / validation state)
renders correctly during loading.

## Resolved: build cache didn't account for `engine/src` changes

`tools/modloader/mods.js`'s `computeCacheKey()` used to hash only the
enabled mods' own files — not `engine/src`. Any change to the engine
(a bugfix, a decompile cleanup, anything) left old `build/merged-src/`
cache entries silently valid for whatever mod set matched their key, so
a mod-enabled build could serve stale engine code under a reported cache
"hit" after an engine change. Fixed: `computeCacheKey()` now also hashes
every file under `engine/src` into the key.

## Resolved: installer `restore` left Info.plist/application.xml patched

`tools/installer/install.sh install` patches `Info.plist`
(`NSSupportsAutomaticTermination`/`NSSupportsSuddenTermination`) and
`application.xml` (`<visible>`) as part of installing. `restore` only
ever reverted the SWF itself, leaving those two patches in place
afterward — so "restore" didn't actually return the app bundle to its
original state. Fixed: `restore` now also reverts both patches
(`unpatch_info_plist_if_macos`, `unpatch_visible_if_macos`), verified via
a full install→restore round-trip diffed against the pristine backup.

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
