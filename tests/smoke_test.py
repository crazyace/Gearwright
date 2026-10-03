#!/usr/bin/env python3
"""Smoke test: load both addons against a mocked WoW API and exercise them.

    pip install lupa
    python tests/smoke_test.py

The mock is intentionally small. It checks syntax, load order, spec detection,
scoring, the slash commands and the probe's export path, not real game data.
"""
import lupa, json, subprocess, os
import tempfile
from pathlib import Path
R = Path(__file__).resolve().parent.parent
OUT = Path(tempfile.mkdtemp())
L = lupa.LuaRuntime(unpack_returned_tuples=True)
print("Lua:", L.eval("_VERSION"))
L.execute(r'''
unpack = unpack or table.unpack
printed = {}
function print(...) local t={} for i=1,select('#',...) do t[#t+1]=tostring((select(i,...))) end printed[#printed+1]=table.concat(t," ") end
function date(f) return "2026-10-03 16:00:00" end
local function stub() local o = {} return setmetatable(o,{__index=function(t,k) return function() return t end end}) end
local frames = {}
function CreateFrame(kind, name) local f = stub(); f.SetText=function(self,t) self.text=t; EXPORTTEXT=t end; f._events={}; f.RegisterEvent=function(self,e) self._events[e]=true end
  f.SetScript=function(self,k,fn) self["_"..k]=fn end; f.CreateFontString=function() local fs=stub(); fs.GetStringHeight=function() return 10 end; fs.SetText=function(self,t) self.text=t; LASTTEXT=t end; return fs end
  f.GetStringHeight=function() return 10 end
  frames[#frames+1]=f; if name then _G[name]=f end; return f end
function fire(event, ...) for _,f in ipairs(frames) do if f._events[event] and f._OnEvent then f._OnEvent(f, event, ...) end end end
function geterrorhandler() return function(e) error(e) end end
UIParent = {}; UISpecialFrames = {}; tinsert = table.insert
SlashCmdList = {}
C_Timer = { After = function(_, fn) fn() end }
WOW_PROJECT_ID = 99
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.15.0", "99999", "Oct 1 2026", 120105 end
function UnitClass() return "Rogue", "ROGUE" end
function UnitRace() return "Human","Human" end
function UnitLevel() return 30 end
function UnitFullName() return "Tester","Realm" end
function UnitName() return "Tester" end
function UnitExists() return true end
-- Classic-style talents: 3 tabs, combat has most points
local TABS = { {"Assassination", {{"Malice",0,5},{"Mutilate",0,1}}}, {"Combat", {{"Hack and Slash",5,5},{"Restless Blades",1,1}}}, {"Subtlety", {{"Hemorrhage",0,1}}} }
function GetNumTalentTabs() return #TABS end
function GetTalentTabInfo(t) return 100+t, TABS[t][1], "desc" end
function GetNumTalents(t) return #TABS[t][2] end
function GetTalentInfo(t,i) local x=TABS[t][2][i] return x[1], "icon", 1, i, x[2], x[3] end
-- Items
local ITEMS = {
 ["item:1001:0:0"] = { equip="INVTYPE_HEAD", stats={ITEM_MOD_AGILITY_SHORT=10, ITEM_MOD_STAMINA_SHORT=8}, tip={"Cap", "Equip: Improves your chance to hit by 1%."} },
 ["item:1002:0:0"] = { equip="INVTYPE_HEAD", stats={ITEM_MOD_AGILITY_SHORT=14, ITEM_MOD_ATTACK_POWER_SHORT=20}, tip={"Better Cap"} },
 ["item:2001:1900:0"] = { equip="INVTYPE_WEAPON", stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=20}, tip={} },
}
INV = { [1] = "item:1001:0:0", [16] = "item:2001:1900:0" }
function GetInventoryItemLink(unit, slot) return INV[slot] end
C_Item = { GetItemStats = function(l) return ITEMS[l] and ITEMS[l].stats end,
           GetItemInfoInstant = function(l) return 1, "Armor", "Cloth", ITEMS[l] and ITEMS[l].equip end }
C_TooltipInfo = { GetHyperlink = function(l) local o={lines={}} for _,t in ipairs(ITEMS[l] and ITEMS[l].tip or {}) do o.lines[#o.lines+1]={leftText=t} end return o end }
function UnitAttackPower() return 100, 0, 0 end
function GetCritChance() return 5.5 end
function issecretvalue(v) return v == "SECRET" end
function GetHaste() return "SECRET" end
function NotifyInspect() end
''')

