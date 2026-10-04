#!/usr/bin/env python3
"""Smoke test: load both addons against a mocked WoW API and exercise them.

    pip install "lupa>=2.0"
    python tests/smoke_test.py

The mock is intentionally small. It checks syntax, load order, spec detection,
scoring, the slash commands and the probe's export path, not real game data.
"""
import tempfile
from lupa import lua51  # WoW runs Lua 5.1; test on the same version
from pathlib import Path
R = Path(__file__).resolve().parent.parent
OUT = Path(tempfile.mkdtemp())
L = lua51.LuaRuntime(unpack_returned_tuples=True)
print("Lua:", L.eval("_VERSION"))
assert L.eval("_VERSION") == "Lua 5.1"
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
  f._shown=false; f.IsShown=function(self) return self._shown end
  f.Show=function(self) if not self._shown then self._shown=true; if self._OnShow then self._OnShow(self) end end end
  f.Hide=function(self) self._shown=false end
  f.SetShown=function(self, v) if v then self:Show() else self:Hide() end end
  frames[#frames+1]=f; if name then _G[name]=f end; return f end
function fire(event, ...) for _,f in ipairs(frames) do if f._events[event] and f._OnEvent then f._OnEvent(f, event, ...) end end end
function geterrorhandler() return function(e) error(e) end end
UIParent = {}; UISpecialFrames = {}; tinsert = table.insert
SlashCmdList = {}
C_Timer = { After = function(_, fn) fn() end }
WOW_PROJECT_ID = 99
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.60.1", "70205", "Oct 2 2026", 16001 end
function UnitClass() return "Rogue", "ROGUE" end
function UnitRace() return "Human","Human" end
function UnitLevel() return 30 end
function UnitFullName() return "Tester","Realm" end
function UnitName() return "Tester" end
function UnitExists() return true end
-- Classic-style talents: 3 tabs, combat has most points
TABS = { {"Assassination", {{"Malice",0,5},{"Mutilate",0,1}}}, {"Combat", {{"Hack and Slash",5,5},{"Restless Blades",1,1}}}, {"Subtlety", {{"Hemorrhage",0,1}}} }
function GetNumTalentTabs() return #TABS end
function GetTalentTabInfo(t) return 100+t, TABS[t][1], "desc" end
function GetNumTalents(t) return #TABS[t][2] end
function GetTalentInfo(t,i) local x=TABS[t][2][i] return x[1], "icon", 1, i, x[2], x[3] end
-- Items
-- class/sub: Enum.ItemClass and subclass (4/2 leather, 4/4 plate, 2/15 dagger, 2/7 sword)
ITEMS = {
 ["item:1001:0:0"] = { equip="INVTYPE_HEAD", class=4, sub=2, stats={ITEM_MOD_AGILITY_SHORT=10, ITEM_MOD_STAMINA_SHORT=8}, tip={"Cap", "Equip: Improves your chance to hit by 1%."} },
 ["item:1002:0:0"] = { equip="INVTYPE_HEAD", class=4, sub=2, stats={ITEM_MOD_AGILITY_SHORT=14, ITEM_MOD_ATTACK_POWER_SHORT=20}, tip={"Better Cap"}, sell=120 },
 ["item:1003:0:0"] = { equip="INVTYPE_HEAD", class=4, sub=2, stats={ITEM_MOD_AGILITY_SHORT=30}, tip={"Future Cap"}, req=40, sell=500 },
 ["item:3001:0:0"] = { equip="INVTYPE_HEAD", class=4, sub=4, stats={ITEM_MOD_AGILITY_SHORT=50}, tip={"Plate Helm"}, sell=900 },
 ["item:2001:1900:0"] = { equip="INVTYPE_WEAPON", class=2, sub=15, stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=20}, tip={} },
 ["item:2002:0:0"] = { equip="INVTYPE_WEAPON", class=2, sub=7, stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=25}, tip={"Sword"} },
 ["item:2003:0:0"] = { equip="INVTYPE_WEAPON", class=2, sub=15, stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=22}, tip={"Dagger"} },
}
INV = { [1] = "item:1001:0:0", [16] = "item:2001:1900:0" }
function GetInventoryItemLink(unit, slot) return INV[slot] end
local function item(l) return ITEMS[l] or {} end
C_Item = { GetItemStats = function(l) return ITEMS[l] and ITEMS[l].stats end,
           GetItemInfoInstant = function(l) local i = item(l) return 1, "Armor", "Cloth", i.equip, 0, i.class, i.sub end,
           GetItemInfo = function(l) local i = ITEMS[l] if not i or i.uncached then return nil end
             return "name", l, 2, 20, i.req or 1, "Armor", "Leather", 1, i.equip, 0, i.sell or 0, 4, 2, i.bind end }
-- Main hand 34 damage every 1.7 s: 20 DPS, so 1% of damage = 2.8 AP.
function UnitDamage() return 34, 34, 17, 17, 0, 0, 1 end
function UnitAttackSpeed() return 1.7, 1.7 end
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
        fn = L.eval("function(src, name) return assert(loadstring(src, '@'..name)) end")(p.read_text(), str(p))
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
# Combat at level 30, 20 main-hand DPS. Scores are in attack-power equivalents.
PCT = 0.14 * 20                                   # AP worth 1% of damage
AGI_PER_CRIT = 7.59 + (29.0 - 7.59) * (30 - 19) / (60 - 19)
AGI = 1 + 1.0 * PCT / AGI_PER_CRIT                # 1 AP + its share of crit
CAP = 10 * AGI + 8 * 0.2 + 1 * 1.2 * PCT          # agi, sta, 1% hit
BETTER_CAP = 14 * AGI + 20
assert abs(cmp[0] - (BETTER_CAP - CAP)) < 1e-9, (cmp, BETTER_CAP - CAP)
print("enchant id:", L.eval("function(ns) return ns.API.GetEnchantID('item:2001:1900:0') end")(ns))
L.globals().SlashCmdList.GEARWRIGHT("spec subtlety")
print("override:", L.eval("function(ns) return ns.Spec.Detect() end")(ns))
L.globals().SlashCmdList.GEARWRIGHT("")  # open window -> OnShow -> buildText
L.execute("""
function SCREEN(ns)
  local out = { ns.UI.frame.spec.text or "" }
  for _, tab in ipairs(ns.UI.TAB_ORDER) do
    local rows, msg = ns.UI.BuildRows(tab)
    out[#out + 1] = "[" .. tab .. "]" .. (msg and (" " .. msg) or "")
    for _, r in ipairs(rows) do
      out[#out + 1] = table.concat({ r.sub or "", r.title or "", r.value or "" }, "  ")
    end
  end
  return table.concat(out, "\\n")
end
""")
txt = L.globals().SCREEN(ns)
print("---- main window ----"); print(txt)
for want in ("Spec:|r Subtlety", "(override)", "Stat weights are provisional", "Head", "item:1001:0:0",
             "No recommended build for this spec yet.", "Best: Superior Striking", "No dungeon loot known yet"):
    assert want in txt, want
L.globals().SlashCmdList.GEARWRIGHT("spec auto")  # refreshes the open window
txt = L.globals().SCREEN(ns)
assert "Spec:|r Combat" in txt and "(talents)" in txt, txt
# No talent points yet (the first comes at level 10): advise for the leveling spec.
L.execute("SAVED_TABS = TABS; TABS = { {'Assassination', {}}, {'Combat', {}}, {'Subtlety', {}} }")
L.globals().fire("CHARACTER_POINTS_CHANGED")
assert list(L.eval("function(ns) return {ns.Spec.Detect()} end")(ns).values()) == ["combat", "leveling"]
txt = L.globals().SCREEN(ns)
assert "Spec:|r Combat" in txt and "the first comes at level 10" in txt, txt
L.execute("TABS = SAVED_TABS")
L.globals().fire("CHARACTER_POINTS_CHANGED")
L.globals().SlashCmdList.GEARWRIGHT("")  # toggle closed
assert not L.eval("function(ns) return ns.UI.frame:IsShown() end")(ns)

