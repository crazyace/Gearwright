# Gearwright

Gear, talent and enchant advice for your build in **World of Warcraft: Forever**.

Gearwright reads your talents to work out your spec, scores items with spec-specific
stat weights, and tells you:

- **Gear** - is this item an upgrade, and by how much? (tooltip line + gear summary)
- **Talents** - where does your build differ from the recommended one?
- **Enchants** - which slots are missing the recommended enchant?

> Status: **pre-alpha.** v1 targets **Rogue** (Assassination, Combat, Subtlety).
> Stat weights, builds and enchant lists are placeholders until beta data is in.
> See [ROADMAP.md](ROADMAP.md).

## Repo layout

```
Gearwright/            The addon players install
  Core/                Bootstrap, event bus, settings, slash commands, API wrapper
  Data/                Stat definitions + per-class data (weights, builds, enchants)
  Engine/              Spec detection, scoring, the three advisors (pure logic)
  UI/                  Tooltip line + main window
GearwrightProbe/       Dev-only addon: dumps what the Forever client exposes
tools/                 probe_to_json.py - turns probe output into JSON + a summary
tests/                 smoke_test.py - runs both addons against a mocked WoW API
docs/                  Architecture, beta checklist
data/probe/            Probe captures you commit (raw research data)
```

## Development setup

1. Clone the repo.
2. Find your Forever `AddOns` folder. Reports disagree on where it lives
   (`_classic_beta_\Interface\AddOns` vs the retail folder), so check which
   folder sits next to the Forever executable.
3. Link both addon folders into it (Windows, run as admin):

   ```
   mklink /J "<WoW>\<forever folder>\Interface\AddOns\Gearwright"      "<repo>\Gearwright"
   mklink /J "<WoW>\<forever folder>\Interface\AddOns\GearwrightProbe" "<repo>\GearwrightProbe"
   ```

4. In game, `/reload` after edits.

Run the offline smoke test after any change:

```
pip install lupa
python tests/smoke_test.py
```

## Commands

| Command | What it does |
|---|---|
| `/gearwright` or `/gwr` | Toggle the Gearwright window |
| `/gearwright spec <assassination\|combat\|subtlety\|auto>` | Force or auto-detect spec |
| `/gearwright tooltip` | Toggle the tooltip upgrade line |
| `/gwp all` | Probe: dump env, APIs, talents, gear, stats |
| `/gwp export` | Probe: copyable JSON of everything recorded |

## License

MIT - see [LICENSE](LICENSE).
