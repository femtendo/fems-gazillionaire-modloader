#!/usr/bin/env node
// Self-check for the conflict-detection logic in tools/modloader/mods.js.
// Run directly: node tests/modloader/conflicts.test.js
const assert = require('assert');
const { computeTouchSets, detectConflicts } = require('../../tools/modloader/mods');

function manifest(id, priority, touches) {
    return { id, priority, touches, _dir: '/fake/' + id };
}

// Disjoint mods: no conflicts, no suppressions.
{
    const mods = [
        manifest('a', 0, { classes: ['A'], data: [], assets: [] }),
        manifest('b', 0, { classes: ['B'], data: [], assets: [] })
    ];
    const { hardFailures, suppressions } = detectConflicts(
        computeTouchSets(mods),
        new Map(mods.map((m) => [m.id, m]))
    );
    assert.strictEqual(hardFailures.length, 0);
    assert.strictEqual(suppressions.length, 0);
}

// Equal priority + overlapping touch: hard failure naming both mods.
{
    const mods = [
        manifest('a', 0, { classes: ['Shared'], data: [], assets: [] }),
        manifest('b', 0, { classes: ['Shared'], data: [], assets: [] })
    ];
    const { hardFailures } = detectConflicts(
        computeTouchSets(mods),
        new Map(mods.map((m) => [m.id, m]))
    );
    assert.strictEqual(hardFailures.length, 1);
    assert.deepStrictEqual(hardFailures[0].modIds.sort(), ['a', 'b']);
    assert.deepStrictEqual(hardFailures[0].overlap, ['Shared']);
}

// Different priority + overlapping touch: suppression, not a hard failure.
{
    const mods = [
        manifest('low', 0, { classes: ['Shared'], data: [], assets: [] }),
        manifest('high', 5, { classes: ['Shared'], data: [], assets: [] })
    ];
    const { hardFailures, suppressions } = detectConflicts(
        computeTouchSets(mods),
        new Map(mods.map((m) => [m.id, m]))
    );
    assert.strictEqual(hardFailures.length, 0);
    assert.strictEqual(suppressions.length, 1);
    assert.strictEqual(suppressions[0].winner, 'high');
    assert.strictEqual(suppressions[0].loser, 'low');
}

// data:/asset: prefixes keep those namespaces from colliding with class names.
{
    const mods = [
        manifest('a', 0, { classes: [], data: ['x'], assets: [] }),
        manifest('b', 0, { classes: ['x'], data: [], assets: [] })
    ];
    const { hardFailures } = detectConflicts(
        computeTouchSets(mods),
        new Map(mods.map((m) => [m.id, m]))
    );
    assert.strictEqual(hardFailures.length, 0);
}

console.log('conflicts.test.js: all assertions passed');