# Regression: an equipped item whose stats can't be read is not an empty slot.
L.execute("INV[1] = 'item:9999:0:0'")
r = L.eval("function(ns) return {ns.Advisor.CompareToEquipped('item:1002:0:0')} end")(ns)
assert r[1] is None and r[2] == "equipped-unreadable", list(r.values())
L.execute("INV[1] = nil")
r = L.eval("function(ns) return ns.Advisor.CompareToEquipped('item:1002:0:0') end")(ns)
assert abs(r[0] - BETTER_CAP) < 1e-9 and r[3] == 0, r  # truly empty slot: full score is the upgrade
L.execute("INV[1] = 'item:1001:0:0'")

# Regression: a bonus in both GetItemStats and an "Equip:" line counts once.
ap, hit = L.eval("""function(ns)
  local s = ns.Stats.AddTooltipEffects(ns.Stats.FromRaw({ITEM_MOD_ATTACK_POWER_SHORT=20}),
    {"Equip: +20 Attack Power.", "Equip: Improves your chance to hit by 1%."})
  return s.ap, s.hit end""")(ns)
assert ap == 20 and hit == 1, (ap, hit)

# Gear checks ------------------------------------------------------------------
def compare(link):
    r = L.eval("function(ns, l) return {ns.Advisor.CompareToEquipped(l)} end")(ns, link)
    return [r[i] if i in r else None for i in range(1, 6)]
# A Rogue can't wear plate, whatever its stats.
assert compare("item:3001:0:0")[:2] == [None, "not-usable"]
# A dagger goes where it helps most: the empty off hand (DPS at half value)
# beats replacing the 20-DPS main-hand dagger.
d = compare("item:2003:0:0")
assert d[1] == 17 and abs(d[0] - 22 * 7) < 1e-9, d
# Main hand: a 25-DPS sword over the 20-DPS dagger is worth 5 x 14 AP for Combat...
L.execute("INV[17] = 'item:2003:0:0'")
d = compare("item:2002:0:0")
assert d[1] == 16 and abs(d[0] - 5 * 14) < 1e-9, d
# ...but Assassination needs a main-hand dagger (Backstab), so for it the sword
# can only replace the 22-DPS off-hand dagger, at half value.
L.eval("function(ns) ns.db.specOverride = 'assassination' end")(ns)
d = compare("item:2002:0:0")
assert d[1] == 17 and abs(d[0] - 3 * 7) < 1e-9, d
L.execute("ITEMS['item:2004:0:0'] = { equip='INVTYPE_WEAPONMAINHAND', class=2, sub=7, stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=30} }")
assert compare("item:2004:0:0")[:2] == [None, "wrong-weapon-type"]
L.eval("function(ns) ns.db.specOverride = false end")(ns)
L.execute("INV[17] = nil")
# One-handed axes: any Rogue can train them on Forever, talents or not.
L.execute("ITEMS['item:2005:0:0'] = { equip='INVTYPE_WEAPON', class=2, sub=0, stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=30} }")
L.execute("TABS[2][2][1][2] = 0")
L.globals().fire("CHARACTER_POINTS_CHANGED")
assert compare("item:2005:0:0")[0] > 0
# The unlock mechanism (a weapon type a talent or spell adds) still works:
# polearms behind Hack and Slash, as a made-up example.
L.execute("ITEMS['item:2008:0:0'] = { equip='INVTYPE_WEAPON', class=2, sub=6, stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=30} }")
L.eval("function(ns) ns.Data.ROGUE.unlocks = { { class = 2, subclass = 6, talent = 'Hack and Slash', spell = 200 } } end")(ns)
assert compare("item:2008:0:0")[:2] == [None, "not-usable"]
L.execute("TABS[2][2][1][2] = 5")
L.globals().fire("CHARACTER_POINTS_CHANGED")
assert compare("item:2008:0:0")[0] > 0
L.execute("TABS[2][2][1][2] = 0")
L.globals().fire("CHARACTER_POINTS_CHANGED")
L.execute("function IsPlayerSpell(id) return id == 200 end")
assert compare("item:2008:0:0")[0] > 0
L.execute("IsPlayerSpell = nil; TABS[2][2][1][2] = 5")
L.globals().fire("CHARACTER_POINTS_CHANGED")
L.eval("function(ns) ns.Data.ROGUE.unlocks = {} end")(ns)
# Dual Wield comes at level 10: before that a one-hand weapon only goes in the
# main hand, and an off-hand-only weapon can't be used yet.
L.execute("ITEMS['item:2006:0:0'] = { equip='INVTYPE_WEAPONOFFHAND', class=2, sub=15, stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=30} }")
assert compare("item:2006:0:0")[1] == 17
L.execute("UnitLevel = function() return 9 end")
assert compare("item:2006:0:0")[:2] == [None, "no-dual-wield"]
assert compare("item:2003:0:0")[1] == 16  # 22-DPS dagger: main hand only, not the empty off hand
L.execute("function IsPlayerSpell(id) return id == 674 end")
assert compare("item:2006:0:0")[1] == 17  # Dual Wield already known
L.execute("IsPlayerSpell = nil; UnitLevel = function() return 30 end")
# Tooltip: best slot first, the other hand after it, and what isn't scored.
L.execute("""
ITEMS['item:2007:0:0'] = { equip='INVTYPE_WEAPON', class=2, sub=15, stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=30, ITEM_MOD_INTELLECT_SHORT=2},
  tip={"Claw", "Chance on hit: Sends a shadowy bolt at the enemy causing 35 Shadow damage."} }
INV[17] = '|cnIQ2:|Hitem:2003::::|h[Pearl-handled Dagger]|h|r'
ITEMS[INV[17]] = ITEMS['item:2003:0:0']
""")
tip = list(L.eval("""function(ns) return ns.Tooltip.Lines('item:2007:0:0', ns.Advisor.CompareSlots('item:2007:0:0')) end""")(ns).values())
print("tooltip:", tip)
assert "+140.0|r in Main Hand over equipped" in tip[0] and "(Combat)" in tip[0], tip
assert tip[1].startswith("|cffaaaaaaOff Hand:|r") and "+56.0|r" in tip[1] and "over Pearl-handled Dagger" in tip[1], tip
assert tip[2] == "|cffaaaaaaNot counted: Intellect, chance on hit effect|r", tip
# Weapon skills: with only Daggers trained, a sword still scores but says to
# train One-Handed Swords first; a dagger doesn't.
L.execute("function IsPlayerSpell(id) return id == 1180 end")
train = L.eval("""function(ns) return ns.Advisor.CompareToEquipped('item:2002:0:0') ~= nil,
  ns.Advisor.TrainingNeeded('item:2002:0:0'), ns.Advisor.TrainingNeeded('item:2003:0:0') end""")(ns)
assert tuple(train) == (True, "One-Handed Swords"), tuple(train)  # dagger: nil
tip = list(L.eval("""function(ns) return ns.Tooltip.Lines('item:2002:0:0', ns.Advisor.CompareSlots('item:2002:0:0')) end""")(ns).values())
assert "|cffff9900Train One-Handed Swords first: Woo Ping, Stormwind (inside the Just Maces shop)|r" in tip, tip
# ...and where: the weapon master gets a pin on the world map, drawn when the
# map shows Stormwind. /gearwright train lists every skill still to train.
L.execute("""
local canvas = CreateFrame("Frame"); canvas.GetWidth = function() return 1000 end; canvas.GetHeight = function() return 600 end
WorldMapFrame = CreateFrame("Frame"); WorldMapFrame._shown = true
WorldMapFrame.GetCanvas = function() return canvas end
WorldMapFrame.GetMapID = function(self) return self.mapID end
WorldMapFrame.SetMapID = function(self, id) self.mapID = id end
PINPOINTS = {}
REAL_CREATEFRAME = CreateFrame
local cf = CreateFrame
CreateFrame = function(kind, name, parent, ...) local f = cf(kind, name, parent, ...)
  f.SetPoint = function(self, a, rel, b, x, y) PINPOINTS[#PINPOINTS + 1] = { x, y } end
  return f end
printed = {}
""")
L.eval("function(ns) ns.Trainers.Show('One-Handed Swords') end")(ns)
pins = L.eval("function() local p = PINPOINTS[#PINPOINTS] return WorldMapFrame.mapID, p[1], p[2] end")()
assert pins[0] == 1453 and abs(pins[1] - 639) < 1e-6 and abs(pins[2] + 414) < 1e-6, tuple(pins)  # 63.9, 69.0
assert L.globals().printed[1].endswith("train One-Handed Swords with Woo Ping in Stormwind, inside the Just Maces shop"), L.globals().printed[1]  # checked
# An Alliance Rogue standing in Stormwind: Woo Ping (here) first, then Ironforge
# on the same continent, Darnassus (other continent) last; the map opens here.
L.execute("""printed = {}; WorldMapFrame.mapID = nil
function UnitFactionGroup() return "Alliance" end
local parents = { [1453] = 1429, [1429] = 1415, [1455] = 1426, [1426] = 1415, [1457] = 1414 }
C_Map = { GetBestMapForUnit = function() return 1453 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
  GetMapInfo = function(id) return { mapType = (id == 1415 or id == 1414) and 2 or 3, parentMapID = parents[id] } end }""")
