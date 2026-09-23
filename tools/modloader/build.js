#!/usr/bin/env node
// Zero-mod build script for Gazillionaire.
// Reads engine/engine.manifest.json, invokes mxmlc against engine/src/,
// outputs to build/output/gazillionaire-modded.swf.
// Only implements the zero-mod case for now.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execFileSync } = require('child_process');
const {
    loadEnabledMods,
    loadModManifest,
    computeTouchSets,
    detectConflicts,
    computeCacheKey,
    validateTouches,
    checkEngineCompat,
    readJsonObjectSafe,
    collectFilesSorted
} = require('./mods');
const { convertAsset, prepareFrames, buildFlipbookSwf, autoFitPng, resolveLooseAssetTargetPath } = require('./loose-assets');

const ROOT = path.resolve(__dirname, '../..');
const ENGINE_DIR = path.resolve(ROOT, 'engine');
const SRC_DIR = path.resolve(ENGINE_DIR, 'src');
const BUILD_DIR = path.resolve(ROOT, 'build', 'output');
const MERGED_SRC_ROOT = path.resolve(ROOT, 'build', 'merged-src');
const GENERATED_SRC_DIR = path.resolve(ROOT, 'build', 'generated');
const SDK_DIR = path.resolve(ROOT, 'tools', '.sdk', 'flex');
const MXMLC = path.resolve(SDK_DIR, 'bin', 'mxmlc');
const OUTPUT_SWF = path.resolve(BUILD_DIR, 'gazillionaire-modded.swf');
// ffdec is a machine-local tool (not fetched by tools/fetch-sdk.sh, and
// tools/.local/ / tools/.sdk/ are gitignored/untracked) — every use of it
// throughout this project's history resolves it at ~/tools/ffdec/ffdec.jar.
const FFDEC_JAR = path.join(require('os').homedir(), 'tools', 'ffdec', 'ffdec.jar');
const LOOSE_ASSETS_OUTPUT_DIR = path.resolve(BUILD_DIR, 'loose-assets');
const LOOSE_ASSETS_MANIFEST = path.resolve(ENGINE_DIR, 'loose-assets-manifest.json');

// Writes engine/src's sibling ModLoaderInfo.as, embedding the actually-
// resolved enabled mod set as compiled-in constants (not read from disk at
// runtime — this SWF's CustomPreloader shows this on the boot screen like
// most mod loaders do: how many mods loaded, a build hash, pass/fail).
// Kept in build/generated/ (gitignored, added as its own -compiler.source-
// path entry below) rather than written into engine/src, so the tracked
// source tree never contains a generated file.
function writeModLoaderInfo(modManifests, cacheKey) {
    const modCount = modManifests.length;
    const buildHash = modCount > 0
        ? cacheKey.slice(0, 10)
        : crypto.createHash('sha256').update('zero-mods').digest('hex').slice(0, 10);
    const src = `package
{
   public class ModLoaderInfo
   {
      public static const MOD_COUNT:int = ${modCount};
      public static const BUILD_HASH:String = "${buildHash}";
      public static const VALIDATED:Boolean = true;
   }
}
`;
    fs.mkdirSync(GENERATED_SRC_DIR, { recursive: true });
    fs.writeFileSync(path.join(GENERATED_SRC_DIR, 'ModLoaderInfo.as'), src);
}

