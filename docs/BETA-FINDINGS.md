# Beta findings

What the Forever beta client actually does, from `GearwrightProbe` captures in
`data/probe/`. Each answer cites its capture.

## Client

| | Value | Capture |
|---|---|---|
| Client version / build | 1.60.1 / 70205 (Oct 2 2026) | 2026-10-03-assassination |
| Interface number | 16001 | 2026-10-03-assassination |
| `WOW_PROJECT_ID` | 18 | 2026-10-03-assassination |
| AddOns folder | `<WoW>\_classic_beta_\Interface\AddOns` | setup |

The interface number is Classic-style, but the APIs are Mainline-style: `C_Item`,
`C_TooltipInfo`, `TooltipDataProcessor`, `C_Traits`, and new-format item links
(`|cnIQ2:|Hitem:...`). The globals `GetItemStats`, `GetItemInfoInstant` and
`GetSpecialization` are gone; their `C_*` versions exist.

## Talents

**API: Traits (`C_ClassTalents` + `C_Traits`). The Classic API (`GetTalentInfo` etc.) is absent.**
Everything is readable; nothing came back as a secret value.

- One tree (`treeID` 1111, config type 4, name "Rogue") holds all three specs: 53 nodes.
- Each node has exactly one spec group ID in `groupIDs`:
  **11580 = Assassination, 11573 = Combat, 11572 = Subtlety**
  (`Data/Rogue/Specs.lua: traitTabGroups`).
- Rank: `activeRank` (also `currentRank`, `ranksPurchased`); max: `maxRanks`.
- Name: node -> `GetEntryInfo` -> `GetDefinitionInfo().spellID` -> `C_Spell.GetSpellName`.
- Level 19 had 10 points, so the first point arrives at level 10, one per level after.
- Rows are `posY` 2130, 2730, ... in steps of 600 (7 rows); specs sit in separate `posX` bands
  (Assassination 1020-2820, Combat 5020-6820, Subtlety 9080-10880).

### Rogue tree (beta 1.60.1)

Max points shown per talent. Spell IDs over 1,000,000 look new or reworked for Forever.

| Row | Assassination | Combat | Subtlety |
|---|---|---|---|
| 1 | Improved Gouge 3, Remorseless Attacks 2, Malice 5 | Improved Eviscerate 3, Improved Sinister Strike 2, Lightning Reflexes 5 | Camouflage 5, Master of Deception 3, Opportunity 2 |
| 2 | Ruthlessness 3, Murder 2, Improved Slice and Dice 3 | Puncturing Wounds 3, Deflection 3, Precision 3 | Setup 3, Elusiveness 2, Dirty Tricks 2, Improved Ambush 3 |
| 3 | Relentless Strikes 1, Improved Expose Armor 2, Lethality 5 | Endurance 2, Riposte 1, Improved Sprint 2 | Initiative 3, Ghostly Strike 1, Improved Distract 2 |
| 4 | Vile Poisons 5, Cold Blood 1, Improved Poisons 5 | Improved Kick 2, Flawless Execution 1, Dual Wield Specialization 5 | Heightened Senses 2, Premeditation 1, Serrated Blades 3 |
| 5 | Vigor 2, Mutilate 1, Improved Kidney Shot 2 | Blade Flurry 1, Hack and Slash 5 | Dirty Deeds 2, Preparation 1, Hemorrhage 1 |
| 6 | Seal Fate 5 | Weapon Expertise 2, Aggression 3 | Quietus 5, Cutthroat 5 |
| 7 | Venom 1 | Adrenaline Rush 1 | Thousand Cuts 1 |
| **Total** | 17 talents, 48 points | 17 talents, 44 points | 19 talents, 47 points |

Talents have moved between trees compared with Classic: Improved Eviscerate and
Puncturing Wounds are now Combat, Improved Gouge is now Assassination.
New or reworked IDs: Mutilate 1310707, Venom 1310703, Flawless Execution 1310711,
Thousand Cuts 1310721, Quietus 1310728, Puncturing Wounds 1224716, Dirty Tricks 1224782,
Cutthroat 462708.

The first talent point comes at **level 10**. Until a point is spent Gearwright
advises for the leveling spec (Combat for Rogues: any weapon in either hand).

**Hack and Slash** (Combat row 5, 5 ranks, 20 points in Combat) replaces Classic's
Sword and Mace Specialization. Per rank: Axe/Sword 1% chance on a melee hit to get
an extra attack; Dagger/Fist 1% crit; Mace ignores 3% of the target's armor
(screenshot, 2026-10-03). Its Axe bonus suggests Rogues can use one-handed axes
here. Gearwright allows them once Hack and Slash has a point or the One-Handed
Axes skill (spell 196) is known. The probe now records which weapon skills are
known, to confirm.