L.globals().SlashCmdList.GEARWRIGHT("train")
out = list(L.globals().printed.values())
print("train:", out)
assert out[1] == "  Woo Ping, Stormwind (inside the Just Maces shop) |cff40ff40(here)|r: Crossbows, One-Handed Swords", out
# (axes too: the mock has Hack and Slash 5/5; only Daggers is trained)
assert out[2] == "  Buliwyf Stonehand, Ironforge (in the Timberline Arms weapon shop): Fist Weapons, Guns, One-Handed Axes, One-Handed Maces", out
assert out[3] == "  Bixi Wobblebonk, Ironforge (in the Timberline Arms weapon shop): Thrown", out
assert out[4] == "  Ilyenia Moonfire, Darnassus |cff999999(other continent)|r: Bows", out
assert L.eval("function() return WorldMapFrame.mapID end")() == 1453
L.execute("UnitFactionGroup = nil; C_Map = nil")
# Opening a weapon master saves where it really is, and that wins over Classic's.
L.execute("""
function GetNumTrainerServices() return 2 end
function GetTrainerServiceInfo(i) return ({ "One-Handed Swords", "Staves" })[i], "", "available" end
function UnitGUID() return "Creature-0-1-0-1-11867-0001" end
function UnitName(u) return u == "npc" and "Woo Ping" or "Tester" end
C_Map = { GetBestMapForUnit = function() return 1453 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.6, 0.7 end } end }
""")
L.globals().fire("TRAINER_SHOW")
seen = L.eval("function(ns) local t = ns.Trainers.For('One-Handed Swords')[1] return t.x, t.y, t.seen ~= nil, #t.skills end")(ns)
assert tuple(seen) == (0.6, 0.7, True, 6), tuple(seen)  # its 2 listed + the seed's other 4
L.execute("""GetNumTrainerServices, GetTrainerServiceInfo, UnitGUID, C_Map = nil, nil, nil, nil
function UnitName() return "Tester" end; WorldMapFrame._shown = false; CreateFrame = REAL_CREATEFRAME""")
L.eval("function(ns) ns.MapPins.Clear(); ns.db.trainers = nil end")(ns)
# Weapon skill levels: training Swords while Gearwright watches puts it at 1/150
# (level 30): the sword warns you'll miss until it's levelled. The character
# sheet's "Swords:  145/150" line, once seen in a tooltip, clears the warning.
L.eval("function(ns) ns.db.weaponSkills = nil end")(ns)
L.execute("function IsPlayerSpell(id) return id == 1180 end")
L.eval("function(ns) ns.Advisor.Context() end")(ns)  # first look: Daggers known, level unknown
L.execute("function IsPlayerSpell(id) return id == 1180 or id == 201 end")
low = L.eval("function(ns) return ns.Advisor.SkillTooLow('item:2002:0:0'), ns.Advisor.SkillTooLow('item:2003:0:0') end")(ns)
assert tuple(low) == ("One-Handed Swords 1/150", None), low  # the dagger's level isn't known: no warning
tip = list(L.eval("""function(ns) return ns.Tooltip.Lines('item:2002:0:0', ns.Advisor.CompareSlots('item:2002:0:0')) end""")(ns).values())
assert "|cffff9900One-Handed Swords 1/150: you'll miss a lot until it's levelled (fight with this weapon type)|r" in tip, tip
assert L.eval("function(ns) return ns.WeaponSkills.ReadLines({ 'Main Hand', 'DPS:  20.0', '|cffffffffSwords:  145/150|r' }) end")(ns) == 1
assert L.eval("function(ns) return ns.Advisor.SkillTooLow('item:2002:0:0') end")(ns) is None
L.eval("function(ns) ns.WeaponSkills.ReadLines({ 'Swords:  40/150' }) end")(ns)
assert L.eval("function(ns) return ns.Advisor.SkillTooLow('item:2002:0:0') end")(ns) == "One-Handed Swords 40/150"
L.eval("function(ns) ns.db.weaponSkills = nil end")(ns)
L.execute("IsPlayerSpell = nil")
L.execute("INV[17] = nil")
# Items above your level still score, and say when you can wear them.
d = compare("item:1003:0:0")
assert d[0] > 0 and d[4] == 40, d
assert compare("item:1002:0:0")[4] is None
# Weights follow level: agility is worth more crit per point at 19 than at 60.
lo, hi = L.eval("""function(ns)
  local c = ns.Data.ROGUE
  return ns.Weights.Build(c, "combat", {level = 19, mainHandDps = 20}).agi,
         ns.Weights.Build(c, "combat", {level = 60, mainHandDps = 20}).agi end""")(ns)
assert abs(lo - (1 + PCT / 7.59)) < 1e-9 and abs(hi - (1 + PCT / 29.0)) < 1e-9, (lo, hi)

# Quest rewards: the upgrade is picked, the plate helm is ignored.
L.execute("""
QUEST = { "item:3001:0:0", "item:1002:0:0", "item:1003:0:0" }
function GetNumQuestChoices() return #QUEST end
function GetQuestItemLink(kind, i) return QUEST[i] end
""")
def last_print():
    p = L.globals().printed
    return p[len(p)]
L.globals().fire("QUEST_COMPLETE")
assert "take reward 2: item:1002:0:0" in last_print(), last_print()
# No upgrade: say which reward sells for the most.
L.execute('QUEST = { "item:3001:0:0", "item:1001:0:0" }')
L.globals().fire("QUEST_DETAIL")
assert "no upgrade among the rewards; item:3001:0:0 sells for the most (0g 9s 0c)" in last_print(), last_print()
# Loot window and need/greed rolls.
L.execute("""
LOOT = { "item:1001:0:0", "item:1002:0:0", "item:1002:0:0" }
function GetNumLootItems() return #LOOT end
function GetLootSlotLink(i) return LOOT[i] end
function GetLootRollItemLink() return "item:1002:0:0" end
""")
n = len(L.globals().printed)
L.globals().fire("LOOT_OPENED")
assert len(L.globals().printed) == n + 1 and "upgrade: item:1002:0:0" in last_print(), last_print()
L.globals().fire("START_LOOT_ROLL", 7)
assert "worth a Need" in last_print(), last_print()
L.globals().SlashCmdList.GEARWRIGHT("notices")
n = len(L.globals().printed)
L.globals().fire("LOOT_OPENED")
assert len(L.globals().printed) == n
L.globals().SlashCmdList.GEARWRIGHT("notices")

# Forever ratings: stored as rating, shown as a fixed % (Wowhead, Mask of the
# Unforgiven: 20 hit rating = "2.0%", 14 crit rating = "1.0%"). Counted once, in %.
hit, crit = L.eval("""function(ns)
  local s = ns.Stats.AddTooltipEffects(
    ns.Stats.FromRaw({ITEM_MOD_HIT_RATING_SHORT = 20, ITEM_MOD_CRIT_RATING_SHORT = 14}),
    {"Equip: Improves your chance to hit by 2.0%.", "Equip: Improves your chance to get a critical strike by 1.0%."})
  return s.hit, s.crit end""")(ns)
