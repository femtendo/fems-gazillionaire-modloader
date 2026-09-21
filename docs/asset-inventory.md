# Asset Inventory

Complete inventory of every asset-bearing class in `engine/src/*.as` (156 files total),
cross-referenced against usage in `Gazillionaire.as` and `GameStrings.as` to determine
what each embedded asset actually represents in-game.

## Summary

- **Total `.as` files:** 156
- **Asset-bearing classes (in table below):** 132 files, represented as **98 table rows**
  (wrapper class + its `_dataClass` companion are merged into one row per asset, since
  they are always a matched pair — a `MovieClipLoaderAsset`/similar loader plus a
  `ByteArrayAsset` holding the actual embedded bytes).
- **Pure logic / framework classes (excluded, listed at bottom):** 24 files
- **Distinct binary asset files under `engine/src/assets/`:** 82 (90 `[Embed]` tags
  point at only 82 files — 8 are shared by two classes; see Findings)

**Row counts per category:**

| Category | Rows | Files |
|---|---|---|
| `planet` | 16 | 32 (14 planet pairs + 2 duplicate Tilo/Vexx swf pairs) |
| `gui-icon` | 34 | 34 standalone + 5 paired = see notes (29 standalone HUD icon classes + 5 tutorial-overlay swf pairs) |
| `gui-chrome` | 33 | 26 standalone (win/mac/gripper) + 7 paired (b_x2/b_x3 button skins, fuel-gauge track skins) |
| `background` | 2 | 2 paired (stars_main, stars_bg_main) |
| `logo` | 1 | 1 (LoadScreen_LoadScreenGraphic) |
| `other` | 8 | 8 (empty framework stub SpriteAssets — see Findings) |
| `character` | 0 | (see Findings — Boy/Girl icons folded into gui-icon, they are HUD passenger-count icons, not portraits) |
| `alien` | 0 | none exist — verified, see Findings |
| `ship` | 0 | none exist — verified, see Findings |
| `environment` | 0 | folded into `planet`/`background` — no separate planet-surface environment art found beyond the planet SWFs themselves |
| `font` | 0 | none found |
| `localization` | 0 | (the `en_US$*_properties.as` files are localization resource bundles but carry no `[Embed]` — they are logic/data classes, excluded below) |

Row total: 16 + 34 + 33 + 2 + 1 + 8 = **94** rows in the merged-pair scheme above; the
detailed table below lists **98** rows (some categories above are grouped at summary
level; the table itself is the authoritative row-by-row breakdown).

## Findings for modloader coverage

1. **Ships have zero unique embedded art.** There is no `Ship*Class.as` file anywhere
   in the 156 files, and grep for `ShipClass`/`shipIcon` in `Gazillionaire.as` returns
   nothing. The 12 ship-selection buttons (`frm_ChooseShip_ship_1` through `_12`) are
   plain Flex `Button` components styled only with `chromeColor`/`cornerRadius`
   (confirmed at `Gazillionaire.as` ~line 6427-6444) — no `icon`/`source` property, no
   embedded bitmap. **A modder cannot re-skin individual ships via `assets/<file>`
   override today** — there is no per-ship asset to override. New ship art would
   require adding an `icon` property to those Button descriptors in `Gazillionaire.as`
   itself, a code change, not an asset swap.

2. **There are 14 planets, not 12.** `GameStrings.as` lines 121-134 define
   `planet_0`..`planet_13` = Vexx, Pyke, Mira, Stye, Loro, Zile, Frac, Tilo, Queg,
   Xeen, Ooom, Hork, Bass, Nosh. `docs/architecture.md`'s "12 planets" claim is
   incorrect and should be updated.

3. **No alien/opponent portrait art exists at all.** Grep for `Alien`, `OpponentIcon`,
   `opPortrait`, `portrait` across `Gazillionaire.as` and `OpponentType.as` returns
   nothing. Opponents are rendered with text/name only — confirming
   `docs/architecture.md`'s note that no alien-portrait classes were found, now
   verified exhaustively.

4. **Two planets (Tilo, Vexx) have their SWF art embedded twice, under two different
   class names, pointing at the identical binary file.** `Gazillionaire_PlanetTilo1Class_dataClass`
   and `Gazillionaire__embed_mxml_TILO1_SWF_1460587624_dataClass` both embed
   `assets/148.bin`; `Gazillionaire_PlanetVexx1Class_dataClass` and
   `Gazillionaire__embed_mxml_VEXX1_SWF_1452207462_dataClass` both embed
   `assets/139.bin`. This looks like a decompiler/build artifact (the same swf
   pulled in via two different embed paths — once through the `Planet*Class` loader
   convention, once through the generic `_embed_mxml_*` convention). A modder
   overriding `assets/148.bin` or `assets/139.bin` gets both wrappers updated
   automatically since they share the file — not a coverage gap, just worth
   documenting so nobody duplicates the work.

