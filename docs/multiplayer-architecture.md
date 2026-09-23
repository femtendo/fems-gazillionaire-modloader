# Multiplayer Architecture

## Goal

Add networked play on top of the game's existing turn-based hotseat mode
(per `README.md`), so remote players (e.g. Steam friends) can play the same
game together instead of passing one machine around.

## What we're leveraging (already there, no reverse-engineering needed)

- `GameType.serialize()` / `GameType.deserialize()` (`engine/src/GameType.as:157,294`)
  already turn the entire game state into a `ByteArray` and back — this was
  built for local/online save-load, but it's exactly the payload a lockstep
  turn-sync network layer needs. We reuse it as-is.
- `frm_Travel3_load()` (`engine/src/Gazillionaire.as:67025`) is the **single**
  turn dispatcher (documented in `docs/architecture.md`). It's the only place
  that needs a network hook: after a turn completes, broadcast state; before
  a turn starts for a slot owned by a remote player, wait for their state
  instead of running local opponent AI.
- The game is already turn-based and strictly sequential (`playerOrder[]`),
  so there's no need for a lockstep/rollback netcode — a simple
  "authoritative relay" model works: one relay server holds the latest
  `GameType` blob and passes it to whichever client's turn is next.

## What we are explicitly NOT building

- **Real Steamworks API integration** (lobbies, rich presence, P2P
  networking via Steam's relay). That needs a Steamworks SDK + registered
  AppID + an ANE (`FRESteamWorks` or similar) built against this game's
  actual Steam AppID, none of which is available in this repo or to this
  agent. `docs/architecture.md` already confirms zero existing Steam bridge
  code. Building a fake one would be unverifiable and likely wrong.
- Instead: a **6-character room code**, produced by the relay server,
  that a player shares with friends however they like — Steam chat, Discord,
  voice. This is the same UX as most indie co-op games' "enter code to join"
  flow and needs no Steam API access. Upgrading to real Steam lobby
  invites later is a swap of the "how do players get the code to each
  other" step only — the relay/sync layer underneath doesn't change.
- Any dedicated hosting. The relay server is a small Node process either
  player can run locally (LAN) or on any box with a public port; no
  matchmaking backend, accounts, or persistence beyond one in-memory game.

## Components

### 1. Relay server — `tools/multiplayer-server/`

Plain Node.js `net` module, no dependencies (this repo has none today —
not adding any for a length-prefixed TCP relay). One process holds N rooms
in memory.

- One raw TCP socket per client, length-prefixed frames (4-byte
  big-endian length + UTF-8 JSON for control messages, or + raw bytes for
  the `GameType` blob, tagged by a 1-byte frame type).
- Room lifecycle: `create` → 6-char code → other clients `join <code>`.
- Server does **not** interpret game state. It just remembers "whose turn
  is it" (an integer slot index, mirrored from `g.playerTurnCounter`) and
  relays the latest state blob to whoever's slot is next. This keeps the
  server dumb and avoids re-implementing any game rules server-side.
- Message types: `hello`, `create`, `join`, `joined`, `peer-list`,
  `state` (binary GameType blob + `turn`/`slot` header), `chat`, `error`.

### 2. Client — `engine/src/NetworkClient.as`

- Wraps a `flash.net.Socket` (raw TCP, matching the relay's framing
  exactly). Kept intentionally tiny: connect, send length-prefixed frame,
  receive length-prefixed frame, done.
- Public surface the engine calls into:
  - `NetworkClient.isNetworked : Boolean`
  - `NetworkClient.mySlots : Vector.<int>` (which player index/indices this
    client controls — usually one)
  - `NetworkClient.connect(host, port, roomCode)`
  - `NetworkClient.publishTurn(state:ByteArray)`   — called once a turn ends
  - `NetworkClient.addEventListener(NetworkEvent.STATE_RECEIVED, ...)`
- No game logic lives here. It never touches `GameType` fields directly,
  only the serialized blob.

### 3. Engine hooks — two dispatchers, one pattern

There isn't just one sequential per-player dispatcher in this game —
there are two, and both needed the same host-authoritative guard:

- `frm_Travel3_load()` (`Gazillionaire.as:67025`) — the actual turn-based
  play loop, documented in `docs/architecture.md`.
- `frm_ChooseShip3_continue()` (`Gazillionaire.as:~50737`) — a separate,
  earlier per-player setup loop (ship selection + company naming) that
  runs once per player *before* `frm_Travel3_load()` ever fires. It has
  its own `g.player` increment and its own "show the next player's
  screen" logic, entirely independent of the travel dispatcher. Missing
  this one would mean guests could sync turns but never actually pick a
  ship — this was caught by tracing the real call graph, not guessed.

Both get the same two-sided guard:

- **Top-of-function guest guard**: if I'm networked and not the host,
  reaching this function means my own part (turn, or ship pick) just
  finished. Publish `g.serialize()` to the host and show a waiting
  screen instead of running the vanilla body.
- **Hand-off guard** at the point either dispatcher would show UI for
  the *next* player: if that slot belongs to a remote guest (not the
  host's own `mySlots`), publish state and wait instead of showing it
  locally.

A single `NetworkEvent.STATE_RECEIVED` handler
(`frm_Travel3_onNetworkStateReceived`) resumes whichever dispatcher is
relevant, using `g.playerTurnCounter == 0` as a free, already-existing
signal for "still in ship-selection/setup" (only `frm_Travel3_load()`
ever changes it away from its game-init value of 0, and that never runs
until setup is done) — no new wire-protocol field needed to tell the two
phases apart.

### 4. Lobby UI — where hosting/joining actually lives

Multiplayer games are only startable/joinable from `frm_HowManyPlayers`
("How Many Players?" — the screen where you already decide 1-6 human
participants before anything else is configured), not from a
global always-present button. `NetworkLobbyUI.attachTrigger()` is called
from `__frm_HowManyPlayers_show` and torn down in
`__frm_HowManyPlayers_hide`, so the "Play Online" corner button only
exists on that one screen.

- **Host**: click Play Online → Connect (blank room code) *before*
  picking a player count. Room code shows in the popup; host then closes
  it and clicks e.g. "Three Players" as normal — the entire rest of
  setup (opponents, planets, ship selection) runs exactly like hotseat,
  since the host is always slot 0 and plays every setup screen for their
  own slot locally. The hand-off guard only kicks in when setup reaches
  a slot that isn't the host's.
- **Join**: click Play Online → Join (host's address + room code + the
  slot number the host tells them out-of-band, e.g. over chat: "you're
  player 2"). On success the popup closes itself and jumps straight to
  a waiting screen — a guest never touches `frm_HowManyPlayers` or any
  local setup screen; the host's broadcasts drive everything.

This directly answers "why is a slot number needed at all instead of
auto-assignment": there's no matchmaking/allocation server, just a dumb
relay, so slot assignment is a manual (out-of-band) coordination step,
same spirit as the room code itself.

## Build integration

`NetworkClient.as` and the lobby screen class are dropped into
`engine/src/` like any other engine source file — `build.js` compiles the
whole `engine/src/` tree via `mxmlc`, so no build script changes are
needed beyond adding the files.

## Installers

The existing `tools/installer/install.sh` already patches a local Steam
install and works on macOS (verified: code-signing re-sign step) and,
being POSIX bash, can run on Windows under Git Bash. Because Windows users
without Git Bash shouldn't need to install one, we add a native
`tools/installer/install.ps1` with the same verify/backup/patch/restore
logic against the Windows Steam default path. Both scripts patch the same
cross-platform `gazillionaire-modded.swf` produced by `build.js` — AIR
content is not platform-specific, only the install target path and the
macOS code-signing step differ.

"Two playable installers" = `install.sh` (macOS/Linux/Git-Bash) and
`install.ps1` (native Windows), both driven off one build output.

Two ways to hand `install.ps1` to a Windows tester without them cloning
the repo, both built from macOS/Linux (no Windows machine needed):

- `tools/installer/windows/build-portable-zip.sh` — `Install.bat`/
  `Uninstall.bat` (self-elevating) plus `install.ps1` and its
  dependencies, zipped. No compiled binary, so nothing for antivirus to
  flag. **Recommended.**
- `tools/installer/windows/build-installer.sh` — the same thing wrapped
  as an NSIS `GazillionaireOnlineSetup.exe`/`Uninstall.exe`. In practice
  Google Drive flagged this as a virus on first use — expected for an
  unsigned binary that requests admin elevation (no code-signing
  certificate available to fix that properly); prefer the zip unless a
  "real" installer UI matters more than avoiding that false positive.

Like `install.ps1` itself, both have been compiled/logic-reviewed but not
run on a real Windows machine.

## Verification status

- Compiles clean against the full 106K-line engine.
- `tools/multiplayer-server/relay.js` has an automated test
  (`tests/multiplayer-server/relay.test.js`) covering framing and a full
  create/join/relay round trip between two plain TCP clients.
- Live-verified on the real local Steam install: launched the patched app,
  clicked Play Online → Connect, and got a real room code back from the
  relay over an actual `flash.net.Socket` — confirms the AS3
  `NetworkClient` ↔ relay wire protocol works, not just the Node-side test.
- **Not yet verified**: a second real client joining and a full turn
  handoff through `frm_Travel3_load()`. AIR enforces single-instance per
  app ID, so a genuine two-client test needs two separate machines/Steam
  accounts (or two installs with distinct app IDs), which weren't
  available while building this. This is the single biggest risk before
  calling multiplayer "done" — the turn-sync logic in
  `frm_Travel3_load()`/`frm_Travel3_onNetworkStateReceived()` is reasoned
  through carefully (see above) and compiles, but has not been watched
  actually run across two players.

## Not built: joining an already-running game as a rival faction

The current model requires a guest's slot to be pre-allocated by the
host at game-setup time (pick N players, guests claim slot 1..N-1 before
or during ship selection). Explicitly requested but not built: joining a
game that's *already past setup*, taking over one of the 6 AI-controlled
opponent companies (Gizzy Shipping, Trading Corp IV, etc.) mid-game.

This is a materially bigger task than anything else here, not just a
smaller version of the same pattern:

- `PlayerType` and `OpponentType` are different, non-interchangeable data
  models (`docs/architecture.md`). `OpponentType` tracks `netWorth`,
  `cash`, `IQ`, `commodityTags`, `shipTons` — a simplified AI abstraction,
  not the granular per-commodity ownership (`comS`/`comPP` per planet/
  category/item), warehouse, insurance, and loan state `PlayerType` has.
  All of the game's buy/sell/travel UI reads/writes `PlayerType` fields
  exclusively. An opponent literally doesn't have the state a human
  needs to play it through the existing screens.
- Making this work needs either (a) migrating a chosen opponent's data
  into a freshly-created `PlayerType` slot and redirecting that
  `playerOrder[]` index from `frm_Travel3_opponentTurn()` (AI) to
  `frm_PlayerTurn` (human UI) for the rest of the game, or (b) building
  full human-playable UI against `OpponentType`'s smaller field set
  directly. Either is real, untested engine surgery — not something to
  guess at blind in a 106K-line decompiled file with no way to run a
  live two-client session here.

If/when this is picked up: a "Join Running Game" button on
`frm_MainMenu` (the active in-game menu, not the title screen) is the
right entry point per the original request — it should list opponent
companies not already claimed by a human, let a guest pick one, and from
that point on treat that slot exactly like a normal networked player
slot for turn dispatch purposes.

## Failure modes / ponytail cuts

- No reconnect/resume-mid-turn handling yet — a dropped connection means
  restart the room. `# ponytail: no reconnect, add session resume if
  players report drops in practice.`
- No NAT traversal — relay must be reachable by all clients (LAN, or a
  public host/port-forward). `# ponytail: no hole-punching, add if
  players can't port-forward.`
- Server trusts whatever `GameType` blob the current-turn client sends
  (no anti-cheat validation). Fine for friends playing together;
  `# ponytail: no server-side validation, add if this ships beyond a
  friend group.`