assert (hit, crit) == (2, 1), (hit, crit)
# Tooltip-only, with Forever's decimal wording.
s = L.eval("""function(ns)
  return ns.Stats.AddTooltipEffects({}, {"Equip: Improves your chance to hit by 0.3%.",
    "Equip: Increases your attack speed and casting speed by 1.0%.",
    "Equip: Reduces chance to be Dodged or Parried by 1.0%.",
    "Equip: Improves your chance to get a critical strike with missile weapons by 1%."}) end""")(ns)
assert (s["hit"], s["haste"], s["expertise"], s["crit"]) == (0.3, 1, 1, None), dict(s)

# Real beta items (/gwp items): each rating converts to exactly the % its own
# tooltip shows, and the rating and tooltip line are counted once together.
import json, re
beta_items = json.loads((R / "data" / "probe" / "2026-10-03-items.json").read_text())["items"]
EXPECT = {"hit": r"chance to hit by ([\d.]+)%", "crit": r"critical strike by ([\d.]+)%",
          "haste": r"attack speed.* by ([\d.]+)%", "expertise": r"Dodged or Parried by ([\d.]+)%"}
read = L.eval("""function(ns, raw, tip)
  local s = ns.Stats.AddTooltipEffects(ns.Stats.FromRaw(raw), tip)
  return s.hit, s.crit, s.haste, s.expertise, s.ap end""")
for item_id, item in beta_items.items():
    got = dict(zip(("hit", "crit", "haste", "expertise", "ap"),
                   read(ns, L.table_from(item["stats"]), L.table_from(item["equip"]))))
    for key, pattern in EXPECT.items():
        m = [re.search(pattern, line) for line in item["equip"]]
        want = sum(float(x.group(1)) for x in m if x) or None
        assert (got[key] is None and want is None) or abs(got[key] - want) < 1e-9, (item["name"], key, got[key], want)
assert read(ns, L.table_from(beta_items["279899"]["stats"]), L.table_from(beta_items["279899"]["equip"]))[4] == 3

# Traits talents, replayed from a real Forever beta capture --------------------
# Level 19 Rogue with 10 points in Assassination (Malice 5, Ruthlessness 3,
# Remorseless Attacks 2). Classic talent API is absent on Forever.
import json
cap = json.loads((R / "data" / "probe" / "2026-10-03-assassination.json").read_text())
traits = cap["snapshots"][0]["sections"]["talents"]["traits"]
nodes = {n["nodeID"]: n for n in traits["trees"][0]["nodes"]}
L.globals().TRAIT_NODES = L.table_from({k: n["node"] for k, n in nodes.items()}, recursive=True)
# Fake entry -> definition -> spell chain keyed by entryID.
L.globals().TRAIT_SPELLS = L.table_from({n["node"]["entryIDs"][0]: n["spellID"] for n in nodes.values()})
L.globals().SPELL_NAMES = L.table_from({n["spellID"]: n["spellName"]["values"][0] for n in nodes.values()})
L.globals().TRAIT_NODE_IDS = L.table_from(list(nodes))
L.execute("""
GetNumTalentTabs, GetTalentTabInfo, GetNumTalents, GetTalentInfo = nil, nil, nil, nil
NODE_READS = 0
C_ClassTalents = { GetActiveConfigID = function() return 9917893 end }
C_Traits = {
  GetConfigInfo = function() return { treeIDs = { 1111 } } end,
  GetTreeNodes = function() return TRAIT_NODE_IDS end,
  GetNodeInfo = function(_, id) NODE_READS = NODE_READS + 1; return TRAIT_NODES[id] end,
  GetEntryInfo = function(_, id) return { definitionID = id } end,
  GetDefinitionInfo = function(id) return { spellID = TRAIT_SPELLS[id] } end,
}
C_Spell = { GetSpellName = function(id) return SPELL_NAMES[id] end, GetSpellDescription = function() return "Permanently enchant" end }
""")
L.globals().fire("TRAIT_CONFIG_UPDATED")  # drop the cached classic read
spec, how = L.eval("function(ns) return ns.Spec.Detect() end")(ns)
print("traits spec:", spec, how)
assert spec == "assassination" and how == "talents", (spec, how)
tabs = L.eval("""function(ns)
  local t = ns.API.ReadTalents(ns.Data.ROGUE.traitTabGroups)
  local o = {}
  for i, tab in ipairs(t.tabs) do o[i] = { tab.points, #tab.talents, tab.talents[1].name } end
  return t.source, o end""")(ns)
source, tabs = tabs
tabs = [tuple(t.values()) for t in tabs.values()]
print("traits tabs:", source, tabs)
assert source == "traits"
assert tabs == [(10, 17, "Improved Gouge"), (0, 17, "Improved Eviscerate"), (0, 19, "Camouflage")], tabs
# Cached: more reads don't touch the API until a talent event fires.
reads = L.globals().NODE_READS
L.eval("function(ns) ns.Spec.Detect(); ns.Spec.Detect() end")(ns)
assert L.globals().NODE_READS == reads
L.globals().fire("PLAYER_TALENT_UPDATE")
L.eval("function(ns) ns.Spec.Detect() end")(ns)
assert L.globals().NODE_READS == reads + len(nodes)
# The talent advisor compares against a build by name.
L.execute("""ROGUE_BUILD = { ["Malice"] = 5, ["Murder"] = 2, ["Ruthlessness"] = 3 }""")
rows = L.eval("""function(ns)
  ns.Data.ROGUE.builds.assassination.talents = ROGUE_BUILD
  local rows = ns.Advisor.TalentReport()
  ns.Data.ROGUE.builds.assassination.talents = {}
  local o = {} for i, r in ipairs(rows) do o[i] = r.name .. " " .. r.have .. "/" .. r.want end
  return table.concat(o, ", ") end""")(ns)
print("talent report:", rows)
assert rows == "Murder 0/2", rows
# Window shows the detected spec and refreshes on a talent event.
L.globals().SlashCmdList.GEARWRIGHT("")
L.globals().fire("TRAIT_CONFIG_UPDATED")
txt = L.globals().SCREEN(ns)
assert "Spec:|r Assassination" in txt and "(talents)" in txt, txt
L.globals().SlashCmdList.GEARWRIGHT("")

# Real beta cloak: "+3 Attack Power" is in GetItemStats AND an Equip: line,
# and the humanoid-only AP line must not count.
gear = cap["snapshots"][0]["sections"]["gear"]
cloak = gear["15"]
ap = L.eval("""function(ns, raw, tip)
  return ns.Stats.AddTooltipEffects(ns.Stats.FromRaw(raw), tip).ap end""")(
    ns, L.table_from(cloak["stats"]["values"][0]), L.table_from(cloak["tooltip"]))
print("beta cloak AP:", ap)
assert ap == 3, ap
assert L.eval("""function(ns)
  return ns.Stats.AddTooltipEffects({}, {"Equip: +4 Attack Power against Humanoids."}).ap end""")(ns) is None
# Enchant IDs parse out of the new-style colored links.
assert L.eval("function(ns, l) return ns.API.GetEnchantID(l) end")(ns, gear["7"]["link"].replace("\\u007c", "|")) == 8481

# Enchants ---------------------------------------------------------------------
# GetItemStats leaves the enchant out; it's read from the "Enchanted:" line.
ench = L.eval("""function(ns, tip) local s, t = ns.Stats.FromEnchantLine(tip) return s.sta, s.armor, t end""")(
    ns, L.table_from(gear["7"]["tooltip"]))
assert tuple(ench) == (2, 16, "Stamina +2 and Armor +16"), ench
assert L.eval("""function(ns) return ns.Stats.FromEnchantLine({"Enchanted: +3 Agility"}).agi end""")(ns) == 3
assert L.eval("""function(ns) return ns.Stats.FromEnchantLine({"Sword", "+2 Agility"}) end""")(ns) is None
assert L.eval("""function(ns) local s, t = ns.Stats.FromEnchantLine({"Enchanted: Crusader"}) return next(s), t end""")(ns) == (None, "Crusader")

