# Loose MP3 Catalog (`Resources/MP3/`)

175 loose `.mp3` files under `Resources/MP3/` — sound effects, voice stings, and per-planet/per-commodity
jingles referenced from `engine/src/Gazillionaire.as`. Confirmed count via `ls -la`: **175 files**
(matches the earlier estimate exactly).

## Summary

| Category | Count |
|---|---|
| UI sounds | 6 |
| Gameplay SFX (buy/sell/travel/event) | 134 |
| Voice / character lines | 8 |
| Ambient (per-planet arrival) | 14 |
| Other | 3 |
| Orphaned (no reference found) | 10 |
| **Total** | **175** |

## Dynamic path construction

Two families of sounds are built at runtime by string concatenation rather than referenced as string literals,
mirroring the ship/planet dynamic patterns found in the SWF and PNG passes:

- **`"MP3/SHIP" + playerShip + ".MP3"`** (and `"MP3/SHIP" + (playerShip - 6) + ".MP3"` for the second ship-model tier,
  since `playerShip` ranges 0-11 across 6 ship files) — the ship engine/model cue for whichever ship a player owns.
  Triggered from `frm_ChooseShip_choose_ship`, `frm_PlayerTurn_load`, `frm_WinGame3_load`, `frm_Travel4_AuctionShip`,
  `frm_Travel4_AuctionFacility`, `frm_Travel4_humanArrivesOnPlanet`, `frm_ShipInfo_load`, `frm_Bankrupt1_load`, `frm_Travel2_ok`.
- **`"MP3/OP" + opponentIndex + ".MP3"`** — a per-AI-opponent-slot (1-6) cue, played whenever an opponent (not the human
  player) wins, auctions, arrives on a planet, buys an engine/ship, or triggers a travel event. Triggered from
  `frm_WinGame3_load`, `frm_Travel4_AuctionShip`/`AuctionFacility`, `frm_Travel4_opponentArrivesOnPlanet`, `frm_Travel2_ok`,
  `frm_Travel3_opponentBuysEngine`, `frm_Travel3_opponentBuyShip`, `frm_Travel3_opponentEvents`.

Additionally, two internal helper functions return sound paths as **literal strings selected by an index**, so the
individual filenames appear as string literals in the source (not concatenation) but are only ever reached through
the helper, not directly at a `frm_*` call site:

- `planet_sound(planetIndex:int)` (14 planets, `VEXX`..`NOSH`, default `NEUTRAL2`) — called from `frm_Travel6_load`,
  `frm_Special_load`, and `frm_Explore_load` to play a planet-specific arrival ambience.
- `commodity_sound(category:int, itemIndex:int)` (18 commodities across 3 categories) — called from `frm_Market_buy`,
  `frm_Market_sell`, `frm_Warehouse_take`, `frm_Warehouse_store` to play a jingle for whichever specific good was
  bought/sold/stored.

## UI sounds (6)

| Filename | Size | Category | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|
| CLOCK.MP3 | 4201 B | sfx-ui | frm_Time_load; frm_Time_next; frm_Time_prev |  |
| HELP.MP3 | 3155 B | sfx-ui | frm_Graph_help; frm_MainMenu_help; frm_Stock_help; frm_Money_help; frm_ShipInfo_help; frm_Bank_help; frm_Loan_help; frm_ZinnLoan_help; frm_Market_help; frm_Supply_help; frm_Warehouse_help; frm_Passengers_help; frm_Advertising_help; frm_Employee_help; frm_Tax_help; frm_Insurance_help; frm_Explore_help; frm_Special_help; frm_News_help; frm_Weather_help; frm_History_help; frm_Time_help; frm_Quick_help; frm_Fuel_help; frm_LeavePlanet_help; frm_DistanceChart_help; frm_Travel2_goodEvent |  |
| HISTORY.MP3 | 3471 B | sfx-ui | frm_History_load; frm_History_next; frm_History_prev |  |
| PING1.MP3 | 4305 B | sfx-ui | frm_Level_load; frm_HowManyPlayers_load; frm_Planets_load; frm_Planets_select_planet; frm_Opponents_load; frm_DistanceChart_choose_planet |  |
| PING3.MP3 | 6604 B | sfx-ui | frm_ChooseShip_load |  |
| TICKET.MP3 | 3679 B | sfx-ui | frm_Passengers |  |

