# Beta session checklist

Run on a **Rogue** in the Forever beta. Commit every capture to `data/probe/`.

## Each session

1. Log in. Note the probe's login line: *SavedVariables OK* or *nothing from a previous session*.
   - Second session onward, "nothing" means the beta is dropping SavedVariables. Use export.
2. Expand every category on your character sheet once (C). `/gwp all` opens the sheet itself to read it.
3. `/gwp all`
4. `/gwp export` -> Ctrl+A, Ctrl+C -> paste into `data/probe/YYYY-MM-DD-<spec>.json`
5. `python tools/probe_to_json.py data/probe/<file>.json` and skim the summary.

## Once each

- [x] Fresh level-10 Rogue with talents in **Assassination** -> `/gwp all`
- [ ] Respec into **Combat** -> `/gwp talents`
- [ ] Respec into **Subtlety** -> `/gwp talents`
- [x] `/gwp items` -> reads six reference items by ID (hit, crit, haste/expertise gear) without
      owning them. Settles the stat units. `/gwp items 1234 5678` reads any other IDs.
- [ ] Equip an item with an "Equip: +x% hit/crit" line -> `/gwp gear` (confirms what equipping changes)
- [x] Open your **class trainer** (recorded automatically)
- [x] Open **Enchanting** on any character (recorded automatically)
- [ ] Open both your professions once, then check `/gearwright` -> Crafting and Enchants
- [ ] On an engineer (any character): open Engineering with the probe loaded
- [ ] At the auction house: `/gwp ah` and keep the window open until it says done (once per
      15 minutes, server rule). Send the SavedVariables file (`WTF/Account/<ACCOUNT>/SavedVariables/
      GearwrightProbe.lua`, after `/reload` or logout), or `/gwp export ah` if it's small enough
- [ ] Target another Rogue -> `/gwp inspect`
- [ ] Hover items with **Gearwright** loaded: does the tooltip line appear?
- [ ] Open `/gearwright`: does spec detection match what you specced?

## Priest

Gearwright's Priest data (`Data/Priest/`) is Classic's, untested on Forever. On a Priest:

- [x] Spend a talent point, then `/gwp talents` -> `data/probe/2026-10-04-priest.json`
      (spec groups 11608 / 11615 / 11622, every talent name)
- [ ] `/gearwright`: does the window's spec match what you specced?
- [x] `/gwp all` with some Intellect gear on: 9.6 Intellect per 1% spell crit at level 12
- [ ] Can a Priest equip staves and daggers? (maces and wands: yes)
- [ ] `/gwp items <id>` on an item with "chance to hit with spells" or "critical strike with
      spells": confirms the spell hit/crit tokens

## Consumables

`Data/Consumables.lua` has Classic's effects and levels. On any character with the probe loaded (then
`/gwp export` into `data/probe/`):

- [ ] `/gwp items 2862 2863 2871 7964 3239 3240 3241 7965 20744 20746 20745` -> stones and oils:
      effect and required level
- [ ] `/gwp items 6947 6949 2892 2457 3390 8949 2454 3391 3383 6373 17708` -> poisons and elixirs
- [ ] `/gwp items 118 858 929 1710 2455 3385 3827 6149` -> healing and mana potions
- [ ] Open **Alchemy** on any character (recorded automatically): are elixirs and mana potions
      still Alchemy? (healing potions are First Aid on Forever)
- [ ] Put a stone or poison on a weapon, then `/gearwright` -> Consumables: does it say
      "applied, N min left"?
- [ ] Rogue: is Instant Poison's proc chance still 20% and Deadly Poison's 30%?

## Stat model

See `docs/STAT-MODEL.md`. On any character with the probe loaded:

- [ ] `/gwp talents` with points in Mental Strength, Meditation, Spiritual Guidance or
      Lethality: is each talent's text at rank 1 the per-rank amount or the whole talent?
- [ ] Equip an item with crit rating, `/gwp sheet` before and after: does spell crit go
      up as well as melee crit?
- [ ] Priest: Spirit's mana per 5 s at a second Spirit value (47 Spirit = 58 so far)
- [ ] Priest: equip a +spell damage item (not "damage and healing"): does healing go up?
- [ ] `/gwp sheet` at another level on any class: crit per Agility should match
      `Data/ClassStats.lua`

## Questions to answer in `docs/BETA-FINDINGS.md`

| Question | Answer | Capture |
|---|---|---|
| Interface number | 16001 (client 1.60.1, build 70205) | `/dump select(4, GetBuildInfo())` |
| Talent API (classic / traits / none) | traits (one tree, spec by group ID) | 2026-10-03-assassination |
| Talent ranks readable or secret? | readable | 2026-10-03-assassination |
| Item stat tokens seen | see BETA-FINDINGS.md | 2026-10-03-assassination |
| Hit/crit units (rating or %) | | |
| Which stat calls are secret? | none so far | 2026-10-03-assassination |
| SavedVariables persist? | yes | 2026-10-03 second session |
| Tab order: Assassination / Combat / Subtlety? | n/a: groups 11580 / 11573 / 11572 | 2026-10-03-assassination |
