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

console.log('loose-assets.test.js: all assertions passed');
