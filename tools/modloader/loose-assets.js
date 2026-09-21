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
                i = i + 19;
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
