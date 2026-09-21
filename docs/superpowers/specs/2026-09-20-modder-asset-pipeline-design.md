# Modder asset-upload pipeline (v0.5.1)

## Problem

A modder should be able to supply a plain PNG or an animated GIF for any
asset in `docs/asset-wiki.md` and have it show up in-game, without knowing
Flash/AS3 or hand-authoring a SWF. Two structurally different asset
channels exist (both fully cataloged this session, see `docs/asset-wiki.md`
and its linked catalogs):

1. **Main-SWF `[Embed]` assets** (`docs/asset-inventory.md`) — compiled
   into `Gazillionaire.swf` itself. Already overridable today: a mod drops
   a same-named file under `mods/<mod>/assets/`, and `tools/modloader/build.js`
   overlays it onto `engine/src/assets/` before `mxmlc` compiles. Most are
   raster PNG (trivial passthrough, no new work needed); ~30 are SWFs saved
   with non-`.swf` extensions (planet icons, GUI chrome, fuel-gauge track
   states, and the just-recovered cursor art) — vector content, needs the
   conversion step below.
2. **Loose runtime-loaded files** (`docs/asset-wiki/external-swf-catalog.md`,
   `loose-png-catalog.md`, `planets-catalog.md`) — never compiled in at
   all. Loaded at runtime by literal or dynamically-constructed relative
   path (e.g. `"./SWF/SHIP1.SWF"`, `"PNG/OP" + n + ".PNG"`) from
   `mx.controls.Image` components in `engine/src/Gazillionaire.as`. **Zero
   override mechanism exists today** — `tools/installer/install.sh` only
   backs up and patches `Gazillionaire.swf`; it never touches
   `Resources/SWF/`, `Resources/PNG/`, or `Resources/MP3/`. This is where
   ship art (24 files) and nearly all named NPCs/aliens (88 files) live.

## Goals

- A modder supplies a PNG (static targets) or GIF (animated targets) named
  to match the wiki-cataloged asset, drops it under a new mirrored folder
  in their mod, and the build produces correct, working output — no manual
  dimension lookup, no SWF authoring.
- Both channels above get one shared conversion core.
- Arbitrary-length, looping GIFs are supported (spinning planets, breathing
  idle NPCs), and a modder can pair a longer animation with a longer
  replacement audio clip for talking characters (e.g. Zinn) — confirmed
  via code reading that the game does not frame-lock animation to audio
  (`frm_ZinnLoan_load()`, `Gazillionaire.as:54334-54352`: image `.source`
  and `playSoundNoLoop()` fire independently, no `ENTER_FRAME`/
  `SoundChannel.position` sync exists anywhere), so this is honest to how
  the original game already behaves.

## Non-goals

- No new input formats beyond static PNG and animated GIF (no APNG, WebP,
  MP4 — YAGNI, matches the explicit ask).
- No attempt to make loose-file and `[Embed]` assets share one on-disk mod
  folder structure beyond both being mirrored-path overlays — they're
  different mechanisms (compile-time vs. install-time) and should stay
  visibly distinct to a modder reading their own mod folder.
- Not touching sound *effects* volume/mixing, only file replacement.

## Design

### Conversion core: template-reuse via `ffdec -importImages`/`-importSprites`

For every SWF-shaped target (vector `[Embed]` assets and all loose
`SWF/` files), the **original asset being overridden is the template**.
Conversion is: decode the modder's image/GIF frames to raw bitmaps, then
run `ffdec -importImages`/`-importSprites <template> <output> <frames-dir>`
to inject them into a copy of the template — same character IDs, same
stage/frame structure, new pixels. No hand-rolled SWF encoder; `ffdec`
already solves the hard part (confirmed working via `-help importImages`/
`-help importSprites` this session).

Pure-raster targets (main-SWF PNG embeds, loose `PNG/` files) need no
conversion — direct passthrough, same as today.

### Dimension handling: auto-fit, not modder-provided

The modder never needs to know or look up pixel dimensions. The pipeline
resizes their image (and every GIF frame) to the template's stage size
automatically: preserve aspect ratio, pad transparent. Only a genuinely
unreadable/corrupt input file fails the build.

### Animation: arbitrary frame count, loop-metadata honored

No frame-count cap and no requirement to match the original animation's
length — a modder's GIF can be longer or shorter than the asset it
replaces. GIF per-frame delay is read from the GIF's own timing metadata;
each decoded frame is replicated enough times at the output SWF's frame
rate (defaulting to the template's own frame rate) to approximate the
GIF's real timing. GIF loop-count metadata (0 = infinite, N = play N
times, absent = play once) is translated directly into the synthesized
SWF's timeline: infinite loop → no terminal `stop()` (a Flash MovieClip
timeline wraps to frame 1 by default); finite/single-play → a `stop()` (or
N-times `gotoAndPlay(1)`) baked onto the last frame. No new modder-facing
concept — this is exactly how GIF loop count already works in every tool
that exports one.

