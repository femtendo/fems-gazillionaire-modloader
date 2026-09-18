# Engine Architecture

## Overview

The game's logic lives entirely in `engine/src`, a source tree derived from
the shipped game and reorganized as our own maintained codebase. `tools/`
contains the build pipeline that turns `engine/src` plus any enabled mods
into a runnable patch, and the installer that applies it to a local Steam
install.

## Class Map

### Turn / Game-State Classes

These are the core state-machine classes that drive the turn-based economy.
All live in the decompiled source under `build/decompiled-raw/scripts/`.

| Class | File | Role |
|-------|------|------|
| `GameType` | `GameType.as` | Master game-state container. Holds turn counter, player/opponent arrays, commodity rates/prices/availability per planet, weather, news, auction state, stock-price trends, difficulty, level, and all `activate*` feature flags. Serializes/deserializes to `ByteArray` for local and online save/load. |
| `PlayerType` | `PlayerType.as` | Per-player state. Holds cash, cargo tons/capacity, commodity stock (`comS`) and purchase-price (`comPP`) per commodity slot, current planet, ship selection, crew, fuel, loan/zinn, warehouse arrays, share-price array, history, facility fees, bankruptcy flag, `turnTaken` flag, and all `quick*` shortcut booleans. |
| `OpponentType` | `OpponentType.as` | Per-opponent (non-player) state. Holds `netWorth`, planet, travel time, `turnTaken`, commodity tags, ship tons, cash, IQ, history, facility data, and share array. |
| `GameStrings` | `GameStrings.as` | Localization string table. All UI text is looked up by key via `getString(key)`. |

**Turn advancement is driven entirely by `frm_Travel3_load()` in `Gazillionaire.as` (line ~66994).** The method is the single end-of-turn / next-turn dispatcher:

1. Sets `g.isMidTurn = false` and increments `g.playerTurnCounter`.
2. If `playerTurnCounter >= playerNumberOf + opNumberOf` (all players + opponents have acted):
   - Resets `playerTurnCounter = -1`.
   - Increments `g.turn`.
   - Resets every player's and opponent's `turnTaken` flag.
   - Runs end-of-turn calculations in order:
     - `frm_Travel3_stockMarket()` — updates stock market prices
     - `frm_Travel3_newsEvent()` — generates new news event
     - `frm_Travel3_travel()` — processes ship travel
     - `frm_Travel3_auction()` — processes auctions
     - `frm_Travel3_economicChange()` — economic trend changes
     - `frm_Travel3_commodityAvailable()` — updates commodity availability
     - `frm_Travel3_commodityPrice()` — updates commodity prices
     - Randomizes `fuelCost` per planet
     - `frm_Travel3_gameEvents()` (turn > 4) — random game events
     - `frm_Travel3_opponentEvents()` (turn > 4) — opponent actions
     - Recalculates every player's and opponent's `netWorth`
     - `frm_Travel3_history()` — appends to history
     - `frm_Travel3_winCheck()` — checks win condition
   - Loads the next player's turn screen via `frm_Travel3_load()` (recursive call).
3. If not all turns complete: reads `g.playerOrder[playerTurnCounter]`, advances to that player/opponent's turn screen.

