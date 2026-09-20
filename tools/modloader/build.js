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

const ROOT = path.resolve(__dirname, '../..');
const ENGINE_DIR = path.resolve(ROOT, 'engine');
const SRC_DIR = path.resolve(ENGINE_DIR, 'src');
const BUILD_DIR = path.resolve(ROOT, 'build', 'output');
const MERGED_SRC_ROOT = path.resolve(ROOT, 'build', 'merged-src');
const GENERATED_SRC_DIR = path.resolve(ROOT, 'build', 'generated');
const SDK_DIR = path.resolve(ROOT, 'tools', '.sdk', 'flex');
const MXMLC = path.resolve(SDK_DIR, 'bin', 'mxmlc');
const OUTPUT_SWF = path.resolve(BUILD_DIR, 'gazillionaire-modded.swf');

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

// Verify mxmlc exists
if (!fs.existsSync(MXMLC)) {
    console.error(`mxmlc not found at ${MXMLC}`);
    process.exit(1);
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
    if (fs.existsSync(mergedDir) && fs.readdirSync(mergedDir).length > 0) {
        console.log(`Cache hit: reusing merged source at ${mergedDir}`);
    } else {
        console.log(`Cache miss: assembling merged source at ${mergedDir}`);
        fs.mkdirSync(mergedDir, { recursive: true });
        fs.cpSync(SRC_DIR, mergedDir, { recursive: true });
        // Lowest priority first, so higher-priority mods overwrite last.
        const inPriorityOrder = [...modManifests].sort(
            (a, b) => (a.priority || 0) - (b.priority || 0)
        );
        for (const m of inPriorityOrder) {
            const modSrc = path.join(m._dir, 'src');
            if (fs.existsSync(modSrc)) {
                fs.cpSync(modSrc, mergedDir, { recursive: true, force: true });
            }
        }

        // Assets: full-file overlay onto merged src/assets/ (same rule as
        // src/ — engine Embed tags resolve assets relative to the source
        // file's directory, so mod assets/ land at mergedDir/assets/).
        for (const m of inPriorityOrder) {
            const modAssets = path.join(m._dir, 'assets');
            if (fs.existsSync(modAssets)) {
                fs.cpSync(modAssets, path.join(mergedDir, 'assets'), { recursive: true, force: true });
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
} else {
    writeModLoaderInfo([], '');
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
