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
local TABS = { {"Assassination", {{"Malice",0,5},{"Mutilate",0,1}}}, {"Combat", {{"Hack and Slash",5,5},{"Restless Blades",1,1}}}, {"Subtlety", {{"Hemorrhage",0,1}}} }
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
           GetItemInfo = function(l) local i = ITEMS[l] if not i then return nil end
             return "name", l, 2, 20, i.req or 1, "Armor", "Leather", 1, i.equip, 0, i.sell or 0 end }
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
txt = L.eval("function(ns) return ns.UI.frame.text.text end")(ns)
print("---- main window ----"); print(txt)
for want in ("Spec:|r Subtlety", "(override)", "Stat weights are provisional", "Head", "item:1001:0:0",
             "No recommended build for this spec yet.", "No enchant recommendations for this spec yet."):
    assert want in txt, want
L.globals().SlashCmdList.GEARWRIGHT("spec auto")  # refreshes the open window
txt = L.eval("function(ns) return ns.UI.frame.text.text end")(ns)
assert "Spec:|r Combat" in txt and "(talents)" in txt, txt
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
C_Spell = { GetSpellName = function(id) return SPELL_NAMES[id] end }
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
txt = L.eval("function(ns) return ns.UI.frame.text.text end")(ns)
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
L.globals().SlashCmdList.GEARWRIGHTPROBE("all")  # window closed: /gwp all opens it, reads it, closes it
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

# Regression: two professions' recipe scans must not overwrite each other.
L.execute("""
PROF = "Enchanting"
C_TradeSkillUI = { GetAllRecipeIDs = function() return {1, 2} end,
  GetRecipeInfo = function(id) return {name = "r"..id} end,
  GetBaseProfessionInfo = function() return {professionName = PROF} end }
""")
L.globals().fire("TRADE_SKILL_SHOW")
L.execute("PROF = 'Leatherworking'"); L.globals().fire("TRADE_SKILL_SHOW")
L.execute("C_TradeSkillUI.GetBaseProfessionInfo = function() return nil end"); L.globals().fire("TRADE_SKILL_SHOW")
keys = sorted(L.eval("function() local o={} for k in pairs(GearwrightProbeDB.scans) do o[#o+1]=k end return o end")().values())
assert keys == ["items", "tradeskill:3", "tradeskill:Enchanting", "tradeskill:Leatherworking"], keys
L.globals().SlashCmdList.GEARWRIGHTPROBE("export")
print("---- probe export title ----"); print(L.globals().LASTTEXT)
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

import subprocess, sys  # noqa: E401
for f in ("export.json", "GearwrightProbe.lua"):
    r = subprocess.run([sys.executable, str(R/"tools"/"probe_to_json.py"), str(OUT/f)], capture_output=True, text=True)
    assert r.returncode == 0 and "Malice (5/5)" in r.stdout and "10 points spent" in r.stdout, r.stdout + r.stderr
    for want in ("character sheet: 2 stat lines", "Agility 66 (49+17)", "Increases Attack Power by 66",
                 "agility per 1% crit: 7.59  (from the sheet", "Reduces Physical Damage taken by 19.46%", "CR_HIT_MELEE (id 6): rating 12, bonus 1.2",
                 "items by ID: 1", "13404 Mask of the Unforgiven (req 52): ITEM_MOD_HIT_RATING_SHORT=20",
                 "Equip: Improves your chance to hit by 2.0%."):
        assert want in r.stdout, (want, r.stdout)
print("\nALL SMOKE TESTS PASSED")