# Flat weapon damage is DPS divided by the weapon's speed (1.7 s in the mock).
wd = L.eval("""function(ns) local w = ns.Advisor.Context().weights
  return ns.Weights.For(w, "weaponDamage", 16), ns.Weights.For(w, "weaponDamage", 17) end""")(ns)
assert abs(wd[0] - 14 / 1.7) < 1e-9 and abs(wd[1] - 7 / 1.7) < 1e-9, wd

# The data file is what the tool makes from the saved scan: nobody edited it by hand.
import subprocess, sys
gen = OUT / "Enchants.lua"
subprocess.run([sys.executable, str(R / "tools" / "enchants_from_probe.py"),
                str(R / "data" / "probe" / "2026-10-03-professions.json"), "-o", str(gen)],
               check=True, capture_output=True)
assert gen.read_text() == (R / "Gearwright" / "Data" / "Enchants.lua").read_text(), "rerun tools/enchants_from_probe.py"
from importlib.util import spec_from_file_location, module_from_spec
_m = spec_from_file_location("ench", R / "tools" / "enchants_from_probe.py"); ench_tool = module_from_spec(_m); _m.loader.exec_module(ench_tool)
assert ench_tool.parse("Permanently enchant a cloak so that it increases the wearer's Agility by 3.") == {"agi": 3}
assert ench_tool.parse("Permanently enchant a piece of chest armor to increase all stats by 4, and Nature Resistance by 15.")["agi"] == 4
assert ench_tool.parse("Permanently enchant a Melee Weapon to do 6 additional points of damage to Beasts.") == {}
assert ench_tool.parse("Permanently enchant a melee weapon so that often when attacking in melee it heals for 75 to 125 and increases Strength by 100 for 15 sec.") == {}

# Report: the bracer's +3 Agility could be +9; the chest's armor kit could be
# Greater Stats; the head takes no enchant; empty slots are skipped.
L.execute("""
ITEMS["item:5001:0:0"] = { equip="INVTYPE_WRIST", class=4, sub=2, stats={ITEM_MOD_AGILITY_SHORT=2}, tip={"Bracers", "Enchanted: Agility +3"} }
ITEMS["item:5002:0:0"] = { equip="INVTYPE_CHEST", class=4, sub=2, stats={ITEM_MOD_AGILITY_SHORT=2}, tip={"Vest", "Enchanted: Stamina +2 and Armor +16"} }
INV[9], INV[5] = "item:5001:0:0", "item:5002:0:0"
""")
rows = L.eval("""function(ns) local rows, ctx = ns.Advisor.EnchantReport() local out = {}
  for i, r in ipairs(rows) do out[i] = {r.slot, r.best.name, r.best.score, r.current or false, r.gain, r.ok} end
  return out, ctx.weights.agi, ctx.weights.sta, ctx.weights.str end""")(ns)
rows, agi, sta, strw = [list(r.values()) for r in rows[0].values()], rows[1], rows[2], rows[3]
print("enchant report:", rows)
assert [r[0] for r in rows] == [5, 9, 16], rows
chest, wrist, mh = rows
assert chest[1] == "Greater Stats" and abs(chest[4] - (4 * agi + 4 * strw + 4 * sta - 2 * sta)) < 1e-9, chest
assert wrist[1] == "Agility" and abs(wrist[4] - 6 * agi) < 1e-9 and wrist[5] is False, wrist
assert mh[1] == "Superior Striking" and mh[3] is False and abs(mh[4] - 5 * 14 / 1.7) < 1e-9, mh
# Already the best: OK.
L.execute('ITEMS["item:5001:0:0"].tip = {"Bracers", "Enchanted: Agility +9"}')
ok = L.eval("function(ns) local rows = ns.Advisor.EnchantReport() return rows[2].ok end")(ns)
assert ok is True
L.execute("INV[9], INV[5] = nil, nil")

# Crafting ---------------------------------------------------------------------
# Recipe 1 makes the better cap; 2 is above level 35; 3 is plate; 4 makes
# nothing; 5's item isn't cached until asked for.
L.execute("""
for _, id in ipairs({1002, 1003, 3001}) do ITEMS["item:" .. id] = ITEMS["item:" .. id .. ":0:0"] end
ITEMS["item:1005"] = { equip="INVTYPE_HEAD", class=4, sub=2, stats={ITEM_MOD_AGILITY_SHORT=40}, tip={"Crafted Cap"}, uncached=true }
C_Item.RequestLoadItemDataByID = function(id) if ITEMS["item:" .. id] then ITEMS["item:" .. id].uncached = nil end end
CRAFT_OUTPUT = { 1002, 1003, 3001, false, 1005 }
RECIPES = { 1, 2, 3, 4, 5 }
C_TradeSkillUI = { GetAllRecipeIDs = function() return RECIPES end,
  GetRecipeInfo = function(id) return { name = "recipe " .. id, learned = id == 1 } end,
  GetRecipeSchematic = function(id) return { outputItemID = CRAFT_OUTPUT[id] or nil } end,
  GetBaseProfessionInfo = function() return { professionName = "Leatherworking" } end }
printed = {}
""")
crafted = L.eval("""function(ns) ns.Notices.Craft() local rows = ns.Advisor.CraftReport() local out = {}
  for i, r in ipairs(rows) do out[i] = {r.recipeID, r.delta, r.learned} end return out end""")(ns)
crafted = [list(r.values()) for r in crafted.values()]
cap_delta = L.eval("function(ns) return ns.Advisor.CompareToEquipped('item:1002:0:0') end")(ns)[0]
print("craft:", crafted)
assert [r[0] for r in crafted] == [5, 1] and abs(crafted[1][1] - cap_delta) < 1e-9, crafted
out = "\n".join(L.globals().printed.values())
assert "reading 1 crafted items" in out and "crafted upgrades:" in out, out
assert "learn the recipe (Leatherworking)" in out and "you can craft it (Leatherworking)" in out, out
# Professions you don't have still count: the 25-DPS sword over the 20-DPS
# dagger is an upgrade to have crafted. Once GetProfessions says you're a
# blacksmith it's yours to check; opening Blacksmithing says the recipe isn't learned.
L.execute("""
ITEMS["item:2002"] = ITEMS["item:2002:0:0"]
CRAFT_OUTPUT[6] = 2002
""")
L.eval("""function(ns) SAVED_CRAFTED = ns.Data.CRAFTED
  ns.Data.CRAFTED = { professions = { "Blacksmithing" }, recipes = { { 1, 6, 2002, "Sword" } } } end""")(ns)
def sword():
    return L.eval("""function(ns) local rows = ns.Advisor.CraftReport()
      for _, r in ipairs(rows) do if r.itemID == 2002 then return r.status, ns.Advisor.CraftStatusText(r) end end end""")(ns)
L.execute("RECIPES = {}")  # Leatherworking window closed
assert sword() == ("order", "have it crafted (Blacksmithing)"), sword()
L.execute("""function GetProfessions() return 1, 2 end
function GetProfessionInfo(i) return ({ "Leatherworking", "Blacksmithing" })[i], "icon", 50 end""")
assert sword()[0] == "yours", sword()
L.execute("""RECIPES = { 6 }
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionName = "Blacksmithing" } end""")
L.globals().fire("TRADE_SKILL_SHOW")
L.execute("RECIPES = {}; printed = {}")
assert sword()[0] == "learn", sword()
# An alt on this realm who knows the recipe can make it for you; one on another
# realm can't mail it, and a bind-on-pickup item can't be passed on at all.
L.eval("""function(ns)
  ns.db.recipes["Smithy-Realm"] = { Blacksmithing = { recipes = { { recipeID = 6, itemID = 2002, learned = true } } } }
  ns.db.characters["Smithy-Realm"] = { name = "Smithy", realm = "Realm" }
  ns.db.recipes["Faraway-Other"] = { Blacksmithing = { recipes = { { recipeID = 6, itemID = 2002, learned = true } } } }
  ns.db.characters["Faraway-Other"] = { name = "Faraway", realm = "Other" } end""")(ns)
