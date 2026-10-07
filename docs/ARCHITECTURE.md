# Architecture

```
 WoW client
     |
 Core/API.lua ........ the only file that reads game data; strips secret values
     |
 Data/ ............... what's "right": stat keys, enchant effects, consumables, specs and weights (per class)
     |
 Engine/ ............. pure logic: Spec.Detect -> Scoring -> Advisor (gear/talents/enchants/consumables/crafting);
                       Professions remembers each profession's recipes per character
     |
 UI/ ................. Tooltip line, main window. Renders Advisor output, no logic.
```

## Rules

1. **Only `Core/API.lua` touches game data APIs.** Forever's API is unconfirmed and
   restricted. When the probe tells us something works differently, we fix one file.
2. **Engine has no WoW calls.** Everything takes plain tables, so it runs in
   `tests/smoke_test.py` and could be reused by a future web tool.
3. **Data is data.** Specs and weights are Lua tables in `Data/<CLASS>/`; enchant effects
   (`Data/Enchants.lua`) are generated from a probe scan and shared by every class.
   Adding a class means adding a folder, not touching the engine.
4. **Every data file carries a status.** `_status = "provisional" | "todo" | "verified"`.
   The UI warns while anything is provisional.

## Load order

Defined in `Gearwright.toc`: Core (Init, Util, API) -> Data -> Engine -> UI -> Commands.
Each file gets the shared addon namespace `ns` via `local _, ns = ...`.

## Adding a class

1. Create `Data/<CLASS_TOKEN>/` with `Specs.lua`, `Weights.lua` (enchants and consumables are shared: `Data/Enchants.lua`, `Data/Consumables.lua`)
   (copy the Rogue files; `CLASS_TOKEN` is the second return of `UnitClass`, e.g. `WARRIOR`).
2. Add the files to `Gearwright.toc`.
3. Fill `tabToSpec`. `traitTabGroups` can wait: without it `Core/API.lua` works the spec groups
   out from the tree's layout (the largest non-overlapping groups, numbered left to right).
   Copy them in from probe output once you have it (`tools/probe_to_json.py` lists every
   talent node; `docs/BETA-FINDINGS.md` shows how the Rogue groups were found).
4. Crit and mana conversions need nothing: `Data/ClassStats.lua` covers all nine classes.
   List the talents that change a stat's worth in `talentEffects` (see `docs/STAT-MODEL.md`).
5. A caster sets `model = "caster"` in `Weights.lua` (see below); a class that holds orbs and
   tomes in the off hand sets `holdables = true` in `Specs.lua`.

## Scoring model (v1)

`score = sum(stat_value x weight)`, in **attack-power equivalents** ("worth N AP").
`Engine/Weights.lua` builds the weights for your level and current damage:

- Strength and AP are 1 (confirmed on the beta); Agility is 1 + its share of crit,
  using Agility-per-crit for your class and level (`Data/ClassStats.lua`, generated from
  Forever's own table by `tools/classstats_from_wago.py`).
- Weapon DPS is 14 on the main hand, 7 on the off hand (Classic: DPS = weapon DPS + AP/14).
- Rating stats are per 1%, valued as a share of your damage: 1% is worth 0.14 x main-hand DPS in AP.

Casters (`model = "caster"`, the Priest) score in points of their spec's main power instead:
bonus healing for a healer, spell damage for Shadow. Spell power is worth healing + spell
damage; school damage counts for the schools the spec casts; spell hit, spell crit and haste
are a share of output (`powerPerPercent` by level); Intellect adds its share of spell crit
(`Data/ClassStats.lua`). Melee weapon DPS is worth nothing, a wand's DPS is.

Talents that change what a stat is worth (`talentEffects` in `Data/<CLASS>/Weights.lua`)
adjust the table after that, from the ranks `Spec.Talents()` reads. `docs/STAT-MODEL.md`
has the formulas, their sources and the talent list.

A two-hander is compared against both hands, and an off-hand item against an equipped two-hander.

An item is only scored for slots it can go in: the class's armor and weapon
proficiencies (`Specs.lua: proficiency`) and the spec's weapon rules (`weapons`)
come first. A tooltip upgrade is `score(new) - score(equipped)` in whichever valid slot
gains the most; an item above your level still scores, with "at level N".

Known gaps, deliberately deferred:
- Stat caps (e.g. hit cap) - needs Forever combat formulas first
- Set bonuses and "Equip:" procs beyond simple % stats
- Weapon type/speed rules per spec
