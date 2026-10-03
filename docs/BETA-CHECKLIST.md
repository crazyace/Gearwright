# Beta session checklist

Run on a **Rogue** in the Forever beta. Commit every capture to `data/probe/`.

## Each session

1. Log in. Note the probe's login line: *SavedVariables OK* or *nothing from a previous session*.
   - Second session onward, "nothing" means the beta is dropping SavedVariables. Use export.
2. `/gwp all`
3. `/gwp export` -> Ctrl+A, Ctrl+C -> paste into `data/probe/YYYY-MM-DD-<spec>.json`
4. `python tools/probe_to_json.py data/probe/<file>.json` and skim the summary.

## Once each

- [ ] Fresh level-10 Rogue with talents in **Assassination** -> `/gwp all`
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
| Interface number | | |
| Talent API (classic / traits / none) | | |
| Talent ranks readable or secret? | | |
| Item stat tokens seen | | |
| Hit/crit units (rating or %) | | |
| Which stat calls are secret? | | |
| SavedVariables persist? | | |
| Tab order: Assassination / Combat / Subtlety? | | |