### Paired audio override

Loose `MP3/` files (cataloged in `docs/asset-wiki/loose-mp3-catalog.md`)
get the same mirrored-path overlay treatment as loose SWF/PNG files —
plain passthrough, no conversion (the engine loads MP3 directly). This
lets a modder replacing, say, `ZINN2_N.SWF` with a longer talking
animation also drop a longer `ZINN.MP3` in the same mod; both fire
together at the same trigger point as today, not frame-locked (matching
the original game's own behavior, see Goals above).

### Mod-facing layout

New `loose-assets/` folder in a mod, mirroring the `Resources/` path being
overridden — same mental model as the existing `assets/` overlay for
`[Embed]` assets, just a second folder for the second channel:

```
mods/my-ship-mod/
  mod.json
  assets/                  <- existing: [Embed] compiled-in overrides
    158_...i_money_png....png
  loose-assets/            <- new: runtime-loaded file overrides
    SWF/
      SHIP1.gif             <- animated, becomes SHIP1.SWF
      SHIP3.png             <- static, becomes SHIP3.SWF
    PNG/
      OP1.png                <- opponent portrait override
    MP3/
      ZINN.mp3                <- paired audio override
```

`mod.json` gets a new `touches.looseAssets` array, validated both
directions exactly like `touches.assets` today (declared-but-missing and
present-but-undeclared are both build errors — see `validateTouches()` in
`tools/modloader/mods.js`), and participates in the same
priority/conflict detection as every other touch kind.

### Build-time wiring

New module `tools/modloader/loose-assets.js`:
- Runs the conversion described above for both `mods/<mod>/assets/`
  (vector `[Embed]` targets — output feeds `merged-src/.../assets/`,
  same tree `build.js` already assembles) and the new
  `mods/<mod>/loose-assets/` (output goes to a new `build/output/loose-assets/`
  tree, mirroring `Resources/`'s own subfolder layout).
- Requires `ffmpeg` on `PATH` for GIF frame extraction (Node has no
  built-in animated-image decoder, and this toolchain currently has no
  `package.json`/npm dependency at all — `ffmpeg` is a new documented
  build prerequisite, same tier as Java/`mxmlc` today, not a new npm
  package). PNG dimension reading needs no library — PNG width/height are
  fixed-offset big-endian integers right after the 8-byte signature +
  `IHDR` chunk header, read directly with a small buffer-read helper.

### Install-time wiring

`tools/installer/install.sh` gets a new responsibility: back up and
replace files under `Resources/SWF/` and `Resources/PNG/` (and `MP3/`)
from `build/output/loose-assets/`, mirroring the existing
`Gazillionaire.swf` backup/replace/resign discipline exactly (see
`resign_app_bundle_if_macos()` — same macOS code-signing-seal concern
applies to any file inside the `.app` bundle, not just the main SWF).
`restore` reverses these the same way it reverses the main SWF patch.

## Testing

One self-check per non-trivial piece, no framework:
- A `demo()`/assert script that synthesizes a SWF from a known sample PNG
  + a real template, then confirms via `ffdec -export symbolClass` that
  the output's character IDs and stage dimensions match the template
  exactly (structural correctness, not pixel-perfect comparison).
- A test that an intentionally corrupt/unreadable input file aborts the
  build with a clear error rather than producing bad output.
- A test that a GIF with `loopCount=0` produces a SWF with no terminal
  `stop()` and one with `loopCount=1` produces one that does.
- Installer: a dry-run test that backup → replace → restore round-trips
  a loose file back to its original bytes exactly (same pattern the
  existing SWF installer test presumably already uses — check
  `tests/` for the existing convention and match it).

## Open items (not blocking, but worth tracking)

- Whether `mx.controls.Image` can load raw PNG bytes at a path ending in
  `.SWF` (content-sniffed by header, not extension) was raised earlier
  as a possible shortcut and explicitly **rejected** in favor of always
  producing real SWF bytes via the template-reuse approach — this avoids
  depending on unconfirmed Flash `Loader` behavior. Noted here so a future
  reader doesn't wonder why that shortcut isn't used.
- `docs/asset-wiki-plan.md`'s Step 2.2 sketched a narrower "ship art only"
  version of this before the full asset picture was known (loose SWF/PNG/MP3
  channels, the cursor-art recovery, planet consolidation). This spec
  supersedes it for scope; Step 2.2 can be marked historical.
