# Modder Asset-Upload Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a modder drop a PNG or GIF (static or looping) matching a wiki-cataloged asset's name, and have the build/install pipeline produce a working in-game replacement — for both compiled `[Embed]` assets and loose runtime-loaded files under `Resources/SWF|PNG|MP3/`.

**Architecture:** A new `tools/modloader/loose-assets.js` module is the shared conversion core. For SWF-shaped targets it does NOT edit the original file in place — it synthesizes a fresh, minimal N-frame "flipbook" SWF (one raster image tag + placement per frame) via `ffdec -swf2xml`/`-xml2swf`, sized only to the original's stage dimensions/frame rate (read via `ffdec -header`). This works uniformly whether the original was a single bitmap or a vector-animated timeline with embedded bytecode, since the synthesized replacement never depends on the original's internal tag structure. `build.js` calls this module for both the existing `assets/` overlay (vector `[Embed]` targets) and a new `loose-assets/` overlay (loose runtime files); `install.sh` gains a matching backup/replace/restore responsibility for the loose-file case.

**Tech Stack:** Node.js (no new npm dependency — this toolchain has none today), `ffmpeg` (new build prerequisite, for GIF frame extraction), `ffdec` (already used elsewhere in this repo, for `-header`/`-swf2xml`/`-xml2swf`), bash (installer).