assert sword() == ("alt", "Smithy can craft it (Blacksmithing)"), sword()
L.eval("function(ns) ns.db.recipes['Smithy-Realm'].Blacksmithing.recipes[1].learned = false end")(ns)
assert sword() == ("learn", "learn the recipe (Blacksmithing)"), sword()  # learning it yourself comes first
L.eval("function(ns) ns.db.recipes['Smithy-Realm'].Blacksmithing.recipes[1].learned = true end")(ns)
L.execute('ITEMS["item:2002"].bind = 1')
assert sword()[0] == "learn", sword()
L.execute('ITEMS["item:2002"].bind = nil')
L.eval("function(ns) ns.db.recipes['Smithy-Realm'] = nil; ns.db.recipes['Faraway-Other'] = nil end")(ns)
# Another player's linked profession: its recipes join the catalog of what
# Tailoring makes, but it isn't yours and its learned flags aren't yours.
L.execute("""CRAFT_OUTPUT[7] = 1003; RECIPES = { 7 }
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionName = "Tailoring" } end
C_TradeSkillUI.IsTradeSkillLinked = function() return true, "Bob" end""")
L.globals().fire("TRADE_SKILL_SHOW")
linked = L.eval("""function(ns) local me = ns.db.recipes[ns.Professions.CharKey()]
  return me.Tailoring == nil, ns.db.catalog.Tailoring[1003] ~= nil, me.Blacksmithing ~= nil end""")(ns)
assert tuple(linked) == (True, True, True), tuple(linked)
L.execute("C_TradeSkillUI.IsTradeSkillLinked = nil; RECIPES = {}")
L.globals().SlashCmdList.GEARWRIGHT("craft")
out = "\n".join(L.globals().printed.values())
assert "learn the recipe (Blacksmithing)" in out and "learn the recipe (Leatherworking)" in out, out
L.execute("GetProfessions, GetProfessionInfo = nil, nil; printed = {}")
L.eval("function(ns) ns.db.recipes = nil; ns.db.catalog = nil; ns.Data.CRAFTED = nil end")(ns)
L.globals().SlashCmdList.GEARWRIGHT("craft")
assert "no recipes known yet" in L.globals().printed[1], L.globals().printed[1]
L.eval("function(ns) ns.Data.CRAFTED = SAVED_CRAFTED end")(ns)
L.execute("C_TradeSkillUI = nil")

# Dungeons ------------------------------------------------------------------------
# Forever Dungeon Journal's table, in its own shape: boss loot {id, name, slot,
# quality}, quest rewards {id, name, quality}. Gearwright only reads it.
L.execute("""
function UnitFactionGroup() return "Alliance" end
ForeverDungeonJournal_NS = { DB = {
  ["Hall of Thanes"] = { level = "13-20",
    bosses = { { name = "Faldrim Anvilmar", loot = { {1002, "Better Cap", "Head, Leather", 3}, {3001, "Plate Helm", "Head, Plate", 3} } },
               { name = "Trash Drops", trash = true, loot = { {1003, "Future Cap", "Head, Leather", 3} } } },
    quests = { { name = "The Restless Dead", faction = "Alliance", rewardItems = { {1005, "Crafted Cap", 3} } },
               { name = "Horde Only", faction = "Horde", rewardItems = { {2003, "Dagger", 3} } } } },
  ["The Deadmines"] = { level = "17-26", bosses = { { name = "Sneed", loot = { {1002, "Better Cap", "Head, Leather", 3} } } } },
} }
""")
L.eval("function(ns) ns.Sources.Reset() end")(ns)
dung = L.eval("""function(ns) local rows = ns.Advisor.DungeonReport() local out = {}
  for i, r in ipairs(rows) do out[i] = {r.itemID, #r.sources, ns.Sources.Describe(r.sources[1])} end return out end""")(ns)
dung = [list(r.values()) for r in dung.values()]
print("dungeon upgrades:", dung)
# 1005 (quest) and 1002 (two bosses) are upgrades; plate is unusable, 1003 is
# level 40 (beyond 5 levels ahead), the Horde quest is for the other faction.
assert [r[0] for r in dung] == [1005, 1002], dung
assert dung[0][2] == "quest The Restless Dead, Hall of Thanes (13-20)", dung
assert dung[1][1] == 2 and dung[1][2] == "Faldrim Anvilmar, Hall of Thanes (13-20)", dung
upg = L.eval("function(ns) local rows = ns.UI.BuildRows('upgrades') return #rows, rows[1].value, rows[2].sub end")(ns)
assert upg[0] == 2 and upg[1].startswith("+") and "(+1 more)" in upg[2], upg

# Gearwright's own table (from probe loot logs) works without that addon.
L.execute("ForeverDungeonJournal_NS = nil")
L.execute('ns_own = { { itemID = 1002, name = "Better Cap", dungeon = "The Deadmines", from = "Rhahk\'Zor", count = 3 } }')
own = L.eval("""function(ns) ns.Data.DUNGEON_LOOT = ns_own; ns.Sources.Reset()
  local rows = ns.Advisor.DungeonReport() local s = ns.Sources.For(1002)[1]
  ns.Data.DUNGEON_LOOT = {}; ns.Sources.Reset()
  return #rows, ns.Sources.Describe(s), ns.Sources.All() end""")(ns)
assert own[0] == 1 and own[1] == "Rhahk'Zor, The Deadmines" and own[2] is None, own

# Probe
# Character sheet + stats, shaped like the Forever beta: no GetCritChanceFromAgility,
# Agility's tooltip only exists on hover, Armor stores its text on the frame.
L.execute(r"""
function UnitStat(_, i) local v = ({33, 66, 56, 26, 29})[i] return v, v, 0, 0 end
CR_HIT_MELEE, CR_CRIT_MELEE = 6, 9
function GetCombatRating(id) return id == 6 and 12 or 0 end
function GetCombatRatingBonus(id) return id == 6 and 1.2 or 0 end
local tipLines, tipShown = {}, false
for i = 1, 10 do
  _G["GameTooltipTextLeft" .. i] = { GetText = function() return tipLines[i] end }
  _G["GameTooltipTextRight" .. i] = { GetText = function() return nil end }
end
GameTooltip = {
  Hide = function() tipLines, tipShown = {}, false end,
  AddLine = function(_, t) tipLines[#tipLines + 1] = t; tipShown = true end,
  IsShown = function() return tipShown end,
  NumLines = function() return #tipLines end,
}
local function text(t) return { GetText = function() return t end, GetObjectType = function() return "FontString" end } end
SHEET_OPEN = false  -- the character window starts closed, as after a login
local function frame(children, fields, regions, scripts)
  local f = fields or {}
  f.GetChildren = function() return unpack(children or {}) end
  f.GetRegions = function() return unpack(regions or {}) end
  f.IsVisible = function() return SHEET_OPEN end
  f.GetScript = function(_, name) return (scripts or {})[name] end
  return f
end
local agility = frame(nil, { GetName = function() return "StatsPaneAgility" end }, { text("Agility:"), text("66") }, {
  OnEnter = function()
    GameTooltip:AddLine("|cffffffffAgility 66 (49|cff20ff20+17|r)|r")
    GameTooltip:AddLine("Increases Critical Strike chance by 8.7%")
    GameTooltip:AddLine("Increases Attack Power by 66")
  end,
  OnLeave = function() GameTooltip:Hide() end })
-- Like Forever: CharacterStatsPane is a hidden leftover holding only Armor's
-- stored text; the stats you see are in another panel; item slots have no text.
local armor = frame(nil, { Label = text("Armor:"), Value = text("487"),
  tooltip = "|cffffffffArmor 487|r", tooltip2 = "Reduces Physical Damage taken by 19.46%" })
armor.IsVisible = function() return false end
CharacterStatsPane = frame({ armor })
CharacterStatsPane.IsVisible = function() return false end
local slot = frame(nil, nil, nil, { OnEnter = function()
  GameTooltip:AddLine("Pearl-handled Dagger"); GameTooltip.item = "item:5540" end })
GameTooltip.GetItem = function(self) return self.item end
local hide = GameTooltip.Hide
GameTooltip.Hide = function(self) self.item = nil; hide(self) end
-- Seen in the 17:14 capture: an empty slot and a model button whose font
-- strings are blank (nil) still show a plain tooltip on hover. Neither is a stat.
local emptySlot = frame(nil, nil, { text(nil) }, { OnEnter = function() GameTooltip:AddLine("Head") end })
local zoom = frame(nil, nil, { text(nil) }, { OnEnter = function() GameTooltip:AddLine("Zoom In") end })
-- The level line carries a hidden placeholder string that must not be read.
local hiddenText = text("Free Trial level cap reached.")
hiddenText.IsShown = function() return false end
local levelInfo = frame(nil, { GetName = function() return "PaperDollLevelInfo" end }, { text("Level 19"), hiddenText })
local statsPane = frame({ agility })
PaperDollFrame = frame({ levelInfo, CharacterStatsPane, statsPane, slot, emptySlot, zoom }, {
  HookScript = function(self, _, fn) self.onShow = fn end })
CharacterFrame = frame({ PaperDollFrame })
-- Like the beta client: right after ToggleCharacter the window doesn't report
-- visible yet; it does a moment later.
SHOW_LAG = 0
PaperDollFrame.IsVisible = function()
  if SHOW_LAG > 0 then SHOW_LAG = SHOW_LAG - 1; return false end
  return SHEET_OPEN
end
TOGGLES = 0
function ToggleCharacter()
  TOGGLES = TOGGLES + 1
  SHEET_OPEN = not SHEET_OPEN
  if SHEET_OPEN then SHOW_LAG = 1 end
  if SHEET_OPEN and PaperDollFrame.onShow then PaperDollFrame.onShow() end
end
""")
load_addon("GearwrightProbe","GearwrightProbe.toc")
L.globals().fire("ADDON_LOADED","GearwrightProbe"); L.globals().fire("PLAYER_LOGIN")
L.globals().SlashCmdList.GEARWRIGHTPROBE("all")  # window closed: /gwp all leaves it closed
assert L.eval("function() return TOGGLES, SHEET_OPEN end")() == (0, False)
assert any("character sheet not read" in str(x) for x in L.globals().printed.values())
L.globals().SlashCmdList.GEARWRIGHTPROBE("sheet")  # /gwp sheet opens it, reads it, closes it
assert L.eval("function() return TOGGLES, SHEET_OPEN end")() == (2, False)
dbg = L.eval("""function() local d = GearwrightProbeDB.snapshots[1].sections.sheetDebug
  return d.how, d.hovered, d.stored, d.map[1], d.map[2] end""")()
