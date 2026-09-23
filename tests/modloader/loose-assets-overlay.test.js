#!/usr/bin/env node
// Self-check for tools/modloader/build.js's buildLooseAssetsOverlay: the
// loose-assets/ overlay pass that converts modder PNG/GIF/MP3 files
// against engine/loose-assets-manifest.json into build/output/loose-assets/.
//
// buildLooseAssetsOverlay only needs each "mod manifest" object to carry a
// `_dir` property (it reads `_dir/loose-assets/`), so fixtures here are
// plain temp directories rather than full mod.json + mods/enabled.json
// wiring — no need to go through the real mod-discovery/build.js CLI path
// (which is gated on mxmlc being installed, unrelated to this function).
//
// Run directly: node tests/modloader/loose-assets-overlay.test.js
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const {
    buildLooseAssetsOverlay,
    LOOSE_ASSETS_MANIFEST,
    LOOSE_ASSETS_OUTPUT_DIR,
    FFDEC_JAR
} = require('../../tools/modloader/build.js');

// Same known-good 1x1 PNG byte literal used elsewhere in this test suite
// (tests/modloader/loose-assets.test.js) — real enough for ffmpeg to decode.
const ONE_PIXEL_PNG = Buffer.from(
    '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c63f8ffffff7f0009fb03fd2a86e38a' +
    '0000000049454e44ae426082', 'hex'
);

function mkMod(baseDir, name) {
    const dir = path.join(baseDir, name);
    fs.mkdirSync(path.join(dir, 'loose-assets'), { recursive: true });
    return { id: name, _dir: dir };
}

assert.ok(fs.existsSync(LOOSE_ASSETS_MANIFEST), `${LOOSE_ASSETS_MANIFEST} must exist for this test`);
const referenceInfo = JSON.parse(fs.readFileSync(LOOSE_ASSETS_MANIFEST, 'utf8'));
assert.ok(referenceInfo['SWF/AGENT_L.SWF'], 'manifest must have a SWF/AGENT_L.SWF entry for this test to use');
assert.ok(referenceInfo['MP3/ADVERT.MP3'], 'manifest must have a MP3/ADVERT.MP3 entry for this test to use');

// (a) A loose SWF-folder override (modder PNG input) converts to a real SWF.
if (fs.existsSync(FFDEC_JAR)) {
    const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'loose-overlay-swf-'));
    const mod = mkMod(workDir, 'mod-swf');
    fs.mkdirSync(path.join(mod._dir, 'loose-assets', 'SWF'), { recursive: true });
    fs.writeFileSync(path.join(mod._dir, 'loose-assets', 'SWF', 'AGENT_L.png'), ONE_PIXEL_PNG);

    buildLooseAssetsOverlay([mod]);

    const outSwf = path.join(LOOSE_ASSETS_OUTPUT_DIR, 'SWF', 'AGENT_L.SWF');
    assert.ok(fs.existsSync(outSwf), 'buildLooseAssetsOverlay should produce SWF/AGENT_L.SWF');
    const sig = fs.readFileSync(outSwf).toString('ascii', 0, 3);
    assert.ok(['FWS', 'CWS', 'ZWS'].includes(sig), `expected a real SWF signature, got "${sig}"`);
    const producedManifest = JSON.parse(fs.readFileSync(path.join(LOOSE_ASSETS_OUTPUT_DIR, 'manifest.json'), 'utf8'));
    assert.deepStrictEqual(producedManifest, ['SWF/AGENT_L.SWF']);
    console.log('buildLooseAssetsOverlay (SWF override): passed —', sig);
} else {
    console.log('buildLooseAssetsOverlay (SWF override): skipped (ffdec not installed on this machine)');
}

// (b) A loose MP3-folder override passes through byte-for-byte (no
// conversion metadata needed — this is exactly the path that was
// previously dead code because the manifest had zero MP3 entries).
// (c) When two mods both ship a file at the same loose-assets path, the
// higher-priority (later in the array) mod's bytes win and the produced
// manifest lists the target path exactly once (no duplicate entries).
{
    const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'loose-overlay-mp3-'));
    const modLow = mkMod(workDir, 'mod-low-priority');
    const modHigh = mkMod(workDir, 'mod-high-priority');
    fs.mkdirSync(path.join(modLow._dir, 'loose-assets', 'MP3'), { recursive: true });
    fs.mkdirSync(path.join(modHigh._dir, 'loose-assets', 'MP3'), { recursive: true });
    const lowBytes = Buffer.from('LOW-PRIORITY-MP3-BYTES');
    const highBytes = Buffer.from('HIGH-PRIORITY-MP3-BYTES');
    fs.writeFileSync(path.join(modLow._dir, 'loose-assets', 'MP3', 'ADVERT.MP3'), lowBytes);
    fs.writeFileSync(path.join(modHigh._dir, 'loose-assets', 'MP3', 'ADVERT.MP3'), highBytes);

    // Lowest priority first, matching how build.js calls this (inPriorityOrder).
    buildLooseAssetsOverlay([modLow, modHigh]);

    const outMp3 = path.join(LOOSE_ASSETS_OUTPUT_DIR, 'MP3', 'ADVERT.MP3');
    assert.ok(fs.existsSync(outMp3), 'buildLooseAssetsOverlay should produce MP3/ADVERT.MP3');
    assert.ok(fs.readFileSync(outMp3).equals(highBytes), 'MP3 passthrough should copy bytes exactly, and the higher-priority mod should win');
    assert.ok(!fs.readFileSync(outMp3).equals(lowBytes), 'the lower-priority mod\'s bytes should have been overwritten');

    const producedManifest = JSON.parse(fs.readFileSync(path.join(LOOSE_ASSETS_OUTPUT_DIR, 'manifest.json'), 'utf8'));
    assert.deepStrictEqual(producedManifest, ['MP3/ADVERT.MP3'], 'the produced manifest must list the shared target path exactly once, not once per contributing mod');
    console.log('buildLooseAssetsOverlay (MP3 passthrough + dedup): passed —', producedManifest);
}

console.log('loose-assets-overlay.test.js: all assertions passed');