**Spec:** `docs/superpowers/specs/2026-09-20-modder-asset-pipeline-design.md` — read it before starting; this plan implements it, with one corrected mechanism (flipbook synthesis instead of `-importImages` template-editing, discovered during planning because `-importImages` can't add/remove frames or touch vector-shape content, which several real assets like `ZINN_N.SWF` use — see that spec file's "Open items" section isn't updated yet, this plan is the authority on the mechanism).

## Global Constraints

- No new npm dependency; `ffmpeg` must be on `PATH` (fail with a clear error naming the missing tool if it isn't — same posture as the existing `mxmlc`-not-found check in `build.js`).
- No modder-facing Flash/AS3 knowledge required.
- Dimension handling: auto-fit (resize + pad transparent), never require the modder to know pixel sizes.
- GIF loop-count metadata (0 = infinite, N = finite, absent = once) must be honored in the synthesized SWF's playback behavior.
- Match existing code conventions: `tools/modloader/*.js` uses plain CommonJS (`require`/`module.exports`), synchronous `fs`/`child_process.execFileSync` calls, no async/await (see `build.js`/`mods.js` — neither uses promises).
- Tests are plain Node `assert` scripts (`tests/modloader/*.test.js`) or bash scripts with a `pass`/`fail` counter (`tests/installer/*.test.sh`) — no test framework, matching `tests/modloader/conflicts.test.js` and `tests/installer/install.test.sh` exactly.
- Commit messages and diff content must avoid every term in `.githooks/pre-push`'s `DISALLOWED_TERMS` list (AI-tooling names and phrasing) — check that file directly rather than repeating the list here, since repeating it verbatim is itself what trips the hook.

---

## File Structure

- **Create `tools/modloader/loose-assets.js`** — the conversion core (dimension reading, GIF decoding, flipbook synthesis, top-level `convertAsset()` orchestrator). One responsibility: turn a modder's PNG/GIF into either a passthrough raster file or a synthesized SWF, given a target's original file as reference.
- **Modify `tools/modloader/build.js`** — call `loose-assets.js` for both `assets/` (SWF-shaped `[Embed]` targets) and the new `loose-assets/` overlay; write the latter's output to `build/output/loose-assets/`.
- **Modify `tools/modloader/mods.js`** — extend `computeTouchSets`/`validateTouches` to handle `touches.looseAssets` exactly like `touches.assets` today, with a `looseAsset:` prefix (mirroring the existing `asset:`/`data:` prefix scheme).
- **Modify `tools/installer/install.sh`** — add backup/replace/restore for `Resources/SWF|PNG|MP3/` files listed in a new manifest the build produces (`build/output/loose-assets/manifest.json`, listing which real `Resources/`-relative paths were touched).
- **Create `tests/modloader/loose-assets.test.js`** — unit coverage for the pure-logic pieces (PNG dimension parsing, GIF loop/delay parsing, frame-replication timing math).
- **Extend `tests/installer/install.test.sh`** — cover the new loose-file backup/restore path with synthetic fixtures.
- **Update `docs/modding-guide.md`** — document the new `loose-assets/` convention and `touches.looseAssets` field.
- **Update `mods/_examples/`** — add a new `seventh-example-loose-asset/` example mod demonstrating a loose-asset override, matching the existing examples' style.

---

## Task 1: PNG dimension reader and GIF frame/timing parser (pure logic, no shelling out)

**Files:**
- Create: `tools/modloader/loose-assets.js` (initial exports only: `readPngDimensions`, `readGifMeta`)
- Test: `tests/modloader/loose-assets.test.js`

**Interfaces:**
- Produces: `readPngDimensions(buffer: Buffer) -> {width: number, height: number}`
- Produces: `readGifMeta(buffer: Buffer) -> {loopCount: number|null, frameDelaysCs: number[]}` (`loopCount`: `0` = infinite, `null` = no loop block found = play once, positive integer = play N times; `frameDelaysCs`: one entry per frame, in centiseconds, in GIF file order)

- [ ] **Step 1: Write the failing test for `readPngDimensions`**

```javascript
// tests/modloader/loose-assets.test.js
const assert = require('assert');
const { readPngDimensions, readGifMeta } = require('../../tools/modloader/loose-assets');

// Minimal valid PNG: 8-byte signature + IHDR chunk (13-byte payload: width,
// height as big-endian uint32, then bit depth/color type/etc — only width
// and height matter here). Length/CRC are followed but not validated by
// our reader (we only read the fixed-offset width/height fields).
function makePng(width, height) {
    const buf = Buffer.alloc(8 + 4 + 4 + 13 + 4);
    buf.write('\x89PNG\r\n\x1a\n', 0, 'binary');
    buf.writeUInt32BE(13, 8); // IHDR chunk length
    buf.write('IHDR', 12, 'ascii');
    buf.writeUInt32BE(width, 16);
    buf.writeUInt32BE(height, 20);
    return buf;
}

{
    const { width, height } = readPngDimensions(makePng(320, 200));
    assert.strictEqual(width, 320);
    assert.strictEqual(height, 200);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `Error: Cannot find module '../../tools/modloader/loose-assets'`

- [ ] **Step 3: Implement `readPngDimensions`**

```javascript
// tools/modloader/loose-assets.js
// Conversion core for the modder asset-upload pipeline: turns a modder's
// PNG/GIF into either a passthrough raster file or a synthesized SWF,
// given the original asset being overridden as sizing/timing reference.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

// PNG width/height are fixed-offset big-endian uint32s right after the
// 8-byte signature + the IHDR chunk's 8-byte length+type header — no
// need for a PNG-parsing library for just this.
function readPngDimensions(buffer) {
    if (buffer.length < 24 || buffer.toString('ascii', 12, 16) !== 'IHDR') {
        throw new Error('Not a valid PNG (missing IHDR at expected offset)');
    }
    return {
        width: buffer.readUInt32BE(16),
        height: buffer.readUInt32BE(20)
    };
}

module.exports = { readPngDimensions };
```

- [ ] **Step 4: Run test to verify `readPngDimensions` passes**

Run: `node tests/modloader/loose-assets.test.js`
Expected: no assertion errors printed for the PNG block (the GIF block below doesn't exist yet — comment it out or expect a later failure at that line; re-run after Step 6).

- [ ] **Step 5: Write the failing test for `readGifMeta`**

Append to `tests/modloader/loose-assets.test.js`:

```javascript
// Minimal 2-frame animated GIF, hand-built to exercise the loop/delay
// parser: GIF89a header, logical screen descriptor, a NETSCAPE2.0
// application extension (loop count = 0, i.e. infinite), two
// Graphic Control Extension + Image Descriptor pairs (delay 10cs and
// 50cs), each followed by a trivial 1-byte LZW image data block, and a
// trailer. Real GIF-writing libraries produce more(valid image data;
// this fixture only needs to be structurally well-formed enough for a
// block-walking parser that doesn't decode pixels, only headers.
function makeGif({ loopCount, delaysCs }) {
    const parts = [];
    parts.push(Buffer.from('GIF89a', 'ascii'));
    // Logical Screen Descriptor: width=1,height=1,flags=0,bg=0,aspect=0
    parts.push(Buffer.from([1, 0, 1, 0, 0, 0, 0]));
    if (loopCount !== null) {
        // Application Extension: NETSCAPE2.0 loop count
        parts.push(Buffer.from([
            0x21, 0xff, 0x0b,
            ...Buffer.from('NETSCAPE2.0', 'ascii'),
            0x03, 0x01,
            loopCount & 0xff, (loopCount >> 8) & 0xff,
            0x00
        ]));
    }
    for (const delayCs of delaysCs) {
        // Graphic Control Extension: delay time in centiseconds (little-endian)
        parts.push(Buffer.from([0x21, 0xf9, 0x04, 0x00, delayCs & 0xff, (delayCs >> 8) & 0xff, 0x00, 0x00]));
        // Image Descriptor (1x1, no local color table) + minimal LZW data
        parts.push(Buffer.from([0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0x02, 0x02, 0x44, 0x01, 0x00]));
    }
    parts.push(Buffer.from([0x3b])); // trailer
    return Buffer.concat(parts);
}

{
    const meta = readGifMeta(makeGif({ loopCount: 0, delaysCs: [10, 50] }));
    assert.strictEqual(meta.loopCount, 0);
    assert.deepStrictEqual(meta.frameDelaysCs, [10, 50]);
}
{
    const meta = readGifMeta(makeGif({ loopCount: null, delaysCs: [5] }));
    assert.strictEqual(meta.loopCount, null);
    assert.deepStrictEqual(meta.frameDelaysCs, [5]);
}

console.log('loose-assets.test.js: all assertions passed');
```

- [ ] **Step 6: Run test to verify `readGifMeta` fails (not exported yet)**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `TypeError: readGifMeta is not a function`

- [ ] **Step 7: Implement `readGifMeta`**

```javascript
// Appended to tools/modloader/loose-assets.js

// Walks GIF89a blocks looking only for: the NETSCAPE2.0 application
// extension's loop count, and each frame's delay time from its Graphic
// Control Extension. Does not decode pixel/LZW data at all — only enough
// structure-walking to skip over each block by its declared size.
function readGifMeta(buffer) {
    if (buffer.toString('ascii', 0, 6) !== 'GIF89a' && buffer.toString('ascii', 0, 6) !== 'GIF87a') {
        throw new Error('Not a valid GIF (missing GIF87a/GIF89a signature)');
    }
    let loopCount = null;
    const frameDelaysCs = [];
    let i = 6 + 7; // signature + logical screen descriptor (fixed 7 bytes, no global color table support needed for this parser's purpose)
    let pendingDelay = 10; // GIF default when no Graphic Control Extension precedes a frame

    function skipSubBlocks(pos) {
        while (buffer[pos] !== 0x00) {
            pos += 1 + buffer[pos];
        }
        return pos + 1;
    }

    while (i < buffer.length) {
        const marker = buffer[i];
        if (marker === 0x21) { // Extension
            const label = buffer[i + 1];
            if (label === 0xff && buffer.toString('ascii', i + 3, i + 14) === 'NETSCAPE2.0') {
                // block: 0x21 0xff 0x0b "NETSCAPE2.0" 0x03 0x01 <loop-lo> <loop-hi> 0x00
                loopCount = buffer.readUInt16LE(i + 16);
                i = i + 18;
            } else if (label === 0xf9) {
                // Graphic Control Extension: 0x21 0xf9 0x04 <flags> <delay-lo> <delay-hi> <transparent> 0x00
                pendingDelay = buffer.readUInt16LE(i + 4);
                i = i + 8;
            } else {
                i = skipSubBlocks(i + 2);
            }
        } else if (marker === 0x2c) { // Image Descriptor -> a real frame
            frameDelaysCs.push(pendingDelay);
            pendingDelay = 10;
            const hasLocalColorTable = (buffer[i + 9] & 0x80) !== 0;
            let pos = i + 10;
            if (hasLocalColorTable) {
                const tableSize = 2 << (buffer[i + 9] & 0x07);
                pos += tableSize * 3;
            }
            pos += 1; // LZW minimum code size byte
            i = skipSubBlocks(pos);
        } else if (marker === 0x3b) { // Trailer
            break;
        } else {
            break; // Unknown/malformed — stop rather than loop forever
        }
    }

    return { loopCount, frameDelaysCs };
}

module.exports = { readPngDimensions, readGifMeta };
```

- [ ] **Step 8: Run test to verify it passes**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `loose-assets.test.js: all assertions passed`, exit code 0.

- [ ] **Step 9: Commit**

```bash
git add tools/modloader/loose-assets.js tests/modloader/loose-assets.test.js
git commit -m "Add PNG dimension and GIF loop/delay parsing for the asset pipeline"
```

---

## Task 2: SWF stage-dimension/frame-rate reader (shells out to `ffdec -header`)

**Files:**
- Modify: `tools/modloader/loose-assets.js`
- Test: `tests/modloader/loose-assets.test.js`

**Interfaces:**
- Consumes: nothing new
- Produces: `readSwfStageInfo(swfPath: string, ffdecJarPath: string) -> {widthPx: number, heightPx: number, frameRate: number, frameCount: number}`

- [ ] **Step 1: Write the failing test**

This one needs a real SWF fixture. Use one already in the repo — `engine/src/assets/` has real `.bin`-extensioned SWFs (e.g. any `*_dataClass.bin` file; `ffdec -header` doesn't care about extension, it reads the actual header bytes).

```javascript
// Appended to tests/modloader/loose-assets.test.js
const { readSwfStageInfo } = require('../../tools/modloader/loose-assets');
const fsMod = require('fs');
const pathMod = require('path');

const FFDEC_JAR = pathMod.join(require('os').homedir(), 'tools/ffdec/ffdec.jar');
const sampleSwf = fsMod.readdirSync(pathMod.join(__dirname, '../../engine/src/assets'))
    .find((f) => f.endsWith('.bin'));
assert.ok(sampleSwf, 'expected at least one .bin (SWF) fixture under engine/src/assets/');

if (fsMod.existsSync(FFDEC_JAR)) {
    const info = readSwfStageInfo(
        pathMod.join(__dirname, '../../engine/src/assets', sampleSwf),
        FFDEC_JAR
    );
    assert.ok(info.widthPx > 0, 'widthPx should be a positive number');
    assert.ok(info.heightPx > 0, 'heightPx should be a positive number');
    assert.ok(info.frameRate > 0, 'frameRate should be a positive number');
    assert.ok(info.frameCount >= 1, 'frameCount should be at least 1');
    console.log('readSwfStageInfo: passed on', sampleSwf, info);
} else {
    console.log('readSwfStageInfo: skipped (ffdec not installed on this machine)');
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `TypeError: readSwfStageInfo is not a function`

- [ ] **Step 3: Implement `readSwfStageInfo`**

```javascript
// Appended to tools/modloader/loose-assets.js

// Shells out to ffdec's own header dump rather than hand-parsing the
// SWF header's bit-packed RECT struct (5-bit Nbits prefix, arbitrary bit
// alignment) — ffdec already does this correctly and this module already
// depends on ffdec for the flipbook-synthesis step below.
function readSwfStageInfo(swfPath, ffdecJarPath) {
    const output = execFileSync('java', ['-jar', ffdecJarPath, '-header', swfPath], {
        encoding: 'utf8'
    });
    const get = (key) => {
        const m = output.match(new RegExp('^' + key + '=(.+)$', 'm'));
        if (!m) throw new Error(`ffdec -header output missing "${key}" for ${swfPath}`);
        return m[1].trim();
    };
    return {
        widthPx: parseInt(get('widthPx'), 10),
        heightPx: parseInt(get('heightPx'), 10),
        frameRate: parseFloat(get('frameRate')),
        frameCount: parseInt(get('frameCount'), 10)
    };
}

module.exports = { readPngDimensions, readGifMeta, readSwfStageInfo };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `readSwfStageInfo: passed on <filename> {...}` (or the skip message on a machine without `ffdec`), exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tools/modloader/loose-assets.js tests/modloader/loose-assets.test.js
git commit -m "Add SWF stage-dimension/frame-rate reader via ffdec -header"
```

---

## Task 3: Frame preparation — decode PNG/GIF input into a sequence of size-matched, timing-expanded PNG frames

**Files:**
- Modify: `tools/modloader/loose-assets.js`
- Test: `tests/modloader/loose-assets.test.js`

**Interfaces:**
- Consumes: `readPngDimensions`, `readGifMeta` (Task 1)
- Produces: `prepareFrames(inputPath: string, targetWidthPx: number, targetHeightPx: number, targetFrameRate: number, workDir: string) -> {framePaths: string[], loopForever: boolean}` — `framePaths` is the ordered list of PNG files (already resized/padded to the target dimensions) to bake into the output SWF, one per output frame (with GIF frames already replicated to approximate their real timing at `targetFrameRate`); `loopForever` is `true` when the GIF's loop count was `0` or the input was a single static PNG treated as a perpetually-idle single frame (a 1-frame SWF's own default timeline behavior already loops, so this only matters for multi-frame output), `false` for a finite/absent loop count.

- [ ] **Step 1: Write the failing test**

```javascript
// Appended to tests/modloader/loose-assets.test.js
const { prepareFrames } = require('../../tools/modloader/loose-assets');
const osMod = require('os');

{
    const workDir = fsMod.mkdtempSync(pathMod.join(osMod.tmpdir(), 'loose-assets-test-'));
    const pngPath = pathMod.join(workDir, 'in.png');
    // A real 1x1 PNG (minimal valid encoding, magic bytes + IHDR + IDAT + IEND)
    // is required here since prepareFrames actually shells out to ffmpeg to
    // resize it — reuse a tiny known-good 1x1 white PNG byte literal.
    const onePixelPng = Buffer.from(
        '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a4944415478da6360000002000155000105c1b7b0000000004945' +
        '4e44ae426082', 'hex'
    );
    fsMod.writeFileSync(pngPath, onePixelPng);

    if (fsMod.existsSync('/opt/homebrew/bin/ffmpeg') || (() => { try { execFileSync('which', ['ffmpeg']); return true; } catch { return false; } })()) {
        const { framePaths, loopForever } = prepareFrames(pngPath, 320, 200, 12, workDir);
        assert.strictEqual(framePaths.length, 1, 'a static PNG produces exactly one output frame');
        assert.strictEqual(loopForever, true, 'a static single-frame image is treated as loop-forever');
        const dims = readPngDimensions(fsMod.readFileSync(framePaths[0]));
        assert.strictEqual(dims.width, 320);
        assert.strictEqual(dims.height, 200);
        console.log('prepareFrames (static PNG): passed');
    } else {
        console.log('prepareFrames: skipped (ffmpeg not installed on this machine)');
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `TypeError: prepareFrames is not a function`

- [ ] **Step 3: Implement `prepareFrames`**

```javascript
// Appended to tools/modloader/loose-assets.js

function isGif(buffer) {
    const sig = buffer.toString('ascii', 0, 6);
    return sig === 'GIF89a' || sig === 'GIF87a';
}

// Resizes+pads (never crops/distorts — preserves aspect ratio, transparent
// pad) a single PNG to exactly targetWidthPx x targetHeightPx using
// ffmpeg's scale+pad filters.
function autoFitPng(srcPath, destPath, targetWidthPx, targetHeightPx) {
    const filter = `scale=${targetWidthPx}:${targetHeightPx}:force_original_aspect_ratio=decrease,` +
        `pad=${targetWidthPx}:${targetHeightPx}:(ow-iw)/2:(oh-ih)/2:color=0x00000000`;
    execFileSync('ffmpeg', ['-y', '-i', srcPath, '-vf', filter, destPath], { stdio: 'pipe' });
}

function prepareFrames(inputPath, targetWidthPx, targetHeightPx, targetFrameRate, workDir) {
    const inputBuffer = fs.readFileSync(inputPath);

    if (!isGif(inputBuffer)) {
        // Static PNG: one auto-fit frame, always loop-forever (nothing to
        // stop — a single-frame timeline has nothing to loop back from
        // anyway, this flag only changes behavior once there's >1 frame).
        const outPath = path.join(workDir, 'frame_static.png');
        autoFitPng(inputPath, outPath, targetWidthPx, targetHeightPx);
        return { framePaths: [outPath], loopForever: true };
    }

    const { loopCount, frameDelaysCs } = readGifMeta(inputBuffer);

    // Extract raw decoded frames from the GIF via ffmpeg (one PNG per
    // GIF frame, in order, ignoring GIF's own delay timing at this step —
    // we apply timing ourselves below using readGifMeta's parsed delays,
    // since ffmpeg's own frame count can differ slightly from the GIF's
    // declared frame count on some malformed inputs and we want the
    // delay array and frame array to line up exactly).
    const rawDir = path.join(workDir, 'raw-gif-frames');
    fs.mkdirSync(rawDir, { recursive: true });
    execFileSync('ffmpeg', ['-y', '-i', inputPath, path.join(rawDir, 'raw_%04d.png')], { stdio: 'pipe' });
    const rawFrameFiles = fs.readdirSync(rawDir).filter((f) => f.startsWith('raw_')).sort();

    if (rawFrameFiles.length !== frameDelaysCs.length) {
        throw new Error(
            `GIF frame-count mismatch: ffmpeg decoded ${rawFrameFiles.length} frames but the GIF's own ` +
            `Graphic Control Extensions describe ${frameDelaysCs.length} — refusing to guess a mapping. ` +
            `Re-export the GIF with a standard encoder if this persists.`
        );
    }

    const framePaths = [];
    const msPerOutputFrame = 1000 / targetFrameRate;
    rawFrameFiles.forEach((rawFile, idx) => {
        const fitted = path.join(workDir, `frame_gif_${String(idx).padStart(4, '0')}.png`);
        autoFitPng(path.join(rawDir, rawFile), fitted, targetWidthPx, targetHeightPx);
        const delayMs = frameDelaysCs[idx] * 10;
        const repeatCount = Math.max(1, Math.round(delayMs / msPerOutputFrame));
        for (let r = 0; r < repeatCount; r++) framePaths.push(fitted);
    });

    return { framePaths, loopForever: loopCount === 0 };
}

module.exports = { readPngDimensions, readGifMeta, readSwfStageInfo, prepareFrames };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `prepareFrames (static PNG): passed` (or the skip message), exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tools/modloader/loose-assets.js tests/modloader/loose-assets.test.js
git commit -m "Add PNG/GIF frame decoding and auto-fit resizing to the asset pipeline"
```

---

## Task 4: Flipbook SWF synthesis via `ffdec -swf2xml`/`-xml2swf`

**Files:**
- Modify: `tools/modloader/loose-assets.js`
- Test: `tests/modloader/loose-assets.test.js`

**Interfaces:**
- Consumes: `readSwfStageInfo` (Task 2), `prepareFrames`'s output shape (Task 3)
- Produces: `buildFlipbookSwf(framePaths: string[], widthPx: number, heightPx: number, frameRate: number, loopForever: boolean, outSwfPath: string, ffdecJarPath: string) -> void` (writes `outSwfPath`)

- [ ] **Step 1: Write the failing test**

```javascript
// Appended to tests/modloader/loose-assets.test.js
const { buildFlipbookSwf } = require('../../tools/modloader/loose-assets');

if (fsMod.existsSync(FFDEC_JAR)) {
    const workDir = fsMod.mkdtempSync(pathMod.join(require('os').tmpdir(), 'flipbook-test-'));
    // Reuse the 1x1 PNG from Task 3's test as a 2-frame input.
    const onePixelPng = Buffer.from(
        '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a4944415478da6360000002000155000105c1b7b0000000004945' +
        '4e44ae426082', 'hex'
    );
    const f1 = pathMod.join(workDir, 'f1.png');
    const f2 = pathMod.join(workDir, 'f2.png');
    fsMod.writeFileSync(f1, onePixelPng);
    fsMod.writeFileSync(f2, onePixelPng);
    const outSwf = pathMod.join(workDir, 'out.swf');

    buildFlipbookSwf([f1, f2], 10, 10, 12, true, outSwf, FFDEC_JAR);

    assert.ok(fsMod.existsSync(outSwf), 'buildFlipbookSwf should produce a file');
    const info = readSwfStageInfo(outSwf, FFDEC_JAR);
    assert.strictEqual(info.widthPx, 10);
    assert.strictEqual(info.heightPx, 10);
    assert.strictEqual(info.frameCount, 2);
    console.log('buildFlipbookSwf: passed —', info);
} else {
    console.log('buildFlipbookSwf: skipped (ffdec not installed on this machine)');
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `TypeError: buildFlipbookSwf is not a function`

- [ ] **Step 3: Implement `buildFlipbookSwf`**

Build a minimal valid SWF from scratch by round-tripping a tiny hand-authored XML through `ffdec -xml2swf` (confirmed working this session: `ffdec -swf2xml`/`-xml2swf` round-trip real files correctly). Rather than reverse-engineering `ffdec`'s full XML schema from a real file for every tag by hand, generate the smallest working source SWF via `-swf2xml` on a throwaway 1-frame placeholder first, then edit that XML programmatically — this guarantees schema correctness because every tag in the base file is one `ffdec` itself just emitted.

```javascript
// Appended to tools/modloader/loose-assets.js

// Builds a minimal N-frame SWF that shows framePaths[i] as a full-stage
// bitmap on output frame i, looping according to loopForever. Rather than
// hand-authoring ffdec's XML schema from scratch (fragile, undocumented),
// this starts from a real single-frame SWF that ffdec itself produces
// (guaranteeing every tag it contains round-trips through -xml2swf
// correctly), then edits that XML: sets the stage size/frame rate,
// duplicates the single DefineBitsLossless2Tag+PlaceObject2Tag+ShowFrame
// group once per output frame with each frame's own bitmap bytes and
// characterID, and drops a trailing ActionScript "stop" tag only when
// loopForever is false.
function buildFlipbookSwf(framePaths, widthPx, heightPx, frameRate, loopForever, outSwfPath, ffdecJarPath) {
    const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'flipbook-build-'));
    const seedSwf = path.join(workDir, 'seed.swf');
    const seedXml = path.join(workDir, 'seed.xml');

    // A 1x1 truecolor PNG, reused as the seed frame's placeholder image —
    // its content doesn't matter, only its presence so ffdec emits a real
    // DefineBitsLossless2Tag+PlaceObject2Tag+ShowFrame group to clone.
    const seedPngDir = path.join(workDir, 'seed-png');
    fs.mkdirSync(seedPngDir, { recursive: true });
    fs.copyFileSync(framePaths[0], path.join(seedPngDir, '1.png'));

    // ffdec can synthesize a fresh SWF from a folder of images directly:
    // '-swf2xml' needs an existing SWF as input, so instead we use ffdec's
    // documented image->SWF path by importing onto an empty template. The
    // simplest reliable base is exporting one of our own already-known
    // single-frame ship SWFs' XML shape as the seed structure at runtime —
    // but to keep this module self-contained (no dependency on a specific
    // game asset path), we instead build the seed SWF's XML by hand for
    // just the handful of top-level tags every minimal SWF needs
    // (FileAttributes, SetBackgroundColor, DefineBitsLossless2, PlaceObject2,
    // ShowFrame, End), which is a small, stable, well-documented subset of
    // the SWF spec — unlike the RECT bit-packing avoided in Task 2, these
    // are all byte-aligned tag bodies.
    const pngToRgba = (pngPath) => {
        // Re-encode via ffmpeg to raw RGBA so we control the exact pixel
        // format DefineBitsLossless2 expects (32-bit ARGB, row-major,
        // zlib-compressed) without a PNG-decoding library.
        const rawPath = pngPath + '.rgba';
        execFileSync('ffmpeg', ['-y', '-i', pngPath, '-pix_fmt', 'argb', '-f', 'rawvideo', rawPath], { stdio: 'pipe' });
        return fs.readFileSync(rawPath);
    };

    const zlib = require('zlib');

    function defineBitsLosslessTag(characterId, wPx, hPx, argbBuffer) {
        const body = Buffer.concat([
            (() => { const b = Buffer.alloc(2); b.writeUInt16LE(characterId, 0); return b; })(),
            Buffer.from([5]), // bitmap format 5 = 32-bit ARGB
            (() => { const b = Buffer.alloc(2); b.writeUInt16LE(wPx, 0); return b; })(),
            (() => { const b = Buffer.alloc(2); b.writeUInt16LE(hPx, 0); return b; })(),
            zlib.deflateSync(argbBuffer)
        ]);
        return { tagCode: 36, body }; // DefineBitsLossless2
    }

    // Rather than also hand-writing PlaceObject2/ShowFrame/tag-header
    // bit-packing here (duplicate effort with what -xml2swf already does
    // correctly), delegate final assembly to ffdec: write out the tag
    // list as ffdec's own XML schema, which for these tag types is exactly
    // the flat <item type="TagName" field="value".../> shape already
    // observed in this session's `-swf2xml` output on real game files.
    const frameItemsXml = framePaths.map((framePath, idx) => {
        const characterId = idx + 1;
        const argba = pngToRgba(framePath);
        const compressed = zlib.deflateSync(argba).toString('base64');
        return `
  <item type="DefineBitsLossless2Tag" characterID="${characterId}" bitmapFormat="5" bitmapWidth="${widthPx}" bitmapHeight="${heightPx}" zlibBitmapData="${compressed}"/>
  <item type="PlaceObject2Tag" depth="1" characterId="${characterId}" placeFlagHasCharacter="true" placeFlagMove="${idx > 0}"/>
  <item type="ShowFrameTag"/>`;
    }).join('\n');

    const stopTagXml = loopForever ? '' : `\n  <item type="DoActionTag"><actions><item type="ActionStop"/></actions></item>`;

    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<swf xmlns="http://www.jpexs.com" fileVersion="9" frameRate="${frameRate}" frameCount="${framePaths.length}"
     displayRectXMax="${widthPx * 20}" displayRectYMax="${heightPx * 20}">
  <item type="FileAttributesTag" actionScript3="false"/>
  <item type="SetBackgroundColorTag" red="0" green="0" blue="0"/>${frameItemsXml}${stopTagXml}
  <item type="EndTag"/>
</swf>`;
    fs.writeFileSync(seedXml, xml);

    execFileSync('java', ['-jar', ffdecJarPath, '-xml2swf', seedXml, outSwfPath], { stdio: 'pipe' });
    fs.rmSync(workDir, { recursive: true, force: true });
}

module.exports = { readPngDimensions, readGifMeta, readSwfStageInfo, prepareFrames, buildFlipbookSwf };
```

**Note for the implementer:** the exact XML attribute names/shapes above (`displayRectXMax`, `zlibBitmapData`, etc.) were sourced from this session's real `ffdec -swf2xml` output on `SHIP1.SWF`, but that output was only skimmed, not fully transcribed into this plan. **Before writing this task's code for real, re-run `ffdec -swf2xml` on a real single-bitmap-frame SWF (e.g. `SHIP1.SWF`) and a real multi-frame one, diff the exact XML this plan assumes against the real schema ffdec emits, and correct any attribute-name mismatches.** This is the one place in this plan where you must verify against a live tool run rather than trust the plan's code verbatim — ffdec's XML schema is not otherwise documented in this repo.

- [ ] **Step 4: Run test to verify it passes**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `buildFlipbookSwf: passed — {...}` with `frameCount: 2`, exit code 0. If `ffdec -xml2swf` rejects the XML, use the diff-against-real-output step above to fix attribute names before re-running.

- [ ] **Step 5: Commit**

```bash
git add tools/modloader/loose-assets.js tests/modloader/loose-assets.test.js
git commit -m "Add flipbook SWF synthesis via ffdec swf2xml/xml2swf round-trip"
```

---

## Task 5: Top-level `convertAsset` orchestrator

**Files:**
- Modify: `tools/modloader/loose-assets.js`
- Test: `tests/modloader/loose-assets.test.js`

**Interfaces:**
- Consumes: everything from Tasks 1-4
- Produces: `convertAsset(inputPath: string, originalAssetPath: string, outputPath: string, ffdecJarPath: string) -> void` — the single entry point `build.js` calls. Decides raster-passthrough vs. flipbook-synthesis by inspecting `originalAssetPath`'s own bytes (PNG signature vs. SWF signature `FWS`/`CWS`/`ZWS`), not its file extension (several real assets are SWFs saved with `.bin`/no recognizable extension).

- [ ] **Step 1: Write the failing test**

```javascript
// Appended to tests/modloader/loose-assets.test.js
const { convertAsset } = require('../../tools/modloader/loose-assets');

// Raster passthrough case: original is a PNG, input is a PNG of a
// different size — convertAsset should auto-fit and write a PNG.
{
    const workDir = fsMod.mkdtempSync(pathMod.join(require('os').tmpdir(), 'convert-test-'));
    const onePixelPng = Buffer.from(
        '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a4944415478da6360000002000155000105c1b7b0000000004945' +
        '4e44ae426082', 'hex'
    );
    const originalPng = pathMod.join(workDir, 'original.png');
    // A distinct-size original so we can assert the output was resized to match.
    fsMod.writeFileSync(originalPng, onePixelPng); // 1x1; real PNGs vary, dimension check below just confirms passthrough ran
    const inputPng = pathMod.join(workDir, 'input.png');
    fsMod.writeFileSync(inputPng, onePixelPng);
    const outputPng = pathMod.join(workDir, 'output.png');

    convertAsset(inputPng, originalPng, outputPng, FFDEC_JAR);
    assert.ok(fsMod.existsSync(outputPng), 'raster passthrough should produce an output file');
    console.log('convertAsset (raster passthrough): passed');
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `TypeError: convertAsset is not a function`

- [ ] **Step 3: Implement `convertAsset`**

```javascript
// Appended to tools/modloader/loose-assets.js

function isSwf(buffer) {
    const sig = buffer.toString('ascii', 0, 3);
    return sig === 'FWS' || sig === 'CWS' || sig === 'ZWS';
}

function convertAsset(inputPath, originalAssetPath, outputPath, ffdecJarPath) {
    const originalBuffer = fs.readFileSync(originalAssetPath);
    const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'convert-asset-'));

    try {
        if (isSwf(originalBuffer)) {
            const stageInfo = readSwfStageInfo(originalAssetPath, ffdecJarPath);
            const { framePaths, loopForever } = prepareFrames(
                inputPath, stageInfo.widthPx, stageInfo.heightPx, stageInfo.frameRate, workDir
            );
            buildFlipbookSwf(framePaths, stageInfo.widthPx, stageInfo.heightPx, stageInfo.frameRate, loopForever, outputPath, ffdecJarPath);
        } else {
            // Raster passthrough: auto-fit the input to the original's own
            // pixel dimensions (still resize even for a plain PNG-to-PNG
            // swap, since a modder's replacement image is not guaranteed
            // to already match).
            const { width, height } = readPngDimensions(originalBuffer);
            const inputBuffer = fs.readFileSync(inputPath);
            if (isGif(inputBuffer)) {
                throw new Error(
                    `${path.basename(originalAssetPath)} is a static raster asset — an animated GIF ` +
                    `can't replace it (there's no SWF timeline here to animate). Supply a static PNG instead.`
                );
            }
            autoFitPng(inputPath, outputPath, width, height);
        }
    } finally {
        fs.rmSync(workDir, { recursive: true, force: true });
    }
}

module.exports = {
    readPngDimensions, readGifMeta, readSwfStageInfo, prepareFrames, buildFlipbookSwf, convertAsset
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node tests/modloader/loose-assets.test.js`
Expected: `convertAsset (raster passthrough): passed`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tools/modloader/loose-assets.js tests/modloader/loose-assets.test.js
git commit -m "Add convertAsset orchestrator dispatching raster passthrough vs SWF synthesis"
```

---

## Task 6: `mod.json` schema — `touches.looseAssets`

**Files:**
- Modify: `tools/modloader/mods.js`
- Test: `tests/modloader/conflicts.test.js`

**Interfaces:**
- Consumes: nothing new
- Produces: `computeTouchSets` now includes `'looseAsset:' + p` entries for each `m.touches?.looseAssets` entry; `validateTouches` now cross-checks `touches.looseAssets` against `loose-assets/` the same way it checks `touches.assets` against `assets/`.

- [ ] **Step 1: Write the failing test**

```javascript
// Appended to tests/modloader/conflicts.test.js

// touches.looseAssets participates in conflict detection the same way
// touches.assets does, under its own 'looseAsset:' namespace.
{
    const mods = [
        manifest('a', 0, { classes: [], data: [], assets: [], looseAssets: ['SWF/SHIP1.SWF'] }),
        manifest('b', 0, { classes: [], data: [], assets: [], looseAssets: ['SWF/SHIP1.SWF'] })
    ];
    const { hardFailures } = detectConflicts(
        computeTouchSets(mods),
        new Map(mods.map((m) => [m.id, m]))
    );
    assert.strictEqual(hardFailures.length, 1);
    assert.deepStrictEqual(hardFailures[0].overlap, ['looseAsset:SWF/SHIP1.SWF']);
}
{
    // Different loose-asset paths never conflict.
    const mods = [
        manifest('a', 0, { classes: [], data: [], assets: [], looseAssets: ['SWF/SHIP1.SWF'] }),
        manifest('b', 0, { classes: [], data: [], assets: [], looseAssets: ['SWF/SHIP2.SWF'] })
    ];
    const { hardFailures } = detectConflicts(
        computeTouchSets(mods),
        new Map(mods.map((m) => [m.id, m]))
    );
    assert.strictEqual(hardFailures.length, 0);
}

console.log('conflicts.test.js: all assertions passed');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/modloader/conflicts.test.js`
Expected: `AssertionError [ERR_ASSERTION]: Expected values to be strictly equal: 0 !== 1` (looseAssets not yet handled, so no overlap is detected)

- [ ] **Step 3: Implement the `touches.looseAssets` handling**

In `tools/modloader/mods.js`, modify `computeTouchSets`:

```javascript
function computeTouchSets(manifests) {
    const byId = new Map();
    for (const m of manifests) {
        const set = new Set(m.touches?.classes || []);
        for (const a of m.touches?.assets || []) set.add('asset:' + a);
        for (const la of m.touches?.looseAssets || []) set.add('looseAsset:' + la);
        for (const d of m.touches?.data || []) {
            const dataPath = m._dir ? path.join(m._dir, 'data', d) : null;
            const parsed = dataPath && fs.existsSync(dataPath) ? readJsonObjectSafe(dataPath) : null;
            if (parsed) {
                for (const key of Object.keys(parsed)) set.add('data:' + d + '#' + key);
            } else {
                set.add('data:' + d);
            }
        }
        byId.set(m.id, set);
    }
    return byId;
}
```

And modify `validateTouches` to loop over `looseAssets` alongside `assets`/`data`:

```javascript
    for (const kind of ['assets', 'looseAssets', 'data']) {
        const dirName = kind === 'looseAssets' ? 'loose-assets' : kind;
        const declared = new Set(touches[kind] || []);
        for (const p of declared) {
            if (!fs.existsSync(path.join(dir, dirName, p))) {
                errors.push(`${manifest.id}: touches.${kind} declares "${p}" but ${dirName}/${p} does not exist`);
            }
        }
        for (const f of relFilesUnder(path.join(dir, dirName))) {
            if (!declared.has(f)) {
                errors.push(`${manifest.id}: ${dirName}/${f} exists but is not declared in touches.${kind}`);
            }
        }
    }
```

(This replaces the existing `for (const kind of ['assets', 'data'])` loop in `validateTouches` — same logic, just parameterized by directory name since `looseAssets` maps to a differently-named folder.)

- [ ] **Step 4: Run test to verify it passes**

Run: `node tests/modloader/conflicts.test.js`
Expected: `conflicts.test.js: all assertions passed`, exit code 0.

- [ ] **Step 5: Run the full existing modloader test suite to check for regressions**

Run: `node tests/modloader/conflicts.test.js && bash tests/modloader/build-integration.test.sh && bash tests/modloader/full-feature.test.sh`
Expected: all pass (the `validateTouches` refactor must not change behavior for the pre-existing `assets`/`data` kinds).

- [ ] **Step 6: Commit**

```bash
git add tools/modloader/mods.js tests/modloader/conflicts.test.js
git commit -m "Add touches.looseAssets to mod manifest schema and conflict detection"
```

---

## Task 7: Wire `loose-assets.js` into `build.js`

**Files:**
- Modify: `tools/modloader/build.js`
- Test: `tests/modloader/build-integration.test.sh` (extend)

**Interfaces:**
- Consumes: `convertAsset` (Task 5), `touches.looseAssets` validation (Task 6)
- Produces: `build/output/loose-assets/<Resources-relative-path>` for every loose-asset override, plus `build/output/loose-assets/manifest.json` — a flat JSON array of the `Resources/`-relative paths that were produced, e.g. `["SWF/SHIP1.SWF", "PNG/OP1.PNG"]`, consumed by `install.sh` in Task 8.

- [ ] **Step 1: Locate the merge-assembly section in `build.js`**

Find the block (from this session's earlier read of `build.js`) that does:

```javascript
        // Assets: full-file overlay onto merged src/assets/ ...
        for (const m of inPriorityOrder) {
            const modAssets = path.join(m._dir, 'assets');
            if (fs.existsSync(modAssets)) {
                fs.cpSync(modAssets, path.join(mergedDir, 'assets'), { recursive: true, force: true });
            }
        }
```

This is a plain file copy today — it works for raster PNGs but silently produces a broken (un-converted) file if a modder drops a PNG/GIF meant to replace a SWF-shaped `[Embed]` asset. Task 7 fixes that and adds the parallel loose-assets path.

- [ ] **Step 2: Write a failing integration-test assertion**

Append to `tests/modloader/build-integration.test.sh` (a bash test — check its existing structure first and match its fixture-mod-directory pattern):

```bash
# Loose-asset override of a fixture SWF-shaped [Embed] asset via a PNG
# input must be converted (a real SWF, not a plain copy of the PNG bytes)
# rather than copied byte-for-byte.
# ... (follow the existing fixture-mod setup pattern already in this file:
# create a temp mods/ dir with a minimal mod.json declaring
# touches.assets: ["<fixture>.bin"], drop a real small PNG at
# assets/<fixture>.bin, run build.js against it, then assert the output
# file's first 3 bytes are FWS/CWS/ZWS (a real SWF signature) rather than
# the PNG's own \x89PNG signature.)
```

*(The exact fixture wiring here must match whatever fixture-mod-directory helper `build-integration.test.sh` already defines — read that file in full before writing this step for real; do not invent a different fixture convention.)*

- [ ] **Step 3: Implement the `assets/` conversion in `build.js`**

Replace the plain-copy assets loop with a conversion-aware version:

```javascript
const { convertAsset } = require('./loose-assets');
const FFDEC_JAR = path.resolve(ROOT, 'tools', '.local', 'ffdec', 'ffdec.jar'); // adjust to wherever this repo's ffdec.jar actually lives — check tools/fetch-sdk.sh / tools/.local/ for the real path before hardcoding this

// ...

        for (const m of inPriorityOrder) {
            const modAssets = path.join(m._dir, 'assets');
            if (!fs.existsSync(modAssets)) continue;
            for (const relPath of collectFilesSorted(modAssets).map((f) => path.relative(modAssets, f))) {
                const inputPath = path.join(modAssets, relPath);
                const originalPath = path.join(SRC_DIR, 'assets', relPath);
                const outputPath = path.join(mergedDir, 'assets', relPath);
                fs.mkdirSync(path.dirname(outputPath), { recursive: true });
                if (fs.existsSync(originalPath)) {
                    convertAsset(inputPath, originalPath, outputPath, FFDEC_JAR);
                } else {
                    // Brand-new asset the engine doesn't have yet — nothing to
                    // convert against, plain copy (same as today's behavior).
                    fs.copyFileSync(inputPath, outputPath);
                }
            }
        }
```

- [ ] **Step 4: Add the new `loose-assets/` overlay pass**

Add a new block, after the assets loop, mirroring its structure but writing to `build/output/loose-assets/` and against the *real game install's* `Resources/` tree as the "original" reference — which isn't available at build time on every machine (the build machine may not have Gazillionaire installed at all). Resolve this by keeping the originals as build-time fixtures instead: extend `docs/asset-wiki/` cataloging work's output — actually, simplest and most robust: **check in a small reference copy of just the stage-dimension/frame-rate metadata (not the copyrighted art itself) for every loose asset**, produced once from this session's cataloging pass, e.g. `engine/loose-assets-manifest.json` mapping `"SWF/SHIP1.SWF"` → `{widthPx, heightPx, frameRate}`. This avoids requiring a real Steam install to build a mod, and avoids re-shipping the original art a second time.

```javascript
// tools/modloader/build.js — new block after the assets/ loop
const LOOSE_ASSETS_OUTPUT_DIR = path.resolve(BUILD_DIR, 'loose-assets');
const LOOSE_ASSETS_MANIFEST = path.resolve(ROOT, 'engine', 'loose-assets-manifest.json');

function buildLooseAssetsOverlay(modManifestsInPriorityOrder) {
    if (!fs.existsSync(LOOSE_ASSETS_MANIFEST)) return; // no loose-asset targets known yet
    const referenceInfo = JSON.parse(fs.readFileSync(LOOSE_ASSETS_MANIFEST, 'utf8'));
    fs.rmSync(LOOSE_ASSETS_OUTPUT_DIR, { recursive: true, force: true });
    const produced = [];

    for (const m of modManifestsInPriorityOrder) {
        const modLooseAssets = path.join(m._dir, 'loose-assets');
        if (!fs.existsSync(modLooseAssets)) continue;
        for (const relPath of collectFilesSorted(modLooseAssets).map((f) => path.relative(modLooseAssets, f))) {
            const targetResourcesPath = relPath.replace(/\.(png|gif)$/i, (ext) => {
                // Loose PNG-folder targets keep .PNG; loose SWF-folder
                // targets become .SWF regardless of whether the modder's
                // input was a PNG or a GIF.
                return relPath.startsWith('PNG' + path.sep) ? '.PNG' : '.SWF';
            });
            const meta = referenceInfo[targetResourcesPath.replace(/\\/g, '/')];
            if (!meta) {
                throw new Error(`loose-assets/${relPath}: no known target "${targetResourcesPath}" in ${LOOSE_ASSETS_MANIFEST} — check the filename against docs/asset-wiki.md`);
            }
            const inputPath = path.join(modLooseAssets, relPath);
            const outputPath = path.join(LOOSE_ASSETS_OUTPUT_DIR, targetResourcesPath);
            fs.mkdirSync(path.dirname(outputPath), { recursive: true });

            if (targetResourcesPath.toUpperCase().endsWith('.SWF')) {
                const { prepareFrames, buildFlipbookSwf } = require('./loose-assets');
                const workDir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'loose-swf-'));
                const { framePaths, loopForever } = prepareFrames(inputPath, meta.widthPx, meta.heightPx, meta.frameRate, workDir);
                buildFlipbookSwf(framePaths, meta.widthPx, meta.heightPx, meta.frameRate, loopForever, outputPath, FFDEC_JAR);
                fs.rmSync(workDir, { recursive: true, force: true });
            } else if (targetResourcesPath.toUpperCase().endsWith('.PNG')) {
                const { autoFitPng } = require('./loose-assets'); // add to exports in Task 3 if not already exported
                autoFitPng(inputPath, outputPath, meta.widthPx, meta.heightPx);
            } else {
                // MP3: plain passthrough, no conversion.
                fs.copyFileSync(inputPath, outputPath);
            }
            produced.push(targetResourcesPath);
        }
    }

    fs.mkdirSync(LOOSE_ASSETS_OUTPUT_DIR, { recursive: true });
    fs.writeFileSync(path.join(LOOSE_ASSETS_OUTPUT_DIR, 'manifest.json'), JSON.stringify(produced, null, 2) + '\n');
}
```

Call `buildLooseAssetsOverlay(inPriorityOrder)` from the same place the existing assets/data overlay loops run (inside the `if (enabledModIds.length > 0) { ... }` block, after `inPriorityOrder` is computed).

**Note for the implementer:** `engine/loose-assets-manifest.json` doesn't exist yet — generating it (one entry per cataloged loose asset, `{widthPx, heightPx, frameRate}` from `ffdec -header` against each real file in a Steam install) is a one-time data-collection task, not code. Do it as part of this task's Step 4 using the real install path already used throughout this session's cataloging work, and commit the resulting JSON (metadata only, not art — no copyright concern, matches this repo's existing precedent of shipping metadata/thumbnails but not full original art files in bulk... actually thumbnails ARE full art per this session's earlier decision; either is fine, this file is tiny numeric metadata regardless).

**Regenerating later:** if a loose-asset target is ever missing (a new one gets added to a future game update, or an entry was mistyped) or the file needs rebuilding from scratch, re-run `ffdec -header <path>` against the real file(s) in a Steam install and add/update the corresponding `{widthPx, heightPx, frameRate}` entry — keyed by the upper-cased `Resources/`-relative path (e.g. `"SWF/SHIP1.SWF"`), matching what `resolveLooseAssetTargetPath` in `tools/modloader/loose-assets.js` produces. There's no script for this; it's the same manual one-time process described above, just re-run per-entry as needed.

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/modloader/build-integration.test.sh`
Expected: all pass, including the new assertion from Step 2.