## Gameplay SFX (buy/sell/travel/event) (134)

| Filename | Size | Category | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|
| ADVERT.MP3 | 3888 B | sfx-gameplay | frm_MainMenu_ad; frm_Advertising_place_ad |  |
| AUCTION.MP3 | 9218 B | sfx-gameplay | frm_PlayerTurn2_AuctionShip (x2); frm_PlayerTurn2_AuctionFacility (x2) |  |
| AUCTION2.MP3 | 6294 B | sfx-gameplay | frm_Auction_load (x2) |  |
| BABEL.MP3 | 3992 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| BAD.MP3 | 10155 B | sfx-gameplay | frm_Special_action (x19); frm_Travel2_yes |  |
| BAD2.MP3 | 8902 B | sfx-gameplay | frm_Travel2_yes |  |
| BAD3.MP3 | 4722 B | sfx-gameplay | frm_Travel2_badEvent; frm_Travel2_crewStrikes; frm_Travel2_fuelRunsOut |  |
| BAD4.MP3 | 3155 B | sfx-gameplay | frm_Travel4_showSabotageResult; frm_Travel2_badEvent; frm_Travel2_fuelRunsOut_part_2 |  |
| BAD5.MP3 | 4200 B | sfx-gameplay | frm_Travel2_badEvent (x3); frm_Travel2_yes |  |
| BAD6.MP3 | 5558 B | sfx-gameplay | frm_Travel2_badEvent (x2) |  |
| BAD7.MP3 | 9424 B | sfx-gameplay | frm_Special_action (x8); frm_Stock |  |
| BADDEAL.MP3 | 4934 B | sfx-gameplay | frm_Market; frm_Market_sell |  |
| BANDITS.MP3 | 10681 B | sfx-gameplay | frm_Travel2_badEvent |  |
| BANK.MP3 | 3886 B | sfx-gameplay | frm_Bank; frm_MainMenu_bank; frm_Bank_deposit_max |  |
| BANK2.MP3 | 3695 B | sfx-gameplay | frm_Bank; frm_MainMenu_bank; frm_Bank_withdraw_max |  |
| BANK3.MP3 | 6923 B | sfx-gameplay | frm_Bank_load |  |
| BANKRUPT.MP3 | 36700 B | sfx-gameplay | frm_Bankrupt2_load |  |
| BLESSING.MP3 | 4413 B | sfx-gameplay | frm_Special_action (x10); frm_Travel2_yes; frm_Travel2_playerEvents |  |
| BOBBLE.MP3 | 5456 B | sfx-gameplay | frm_Travel2_badEvent |  |
| BOLLUP.MP3 | 5560 B | sfx-gameplay | frm_Travel2_badEvent |  |
| CANTALOU.MP3 | 3159 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| CORNU.MP3 | 15172 B | sfx-gameplay | frm_Special_action |  |
| CREW.MP3 | 7126 B | sfx-gameplay | frm_Special_action (x13); frm_MainMenu_crew; frm_Employee_pay |  |
| CYLET.MP3 | 6918 B | sfx-gameplay | frm_Travel2_badEvent |  |
| DARLEEN.MP3 | 3680 B | sfx-gameplay | frm_Travel2_badEvent |  |
| DEXXYGAS.MP3 | 9637 B | sfx-gameplay | frm_Travel2_badEvent |  |
| DIAPERS.MP3 | 3994 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| ENGINE.MP3 | 5665 B | sfx-gameplay | frm_Special_action |  |
| EVENT.MP3 | 5559 B | sfx-gameplay | frm_Travel4_gameEvents (x8) |  |
| EXOTIC.MP3 | 4515 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| FEZFAFA.MP3 | 5457 B | sfx-gameplay | frm_Travel2_badEvent |  |
| FIRE.MP3 | 18306 B | sfx-gameplay | frm_Travel2_badEvent |  |
| FROGLEG.MP3 | 3262 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| FUEL.MP3 | 3886 B | sfx-gameplay | frm_Special_action (x2); frm_Fuel; frm_MainMenu_fuel |  |
| GAMBLE.MP3 | 14128 B | sfx-gameplay | frm_Special (x2); frm_Stock |  |
| GEMS.MP3 | 4618 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| GOOD.MP3 | 6499 B | sfx-gameplay | frm_Special_action (x25); frm_Travel5_revenueFacilities |  |
| GOOD2.MP3 | 6500 B | sfx-gameplay | frm_Travel2_goodEvent (x3); frm_Travel2_yes |  |
| GOOD3.MP3 | 5455 B | sfx-gameplay | frm_Travel2_goodEvent (x4) |  |
| GOOD4.MP3 | 8589 B | sfx-gameplay | frm_Travel2_yes |  |
| GOOD5.MP3 | 5135 B | sfx-gameplay | frm_Travel2_goodEvent (x3); frm_Travel2_yes |  |
| GOODDEAL.MP3 | 5040 B | sfx-gameplay | frm_Market; frm_Market_sell |  |
| GURTTLE.MP3 | 19772 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| HANDS.MP3 | 4514 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| HAPA.MP3 | 4618 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| HUNGO.MP3 | 5037 B | sfx-gameplay | frm_Travel2_badEvent |  |
| INSURE.MP3 | 4933 B | sfx-gameplay | frm_Special_action (x14); frm_MainMenu_insure; frm_Insurance_buy |  |
| ISO.MP3 | 28231 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| JELLYBEA.MP3 | 2845 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| KRYPTOON.MP3 | 5144 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| LAVALAMP.MP3 | 4831 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| LEAHY.MP3 | 4932 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| LEAK.MP3 | 19873 B | sfx-gameplay | frm_Travel2_badEvent |  |
| LIMPUS.MP3 | 3575 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| LIPPO.MP3 | 3887 B | sfx-gameplay | frm_Travel2_badEvent |  |
| LOAN.MP3 | 3782 B | sfx-gameplay | frm_Special_action (x14); frm_Loan (x3); frm_MainMenu_loan (x2); frm_Travel5_payFacilities; frm_Loan_load; frm_Loan_repay_max; frm_Loan_borrow_max; frm_LeavePlanet_select_planet |  |
| LORD.MP3 | 8902 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| MECH.MP3 | 4409 B | sfx-gameplay | frm_Special_action; frm_Travel2_goodEvent |  |
| MEEG.MP3 | 9111 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| METEOR.MP3 | 21547 B | sfx-gameplay | frm_Travel2_badEvent (x2) |  |
| MIPPI.MP3 | 3783 B | sfx-gameplay | frm_Travel2_badEvent |  |
| MONK.MP3 | 7857 B | sfx-gameplay | frm_Special_action (x12) |  |
| MOOGLER.MP3 | 3680 B | sfx-gameplay | frm_Travel2_badEvent |  |
| MOONFERN.MP3 | 2845 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| MULLS.MP3 | 16635 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| NEBBIT.MP3 | 7232 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| NECTUM.MP3 | 11516 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| NEUTRAL.MP3 | 5039 B | sfx-gameplay | frm_Special_action (x8); frm_Stock |  |
| NEUTRAL2.MP3 | 3159 B | sfx-gameplay | frm_Special (x3); frm_HowManyPlayers_setNumPlayers |  |
| NEUTRAL3.MP3 | 4308 B | sfx-gameplay | frm_Special_action |  |
| NEWS.MP3 | 17888 B | sfx-gameplay | frm_WinGame2_load; frm_News_load |  |
| NIBBLE.MP3 | 6814 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| NIBBLE2.MP3 | 4725 B | sfx-gameplay | frm_Travel2_yes |  |
| OGGLE.MP3 | 3678 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| OP1.MP3 | 16320 B | sfx-gameplay | dynamic: "MP3/OP" + opponentIndex + ".MP3" (frm_WinGame3_load, frm_Travel4_AuctionShip/Facility, frm_Travel4_opponentArrivesOnPlanet, frm_Travel2_ok, frm_Travel3_opponentBuysEngine, frm_Travel3_opponentBuyShip, frm_Travel3_opponentEvents) | Per-opponent-slot cue (1-6) played whenever an AI opponent (not the human player) wins, auctions, arrives, buys an engine/ship, or triggers a travel event. |
| OP2.MP3 | 20395 B | sfx-gameplay | dynamic: "MP3/OP" + opponentIndex + ".MP3" (frm_WinGame3_load, frm_Travel4_AuctionShip/Facility, frm_Travel4_opponentArrivesOnPlanet, frm_Travel2_ok, frm_Travel3_opponentBuysEngine, frm_Travel3_opponentBuyShip, frm_Travel3_opponentEvents) | Per-opponent-slot cue (1-6) played whenever an AI opponent (not the human player) wins, auctions, arrives, buys an engine/ship, or triggers a travel event. |
| OP3.MP3 | 19036 B | sfx-gameplay | dynamic: "MP3/OP" + opponentIndex + ".MP3" (frm_WinGame3_load, frm_Travel4_AuctionShip/Facility, frm_Travel4_opponentArrivesOnPlanet, frm_Travel2_ok, frm_Travel3_opponentBuysEngine, frm_Travel3_opponentBuyShip, frm_Travel3_opponentEvents) | Per-opponent-slot cue (1-6) played whenever an AI opponent (not the human player) wins, auctions, arrives, buys an engine/ship, or triggers a travel event. |
| OP4.MP3 | 15693 B | sfx-gameplay | dynamic: "MP3/OP" + opponentIndex + ".MP3" (frm_WinGame3_load, frm_Travel4_AuctionShip/Facility, frm_Travel4_opponentArrivesOnPlanet, frm_Travel2_ok, frm_Travel3_opponentBuysEngine, frm_Travel3_opponentBuyShip, frm_Travel3_opponentEvents) | Per-opponent-slot cue (1-6) played whenever an AI opponent (not the human player) wins, auctions, arrives, buys an engine/ship, or triggers a travel event. |
| OP5.MP3 | 33456 B | sfx-gameplay | dynamic: "MP3/OP" + opponentIndex + ".MP3" (frm_WinGame3_load, frm_Travel4_AuctionShip/Facility, frm_Travel4_opponentArrivesOnPlanet, frm_Travel2_ok, frm_Travel3_opponentBuysEngine, frm_Travel3_opponentBuyShip, frm_Travel3_opponentEvents) | Per-opponent-slot cue (1-6) played whenever an AI opponent (not the human player) wins, auctions, arrives, buys an engine/ship, or triggers a travel event. |
| OP6.MP3 | 45995 B | sfx-gameplay | dynamic: "MP3/OP" + opponentIndex + ".MP3" (frm_WinGame3_load, frm_Travel4_AuctionShip/Facility, frm_Travel4_opponentArrivesOnPlanet, frm_Travel2_ok, frm_Travel3_opponentBuysEngine, frm_Travel3_opponentBuyShip, frm_Travel3_opponentEvents) | Per-opponent-slot cue (1-6) played whenever an AI opponent (not the human player) wins, auctions, arrives, buys an engine/ship, or triggers a travel event. |
| OXYGEN.MP3 | 3575 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| PICKUP.MP3 | 2634 B | sfx-gameplay | frm_MainMenu_passengers; frm_Passengers_pick_up |  |
| PILOT.MP3 | 5977 B | sfx-gameplay | frm_Travel2_badEvent (x2); frm_Travel2_yes; frm_Travel2_goodEvent |  |
| PIRATES.MP3 | 8069 B | sfx-gameplay | frm_Travel2_badEvent |  |
| POLICE.MP3 | 17576 B | sfx-gameplay | frm_Travel2_yes (x5) |  |
| POLYESTR.MP3 | 4099 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| QUIST.MP3 | 5350 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| REBELS.MP3 | 4202 B | sfx-gameplay | frm_Travel2_badEvent |  |
| REPAIR.MP3 | 11098 B | sfx-gameplay | frm_Travel2_badEvent |  |
| RJ.MP3 | 8064 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| ROCKET1.MP3 | 27817 B | sfx-gameplay | frm_Travel1_load | Travel launch sequence stinger (one of 6 variants, frm_Travel1_load). |
| ROCKET2.MP3 | 16637 B | sfx-gameplay | frm_Travel1_load | Travel launch sequence stinger (one of 6 variants, frm_Travel1_load). |
| ROCKET3.MP3 | 21130 B | sfx-gameplay | frm_Travel1_load | Travel launch sequence stinger (one of 6 variants, frm_Travel1_load). |
| ROCKET4.MP3 | 14443 B | sfx-gameplay | frm_Travel1_load | Travel launch sequence stinger (one of 6 variants, frm_Travel1_load). |
| ROCKET5.MP3 | 13607 B | sfx-gameplay | frm_Travel1_load | Travel launch sequence stinger (one of 6 variants, frm_Travel1_load). |
| ROCKET6.MP3 | 20294 B | sfx-gameplay | frm_Travel1_load | Travel launch sequence stinger (one of 6 variants, frm_Travel1_load). |
| SABOTAGE.MP3 | 5667 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| SCOOTER.MP3 | 7546 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| SHIMMER.MP3 | 5561 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| SHIMMER2.MP3 | 6398 B | sfx-gameplay | frm_Travel2_yes |  |
| SHIP1.MP3 | 24994 B | sfx-gameplay | dynamic: "MP3/SHIP" + playerShip + ".MP3" (playerShip 0-5 -> SHIP1-6, 6-11 -> SHIP(n-6) i.e. SHIP1-6 again for second ship-model tier) | Ship engine/model cue played on ship selection, turn start, win screen, ship auction, arrival, ship-info screen, and bankruptcy screen; index derived from this.g.p[x].playerShip. |
| SHIP2.MP3 | 29592 B | sfx-gameplay | dynamic: "MP3/SHIP" + playerShip + ".MP3" (playerShip 0-5 -> SHIP1-6, 6-11 -> SHIP(n-6) i.e. SHIP1-6 again for second ship-model tier) | Ship engine/model cue played on ship selection, turn start, win screen, ship auction, arrival, ship-info screen, and bankruptcy screen; index derived from this.g.p[x].playerShip. |
| SHIP3.MP3 | 27398 B | sfx-gameplay | dynamic: "MP3/SHIP" + playerShip + ".MP3" (playerShip 0-5 -> SHIP1-6, 6-11 -> SHIP(n-6) i.e. SHIP1-6 again for second ship-model tier) | Ship engine/model cue played on ship selection, turn start, win screen, ship auction, arrival, ship-info screen, and bankruptcy screen; index derived from this.g.p[x].playerShip. |
| SHIP4.MP3 | 30219 B | sfx-gameplay | dynamic: "MP3/SHIP" + playerShip + ".MP3" (playerShip 0-5 -> SHIP1-6, 6-11 -> SHIP(n-6) i.e. SHIP1-6 again for second ship-model tier) | Ship engine/model cue played on ship selection, turn start, win screen, ship auction, arrival, ship-info screen, and bankruptcy screen; index derived from this.g.p[x].playerShip. |
| SHIP5.MP3 | 28129 B | sfx-gameplay | dynamic: "MP3/SHIP" + playerShip + ".MP3" (playerShip 0-5 -> SHIP1-6, 6-11 -> SHIP(n-6) i.e. SHIP1-6 again for second ship-model tier) | Ship engine/model cue played on ship selection, turn start, win screen, ship auction, arrival, ship-info screen, and bankruptcy screen; index derived from this.g.p[x].playerShip. |
| SHIP6.MP3 | 27293 B | sfx-gameplay | dynamic: "MP3/SHIP" + playerShip + ".MP3" (playerShip 0-5 -> SHIP1-6, 6-11 -> SHIP(n-6) i.e. SHIP1-6 again for second ship-model tier) | Ship engine/model cue played on ship selection, turn start, win screen, ship auction, arrival, ship-info screen, and bankruptcy screen; index derived from this.g.p[x].playerShip. |
| SNOZ.MP3 | 18201 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| SOOTH.MP3 | 24890 B | sfx-gameplay | frm_Special_action |  |
| SPEEVAK.MP3 | 21130 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| SPIKE.MP3 | 26875 B | sfx-gameplay | frm_Travel2_yes; frm_Travel2_goodEvent |  |
| SQUOWK.MP3 | 5978 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| STOCK.MP3 | 49967 B | sfx-gameplay | frm_Stock_load |  |
| STOCK2.MP3 | 8277 B | sfx-gameplay | frm_Special_action |  |
| STOKCRSH.MP3 | 23848 B | sfx-gameplay | frm_PlayerTurn2_stockCrash; frm_PlayerTurn2_stockFall; frm_Stock_load |  |
| STORM.MP3 | 10157 B | sfx-gameplay | frm_Travel2_badEvent (x3) |  |
| STUBBS.MP3 | 7545 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| TATILUS.MP3 | 5143 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| TAX.MP3 | 5975 B | sfx-gameplay | frm_Travel4_gameEvents (x3); frm_Tax_load; frm_Travel2_no; frm_Travel2_taxAudit |  |
| TAX2.MP3 | 3468 B | sfx-gameplay | frm_Travel4_gameEvents (x3); frm_MainMenu_tax; frm_Tax_pay |  |
| TEAL.MP3 | 9424 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| TEETER.MP3 | 5247 B | sfx-gameplay | frm_Special_action; frm_Travel2_goodEvent |  |
| TEETER2.MP3 | 12457 B | sfx-gameplay | frm_Travel2_yes |  |
| THANKYOU.MP3 | 3681 B | sfx-gameplay | frm_Special (x2) |  |
| TOASTERS.MP3 | 3890 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| TONIC.MP3 | 4201 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| UMBRELLA.MP3 | 3890 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| VAPOR.MP3 | 6813 B | sfx-gameplay | frm_Travel2_badEvent |  |
| WEATHER.MP3 | 13084 B | sfx-gameplay | frm_Weather_load |  |
| WHIPCREM.MP3 | 3159 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| WHIRL.MP3 | 7335 B | sfx-gameplay | frm_Travel2_badEvent |  |
| WICKY.MP3 | 12560 B | sfx-gameplay | frm_Travel2_badEvent |  |
| WOBBLER.MP3 | 4203 B | sfx-gameplay | frm_Travel2_goodEvent |  |
| XFUEL.MP3 | 4410 B | sfx-gameplay | commodity_sound() called from: frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal commodity_sound(category,itemIndex) helper (18 commodities across 3 categories); not referenced directly at any frm_* site. |
| YOYO.MP3 | 3886 B | sfx-gameplay | frm_Travel2_yes; frm_Travel2_goodEvent |  |

