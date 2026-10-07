# Gearwright

Gear, enchant and consumable advice for your build in **World of Warcraft: Forever**.

Gearwright reads your talents to work out your spec, scores items with stat weights built
for your class, level and talents (see [docs/STAT-MODEL.md](docs/STAT-MODEL.md)), and tells you:

- **Gear** - is this item an upgrade, and by how much? (tooltip line), and for every slot the best
  known crafted upgrade and who can make it
- **Wishlist and next goal** - right-click any upgrade to wishlist it; the minimap button (or your
  info bar, via LibDataBroker) shows the next one you can wear
- **Settings** - in the window's Settings tab (also reachable from the game's AddOns settings)
- **Quest rewards and loot** - which reward to take, and which drops or rolls are upgrades
  (chat messages; `/gearwright notices` turns them off)
- **Enchants** - the best stat enchant for each slot, and what it adds over the one you have
- **Consumables** - the best weapon buff for each hand (sharpening stone, weightstone, wizard or
  mana oil, Rogue poison) and whether one is on, the elixirs worth drinking, and which healing
  and mana potions to carry, all for your level and spec
- **Crafting** - crafted upgrades from every profession, yours or not: whether you can craft
  it, one of your other characters can (same realm and faction, not bind-on-pickup), you
  need to learn the recipe, or should have someone craft it (`/gearwright` -> Crafting,
  `/gearwright craft`)

The window (`/gearwright`) has a tab per advisor: Gear, Wishlist, Crafting, Enchants,
Consumables and Settings. Hover a row for the item tooltip; Shift-click
links it in chat; right-click an upgrade to add it to your wishlist.

> Status: **pre-alpha.** v1 targets **Rogue** (Assassination, Combat, Subtlety) and
> **Priest** (Discipline, Holy, Shadow; Classic data, not yet checked in game).
> Stat weights are early estimates. Enchant amounts are read from the beta's recipes.
> See [ROADMAP.md](ROADMAP.md).

## Repo layout

```
Gearwright/            The addon players install
  Core/                Bootstrap, event bus, settings, slash commands, API wrapper
  Data/                Stat definitions, enchant effects, consumables, per-class data (specs, weights)
  Engine/              Spec detection, scoring, the advisors (pure logic)
  UI/                  Theme, tooltip line, main window
GearwrightProbe/       Dev-only addon: dumps what the Forever client exposes
tools/                 probe_to_json.py - turns probe output into JSON + a summary
                       enchants_from_probe.py - builds Data/Enchants.lua from a recipe scan
                       crafted_from_probe.py - builds Data/Crafted.lua from profession scans
                       ah_report.py - ranks auction house gear with Gearwright's scoring
                       classstats_from_wago.py - builds Data/ClassStats.lua from Forever's stat table
tests/                 smoke_test.py - runs both addons against a mocked WoW API
docs/                  Architecture, stat model, beta checklist
data/probe/            Probe captures you commit (raw research data)
data/reference/        Copies of Forever game data the tools read (stat table, talent text)
```

## Development setup

1. Clone the repo.
2. Find your Forever `AddOns` folder. The beta uses
   `<WoW>\_classic_beta_\Interface\AddOns`.
3. Link both addon folders into it. In PowerShell from the repo root (junctions
   don't need admin):

   ```powershell
   $addons = "<WoW>\_classic_beta_\Interface\AddOns"
   New-Item -ItemType Directory -Force -Path $addons | Out-Null
   New-Item -ItemType Junction -Path "$addons\Gearwright"      -Target "$PWD\Gearwright"
   New-Item -ItemType Junction -Path "$addons\GearwrightProbe" -Target "$PWD\GearwrightProbe"
   ```

4. In game, `/reload` after edits.

Run the offline smoke test after any change:

```
pip install "lupa>=2.0"
python tests/smoke_test.py
```

## Commands

| Command | What it does |
|---|---|
| `/gearwright` or `/gwr` | Toggle the Gearwright window |
| `/gearwright spec <assassination\|combat\|subtlety\|auto>` | Force or auto-detect spec |
| `/gearwright tooltip` | Toggle the tooltip upgrade line |
| `/gearwright notices` | Toggle quest reward / loot upgrade messages |
| `/gearwright craft` | Crafted upgrades up to 5 levels ahead, and who can make them |
| `/gwp all` | Probe: dump env, APIs, talents, gear, stats |
| `/gwp sheet` | Probe: record the character sheet's stat lines and tooltips (also automatic when you open it) |
| `/gwp ah` | Probe, at the auction house: full scan; records every gear item listed (stats, level, slot, lowest buyout) |
| `/gwp export` | Probe: copyable JSON of everything recorded, except the auction scan (`/gwp export ah` for that) |

## License

MIT - see [LICENSE](LICENSE).

## Sibling addon

[Battlewright](https://github.com/crazyace/Battlewright) shows what to press next in a
fight. Its combat testing (BattlewrightProbe, `/bwp combat`) lives in that repo.

## Credits

- Auctionator, TrainerSpells and GearJourney were looked at for how the game's APIs
  behave on Forever; no code or data from them is used.
