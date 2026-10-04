# Gearwright

Gear, talent and enchant advice for your build in **World of Warcraft: Forever**.

Gearwright reads your talents to work out your spec, scores items with spec-specific
stat weights, and tells you:

- **Gear** - is this item an upgrade, and by how much? (tooltip line + gear summary)
- **Quest rewards and loot** - which reward to take, and which drops or rolls are upgrades
  (chat messages; `/gearwright notices` turns them off)
- **Talents** - where does your build differ from the recommended one?
- **Enchants** - the best stat enchant for each slot, and what it adds over the one you have
- **Crafting** - crafted upgrades from every profession, yours or not: whether you can craft
  it, one of your other characters can (same realm and faction, not bind-on-pickup), you
  need to learn the recipe, or should have someone craft it (`/gearwright` -> Crafting,
  `/gearwright craft`)
- **Dungeons** - the boss drops and dungeon quest rewards that would be upgrades for you, and
  where they drop (window tab + tooltip line)

The window (`/gearwright`) has a tab per advisor: Gear, Dungeons, Enchants, Talents.
Hover a row for the item tooltip; Shift-click links it in chat.

### Dungeon loot

Forever's Encounter Journal is empty, so Gearwright gets dungeon loot two ways:

- **Its own table** (`Data/DungeonLoot.lua`), built from drops recorded in game:
  run dungeons with GearwrightProbe loaded, `/gwp export`, then
  `python tools/loot_from_probe.py data/probe/*.json`.
- **Forever Dungeon Journal** by Exehn, if you have it
  installed: Gearwright reads its loot and quest-reward tables while the game runs. Nothing
  from it is copied into Gearwright.

> Status: **pre-alpha.** v1 targets **Rogue** (Assassination, Combat, Subtlety).
> Stat weights and builds are early estimates. Enchant amounts are read from the beta's recipes.
> See [ROADMAP.md](ROADMAP.md).

## Repo layout

```
Gearwright/            The addon players install
  Core/                Bootstrap, event bus, settings, slash commands, API wrapper
  Data/                Stat definitions, enchant effects, per-class data (weights, builds)
  Engine/              Spec detection, scoring, the advisors (pure logic)
  UI/                  Theme, tooltip line, main window
GearwrightProbe/       Dev-only addon: dumps what the Forever client exposes
tools/                 probe_to_json.py - turns probe output into JSON + a summary
                       enchants_from_probe.py - builds Data/Enchants.lua from a recipe scan
                       loot_from_probe.py - builds Data/DungeonLoot.lua from probe loot logs
                       crafted_from_probe.py - builds Data/Crafted.lua from profession scans
                       ah_report.py - ranks auction house gear with Gearwright's scoring
tests/                 smoke_test.py - runs both addons against a mocked WoW API
docs/                  Architecture, beta checklist
data/probe/            Probe captures you commit (raw research data)
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
| `/gearwright train` | Weapon skills you can still train, who teaches them, pinned on the world map |
| `/gearwright craft` | Crafted upgrades up to 5 levels ahead, and who can make them |
| `/gwp all` | Probe: dump env, APIs, talents, gear, stats |
| `/gwp sheet` | Probe: record the character sheet's stat lines and tooltips (also automatic when you open it) |
| `/gwp ah` | Probe, at the auction house: full scan; records every gear item listed (stats, level, slot, lowest buyout) |
| `/gwp export` | Probe: copyable JSON of everything recorded, except the auction scan (`/gwp export ah` for that) |

## License

MIT - see [LICENSE](LICENSE).
