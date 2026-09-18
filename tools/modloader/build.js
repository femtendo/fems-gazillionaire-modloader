#!/usr/bin/env node
// Zero-mod build script for Gazillionaire.
// Reads engine/engine.manifest.json, invokes mxmlc against engine/src/,
// outputs to build/output/gazillionaire-modded.swf.
// Only implements the zero-mod case for now.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const {
    loadEnabledMods,
    loadModManifest,
    computeTouchSets,
    detectConflicts,
    computeCacheKey
} = require('./mods');

const ROOT = path.resolve(__dirname, '../..');
const ENGINE_DIR = path.resolve(ROOT, 'engine');
const SRC_DIR = path.resolve(ENGINE_DIR, 'src');
const BUILD_DIR = path.resolve(ROOT, 'build', 'output');
const MERGED_SRC_ROOT = path.resolve(ROOT, 'build', 'merged-src');
const SDK_DIR = path.resolve(ROOT, 'tools', '.sdk', 'flex');
const MXMLC = path.resolve(SDK_DIR, 'bin', 'mxmlc');
const OUTPUT_SWF = path.resolve(BUILD_DIR, 'gazillionaire-modded.swf');

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

    const cacheKey = computeCacheKey(modManifests);
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
    }
    sourceTreeDir = mergedDir;
}

// Determine swf-version from the codebase
// The app uses Flex SDK 4.6.0 with mx.* imports, so swf-version 43 is appropriate
// (Flex SDK 4.6 targets swf-version 43 by default)
const SWF_VERSION = 43;
const TARGET_PLAYER = '11.1';

// Build mxmlc command
// air-config.xml switches the compiler+framework libs to the AIR profile
// (this Flex 4.6.0 SDK bundles its own AIR SDK, no separate overlay needed)
const mxmlcArgs = [
    `-load-config+=${path.resolve(SDK_DIR, 'frameworks', 'air-config.xml')}`,
    `-swf-version=${SWF_VERSION}`,
    `-target-player=${TARGET_PLAYER}`,
    `-compiler.source-path=${sourceTreeDir}`,
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