def load_addon(folder, toc):
    ns = L.table()
    for line in (R/folder/toc).read_text().splitlines():
        line=line.strip()
        if not line or line.startswith("#"): continue
        p = R/folder/line.replace("\\","/")
        L.execute("local f = assert(load(...)); return f", p.read_text())  # syntax check
        fn = L.eval("function(src, name) return assert(load(src, '@'..name)) end")(p.read_text(), str(p))
        fn(folder, ns)
    return ns

ns = load_addon("Gearwright","Gearwright.toc")
L.globals().fire("ADDON_LOADED","Gearwright")
L.globals().fire("PLAYER_LOGIN")
spec, how = L.eval("function(ns) return ns.Spec.Detect() end")(ns)
print("spec:", spec, how)
cmp = L.eval("function(ns) return ns.Advisor.CompareToEquipped('item:1002:0:0') end")(ns)
print("compare better cap:", cmp)
assert spec == "combat" and how == "talents"
assert abs(cmp[0] - 1.6) < 1e-9, cmp
print("enchant id:", L.eval("function(ns) return ns.API.GetEnchantID('item:2001:1900:0') end")(ns))
L.globals().SlashCmdList.GEARWRIGHT("spec subtlety")
print("override:", L.eval("function(ns) return ns.Spec.Detect() end")(ns))
L.globals().SlashCmdList.GEARWRIGHT("")  # open window → buildText
txt = L.eval("function(ns) return ns.UI.frame and 'ok' end")(ns)
print("window:", txt)
# build text directly
L.globals().SlashCmdList.GEARWRIGHT("spec auto")

# Probe
load_addon("GearwrightProbe","GearwrightProbe.toc")
L.globals().fire("ADDON_LOADED","GearwrightProbe"); L.globals().fire("PLAYER_LOGIN")
L.globals().SlashCmdList.GEARWRIGHTPROBE("all")
L.globals().SlashCmdList.GEARWRIGHTPROBE("export")
print("---- window text ----"); print(L.globals().LASTTEXT)
for p in L.globals().printed.values(): print("  >", p)

open(OUT/"export.json","w").write(L.globals().EXPORTTEXT)
# also write a SavedVariables-style Lua file
L.execute(r"""
local function ser(v, ind)
  ind = ind or ""
  if type(v)=="table" then local o={"{\n"} for k,val in pairs(v) do local key = type(k)=="number" and "["..k.."]" or string.format("[%q]",k)
    o[#o+1]=ind.."\t"..key.." = "..ser(val, ind.."\t")..",\n" end o[#o+1]=ind.."}" return table.concat(o)
  elseif type(v)=="string" then return string.format("%q", v) else return tostring(v) end end
SVTEXT = "\nGearwrightProbeDB = " .. ser(GearwrightProbeDB) .. "\n"
""")
open(OUT/"GearwrightProbe.lua","w").write(L.globals().SVTEXT)

import subprocess, sys
for f in ("export.json", "GearwrightProbe.lua"):
    r = subprocess.run([sys.executable, str(R/"tools"/"probe_to_json.py"), str(OUT/f)], capture_output=True, text=True)
    assert r.returncode == 0 and "Hack and Slash (5/5)" in r.stdout, r.stdout + r.stderr
print("\nALL SMOKE TESTS PASSED")
