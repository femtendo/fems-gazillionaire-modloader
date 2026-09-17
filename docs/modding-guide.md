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
another one — declaring it inaccurately will fail the build.

## Enabling mods

List enabled mod IDs in your local `mods/enabled.json` (not committed) and
run the build. Mods that touch different systems combine automatically.
Mods that touch the same class or file will fail the build with a conflict
message unless you set different `priority` values.

## Multiplayer compatibility

The built-in multiplayer mod touches the game's turn/state-machine classes.
Any mod that also touches those classes will conflict with multiplayer —
this is an accepted limitation, not a bug. Everyone in an online session
must be running an identical set of mods; mismatches are rejected on join.
