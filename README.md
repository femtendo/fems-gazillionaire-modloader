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
- An online multiplayer layer that adds Steam friend invites and networked
  play on top of the game's existing turn-based hotseat mode.

## Requirements

- A legitimate Steam copy of Gazillionaire (macOS or Windows).
- Java (for the build tooling).

## Installation

1. Clone this repo.
2. Run `tools/fetch-sdk.sh` once to download the required build tools.
3. Run `tools/modloader/build.js` to build the base game (or with any mods
   enabled in `mods/`).
4. Run `tools/installer/install.sh` to patch your local Steam installation.

See `docs/modding-guide.md` for how to write your own mods, and
`docs/architecture.md` for how the engine is organized.

## Uninstalling

Run `tools/installer/install.sh restore` to revert to your original,
unmodified game file.

## Contributing

Run `git config core.hooksPath .githooks` once after cloning to enable this
repo's pre-push checks (commit hygiene + secret scanning via `gitleaks`).
