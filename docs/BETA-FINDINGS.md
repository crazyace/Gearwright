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

## Items and stats

- `C_Item.GetItemStats` works and returns `ITEM_MOD_*_SHORT` tokens. Seen so far:
  `AGILITY`, `STRENGTH`, `STAMINA`, `SPIRIT`, `ATTACK_POWER`, `ATTACK_POWER_VS_HUMANOID`,
  `DAMAGE_PER_SECOND`, `FROST_RESISTANCE`, plus `RESISTANCE0_NAME` (armor) and `RESISTANCE4_NAME`.
- **"Equip:" bonuses are reported twice.** Catacomb Cloak has `ITEM_MOD_ATTACK_POWER_SHORT = 3`
  and the tooltip line "Equip: +3 Attack Power." Gearwright counts the stat once.
- "Equip: +4 Attack Power against Humanoids." is a separate token and is not counted as AP.
- Enchants are **not** in `GetItemStats`; they show as an "Enchanted: ..." tooltip line.
- **Hit/crit units: still open.** No hit/crit/haste/expertise gear in any capture yet.
  The client defines the full Mainline set of 31 `CR_*` ratings (including Versatility,
  Mastery, Avoidance, Lifesteal, Speed) and all read 0, so the rating system exists,
  but whether items use it is unknown.

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

## Still open

- [ ] Hit/crit/haste/expertise units: equip gear with those stats, `/gwp gear`
- [ ] Enchanting recipes and trainer services (open the windows; recorded automatically)
- [ ] Other Rogues' gear and enchants (`/gwp inspect`)
- [ ] Confirm spec detection in game after respeccing into Combat and Subtlety
- [ ] Agility-per-crit at more levels (`/gwp all` every few levels; beta cap is 30)
- [ ] Does any gear carry weapon-skill bonuses ("+N Daggers")?
