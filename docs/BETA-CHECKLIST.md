# Beta session checklist

Run on a **Rogue** in the Forever beta. Commit every capture to `data/probe/`.

## Each session

1. Log in. Note the probe's login line: *SavedVariables OK* or *nothing from a previous session*.
   - Second session onward, "nothing" means the beta is dropping SavedVariables. Use export.
2. Open your character sheet (C) once, so the probe records every stat line and tooltip.
3. `/gwp all`
4. `/gwp export` -> Ctrl+A, Ctrl+C -> paste into `data/probe/YYYY-MM-DD-<spec>.json`
5. `python tools/probe_to_json.py data/probe/<file>.json` and skim the summary.

## Once each

- [x] Fresh level-10 Rogue with talents in **Assassination** -> `/gwp all`
- [ ] Respec into **Combat** -> `/gwp talents`
- [ ] Respec into **Subtlety** -> `/gwp talents`
- [ ] Equip an item with an "Equip: +x% hit/crit" line -> `/gwp gear` (stat units)
- [ ] Equip something with Expertise and Haste if you find it -> `/gwp gear`
- [ ] Open your **class trainer** (recorded automatically)
- [ ] Open **Enchanting** on any character (recorded automatically)
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
