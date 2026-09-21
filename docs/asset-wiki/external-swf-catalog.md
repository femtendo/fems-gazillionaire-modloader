# External SWF Asset Catalog

Companion catalog to `docs/asset-inventory.md` (which covers the 156 `.as` classes /
98 rows embedded directly in the compiled `Gazillionaire.swf`). This document covers
the **156 standalone `.swf` files** at
`Gazillionaire.app/Contents/Resources/SWF/`, loaded at runtime by relative path from
`mx.controls.Image` descriptors (literal `"source":"./SWF/NAME.SWF"`) or built
dynamically at runtime (`"SWF/" + baseName + suffix + ".SWF"`) inside
`engine/src/Gazillionaire.as`.

## Completeness sweep

**What was checked:**

1. **Full `Resources/` tree walked** (not just `SWF/`) via
   `find .../Resources -type f`. Besides `SWF/` (156 files, confirmed count — matches
   the figure from the prior pass) and the main `Gazillionaire.swf`, the tree contains:
   - `MP3/` — **175 `.mp3` files**, sound effects/stingers. Many share a base name with
     a `SWF/` file (e.g. `BANDITS.MP3` alongside `BANDITS.SWF`, played together via
     `playSoundNoLoop("MP3/BANDITS.MP3")` right next to the image assignment) — this is
     a **paired audio channel**, not previously cataloged anywhere. Out of scope for
     this pass (art only) but worth its own catalog later.
   - `PNG/` — **30 `.png` files**. Mostly `PLANET3.PNG`-style "level 3" planet variants
     (`BASS3.PNG`, `FRAC3.PNG`, … — a third zoom/upgrade level beyond the `SWF/`
     folder's level-1/level-2 planet art) plus **`OP1.PNG`–`OP6.PNG` and
     `OP1A.PNG`–`OP6A.PNG`**, loaded dynamically as
     `"PNG/OP" + (this.g.winner - 6) + ".PNG"` etc. (Gazillionaire.as ~line 51134,
     51513, 63386, 67715). **These are opponent/rival-company portraits** — a real,
     external, non-embedded portrait asset. **This corrects
     `docs/asset-inventory.md` finding #3** ("no alien/opponent portrait art exists at
     all"): that finding was scoped to the main SWF's `[Embed]` classes and is still
     true for that scope, but opponent portraits DO exist as loose external files —
     they just live in `PNG/`, not as an embedded class, which is why the earlier
     grep for class names found nothing. Also out of scope for this SWF-only pass;
     flagged here so it isn't missed.
   - `resources/` (lowercase, singular-vs-`Resources/`) — **60 files**. This is a
     **third asset channel** distinct from both the main-SWF embeds and the `SWF/`
     folder: it holds what look like the original **source** files for many of the
     main SWF's `[Embed]`-ed gui-chrome/icon assets under their pre-build names
     (`b_circle.swf`, `f_fillblue.png`, `f_fillred.png`, `i_zinn.png`,
     `i_warehouse.png`, `stars_main.swf`, etc. — names matching the `_class_embed_css_*`
     / `_embed_mxml_*` class names in `asset-inventory.md`), **plus 14
     `PlanetNAME1.SWF` files** (`BASS1.SWF`, `FRAC1.SWF`, `HORK1.SWF`, `LORO1.SWF`,
     `MIRA1.SWF`, `NOSH1.SWF`, `OOOM1.SWF`, `PYKE1.SWF`, `QUEG1.SWF`, `STYE1.SWF`,
     `TILO1.SWF`, `VEXX1.SWF`, `XEEN1.SWF`, `ZILE1.SWF`) that are very likely the exact
     source files compiled into the `Gazillionaire_Planet*1Class` embeds
     (`asset-inventory.md` rows for `148.bin`, `139.bin`, etc.) — **not byte-diffed in
     this pass**, flagged for a follow-up check rather than assumed identical.
     Notably `f_fillblue.png`/`f_fillred.png` **do exist here**, even though
     `asset-inventory.md` finding #5 says no bytes were recoverable for those two
     fuel-gauge classes from the decompiled `.as` — **this loose `resources/` copy may
     close that gap** for modloader purposes and is worth a direct look.
   - `icon-gaz/`, `Icon.icns` — app icons (not game art).
   - `META-INF/`, `mimetype` — AIR packaging/signing metadata, not assets.
   - **No fourth channel found.** Every file under `Resources/` falls into one of:
     main-SWF embeds (already cataloged), `SWF/` (this catalog), `MP3/`, `PNG/`,
     `resources/`, or app packaging/icons.

2. **File count under `Resources/SWF/`: confirmed 156** (`ls | wc -l` → 156, matching
   the number carried over from the prior pass — not just assumed).

3. **Two-direction reference cross-check:**
   - *Folder → code:* every file was grepped case-insensitively by base name against
     `Gazillionaire.as`. **155 of 156 resolve to at least one real usage site.**
     **`BANK2_N.SWF` is the sole exception — zero matches for `BANK2_N` anywhere in
     Gazillionaire.as, in any form.** `BANK2A_N.SWF` (its "A" sibling) IS referenced
     (`frm_Bank_image`, lines 48749/54196), but the non-"A" `BANK2_N.SWF` is not. This
     looks like a genuinely **orphaned/dead asset** — flagged in its table row below.
   - *Code → folder:* every distinct literal `"./SWF/NAME.SWF"` / `"SWF/NAME.SWF"`
     string in the file (128 distinct literal filenames, extracted via regex) was
     checked against the files on disk. **All 128 resolve to a real file with
     matching case.** No missing files, no case mismatches.
   - **Dynamic path construction confirmed and accounted for**, explaining why many
     files (planet `*2.SWF` variants, ship `*A.SWF` variants) don't show up as a
     literal string: `planet_image_swf()` (~Gazillionaire.as:50043-50099) builds
     `"SWF/" + PLANETNAME + levelSuffix + ".SWF"` (levelSuffix `""` or `"2"`), and
     `frm_Travel1_ship` (~line 63035) builds
     `"SWF/SHIP" + playerShip + "A.SWF"`. Both patterns were traced to source and are
     noted per-row below instead of being reported as unmatched.

**Result: clean bill of health except one orphaned file (`BANK2_N.SWF`) and the
`resources/`+`PNG/` discoveries above**, which don't affect this SWF-only catalog's
completeness but are worth a maintainer's attention before calling the full asset
picture "done."

## Summary

Total external SWF files cataloged: **156**. Static (1 frame): **127**. Animated (>1 frame): **29**.

| Category | Count |
|---|---|
| Ship | 24 |
| Alien NPC (named character) | 87 (MONEY_N.SWF recategorized to GUI, see below) |
| GUI | 3 |
| Environment (planet surface) | 0 (consolidated — see [planets-catalog.md](planets-catalog.md)) |
| Background | 2 |
| Title Screen | 2 |
| Cutscene / Intro | 8 |
| Other | 2 |

## Ship (24)

| Filename | Thumbnail | Frame count | Category | Suggested name | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|---|---|
| SHIP1.SWF | ![thumb](thumbnails/external-swf/ship1.swf.png) | 1 | ship | Ship 1 (selection art) | Gazillionaire.as:6669 |  |
| SHIP10.SWF | ![thumb](thumbnails/external-swf/ship10.swf.png) | 1 | ship | Ship 10 (selection art) | Gazillionaire.as:6831 |  |
| SHIP10A.SWF | ![thumb](thumbnails/external-swf/ship10a.swf.png) | 1 | ship | Ship 10 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP11.SWF | ![thumb](thumbnails/external-swf/ship11.swf.png) | 1 | ship | Ship 11 (selection art) | Gazillionaire.as:6849 |  |
| SHIP11A.SWF | ![thumb](thumbnails/external-swf/ship11a.swf.png) | 1 | ship | Ship 11 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP12.SWF | ![thumb](thumbnails/external-swf/ship12.swf.png) | 1 | ship | Ship 12 (selection art) | Gazillionaire.as:6867 |  |
| SHIP12A.SWF | ![thumb](thumbnails/external-swf/ship12a.swf.png) | 1 | ship | Ship 12 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP1A.SWF | ![thumb](thumbnails/external-swf/ship1a.swf.png) | 1 | ship | Ship 1 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP2.SWF | ![thumb](thumbnails/external-swf/ship2.swf.png) | 1 | ship | Ship 2 (selection art) | `frm_ChooseShip2` (Gazillionaire.as:333) |  |
| SHIP2A.SWF | ![thumb](thumbnails/external-swf/ship2a.swf.png) | 1 | ship | Ship 2 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP3.SWF | ![thumb](thumbnails/external-swf/ship3.swf.png) | 1 | ship | Ship 3 (selection art) | `frm_ChooseShip3` (Gazillionaire.as:347) |  |
| SHIP3A.SWF | ![thumb](thumbnails/external-swf/ship3a.swf.png) | 1 | ship | Ship 3 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP4.SWF | ![thumb](thumbnails/external-swf/ship4.swf.png) | 1 | ship | Ship 4 (selection art) | Gazillionaire.as:6723 |  |
| SHIP4A.SWF | ![thumb](thumbnails/external-swf/ship4a.swf.png) | 1 | ship | Ship 4 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP5.SWF | ![thumb](thumbnails/external-swf/ship5.swf.png) | 1 | ship | Ship 5 (selection art) | Gazillionaire.as:6741 |  |
| SHIP5A.SWF | ![thumb](thumbnails/external-swf/ship5a.swf.png) | 1 | ship | Ship 5 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP6.SWF | ![thumb](thumbnails/external-swf/ship6.swf.png) | 1 | ship | Ship 6 (selection art) | Gazillionaire.as:6759 |  |
| SHIP6A.SWF | ![thumb](thumbnails/external-swf/ship6a.swf.png) | 1 | ship | Ship 6 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP7.SWF | ![thumb](thumbnails/external-swf/ship7.swf.png) | 1 | ship | Ship 7 (selection art) | Gazillionaire.as:6777 |  |
| SHIP7A.SWF | ![thumb](thumbnails/external-swf/ship7a.swf.png) | 1 | ship | Ship 7 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP8.SWF | ![thumb](thumbnails/external-swf/ship8.swf.png) | 1 | ship | Ship 8 (selection art) | Gazillionaire.as:6795 |  |
| SHIP8A.SWF | ![thumb](thumbnails/external-swf/ship8a.swf.png) | 1 | ship | Ship 8 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |
| SHIP9.SWF | ![thumb](thumbnails/external-swf/ship9.swf.png) | 1 | ship | Ship 9 (selection art) | Gazillionaire.as:6813 |  |
| SHIP9A.SWF | ![thumb](thumbnails/external-swf/ship9a.swf.png) | 1 | ship | Ship 9 (in-flight variant) | `frm_Travel1_ship` dynamic path `"SWF/SHIP" + playerShip + "A.SWF"` (Gazillionaire.as:63035) |  |

## Alien NPC (named character) (88)

| Filename | Thumbnail | Frame count | Category | Suggested name | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|---|---|
| AGENT_L.SWF | ![thumb](thumbnails/external-swf/agent_l.swf.png) | 6 | alien-npc | Agent (loading/special) | `frm_Special_image` (Gazillionaire.as:56631) | Confirmed via GameStrings.as: "Your Agent" (frm_Special_result_11_1_1). |
| ASIAN_N.SWF | ![thumb](thumbnails/external-swf/asian_n.swf.png) | 21 | alien-npc | Imperial Magistrate | `frm_Special_image` (Gazillionaire.as:56345) | Real name/title: Imperial Magistrate — see frm_Special_action_0. |
| BANDITS.SWF | ![thumb](thumbnails/external-swf/bandits.swf.png) | 1 | alien-npc | Baid-Rowel Bandits | `frm_Travel2_vertical_image` (Gazillionaire.as:65956) | Real name: the Baid-Rowel Bandits — see frm_Travel2_bad_event_10_5. |
| BANK1A_N.SWF | ![thumb](thumbnails/external-swf/bank1a_n.swf.png) | 7 | alien-npc | Bank Manager | `frm_Bank_image` (Gazillionaire.as:48735) | Real title: Bank Manager — see frm_Bank_image_txt. |
| BANK1_N.SWF | ![thumb](thumbnails/external-swf/bank1_n.swf.png) | 7 | alien-npc | Bank1 (NPC) | `frm_Travel2_vertical_image` (Gazillionaire.as:64767) | Unresolved: generic banker portrait for the savings-interest Travel2 event; no personal name found near frm_Travel2_good_event_10. |
| BANK2A_N.SWF | ![thumb](thumbnails/external-swf/bank2a_n.swf.png) | 7 | alien-npc | Bank Manager (withdrawal pose) | `frm_Bank_image` (Gazillionaire.as:48749) | Real title: Bank Manager (same character/title as BANK1A_N) — see frm_Bank_image_txt. |
| BANK2_N.SWF | ![thumb](thumbnails/external-swf/bank2_n.swf.png) | 7 | alien-npc | Bank2 (NPC) | *(none found — orphaned asset, see completeness sweep)* | **ORPHANED — no reference to this filename (in any form) found anywhere in Gazillionaire.as.** Confirmed dead asset (or reached via a mechanism outside the decompiled .as source); see completeness sweep. Re-confirmed: zero references to SWF/BANK2_N.SWF anywhere in Gazillionaire.as — orphaned asset. |
| BOBBLE.SWF | ![thumb](thumbnails/external-swf/bobble.swf.png) | 1 | alien-npc | Bobble Warp | `frm_Travel2_image_ship` (Gazillionaire.as:66488) | Not a character: a space-time anomaly — see frm_Travel2_bad_event_11_19b ("Bobble Warp, a dangerous break in the time-space continuum"). |
| BOLLUP.SWF | ![thumb](thumbnails/external-swf/bollup.swf.png) | 1 | alien-npc | Bollup Juice | `frm_Travel2_image_ship` (Gazillionaire.as:66425) | Not a character: a corrosive substance — see frm_Travel2_bad_event_11_13b ("acidic Bollup Juice"). |
| BROKER_N.SWF | ![thumb](thumbnails/external-swf/broker_n.swf.png) | 10 | alien-npc | Your Stock Broker | `frm_Special_image` (Gazillionaire.as:56647) | Real title: Your Stock Broker — see frm_Special_action_12. |
| BRONAP.SWF | ![thumb](thumbnails/external-swf/bronap.swf.png) | 1 | alien-npc | Bro Nap Goodshark's Raiders | `frm_Travel2_vertical_image` (Gazillionaire.as:66248) | Real name: descendants of the infamous Bro Nap Goodshark — see frm_Travel2_bad_event_10_23 / 10_24. |
| CLOCK_L.SWF | ![thumb](thumbnails/external-swf/clock_l.swf.png) | 20 | alien-npc | Clock (loading/special) | `frm_Time_image` (Gazillionaire.as:59765) | Unresolved: generic clock-icon UI element on frm_Time screen; no bound character. |
| CORNU_N.SWF | ![thumb](thumbnails/external-swf/cornu_n.swf.png) | 24 | alien-npc | Lady Cornucopia | `frm_Special_image` (Gazillionaire.as:56501) | Real name: Lady Cornucopia, ruler of Queg — see frm_Special_action_8_1, frm_Special_result_8_1 through 8_12. |
| CREW_N.SWF | ![thumb](thumbnails/external-swf/crew_n.swf.png) | 20 | alien-npc | Crew (NPC) | `frm_Employee_image` (Gazillionaire.as:56099) | Unresolved: generic crew/sailor portrait reused across many Travel2 events; no distinct personal name. |
| CREW_S.SWF | ![thumb](thumbnails/external-swf/crew_s.swf.png) | 1 | alien-npc | Union Boss | `frm_Employee_image` (Gazillionaire.as:56051) | Real title: Union Boss — see frm_Employee_image_txt. |
| CURTIS.SWF | ![thumb](thumbnails/external-swf/curtis.swf.png) | 1 | alien-npc | Curtonian Plus | `frm_Travel2_vertical_image` (Gazillionaire.as:63906) | Real name: Curtonian Plus — see frm_Travel2_good_event_19_1 and 19_4. |
| CYLET.SWF | ![thumb](thumbnails/external-swf/cylet.swf.png) | 1 | alien-npc | Cylet Mind Buggers | `frm_Travel2_vertical_image` (Gazillionaire.as:66114) | Not an individual: the Cylet Mind Buggers, brain-robbing creatures — see frm_Travel2_bad_event_10_15. |
| DARLEEN.SWF | ![thumb](thumbnails/external-swf/darleen.swf.png) | 1 | alien-npc | Darleen Smugglers | `frm_Travel2_vertical_image` (Gazillionaire.as:65919) | Not an individual: the Darleen Smugglers — see frm_Travel2_bad_event_10_3. |
| DEALER_N.SWF | ![thumb](thumbnails/external-swf/dealer_n.swf.png) | 25 | alien-npc | Casino Dealer | `frm_Special_image` (Gazillionaire.as:56464) | Real title: Casino Dealer — see frm_Special_action_7. |
| DEXXYGAS.SWF | ![thumb](thumbnails/external-swf/dexxygas.swf.png) | 1 | alien-npc | Dexxy Gas | `frm_Travel2_image_ship` (Gazillionaire.as:66383) | Not a character: a corrosive gas cloud — see frm_Travel2_bad_event_11_9b. |
| DRED.SWF | ![thumb](thumbnails/external-swf/dred.swf.png) | 1 | alien-npc | Emperor Dred Nicolson | Gazillionaire.as:11225 | Real name: Emperor Dred Nicolson (also styled "Supreme Commander Dred Nicolson") — see frm_NewOrContinue_text, frm_Special_result_0_14, frm_News_text_87, frm_PlayerTurn2_auction_ship_no_bid, frm_Travel2_good_event_21_3/21_4. |
| FEZFAFA.SWF | ![thumb](thumbnails/external-swf/fezfafa.swf.png) | 1 | alien-npc | Fez Fa Fa | `frm_Travel2_vertical_image` (Gazillionaire.as:66051) | Not an individual: a herd of ever-hungry Fez Fa Fa creatures — see frm_Travel2_bad_event_10_11. |
| FIRE.SWF | ![thumb](thumbnails/external-swf/fire.swf.png) | 1 | alien-npc | Fire | Gazillionaire.as:72 | Unresolved: generic "Warehouse Fire" disaster event image, no character — see frm_Travel2_bad_event_3_0/3_1. |
| GURTTLE.SWF | ![thumb](thumbnails/external-swf/gurttle.swf.png) | 1 | alien-npc | Gurttle | `frm_Travel2_vertical_image` (Gazillionaire.as:65215) | Confirmed: "Gurttle, a notorious fuel fiend" — see frm_Travel2_good_event_31_1. |
| HANDS.SWF | ![thumb](thumbnails/external-swf/hands.swf.png) | 1 | alien-npc | Hands | `frm_Travel2_vertical_image` (Gazillionaire.as:64927) | Confirmed: "Hands, a well-known crook and racketeer" — see frm_Travel2_good_event_18_1. |
| HAPA.SWF | ![thumb](thumbnails/external-swf/hapa.swf.png) | 1 | alien-npc | Hapa Jillo Crime Syndicate | `frm_Travel2_vertical_image` (Gazillionaire.as:65469) | Not an individual: the Hapa Jillo Crime Syndicate — see frm_Travel2_good_event_42_1. |
| HUNGO.SWF | ![thumb](thumbnails/external-swf/hungo.swf.png) | 1 | alien-npc | Hungo Warriors | `frm_Travel2_vertical_image` (Gazillionaire.as:66077) | Not an individual: a tribe of Hungo Warriors — see frm_Travel2_bad_event_10_13/10_14. |
| INSURE_N.SWF | ![thumb](thumbnails/external-swf/insure_n.swf.png) | 17 | alien-npc | Insure (NPC) | Gazillionaire.as:11074 | Unresolved: generic insurance-purchase confirmation icon reused across several screens; no character name found. |
| INSURE_S.SWF | ![thumb](thumbnails/external-swf/insure_s.swf.png) | 1 | alien-npc | Insure (NPC alt) | `frm_Insurance_image` (Gazillionaire.as:56212) | Unresolved: generic insurance-office icon on frm_Insurance_load; no character name. |
| ISO.SWF | ![thumb](thumbnails/external-swf/iso.swf.png) | 1 | alien-npc | Iso | `frm_Travel2_vertical_image` (Gazillionaire.as:65103) | Confirmed: "Iso, a painfully shy monk" — see frm_Travel2_good_event_27_1. |
| LEAHY.SWF | ![thumb](thumbnails/external-swf/leahy.swf.png) | 1 | alien-npc | Captain Leahy | `frm_Travel2_vertical_image` (Gazillionaire.as:65323) | Real name: Captain Leahy, an ex-pirate turned businessman — see frm_Travel2_good_event_35_1. |
| LIMPUS.SWF | ![thumb](thumbnails/external-swf/limpus.swf.png) | 1 | alien-npc | Limpus | `frm_Travel2_vertical_image` (Gazillionaire.as:65055) | Confirmed: "Limpus, a renowned humanitarian and philanthropist" — see frm_Travel2_good_event_24_1. |
| LIPPO.SWF | ![thumb](thumbnails/external-swf/lippo.swf.png) | 1 | alien-npc | Lippo Jungies | `frm_Travel2_image_ship` (Gazillionaire.as:66184) | Not an individual: a herd of Lippo Jungies (space-whale creatures) — see frm_Travel2_bad_event_10_19b. |
| LOAN2_N.SWF | ![thumb](thumbnails/external-swf/loan2_n.swf.png) | 9 | alien-npc | Loan2 (NPC) | `frm_Loan_image` (Gazillionaire.as:54232) | Unresolved: generic bank-loan-office icon on frm_Loan_load; no character name. |
| LOAN_N.SWF | ![thumb](thumbnails/external-swf/loan_n.swf.png) | 9 | alien-npc | Loan (NPC) | `frm_Loan_not_enough_cash` (Gazillionaire.as:48761) | Unresolved: generic loan/payment icon reused across many contexts; no character name found near any use. |
| LORD.SWF | ![thumb](thumbnails/external-swf/lord.swf.png) | 1 | alien-npc | Lord 104 | `frm_Travel2_vertical_image` (Gazillionaire.as:65247) | Real name/title: Lord 104, the 104th Prince of the Leaper Colony — see frm_Travel2_good_event_32_1. |
| LUMBOR.SWF | ![thumb](thumbnails/external-swf/lumbor.swf.png) | 1 | alien-npc | Lumbor | `frm_Travel2_vertical_image` (Gazillionaire.as:66628) | Confirmed: "Lumbor, your ship's trusty engineer" — see frm_Travel2_bad_event_14. |
| MECHAN_L.SWF | ![thumb](thumbnails/external-swf/mechan_l.swf.png) | 6 | alien-npc | Mechan (loading/special) | `frm_Special_image` (Gazillionaire.as:56552) | Unresolved: "your favorite mechanic" is never personally named — see frm_Special_action_9_1_1 through 9_4_1 (planet Xeen). |
| MECH_N.SWF | ![thumb](thumbnails/external-swf/mech_n.swf.png) | 23 | alien-npc | Mech (NPC) | `frm_Special_image` (Gazillionaire.as:56368) | Unresolved: L-Tech Sales Rep. is never personally named — see frm_Special_action_1_1 (planet Pyke). |
| MEEG.SWF | ![thumb](thumbnails/external-swf/meeg.swf.png) | 1 | alien-npc | Meeg | `frm_Travel2_vertical_image` (Gazillionaire.as:64215) | Confirmed: "Meeg, a true adolescent technoid" — see frm_Travel2_good_event_38_1. |
| METEOR.SWF | ![thumb](thumbnails/external-swf/meteor.swf.png) | 1 | alien-npc | Meteor | `frm_Travel2_image_ship` (Gazillionaire.as:66302) | Unresolved: generic "meteor storm" hazard, no character — see frm_Travel2_bad_event_11_1a/1b. |
| MIPPI.SWF | ![thumb](thumbnails/external-swf/mippi.swf.png) | 1 | alien-npc | Mippi Weeds | `frm_Travel2_image_ship` (Gazillionaire.as:66404) | Not an individual: a cluster of sticky Mippi Weeds — see frm_Travel2_bad_event_11_11a/11b. |
| MONEY_N.SWF | ![thumb](thumbnails/external-swf/money_n.swf.png) | 11 | gui | Cash Reward Animation | `frm_Travel5_image` (Gazillionaire.as:52052), `frm_Travel2_vertical_image` (Gazillionaire.as:64446, 64838, 64855) | Not an NPC — an 11-frame growing stack-of-cash-bills animation shown whenever a "good event" grants the player cash (`this.g.p[this.g.player].cash += ...`, paired with `MP3/GOOD*.MP3` cues). Thumbnail regenerated from frame 11 (the earlier thumbnail captured frame 1, which is a blank/empty starting frame of the animation, not a broken export). |
| MONK_N.SWF | ![thumb](thumbnails/external-swf/monk_n.swf.png) | 31 | alien-npc | Grand Sage | `frm_Special_image` (Gazillionaire.as:56384) | Real title: Grand Sage (planet Mira) — see frm_Special_action_2. |
| MOOGLERS.SWF | ![thumb](thumbnails/external-swf/mooglers.swf.png) | 1 | alien-npc | Mooglers | `frm_Travel2_vertical_image` (Gazillionaire.as:66025) | Confirmed: "a crowd of mad Mooglers, a rowdy group of anarchists" — see frm_Travel2_bad_event_10_9. |
| MULLS.SWF | ![thumb](thumbnails/external-swf/mulls.swf.png) | 1 | alien-npc | Mulls | `frm_Travel2_vertical_image` (Gazillionaire.as:65339) | Confirmed: "Mulls, a reclusive, retired business consultant" — see frm_Travel2_good_event_36_0. |
| NEBBIT.SWF | ![thumb](thumbnails/external-swf/nebbit.swf.png) | 1 | alien-npc | Nebbit | `frm_Travel2_vertical_image` (Gazillionaire.as:65173) | Confirmed: "Nebbit, a big-time stock broker" — see frm_Travel2_good_event_29_1. |
| NECTUM.SWF | ![thumb](thumbnails/external-swf/nectum.swf.png) | 1 | alien-npc | Nectum | `frm_Travel2_vertical_image` (Gazillionaire.as:65263) | Confirmed: "Nectum, a foreign commodities wholesaler" — see frm_Travel2_good_event_33_1. |
| NEWS_L.SWF | ![thumb](thumbnails/external-swf/news_l.swf.png) | 8 | alien-npc | News (loading/special) | `frm_WinGame2_image` (Gazillionaire.as:51024) | Unresolved: generic News Center header portrait reused across several screens; no character name. |
| NIBBLE.SWF | ![thumb](thumbnails/external-swf/nibble.swf.png) | 1 | alien-npc | Nibble | `frm_Travel2_vertical_image` (Gazillionaire.as:64295) | Confirmed: "Nibble, a professional bully" — see frm_Travel2_good_event_40_1/40_3. |
| NOSH_H.SWF | ![thumb](thumbnails/external-swf/nosh_h.swf.png) | 1 | alien-npc | Nosh (horizontal) | `frm_Travel4_image_ship` (Gazillionaire.as:51778) | Unresolved: generic fuel-price news icon (frm_Travel4_event_7/8); no character name. |
| PEELIA_L.SWF | ![thumb](thumbnails/external-swf/peelia_l.swf.png) | 10 | alien-npc | Peelia Veelia, Queen of Loro | `frm_Special_image` (Gazillionaire.as:56416) | Real name/title: Peelia Veelia, Queen of Loro — see frm_Special_action_4. |
| PILOT.SWF | ![thumb](thumbnails/external-swf/pilot.swf.png) | 1 | alien-npc | Pilot | `frm_Travel2_vertical_image` (Gazillionaire.as:64469) | Unresolved: generic "your pilot" role portrait, no personal name — see frm_Travel2 navigation-error events. |
| POLICE.SWF | ![thumb](thumbnails/external-swf/police.swf.png) | 1 | alien-npc | Police | `frm_Travel2_vertical_image` (Gazillionaire.as:63830) | Unresolved: generic Imperial Police institution reused across several bust/fine events; no individually named officer. |
| QUASO.SWF | ![thumb](thumbnails/external-swf/quaso.swf.png) | 1 | alien-npc | Quaso Mutta | `frm_Travel2_vertical_image` (Gazillionaire.as:64552) | Real name: "the venerated Quaso Mutta" — see frm_Travel2_event_0_1. |
| QUIST.SWF | ![thumb](thumbnails/external-swf/quist.swf.png) | 1 | alien-npc | Quist | `frm_Travel2_vertical_image` (Gazillionaire.as:64967) | Confirmed: "Quist, a high flying financier" — see frm_Travel2_good_event_20_1. |
| REBELS.SWF | ![thumb](thumbnails/external-swf/rebels.swf.png) | 1 | alien-npc | Chichi Bobo Rebels | `frm_Travel2_vertical_image` (Gazillionaire.as:65893) | Not an individual: the Chichi Bobo Rebels — see frm_Travel2_bad_event_10_1. |
| REPAIR.SWF | ![thumb](thumbnails/external-swf/repair.swf.png) | 1 | alien-npc | Repair | `frm_Travel2_image_ship` (Gazillionaire.as:66597) | Unresolved: generic "Your Ship Breaks Down!" scene, no character — see frm_Travel2_bad_event_13. |
| RJ.SWF | ![thumb](thumbnails/external-swf/rj.swf.png) | 1 | alien-npc | R.J. Raffety | `frm_Travel2_vertical_image` (Gazillionaire.as:65139) | Real name: R.J. Raffety, a big-time speculator — see frm_Travel2_good_event_28_1. |
| SABOTAGE.SWF | ![thumb](thumbnails/external-swf/sabotage.swf.png) | 1 | alien-npc | Brow | Gazillionaire.as:51367 | Real name: Brow, an industrial spy — see frm_Travel2_good_event_22_1. |
| SCOOTER.SWF | ![thumb](thumbnails/external-swf/scooter.swf.png) | 1 | alien-npc | Scooter Jay | `frm_Travel2_vertical_image` (Gazillionaire.as:64895) | Real name: Scooter Jay, a smuggler — see frm_Travel2_good_event_17_1 and frm_News_text_87 (same character referenced later as a news headline). |
| SHIMMER.SWF | ![thumb](thumbnails/external-swf/shimmer.swf.png) | 1 | alien-npc | Lady Shimmer | `frm_Travel2_vertical_image` (Gazillionaire.as:64423) | Real name: Lady Shimmer, a former polka dancer — see frm_Travel2_good_event_45_1. |
| SLEG.SWF | ![thumb](thumbnails/external-swf/sleg.swf.png) | 1 | alien-npc | Sleg | `frm_Travel2_vertical_image` (Gazillionaire.as:65071) | Confirmed: "Sleg, an inter-galactic commodities broker" — see frm_Travel2_good_event_25_1. |
| SNOZ.SWF | ![thumb](thumbnails/external-swf/snoz.swf.png) | 1 | alien-npc | Snoz Lombardo | `frm_Travel2_vertical_image` (Gazillionaire.as:65516) | Real name: Snoz Lombardo, a lounge singer — see frm_Travel2_good_event_44_1. |
| SOOTH_N.SWF | ![thumb](thumbnails/external-swf/sooth_n.swf.png) | 30 | alien-npc | Soothsayer of Ooom | `frm_Special_image` (Gazillionaire.as:56576) | Real title: Soothsayer (planet Ooom) — see frm_Special_action_10_1, frm_Special_result_10_1. |
| SPEEVAK.SWF | ![thumb](thumbnails/external-swf/speevak.swf.png) | 1 | alien-npc | Speevak | `frm_Travel2_vertical_image` (Gazillionaire.as:65452) | Not an individual: "Speevak" is a species name (a pregnant space fly) — see frm_Travel2_good_event_41_1. |
| SPIKE.SWF | ![thumb](thumbnails/external-swf/spike.swf.png) | 1 | alien-npc | Spike the Space Mutt | `frm_Travel2_vertical_image` (Gazillionaire.as:64260) | Fuller name: Spike the Space Mutt — see frm_Travel2_good_event_39_1. |
| SQUOWK.SWF | ![thumb](thumbnails/external-swf/squowk.swf.png) | 1 | alien-npc | Squowk | `frm_Travel2_vertical_image` (Gazillionaire.as:65289) | Confirmed: "Squowk, a migrating commodities merchant" — see frm_Travel2_good_event_34_1. |
| STORM.SWF | ![thumb](thumbnails/external-swf/storm.swf.png) | 1 | alien-npc | Storm | `frm_Travel2_horizontal_image` (Gazillionaire.as:66322) | Unresolved: generic storm/hazard image reused across several bad-event outcomes; no named character. |
| STUBBS.SWF | ![thumb](thumbnails/external-swf/stubbs.swf.png) | 1 | alien-npc | Stubbs | `frm_Travel2_vertical_image` (Gazillionaire.as:65580) | Confirmed: "Stubbs, a crazed water junkie" — see frm_Travel2_good_event_47_1. |
| TATILUS.SWF | ![thumb](thumbnails/external-swf/tatilus.swf.png) | 1 | alien-npc | Tatilus | `frm_Travel2_vertical_image` (Gazillionaire.as:65198) | Confirmed: "Tatilus, an emergency passenger broker" — see frm_Travel2_good_event_30_1. |
| TAX1H_N.SWF | ![thumb](thumbnails/external-swf/tax1h_n.swf.png) | 32 | alien-npc | Tax1H (NPC) | `frm_Travel4_image` (Gazillionaire.as:51807) | Unresolved: generic tax-collector illustration for Travel4 tax events; no character name. |
| TAX1_N.SWF | ![thumb](thumbnails/external-swf/tax1_n.swf.png) | 32 | alien-npc | Tax1 (NPC) | `frm_Tax_image` (Gazillionaire.as:56129) | Unresolved: generic tax-office illustration for frm_Tax screen; no character name. |
| TAX2H_N.SWF | ![thumb](thumbnails/external-swf/tax2h_n.swf.png) | 13 | alien-npc | Tax2H (NPC) | `frm_Travel4_image` (Gazillionaire.as:51861) | Unresolved: generic tax illustration, same as TAX1H_N for later events; no character name. |
| TAX2_N.SWF | ![thumb](thumbnails/external-swf/tax2_n.swf.png) | 13 | alien-npc | Tax2 (NPC) | `frm_Tax_image` (Gazillionaire.as:56180) | Unresolved: generic "tax paid" illustration in frm_Tax_pay; no character name. |
| TEAL.SWF | ![thumb](thumbnails/external-swf/teal.swf.png) | 1 | alien-npc | Teal | `frm_Travel2_vertical_image` (Gazillionaire.as:65562) | Confirmed (not a person): "a Teal Tree, a lonely breed of wild space oak" — see frm_Travel2_good_event_46_1. |
| TEETER.SWF | ![thumb](thumbnails/external-swf/teeter.swf.png) | 1 | alien-npc | Teeter | Gazillionaire.as:58110 | Confirmed: "Teeter may not look like a genius, but he manages to turbocharge your ship's engine" — see frm_Travel2_good_event_37_9. |
| VAPOR.SWF | ![thumb](thumbnails/external-swf/vapor.swf.png) | 1 | alien-npc | Vapor | `frm_Travel2_image_ship` (Gazillionaire.as:66446) | Unresolved: generic "Hazardous Vapor" hazard image, no character — see frm_Travel2_bad_event_11_15a. |
| WAREHOUS.SWF | ![thumb](thumbnails/external-swf/warehous.swf.png) | 1 | alien-npc | Warehous | `frm_MainMenu_button_warehouse` (Gazillionaire.as:1245) | Unresolved: generic "Warehouse Space For Sale" building illustration, no character — see frm_Travel2_good_event_3_0. |
| WEATHER_L.SWF | ![thumb](thumbnails/external-swf/weather_l.swf.png) | 8 | alien-npc | Weather (loading/special) | `frm_Weather_load` (Gazillionaire.as:59339) | Unresolved: generic weather-report screen illustration on frm_Weather_load; no character. |
| WHIRL.SWF | ![thumb](thumbnails/external-swf/whirl.swf.png) | 1 | alien-npc | Whirl | `frm_Travel2_image_ship` (Gazillionaire.as:66467) | Unresolved: generic "Tight Spin" whirlwind hazard image, no character — see frm_Travel2_bad_event_11_17a. |
| WICKY.SWF | ![thumb](thumbnails/external-swf/wicky.swf.png) | 1 | alien-npc | Wicky Wicks | `frm_Travel2_vertical_image` (Gazillionaire.as:66211) | Not an individual: a group of nasty little Wicky Wicks — see frm_Travel2_bad_event_10_21/10_22. |
| WOBBLER.SWF | ![thumb](thumbnails/external-swf/wobbler.swf.png) | 1 | alien-npc | The Wobbler | `frm_Travel2_vertical_image` (Gazillionaire.as:64991) | Confirmed, fuller form: "The Wobbler," a starving artist — see frm_Travel2_good_event_21_1. (Distinct from DRED.SWF, which is the outcome-screen portrait for the same event, showing Supreme Commander Dred Nicolson's reaction.) |
| YOYO.SWF | ![thumb](thumbnails/external-swf/yoyo.swf.png) | 1 | alien-npc | Yoyo | Gazillionaire.as:63994 | Confirmed: "Yoyo, a notorious gambler" — see frm_Travel2_good_event_23_1. |
| ZINN2_N.SWF | ![thumb](thumbnails/external-swf/zinn2_n.swf.png) | 29 | alien-npc | Mr. Zinn | `frm_ZinnLoan_image` (Gazillionaire.as:54350) | Real name: Mr. Zinn — see frm_ZinnLoan_image_txt, frm_Special_action_5. |
| ZINN_N.SWF | ![thumb](thumbnails/external-swf/zinn_n.swf.png) | 29 | alien-npc | Mr. Zinn | `frm_ChooseShip3_image` (Gazillionaire.as:50637) | Real name: Mr. Zinn — see frm_Special_action_5 ("Zile is Mr. Zinn's home planet"). |
| ZOBROK_N.SWF | ![thumb](thumbnails/external-swf/zobrok_n.swf.png) | 9 | alien-npc | Zobrok the Fuel Wholesaler | `frm_Special_image` (Gazillionaire.as:58627) | Real name/title: Zobrok the Fuel Wholesaler — see frm_Special_result_13_1. |
| ZOBROK_S.SWF | ![thumb](thumbnails/external-swf/zobrok_s.swf.png) | 1 | alien-npc | Zobrok the Fuel Wholesaler (alt art) | `frm_Special_image` (Gazillionaire.as:56670) | Same character as ZOBROK_N, alternate art variant used in the same planet fuel-purchase flow — see frm_Special_result_13_1. |

## GUI (2)

| Filename | Thumbnail | Frame count | Category | Suggested name | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|---|---|
| WHITE_H.SWF | ![thumb](thumbnails/external-swf/white_h.swf.png) | 1 | gui | White (horizontal) | Gazillionaire.as:8075 |  |
| WHITE_V.SWF | ![thumb](thumbnails/external-swf/white_v.swf.png) | 1 | gui | White V | Gazillionaire.as:7116 |  |

## Environment (planet surface) — consolidated

Planet assets consolidated — see [Planets](Asset-Wiki-Planets) /
[planets-catalog.md](planets-catalog.md). All 28 rows previously here (14
planets x level-1/level-2 surface SWFs) now live there, alongside each
planet's main-SWF icon, dead-code level-3 PNG, and resources-folder
duplicate.

## Background (2)

| Filename | Thumbnail | Frame count | Category | Suggested name | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|---|---|
| STARS2.SWF | ![thumb](thumbnails/external-swf/stars2.swf.png) | 1 | background | Stars2 | Gazillionaire.as:3856 |  |
| STARS_BG.SWF | ![thumb](thumbnails/external-swf/stars_bg.swf.png) | 1 | background | Stars Bg | Gazillionaire.as:5591 |  |

## Title Screen (2)

| Filename | Thumbnail | Frame count | Category | Suggested name | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|---|---|
| GAZ_TITLE_S.SWF | ![thumb](thumbnails/external-swf/gaz_title_s.swf.png) | 1 | title-screen | Gaz Title (NPC alt) | Gazillionaire.as:3096 |  |
| NEWCONTINUE.SWF | ![thumb](thumbnails/external-swf/newcontinue.swf.png) | 1 | title-screen | Newcontinue | Gazillionaire.as:3345 |  |

## Cutscene / Intro (8)

| Filename | Thumbnail | Frame count | Category | Suggested name | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|---|---|
| INIT.SWF | ![thumb](thumbnails/external-swf/init.swf.png) | 1 | cutscene | Init | Gazillionaire.as:79 |  |
| INIT_MONSTER.SWF | ![thumb](thumbnails/external-swf/init_monster.swf.png) | 1 | cutscene | Init Monster | Gazillionaire.as:3135 |  |
| LAVAMIND_S.SWF | ![thumb](thumbnails/external-swf/lavamind_s.swf.png) | 1 | cutscene | Lavamind (NPC alt) | Gazillionaire.as:3750 |  |
| LEVEL_PLANET.SWF | ![thumb](thumbnails/external-swf/level_planet.swf.png) | 1 | cutscene | Level Planet | Gazillionaire.as:4410 |  |
| LOSE.SWF | ![thumb](thumbnails/external-swf/lose.swf.png) | 1 | cutscene | Lose | `frm_HelpNew2_button_close` (Gazillionaire.as:789) |  |
| PROPEOPLE.SWF | ![thumb](thumbnails/external-swf/propeople.swf.png) | 1 | cutscene | Propeople | Gazillionaire.as:4107 |  |
| WIN.SWF | ![thumb](thumbnails/external-swf/win.swf.png) | 1 | cutscene | Win | Gazillionaire.as:45 |  |
| ZAP_INTRO.SWF | ![thumb](thumbnails/external-swf/zap_intro.swf.png) | 1 | cutscene | Zap Intro | Gazillionaire.as:3921 |  |

## Other (2)

| Filename | Thumbnail | Frame count | Category | Suggested name | Used at (Gazillionaire.as reference) | Notes |
|---|---|---|---|---|---|---|
| GAZINFO.SWF | ![thumb](thumbnails/external-swf/gazinfo.swf.png) | 1 | other | Gazinfo | Gazillionaire.as:4293 |  |
| HISTORY.SWF | ![thumb](thumbnails/external-swf/history.swf.png) | 1 | other | History | `frm_Explore_button_history` (Gazillionaire.as:605) |  |
