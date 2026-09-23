// Conversion core for the modder asset-upload pipeline: turns a modder's
// PNG/GIF into either a passthrough raster file or a synthesized SWF,
// given the original asset being overridden as sizing/timing reference.
const fs = require('fs');
const path = require('path');
const os = require('os');
const zlib = require('zlib');
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
    // -fps_mode passthrough (output-side option, must come after -i) forces
    // ffmpeg to emit exactly one PNG per decoded GIF frame. Without it,
    // ffmpeg defaults to resampling to the container's tbr, which for many
    // real-world GIFs is a multiple of the true frame rate (e.g. 2x) and
    // silently duplicates frames — tripping the frame-count guard below on
    // otherwise-valid GIFs.
    execFileSync(
        'ffmpeg',
        ['-y', '-i', inputPath, '-fps_mode', 'passthrough', path.join(rawDir, 'raw_%04d.png')],
        { stdio: 'pipe' }
    );
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

// Re-encodes a PNG to raw ARGB (top-down, row-major, 4 bytes/pixel: A,R,G,B)
// via ffmpeg, matching exactly what SWF's DefineBitsLossless bitmapFormat=5
// (32-bit ARGB) expects once zlib-deflated — this was cross-checked against
// a real ffdec-produced DefineBitsLosslessTag (see task-4-report.md).
function pngToArgb(pngPath) {
    const rawPath = pngPath + '.rgba';
    execFileSync('ffmpeg', ['-y', '-i', pngPath, '-pix_fmt', 'argb', '-f', 'rawvideo', rawPath], { stdio: 'pipe' });
    return fs.readFileSync(rawPath);
}

// Minimum bit width (SWF-spec "Nbits"/"NumBits" style: enough bits for a
// signed two's-complement value up to maxAbsValue, plus a 2-bit safety
// margin) needed to declare a coordinate/fixed-point field in ffdec's
// -xml2swf XML. Verified this session that ffdec recomputes the *actual*
// packed bit width itself at write time (an under-sized declared value
// still round-tripped correctly in testing), but real ffdec-emitted XML
// always declares a correctly-sized value, so we do too rather than
// relying on that leniency.
function bitsNeeded(maxAbsValue) {
    return Math.max(1, Math.floor(Math.log2(Math.max(1, maxAbsValue))) + 2);
}