## Items and stats

- `C_Item.GetItemStats` works and returns `ITEM_MOD_*_SHORT` tokens. Seen so far:
  `AGILITY`, `STRENGTH`, `STAMINA`, `SPIRIT`, `ATTACK_POWER`, `ATTACK_POWER_VS_HUMANOID`,
  `DAMAGE_PER_SECOND`, `FROST_RESISTANCE`, plus `RESISTANCE0_NAME` (armor) and `RESISTANCE4_NAME`.
- **"Equip:" bonuses are reported twice.** Catacomb Cloak has `ITEM_MOD_ATTACK_POWER_SHORT = 3`
  and the tooltip line "Equip: +3 Attack Power." Gearwright counts the stat once.
- "Equip: +4 Attack Power against Humanoids." is a separate token and is not counted as AP.
- Enchants are **not** in `GetItemStats`; they show as an "Enchanted: ..." tooltip line.
- **Hit, crit, haste and expertise are ratings, shown on the tooltip as a fixed %.**
  Confirmed in the client with `/gwp items` (2026-10-03, items not owned;
  `data/probe/2026-10-03-items.json`):

  | Token | Rating per 1% | Seen |
  |---|---|---|
  | `ITEM_MOD_HIT_RATING_SHORT` | 10 | 3 -> 0.3%, 7 -> 0.7%, 10 -> 1.0%, 20 -> 2.0% |
  | `ITEM_MOD_CRIT_RATING_SHORT` | 14 | 14 -> 1.0% |
  | `ITEM_MOD_HASTE_RATING_SHORT` | 10 | 10 -> "attack speed and casting speed by 1.0%" |
  | `ITEM_MOD_EXPERTISE_RATING_SHORT` | 10 | 10 -> "Dodged or Parried by 1.0%" |
  | `ITEM_MOD_PARRY_RATING_SHORT` | 15 | -15 -> "Decreases your chance to Parry by 1.0%" |
  | `ITEM_MOD_DEFENSE_SKILL_RATING_SHORT` | 1 | 21 -> "Increased Defense +21" |

  The same rates Wowhead's data gives (below). The smoke test runs every one of these
  items through `Data/Stats.lua` and checks the result against its own tooltip.
  The 31 `CR_*` rating constants (Versatility, Mastery, Avoidance, ...) all read 0 so far.
- **Any item can be read by ID**, owned or not: `C_Item.GetItemInfo` (the global
  `GetItemInfo` is gone), `C_Item.GetItemStats`, `C_TooltipInfo.GetItemByID`. Data arrives
  a second or so after `C_Item.RequestLoadItemDataByID`. Mask of the Unforgiven (13404)
  never loaded; it may not be on the beta.
- New Forever gear seen: Assassin's Waistguard (272395, "Classes: Rogue", level 60,
  21 Agi / 11 Sta / 20 hit rating), Scoutmaster's Eyepatch (276105), Brawler's Leather Hood (252504).

## Character stats (level 19 Gnome Rogue, 16:58 and 17:04 captures)

All stat calls are readable. Missing: `GetCritChanceFromAgility`,
`GetSpellCritChanceFromIntellect`, `UnitDefense`, `UnitAttackBothHands`.

| Stat | Value | Notes |
|---|---|---|
| Str / Agi / Sta / Int / Spi | 33 / 66 / 56 / 26 / 29 | Agi +17, Sta +24, Spi +2 from gear |
| Health / Energy | 601 / 105 | Energy regen 10/s |
| Attack Power | 117 base, +3 from gear | Base = 2 x level + Str + Agi - 20, the Classic Rogue formula. The 16:58 capture showed +43 (a 40 AP buff was up) |
| Ranged AP | 131 (+3) | |
| Crit: melee / ranged / spell | 13.69% / 13.53% / 5.00% | |
| Dodge / Parry / Block | 17.29% / 4.92% / 0% | |
| Armor | 487 | Sheet: reduces physical damage taken by 19.46% |
| Weapon damage (unbuffed) | MH 27.6-40.6, OH 13.8-20.3 | Off-hand at 50%; speeds 1.7 / 1.7, ranged 1.9. With the 40 AP buff: MH 32.4-45.4 |

