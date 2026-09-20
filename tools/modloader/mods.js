// Mod discovery, conflict detection, and cache-key logic for the build pipeline.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function loadEnabledMods(rootDir) {
    const enabledPath = path.join(rootDir, 'mods', 'enabled.json');
    if (!fs.existsSync(enabledPath)) return [];
    return JSON.parse(fs.readFileSync(enabledPath, 'utf8'));
}

function findModDirs(dir, depth) {
    if (depth < 0) return [];
    const out = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (!entry.isDirectory()) continue;
        const full = path.join(dir, entry.name);
        if (fs.existsSync(path.join(full, 'mod.json'))) out.push(full);
        else out.push(...findModDirs(full, depth - 1));
    }
    return out;
}

function loadModManifest(rootDir, modId) {
    const modsDir = path.join(rootDir, 'mods');
    // Mod dirs are usually direct children of mods/, but examples live one
    // level deeper under mods/_examples/ — search a couple levels down.
    for (const dir of findModDirs(modsDir, 2)) {
        const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'mod.json'), 'utf8'));
        if (manifest.id === modId) {
            manifest._dir = dir;
            return manifest;
        }
    }
    throw new Error(`No mod found with id "${modId}" under ${modsDir}`);
}

function readJsonObjectSafe(filePath) {
    try {
        const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) return parsed;
    } catch (e) {
        // Not JSON, or not an object — caller falls back to whole-file identity.
    }
    return null;
}

// Data touches expand to one identifier per top-level JSON key
// ('data:file.json#key') so two mods editing different keys of the same
// file are disjoint, per the plan's key-level merge exception for data.
// Non-object/non-JSON data files fall back to a single whole-file identifier.
function computeTouchSets(manifests) {
    const byId = new Map();
    for (const m of manifests) {
        const set = new Set(m.touches?.classes || []);
        for (const a of m.touches?.assets || []) set.add('asset:' + a);
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

function detectConflicts(touchSetsByModId, manifestsById) {
    const hardFailures = [];
    const suppressions = [];
    const ids = [...touchSetsByModId.keys()];
    for (let i = 0; i < ids.length; i++) {
        for (let j = i + 1; j < ids.length; j++) {
            const idA = ids[i];
            const idB = ids[j];
            const setA = touchSetsByModId.get(idA);
            const setB = touchSetsByModId.get(idB);
            const overlap = [...setA].filter((x) => setB.has(x));
            if (overlap.length === 0) continue;

            const priorityA = manifestsById.get(idA).priority || 0;
            const priorityB = manifestsById.get(idB).priority || 0;
            if (priorityA === priorityB) {
                hardFailures.push({ modIds: [idA, idB], overlap });
            } else {
                const [winner, loser] =
                    priorityA > priorityB ? [idA, idB] : [idB, idA];
                suppressions.push({ winner, loser, overlap });
            }
        }
    }
    return { hardFailures, suppressions };
}

function hashFile(filePath) {
    return fs.readFileSync(filePath);
}

function collectFilesSorted(dir) {
    if (!fs.existsSync(dir)) return [];
    const out = [];
    (function walk(d) {
        for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
            const full = path.join(d, entry.name);
            if (entry.isDirectory()) walk(full);
            else out.push(full);
        }
    })(dir);
    return out.sort();
}

function relFilesUnder(dir) {
    if (!fs.existsSync(dir)) return [];
    const out = [];
    (function walk(d, prefix) {
        for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
            const rel = prefix ? prefix + '/' + entry.name : entry.name;
            if (entry.isDirectory()) walk(path.join(d, entry.name), rel);
            else out.push(rel);
        }
    })(dir, '');
    return out;
}

// Cross-checks a mod's declared touches against its actual files, both ways:
// a declared touch with no matching file, and a file with no declared touch,
// are both hard errors. Keeps conflict detection honest — a mod that
// undersells what it touches would otherwise defeat the conflict system.
function validateTouches(manifest) {
    const errors = [];
    const dir = manifest._dir;
    const touches = manifest.touches || {};

    const declaredClasses = new Set(touches.classes || []);
    for (const c of declaredClasses) {
        if (!fs.existsSync(path.join(dir, 'src', c + '.as'))) {
            errors.push(`${manifest.id}: touches.classes declares "${c}" but src/${c}.as does not exist`);
        }
    }
    for (const f of relFilesUnder(path.join(dir, 'src')).filter((f) => f.endsWith('.as'))) {
        const className = f.slice(0, -3);
        if (!declaredClasses.has(className)) {
            errors.push(`${manifest.id}: src/${f} exists but "${className}" is not declared in touches.classes`);
        }
    }

    for (const kind of ['assets', 'data']) {
        const declared = new Set(touches[kind] || []);
        for (const p of declared) {
            if (!fs.existsSync(path.join(dir, kind, p))) {
                errors.push(`${manifest.id}: touches.${kind} declares "${p}" but ${kind}/${p} does not exist`);
            }
        }
        for (const f of relFilesUnder(path.join(dir, kind))) {
            if (!declared.has(f)) {
                errors.push(`${manifest.id}: ${kind}/${f} exists but is not declared in touches.${kind}`);
            }
        }
    }
    return errors;
}

// Only supports the ">=X.Y.Z" form, which is the only form the plan/docs use.
function checkEngineCompat(manifest, engineVersion) {
    const req = manifest.engineCompat;
    const m = /^>=(\d+)\.(\d+)\.(\d+)$/.exec(req || '');
    if (!m) {
        return `${manifest.id}: engineCompat "${req}" is not a supported range (only ">=X.Y.Z" is supported)`;
    }
    const required = [Number(m[1]), Number(m[2]), Number(m[3])];
    const actual = (engineVersion || '0.0.0').split('.').map(Number);
    for (let i = 0; i < 3; i++) {
        if ((actual[i] || 0) > required[i]) return null;
        if ((actual[i] || 0) < required[i]) {
            return `${manifest.id}: engineCompat "${req}" requires a newer engine than this build (engine.manifest.json declares ${engineVersion})`;
        }
    }
    return null;
}

function computeCacheKey(manifests, engineSrcDir) {
    const entries = manifests
        .map((m) => {
            const hash = crypto.createHash('sha256');
            for (const sub of ['src', 'data', 'assets']) {
                for (const f of collectFilesSorted(path.join(m._dir, sub))) {
                    hash.update(hashFile(f));
                }
            }
            return { id: m.id, version: m.version, contentHash: hash.digest('hex') };
        })
        .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
    // engine/src's own content must be part of the cache key — otherwise a
    // merged-src cache entry from before an engine/src change (a decompile
    // fix, a bugfix, anything) gets silently reused forever for any mod set
    // whose own files haven't changed, serving stale engine code under a
    // cache "hit". Bit us for real: see _local/plans/PROJECT_PLAN.md session 7.
    let engineHash = '';
    if (engineSrcDir) {
        const hash = crypto.createHash('sha256');
        for (const f of collectFilesSorted(engineSrcDir)) {
            hash.update(hashFile(f));
        }
        engineHash = hash.digest('hex');
    }
    return crypto.createHash('sha256').update(JSON.stringify({ entries, engineHash })).digest('hex');
}

module.exports = {
    loadEnabledMods,
    loadModManifest,
    computeTouchSets,
    detectConflicts,
    computeCacheKey,
    validateTouches,
    checkEngineCompat,
    readJsonObjectSafe,
    collectFilesSorted
};
