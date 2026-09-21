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
    if (buffer.length < 13) {
        throw new Error('Malformed GIF: truncated header');
    }
    let loopCount = null;
    const frameDelaysCs = [];
    let i = 6 + 7; // signature + logical screen descriptor (fixed 7 bytes)

    // Account for Global Color Table (GCT) if present. The packed fields byte
    // (at buffer[10]) bit 7 indicates GCT presence; if set, GCT size is
    // 2 << (packed & 0x07) entries, each 3 bytes (RGB).
    const packedByte = buffer[10];
    if ((packedByte & 0x80) !== 0) {
        const gctSize = 2 << (packedByte & 0x07);
        i += gctSize * 3;
        if (i > buffer.length) {
            throw new Error('Malformed GIF: truncated');
        }
    }

    let pendingDelay = 10; // GIF default when no Graphic Control Extension precedes a frame

    function skipSubBlocks(pos) {
        while (pos < buffer.length && buffer[pos] !== 0x00) {
            if (pos + 1 > buffer.length) {
                throw new Error('Malformed GIF: truncated block data');
            }
            pos += 1 + buffer[pos];
        }
        if (pos >= buffer.length) {
            throw new Error('Malformed GIF: truncated block data');
        }
        return pos + 1;
    }

    while (i < buffer.length) {
        const marker = buffer[i];
        if (marker === 0x21) { // Extension
            if (i + 1 >= buffer.length) {
                throw new Error('Malformed GIF: truncated extension block');
            }
            const label = buffer[i + 1];
            if (label === 0xff && i + 14 <= buffer.length && buffer.toString('ascii', i + 3, i + 14) === 'NETSCAPE2.0') {
                // block: 0x21 0xff 0x0b "NETSCAPE2.0" 0x03 0x01 <loop-lo> <loop-hi> 0x00
                if (i + 18 >= buffer.length) {
                    throw new Error('Malformed GIF: truncated extension block');
                }
                loopCount = buffer.readUInt16LE(i + 16);
                i = i + 19;
            } else if (label === 0xf9) {
                // Graphic Control Extension: 0x21 0xf9 0x04 <flags> <delay-lo> <delay-hi> <transparent> 0x00
                if (i + 8 > buffer.length) {
                    throw new Error('Malformed GIF: truncated extension block');
                }
                pendingDelay = buffer.readUInt16LE(i + 4);
                i = i + 8;
            } else {
                i = skipSubBlocks(i + 2);
            }
        } else if (marker === 0x2c) { // Image Descriptor -> a real frame
            if (i + 10 >= buffer.length) {
                throw new Error('Malformed GIF: truncated image descriptor');
            }
            frameDelaysCs.push(pendingDelay);
            pendingDelay = 10;
            const hasLocalColorTable = (buffer[i + 9] & 0x80) !== 0;
            let pos = i + 10;
            if (hasLocalColorTable) {
                const tableSize = 2 << (buffer[i + 9] & 0x07);
                pos += tableSize * 3;
            }
            pos += 1; // LZW minimum code size byte
            if (pos > buffer.length) {
                throw new Error('Malformed GIF: truncated block data');
            }
            i = skipSubBlocks(pos);
        } else if (marker === 0x3b) { // Trailer
            break;
        } else {
            break; // Unknown/malformed — stop rather than loop forever
        }
    }

    return { loopCount, frameDelaysCs };
}

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
