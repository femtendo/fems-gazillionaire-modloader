# Modding guide

A mod is a folder under `mods/` containing a manifest plus any source,
data, or asset overrides it needs.

## Layout

```
mods/your-mod-name/
  mod.json
  src/...      # full-file class replacements or new classes
  data/...     # JSON value overrides
  assets/...   # drop-in replacement art/audio
```

## `mod.json`

```json
{
  "id": "your-mod-id",
  "name": "Your Mod Name",
  "version": "1.0.0",
  "engineCompat": ">=0.5.0",
  "touches": {
    "classes": ["fully.qualified.ClassName"],
    "data": ["path/to/data/file.json"],
    "assets": ["path/to/asset.png"]
  },
  "priority": 0
}
```

List every class, data file, and asset your mod overrides or adds in
`touches`. This is how the loader decides whether your mod conflicts with
another one — declaring it inaccurately will fail the build. Validation
runs both directions: a declared touch with no matching file is an error,
and a file that exists but isn't declared is also an error.

`engineCompat` is checked against `engine/engine.manifest.json`'s
`engineVersion` at build time (only the `">=X.Y.Z"` form is supported); a
mod that needs a newer engine than you have aborts the build with a clear
message instead of compiling against an engine it wasn't written for.

## Override kinds

- **`src/`** — full-file class replacement or a brand new class. AS3
  classes in this engine live at the top level with no package nesting, so
  a class named `Foo` is `src/Foo.as`. Replacing an existing file overrides
  it; adding a file the engine doesn't have adds a new class.
- **`assets/`** — drop-in replacement art/audio. Paths mirror
  `engine/src/assets/` (e.g. `assets/109.png` overrides
  `engine/src/assets/109.png`) since Flex resolves `Embed` paths relative to
  the compiling file's directory.
- **`data/`** — JSON files that merge at the *key* level instead of the
  full-file replace rule everything else uses: two mods can both ship
  `data/balance.json` as long as they set different top-level keys. Only a
  mod's actual JSON *keys* matter for conflict detection, not the whole
  file, so `touches.data` conflicts are reported per key.

## Enabling mods

List enabled mod IDs in your local `mods/enabled.json` (not committed) and
run the build. Mods that touch different systems combine automatically.
Mods that touch the same class, asset, or data key will fail the build with
a conflict message unless you set different `priority` values, in which
case the higher-priority mod's file silently wins and a warning names what
was suppressed.

## Example mods

`mods/_examples/` has one working example per override kind — read these
before writing your own:

| Mod | Demonstrates |
|-----|--------------|
| `hello-world-mod` | Overriding an existing class (`GameStrings`) |
| `second-example-mod` | A second, disjoint class override (`LoadScreen`), for testing mod stacking |
| `third-example-new-class` | Adding a brand new class the engine doesn't have |
| `fourth-example-asset-override` | Overriding a drop-in asset (`assets/109.png`) |
| `fifth-example-data-a` + `sixth-example-data-b` | Two mods merging disjoint keys of the same `data/balance.json` |
| `jerma985-mod` | Full-file class override at maximum coverage — every one of `GameStrings`'s ~3000 string values replaced, for stress-testing the text-override path |

None of these are enabled by default — copy IDs into your own
`mods/enabled.json` to try them.

## Multiplayer compatibility

The built-in multiplayer mod touches the game's turn/state-machine classes.
Any mod that also touches those classes will conflict with multiplayer —
this is an accepted limitation, not a bug. Everyone in an online session
must be running an identical set of mods; mismatches are rejected on join.
