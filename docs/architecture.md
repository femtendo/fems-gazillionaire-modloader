# Architecture

## Overview

The game's logic lives entirely in `engine/src`, a source tree derived from
the shipped game and reorganized as our own maintained codebase. `tools/`
contains the build pipeline that turns `engine/src` plus any enabled mods
into a runnable patch, and the installer that applies it to a local Steam
install.

## Class map

To be filled in once the source is decompiled and organized (see
`PROJECT_PLAN.md` step "Map the structure"). This section should record:

- The turn/player/game-state classes (how a turn advances, where shared
  state is mutated at turn end).
- The market/economy classes (ships, cargo, commodities, prices).
- The existing Steam integration reference point.

## Engine versioning

`engine/engine.manifest.json` pins the official game version this engine
tree was derived from, via a SHA-256 of the original compiled file. The
installer refuses to patch anything that doesn't match, so a corrupted or
unexpected install is never silently modified.
