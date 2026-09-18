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

function computeTouchSets(manifests) {
    const byId = new Map();
    for (const m of manifests) {
        const set = new Set([
            ...(m.touches?.classes || []),
            ...(m.touches?.data || []).map((d) => 'data:' + d),
            ...(m.touches?.assets || []).map((a) => 'asset:' + a)
        ]);
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

function computeCacheKey(manifests) {
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
    return crypto.createHash('sha256').update(JSON.stringify(entries)).digest('hex');
}

module.exports = {
    loadEnabledMods,
    loadModManifest,
    computeTouchSets,
    detectConflicts,
    computeCacheKey
};
