# Asset Wiki

This is the catalog of every named, findable asset in the game — every planet,
HUD icon, GUI chrome element, background, logo, ship, alien/NPC, opponent
portrait, planet-surface SWF, cutscene, and sound effect that was pulled out of
the compiled game and cross-referenced against the decompiled source
(`engine/src/*.as`). Use it to find your asset: look it up by name or category
in the tables below or in one of the five detail docs, note the file path
listed for it, and follow `docs/modding-guide.md` to override it in your own
mod. Every asset below can be overridden — see `docs/modding-guide.md`'s
`assets/`/`loose-assets/` sections for how, depending on which kind it is
(noted in each catalog's "Overridable today?" column). The thumbnail images
throughout this wiki and its companion docs are the original game's
copyrighted art, extracted here for cataloging purposes only — the same
precedent already established for the checked-in originals under
`engine/src/assets/`.

## Summary

| Category | Count | Where cataloged | Overridable today? |
|---|---|---|---|
| Main-SWF embedded assets (planets, HUD icons, GUI chrome, backgrounds, logo) | 98 table rows / 82 distinct files | [`asset-inventory.md`](asset-inventory.md) | **Yes** — `mods/<mod>/assets/<path>` overlay (`[Embed]`-based, see `docs/modding-guide.md`) |
| External SWFs (ships, named NPCs/aliens, planet-surface art, cutscenes, title/splash screens) | 156 files | [`asset-wiki/external-swf-catalog.md`](asset-wiki/external-swf-catalog.md) | **Yes** — `mods/<mod>/loose-assets/SWF/<name>.png`\|`.gif` overlay (v0.5.1, see `docs/modding-guide.md`) |
| Loose PNGs (opponent/rival portraits, orphaned level-3 planet art, misc splash art) | 30 files | [`asset-wiki/loose-png-catalog.md`](asset-wiki/loose-png-catalog.md) | **Yes** — `mods/<mod>/loose-assets/PNG/<name>.png` overlay |
| Loose pre-build resources (leftover source-art duplicates + fuel-gauge-gap fix candidates) | 60 files | [`asset-wiki/loose-resources-catalog.md`](asset-wiki/loose-resources-catalog.md) | **N/A** — not loaded by the shipped game at all; 51/60 are duplicates of assets already overridable via the main-SWF channel above, the rest are gap-fix candidates or orphaned cut content (see Known gaps) |
| Loose MP3s (sound effects, voice lines, per-planet/commodity jingles) | 175 files | [`asset-wiki/loose-mp3-catalog.md`](asset-wiki/loose-mp3-catalog.md) | **Yes** — `mods/<mod>/loose-assets/MP3/<name>.mp3` overlay (plain passthrough, no conversion) |

## Detail docs

- **[`asset-inventory.md`](asset-inventory.md)** — the 98 classes `[Embed]`-ed
  directly into the compiled `Gazillionaire.swf`: planets, HUD icons, GUI
  chrome (window buttons, fuel gauge, close-X buttons), backgrounds, and the
  loading-screen logo. Every row now has a thumbnail.
- **[`asset-wiki/external-swf-catalog.md`](asset-wiki/external-swf-catalog.md)**
  — the 156 loose `.swf` files under `Resources/SWF/`: ship art, named
  alien/NPC characters, planet-surface environment art, cutscenes, and title
  screens. Has thumbnails.
- **[`asset-wiki/loose-png-catalog.md`](asset-wiki/loose-png-catalog.md)** —
  the 30 loose `.png` files under `Resources/PNG/`: the six opponent/rival
  portraits (`OP1`-`OP6`), their unused alt-expression variants
  (`OP1A`-`OP6A`), 14 unreachable "level 3" planet variants, and two orphaned
  branding images. Has thumbnails.
- **[`asset-wiki/loose-resources-catalog.md`](asset-wiki/loose-resources-catalog.md)**
  — the 60 files under the lowercase `Resources/resources/` folder: leftover
  pre-build source art, mostly duplicates of files already covered by
  `asset-inventory.md`, plus the two fuel-gauge-gap fix candidates and a
  handful of genuinely orphaned files. Has thumbnails.
- **[`asset-wiki/loose-mp3-catalog.md`](asset-wiki/loose-mp3-catalog.md)** —
  all 175 `.mp3` sound files under `Resources/MP3/`: UI sounds, gameplay SFX,
  voice lines, per-planet ambience, and per-commodity jingles. No thumbnails
  (not applicable to audio).
- **[`asset-wiki/planets-catalog.md`](asset-wiki/planets-catalog.md)** — all
  14 planets' assets in one place: the main-SWF icon, the level-2 turn-start
  SWF, the dead-code level-3 PNG close-up, and the resources-folder
  duplicate, organized by planet name instead of by source-file type.
  Previously scattered across `asset-inventory.md`,
  `asset-wiki/external-swf-catalog.md`, `asset-wiki/loose-png-catalog.md`,
  and `asset-wiki/loose-resources-catalog.md` — those four docs now just
  point here for planet rows.

## Known gaps

Consolidated from all five catalog passes, so a maintainer doesn't have to
reread every doc to see what's still open:

1. **Fuel-gauge fill-bar gap — fix candidate found, not yet confirmed.**
   `asset-inventory.md` finding #5 identified two CSS classes
   (`fuelFillBlue`/`fuelFillRed`, wired at `Gazillionaire.as` ~76273-76315)
   with no `[Embed]` tag and no recoverable file — the fuel gauge's "filling"
   state has no overridable asset. `asset-wiki/loose-resources-catalog.md`
   found `f_fillblue.png` and `f_fillred.png` in the leftover pre-build
   `resources/` folder: filename and visual appearance (gradient bars in the
   right colors) strongly suggest these are the missing art, but there's
   nothing to byte-diff against, so this is a **candidate fix pending
   maintainer confirmation**, not yet wired into `engine/src/assets/`.

2. **Orphaned files found across the loose-asset passes** (present on disk,
   no reachable code path in the decompiled `Gazillionaire.as`):
   - `BANK2_N.SWF` (external SWF catalog) — an alien-NPC swf with no
     reference anywhere.
   - `OP1A.PNG`-`OP6A.PNG` (loose PNG catalog) — alt-expression variants of
     the six opponent portraits; every code path builds `"PNG/OP" + n +
     ".PNG"` with no `"A"` suffix ever appended.
   - The 14 `<PLANET>3.PNG` "level 3" planet variants (loose PNG catalog) —
     returned only by a dead branch of `planet_image()`.
   - `i_pay.png` and `i_study.png` (loose resources catalog) — cut UI icons
     with no embed class or reference anywhere; likely planned-but-unbuilt
     features.
   - 10 orphaned MP3s (loose MP3 catalog): `BEGIN.MP3`, `CATACOM3.MP3`,
     `COINS.MP3`, `EMAIL.MP3`, `LAVAMIND.MP3`, `MENTAL.MP3`, `PING2.MP3`,
     `PING4.MP3`, `SPIKE2.MP3`, `ZAP.MP3`.

3. **Resolved (v0.5.1): loose SWF/PNG/MP3 assets now have an override
   mechanism.** The three loose-file channels (external SWFs, loose PNGs,
   loose MP3s — 361 files total) are loaded by the game at runtime via
   filesystem path (literal strings like `"./SWF/BANDITS.SWF"` or built
   dynamically, e.g. `"SWF/" + baseName + suffix + ".SWF"`), not via AS3
   `[Embed]`, so the pre-existing `mods/<mod>/assets/<path>` overlay never
   reached them. A new `mods/<mod>/loose-assets/` overlay closes this: a
   modder drops a PNG or (looping) GIF at the mirrored `Resources/`-relative
   path, `tools/modloader/build.js` converts it (auto-fit to the original's
   dimensions; for SWF targets, synthesizes a fresh flipbook SWF via
   `ffdec swf2xml`/`xml2swf`, honoring the GIF's loop-count metadata), and
   `tools/installer/install.sh` backs up and deploys the result into
   `Resources/SWF|PNG|MP3/` alongside the existing main-SWF patch. See
   `docs/superpowers/specs/2026-09-20-modder-asset-pipeline-design.md` for
   the full design and `docs/modding-guide.md` for the modder-facing
   how-to.

4. **Ships now have overridable art.** There is still no `Ship*Class.as` in
   the decompiled source and the 12 ship-selection buttons are still plain
   styled Flex `Button`s with no `[Embed]`-based icon — but the `SHIP*.SWF`
   files in the external SWF catalog (the actual ship art, loaded by
   filesystem path) are covered by the gap-3 fix above, so a modder can
   already replace ship art via `loose-assets/SWF/SHIP<N>.png`\|`.gif`
   without any `Gazillionaire.as` change.