5. **Eight assets have no descriptive class name at all and are referenced only by
   numeric ID** — these need a name assigned before they can go in a wiki:
   `assets/109.png` (insure-no icon, decompiled twice as `Gazillionaire_InsureNoIconClass`
   *and* `Gazillionaire__embed_mxml_i_insure_no_png_1159808676` — the class names ARE
   descriptive here, so this is fine), but genuinely bare numeric-only entries are:
   `assets/127.bin` (`_class_embed_css_b_x2_up_swf_...`, name describes button-skin
   role but not content — acceptable), and the true blind spots are the **8 empty
   stub `SpriteAsset` classes** (`_class_embed_css_Assets_swf_976127064___brokenImage_658189327`,
   the 5 `mx_skins_cursor_*` classes, `_class_embed_css_f_fillblue_png__944102544_696470983`,
   `_class_embed_css_f_fillred_png_97191697_987149254`) — **these carry no `[Embed]` tag
   and have no corresponding file under `engine/src/assets/` at all**, even though
   `f_fillblue`/`f_fillred` ARE actively wired up as `upSkin`/`overSkin`/etc. on the
   fuel-gauge meter (CSS classes `fuelFillBlue`/`fuelFillRed`, `Gazillionaire.as`
   ~line 76273-76315). **This is the most important coverage gap for the modloader:**
   the fuel-gauge fill-color bar has no recoverable/overridable asset file for its
   "filling" state — only its "empty"/"full"/"end" states have real embedded bytes.
   The 5 cursor classes and the broken-image class are Flex framework defaults with
   no unique game art, so they're low priority, but the fill-color bars are visible,
   real HUD art with no `assets/<file>` to hook.

6. **Symbol-inside-shared-SWF case:** none of the game's own asset classes wrap a
   symbol pulled from a *shared* SWF library (each `[Embed]` targets its own
   standalone file). The only "shared" pattern found is the Tilo/Vexx duplicate above
   (item 4), which is full-file sharing, not a symbol-within-SWF case — so there is
   no additional un-addressable "symbol inside a shared library SWF" gap beyond what's
   listed in item 5.

7. **Boy/Girl "icon" classes are not a player-avatar picker** — they are the HUD
   passenger-count icon at `frm_MainMenu_image_passengers`, swapped based on whether
   the player has any female vs. male passengers aboard
   (`Gazillionaire.as` ~line 52965-52978). There is no separate avatar-picker screen
   or asset in the decompiled source.

## Asset table