## Voice / character lines (8)

| Filename | Size | Category | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|
| AGENT.MP3 | 9739 B | voice | frm_Special_action (x14) |  |
| AGENT2.MP3 | 4128 B | voice | frm_Special_action (x8) |  |
| ASIAN.MP3 | 4305 B | voice | frm_Special_action (x6) |  |
| ASIAN2.MP3 | 9008 B | voice | frm_Special_action (x16) |  |
| CURTIS.MP3 | 5560 B | voice | frm_Travel2_yes; frm_Travel2_goodEvent |  |
| DRED.MP3 | 20605 B | voice | frm_Travel2_goodEvent (x2); frm_Travel2_yes; frm_Travel2_badEvent |  |
| IMPERIAL.MP3 | 12041 B | voice | frm_Special_action (x8) |  |
| ZINN.MP3 | 4200 B | voice | frm_Special_action (x16); frm_Travel2_goodEvent (x3); frm_ZinnLoan (x2); frm_Travel2_badEvent (x2); frm_ChooseShip2_confirm_selection; frm_ZinnLoan_load; frm_ZinnLoan_repay_max; frm_LeavePlanet_select_planet |  |

## Ambient (per-planet arrival) (14)

| Filename | Size | Category | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|
| BASS.MP3 | 61669 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| FRAC.MP3 | 21859 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| HORK.MP3 | 50280 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| LORO.MP3 | 19873 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| MIRA.MP3 | 18410 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| NOSH.MP3 | 48503 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| OOOM.MP3 | 47041 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| PYKE.MP3 | 30218 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| QUEG.MP3 | 46936 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| STYE.MP3 | 34502 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| TILO.MP3 | 67207 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| VEXX.MP3 | 27188 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| XEEN.MP3 | 43488 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |
| ZILE.MP3 | 55191 B | ambient | planet_sound() called from: frm_Travel6_load, frm_Special_load, frm_Explore_load, frm_Market_buy, frm_Market_sell, frm_Warehouse_take, frm_Warehouse_store | Returned as a literal string by the internal planet_sound(planetIndex) helper (index selects one of 14 planets, default NEUTRAL2); not referenced directly at any frm_* site. |