// Overlays enabled mods' loose-assets/ (SWF/PNG files the engine loads from
// disk at runtime rather than [Embed]-ing at compile time — see Task 6's
// touches.looseAssets) onto build/output/loose-assets/, converting each
// against known target dimensions/frame-rate from a checked-in metadata
// manifest rather than the real game install (which may not be present on
// the build machine at all).
function buildLooseAssetsOverlay(modManifestsInPriorityOrder) {
    // Always clear the previous overlay and (re)write a manifest — including
    // the zero-mod / no-loose-assets-mods case, which must produce an EMPTY
    // manifest rather than leaving a prior build's stale
    // build/output/loose-assets/ (and its manifest) sitting around. Without
    // this, rebuilding with fewer/no mods enabled left install.sh re-
    // deploying loose assets from a mod set that's no longer even part of
    // this build.
    fs.rmSync(LOOSE_ASSETS_OUTPUT_DIR, { recursive: true, force: true });
    const referenceInfo = fs.existsSync(LOOSE_ASSETS_MANIFEST)
        ? JSON.parse(fs.readFileSync(LOOSE_ASSETS_MANIFEST, 'utf8'))
        : null;
    // A Set, not an array: a suppressed-priority mod and the winning mod can
    // both physically ship a file at the same loose-assets path (both get
    // iterated and converted/copied in priority order, even though only the
    // higher-priority one's bytes end up on disk at the end) — the produced
    // manifest must list each target path once, not once per contributing mod.
    const produced = new Set();

    for (const m of modManifestsInPriorityOrder) {
        const modLooseAssets = path.join(m._dir, 'loose-assets');
        if (!fs.existsSync(modLooseAssets)) continue;
        if (!referenceInfo) {
            throw new Error(`build aborted: ${m.id} ships loose-assets/ but ${LOOSE_ASSETS_MANIFEST} does not exist to convert against`);
        }
        for (const relPath of collectFilesSorted(modLooseAssets).map((f) => path.relative(modLooseAssets, f))) {
            // Resolved (and upper-cased) via the same helper mods.js uses for
            // conflict detection, so both places agree on what real file a
            // given source path actually overwrites regardless of the
            // modder's input casing/extension (e.g. "MP3/zinn.mp3" and
            // "SWF/SHIP1.gif" both need to land on the manifest's own
            // upper-cased keys, e.g. "MP3/ZINN.MP3"/"SWF/SHIP1.SWF").
            const targetResourcesPath = resolveLooseAssetTargetPath(relPath);
            const meta = referenceInfo[targetResourcesPath];
            if (!meta) {
                throw new Error(`build aborted: loose-assets/${relPath}: no known target "${targetResourcesPath}" in ${LOOSE_ASSETS_MANIFEST} — check the filename against docs/asset-wiki.md`);
            }
            const inputPath = path.join(modLooseAssets, relPath);
            const outputPath = path.join(LOOSE_ASSETS_OUTPUT_DIR, targetResourcesPath);
            fs.mkdirSync(path.dirname(outputPath), { recursive: true });

            if (targetResourcesPath.endsWith('.SWF')) {
                const workDir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'loose-swf-'));
                const { framePaths, loopForever } = prepareFrames(inputPath, meta.widthPx, meta.heightPx, meta.frameRate, workDir);
                buildFlipbookSwf(framePaths, meta.widthPx, meta.heightPx, meta.frameRate, loopForever, outputPath, FFDEC_JAR);
                fs.rmSync(workDir, { recursive: true, force: true });
            } else if (targetResourcesPath.endsWith('.PNG')) {
                // Same guard convertAsset applies to a SWF-target's raster
                // passthrough case: a static PNG target has no timeline to
                // animate, so an animated GIF input can't replace it — fail
                // with a clear message instead of ffmpeg's raw stderr about
                // an unsupported multi-frame-to-single-frame conversion.
                const inputBuffer = fs.readFileSync(inputPath);
                const sig = inputBuffer.toString('ascii', 0, 6);
                if (sig === 'GIF89a' || sig === 'GIF87a') {
                    throw new Error(
                        `build aborted: loose-assets/${relPath} is a static raster target (${targetResourcesPath}) — ` +
                        `an animated GIF can't replace it (there's no SWF timeline here to animate). Supply a static PNG instead.`
                    );
                }
                autoFitPng(inputPath, outputPath, meta.widthPx, meta.heightPx);
            } else {
                // MP3: plain passthrough, no conversion.
                fs.copyFileSync(inputPath, outputPath);
            }
            produced.add(targetResourcesPath);
        }
    }

    fs.mkdirSync(LOOSE_ASSETS_OUTPUT_DIR, { recursive: true });
    fs.writeFileSync(path.join(LOOSE_ASSETS_OUTPUT_DIR, 'manifest.json'), JSON.stringify([...produced], null, 2) + '\n');
}

// Exported for tests/modloader/loose-assets-overlay.test.js, which exercises
// buildLooseAssetsOverlay directly against fixture mods without going
// through the mxmlc-availability gate below (mxmlc is unrelated to this
// function, but a plain `require('./build')` would otherwise immediately
// run the whole build — see the `require.main === module` guard below).
module.exports = { buildLooseAssetsOverlay, LOOSE_ASSETS_MANIFEST, LOOSE_ASSETS_OUTPUT_DIR, FFDEC_JAR };