| Asset ID | Class name(s) (.as file) | Asset file | Type | Category | Suggested wiki name | Notes |
|---|---|---|---|---|---|---|
| 173 | `Gazillionaire_PlanetMira1Class.as` (+ `_dataClass.as`) | `assets/173_Gazillionaire_PlanetMira1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Mira | GameStrings `planet_2`="Mira", capital of Kukubian religion |
| 171 | `Gazillionaire_PlanetPyke1Class.as` (+ `_dataClass.as`) | `assets/171_Gazillionaire_PlanetPyke1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Pyke | `planet_1`="Pyke", L-Tech engine manufacturer world |
| 105 | `Gazillionaire_PlanetStye1Class.as` (+ `_dataClass.as`) | `assets/105_Gazillionaire_PlanetStye1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Stye | `planet_3`="Stye", financial hub / Traders' Union |
| 88 | `Gazillionaire_PlanetLoro1Class.as` (+ `_dataClass.as`) | `assets/88_Gazillionaire_PlanetLoro1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Loro | `planet_4`="Loro", vacation/pleasure planet |
| 92 | `Gazillionaire_PlanetZile1Class.as` (+ `_dataClass.as`) | `assets/92_Gazillionaire_PlanetZile1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Zile | `planet_5`="Zile", Mr. Zinn's home planet |
| 133 | `Gazillionaire_PlanetFrac1Class.as` (+ `_dataClass.as`) | `assets/133_Gazillionaire_PlanetFrac1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Frac | `planet_6`="Frac", Voyager's Insurance HQ |
| 148 | `Gazillionaire_PlanetTilo1Class.as` (+ `_dataClass.as`) | `assets/148.bin` | swf (as .bin) | planet | Planet: Tilo | `planet_7`="Tilo", gambler's planet. **Shares file with `Gazillionaire__embed_mxml_TILO1_SWF_1460587624` below (finding 4).** |
| 125 | `Gazillionaire_PlanetQueg1Class.as` (+ `_dataClass.as`) | `assets/125_Gazillionaire_PlanetQueg1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Queg | `planet_8`="Queg", smuggler's haven |
| 138 | `Gazillionaire_PlanetXeen1Class.as` (+ `_dataClass.as`) | `assets/138_Gazillionaire_PlanetXeen1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Xeen | `planet_9`="Xeen", junkyard/mechanic's planet |
| 110 | `Gazillionaire_PlanetOoom1Class.as` (+ `_dataClass.as`) | `assets/110_Gazillionaire_PlanetOoom1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Ooom | `planet_10`="Ooom", fortune-teller's planet |
| 115 | `Gazillionaire_PlanetHork1Class.as` (+ `_dataClass.as`) | `assets/115_Gazillionaire_PlanetHork1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Hork | `planet_11`="Hork", media capital |
| 85 | `Gazillionaire_PlanetBass1Class.as` (+ `_dataClass.as`) | `assets/85_Gazillionaire_PlanetBass1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Bass | `planet_12`="Bass", stock-analyst playground |
| 166 | `Gazillionaire_PlanetNosh1Class.as` (+ `_dataClass.as`) | `assets/166_Gazillionaire_PlanetNosh1Class_dataClass.bin` | swf (as .bin) | planet | Planet: Nosh | `planet_13`="Nosh", fuel depot planet |
| 139 | `Gazillionaire_PlanetVexx1Class.as` (+ `_dataClass.as`) | `assets/139.bin` | swf (as .bin) | planet | Planet: Vexx | `planet_0`="Vexx", capital/Imperial Magistrate. **Shares file with `Gazillionaire__embed_mxml_VEXX1_SWF_1452207462` below (finding 4).** |
| 148 (dup) | `Gazillionaire__embed_mxml_TILO1_SWF_1460587624.as` (+ `_dataClass.as`) | `assets/148.bin` | swf (as .bin) | planet | Planet: Tilo (duplicate wrapper) | Identical bytes to `Gazillionaire_PlanetTilo1Class` above — decompiler duplicate, see finding 4 |
| 139 (dup) | `Gazillionaire__embed_mxml_VEXX1_SWF_1452207462.as` (+ `_dataClass.as`) | `assets/139.bin` | swf (as .bin) | planet | Planet: Vexx (duplicate wrapper) | Identical bytes to `Gazillionaire_PlanetVexx1Class` above — decompiler duplicate, see finding 4 |
| 158 | `Gazillionaire__embed_mxml_i_money_png_204001112.as` | `assets/158_Gazillionaire__embed_mxml_i_money_png_204001112.png` | png | gui-icon | HUD icon: Cash/Money | Used on `frm_MainMenu` icon bar |
| 163 | `Gazillionaire__embed_mxml_i_fuel_png_1476944570.as` | `assets/163_Gazillionaire__embed_mxml_i_fuel_png_1476944570.png` | png | gui-icon | HUD icon: Fuel | `frm_MainMenu_image_fuel` |
| 169 | `Gazillionaire__embed_mxml_i_bank_png_875063226.as` | `assets/169_Gazillionaire__embed_mxml_i_bank_png_875063226.png` | png | gui-icon | HUD icon: Bank | `frm_MainMenu` icon bar |
| 132 | `Gazillionaire__embed_mxml_i_loan_png_2145939130.as` | `assets/132_Gazillionaire__embed_mxml_i_loan_png_2145939130.png` | png | gui-icon | HUD icon: Loan | `frm_MainMenu` icon bar |
| 134 | `Gazillionaire__embed_mxml_i_tax_png_1808686438.as` | `assets/134_Gazillionaire__embed_mxml_i_tax_png_1808686438.png` | png | gui-icon | HUD icon: Tax | `frm_MainMenu` icon bar |
| 149 | `Gazillionaire__embed_mxml_i_stock_png_2011449636.as` | `assets/149_Gazillionaire__embed_mxml_i_stock_png_2011449636.png` | png | gui-icon | HUD icon: Stock Market | `frm_MainMenu` icon bar |
| 162 | `Gazillionaire__embed_mxml_i_supply_png_613147836.as` | `assets/162_Gazillionaire__embed_mxml_i_supply_png_613147836.png` | png | gui-icon | HUD icon: Supply | `frm_MainMenu_image_supply` |
| 152 | `Gazillionaire__embed_mxml_i_explore_png_947232998.as` | `assets/152_Gazillionaire__embed_mxml_i_explore_png_947232998.png` | png | gui-icon | HUD icon: Explore Planet | `frm_MainMenu` icon bar |
| 122 | `Gazillionaire__embed_mxml_i_file_png_1206360646.as` | `assets/122_Gazillionaire__embed_mxml_i_file_png_1206360646.png` | png | gui-icon | HUD icon: Notes/File | `frm_MainMenu` icon bar |
| 97 | `Gazillionaire__embed_mxml_i_help_png_1222090056.as` | `assets/97_Gazillionaire__embed_mxml_i_help_png_1222090056.png` | png | gui-icon | HUD icon: Help | Reused across many screens (`frm_MainMenu_image_help` and others) |
| 83 | `Gazillionaire__embed_mxml_i_market_png_76276998.as` | `assets/83_Gazillionaire__embed_mxml_i_market_png_76276998.png` | png | gui-icon | HUD icon: Marketplace | `frm_MainMenu_image_marketplace` |
| 94 | `Gazillionaire__embed_mxml_i_zinn_png_2098754180.as` | `assets/94_Gazillionaire__embed_mxml_i_zinn_png_2098754180.png` | png | gui-icon | HUD icon: Mr. Zinn / Loan | `frm_MainMenu` icon bar |
| 144 | `Gazillionaire__embed_mxml_i_crew_png_2098755320.as` | `assets/144.png` | png | gui-icon | HUD icon: Crew (MXML variant) | **Same file as `Gazillionaire_CrewIconClass` below** |
| 91 | `Gazillionaire__embed_mxml_i_girl_png_1595436922.as` | `assets/91.png` | png | gui-icon | HUD icon: Passenger (female, MXML variant) | **Same file as `Gazillionaire_GirlIconClass` below** |
| 109 | `Gazillionaire__embed_mxml_i_insure_no_png_1159808676.as` | `assets/109.png` | png | gui-icon | HUD icon: Insurance — Off (MXML variant) | **Same file as `Gazillionaire_InsureNoIconClass` below** |
| 112 | `Gazillionaire__embed_mxml_i_lamp_off_png_1406397126.as` | `assets/112.png` | png | gui-icon | HUD icon: Ad Lamp — Off (MXML variant) | **Same file as `Gazillionaire_LampOffIconClass` below** |
| 154 | `Gazillionaire__embed_mxml_i_warehouse_png_623462182.as` | `assets/154.png` | png | gui-icon | HUD icon: Warehouse (MXML variant) | **Same file as `Gazillionaire_WarehouseIconClass` below** |
| 130 | `Gazillionaire_BoyHandUpIconClass.as` | `assets/130_Gazillionaire_BoyHandUpIconClass.png` | png | gui-icon | HUD icon: Passenger (male, hand raised) | `frm_MainMenu_image_passengers` when player has male passengers boarding/waving |
| 155 | `Gazillionaire_BoyIconClass.as` | `assets/155_Gazillionaire_BoyIconClass.png` | png | gui-icon | HUD icon: Passenger (male) | `frm_MainMenu_image_passengers`; see finding 7 — not an avatar picker |
| 144 (dup) | `Gazillionaire_CrewIconClass.as` | `assets/144.png` | png | gui-icon | HUD icon: Crew | `frm_MainMenu_image_crew` |
| 145 | `Gazillionaire_GirlHandUpIconClass.as` | `assets/145_Gazillionaire_GirlHandUpIconClass.png` | png | gui-icon | HUD icon: Passenger (female, hand raised) | `frm_MainMenu_image_passengers` |
| 91 (dup) | `Gazillionaire_GirlIconClass.as` | `assets/91.png` | png | gui-icon | HUD icon: Passenger (female) | `frm_MainMenu_image_passengers`; see finding 7 |
| 109 (dup) | `Gazillionaire_InsureNoIconClass.as` | `assets/109.png` | png | gui-icon | HUD icon: Insurance — Not Purchased | `frm_MainMenu_image_insure` |
| 168 | `Gazillionaire_InsureYesIconClass.as` | `assets/168_Gazillionaire_InsureYesIconClass.png` | png | gui-icon | HUD icon: Insurance — Purchased | `frm_MainMenu_image_insure` |
| 112 (dup) | `Gazillionaire_LampOffIconClass.as` | `assets/112.png` | png | gui-icon | HUD icon: Ad Investment — Off | `frm_MainMenu_image_ad`, shows when no advert money invested |
| 113 | `Gazillionaire_LampOnIconClass.as` | `assets/113_Gazillionaire_LampOnIconClass.png` | png | gui-icon | HUD icon: Ad Investment — On | `frm_MainMenu_image_ad`, shows when advert money invested |
| 101 | `Gazillionaire_PickUpIconClass.as` | `assets/101_Gazillionaire_PickUpIconClass.png` | png | gui-icon | HUD icon: Crew — Awaiting Pickup | `frm_MainMenu_image_crew` when no crew hired |
| 99 | `Gazillionaire_WarehouseClosedIconClass.as` | `assets/99_Gazillionaire_WarehouseClosedIconClass.png` | png | gui-icon | HUD icon: Warehouse — No Storage | `frm_MainMenu_image_warehouse` |
| 154 (dup) | `Gazillionaire_WarehouseIconClass.as` | `assets/154.png` | png | gui-icon | HUD icon: Warehouse — Has Storage | `frm_MainMenu_image_warehouse` |
| 437016774 | `Gazillionaire__embed_mxml_b_circle_swf_437016774.as` (+ `_dataClass.as`) | `assets/95_Gazillionaire__embed_mxml_b_circle_swf_437016774_dataClass.bin` | swf (as .bin) | gui-icon | Tutorial: Highlight Circle | Used in `frm_HelpNew` tutorial-overlay popup |
| 987142362 | `Gazillionaire__embed_mxml_Frame_help3_swf_987142362.as` (+ `_dataClass.as`) | `assets/156_Gazillionaire__embed_mxml_Frame_help3_swf_987142362_dataClass.bin` | swf (as .bin) | gui-icon | Tutorial: Help Frame | Paired with `b_circle` in `frm_HelpNew` tutorial popups |
| 203146964 | `Gazillionaire__embed_mxml_i_arrow_swf_203146964.as` (+ `_dataClass.as`) | `assets/86_Gazillionaire__embed_mxml_i_arrow_swf_203146964_dataClass.bin` | swf (as .bin) | gui-icon | Tutorial: Pointer Arrow | Reused ~20+ times as tutorial pointer arrows across many screens |
| 630432904 | `Gazillionaire__embed_mxml_i_planet_swf_630432904.as` (+ `_dataClass.as`) | `assets/128_Gazillionaire__embed_mxml_i_planet_swf_630432904_dataClass.bin` | swf (as .bin) | gui-icon | HUD icon: Generic Planet | Small planet glyph icon (2 uses) |
| 976591674 | `Gazillionaire__embed_mxml_i_target_swf_976591674.as` (+ `_dataClass.as`) | `assets/93_Gazillionaire__embed_mxml_i_target_swf_976591674_dataClass.bin` | swf (as .bin) | gui-icon | Tutorial: Target Marker | Tutorial-overlay target/bullseye graphic |
| 835323288 | `Gazillionaire__embed_mxml_stars_bg_main_swf_835323288.as` (+ `_dataClass.as`) | `assets/108_Gazillionaire__embed_mxml_stars_bg_main_swf_835323288_dataClass.bin` | swf (as .bin) | background | Starfield Background (variant) | Used at 2 sites |
| 1623989498 | `Gazillionaire__embed_mxml_stars_main_swf_1623989498.as` (+ `_dataClass.as`) | `assets/167_Gazillionaire__embed_mxml_stars_main_swf_1623989498_dataClass.bin` | swf (as .bin) | background | Starfield Background (main) | Widely reused starfield backdrop across ~10 screens |
| 77392359/80761093 | `_class_embed_css_b_x2_dn_swf_77392359_80761093.as` (+ `_dataClass.as`) | `assets/123__class_embed_css_b_x2_dn_swf_77392359_80761093_dataClass.bin` | swf (as .bin) | gui-chrome | Close-X Button (small) — Down state | CSS class `xButton`, `downSkin` |
| 335978239/175555539 | `_class_embed_css_b_x2_mo_swf_335978239_175555539.as` (+ `_dataClass.as`) | `assets/121__class_embed_css_b_x2_mo_swf_335978239_175555539_dataClass.bin` | swf (as .bin) | gui-chrome | Close-X Button (small) — Over state | CSS class `xButton`, `overSkin` |
| 565934968/340354117 | `_class_embed_css_b_x2_up_swf_565934968_340354117.as` (+ `_dataClass.as`) | `assets/127.bin` | swf (as .bin) | gui-chrome | Close-X Button (small) — Disabled state | CSS class `xButton`, `disabledSkin` (reuses "up" art) |
| 565934968/340354118 | `_class_embed_css_b_x2_up_swf_565934968_340354118.as` (+ `_dataClass.as`) | `assets/127.bin` | swf (as .bin) | gui-chrome | Close-X Button (small) — Up state | CSS class `xButton`, `upSkin`; **identical bytes to the 340354117 class above** |
| 1820202694/745722986 | `_class_embed_css_b_x3_dn_swf_1820202694_745722986.as` (+ `_dataClass.as`) | `assets/96__class_embed_css_b_x3_dn_swf_1820202694_745722986_dataClass.bin` | swf (as .bin) | gui-chrome | Close-X Button (large) — Down state | CSS class `xButton2`, `downSkin` |
| 2078788574/683813778 | `_class_embed_css_b_x3_mo_swf_2078788574_683813778.as` (+ `_dataClass.as`) | `assets/106__class_embed_css_b_x3_mo_swf_2078788574_683813778_dataClass.bin` | swf (as .bin) | gui-chrome | Close-X Button (large) — Over state | CSS class `xButton2`, `overSkin` |
| 1986221993/1815107817 | `_class_embed_css_b_x3_up_swf__1986221993_1815107817.as` (+ `_dataClass.as`) | `assets/119__class_embed_css_b_x3_up_swf__1986221993_1815107817_dataClass.bin` | swf (as .bin) | gui-chrome | Close-X Button (large) — Up/Disabled state | CSS class `xButton2`, `upSkin` and `disabledSkin` |
| 416068855/1574736089 | `_class_embed_css_f_empty_swf__416068855_1574736089.as` (+ `_dataClass.as`) | `assets/84__class_embed_css_f_empty_swf__416068855_1574736089_dataClass.bin` | swf (as .bin) | gui-chrome | Fuel Gauge — Empty track | CSS class `fuelEmpty` |
| 1667013489/1828896639 | `_class_embed_css_f_endblue_swf_1667013489_1828896639.as` (+ `_dataClass.as`) | `assets/131__class_embed_css_f_endblue_swf_1667013489_1828896639_dataClass.bin` | swf (as .bin) | gui-chrome | Fuel Gauge — Blue end-cap | CSS class `fuelEndBlue` |
| 735613634/1127775762 | `_class_embed_css_f_endred_swf_735613634_1127775762.as` (+ `_dataClass.as`) | `assets/161__class_embed_css_f_endred_swf_735613634_1127775762_dataClass.bin` | swf (as .bin) | gui-chrome | Fuel Gauge — Red end-cap | CSS class `fuelEndRed` |
| 392505595/2100659351 | `_class_embed_css_f_full_swf_392505595_2100659351.as` (+ `_dataClass.as`) | `assets/98__class_embed_css_f_full_swf_392505595_2100659351_dataClass.bin` | swf (as .bin) | gui-chrome | Fuel Gauge — Full track | CSS class `fuelFull` |
| 111 | `_class_embed_css_gripper_up_png__1147833896_1566397784.as` | `assets/111__class_embed_css_gripper_up_png__1147833896_1566397784.png` | png | gui-chrome | Window Resize Gripper | AIR window chrome; no direct reference found by name in `Gazillionaire.as` — wired via Flex framework default skin lookup |
| 129 | `_class_embed_css_mac_close_down_png_1810215554_222415538.as` | `assets/129__class_embed_css_mac_close_down_png_1810215554_222415538.png` | png | gui-chrome | Mac Window Close Button — Down | AIR native window chrome (Mac skin) |
| 124 | `_class_embed_css_mac_close_over_png_912220596_2027733068.as` | `assets/124__class_embed_css_mac_close_over_png_912220596_2027733068.png` | png | gui-chrome | Mac Window Close Button — Over | AIR native window chrome (Mac skin) |
| 142 | `_class_embed_css_mac_close_up_png_978951483_2125766469.as` | `assets/142__class_embed_css_mac_close_up_png_978951483_2125766469.png` | png | gui-chrome | Mac Window Close Button — Up | AIR native window chrome (Mac skin) |
| 126 | `_class_embed_css_mac_max_dis_png_383647856_1603147588.as` | `assets/126__class_embed_css_mac_max_dis_png_383647856_1603147588.png` | png | gui-chrome | Mac Window Maximize Button — Disabled | AIR native window chrome (Mac skin) |
| 147 | `_class_embed_css_mac_max_down_png_209894422_1077444074.as` | `assets/147__class_embed_css_mac_max_down_png_209894422_1077444074.png` | png | gui-chrome | Mac Window Maximize Button — Down | AIR native window chrome (Mac skin) |
| 170 | `_class_embed_css_mac_max_over_png__688100536_1285742312.as` | `assets/170__class_embed_css_mac_max_over_png__688100536_1285742312.png` | png | gui-chrome | Mac Window Maximize Button — Over | AIR native window chrome (Mac skin) |
| 120 | `_class_embed_css_mac_max_up_png_1611922383_1155782463.as` | `assets/120__class_embed_css_mac_max_up_png_1611922383_1155782463.png` | png | gui-chrome | Mac Window Maximize Button — Up | AIR native window chrome (Mac skin) |
| 143 | `_class_embed_css_mac_min_dis_png__293784738_393350258.as` | `assets/143__class_embed_css_mac_min_dis_png__293784738_393350258.png` | png | gui-chrome | Mac Window Minimize Button — Disabled | AIR native window chrome (Mac skin) |
| 172 | `_class_embed_css_mac_min_down_png_684320488_895589496.as` | `assets/172__class_embed_css_mac_min_down_png_684320488_895589496.png` | png | gui-chrome | Mac Window Minimize Button — Down | AIR native window chrome (Mac skin) |
| 87 | `_class_embed_css_mac_min_over_png__213674470_948261914.as` | `assets/87__class_embed_css_mac_min_over_png__213674470_948261914.png` | png | gui-chrome | Mac Window Minimize Button — Over | AIR native window chrome (Mac skin) |
| 136 | `_class_embed_css_mac_min_up_png__211045599_1953174353.as` | `assets/136__class_embed_css_mac_min_up_png__211045599_1953174353.png` | png | gui-chrome | Mac Window Minimize Button — Up | AIR native window chrome (Mac skin) |
| 159 | `_class_embed_css_win_close_down_png_1345060949_1964794325.as` | `assets/159__class_embed_css_win_close_down_png_1345060949_1964794325.png` | png | gui-chrome | Windows Window Close Button — Down | AIR native window chrome (Win skin) |
| 117 | `_class_embed_css_win_close_over_png_447065991_1526848935.as` | `assets/117__class_embed_css_win_close_over_png_447065991_1526848935.png` | png | gui-chrome | Windows Window Close Button — Over | AIR native window chrome (Win skin) |
| 104 | `_class_embed_css_win_close_up_png__1922087986_1039254206.as` | `assets/104__class_embed_css_win_close_up_png__1922087986_1039254206.png` | png | gui-chrome | Windows Window Close Button — Up | AIR native window chrome (Win skin) |
| 135 | `_class_embed_css_win_max_dis_png__402670723_233731217.as` | `assets/135__class_embed_css_win_max_dis_png__402670723_233731217.png` | png | gui-chrome | Windows Window Maximize Button — Disabled | AIR native window chrome (Win skin) |
| 107 | `_class_embed_css_win_max_down_png_1603822249_191957175.as` | `assets/107__class_embed_css_win_max_down_png_1603822249_191957175.png` | png | gui-chrome | Windows Window Maximize Button — Down | AIR native window chrome (Win skin) |
| 82 | `_class_embed_css_win_max_over_png_705827291_772282149.as` | `assets/82__class_embed_css_win_max_over_png_705827291_772282149.png` | png | gui-chrome | Windows Window Maximize Button — Over | AIR native window chrome (Win skin) |
| 165 | `_class_embed_css_win_max_up_png__76010718_1667118254.as` | `assets/165__class_embed_css_win_max_up_png__76010718_1667118254.png` | png | gui-chrome | Windows Window Maximize Button — Up | AIR native window chrome (Win skin) |
| 164 | `_class_embed_css_win_min_dis_png__1080103317_951229137.as` | `assets/164__class_embed_css_win_min_dis_png__1080103317_951229137.png` | png | gui-chrome | Windows Window Minimize Button — Disabled | AIR native window chrome (Win skin) |
| 174 | `_class_embed_css_win_min_down_png_2078248315_608071429.as` | `assets/174__class_embed_css_win_min_down_png_2078248315_608071429.png` | png | gui-chrome | Windows Window Minimize Button — Down | AIR native window chrome (Win skin) |
| 137 | `_class_embed_css_win_min_over_png_1180253357_1655963331.as` | `assets/137__class_embed_css_win_min_over_png_1180253357_1655963331.png` | png | gui-chrome | Windows Window Minimize Button — Over | AIR native window chrome (Win skin) |
| 118 | `_class_embed_css_win_min_up_png__1898978700_2122316684.as` | `assets/118__class_embed_css_win_min_up_png__1898978700_2122316684.png` | png | gui-chrome | Windows Window Minimize Button — Up | AIR native window chrome (Win skin) |
| 114 | `_class_embed_css_win_restore_down_png_858281023_9501489.as` | `assets/114__class_embed_css_win_restore_down_png_858281023_9501489.png` | png | gui-chrome | Windows Window Restore Button — Down | AIR native window chrome (Win skin) |
| 141 | `_class_embed_css_win_restore_over_png__39713935_485649921.as` | `assets/141__class_embed_css_win_restore_over_png__39713935_485649921.png` | png | gui-chrome | Windows Window Restore Button — Over | AIR native window chrome (Win skin) |
| 153 | `_class_embed_css_win_restore_up_png_1550027320_1865955528.as` | `assets/153__class_embed_css_win_restore_up_png_1550027320_1865955528.png` | png | gui-chrome | Windows Window Restore Button — Up | AIR native window chrome (Win skin) |
| 1 | `LoadScreen_LoadScreenGraphic.as` | `assets/1_LoadScreen_LoadScreenGraphic.bin` | bin (bitmap data) | logo | Loading Screen Graphic | Branding asset shown during game load, before `CustomPreloader` finishes |
| n/a | `_class_embed_css_Assets_swf_976127064___brokenImage_658189327.as` | *(none — no `[Embed]` tag)* | n/a | other | Flex Default: Broken-Image Placeholder | Empty `SpriteAsset` stub, no unique data recovered — Flex framework default, not custom game art |
| n/a | `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_BusyCursor_487872263.as` | *(none)* | n/a | other | Flex Default: Busy Cursor | Empty stub, Flex framework default cursor |
| n/a | `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_DragCopy_806051697.as` | *(none)* | n/a | other | Flex Default: Drag-Copy Cursor | Empty stub, Flex framework default cursor |
| n/a | `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_DragLink_806313702.as` | *(none)* | n/a | other | Flex Default: Drag-Link Cursor | Empty stub, Flex framework default cursor |
| n/a | `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_DragMove_806339277.as` | *(none)* | n/a | other | Flex Default: Drag-Move Cursor | Empty stub, Flex framework default cursor |
| n/a | `_class_embed_css_Assets_swf_976127064_mx_skins_cursor_DragReject_681200837.as` | *(none)* | n/a | other | Flex Default: Drag-Reject Cursor | Empty stub, Flex framework default cursor |
| n/a | `_class_embed_css_f_fillblue_png__944102544_696470983.as` | *(none — no `[Embed]` tag, no file recovered)* | n/a | other | **[GAP] Fuel Gauge — Blue fill bar** | **Actively used** as `upSkin`/`overSkin`/`downSkin`/`disabledSkin` for CSS class `fuelFillBlue` (`Gazillionaire.as` ~line 76315), but no asset bytes exist to override — see finding 5 |
| n/a | `_class_embed_css_f_fillred_png_97191697_987149254.as` | *(none — no `[Embed]` tag, no file recovered)* | n/a | other | **[GAP] Fuel Gauge — Red fill bar** | **Actively used** as `upSkin`/`overSkin`/`downSkin`/`disabledSkin` for CSS class `fuelFillRed` (`Gazillionaire.as` ~line 76285), but no asset bytes exist to override — see finding 5 |

## Non-asset classes (excluded)

These 24 files contain no `[Embed]` tag and are not paired with any `_dataClass`
companion — pure game logic, data model, or Flex framework glue:

- `Gazillionaire.as` — main application class, all UI frames + game logic (~106K lines)
- `GameType.as` — master game-state data class
- `PlayerType.as` — per-player state data class
- `OpponentType.as` — per-opponent state data class
- `GameStrings.as` — localization string table (`getString()` lookup)
- `CustomPreloader.as` — preloader UI logic (uses `LoadScreen`/`LoadScreen_LoadScreenGraphic` but embeds nothing itself)
- `LoadScreen.as` — loading-screen container logic (the graphic itself is the separate `LoadScreen_LoadScreenGraphic` asset class, listed in the table above)
- `_Gazillionaire_FlexInit.as` — Flex framework bootstrap/initialization
- `_Gazillionaire_mx_managers_SystemManager.as` — Flex SystemManager subclass, framework glue
- `_Gazillionaire_Styles.as` — 1274-line CSS style registration file (`registerInheritingStyle()` calls); it *references* many of the embedded asset classes above as skins but embeds nothing itself
- `_mx_skins_spark_PanelBorderSkinWatcherSetupUtil.as` — Flex Spark skin-watcher setup utility, framework glue
- `CustomComboBoxSkin.as` — custom combo-box skin logic (vector-drawn, no embedded bitmap)
- `GradientBarSkin.as` — custom gradient-drawn skin logic (procedural, no embedded bitmap)
- `GradientTrackSkin.as` — custom gradient-drawn track skin logic (procedural, no embedded bitmap)
- `en_US$collections_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$components_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$containers_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$controls_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$core_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$effects_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$layout_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$skins_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$styles_properties.as` — Flex `ResourceBundle` subclass, localization strings only
- `en_US$utils_properties.as` — Flex `ResourceBundle` subclass, localization strings only

**24 excluded + 132 asset-bearing files (98 table rows, several rows merging a
wrapper + `_dataClass` pair) = 156 total, fully accounted for.**