From the character sheet's Agility tooltip: **66 Agility gives 8.7% crit, so about
7.6 Agility per 1% crit at level 19** (base crit is about 5%). Agility also gives
1 AP, 2 ranged AP and 2 armor each. Classic's per-level crit conversion means this
number changes with level; captures at more levels will show the curve.

### From the character sheet (17:14 capture)

The sheet capture works: the probe scans the whole `CharacterFrame` (503 frames,
117 visible) and hovers each visible stat line. `CharacterStatsPane` is a hidden
leftover on Forever; the real stat lines are unnamed frames elsewhere in the window.

| Line | Tooltip says |
|---|---|
| Strength 33 (32+1) | +33 Attack Power (1 AP per Str) |
| Agility 66 (49+17) | 8.7% crit, +66 AP, +132 ranged AP, +132 armor, 17.4% dodge |
| Stamina 56 (32+24) | +380 Health: "every 1 Stamina adds 10 Health" |
| Intellect 26 | Raises the rate at which weapon skills improve |
| Spirit 29 (27+2) | 35 Health per 5 s out of combat, +33% while sitting |
| Energy 105 | Regenerates 10 per second |
| Main Hand | 1.70 speed, 27-41 damage, 20.0 DPS; **Daggers skill 95/95** |
| Off Hand | 13-21 damage, 10.0 DPS |
| Armor 487 | Reduces physical damage taken by 19.46% |
| Movement speed | 7.0 yd/s run, 4.7 swim, 4.5 backpedal, 2.5 walk |

**Weapon skill exists** (Classic style), so weapon-skill bonuses may matter for gear.

The beta's level cap is currently 30. (An earlier note here claimed a Free Trial cap at
19; that came from a hidden placeholder string on the level line, which the probe now ignores.)

## From Wowhead's Forever database

Wowhead has a Forever database at `wowhead.com/forever/...` (checked 2026-10-03).
It's datamined, so it can be ahead of or behind the beta client: its Catacomb Cloak
(279899) has 6 AP, 3 Stamina and 17 armor; the beta client reports 3 AP, 2 Stamina
and 15 armor, both equipped and read by ID. Treat it as a lead to confirm in game,
not as ground truth.

- **Ratings convert at a fixed rate, at every item level.** 40 leather items,
  stored rating vs tooltip text:

  | Stat | Rating per 1% | Examples |
  |---|---|---|
  | Hit | 10 | 3 -> 0.3%, 10 -> 1.0%, 20 -> 2.0% |
  | Crit | 14 | 7 -> 0.5%, 14 -> 1.0%, 21 -> 1.5%, 28 -> 2.0% |
  | Haste | 10 | "Increases your attack speed and casting speed by 1.0%" |
  | Expertise | 10 | "Reduces chance to be Dodged or Parried by 1.0%" |

  Tooltips use one decimal ("by 2.0%"), unlike Classic ("by 2%").
  Gearwright converts rating tokens to % and reads either wording (`Data/Stats.lua`).
- **Weapon rules:** Backstab and Ambush require a main-hand dagger. Mutilate (1310707,
  level 30) "attacks with both weapons" and has no dagger requirement, so Assassination
  is free in the off hand.

## Other APIs present (2026-10-03)

- Quest rewards and loot: `GetNumQuestChoices`, `GetQuestItemLink`, `GetNumLootItems`,
  `GetLootSlotLink`, `GetLootRollItemLink`.
