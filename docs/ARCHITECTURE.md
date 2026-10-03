# Architecture

```
 WoW client
     |
 Core/API.lua ........ the only file that reads game data; strips secret values
     |
 Data/ ............... what's "right": stat keys, weights, builds, enchants (per class)
     |
 Engine/ ............. pure logic: Spec.Detect -> Scoring -> Advisor (gear/talents/enchants)
     |
 UI/ ................. Tooltip line, main window. Renders Advisor output, no logic.
```

## Rules

1. **Only `Core/API.lua` touches game data APIs.** Forever's API is unconfirmed and
   restricted. When the probe tells us something works differently, we fix one file.
2. **Engine has no WoW calls.** Everything takes plain tables, so it runs in
   `tests/smoke_test.py` and could be reused by a future web tool.
3. **Data is data.** Weights, builds and enchants are Lua tables in `Data/<CLASS>/`.
   Adding a class means adding a folder, not touching the engine.
4. **Every data file carries a status.** `_status = "provisional" | "todo" | "verified"`.
   The UI warns while anything is provisional.

## Load order

Defined in `Gearwright.toc`: Core (Init, Util, API) -> Data -> Engine -> UI -> Commands.
Each file gets the shared addon namespace `ns` via `local _, ns = ...`.

## Adding a class

1. Create `Data/<CLASS_TOKEN>/` with `Specs.lua`, `Weights.lua`, `Talents.lua`, `Enchants.lua`
   (copy the Rogue files; `CLASS_TOKEN` is the second return of `UnitClass`, e.g. `WARRIOR`).
2. Add the files to `Gearwright.toc`.
3. Fill `tabToSpec` and `traitTabGroups` from probe output (`tools/probe_to_json.py` lists every
   talent node; `docs/BETA-FINDINGS.md` shows how the Rogue groups were found).

## Scoring model (v1)

`score = sum(stat_value x weight)`, weights normalized to Agility = 1.0.
A tooltip upgrade is `score(new) - score(weakest equipped item in a valid slot)`.

Known gaps, deliberately deferred:
- Stat caps (e.g. hit cap) - needs Forever combat formulas first
- Set bonuses and "Equip:" procs beyond simple % stats
- Weapon type/speed rules per spec
