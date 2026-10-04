# Gearwright roadmap

Built around Forever's published schedule: beta to **Oct 22** (level 30 cap),
launch **Nov 4**, first raids **Dec 9**, major update **Spring 2027**.

## Phase 0 - Beta reconnaissance (Oct 3 - Oct 22)

Goal: replace every "unconfirmed" in the code with a fact. Data first, features later.

- [x] Run `GearwrightProbe` on a beta Rogue; commit captures to `data/probe/`
- [x] Confirm interface number; fix both `.toc` files (16001, client 1.60.1)
- [x] **Talent API**: Classic (`GetTalentInfo`) or Traits (`C_Traits`)? Readable or secret? (Traits, readable)
- [ ] **Stat units**: do items report hit/crit/expertise/haste as ratings or "Equip: +x%"?
      Record every `ITEM_MOD_*` token -> update `Data/Stats.lua`
- [x] **Secret values**: which item/character-stat calls are blocked? (none so far)
- [x] **SavedVariables**: do they survive a relog? (yes)
- [x] Dump all three Rogue talent trees (names, ranks, tiers) -> `docs/BETA-FINDINGS.md`
- [x] Open Enchanting to record recipes and their effects; class and profession trainers
- [x] Encounter Journal: empty on Forever, so loot tables come from the probe's loot log
- [ ] Inspect other Rogues (`/gwp inspect`) to collect real gear + enchant IDs
- [ ] Decide: key talents/enchants by name or by ID

Exit criteria: `docs/BETA-FINDINGS.md` answers every question above.

## Phase 1 - MVP for launch (Oct 22 - Nov 4)

Goal: a Rogue can install Gearwright on day one and get useful advice.

- [x] Implement whichever talent reader Phase 0 says is right (`Core/API.lua`: Traits)
- [ ] Spec detection verified on all three specs
- [x] First-pass stat weights per spec (clearly labelled as early; AP equivalents, scaled by level)
- [x] Skip items the class can't use; spec weapon rules (daggers for Assassination)
- [x] Quest reward pick and loot/roll upgrade messages
- [x] Crafted upgrades from every scanned profession, yours or not: craft it, learn it, or have it
      crafted (`Data/Crafted.lua` from `tools/crafted_from_probe.py`; Crafting tab)
- [x] Crafting knows your other characters' recipes ("Smithy can craft it")
- [x] Weapon skills: untrained weapons say where to train them; weapon masters pinned on the map
- [x] Weapon skill levels: warn while a trained skill is low (read from the sheet's weapon tooltips)
- [ ] Score low-skill weapons lower (Classic miss chance from skill vs. target defense)
- [ ] Check the weapon masters' positions on Forever (Gearwright saves them when you visit one)
- [x] Train reminder: new class spells on level-up, untrained ones at login, /gearwright spells
- [x] Trainer spells below level 20 (checked on Wowhead: `data/verified/rogue-trainer-low-levels.json`)
- [ ] Trainer costs (the probe records them at the next trainer visit)
- [x] Training tab (class spells, weapon skills)
- [x] Gear tab overview: each slot with its best known upgrade and where to get it
- [x] Settings tab (tooltip, chat messages, spec, look-ahead, map pins, debug) + AddOns settings entry
- [x] Next-goal button (minimap / LibDataBroker) and a per-character wishlist
- [ ] Engineering recipes (needs a probe scan from an engineer)
- [x] Probe: auction house full scan (`/gwp ah`) for gear stats and prices in bulk
- [ ] Auction house upgrades in Gearwright itself: gear on the AH that beats yours, with prices
- [x] Advice before level 10 (no talent points yet): scored as the leveling spec, Combat
- [ ] Bag scan for upgrades you're carrying
- [ ] One recommended build per spec (raid DPS)
- [x] Enchant advice: best stat enchant per slot, scored with the spec weights
- [ ] Score proc enchants (Crusader, Fiery Weapon)
- [ ] Tooltip upgrade line verified on weapons, rings, trinkets
- [ ] Packaging: `.pkgmeta` + GitHub Action release to CurseForge and Wago
- [ ] CurseForge page: screenshots, "provisional data" disclaimer

## Priest

- [x] Priest data for Discipline, Holy and Shadow (`Data/Priest/`, Classic values): cloth,
      maces/staves/daggers/wands, orbs in the off hand, caster weights in healing / spell damage
- [x] Spec groups worked out from the talent tree's layout when a class has none yet
- [ ] Priest talent capture: spec groups, talent names, builds (`docs/BETA-CHECKLIST.md`)
- [ ] Priest trainer capture -> `Data/Priest/Trainer.lua`
- [ ] Measure Intellect per spell crit and check the caster weights in game

## Phase 2 - Raid tier 1 (Nov 4 - Dec 9)

- [ ] Refine weights from launch-week feedback and logs
- [x] Real UI: tabbed window with item rows, icons and tooltips (UI/Theme.lua, UI/MainFrame.lua)
- [ ] "Why" breakdown per item (`Scoring.Breakdown`), talent tree view
- [ ] Weapon logic: daggers for Mutilate/Hemorrhage, main-hand vs off-hand speed
- [x] Dungeon upgrades: own loot table from the probe's loot log, plus Forever Dungeon Journal's
      tables when installed (read at runtime, optional dependency)
- [x] Ask Exehn (Forever Dungeon Journal) about using his data: yes, with credit (2026-10-04)
- [ ] Offer Exehn Gearwright's probe findings (loot logs, quest rewards) for his addon
- [ ] Raid and quest-hub sources
- [ ] Raid gear + enchants for Barrow Deeps, Hyjal Summit, Onyxia's Lair (Dec 9)
- [ ] Multiple builds per spec (raid, dungeon, PvP)
- [ ] Localization groundwork (IDs instead of English names)

## Phase 3 - Grow (2027)

- [ ] Second class (pick by demand; Warrior shares most of the melee engine)
- [ ] PvP weights (beta shows reduced crit damage vs players)
- [ ] Spring 2027 raid content
- [ ] Optional: Legacy-tree suggestions

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-10-03 | Name: Gearwright | No CurseForge collisions; "Quartermaster" taken 4x |
| 2026-10-03 | Rogue first | One class, three distinct specs, big Forever talent changes |
| 2026-10-03 | Mainline API, not Classic | Forever uses Mainline 12.1.5 UI + Midnight restrictions |
| 2026-10-03 | All WoW reads in `Core/API.lua` | API is unconfirmed; fix it in one place |
| 2026-10-03 | Engine is pure Lua | Testable offline with `tests/smoke_test.py` |
| 2026-10-03 | Interface 16001 | Confirmed on beta client 1.60.1 (70205). Classic-style number; whether the APIs are Mainline or Classic is still for the probe to answer |
| 2026-10-03 | Read talents via Traits API, spec by group ID | Probe: Classic talent API absent; one tree, each node tagged 11580/11573/11572 |
| 2026-10-03 | Read Forever Dungeon Journal at runtime, don't copy it | It has no license file; its data stays its author's. Gearwright builds its own table from observed drops |
| 2026-10-03 | Drop the Encounter Journal; log real drops | `LoadAddOn("Blizzard_EncounterJournal")` = WRONG_GAME_TYPE, no instance answers |
| 2026-10-03 | Score enchants instead of listing them per spec | Recipe descriptions give exact amounts; one table serves every class and spec |