// Builds a minimal N-frame SWF that shows framePaths[i] as a full-stage
// bitmap on output frame i, looping according to loopForever.
//
// Schema note (re-verified against a live `ffdec -swf2xml`/`-xml2swf` run
// this session — see task-4-report.md for the full transcript): a bare
// DefineBitsLosslessTag placed directly via PlaceObject2 does NOT render
// (confirmed by exporting frames from such a file: both came out as flat
// background color). Real ffdec-authored SWFs in this repo's own assets
// never place a bitmap character directly — they always wrap it as a
// bitmap fill inside a DefineShapeTag, then place *that* shape. We do the
// same: one DefineBitsLosslessTag + one DefineShapeTag (single rectangular
// fill covering the full stage, bitmapFillType 67 = clipped/non-smoothed)
// + one PlaceObject2Tag per output frame, followed by a ShowFrameTag, with
// characterIDs incrementing per frame so each frame swaps in fresh bitmap
// data at the same depth (placeFlagMove=true from the second frame on).
//
// Confirmed real attribute names (differ from earlier unverified notes):
// tag is "DefineBitsLosslessTag" (not "...Lossless2Tag") even for
// bitmapFormat="5" (32-bit ARGB); its character-id attribute is
// "characterID" (capital ID), while PlaceObject2Tag's is "characterId"
// (lowercase id) — these are NOT the same casing, easy to typo. Bitmap
// bytes are lower-case hex in "zlibBitmapData", not base64.
function buildFlipbookSwf(framePaths, widthPx, heightPx, frameRate, loopForever, outSwfPath, ffdecJarPath) {
    const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'flipbook-build-'));
    const seedXml = path.join(workDir, 'seed.xml');

    const wt = widthPx * 20; // SWF twips: 1px = 20 twips
    const ht = heightPx * 20;
    const rectBits = bitsNeeded(Math.max(wt, ht));
    const edgeBits = bitsNeeded(Math.max(wt, ht));
    const scaleFixed = Math.round(20 * 65536); // 20.0 as a 16.16 fixed-point value
    const scaleBits = bitsNeeded(scaleFixed);

    const tagItems = [];
    tagItems.push(
        '<item type="FileAttributesTag" actionScript3="true" forceWriteAsLong="false" hasMetadata="false" ' +
        'noCrossDomainCache="false" reservedA="false" reservedB="0" swfRelativeUrls="false" useDirectBlit="false" ' +
        'useGPU="false" useNetwork="false"/>'
    );
    tagItems.push(
        '<item type="SetBackgroundColorTag" forceWriteAsLong="false">' +
        '<backgroundColor type="RGB" blue="0" green="0" red="0"/></item>'
    );

    // Emit one DefineBitsLosslessTag + one DefineShapeTag per UNIQUE frame
    // path, not once per entry in framePaths. prepareFrames intentionally
    // pushes the SAME fitted PNG path multiple times to represent a GIF
    // frame's held duration (e.g. [f1, f1, f1, f2] for a frame held 3 output
    // ticks then a second frame held 1) — re-encoding/re-deflating and
    // defining a brand-new bitmap+shape pair per repeated entry bloated the
    // output far beyond what the actual distinct frame content needs. Each
    // OUTPUT frame still gets its own PlaceObject2Tag+ShowFrameTag pair
    // (that's what actually drives the timeline/timing), just referencing
    // the one shared character definition for repeats.
    const shapeIdByFramePath = new Map();
    let nextCharacterId = 1;
    for (const framePath of framePaths) {
        if (shapeIdByFramePath.has(framePath)) continue;
        const bitmapId = nextCharacterId++;
        const shapeId = nextCharacterId++;
        const argb = pngToArgb(framePath);
        const zlibHex = zlib.deflateSync(argb).toString('hex');

        tagItems.push(
            `<item type="DefineBitsLosslessTag" bitmapFormat="5" bitmapHeight="${heightPx}" ` +
            `bitmapWidth="${widthPx}" characterID="${bitmapId}" forceWriteAsLong="true" ` +
            `zlibBitmapData="${zlibHex}"/>`
        );
        tagItems.push(
            `<item type="DefineShapeTag" forceWriteAsLong="true" shapeId="${shapeId}">` +
            `<shapeBounds type="RECT" Xmax="${wt}" Xmin="0" Ymax="${ht}" Ymin="0" nbits="${rectBits}"/>` +
            '<shapes type="SHAPEWITHSTYLE" numFillBits="1" numLineBits="0">' +
            '<fillStyles type="FILLSTYLEARRAY"><fillStyles>' +
            `<item type="FILLSTYLE" bitmapId="${bitmapId}" fillStyleType="67">` +
            `<bitmapMatrix type="MATRIX" hasRotate="false" hasScale="true" nScaleBits="${scaleBits}" ` +
            'nTranslateBits="0" scaleX="20.0" scaleY="20.0" translateX="0" translateY="0"/>' +
            '</item></fillStyles></fillStyles>' +
            '<lineStyles type="LINESTYLEARRAY"><lineStyles/></lineStyles>' +
            '<shapeRecords>' +
            '<item type="StyleChangeRecord" fillStyle0="1" moveBits="1" moveDeltaX="0" moveDeltaY="0" ' +
            'stateFillStyle0="true" stateFillStyle1="false" stateLineStyle="false" stateMoveTo="true" ' +
            'stateNewStyles="false"/>' +
            `<item type="StraightEdgeRecord" deltaX="${wt}" generalLineFlag="false" numBits="${edgeBits}" vertLineFlag="false"/>` +
            `<item type="StraightEdgeRecord" deltaY="${ht}" generalLineFlag="false" numBits="${edgeBits}" vertLineFlag="true"/>` +
            `<item type="StraightEdgeRecord" deltaX="${-wt}" generalLineFlag="false" numBits="${edgeBits}" vertLineFlag="false"/>` +
            `<item type="StraightEdgeRecord" deltaY="${-ht}" generalLineFlag="false" numBits="${edgeBits}" vertLineFlag="true"/>` +
            '<item type="EndShapeRecord" endOfShape="0"/>' +
            '</shapeRecords></shapes></item>'
        );
        shapeIdByFramePath.set(framePath, shapeId);
    }

    framePaths.forEach((framePath, idx) => {
        const shapeId = shapeIdByFramePath.get(framePath);
        tagItems.push(
            `<item type="PlaceObject2Tag" characterId="${shapeId}" depth="1" forceWriteAsLong="false" ` +
            'placeFlagHasCharacter="true" placeFlagHasClipActions="false" placeFlagHasClipDepth="false" ' +
            'placeFlagHasColorTransform="false" placeFlagHasMatrix="true" placeFlagHasName="false" ' +
            `placeFlagHasRatio="false" placeFlagMove="${idx > 0}">` +
            '<matrix type="MATRIX" hasRotate="false" hasScale="false" nRotateBits="0" nScaleBits="0" ' +
            'nTranslateBits="0" translateX="0" translateY="0"/></item>'
        );
        tagItems.push('<item type="ShowFrameTag" forceWriteAsLong="false"/>');
    });

    // ActionStop (opcode 0x07) + ActionEnd (0x00) as raw AS1/2 bytecode —
    // DoActionTag's real field is "actionBytes" (raw hex), not a structured
    // "actions" list (confirmed via javap on ffdec_lib.jar's DoActionTag
    // class this session, then round-tripped through -swf2xml to verify).
    if (!loopForever) {
        tagItems.push('<item type="DoActionTag" actionBytes="0700" forceWriteAsLong="false"/>');
    }

    const xml = '<?xml version="1.0" encoding="UTF-8"?>' +
        `<swf _xmlExportMajor="2" _xmlExportMinor="2" type="SWF" charset="UTF-8" compression="ZLIB" ` +
        `encrypted="false" frameCount="${framePaths.length}" frameRate="${frameRate}" gfx="false" ` +
        'hasEndTag="true" version="9">' +
        `<displayRect type="RECT" Xmax="${wt}" Xmin="0" Ymax="${ht}" Ymin="0" nbits="${rectBits}"/>` +
        `<tags>${tagItems.join('')}</tags></swf>`;
    fs.writeFileSync(seedXml, xml);

    execFileSync('java', ['-jar', ffdecJarPath, '-xml2swf', seedXml, outSwfPath], { stdio: 'pipe' });
    fs.rmSync(workDir, { recursive: true, force: true });
}