assert tuple(dbg) == ("opened by probe", 1, 1, "2 PaperDollLevelInfo: Level 19", "3 StatsPaneAgility: Agility: | 66"), tuple(dbg)
# With the window closed and no way to open it, an empty read keeps the earlier capture.
L.execute("local t = ToggleCharacter; ToggleCharacter = nil; SlashCmdList.GEARWRIGHTPROBE('sheet'); ToggleCharacter = t")
sheet = L.eval("""function() local s = GearwrightProbeDB.snapshots[1].sections.sheet
  local by = {} for _, r in ipairs(s) do by[r.label] = r end
  return #s, by["Agility:"].value, #by["Agility:"].hover, by["Armor:"].tooltip2, by["Agility:"].hover[3] end""")()
# Agility hovered in the visible pane, Armor's stored text from the hidden one;
# item slot, empty slot and model button skipped; no "<nil>" from blank right-hand tooltip text.
assert tuple(sheet) == (2, "66", 3, "Reduces Physical Damage taken by 19.46%", "Increases Attack Power by 66"), tuple(sheet)

# Items by ID: the server sends item data a moment after it's asked for, and
# never for an ID that doesn't exist.
L.execute("""
ITEMS["item:13404:0:0"] = { equip="INVTYPE_HEAD", class=4, sub=2, stats={ITEM_MOD_HIT_RATING_SHORT=20},
  tip={"Mask of the Unforgiven", "Equip: Improves your chance to hit by 2.0%."} }
local asked, byLink = {}, C_Item.GetItemInfo
C_Item.RequestLoadItemDataByID = function(id) asked[id] = (asked[id] or 0) end
C_Item.GetItemInfo = function(x)
  if type(x) ~= "number" then return byLink(x) end
  asked[x] = (asked[x] or 0) + 1
  if x ~= 13404 or asked[x] < 2 then return nil end
  return "Mask of the Unforgiven", "item:13404:0:0", 3, 57, 52
end
""")
L.globals().SlashCmdList.GEARWRIGHTPROBE("items 13404 424242")
mask = L.eval("""function() local r = GearwrightProbeDB.scans.items["13404"]
  return r.stats.values[1].ITEM_MOD_HIT_RATING_SHORT, r.tooltip[2], GearwrightProbeDB.scans.items["424242"] end""")()
assert tuple(mask) == (20, "Equip: Improves your chance to hit by 2.0%.", None), tuple(mask)
assert "items: read 1 of 2 (no data for 424242)" in L.globals().printed[len(L.globals().printed) - 1]

# Encounter Journal: instances, bosses, then loot once the client has it.
L.execute("""
local INST = { [false] = { {101, "The Deadmines"} }, [true] = { {201, "Molten Core"} } }
local SEL
function EJ_GetNumTiers() return 1 end
function EJ_GetLootFilter() return 0, 0 end
function EJ_GetInstanceByIndex(i, raid) local x = INST[raid][i] if x then return x[1], x[2] end end
function EJ_SelectInstance(id) SEL = id end
function EJ_GetEncounterInfoByIndex(i, id) if i <= 2 then return "Boss " .. i, "desc", id * 10 + i end end
function EJ_GetNumLoot() return SEL == 101 and 1 or 0 end
C_EncounterJournal = { GetLootInfoByIndex = function(i)
  return { itemID = 5193, name = "Cape of the Brotherhood", slot = "Back", armorType = "Cloth" } end }
""")
L.globals().SlashCmdList.GEARWRIGHTPROBE("ej")
ej = L.eval("""function() local e = GearwrightProbeDB.scans.ej
  return #e.instances, e.instances[1].name, #e.instances[1].bosses, e.instances[1].lootCount,
    e.instances[1].loot[1].values[1].name, e.instances[2].raid, e.instances[2].lootCount end""")()
assert tuple(ej) == (2, "The Deadmines", 2, 1, "Cape of the Brotherhood", True, 0), tuple(ej)
assert "loot listed for 1 of 2 instances" in L.globals().printed[len(L.globals().printed)]
# Like the beta: the tier listing is empty, but asking by journal ID works.
L.execute("""
local byIndex = EJ_GetInstanceByIndex
EJ_GetInstanceByIndex = function() return nil end
function EJ_GetInstanceInfo(id) if id == 63 then return "The Deadmines" end end
SlashCmdList.GEARWRIGHTPROBE("ej")
EJ_GetInstanceByIndex, EJ_GetInstanceInfo = byIndex, nil
""")
p = L.globals().printed
assert "1 tiers, 1 instances (by ID: 1 of 20)" in p[len(p) - 1], p[len(p) - 1]
assert L.eval("function() return GearwrightProbeDB.scans.ej.instances[1].byID end")()

# Regression: two professions' recipe scans must not overwrite each other.
L.execute("""
PROF = "Enchanting"
C_TradeSkillUI = { GetAllRecipeIDs = function() return {1, 2} end,
  GetRecipeInfo = function(id) return {name = "r"..id, learned = id == 1} end,
  GetRecipeSchematic = function(id) return {outputItemID = id == 2 and 4239 or nil} end,
  GetBaseProfessionInfo = function() return {professionName = PROF} end }
""")
L.globals().fire("TRADE_SKILL_SHOW")
L.execute("PROF = 'Leatherworking'"); L.globals().fire("TRADE_SKILL_SHOW")
L.execute("C_TradeSkillUI.GetBaseProfessionInfo = function() return nil end"); L.globals().fire("TRADE_SKILL_SHOW")
rec = L.eval("""function() local r = GearwrightProbeDB.scans["tradeskill:Enchanting"].recipes
  return r[1].learned, r[2].learned, r[2].outputItemID, r[1].desc end""")()
