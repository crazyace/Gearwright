#!/usr/bin/env python3
"""Rank the gear from a GearwrightProbe auction house scan for one character.

Scores every listed item with Gearwright's own Lua code (Data/Stats.lua, the
class's weights, Engine/Weights.lua and Engine/Scoring.lua, run through lupa),
so the ranking is exactly what the addon would say. Prints the best few per
slot that the class can use at that level, with the lowest buyout.

Needs: pip install "lupa>=2.0"

Usage:
  python tools/ah_report.py GearwrightProbe.lua --level 20 --spec combat
  python tools/ah_report.py export.json --level 25 --spec assassination --top 3
"""
import argparse
import json
import sys
from pathlib import Path

from lupa import lua51

R = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / "tools"))
from probe_to_json import load  # noqa: E402

ADDON = R / "Gearwright"
FILES = ["Data/Stats.lua", "Data/{cls}/Specs.lua", "Data/{cls}/Weights.lua", "Engine/Weights.lua", "Engine/Scoring.lua"]

# INVTYPE -> (slot group shown, slot ID used for scoring)
SLOTS = {
    "INVTYPE_HEAD": ("Head", 1), "INVTYPE_NECK": ("Neck", 2), "INVTYPE_SHOULDER": ("Shoulder", 3),
    "INVTYPE_CLOAK": ("Back", 15), "INVTYPE_CHEST": ("Chest", 5), "INVTYPE_ROBE": ("Chest", 5),
    "INVTYPE_WRIST": ("Wrist", 9), "INVTYPE_HAND": ("Hands", 10), "INVTYPE_WAIST": ("Waist", 6),
    "INVTYPE_LEGS": ("Legs", 7), "INVTYPE_FEET": ("Feet", 8), "INVTYPE_FINGER": ("Finger", 11),
    "INVTYPE_TRINKET": ("Trinket", 13), "INVTYPE_WEAPON": ("One-hand", 16),
    "INVTYPE_WEAPONMAINHAND": ("Main hand", 16), "INVTYPE_WEAPONOFFHAND": ("Off hand", 17),
    "INVTYPE_2HWEAPON": ("Two-hand", 16), "INVTYPE_RANGED": ("Ranged", 18),
    "INVTYPE_RANGEDRIGHT": ("Ranged", 18), "INVTYPE_THROWN": ("Ranged", 18),
}
ORDER = ["Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
         "Finger", "Trinket", "One-hand", "Main hand", "Off hand", "Two-hand", "Ranged"]
DAGGER = 15


def money(c):
    if c is None:
        return "no buyout"
    g, s = divmod(int(c), 10000)
    s, _ = divmod(s, 100)
    return f"{g}g {s:02d}s" if g else f"{s}s"


def lua_env(cls):
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    ns = L.eval("{ Data = {} }")
    run = L.eval("function(src, name, ns) return assert(loadstring(src, name))('Gearwright', ns) end")
    for f in FILES:
        path = ADDON / f.format(cls=cls.capitalize())
        run(path.read_text(), "@" + str(path), ns)
    return L, ns


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("probe", help="GearwrightProbe.lua (SavedVariables) or a /gwp export ah .json")
    ap.add_argument("--class", dest="cls", default="ROGUE")
    ap.add_argument("--spec", default="combat")
    ap.add_argument("--level", type=int, default=20)
    ap.add_argument("--mh-dps", type=float, default=None, help="your main-hand DPS (sets crit/hit value)")
    ap.add_argument("--top", type=int, default=5)
    ap.add_argument("--max-gold", type=float, default=None, help="leave out items costing more")
    args = ap.parse_args()

    scan = (load(args.probe).get("scans") or {}).get("auction")
    if not scan:
        sys.exit("no auction scan in this file (/gwp ah at the auction house)")
    L, ns = lua_env(args.cls)
    cls = ns.Data[args.cls]
    spec = cls.specs[args.spec]
    rules = spec.weapons
    prof = cls.proficiency
    weights = ns.Weights.Build(cls, args.spec, L.table_from({"level": args.level, "mainHandDps": args.mh_dps}))
    score = L.eval("""function(ns, raw, lines, weights, slot)
      local s = ns.Stats.AddTooltipEffects(ns.Stats.FromRaw(raw), lines)
      return ns.Scoring.ScoreStats(s, weights, slot) end""")

    # Scans before 2026-10-04 split an item when some listings came without data
    # (empty name in the key): merge by item ID and name.
    merged = {}
    for rec in (scan.get("gear") or {}).values():
        key = (rec.get("id"), rec.get("name"))
        prev = merged.get(key)
        if not prev:
            merged[key] = dict(rec)
            continue
        prev["listings"] = (prev.get("listings") or 0) + (rec.get("listings") or 0)
        prices = [x for x in (prev.get("minBuyout"), rec.get("minBuyout")) if x]
        prev["minBuyout"] = min(prices) if prices else None

    best = {}
    for rec in merged.values():
        req = rec.get("reqLevel") or 0
        group = SLOTS.get(rec.get("equip"))
        if not group or req > args.level:
            continue
        cl, sub = rec.get("class"), rec.get("sub")
        if prof[cl] is not None and not prof[cl][sub]:
            continue
        if args.max_gold is not None and (rec.get("minBuyout") or 0) > args.max_gold * 10000:
            continue
        name, slot = group
        if slot == 16 and rules is not None and rules.mainHand == "dagger" and sub != DAGGER:
            if rec.get("equip") == "INVTYPE_WEAPON":
                name, slot = "Off hand", 17  # Backstab specs: non-daggers are off-hand only
            else:
                continue
        raw = L.table_from(rec.get("stats") or {})
        lines = L.table_from([t for t in rec.get("tooltip") or [] if isinstance(t, str)])
        best.setdefault(name, []).append((score(ns, raw, lines, weights, slot), req, rec))

    print(f"{args.cls.capitalize()} {spec.label}, level {args.level}: {scan.get('listings')} listings scanned {scan.get('at')}")
    print("score = attack-power equivalents (Gearwright's weights, provisional)\n")
    for name in ORDER:
        rows = sorted(best.get(name, []), key=lambda r: (-r[0], r[2].get("minBuyout") or 0))[:args.top]
        if not rows:
            continue
        print(name)
        for sc, req, rec in rows:
            print(f"  {sc:6.1f}  {rec.get('name')}  (level {req}, {money(rec.get('minBuyout'))}, {rec.get('listings')} listed)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