// Resolves a modder's loose-assets/ relative path (as authored, e.g.
// "SWF/SHIP1.png", "PNG/OP1.png", or "MP3/zinn.mp3") to the actual
// Resources/-relative target path it will end up overwriting: PNG-folder
// targets keep ".PNG", SWF-folder targets always become ".SWF" regardless
// of whether the modder's input was a PNG or a GIF, and everything else
// (MP3) keeps its own extension. The result is upper-cased end-to-end so
// two mods whose declared source paths differ only in extension or casing
// but resolve to the same real file (e.g. "SWF/SHIP1.png" vs.
// "SWF/SHIP1.gif", or "MP3/zinn.mp3" vs. "MP3/ZINN.MP3") are recognized as
// the same target — both by build.js's reference-manifest lookup and by
// mods.js's conflict detection. Shared by both call sites so they can never
// drift apart.
function resolveLooseAssetTargetPath(relPath) {
    const normalized = relPath.replace(/\\/g, '/');
    const targetPath = normalized.replace(/\.(png|gif)$/i, () =>
        /^PNG\//i.test(normalized) ? '.PNG' : '.SWF'
    );
    return targetPath.toUpperCase();
}

function isSwf(buffer) {
    const sig = buffer.toString('ascii', 0, 3);
    return sig === 'FWS' || sig === 'CWS' || sig === 'ZWS';
}

// Single entry point build.js calls. Decides raster-passthrough vs.
// flipbook-synthesis by sniffing originalAssetPath's own bytes (PNG
// signature vs. SWF signature FWS/CWS/ZWS) rather than trusting its file
// extension — several real assets are SWFs saved with .bin/no extension.
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
    readPngDimensions, readGifMeta, readSwfStageInfo, prepareFrames, buildFlipbookSwf, convertAsset, autoFitPng,
    resolveLooseAssetTargetPath
};
