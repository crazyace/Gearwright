#!/usr/bin/env python3
"""Turn GearwrightProbe output into JSON and a readable summary.

Input is either:
  * the SavedVariables file:  WTF/Account/<ACCOUNT>/SavedVariables/GearwrightProbe.lua
  * a JSON file you pasted from /gwp export

Usage:
  python tools/probe_to_json.py GearwrightProbe.lua -o data/probe/2026-10-03.json
  python tools/probe_to_json.py export.json            # summary only
"""
import argparse
import json
import re
import sys
from pathlib import Path


# --- Minimal Lua table parser (enough for WoW SavedVariables) ----------------

class LuaParser:
    TOKEN = re.compile(r"""
        (?P<ws>\s+|--\[\[.*?\]\]|--[^\n]*)
      | (?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')
      | (?P<num>-?(?:0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+))
      | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
      | (?P<sym>[{}\[\]=,;])
    """, re.VERBOSE | re.DOTALL)

    ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n"}

    def __init__(self, text):
        self.tokens = []
        pos = 0
        while pos < len(text):
            m = self.TOKEN.match(text, pos)
            if not m:
                raise ValueError(f"unexpected character at {pos}: {text[pos:pos+20]!r}")
            pos = m.end()
            kind = m.lastgroup
            if kind != "ws":
                self.tokens.append((kind, m.group()))
        self.i = 0

    def peek(self):
        return self.tokens[self.i] if self.i < len(self.tokens) else (None, None)

    def take(self, value=None):
        tok = self.peek()
        if value is not None and tok[1] != value:
            raise ValueError(f"expected {value!r}, got {tok[1]!r}")
        self.i += 1
        return tok

    def unquote(self, s):
        body = s[1:-1]
        out, k = [], 0
        while k < len(body):
            c = body[k]
            if c == "\\" and k + 1 < len(body):
                nxt = body[k + 1]
                if nxt.isdigit():
                    m = re.match(r"\d{1,3}", body[k + 1:])
                    out.append(chr(int(m.group())))
                    k += 1 + len(m.group())
                    continue
                out.append(self.ESCAPES.get(nxt, nxt))
                k += 2
                continue
            out.append(c)
            k += 1
        return "".join(out)

    def value(self):
        kind, tok = self.peek()
        if tok == "{":
            return self.table()
        self.take()
        if kind == "str":
            return self.unquote(tok)
        if kind == "num":
            n = int(tok, 16) if tok.lower().startswith(("0x", "-0x")) else float(tok)
            return int(n) if isinstance(n, float) and n.is_integer() else n
        if tok == "true":
            return True
        if tok == "false":
            return False
        if tok == "nil":
            return None
        raise ValueError(f"unexpected token {tok!r}")

    def table(self):
        self.take("{")
        items, arr, auto = {}, [], 1
        while self.peek()[1] != "}":
            kind, tok = self.peek()
            if tok == "[":
                self.take("[")
                key = self.value()
                self.take("]")
                self.take("=")
                items[key] = self.value()
            elif kind == "name" and self.tokens[self.i + 1][1] == "=":
                self.take()
                self.take("=")
                items[tok] = self.value()
            else:
                items[auto] = self.value()
                auto += 1
            if self.peek()[1] in (",", ";"):
                self.take()
        self.take("}")
        # Convert 1..n integer-keyed tables to lists.
        keys = list(items)
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [items[k] for k in range(1, len(keys) + 1)]
        if not keys:
            return {}
        return {str(k): v for k, v in items.items()}

    def assignments(self):
        out = {}
        while self.peek()[0] is not None:
            _, name = self.take()
            self.take("=")
            out[name] = self.value()
        return out


def load(path):
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    if text.lstrip().startswith("{"):
        return json.loads(text)
    return LuaParser(text).assignments().get("GearwrightProbeDB", {})


# --- Summary -----------------------------------------------------------------

def summarize(db):
    lines = []
    snaps = db.get("snapshots") or []
    lines.append(f"snapshots: {len(snaps)}   scans: {len(db.get('scans') or {})}")
    persist = db.get("persistTest")
    lines.append(f"persistence marker: {persist.get('written') if persist else 'none'}")

    for snap in snaps:
        sec = snap.get("sections", {})
        lines.append("")
        lines.append(f"== {snap.get('at')}  {snap.get('character')}  {snap.get('class')}  lvl {snap.get('level')}")

        build = (sec.get("env", {}).get("build") or {}).get("values") or []
        if build:
            lines.append(f"   build: {build}")

        api = sec.get("api") or {}
        missing = sorted(k for k, v in api.items() if v == "nil")
        if api:
            lines.append(f"   APIs: {len(api) - len(missing)}/{len(api)} present")
            if missing:
                lines.append(f"   missing: {', '.join(missing)}")

        talents = sec.get("talents") or {}
        if "classic" in talents:
            for t, tab in enumerate(talents["classic"], 1):
                info = (tab.get("info") or {}).get("values") or []
                tab_name = next((v for v in info if isinstance(v, str) and not v.startswith("<")), "?")
                names = []
                for tal in tab.get("talents") or []:
                    v = tal.get("values") or []
                    if v:
                        names.append(f"{v[0]} ({v[4] if len(v) > 4 else '?'}/{v[5] if len(v) > 5 else '?'})")
                lines.append(f"   talents tab {t} [{tab_name}]: {len(names)} talents")
                for n in names:
                    lines.append(f"      {n}")
        if "traits" in talents:
            trees = talents["traits"].get("trees") or []
            lines.append(f"   traits trees: {len(trees)}")

        gear = sec.get("gear") or {}
        tokens = set()
        for item in (gear.values() if isinstance(gear, dict) else gear):
            if not isinstance(item, dict):
                continue
            st = (item.get("stats") or {}).get("values") or []
            if st and isinstance(st[0], dict):
                tokens.update(st[0].keys())
        if gear:
            lines.append(f"   gear items: {len(gear)}   stat tokens: {', '.join(sorted(tokens)) or 'none'}")

        stats = sec.get("stats") or {}
        secret = sorted(k for k, v in stats.items() if isinstance(v, dict) and v.get("status") == "secret")
        if stats:
            lines.append(f"   stat calls: {len(stats)}   secret: {', '.join(secret) or 'none'}")

    for key, scan in (db.get("scans") or {}).items():
        count = len(scan.get("recipes") or scan.get("services") or scan.get("gear") or [])
        lines.append(f"scan {key}: {count} entries")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", help="GearwrightProbe.lua (SavedVariables) or exported .json")
    ap.add_argument("-o", "--out", help="write normalized JSON here")
    args = ap.parse_args()

    db = load(args.input)
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(json.dumps(db, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"wrote {args.out}")
    print(summarize(db))


if __name__ == "__main__":
    sys.exit(main())
