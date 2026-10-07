# How Gearwright values stats

What each attribute does on Forever, where that knowledge comes from, and how Gearwright
turns it into stat weights that follow your level and your talents.

## Sources, most trusted first

1. **Forever's own game data.** The `PlayerExpectedStat` DB2 table (build 1.60.1.70245,
   copied from wago.tools into `data/reference/`) holds, for all nine classes at every
   level: crit per Agility, spell crit per Intellect, base mana and health per Stamina.
   `tools/classstats_from_wago.py` turns it into `Gearwright/Data/ClassStats.lua`.
2. **The beta's character sheet.** `/gwp sheet` records every stat line's tooltip
   ("66 Agility: 8.7% crit, +66 AP, +132 ranged AP..."). These are measurements.
3. **Wowhead's Forever database** (`nether.wowhead.com/forever/tooltip/spell/<id>`).
   Datamined talent text, saved in `data/reference/forever-stat-talents.json` (the 177
   talents of 466 that mention a stat). It can be ahead of or behind the beta.
4. **Classic's formulas.** Used where nothing above says otherwise, and marked as such.

## Attributes

Checked = seen on the beta's character sheet or matched against it.

| Attribute | What it gives | Status |
|---|---|---|
| Strength | Melee AP: 2 per point (Warrior, Paladin, Shaman, Druid), 1 (Rogue, Hunter, casters). Block value for shield users | Rogue 1 AP: checked. Others: Classic |
| Agility | Crit (per-level table below), 2 armor, dodge. Melee AP: 1 per point for Rogue and Hunter. Ranged AP: 2 for Hunter, 1 for Warrior, **2 for Rogue on Forever** | Rogue crit, AP, ranged AP, armor: checked |
| Stamina | 10 health per point (the table says 10 for every class at every level) | Checked |
| Intellect | Spell crit (table below). Mana: 15 per point (the first 20 give 1 each) | Spell crit: checked on a level 12 Priest. Mana: Classic |
| Spirit | Health and mana regeneration outside the five-second rule | Rogue: 29 Spirit = 35 health per 5 s. Priest: 47 Spirit = 58 mana per 5 s (Classic's 13 + Spirit/4 per 2 s gives 62). Needs more points |
| Hit / crit rating | Fixed rates at every item level: 10 hit rating = 1%, 14 crit rating = 1%. **Crit is one stat** for melee, ranged and spells, so crit on gear counts as spell crit for a caster | Rates: from 40 Wowhead items. One crit stat: Blizzard's Forever announcement |
| Spell damage / healing | "Damage and healing done by magical spells" gives its amount to both. A damage-only bonus gives no healing. Healing gear also grants a third as much spell damage (90 healing = 30 damage); Forever's items list both numbers, so Gearwright scores each as written | Forever's published rules |
| Attack power | Melee DPS = weapon DPS + AP / 14 | Rogue base AP = 2 x level + Str + Agi - 20: checked |

### Crit per Agility and spell crit per Intellect

From Forever's table, at levels 10 / 20 / 30 / 40 / 50 / 60. They match Classic at 60.
Checked on the beta: Rogue 19 (7.6 Agility per 1%) and Priest 12 (9.5 Intellect per 1%).

| Class | Agility per 1% crit | Intellect per 1% spell crit | Base mana at 60 |
|---|---|---|---|
| Warrior | 5.2 / 7.8 / 10.4 / 13.2 / 16.4 / 20.0 | - | - |
| Paladin | 5.8 / 8.1 / 10.7 / 13.5 / 16.5 / 19.8 | 16.7 / 24.0 / 31.9 / 40.7 / 50.0 / 59.9 | 1512 |
| Hunter | 6.8 / 15.2 / 24.0 / 33.0 / 42.7 / 52.9 | 17.9 / 25.0 / 32.9 / 41.5 / 50.8 / 60.6 | 1720 |
| Rogue | 3.5 / 8.1 / 13.0 / 18.0 / 23.4 / 29.0 | - | - |
| Priest | 11.0 / 12.5 / 14.0 / 15.5 / 17.5 / 20.0 | 7.9 / 17.2 / 26.9 / 37.2 / 48.1 / 59.5 | 1376 |
| Shaman | 7.3 / 9.4 / 11.5 / 13.9 / 16.7 / 19.7 | 10.4 / 19.3 / 28.2 / 38.2 / 48.1 / 59.2 | 1520 |
| Mage | 12.2 / 13.3 / 14.5 / 16.1 / 17.8 / 19.5 | 7.5 / 16.9 / 27.3 / 36.2 / 47.4 / 59.5 | 1213 |
| Warlock | 7.7 / 9.7 / 12.0 / 14.3 / 17.0 / 20.0 | 9.4 / 18.5 / 28.2 / 38.2 / 49.0 / 60.6 | 1373 |
| Druid | 6.3 / 8.8 / 11.2 / 13.9 / 16.8 / 20.0 | 10.0 / 19.0 / 28.4 / 38.5 / 48.8 / 59.9 | 1244 |

Every level, not just these, is in `Data/ClassStats.lua`, so Gearwright no longer draws a
line between two known points.

### Not known yet

- Spirit's mana regeneration formula. Beta reports conflict (some say Classic's Spirit / 4
  or / 5 per tick, some say it changed), so Classic's formula is not treated as Forever's.
  Blizzard confirms casting regen is stronger through talents (Priest Meditation, Druid
  Reflection) but gives no base equation. One point so far: Priest, 47 Spirit = 58 mana per 5 s.