- Encounter Journal: `EJ_SelectInstance`, `EJ_GetNumLoot` and
  `C_EncounterJournal.GetLootInfoByIndex` exist (the old `EJ_GetLootInfoByIndex` doesn't).
  **But it's empty, and can't be filled.** On 2026-10-03 `/gwp ej` found 0 tiers and
  0 instances. With the diagnostics (17:49): `LoadAddOn("Blizzard_EncounterJournal")`
  returns `WRONG_GAME_TYPE`, `EJ_GetCurrentTier` is 0, and `EJ_GetInstanceInfo` answers
  nothing for any of 20 Classic journal IDs (Deadmines 63, Wailing Caverns 240, Molten
  Core 741, Onyxia 760...). Forever ships the functions without the journal's data.
  Dungeon loot has to come from real drops instead: the probe now logs every loot
  window with the NPC (from its GUID) and the instance or zone it dropped in.

## Enchanting (another player's window, skill 225/225)

The Enchanting window listed 270 recipes (`C_TradeSkillUI`), many new for Forever
(recipe IDs over 1,200,000). Agility enchants, the ones a Rogue cares about:

| Slot | Recipes |
|---|---|
| Bracer | Minor Agility (7779), Lesser Agility (1248460), Agility (1248497 and 1217203), Greater Agility (1248500), Superior Agility (1248599) |
| Boots | Minor Agility (7867), Lesser Agility (13637), Agility (13935), Greater Agility (20023) |
| Gloves | Agility (13815), Greater Agility (20012), Superior Agility (25080), Minor Haste (13948) |
| Cloak | Minor Agility (13419), Lesser Agility (13882), Agility (1219587) |
| Necklace (new slot) | Agility (1249059) |
| Weapon | Agility (23800), Crusader (20034), Lesser/Greater/Superior Striking |
| 2H Weapon | Lesser Agility (1248510), Agility (27837) |

A second capture (2026-10-03 17:46) recorded each recipe's description, learned flag
and output item. 179 of the 261 recipes are `Enchant <slot> - <name>`; the descriptions
give exact amounts (e.g. "Permanently enchant bracers to give +9 Agility."), and
`tools/enchants_from_probe.py` turns 114 of them into `Gearwright/Data/Enchants.lua`.
The other 65 are procs (Crusader, Fiery Weapon), spell power, resistances, slayer
damage, gathering skills or movement speed, which have no stat weight yet.

Forever-specific amounts worth knowing:

- Two different "Bracer - Agility" recipes: 1248497 gives +5, 1217203 gives +9
  (the same as Superior Agility, 1248599).
- Cloak - Lesser Agility (13882) gives +3, the same as Minor Agility (13419).
- Chest - Minor Stats (13626) and Lesser Stats (13700) both give +2 to all stats.
- Living Stats (1213616): +4 all stats and +15 Nature resistance.
- Shield - Critical Strike (1220623): +1% crit.

## Professions (2026-10-03, saved in `data/probe/2026-10-03-professions.json`)

**These windows were found in game, not opened on Jeff's characters**: the skill
levels and "learned" counts below belong to whoever's profession it was. The recipe
lists (what each profession makes) are what's useful. How they were opened (a
player's link, a crafting station...) isn't recorded; the probe now records
`IsTradeSkillLinked` / `IsTradeSkillGuild` / `IsNPCCrafting` and your own
`GetProfessions` with each scan to tell.

| Profession | Skill | Recipes | Learned | Make an item |
|---|---|---|---|---|
| Tailoring | 225/225 | 471 | 97 | 471 |
| Leatherworking | 85/150 | 592 | 31 | 592 |
| Enchanting | 225/225 | 261 | 74 | 82 |
| First Aid | 83/150 | 32 | 7 | 32 |
| Cooking | 15/75 | 132 | 4 | 132 |
| Skinning | 133/150 | 3 | 1 | 3 |
| Blacksmithing | 208/225 | 507 | 91 | 507 |

- Forever allows **two primary professions**. The API only lists the open profession's
  recipes, so Gearwright saves them per character whenever a profession window opens.
- Gearwright only treats a window as yours when it isn't linked, a guild list or NPC
  crafting, and (if `GetProfessions` answers) the profession is one of yours. Any window,
  yours or not, adds to an account-wide catalog of what each profession makes.
- Crafted gear from other professions comes from the probe scans (`Data/Crafted.lua`):
  Blacksmithing, Enchanting, Leatherworking and Tailoring so far; no Engineering scan yet.
  Which professions you have comes from `GetProfessions`/`GetProfessionInfo`, if the
  client has them (the probe now records whether it does).
- `C_TradeSkillUI.GetAllRecipeIDs` lists every recipe of the profession, learned or not.
- `GetRecipeSchematic(id, false).outputItemID` gives the crafted item, so crafted gear
  can be scored like any other item (`/gearwright craft`).
- Every profession has new Forever "camp" recipes (Camp Tent, Loom, Tanning Rack,
  Basic Campfire...). They make items, not gear.
- Recipes that make an item have an empty description, or "Craft a <name>.".

## Trainers (2026-10-03)

The trainer window lists every service with its level, rank and category (`GetTrainerServiceInfo`
returns name, availability, icon, level, rank, category). A level 19 Rogue saw 85 class
services from level 20 to 60. Worth knowing for Rogue advice:

- **Poisons are trained** from level 20 (Crippling, Instant II at 28, Deadly at 30, Wound
  at 32, Mind-numbing at 24), not learned from the level 20 quest as in Classic.
- **Mutilate has trained ranks**: rank 1 comes from the talent, ranks 2-4 from the trainer
  at 40, 50 and 60.
- Kidney Shot rank 1 at 30, Blind at 34, Slice and Dice rank 2 at 42; no Hemorrhage or
  Ghostly Strike ranks (talent-only).
- The Leatherworking trainer (21 services) teaches the new Forever "Prowler's / Skulker's /
  Skirmisher's Leather Belt" family alongside the Classic patterns.

Saved with the profession scans in `data/probe/2026-10-03-professions.json`.

## Enchants

The enchant ID parses out of the item link as expected.

| Enchant ID | Tooltip | Seen on |
|---|---|---|
| 15 | Enchanted: Stamina +1 and Armor +8 | Chest, Hands |
| 8481 | Enchanted: Stamina +2 and Armor +16 | Legs, Feet |

## Secret values

`issecretvalue` and `canaccessvalue` exist. Nothing captured so far was secret:
talents, item stats, tooltips and all 14 character-stat calls returned plain values.

## SavedVariables

**They persist across sessions.** In a later session the probe's login line read
"SavedVariables OK: found data written 2026-10-03 16:49:39", and that session's export
still held the 16:36:04 snapshot from the first session next to a new 16:50:41 one.
Gearwright's settings (`GearwrightDB`) can rely on this; `/gwp export` is a convenience,
not a workaround. The second snapshot (gear only) matched the first, so it wasn't
committed as a separate capture.

## Auction house

Auctionator 340 runs on Forever with its **modern** auction house code
(`C_AuctionHouse`), not the Classic one. So Forever's AH API is Mainline's:
`C_AuctionHouse.ReplicateItems()` asks for every listing at once (allowed once per
15 minutes), `REPLICATE_ITEM_LIST_UPDATE` says it arrived, then
`GetNumReplicateItems` / `GetReplicateItemInfo(i)` / `GetReplicateItemLink(i)` (0-based)
read it. Some listings come without item data and need `RequestLoadItemDataByID` first.
Auctionator is "All Rights Reserved"; none of its code is used, only the API it shows.
First scan, 2026-10-03 18:34 (`data/probe/2026-10-03-auction.json`, tooltips trimmed to
effect lines): **109,889 listings, 5,295 distinct gear items, 1,177 other items priced.**
Every gear item had data after the probe's retries. What it shows:

- Mostly levels 10-29 (beta cap 30): required level 0-9: 1,309, 10-19: 2,823,
  20-29: 2,049, 30+: 89. Quality: 5,224 green, 505 white, 346 grey, 195 blue.
- Stat tokens seen: the six base stats, `ATTACK_POWER`, `RANGED_ATTACK_POWER`,
  `ATTACK_POWER_VS_BEAST/HUMANOID/MECHANICAL`, spell power and per-school damage,
  healing, defense, resistances, mana and health regen, fishing; `HIT_RATING` on 3
  items (3 -> 0.3%), `CRIT_RATING` and `PARRY_RATING` on Fletcher's Gloves
  (14 -> 1% crit, -15 -> "Decreases your chance to Parry by 1.0%"). No haste or
  expertise gear listed yet.
- Zircon Band of Eluding's "+1% dodge" exists only as a tooltip line, with no stat token.
- Gearwright's reader (`Data/Stats.lua`) gets hit, crit and AP right on every item:
  each counted once, each matching its tooltip.
- An item listed both with and without its data loaded was split in two in this scan
  (empty name in the key); the probe now merges them, and `tools/ah_report.py` merges
  older scans.

`python tools/ah_report.py data/probe/2026-10-03-auction.json --level 20 --spec combat`
ranks what's listed for a character, per slot, with prices.

## Still open

- [x] Encounter Journal loot tables: not available on Forever (`WRONG_GAME_TYPE`)
- [ ] Dungeon drops from the probe's loot log (run a dungeon, then `/gwp export`)
- [x] Enchanting again, for recipe effects and learned flags (2026-10-03 17:46)
- [ ] What the enchant tooltip line says for a stat enchant ("Enchanted: Agility +3"?
      only armor kits seen so far)
- [x] Trainer services (Rogue and Leatherworking trainers, 2026-10-03)
- [ ] Other Rogues' gear and enchants (`/gwp inspect`)
- [ ] Confirm spec detection in game after respeccing into Combat and Subtlety
- [ ] Agility-per-crit at more levels (`/gwp all` every few levels; beta cap is 30)
- [ ] Does any gear carry weapon-skill bonuses ("+N Daggers")?
- [ ] Can a Rogue equip one-handed axes, and only with Hack and Slash? (`/gwp talents`
      before and after putting a point in it; try equipping an axe)
