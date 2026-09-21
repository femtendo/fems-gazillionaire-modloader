# Asset wiki plan

Goal: a modder can look up any planet, GUI icon, background, logo, or chrome
element by name, find its file under `engine/src/assets/`, and override it
per `docs/modding-guide.md` — without spelunking `engine/src/*.as` first.

## What's already true (no plan needed)

The modloader's asset-override mechanism already reaches every asset that
exists as a file: `mods/<mod>/assets/<same-relative-path>` overlays
`engine/src/assets/<file>` 1:1 (`tools/modloader/build.js`), validated
against `mod.json`'s `touches.assets`. This was verified exhaustively —
`docs/asset-inventory.md` walks all 156 `engine/src/*.as` files (132
asset-bearing, 98 merged rows) and confirms every embedded asset resolves to
a standalone file, not a symbol packed inside a shared library SWF. **The
gap isn't loader capability — it's that a modder can't find or name what
they're looking at**, since ~2/3 of classes carry obfuscated decompiler
names (`_class_embed_css_win_max_up_png__76010718_1667118254`) instead of
descriptive ones.

## Step 1 — Publish the wiki (no code changes)

`docs/asset-inventory.md` (already written) is 90% of the wiki content: ID,
class, file path, category, plain-English name, in-game usage note. Turn it
into the wiki proper:

1. Rename/restructure it as `docs/asset-wiki.md`, grouped by category
   (Planets, HUD Icons, Backgrounds, GUI Chrome, Logo) instead of one flat
   table — a modder thinks "I want to change the fuel icon," not "row 34."
2. Add a one-line "how to override this" snippet per entry, e.g.:
   `mods/your-mod/assets/158_Gazillionaire__embed_mxml_i_money_png_204001112.png`
   overrides the Cash/Money HUD icon.
3. Link it from `docs/modding-guide.md`'s `assets/` section ("see
   docs/asset-wiki.md for the full named list of every overridable asset").
4. Fix `docs/architecture.md`'s planet count (says 12, actual is 14 — Vexx,
   Pyke, Mira, Stye, Loro, Zile, Frac, Tilo, Queg, Xeen, Ooom, Hork, Bass,
   Nosh per `GameStrings.as`).

No renaming of the actual `.as` classes — the wiki is a lookup layer over
the existing file paths, not a repo restructure. Renaming 90+ obfuscated
classes for cosmetic reasons risks breaking the build for no functional
gain; skip it.

## Step 2 — Close the two real coverage gaps

These are the only assets a modder *can't* currently reach via `assets/`
override, and both need an engine change, not a wiki entry:

1. **Fuel gauge fill bars** (`fuelFillBlue` / `fuelFillRed`, wired at
   `Gazillionaire.as` ~line 76285–76315). No `[Embed]`, no file — lost in
   decompilation even though the CSS classes actively reference them as
   `upSkin`/`overSkin`/`downSkin`/`disabledSkin`. Fix: re-run the JPEXS
   export pass (`docs/known-issues.md` has the working invocation) targeting
   just these two symbols from the original SWF, wire them up as real
   `[Embed]`-backed classes the same way every other fuel-gauge state
   already is, and add the two new files to `engine/src/assets/`.
2. **Ship art** — doesn't exist to lose. If "moddable ships" matters to the
   project, this needs a real feature: add an `icon`/skin property to the
   12 `frm_ChooseShip_ship_N` Button descriptors in `Gazillionaire.as`,
   backed by a new per-ship `[Embed]` asset class (`Ship1Class` .. `Ship12Class`)
   following the existing planet-class pattern, so a mod can then override
   `assets/ship_N.png` like anything else. This is new functionality, not a
   bug fix — worth a separate go/no-go decision before building it, since
   it's a `Gazillionaire.as` change (multiplayer-conflict surface) for art
   the original game never had per-ship.

## Step 3 — Keep the wiki honest going forward

Add one CI-ish check (or just a documented habit) so the wiki doesn't rot:
whenever `engine/src/assets/` gains or loses a file, `docs/asset-wiki.md`
gets a matching row. Given the asset set is fixed (decompiled from one
original SWF, only grows if Step 2's fuel-bar re-export or new ship-art
feature lands), this is a rare, manual edit — no tooling needed.

## Priority

1. Step 1 (wiki publish) — do first, zero risk, unblocks every modder today.
2. Step 2.1 (fuel bar re-export) — small, mechanical, fixes a real visible
   gap.
3. Step 2.2 (ship art) — only if the project actually wants moddable ships;
   confirm before building, since it touches `Gazillionaire.as` and the
   multiplayer-conflict rule in `docs/modding-guide.md`.
