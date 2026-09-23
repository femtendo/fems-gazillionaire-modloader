# Multiplayer Architecture

## Goal

Add networked play on top of the game's existing turn-based hotseat mode
(per `README.md`), so remote players (e.g. Steam friends) can play the same
game together instead of passing one machine around.

## What we're leveraging (already there, no reverse-engineering needed)

- `GameType.serialize()` / `GameType.deserialize()` (`engine/src/GameType.as:157,294`)
  already turn the entire game state into a `ByteArray` and back — this was
  built for local/online save-load, but it's exactly the payload turn-sync
  needs. We reuse it as-is.
- The game is already turn-based and strictly sequential (`playerOrder[]`),
  so there's no need for a lockstep/rollback netcode — an "authoritative
  host" model works: the host's client holds the current `GameType` blob
  and sends it to whichever peer's turn is next.

## Peer-to-peer, not a relay — the host's own game is the server

Earlier revisions of this had players separately run a standalone Node.js
relay process before playing. Real user feedback ("the installer should
take care of all of that so a user doesn't have to, and it should only run
when the game is open") made clear that was the wrong shape: a step a
player has to remember to run, coordinate a port for, and separately debug
when something else on their machine squats that port (which is exactly
the bug that surfaced during real testing — see Verification status).

AIR desktop supports `flash.net.ServerSocket` for listening directly, so
the host's own game process **is** the server:

- No separate process to install, run, or keep track of.
- Exists only while the host's game is open — closing the game closes the
  listening socket, automatically satisfying "only run when the game is
  open."
- One fewer port for anything else on the host's machine to collide with,
  since it isn't a fixed well-known service running independently of the
  game.

The trade-off is the one every peer-to-peer game has: the host needs to be
reachable at the port they're listening on. LAN play works with no setup.
Over the internet, the host forwards that port on their router — same
requirement as any P2P game, not something a WebSocket-style relay would
have avoided for actually free (a public relay is a real server someone
has to run and pay for).

## What we are explicitly NOT building

- **Real Steamworks API integration** (lobbies, rich presence, P2P
  networking via Steam's relay). That needs a Steamworks SDK + registered
  AppID + an ANE (`FRESteamWorks` or similar) built against this game's
  actual Steam AppID, none of which is available in this repo or to this
  agent. `docs/architecture.md` already confirms zero existing Steam bridge
  code. Building a fake one would be unverifiable and likely wrong.
- Instead: the host shares their address and port with friends however
  they like — Steam chat, Discord, voice. Same UX as most indie co-op
  games' "enter the host's address" flow, no Steam API access needed.
  Upgrading to real Steam lobby invites later only changes how players get
  that address to each other — the sync layer underneath doesn't change.
- NAT traversal / hole-punching. See trade-off above.

## Components

### 1. Client/host — `engine/src/NetworkClient.as`

Both roles live in one class:

- **Host** (`hostGame(port, slot)`): binds a `flash.net.ServerSocket` and
  listens. Each incoming `ServerSocketConnectEvent.CONNECT` hands back an
  already-connected `Socket` for that guest. Guests announce which slot
  they're claiming in their first control message; the host tracks
  `slot -> Socket` in a `Dictionary`.
- **Guest** (`joinGame(hostAddress, port, slot)`): opens a plain
  `flash.net.Socket` straight to the host.
- Every open socket (the host's several guest connections, or the guest's
  single connection to the host) gets its own receive buffer in a
  `Dictionary`, since TCP framing must never mix bytes from two different
  connections.
- Wire format on every connection, matching what the length-prefixed
  framing always was: `[1 byte type][4 byte BE length][payload]`
  (`FRAME_JSON` for control messages, `FRAME_STATE` for a `GameType`
  blob).
- `publishTurn(state)` doesn't need the caller to know which role it's
  running as: the host broadcasts to every connected guest (each guest
  self-filters by checking `g.player` against its own `mySlots`, unchanged
  from before); a guest sends to its one connection, the host.
- Two timeouts protect against a real failure mode found by live testing:
  a **connect timeout** (nothing accepted the TCP connection at all) and a
  separate **handshake timeout** (TCP connected fine, but nothing
  Gazillionaire-shaped ever replied — e.g. an unrelated server already
  bound to that port answered instead). The first byte of every frame is
  also validated against the two known frame types; anything else closes
  the connection with an explicit "something else is listening on that
  address/port" error instead of hanging or silently discarding garbage.
- No game logic lives here. It never touches `GameType` fields directly,
  only the serialized blob.

### 2. Engine hooks — two dispatchers, one pattern

There isn't just one sequential per-player dispatcher in this game —
there are two, and both needed the same host-authoritative guard:

- `frm_Travel3_load()` (`Gazillionaire.as:~67045`) — the actual turn-based
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
  overlay instead of running the vanilla body.
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

The "waiting for other players" state is a standalone overlay
(`frm_Travel3_networkWait()`/`frm_Travel3_hideNetworkWait()`), not a
reused screen. It originally reused the `frm_Travel3` screen (swapping
its text), but that screen has a `show` event wired to
`__frm_Travel3_show()`, which unconditionally calls `frm_Travel3_load()`
— so simply *displaying* the wait screen re-entered real turn-dispatch
logic against a guest's not-yet-populated `GameType` and crashed inside
`GameType.serialize()` with a null reference. Caught by live two-client
testing, not by reading the code. A plain `Sprite` overlay added via
`rawChildren` never touches `mainCanvas.selectedChild`, so it can't
trigger any screen's `show` wiring.

### 3. Lobby UI — where hosting/joining actually lives

Multiplayer games are only startable/joinable from `frm_HowManyPlayers`
("How Many Players?" — the screen where you already decide 1-6 human
participants before anything else is configured), not from a
global always-present button. `NetworkLobbyUI.attachTrigger()` is called
from `__frm_HowManyPlayers_show` and torn down in
`__frm_HowManyPlayers_hide`, so the "Play Online" corner button only
exists on that one screen.

- **Host**: click Play Online → leave the address field blank → Connect.
  This starts listening immediately (before picking a player count); the
  popup shows the port to share. Host then closes it and clicks e.g.
  "Three Players" as normal — the entire rest of setup (opponents,
  planets, ship selection) runs exactly like hotseat, since the host is
  always slot 0 and plays every setup screen for their own slot locally.
  The hand-off guard only kicks in when setup reaches a slot that isn't
  the host's.
- **Join**: click Play Online → fill in the host's address, port, and the
  slot number the host tells them to use (out-of-band, e.g. over chat:
  "you're player 2") → Connect. On success the popup closes itself and
  jumps straight to the waiting overlay — a guest never touches
  `frm_HowManyPlayers` or any local setup screen; the host's broadcasts
  drive everything.

Slot assignment being a manual, out-of-band step (rather than
auto-assigned) is a direct consequence of there being no matchmaking
server in this design — the host just tells guests which number to type
in, the same spirit as sharing an address.

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

`install.ps1` prints its own version string as the first thing it does
(bump `$ScriptVersion` whenever the file changes), specifically to make a
stale-copy-vs-real-bug ambiguity in a bug report resolvable in one
round-trip instead of another guess.

## Verification status

Everything below was verified live, not just by reading the code —
including two real bugs that static review alone did not catch:

- Compiles clean against the full 106K-line engine.
- **Full two-client session, run on one Mac** using two independent AIR
  processes (the installed app as host, a second instance launched via
  `adl` with a distinct application id so AIR's single-instance lock
  doesn't collide with the first): host started listening
  (`ServerSocket.bind`/`listen` succeeded), guest connected directly over
  TCP with no intermediary, both completed ship selection with the
  hand-off guard correctly routing each player's own screen to their own
  client, the host received the guest's finished state and correctly
  resumed with *both* players' data merged into one `GameType` (confirmed
  on the Week 1 leaderboard screen, which listed both companies), and the
  host's own turn began normally afterward. No crashes anywhere in that
  path.
- **Real Windows tester, real bug found and fixed live**: an unrelated
  local server (not part of this project) happened to already be bound to
  `127.0.0.1:8642` specifically. Because that bind was more specific than
  the (now-removed) relay's wildcard bind, every connection attempt
  silently landed on the wrong server, which replied with an HTTP error
  instead of anything Gazillionaire-shaped. The original connect-timeout
  never fired, because the TCP connect itself had genuinely succeeded —
  it just wasn't talking to a peer that spoke this protocol. This directly
  motivated both the handshake timeout and the frame-type validation
  described above, *and* was part of what motivated dropping the
  standalone relay in favor of peer-to-peer (the host no longer needs to
  agree on a well-known port with anything else running on their
  machine).
- **Not yet verified**: a real two-machine session over an actual network
  (LAN or internet) — everything above was same-machine loopback. The
  protocol and hand-off logic don't care whether the socket happens to be
  loopback or not, but router port-forwarding for the "over the internet"
  case specifically remains unverified in practice.

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
  guess at blind in a 106K-line decompiled file.

If/when this is picked up: a "Join Running Game" button on
`frm_MainMenu` (the active in-game menu, not the title screen) is the
right entry point per the original request — it should list opponent
companies not already claimed by a human, let a guest pick one, and from
that point on treat that slot exactly like a normal networked player
slot for turn dispatch purposes.

## Failure modes / ponytail cuts

- No reconnect/resume-mid-turn handling yet — a dropped connection means
  restart the game. `# ponytail: no reconnect, add session resume if
  players report drops in practice.`
- No NAT traversal — the host must be reachable by every guest (LAN, or
  the host's router with the chosen port forwarded).
  `# ponytail: no hole-punching, add if players can't port-forward.`
- Host trusts whatever `GameType` blob the current-turn guest sends (no
  anti-cheat validation). Fine for friends playing together;
  `# ponytail: no server-side validation, add if this ships beyond a
  friend group.`
