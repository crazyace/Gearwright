# Gearwright roadmap

Built around Forever's published schedule: beta to **Oct 22** (level 30 cap),
launch **Nov 4**, first raids **Dec 9**, major update **Spring 2027**.

## Phase 0 - Beta reconnaissance (Oct 3 - Oct 22)

Goal: replace every "unconfirmed" in the code with a fact. Data first, features later.

- [ ] Run `GearwrightProbe` on a beta Rogue; commit captures to `data/probe/`
- [ ] Confirm interface number; fix both `.toc` files
- [ ] **Talent API**: Classic (`GetTalentInfo`) or Traits (`C_Traits`)? Readable or secret?
- [ ] **Stat units**: do items report hit/crit/expertise/haste as ratings or "Equip: +x%"?
      Record every `ITEM_MOD_*` token -> update `Data/Stats.lua`
- [ ] **Secret values**: which item/character-stat calls are blocked?
- [ ] **SavedVariables**: do they survive a relog? (probe reports on login)
- [ ] Dump all three Rogue talent trees (names, ranks, tiers) -> `Data/ROGUE/Talents`
- [ ] Open Enchanting / a trainer to record recipes and enchant IDs
- [ ] Inspect other Rogues (`/gwp inspect`) to collect real gear + enchant IDs
- [ ] Decide: key talents/enchants by name or by ID

Exit criteria: `docs/BETA-FINDINGS.md` answers every question above.

## Phase 1 - MVP for launch (Oct 22 - Nov 4)

Goal: a Rogue can install Gearwright on day one and get useful advice.

- [ ] Implement whichever talent reader Phase 0 says is right (`Core/API.lua`)
- [ ] Spec detection verified on all three specs
- [ ] First-pass stat weights per spec (clearly labelled as early)
- [ ] One recommended build per spec (raid DPS)
- [ ] Enchant list for the levelling/early-60 game
- [ ] Tooltip upgrade line verified on weapons, rings, trinkets
- [ ] Packaging: `.pkgmeta` + GitHub Action release to CurseForge and Wago
- [ ] CurseForge page: screenshots, "provisional data" disclaimer

## Phase 2 - Raid tier 1 (Nov 4 - Dec 9)

- [ ] Refine weights from launch-week feedback and logs
- [ ] Real UI: per-slot list, "why" breakdown (`Scoring.Breakdown`), talent tree view
- [ ] Weapon logic: daggers for Mutilate/Hemorrhage, main-hand vs off-hand speed
- [ ] Gear source tagging (dungeon / quest / crafted / raid)
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
