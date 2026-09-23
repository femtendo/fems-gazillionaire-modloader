# Gazillionaire Online

A fan-made mod loader and online multiplayer patch for Gazillionaire.

This project does not include any of the original game's code, art, or audio.
It requires a legitimate Steam copy of Gazillionaire to run. The installer
verifies your existing installation before patching it, and always keeps a
backup of the original file.

## What this is

- A mod loader that lets you stack multiple community mods (new ships, aliens,
  events, planets, resources, mechanics, art, and more) on top of the base
  game.
- An online multiplayer layer that adds networked play on top of the game's
  existing turn-based hotseat mode: one player hosts (a small relay server,
  run locally or on any reachable box) and shares a room code with friends
  however they'd normally talk to them — Steam chat included. See
  `docs/multiplayer-architecture.md` for why this doesn't use the Steamworks
  API directly (no SDK/AppID access to build a verified integration against).

## Requirements

- A legitimate Steam copy of Gazillionaire (macOS or Windows).
- Java (for the build tooling).
- [`ffdec`](docs/known-issues.md#build-requirement-ffdec-jpexs-free-flash-decompiler-and-ffmpeg)
  (JPEXS Free Flash Decompiler) at `~/tools/ffdec/ffdec.jar` — only needed
  if any enabled mod ships `assets/` or `loose-assets/` overrides.
- [`ffmpeg`](docs/known-issues.md#build-requirement-ffdec-jpexs-free-flash-decompiler-and-ffmpeg)
  on your `PATH` — only needed for that same case (image/GIF conversion for
  `assets/`/`loose-assets/` overrides).

## Installation

### Windows — from a pre-built package

If someone already built one of these for you, just run it — no
Node/Java/SDK needed on your machine at all:

- **`GazillionaireOnline-Windows.zip`** (recommended): unzip it, double-
  click `Install.bat` (it self-elevates for you), later `Uninstall.bat`
  to revert. Plain batch + PowerShell, no compiled binary — nothing for
  antivirus/Google Drive to flag.
- **`GazillionaireOnlineSetup.exe`**: same thing packaged as an NSIS
  installer with an auto-generated `Uninstall.exe`. Being an unsigned
  binary that requests admin, it's likely to get flagged as a false
  positive by Drive/Defender/SmartScreen — the `.bat` zip avoids that
  entirely, so prefer it unless you specifically want a "real" installer
  UI.

Both are wrappers around `tools/installer/install.ps1 install`/`restore`.

### From source (any platform)

1. Clone this repo.
2. Run `tools/fetch-sdk.sh` once to download the required build tools
   (currently macOS-only — building from Windows/Linux isn't wired up yet,
   but the *output* SWF is cross-platform, so build once on macOS and
   distribute it).
3. Run `tools/modloader/build.js` to build the base game (or with any mods
   enabled in `mods/`).
4. Run `tools/installer/install.sh` (macOS/Linux/Git Bash) or
   `tools/installer/install.ps1` (native Windows PowerShell) to patch your
   local Steam installation directly, **or** package it for a Windows
   tester who doesn't want to clone the repo:
   `tools/installer/windows/build-portable-zip.sh` (needs `zip`, no other
   deps — produces `GazillionaireOnline-Windows.zip`, recommended) or
   `tools/installer/windows/build-installer.sh` (needs `nsis`, e.g.
   `brew install nsis` — produces `GazillionaireOnlineSetup.exe`, more
   likely to trip antivirus false positives since it's an unsigned
   binary).
5. To play online: one player picks "Play Online" in-game, runs the relay
   (`node tools/multiplayer-server/relay.js`) somewhere everyone can reach,
   and shares the room code it prints. Everyone else picks "Play Online" →
   Join with that address and code.

See `docs/modding-guide.md` for how to write your own mods,
`docs/architecture.md` for how the engine is organized, and
`docs/multiplayer-architecture.md` for how the network layer works.

## Uninstalling

Run `tools/installer/install.sh restore` (or `install.ps1 restore` on
Windows) to revert to your original, unmodified game file.

## Contributing

Run `git config core.hooksPath .githooks` once after cloning to enable this
repo's pre-push checks (commit hygiene + secret scanning via `gitleaks`).