## Other (3)

| Filename | Size | Category | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|
| MORECOMPLEX.MP3 | 8172 B | other | frm_Tutorial_button_more_click | Tutorial 'more info' button click. |
| PROFITANIA.MP3 | 45892 B | other | frm_LavaMind_4_show | Loading-tip splash screen (frm_LavaMind_4). |
| ZAPITALISM.MP3 | 49656 B | other | frm_LavaMind_3_show | Loading-tip splash screen (frm_LavaMind_3). |

## Orphaned files (no reference found)

These 10 files have no string-literal reference and don't fit any known dynamic-construction pattern
(`SHIP`+n, `OP`+n, or the `planet_sound`/`commodity_sound` index tables) anywhere in `Gazillionaire.as`:

| Filename | Size | Notes |
|---|---|---|
| BEGIN.MP3 | 14441 B | No reference found; name suggests a game-start/intro cue. |
| CATACOM3.MP3 | 23116 B | No reference found; likely leftover/unused asset (name doesn't match any known naming convention in the code). |
| COINS.MP3 | 7127 B | No reference found; name suggests a cash/transaction cue, but no call site located. |
| EMAIL.MP3 | 14650 B | No reference found; possibly an unused notification sound. |
| LAVAMIND.MP3 | 15489 B | No reference found as an MP3, but 'LavaMind' is a real splash-screen family in code (frm_LavaMind_2/3/4 each play OOOM/ZAPITALISM/PROFITANIA respectively) and LAVAMIND_S.SWF exists in the external SWF catalog — this specific MP3 looks like a leftover/unused variant. |
| MENTAL.MP3 | 25309 B | No reference found; no matching frm_ or persona name in the code. |
| PING2.MP3 | 3051 B | No reference found; PING1 and PING3 are both used (UI ping/tick sound) but PING2 is skipped in every call site inspected. |
| PING4.MP3 | 5559 B | No reference found; same series as PING1/PING3, unused variant. |
| SPIKE2.MP3 | 10053 B | No reference found; SPIKE.MP3 is used in frm_Travel2_yes/goodEvent, but SPIKE2 has no call site. |
| ZAP.MP3 | 49652 B | No reference found; distinct from ZAPITALISM.MP3 (which is used, splash screen). ZAP alone is unused. |

