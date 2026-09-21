#!/usr/bin/env node
// Self-check for PNG/GIF parsing logic in tools/modloader/loose-assets.js.
// Run directly: node tests/modloader/loose-assets.test.js
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

// Minimal 2-frame animated GIF, hand-built to exercise the loop/delay
// parser: GIF89a header, logical screen descriptor, a NETSCAPE2.0
// application extension (loop count = 0, i.e. infinite), two
// Graphic Control Extension + Image Descriptor pairs (delay 10cs and
// 50cs), each followed by a trivial 1-byte LZW image data block, and a
// trailer. Real GIF-writing libraries produce more valid image data;
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

// GIF with Global Color Table (GCT): the LSD's packed byte has bit 7 set,
// followed by a real color table of 2^(size+1) entries, each 3 bytes (RGB).
// The parser must skip over the GCT before starting block-walking.
function makeGifWithGct({ loopCount, delaysCs, gctSize }) {
    const parts = [];
    parts.push(Buffer.from('GIF89a', 'ascii'));
    // Logical Screen Descriptor with GCT: width=1, height=1
    // Packed byte: bit 7 set (GCT present), bits 2-0 = log2(gctSize) - 1
    // (since 2^(size+1) = entries, so size = log2(gctSize) - 1)
    // For gctSize=2: size=0, packed=0x80|0=0x80
    // For gctSize=4: size=1, packed=0x80|1=0x81
    const sizeField = Math.log2(gctSize) - 1;
    const packedByte = 0x80 | sizeField;
    parts.push(Buffer.from([1, 0, 1, 0, packedByte, 0, 0]));
    // Global Color Table: gctSize entries, each 3 bytes (RGB)
    const gct = Buffer.alloc(gctSize * 3);
    for (let i = 0; i < gctSize * 3; i++) {
        gct[i] = i & 0xff;
    }
    parts.push(gct);

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
    // Test GIF with 2-entry Global Color Table
    const meta = readGifMeta(makeGifWithGct({ loopCount: 3, delaysCs: [20, 30], gctSize: 2 }));
    assert.strictEqual(meta.loopCount, 3);
    assert.deepStrictEqual(meta.frameDelaysCs, [20, 30]);
}

{
    // Test truncated GIF (missing trailer and final frame data)
    const truncated = Buffer.from('GIF89a\x01\x00\x01\x00\x00\x00\x00\x21\xf9\x04\x00\x0a\x00');
    assert.throws(
        () => readGifMeta(truncated),
        /Malformed GIF: truncated/,
        'should throw on truncated GIF'
    );
}

{
    // Test truncated GIF with GCT flag set: packed byte 0x87 declares 256-entry color table,
    // but buffer ends right after LSD, with no GCT bytes. Must throw, not return empty result.
    const truncatedWithGctFlag = Buffer.from('GIF89a\x01\x00\x01\x00\x87\x00\x00');
    assert.throws(
        () => readGifMeta(truncatedWithGctFlag),
        /Malformed GIF: truncated/,
        'should throw on GIF with GCT flag but truncated before GCT data'
    );
}

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

const { prepareFrames } = require('../../tools/modloader/loose-assets');
const osMod = require('os');
const { execFileSync } = require('child_process');

{
    const workDir = fsMod.mkdtempSync(pathMod.join(osMod.tmpdir(), 'loose-assets-test-'));
    const pngPath = pathMod.join(workDir, 'in.png');
    // A real 1x1 PNG (minimal valid encoding, magic bytes + IHDR + IDAT + IEND)
    // is required here since prepareFrames actually shells out to ffmpeg to
    // resize it — reuse a tiny known-good 1x1 white PNG byte literal.
    // (Note: the byte literal originally drafted for this fixture had a
    // corrupt zlib/Adler32 checksum in its IDAT chunk that ffmpeg's PNG
    // decoder correctly rejects — this is a freshly-generated valid 1x1
    // RGBA PNG with the same shape/intent.)
    const onePixelPng = Buffer.from(
        '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c63f8ffffff7f0009fb03fd2a86e38a' +
        '0000000049454e44ae426082', 'hex'
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

console.log('loose-assets.test.js: all assertions passed');