- Whether hit was merged the way crit was.

These are on `docs/BETA-CHECKLIST.md` under "Stat model".

## Weapon speed

Sinister Strike and Backstab hit for the main-hand weapon's damage once per use, however
fast the weapon swings, so of two weapons with the same DPS the slower one hits harder and
is worth more. Each Rogue spec has `abilityHits`, main-hand hits a second from abilities
(0.15: about 60% of 10 energy a second on 40-energy Sinister Strikes, or 60-energy Backstabs
at 150%). A main-hand weapon scores its DPS plus `DPS x speed x abilityHits` more DPS; flat
weapon damage (stones) and poison procs count those hits too. Classic's numbers, not measured
on Forever.

## Talents that change what a stat is worth

A talent matters to weights only when it changes what **one more point** of a stat is
worth. +5% crit chance (Malice) does not: the next point of crit is worth the same.
+15% Intellect (Mental Strength) does: every Intellect point on gear becomes 1.15.

Gearwright counts these today (amounts from Wowhead's Forever text):

| Class | Talent | Effect on weights |
|---|---|---|
| Priest | Mental Strength | Intellect x 1.15 at 5/5 |
| Priest | Meditation | Spirit x 1.5 at 3/3 (50% of regen while casting) |
| Priest | Spiritual Guidance | Spirit also gives 25% of itself as healing and 8% as spell damage at 5/5 |
| Priest | Shadowform | Spell crit x 2 (Shadow crit damage bonus +100%) |
| Rogue | Lethality | Crit x (1 + 6% per rank x half your damage) |

Other talents that would matter, not modelled yet:

- **Hit from talents** (Rogue Precision, Priest Holy Precision and Shadow Focus) lower what
  hit on gear is worth near the cap. The weights don't model the hit cap yet.
- **Rogue Hack and Slash** and **Serrated Blades**: weapon type and armor penetration.
- **Priest Divine Aegis** (crit heals add a shield) raises crit for a healer.

### Per rank or total?

Wowhead's text doesn't say. Where Forever kept a Classic talent unchanged it shows the
rank 1 amount (Holy Specialization 1%, Lethality 6%). Where Forever changed it, the amounts
read like the whole talent (Mental Strength 15%, Malice 5%). Gearwright follows that
reading talent by talent (`perRank` in the data). `/gwp talents` now records each talent's
in-game text at rank 1, your rank and max rank, which settles it.

## How weights are built

`Engine/Weights.lua` builds a fresh weight table each time the advisors need one:

1. The spec's base weights (`Data/<Class>/Weights.lua`): how much of your output 1% of
   each rating is worth, Strength and attack power for melee, healing or spell damage
   for casters.
2. Ratings are turned into points of your main power at your level and weapon DPS.
3. Talent effects that scale a rating (Shadowform, Lethality) apply.
4. Agility and Intellect take their share of crit from the class table at your level.
5. Talent effects that multiply a stat (Mental Strength) or turn one into another
   (Spiritual Guidance) apply.

The spec still comes from where your talent points are, and only picks the base weights.
The window's header lists the talents the weights count.

## Settings

The Settings tab's four spec rows are now one row, **Score gear for**: Automatic follows
your talents; clicking steps through the specs (for scoring a second build); right-click
goes back to Automatic.

## Adding a class

1. `Data/<Class>/Specs.lua` and `Weights.lua` (base weights per spec, `talentEffects`).
2. Nothing for crit or mana conversions: `Data/ClassStats.lua` already has all nine.
3. A talent capture from the beta for the spec groups.