**Player turn flow** (within a single player's turn):
- `frm_PlayerTurn_load()` → shows current player's info, checks turn limit
- `frm_PlayerTurn_continue()` → called when player clicks "continue"
- `frm_PlayerTurn2_enter()` → enters the action phase
- `frm_PlayerTurn2_continue()` → after all actions, proceeds to ship selection
- `frm_ChooseShip_load()` / `frm_ChooseShip2_confirm_selection()` / `frm_ChooseShip3_continue()` → ship selection per player
- After last player: `g.player = 0`, shows `frm_PlayerTurn` for next turn, which eventually calls `frm_Travel3_load()`

**Key state fields on `GameType`:**
- `g.turn` — current turn number (1-based)
- `g.player` — index of current player (0-based)
- `g.playerNumberOf` — total player count
- `g.opNumberOf` — total opponent count (always 6)
- `g.playerOrder[]` — turn order array (player indices 0..5, opponent indices 6..11)
- `g.playerTurnCounter` — how many turns have been completed this round
- `g.isMidTurn` — whether a turn is in progress
- `g.winner` / `g.winningPoint` — win-tracking
- `g.comR[planet][cat][item]` — commodity rate (max available)
- `g.comP[planet][cat][item]` — commodity price per ton
- `g.comA[planet][cat][item]` — commodity available for sale
- `g.stockPrice[planet][turn]` — stock market price trend
- `g.stockTrend[planet]` — stock trend direction
- `g.stockCrash[planet]` — stock crash flag
- `g.activateTurn` through `g.activateStock` — tutorial/feature activation thresholds (1–17)

**Key state fields on `PlayerType`:**
- `g.p[i].cash` — player's cash/balance
- `g.p[i].cargoTons` / `cargoCapacity` — current and max cargo
- `g.p[i].comS[cat][item]` — commodity stock owned
- `g.p[i].comPP[cat][item]` — price-per-ton at time of purchase
- `g.p[i].planet` / `planetLast` — current and last planet
- `g.p[i].playerShip` — selected ship (1–12)
- `g.p[i].bankrupt` — bankruptcy flag
- `g.p[i].turnTaken` — whether this player has acted this round
- `g.p[i].warehouse[planet][cat][item]` — warehouse storage
- `g.p[i].share[planet]` — share price multiplier per planet
- `g.p[i].netWorth` — calculated net worth (cash + stock*share + savings − loan − zinnLoan)

### Market / Economy Classes

Commodity trading, cargo, ships, and auction logic are all methods inside `Gazillionaire.as` operating on `GameType` and `PlayerType` fields. There are no separate "Market" or "Cargo" classes — the decompilation inlined all UI logic into the main application class.

| Method (in `Gazillionaire.as`) | Line | Role |
|--------------------------------|------|------|
| `frm_Market_buy_sell(param1:int)` | ~54703 | Dispatches buy vs. sell based on whether player already possesses the commodity |
| `frm_Market_buy()` | ~54739 | Executes a buy: checks cash, cargo capacity, and availability; updates `comS`, `comPP`, `cargoTons`, `comA`, and calls `subtract_cash()` |
| `frm_Market_sell()` | ~54797 | Executes a sell: updates `cash`, `cargoTons`, `comA`, `comS`, `comPP`, and accumulates `sellingProfit` |
| `frm_ShipInfo_load()` | ~56199 | Loads ship info screen (size, fuel tank, crew, engine, passenger, cargo, fuel use) |
| `frm_ShipInfo_size()` / `_larger()` / `_fuel_tank()` / `_crew()` / `_engine()` / `_passenger()` / `_cargo()` / `_fuel_use()` | ~53994–54051 | Ship modification actions |
| `select_player_ship(param1:int, param2:int)` | ~50486 | Assigns ship specs to a player (sets passengerCapacity, crew, fuelCapacity, cargoCapacity, engine) |
| `frm_ChooseShip_load()` / `_choose_ship()` / `_confirm_selection()` / `_continue()` | ~50343–50701 | Ship selection UI flow |
| `frm_Travel1_move_ship(param1:TimerEvent)` | ~63036 | Processes ship movement between planets |
| `frm_Travel3_opponentBuySell(param1:int)` | ~67382 | Opponent buy/sell during their turn |
| `frm_Travel3_opponentBuysEngine(param1:int)` | ~67675 | Opponent engine upgrade |
| `frm_Travel3_opponentBuyShip(param1:int)` | ~67711 | Opponent ship purchase |
| `frm_Travel3_auctionShip()` | ~70073 | Auction ship selection |
| `frm_Stock_buy()` / `frm_Stock_sell()` | ~53750 / ~53793 | Stock market buy/sell |
| `frm_Travel3_stockMarket()` | (in Travel3) | End-of-turn stock market recalculation |
| `frm_Travel3_commodityAvailable()` | (in Travel3) | End-of-turn commodity availability update |
| `frm_Travel3_commodityPrice()` | (in Travel3) | End-of-turn commodity price update |
| `frm_Travel3_economicChange()` | (in Travel3) | End-of-turn economic trend change |
| `frm_Travel3_gameEvents()` | (in Travel3) | Random game events (turn > 4) |
| `frm_Travel3_opponentEvents()` | (in Travel3) | Opponent random events (turn > 4) |
| `frm_Travel3_winCheck()` | (in Travel3) | Win condition check — compares max player/opponent netWorth against `winningPoint` |
| `bankrupt_player(param1:int)` | ~48564 | Marks a player as bankrupt (sets netWorth to −10,000,000,000) |
| `subtract_cash(param1:int, param2:Number)` | (helper) | Decrements a player's cash by a given amount |

**Commodity model:** 7 planets × 3 categories × 6 items = 126 commodity slots. Each slot has a rate (max possible), a price-per-ton, and an available quantity. Players buy by reducing available quantity and increasing their stock; they sell by returning stock to the market and gaining cash proportional to (current price − purchase price) × tons.

**Ship model:** 12 ship types (indices 1–12), each with fixed specs for passenger capacity, crew, fuel capacity, cargo capacity, and engine class. Selected per-player via `select_player_ship()`.

**Warehouse model:** Per-player, per-planet storage: `warehouse[planet][category][item]` (tons stored), `warehouseGoodsValue[planet][category][item]` (value), `warehouseT[planet]` (total tons).

### Steam Bridge Usage

**Zero references found.** The decompiled source contains no usage of `FRESteamWorks`, `ExtensionContext`, or any Steam SDK classes. The search across all 156 `.as` files returned no matches for `FRESteam`, `Steam`, `Extension`, or `steamworks`.

The only external/network integration is a custom PHP server:
- `navigateToURL(new URLRequest("/makeSharedGame.php"), "_self")` — opens shared-game creation page
- `load_online_game()` / `frm_LoadGame_online_autosave()` — saves/loads game state via Base64-encoded `ByteArray` to a server endpoint using `username`/`password`/`game_id`/`game_turn` parameters
- Local save uses `SharedObject.getLocal("LavamindGazillionaireSaveData")` (buildLevel 2 only)

The Steam bridge footprint is **empty** in this decompilation — it was either never present in this version of the game, or was stripped before decompilation.

### Classes Needing Cleanup

These classes are present in the decompiled output but have obvious decompilation artifacts (garbled names, placeholder content, or are pure asset loaders with no logic):

| Class | File | Issue |
|-------|------|-------|
| All `Gazillionaire_Planet*Class` (12 planets) | `Gazillionaire_Planet*Bass1Class.as`, etc. | Pure `MovieClipLoaderAsset` wrappers for planet SWF assets. Names are obfuscated hash-suffixes. No logic. |
| All `Gazillionaire_Planet*_dataClass` (12 planets) | `Gazillionaire_Planet*Bass1Class_dataClass.as`, etc. | `ByteArrayAsset` subclasses. Empty constructors. No logic. |
| All `_class_embed_css_*` (~30 files) | `_class_embed_css_*.as` | CSS/theme asset loaders (`MovieClipLoaderAsset`, `BitmapAsset`, `SpriteAsset`, `ByteArrayAsset`). No logic. |
| All `Gazillionaire__embed_mxml_*` (~25 files) | `Gazillionaire__embed_mxml_*.as` | MXML-embedded asset loaders. No logic. |
| All `en_US$*_properties` (9 files) | `en_US$*_properties.as` | Flex `ResourceBundle` subclasses for localization. No logic. |
| `_Gazillionaire_Styles.as` | `_Gazillionaire_Styles.as` | 1274-line style registration file. Mostly `registerInheritingStyle()` calls. Not game logic. |
| `LoadScreen_LoadScreenGraphic.as` | `LoadScreen_LoadScreenGraphic.as` | `ByteArrayAsset` for loading screen graphic. No logic. |

The **only** files with actual game logic are:
- `Gazillionaire.as` (~106K lines, ~5.2 MB) — the main application class containing all UI frames and game logic
- `GameType.as` — game state data class
- `PlayerType.as` — player state data class
- `OpponentType.as` — opponent state data class
- `GameStrings.as` — localization strings
- `CustomPreloader.as` — preloader UI
- `LoadScreen.as` — loading screen
- `_Gazillionaire_FlexInit.as` — Flex framework initialization
- `GradientBarSkin.as`, `GradientTrackSkin.as`, `CustomComboBoxSkin.as` — custom UI skins

**Summary of class counts by category:**
- Turn/game-state classes: **4** (GameType, PlayerType, OpponentType, GameStrings)
- Market/economy logic: **~25 methods** in `Gazillionaire.as` (no separate classes)
- Steam bridge references: **0** files
- Asset/decompilation-only classes: **~60** files (planet loaders, CSS embeds, MXML embeds, resource bundles)
- Total `.as` files: **156**
- Files with actual game logic: **9**