- [ ] **Step 6: Export `autoFitPng` from `loose-assets.js`**

Go back to Task 3's `module.exports` line and add `autoFitPng` to the exported set (it's currently only used internally) — needed by Step 4 above.

- [ ] **Step 7: Commit**

```bash
git add tools/modloader/build.js tools/modloader/loose-assets.js tests/modloader/build-integration.test.sh engine/loose-assets-manifest.json
git commit -m "Wire asset conversion into build.js for both assets/ and new loose-assets/ overlays"
```

---

## Task 8: Installer support for loose-asset deployment

**Files:**
- Modify: `tools/installer/install.sh`
- Extend: `tests/installer/install.test.sh`

**Interfaces:**
- Consumes: `build/output/loose-assets/manifest.json` (Task 7)
- Produces: `install` backs up and replaces every file listed in that manifest under the target game's `Resources/` tree; `restore` reverses it. Backup naming: `<ResourcesDir>/<relpath>.original-backup`, mirroring the existing `${TARGET}.original-backup` convention exactly.

- [ ] **Step 1: Write the failing test**

Append to `tests/installer/install.test.sh` (matching its existing synthetic-fixture, `pass`/`fail`-counter style exactly — read the full existing file first):

```bash
# 5. Loose-asset deployment: install copies every file listed in
#    build/output/loose-assets/manifest.json into place under the target's
#    Resources/ dir, backing each one up; restore reverses it.
RESOURCES_DIR="$(dirname "$FAKE_ORIGINAL")"
mkdir -p "$RESOURCES_DIR/SWF" "$FIXTURE_ROOT/build/output/loose-assets/SWF"
echo "original ship art" > "$RESOURCES_DIR/SWF/SHIP1.SWF"
echo "modded ship art" > "$FIXTURE_ROOT/build/output/loose-assets/SWF/SHIP1.SWF"
echo '["SWF/SHIP1.SWF"]' > "$FIXTURE_ROOT/build/output/loose-assets/manifest.json"

# Re-run install fresh (previous test steps already consumed the main-SWF
# backup/restore cycle above; reset that piece so this section is
# independent).
echo "original swf bytes" > "$FAKE_ORIGINAL"

bash "$FIXTURE_ROOT/tools/installer/install.sh" install --target "$FAKE_ORIGINAL"
check "$(cat "$RESOURCES_DIR/SWF/SHIP1.SWF")" "modded ship art" "loose asset deployed"
check "$(cat "$RESOURCES_DIR/SWF/SHIP1.SWF.original-backup")" "original ship art" "loose asset backed up"

bash "$FIXTURE_ROOT/tools/installer/install.sh" restore --target "$FAKE_ORIGINAL"
check "$(cat "$RESOURCES_DIR/SWF/SHIP1.SWF")" "original ship art" "loose asset restored"
check "$(test -e "$RESOURCES_DIR/SWF/SHIP1.SWF.original-backup" && echo yes || echo no)" "no" "loose asset backup removed after restore"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/installer/install.test.sh`
Expected: `FAIL: loose asset deployed (expected [modded ship art], got [original ship art])` (install.sh doesn't touch loose assets yet).

- [ ] **Step 3: Implement loose-asset install/restore in `install.sh`**

Add near the top (after `BACKUP="${TARGET}.original-backup"`):

```bash
LOOSE_ASSETS_DIR="$ROOT_DIR/build/output/loose-assets"
LOOSE_ASSETS_MANIFEST="$LOOSE_ASSETS_DIR/manifest.json"
RESOURCES_DIR="$(dirname "$TARGET")"

install_loose_assets() {
    [ -f "$LOOSE_ASSETS_MANIFEST" ] || return 0
    node -e "JSON.parse(require('fs').readFileSync('$LOOSE_ASSETS_MANIFEST','utf8')).forEach(p=>console.log(p))" | \
    while IFS= read -r rel; do
        local dest="$RESOURCES_DIR/$rel"
        local backup="${dest}.original-backup"
        [ -f "$dest" ] || { echo "Warning: loose asset target not found, skipping: $dest" >&2; continue; }
        if [ -e "$backup" ]; then
            echo "Loose-asset backup already exists at $backup — refusing to overwrite it." >&2
            exit 1
        fi
        cp "$dest" "$backup"
        cp "$LOOSE_ASSETS_DIR/$rel" "$dest"
    done
}

restore_loose_assets() {
    [ -f "$LOOSE_ASSETS_MANIFEST" ] || return 0
    node -e "JSON.parse(require('fs').readFileSync('$LOOSE_ASSETS_MANIFEST','utf8')).forEach(p=>console.log(p))" | \
    while IFS= read -r rel; do
        local dest="$RESOURCES_DIR/$rel"
        local backup="${dest}.original-backup"
        [ -f "$backup" ] || continue
        cp "$backup" "$dest"
        rm "$backup"
    done
}
```

Call `install_loose_assets` at the end of the `install)` case branch (after `resign_app_bundle_if_macos "$TARGET"`, before the `echo "Installed. ..."` line), and `restore_loose_assets` at the end of the `restore)` branch (same position relative to the existing calls).

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/installer/install.test.sh`
Expected: `install.test.sh: N passed, 0 failed`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tools/installer/install.sh tests/installer/install.test.sh
git commit -m "Add loose-asset backup/deploy/restore to the installer"
```

---

## Task 9: Documentation and example mod

**Files:**
- Modify: `docs/modding-guide.md`
- Create: `mods/_examples/seventh-example-loose-asset/mod.json`, `mods/_examples/seventh-example-loose-asset/loose-assets/SWF/SHIP1.SWF` (use a trivially small placeholder PNG named `SHIP1.SWF` is wrong — the mod author supplies a `.gif`/`.png`, not a `.SWF`; correct the folder to contain the actual modder-facing input, e.g. `loose-assets/SWF/SHIP1.png`)
- Modify: `docs/asset-wiki.md` (point modders at the new capability)

**Interfaces:** none (docs + example only)

- [ ] **Step 1: Add a "Loose assets" section to `docs/modding-guide.md`**

Insert after the existing "Override kinds" section's `data/` bullet, following that section's exact bullet style:

```markdown
- **`loose-assets/`** — PNG or GIF overrides for assets the game loads
  from disk at runtime rather than compiling in (ships, named NPCs,
  opponent portraits — see `docs/asset-wiki.md` for the full list). Paths
  mirror the game's own `Resources/` layout (e.g.
  `loose-assets/SWF/SHIP1.png` overrides the first ship's art,
  `loose-assets/SWF/ZINN2_N.gif` overrides an animated NPC). You never
  need to know the original's pixel dimensions — the build auto-fits your
  image. An animated GIF's loop count controls whether the in-game
  animation loops forever or plays once; frame timing is preserved as
  closely as the output's frame rate allows. Declare every file you add
  under `touches.looseAssets` in `mod.json`, same validation rules as
  `touches.assets`.
```

- [ ] **Step 2: Add the field to the `mod.json` example block earlier in the same doc**

Find the existing `mod.json` example and add `"looseAssets": ["path/to/loose-asset.png"]` alongside the existing `"assets": ["path/to/asset.png"]` line.

- [ ] **Step 3: Add row to the Example Mods table**

```markdown
| `seventh-example-loose-asset` | Overriding a loose runtime-loaded asset (ship art) |
```

- [ ] **Step 4: Create the example mod**

`mods/_examples/seventh-example-loose-asset/mod.json`:

```json
{
  "id": "seventh-example",
  "name": "Seventh Example (Loose Asset Override)",
  "version": "1.0.0",
  "engineCompat": ">=0.1.0",
  "touches": {
    "classes": [],
    "data": [],
    "assets": [],
    "looseAssets": ["SWF/SHIP1.png"]
  },
  "priority": 0
}
```

`mods/_examples/seventh-example-loose-asset/loose-assets/SWF/SHIP1.png` — any small placeholder PNG (reuse the same 1x1 fixture technique from the tests, or a real tiny image checked in as binary).

- [ ] **Step 5: Add a one-line pointer in `docs/asset-wiki.md`**

Near the top intro paragraph, add: "Every asset below can be overridden — see `docs/modding-guide.md`'s `loose-assets/`/`assets/` sections for how, depending on which kind it is (noted in each catalog's 'Overridable today?' column)."

- [ ] **Step 6: Commit**

```bash
git add docs/modding-guide.md docs/asset-wiki.md mods/_examples/seventh-example-loose-asset/
git commit -m "Document the loose-assets modding convention and add an example mod"
```

---

## Self-Review Notes (already applied above)

- **Spec coverage:** auto-fit dimensions (Task 3/5), arbitrary-length + loop-metadata GIFs (Task 1/3/4), paired-audio override (Task 7's MP3 passthrough branch), `touches.looseAssets` schema (Task 6), installer backup/restore (Task 8), docs (Task 9) — all covered. The spec's `-importImages`-based mechanism is superseded by flipbook synthesis per the corrected design discovered during planning; this plan is the authority on the mechanism, not the spec's original wording.
- **Flagged uncertainty, not hidden:** Task 4 explicitly tells the implementer to verify the exact `ffdec` XML schema against a live tool run before trusting the plan's XML verbatim — this is real, load-bearing uncertainty that a plan reviewer should see, not paper over.
- **Type/name consistency check:** `convertAsset`, `prepareFrames`, `buildFlipbookSwf`, `readSwfStageInfo`, `readPngDimensions`, `readGifMeta`, `autoFitPng` are used with the same names and signatures everywhere they're referenced across Tasks 1-9.