assert tuple(rec) == (True, False, 4239, "Permanently enchant"), tuple(rec)
keys = sorted(L.eval("function() local o={} for k in pairs(GearwrightProbeDB.scans) do o[#o+1]=k end return o end")().values())
assert keys == ["ej", "items", "tradeskill:3", "tradeskill:Enchanting", "tradeskill:Leatherworking"], keys
# Loot log: each corpse counts once; the NPC ID comes out of its GUID.
L.execute("""
LOOT = { "|cff1eff00|Hitem:5540::::|h[Pearl-handled Dagger]|h|r" }
function GetLootSourceInfo() return "Creature-0-4618-0-12-1732-000012345", 1 end
function GetInstanceInfo() return "The Deadmines", "party" end
function UnitGUID() return "Creature-0-4618-0-12-1732-000012345" end
function UnitName() return "Defias Squallshaper" end
""")
L.globals().fire("LOOT_OPENED"); L.globals().fire("LOOT_OPENED")
L.execute('function GetLootSourceInfo() return "Creature-0-4618-0-12-1732-000099999", 1 end')
L.globals().fire("LOOT_OPENED")
drop = L.eval("""function() local e = GearwrightProbeDB.scans.loot.items["5540"]
  local f = e.from["Creature:1732"] return e.name, f.count, f.where, f.name end""")()
assert tuple(drop) == ("Pearl-handled Dagger", 2, "The Deadmines", "Defias Squallshaper"), tuple(drop)
L.execute("LOOT = {}; GetLootSourceInfo, GetInstanceInfo, UnitGUID = nil, nil, nil; function UnitName() return 'Tester' end")
# Auction house full scan: gear gets its full record and lowest buyout; other
# items only a unit price; a gear item whose data never loads is counted.
L.execute("""
function time() return NOW or 100000 end
ITEMS[2002] = ITEMS["item:2002:0:0"]
ITEMS[7777] = { equip="INVTYPE_HEAD", class=4, sub=2 }
ITEMS["item:7777"] = { equip="INVTYPE_HEAD", class=4, sub=2, uncached=true }
AH_ROWS = {
  { "Sword", 1, 5000, 2002, "item:2002:0:0" }, { "", 1, 4000, 2002, "item:2002:0:0" },
  { "Linen Cloth", 20, 2000, 2589, "item:2589" }, { "Linen Cloth", 5, 1000, 2589, "item:2589" },
  { "Odd Cap", 1, 900, 7777, "item:7777" },
}
C_AuctionHouse = {
  ReplicateItems = function() fire("REPLICATE_ITEM_LIST_UPDATE") end,
  GetNumReplicateItems = function() return #AH_ROWS end,
  GetReplicateItemInfo = function(i) local r = AH_ROWS[i + 1]
    return r[1], 0, r[2], 2, true, 20, 0, 0, 0, r[3], 0, false, nil, "Seller", "Seller-Realm", 0, r[4], true end,
  GetReplicateItemLink = function(i) return AH_ROWS[i + 1][5] end,
}
printed = {}
""")
L.globals().SlashCmdList.GEARWRIGHTPROBE("ah")
assert "open the auction house first" in L.globals().printed[1], L.globals().printed[1]
L.globals().fire("AUCTION_HOUSE_SHOW")
L.globals().SlashCmdList.GEARWRIGHTPROBE("ah")
ahs = L.eval("""function() local a = GearwrightProbeDB.scans.auction local g, n = nil, 0
  for _, v in pairs(a.gear) do n = n + 1; if v.id == 2002 then g = v end end
  assert(n == 1, "listings with and without a name merge into one record")
  return a.listings, g.minBuyout, g.listings, g.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT, g.equip, a.prices["2589"], a.missing,
    a.gear["7777:Odd Cap"] == nil end""")()
assert tuple(ahs) == (5, 4000, 2, 25, "INVTYPE_WEAPON", 100, 1, True), tuple(ahs)
out = "\n".join(L.globals().printed.values())
assert "5 listings, 1 gear items recorded, 1 other items priced, 1 gear items had no data" in out, out
assert "Seller" not in L.eval("function() local b = {} for k, v in pairs(GearwrightProbeDB.scans.auction.gear) do b[#b+1] = v.link end return table.concat(b) end")()
L.execute("printed = {}")
L.globals().SlashCmdList.GEARWRIGHTPROBE("ah")
assert "one full scan every 15 minutes; try again in 15 min" in L.globals().printed[1], L.globals().printed[1]
L.globals().SlashCmdList.GEARWRIGHTPROBE("export ah")
assert '"auction"' in L.globals().EXPORTTEXT and '"snapshots"' not in L.globals().EXPORTTEXT
L.globals().fire("AUCTION_HOUSE_CLOSED")
L.execute("C_AuctionHouse = nil")
L.globals().SlashCmdList.GEARWRIGHTPROBE("export")
print("---- probe export title ----"); print(L.globals().LASTTEXT)
for p in L.globals().printed.values(): print("  >", p)

open(OUT/"export.json","w").write(L.globals().EXPORTTEXT)
assert '"auction"' not in L.globals().EXPORTTEXT  # the big auction scan has its own export
# The probe's loot log turns into Gearwright's own dungeon loot table.
gen = OUT / "DungeonLoot.lua"
subprocess.run([sys.executable, str(R / "tools" / "loot_from_probe.py"), str(OUT / "export.json"), "-o", str(gen)],
               check=True, capture_output=True)
loot_lua = gen.read_text()
assert 'itemID = 5540, name = "Pearl-handled Dagger", dungeon = "The Deadmines", from = "Defias Squallshaper", npcID = 1732, count = 2' in loot_lua, loot_lua
assert subprocess.run([sys.executable, str(R / "tools" / "loot_from_probe.py"), *map(str, sorted((R / "data" / "probe").glob("*.json"))),
                       "-o", str(OUT / "check.lua")], capture_output=True).returncode == 0
assert (OUT / "check.lua").read_text() == (R / "Gearwright" / "Data" / "DungeonLoot.lua").read_text(), "rerun tools/loot_from_probe.py"
# Data/Crafted.lua is current with the saved probe scans.
assert subprocess.run([sys.executable, str(R / "tools" / "crafted_from_probe.py"), *map(str, sorted((R / "data" / "probe").glob("*.json"))),
                       "-o", str(OUT / "crafted.lua")], check=True, capture_output=True).returncode == 0
assert (OUT / "crafted.lua").read_text() == (R / "Gearwright" / "Data" / "Crafted.lua").read_text(), "rerun tools/crafted_from_probe.py"
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

import subprocess, sys  # noqa: E401
for f in ("export.json", "GearwrightProbe.lua"):
    r = subprocess.run([sys.executable, str(R/"tools"/"probe_to_json.py"), str(OUT/f)], capture_output=True, text=True)
    assert r.returncode == 0 and "Malice (5/5)" in r.stdout and "10 points spent" in r.stdout, r.stdout + r.stderr
    for want in ("character sheet: 2 stat lines", "Agility 66 (49+17)", "Increases Attack Power by 66",
                 "agility per 1% crit: 7.59  (from the sheet", "Reduces Physical Damage taken by 19.46%", "CR_HIT_MELEE (id 6): rating 12, bonus 1.2",
                 "items by ID: 1", "13404 Mask of the Unforgiven (req 52): ITEM_MOD_HIT_RATING_SHORT=20",
                 "Equip: Improves your chance to hit by 2.0%.",
                 "encounter journal: 1 instances, 1 tiers", "1 of 20 known IDs answered", "The Deadmines (dungeon, 2 bosses, loot"):
        assert want in r.stdout, (want, r.stdout)
    if f == "GearwrightProbe.lua":  # the SavedVariables file has the auction scan too
        assert "auction house scan 2026-10-03 16:00:00: 5 listings, 1 gear items, 1 other items priced" in r.stdout, r.stdout
        r = subprocess.run([sys.executable, str(R/"tools"/"ah_report.py"), str(OUT/f), "--level", "30"],
                           capture_output=True, text=True)
        assert r.returncode == 0 and "One-hand\n" in r.stdout and "(level 1, 40s, 2 listed)" in r.stdout, r.stdout + r.stderr
print("\nALL SMOKE TESTS PASSED")