// Everything below only runs when this file is executed directly (node
// tools/modloader/build.js), not when it's require()'d by a test.
if (require.main === module) {

// Verify mxmlc exists
if (!fs.existsSync(MXMLC)) {
    console.error(`mxmlc not found at ${MXMLC}`);
    process.exit(1);
}

// ffdec and ffmpeg are only needed to convert a mod's assets/ or
// loose-assets/ files — a zero-mod build (or a mod set with no such files)
// never touches either tool, so the check is deferred until we actually
// know at least one enabled mod ships something needing conversion, rather
// than being an unconditional hard requirement for every build. See
// docs/known-issues.md and README.md's Requirements section.
function checkFfdecAvailable() {
    if (!fs.existsSync(FFDEC_JAR)) {
        console.error(`ffdec.jar not found at ${FFDEC_JAR} — needed to convert a mod's assets/ or loose-assets/ files (see docs/known-issues.md)`);
        process.exit(1);
    }
}
function checkFfmpegAvailable() {
    try {
        execFileSync('/bin/sh', ['-c', 'command -v ffmpeg'], { stdio: 'ignore' });
    } catch (e) {
        console.error('ffmpeg not found on PATH — needed to convert a mod\'s assets/ or loose-assets/ files (see README.md Requirements)');
        process.exit(1);
    }
}

// Read manifest
const manifestPath = path.resolve(ENGINE_DIR, 'engine.manifest.json');
if (!fs.existsSync(manifestPath)) {
    console.error(`engine.manifest.json not found at ${manifestPath}`);
    process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
console.log('Manifest:', JSON.stringify(manifest, null, 2));

// Resolve enabled mods, check for conflicts, and pick the source tree to compile.
const enabledModIds = loadEnabledMods(ROOT);
console.log('Enabled mods:', enabledModIds.length ? enabledModIds.join(', ') : '(none)');

let sourceTreeDir = SRC_DIR;

if (enabledModIds.length > 0) {
    const modManifests = enabledModIds.map((id) => loadModManifest(ROOT, id));
    const manifestsById = new Map(modManifests.map((m) => [m.id, m]));

    const validationErrors = [];
    for (const m of modManifests) {
        validationErrors.push(...validateTouches(m));
        const compatError = checkEngineCompat(m, manifest.engineVersion);
        if (compatError) validationErrors.push(compatError);
    }
    if (validationErrors.length > 0) {
        console.error('\nMod validation failed — build aborted:');
        for (const e of validationErrors) console.error('  ' + e);
        process.exit(1);
    }

    // Only require ffdec/ffmpeg once we know at least one enabled mod
    // actually ships assets/ or loose-assets/ files that need converting —
    // a mod that only touches src/ or data/ never needs either tool.
    const needsConversionTools = modManifests.some((m) =>
        fs.existsSync(path.join(m._dir, 'assets')) || fs.existsSync(path.join(m._dir, 'loose-assets'))
    );
    if (needsConversionTools) {
        checkFfdecAvailable();
        checkFfmpegAvailable();
    }

    const touchSets = computeTouchSets(modManifests);
    const { hardFailures, suppressions } = detectConflicts(touchSets, manifestsById);

    if (hardFailures.length > 0) {
        console.error('\nConflict detection failed — build aborted:');
        for (const f of hardFailures) {
            console.error(
                `  ${f.modIds[0]} <-> ${f.modIds[1]} (equal priority) overlap on: ${f.overlap.join(', ')}`
            );
        }
        process.exit(1);
    }
    for (const s of suppressions) {
        console.warn(
            `Warning: ${s.winner} (higher priority) suppresses ${s.loser} on: ${s.overlap.join(', ')}`
        );
    }

    const cacheKey = computeCacheKey(modManifests, SRC_DIR);
    writeModLoaderInfo(modManifests, cacheKey);
    const mergedDir = path.join(MERGED_SRC_ROOT, cacheKey);
    // Lowest priority first, so higher-priority mods overwrite last. Needed
    // both by the merged-src assembly below (cache-miss only) and by the
    // loose-assets overlay (which is not part of the merged-src cache and
    // must run every build regardless of cache hit/miss).
    const inPriorityOrder = [...modManifests].sort(
        (a, b) => (a.priority || 0) - (b.priority || 0)
    );
    if (fs.existsSync(mergedDir) && fs.readdirSync(mergedDir).length > 0) {
        console.log(`Cache hit: reusing merged source at ${mergedDir}`);
    } else {
        console.log(`Cache miss: assembling merged source at ${mergedDir}`);
        fs.mkdirSync(mergedDir, { recursive: true });
        fs.cpSync(SRC_DIR, mergedDir, { recursive: true });
        for (const m of inPriorityOrder) {
            const modSrc = path.join(m._dir, 'src');
            if (fs.existsSync(modSrc)) {
                fs.cpSync(modSrc, mergedDir, { recursive: true, force: true });
            }
        }

        // Assets: full-file overlay onto merged src/assets/ (same rule as
        // src/ — engine Embed tags resolve assets relative to the source
        // file's directory, so mod assets/ land at mergedDir/assets/).
        // A modder's PNG/GIF replacing a SWF-shaped [Embed] asset must be
        // converted (flipbook-synthesized), not plain-copied, or the
        // compiled SWF ends up with a broken (un-decodable) embed.
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

        // Data: JSON files merge at the key level (later/higher-priority mod
        // wins per key) instead of full-file replace — conflict detection
        // already guarantees no two enabled mods set the same key. Non-JSON
        // (or non-object) data files fall back to a full-file overlay.
        const dataByRelPath = new Map();
        for (const m of inPriorityOrder) {
            const modData = path.join(m._dir, 'data');
            if (!fs.existsSync(modData)) continue;
            for (const abs of collectFilesSorted(modData)) {
                const relPath = path.relative(modData, abs);
                const parsed = readJsonObjectSafe(abs);
                const existing = dataByRelPath.get(relPath);
                if (parsed && existing?.json) {
                    Object.assign(existing.json, parsed);
                } else if (parsed) {
                    dataByRelPath.set(relPath, { json: parsed });
                } else {
                    dataByRelPath.set(relPath, { raw: fs.readFileSync(abs) });
                }
            }
        }
        for (const [relPath, entry] of dataByRelPath) {
            const outFile = path.join(mergedDir, 'data', relPath);
            fs.mkdirSync(path.dirname(outFile), { recursive: true });
            fs.writeFileSync(outFile, entry.json ? JSON.stringify(entry.json, null, 2) + '\n' : entry.raw);
        }
    }
    sourceTreeDir = mergedDir;
    buildLooseAssetsOverlay(inPriorityOrder);
} else {
    writeModLoaderInfo([], '');
    // Unconditional even in the zero-mod case: clears out any stale
    // build/output/loose-assets/ (and its manifest) left over from a
    // previous build that had loose-asset mods enabled.
    buildLooseAssetsOverlay([]);
}

// Matches the real shipped SWF's header exactly (verified via swfdump):
// swf-version 43, built with Apache Flex 4.16.1 (not old Adobe Flex 4.6 —
// see tools/fetch-sdk.sh). tools/.sdk/flex/ has the HARMAN AIR SDK overlaid
// on top per Apache's documented procedure, so air-config.xml resolves.
const SWF_VERSION = 43;
const TARGET_PLAYER = '11.1';

// mxmlc's own default stage size (500x375) does NOT match the shipped
// game's real stage size (760x570, confirmed via swfdump on the original
// SWF's header, and matches the width/height set in Gazillionaire.as's own
// constructor) — has to be passed explicitly or windows come out too small.
const DEFAULT_WIDTH = 760;
const DEFAULT_HEIGHT = 570;

// mxmlc auto-generates its own SystemManager subclass for any
// WindowedApplication root (Gazillionaire extends WindowedApplication) —
// it does NOT use engine/src's decompiled _Gazillionaire_mx_managers_
// SystemManager.as at all (that file is itself just a decompiled copy of
// what the ORIGINAL build's compiler generated; ours generates a fresh,
// differently-named one every time and silently ignores the old one).
// -preloader and -default-size (passed as compiler flags below, not
// embedded in source) are what make the freshly generated SystemManager's
// info() populate correctly — without them "usePreloader" still defaults
// true but info()["preloader"] is undefined, causing an uncaught
// `new null()` deep in Preloader.initialize() before any window shows.
// [Mixin] metadata (on _Gazillionaire_Styles in engine/src) is Flex's own
// source-path-wide scan for self-registering init classes and wires the
// rest up without needing to fight the codegen further.
//
// IMPORTANT: compile directly from Gazillionaire.as, NOT from an .mxml
// wrapper. An earlier version of this build wrapped Gazillionaire (then
// named GazillionaireImpl) in a thin Gazillionaire.mxml entry point,
// working around what looked like an MXML-only requirement for info() to
// populate. That wrapper's real effect was to make mxmlc emit an extra
// `Gazillionaire extends GazillionaireImpl` subclass layer (MXML always
// generates a subclass of its root tag's referenced class) — doubling
// AVM2's verification work for this already-huge class (every member
// re-checked for override compatibility in the subclass), which is what
// caused AIR's boot-timeout watchdog to kill the app ~1-4s after launch,
// every time, regardless of how much the class itself was trimmed down
// (confirmed via extensive bisection — see docs/known-issues.md and
// _local/plans/PROJECT_PLAN.md). Compiling Gazillionaire.as directly with
// -preloader/-default-size as flags (not MXML attributes) populates
// info() correctly with NO extra subclass layer — this is the fix.
const PRELOADER_CLASS = 'CustomPreloader';

const mxmlcArgs = [
    `-load-config+=${path.resolve(SDK_DIR, 'frameworks', 'air-config.xml')}`,
    `-swf-version=${SWF_VERSION}`,
    `-target-player=${TARGET_PLAYER}`,
    '-default-size', String(DEFAULT_WIDTH), String(DEFAULT_HEIGHT),
    `-preloader=${PRELOADER_CLASS}`,
    `-compiler.source-path=${sourceTreeDir}`,
    `-compiler.source-path+=${GENERATED_SRC_DIR}`,
    '-define+=CONFIG::performanceInstrumentation,false',
    // mx.core.TextFieldFactory is only ever referenced reflectively, via
    // getDefinitionByName("mx.core::TextFieldFactory") inside the Flex
    // framework's own SystemManager.kickOff() (to register it as the
    // mx.core::ITextFieldFactory singleton implementation). Nothing in
    // this app's decompiled source statically imports/instantiates it, so
    // mxmlc's dead-code elimination silently drops the class from the
    // compiled SWF; at runtime, getDefinitionByName() then returns null,
    // Singleton.registerClass() stores that null, and the first component
    // whose validateSize()/measure() touches UITextFormat's textFieldFactory
    // getter (Singleton.getInstance) throws "No class registered for
    // interface 'mx.core::ITextFieldFactory'." — an uncaught exception
    // thrown from inside an ENTER_FRAME-dispatched callback
    // (LayoutManager.doPhasedInstantiationCallback), which AIR does not
    // surface via UncaughtErrorEvent (same swallowing behavior as the
    // earlier Timer.tick()-context TypeError root cause). This aborts
    // LayoutManager's phased instantiation permanently (it never
    // re-attaches its ENTER_FRAME listener), so FlexEvent.CREATION_COMPLETE
    // never fires, yet nothing crashes and other timers/listeners keep
    // running fine forever — explaining the "stuck at ~55-60% CPU forever,
    // no crash" symptom. Force-including the class here (confirmed present
    // in the pristine original SWF's disassembly, absent from ours without
    // this flag) fixes it without touching decompiled framework internals.
    '-includes=mx.core.TextFieldFactory',
    `-output=${OUTPUT_SWF}`,
    `-compiler.external-library-path=${path.resolve(SDK_DIR, 'frameworks')}`,
    '--',
    path.resolve(sourceTreeDir, 'Gazillionaire.as')
];

console.log('mxmlc command:', MXMLC, mxmlcArgs.join(' '));
console.log('');

// Create output directory
fs.mkdirSync(BUILD_DIR, { recursive: true });

try {
    const result = execFileSync(MXMLC, mxmlcArgs, {
        cwd: ROOT,
        env: { ...process.env, PATH: `${SDK_DIR}/bin:${process.env.PATH}` },
        maxBuffer: 10 * 1024 * 1024, // 10MB buffer
        timeout: 300000 // 5 minutes
    });
    console.log('Compile output:', result.toString());
} catch (error) {
    console.error('Compile failed!');
    console.error('stdout:', error.stdout?.toString());
    console.error('stderr:', error.stderr?.toString());
    console.error('exit code:', error.status);
    process.exit(error.status || 1);
}

// Check output
if (fs.existsSync(OUTPUT_SWF)) {
    const stats = fs.statSync(OUTPUT_SWF);
    console.log(`\nSuccess! Output SWF: ${OUTPUT_SWF} (${stats.size} bytes)`);
} else {
    console.error(`\nFailed! Output SWF not found at ${OUTPUT_SWF}`);
    process.exit(1);
}

} // if (require.main === module)
