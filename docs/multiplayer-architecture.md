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

### 3. Engine hook — `frm_Travel3_load()`

At the top of `frm_Travel3_load()`:

```
if (NetworkClient.isNetworked) {
    var nextSlot:int = ...; // same index frm_Travel3_load already computes
    if (!NetworkClient.mySlots.indexOf(nextSlot) >= 0) {
        // not our turn: ask NetworkClient for the next state broadcast
        // instead of proceeding synchronously, then resume with the
        // received GameType.deserialize() applied to `g`.
        NetworkClient.awaitState(onRemoteStateReceived);
        return;
    }
}
```

And at the point a turn is fully committed (end of the existing
`turnTaken = true` assignment for a network-controlled slot), call
`NetworkClient.publishTurn(g.serialize())`.

This is the only touch point in the 106K-line file. Everything else (buy/
sell, ship selection, market) is unchanged — those all operate on local `g`
state during "my turn" exactly as in hotseat today.

### 4. Lobby UI

Minimal: one new screen reachable from the main menu — "Play Online" with
a text field (room code) and Create/Join buttons, wired the same way other
`frm_*` screens are. No new visual assets; reuses existing panel/button
skins.

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
