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
- [ ] Run a dungeon with the probe loaded: every loot window is logged with what dropped it
- [ ] Open both your professions once, then check `/gearwright` -> Crafting and Enchants
- [ ] On an engineer (any character): open Engineering with the probe loaded
- [ ] At the auction house: `/gwp ah` and keep the window open until it says done (once per
      15 minutes, server rule). Send the SavedVariables file (`WTF/Account/<ACCOUNT>/SavedVariables/
      GearwrightProbe.lua`, after `/reload` or logout), or `/gwp export ah` if it's small enough
- [ ] Visit a weapon master (Woo Ping in Stormwind, Buliwyf Stonehand in Ironforge) with the
      probe loaded: records where it really is and what it teaches
- [ ] Target another Rogue -> `/gwp inspect`
- [ ] Hover items with **Gearwright** loaded: does the tooltip line appear?
- [ ] Open `/gearwright`: does spec detection match what you specced?

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
