-- GearwrightProbe: answers the questions Gearwright can't be built without.
--
--   * Which talent API does the Forever client expose, and is it readable?
--   * What stat tokens/units do items report (ratings vs % "Equip:" lines)?
--   * Which character-stat APIs return numbers vs "secret values"?
--   * Do SavedVariables survive a relog on the beta?
--   * What are the real enchant IDs and recipe lists?
--
-- Everything is stored in GearwrightProbeDB AND can be shown in a copyable
-- window (/gwp export), because the beta reportedly doesn't reload settings.
local ADDON = ...

local P = {}
local PREFIX = "|cffff9900GearwrightProbe|r: "
local function say(s, ...) print(PREFIX .. (select("#", ...) > 0 and s:format(...) or s)) end
local function now() return date("%Y-%m-%d %H:%M:%S") end
local function pack(...) return { n = select("#", ...), ... } end

-- Value sanitizing --------------------------------------------------------------
local function isSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end

local function sanitize(v, depth)
  depth = depth or 0
  if isSecret(v) then return "<secret>" end
  local t = type(v)
  if t == "nil" then return "<nil>" end
  if t == "string" or t == "number" or t == "boolean" then return v end
  if t == "table" then
    if depth >= 3 then return "<table>" end
    local out = {}
    for k, val in pairs(v) do
      local key = (type(k) == "string" or type(k) == "number") and k or tostring(k)
      out[key] = sanitize(val, depth + 1)
    end
    return out
  end
  return "<" .. t .. ">"
end

local function resolve(path)
  local cur = _G
  for part in path:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
  end
  return cur
end

-- Call a function by path; record status and every return value.
local function capture(path, ...)
  local fn = resolve(path)
  if type(fn) ~= "function" then return { status = "missing" } end
  local res = pack(pcall(fn, ...))
  if not res[1] then return { status = "error", error = tostring(res[2]) } end
  local values, secret = {}, false
  for i = 2, res.n do
    if isSecret(res[i]) then secret = true end
    values[i - 1] = sanitize(res[i])
  end
  return { status = secret and "secret" or "ok", values = values }
end

-- Storage ------------------------------------------------------------------------
local function db()
  GearwrightProbeDB = GearwrightProbeDB or {}
  local d = GearwrightProbeDB
  d.version = 1
  d.snapshots = d.snapshots or {}
  d.scans = d.scans or {}
  return d
end

local current -- snapshot being filled this session

local function snapshot()
  if current then return current end
  local name, realm = UnitFullName("player")
  local _, class = UnitClass("player")
  current = {
    at = now(),
    character = sanitize(name) .. "-" .. tostring(sanitize(realm)),
    class = class,
    level = sanitize(UnitLevel("player")),
    sections = {},
  }
  table.insert(db().snapshots, current)
  return current
end

-- Sections ------------------------------------------------------------------------
local API_PATHS = {
  -- secret values
  "issecretvalue", "canaccessvalue",
  -- talents (Classic-style vs Traits)
  "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo",
  "C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "C_Traits.GetTreeNodes",
  "C_Traits.GetNodeInfo", "C_Traits.GetEntryInfo", "C_Traits.GetDefinitionInfo",
  "GetSpecialization", "C_SpecializationInfo.GetSpecialization", "GetInspectSpecialization",
  -- items
  "C_Item.GetItemStats", "GetItemStats", "C_Item.GetItemInfoInstant", "GetItemInfoInstant",
  "C_TooltipInfo.GetHyperlink", "C_TooltipInfo.GetInventoryItem", "TooltipDataProcessor.AddTooltipPostCall",
  "GetInventoryItemLink", "C_PaperDollInfo.GetInspectItemLevel", "C_Item.GetItemInfo", "GetItemInfo",
  -- quest rewards / loot (Gearwright's upgrade messages)
  "GetNumQuestChoices", "GetQuestItemLink", "GetNumLootItems", "GetLootSlotLink", "GetLootRollItemLink",
  "UnitDamage", "C_Item.RequestLoadItemDataByID", "C_TooltipInfo.GetItemByID",
  -- dungeon/raid loot tables, if this client has the Encounter Journal
  "EJ_SelectInstance", "EJ_GetNumLoot", "EJ_GetLootInfoByIndex", "C_EncounterJournal.GetLootInfoByIndex",
  "EJ_GetNumTiers", "EJ_GetInstanceByIndex", "EJ_GetEncounterInfoByIndex", "EJ_GetLootFilter",
  "EJ_SelectTier", "EJ_GetInstanceInfo", "C_AddOns.LoadAddOn",
  "C_TradeSkillUI.GetRecipeSchematic", "C_Spell.GetSpellDescription",
  -- character stats
  "UnitStat", "UnitAttackPower", "UnitAttackSpeed", "GetCritChance", "GetHitModifier",
  "GetSpellHitModifier", "GetExpertise", "GetHaste", "GetMeleeHaste", "GetCombatRating",
  "GetCombatRatingBonus", "GetDodgeChance", "GetParryChance", "GetArmorPenetration",
  -- professions / trainers
  "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetBaseProfessionInfo",
  "GetNumTradeSkills", "GetTradeSkillInfo", "GetNumTrainerServices", "GetTrainerServiceInfo",
  "GetProfessions", "GetProfessionInfo",
  -- auction house full scan
  "C_AuctionHouse.ReplicateItems", "C_AuctionHouse.GetNumReplicateItems", "C_AuctionHouse.GetReplicateItemInfo",
  "C_AuctionHouse.GetReplicateItemLink", "C_AuctionHouse.SendBrowseQuery",
  -- inspect
  "NotifyInspect", "CanInspect",
  -- weapon skills (does a talent add axes?)
  "IsPlayerSpell", "C_SpellBook.IsSpellKnown", "IsSpellKnown", "GetNumSkillLines", "GetSkillLineInfo",
}

function P.env()
  local s = snapshot()
  s.sections.env = {
    build = capture("GetBuildInfo"),
    project = sanitize(WOW_PROJECT_ID),
    locale = GetLocale(),
    race = capture("UnitRace", "player"),
  }
  local build = s.sections.env.build.values or {}
  say("build %s (%s), interface %s, project %s",
    tostring(build[1]), tostring(build[2]), tostring(build[4]), tostring(WOW_PROJECT_ID))
end

function P.api()
  local out, present, missing = {}, 0, {}
  for _, path in ipairs(API_PATHS) do
    local t = type(resolve(path))
    out[path] = t
    if t == "nil" then missing[#missing + 1] = path else present = present + 1 end
  end
  snapshot().sections.api = out
  say("APIs present: %d / %d", present, #API_PATHS)
  if #missing > 0 then say("missing: %s", table.concat(missing, ", ")) end
end

local function talentsClassic()
  local tabs = {}
  for tab = 1, GetNumTalentTabs() do
    local info = capture("GetTalentTabInfo", tab)
    local talents = {}
    for i = 1, (GetNumTalents(tab) or 0) do
      talents[i] = capture("GetTalentInfo", tab, i)
    end
    tabs[tab] = { info = info, talents = talents }
  end
  return tabs
end

local function talentsTraits()
  local out = { configID = capture("C_ClassTalents.GetActiveConfigID") }
  local configID = out.configID.values and out.configID.values[1]
  if type(configID) ~= "number" then return out end
  out.config = capture("C_Traits.GetConfigInfo", configID)
  local config = out.config.values and out.config.values[1]
  local treeIDs = type(config) == "table" and config.treeIDs
  if type(treeIDs) ~= "table" then return out end
  out.trees = {}
  for _, treeID in pairs(treeIDs) do
    local nodes = capture("C_Traits.GetTreeNodes", treeID)
    local tree = { treeID = treeID, nodeCount = 0, nodes = {} }
    for _, nodeID in pairs((nodes.values and nodes.values[1]) or {}) do
      tree.nodeCount = tree.nodeCount + 1
      local node = capture("C_Traits.GetNodeInfo", configID, nodeID)
      local info = node.values and node.values[1]
      local entry = { nodeID = nodeID, node = info }
      if type(info) == "table" and type(info.entryIDs) == "table" and info.entryIDs[1] then
        local e = capture("C_Traits.GetEntryInfo", configID, info.entryIDs[1])
        local ev = e.values and e.values[1]
        if type(ev) == "table" and ev.definitionID then
          local d = capture("C_Traits.GetDefinitionInfo", ev.definitionID)
          local dv = d.values and d.values[1]
          if type(dv) == "table" and dv.spellID then
            entry.spellID = dv.spellID
            entry.spellName = capture("C_Spell.GetSpellName", dv.spellID)
          end
        end
      end
      tree.nodes[#tree.nodes + 1] = entry
    end
    out.trees[#out.trees + 1] = tree
  end
  return out
end

-- Which weapon skill spells the player knows, and the Classic skill list if the
-- client still has one. Says whether a talent (e.g. Hack and Slash) adds axes.
local WEAPON_SKILL_SPELLS = {
  [196] = "One-Handed Axes", [197] = "Two-Handed Axes", [198] = "One-Handed Maces",
  [199] = "Two-Handed Maces", [200] = "Polearms", [201] = "One-Handed Swords",
  [202] = "Two-Handed Swords", [227] = "Staves", [1180] = "Daggers", [15590] = "Fist Weapons",
  [264] = "Bows", [266] = "Guns", [5011] = "Crossbows", [2567] = "Thrown", [5009] = "Wands",
  [674] = "Dual Wield",
}
local function weaponSkills()
  local out = { spells = {} }
  local known = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
  for id, name in pairs(WEAPON_SKILL_SPELLS) do
    local ok, v = pcall(known or function() return nil end, id)
    if ok then out.spells[name] = sanitize(v) == true else out.spells[name] = "error" end
  end
  if GetNumSkillLines and GetSkillLineInfo then
    out.skillLines = {}
    for i = 1, GetNumSkillLines() do
      out.skillLines[#out.skillLines + 1] = sanitize(pack(GetSkillLineInfo(i)))
    end
  end
  return out
end

function P.talents()
  local s = snapshot()
  local out = {}
  if GetNumTalentTabs and GetTalentInfo then
    out.classic = talentsClassic()
    local n = 0
    for _, tab in ipairs(out.classic) do n = n + #tab.talents end
    say("classic talent API: %d tabs, %d talents", #out.classic, n)
  else
    say("classic talent API: not present")
  end
  if C_ClassTalents and C_Traits then
    out.traits = talentsTraits()
    local trees = out.traits.trees or {}
    say("traits API: %d tree(s)%s", #trees, trees[1] and (", first has " .. trees[1].nodeCount .. " nodes") or "")
  else
    say("traits API: not present")
  end
  out.weaponSkills = weaponSkills()
  s.sections.talents = out
end

local function itemStats(link)
  if C_Item and C_Item.GetItemStats then return capture("C_Item.GetItemStats", link) end
  return capture("GetItemStats", link)
end

local function tooltipLines(data)
  local lines = {}
  if type(data) == "table" and type(data.lines) == "table" then
    for _, line in ipairs(data.lines) do lines[#lines + 1] = sanitize(line.leftText) end
  end
  return lines
end

local function dumpInventory(unit)
  local gear, tokens = {}, {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink(unit, slot)
    if isSecret(link) then
      gear[slot] = { link = "<secret>" }
    elseif link then
      local itemID, enchantID = link:match("item:(%-?%d+):(%-?%d*)")
      local stats = itemStats(link)
      local tip = capture("C_TooltipInfo.GetHyperlink", link)
      gear[slot] = {
        link = link, itemID = tonumber(itemID), enchantID = tonumber(enchantID) or 0,
        stats = stats, tooltip = tooltipLines(tip.values and tip.values[1]),
      }
      local st = stats.values and stats.values[1]
      if type(st) == "table" then for token in pairs(st) do tokens[token] = true end end
    end
  end
  return gear, tokens
end

function P.gear()
  local gear, tokens = dumpInventory("player")
  snapshot().sections.gear = gear
  local n, list = 0, {}
  for _ in pairs(gear) do n = n + 1 end
  for token in pairs(tokens) do list[#list + 1] = token end
  table.sort(list)
  say("gear: %d items; stat tokens seen: %s", n, #list > 0 and table.concat(list, ", ") or "none")
end

-- Every character-stat function we know of, Classic and Mainline. Missing ones
-- are recorded as "missing", so one capture shows what this client has.
local STAT_CALLS = {
  { "UnitStat", "player", 1 }, { "UnitStat", "player", 2 }, { "UnitStat", "player", 3 },
  { "UnitStat", "player", 4 }, { "UnitStat", "player", 5 },
  { "UnitArmor", "player" }, { "UnitHealthMax", "player" }, { "UnitPowerMax", "player" },
  { "UnitAttackPower", "player" }, { "UnitRangedAttackPower", "player" },
  { "UnitDamage", "player" }, { "UnitRangedDamage", "player" },
  { "UnitAttackSpeed", "player" }, { "UnitAttackBothHands", "player" }, { "UnitDefense", "player" },
  { "GetCritChance" }, { "GetRangedCritChance" }, { "GetSpellCritChance", 2 },
  { "GetCritChanceFromAgility", "player" }, { "GetSpellCritChanceFromIntellect", "player" },
  { "GetHitModifier" }, { "GetSpellHitModifier" }, { "GetExpertise" }, { "GetArmorPenetration" },
  { "GetHaste" }, { "GetMeleeHaste" }, { "GetRangedHaste" }, { "UnitSpellHaste", "player" },
  { "GetDodgeChance" }, { "GetParryChance" }, { "GetBlockChance" }, { "GetShieldBlock" },
  { "GetSpellBonusDamage", 2 }, { "GetSpellBonusHealing" }, { "GetManaRegen" }, { "GetPowerRegen" },
  { "UnitResistance", "player", 1 }, { "UnitResistance", "player", 2 }, { "UnitResistance", "player", 3 },
  { "UnitResistance", "player", 4 }, { "UnitResistance", "player", 5 }, { "UnitResistance", "player", 6 },
}

-- All CR_* combat-rating constants this client defines, sorted by name.
local function ratingConstants()
  local out = {}
  for name, id in pairs(_G) do
    if type(name) == "string" and name:find("^CR_") and type(id) == "number" then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

function P.stats()
  local out, secret, ok, missing = {}, 0, 0, 0
  for _, call in ipairs(STAT_CALLS) do
    local parts = {}
    for i, v in ipairs(call) do parts[i] = tostring(v) end
    local r = capture(unpack(call))
    out[table.concat(parts, ":")] = r
    if r.status == "secret" then secret = secret + 1
    elseif r.status == "ok" then ok = ok + 1
    elseif r.status == "missing" then missing = missing + 1 end
  end
  local ratings = ratingConstants()
  for _, c in ipairs(ratings) do
    local id = _G[c]
    out["rating:" .. c] = { id = id, rating = capture("GetCombatRating", id), bonus = capture("GetCombatRatingBonus", id) }
  end
  snapshot().sections.stats = out
  say("character stats: %d readable, %d secret, %d missing, %d error; %d combat ratings",
    ok, secret, missing, #STAT_CALLS - ok - secret - missing, #ratings)
end

-- Character sheet ------------------------------------------------------------------
-- Most stat lines build their tooltip only on hover, so the probe "hovers" each
-- visible stat frame (calls its OnEnter), reads GameTooltip, then leaves.
-- Frames that store the text up front (.tooltip / .tooltip2) are read directly.
local function fontText(region)
  if type(region) ~= "table" or type(region.GetText) ~= "function" then return nil end
  local text = region:GetText()
  -- An empty font string is nil, not "<nil>": otherwise every blank slot and
  -- button counts as a text frame and gets hovered and recorded.
  if text == nil then return nil end
  return sanitize(text)
end

-- Text of a frame's own font strings, e.g. "Agility:" and "66".
local function regionTexts(frame)
  local out = {}
  if type(frame.GetRegions) ~= "function" then return out end
  for _, r in ipairs({ frame:GetRegions() }) do
    -- Hidden font strings hold placeholder text (e.g. the level line's
    -- "Free Trial level cap reached."), so only shown ones count.
    local shown = type(r.IsShown) ~= "function" or r:IsShown()
    if shown and type(r.GetObjectType) == "function" and r:GetObjectType() == "FontString" then
      local t = fontText(r)
      if type(t) == "string" and t ~= "" then out[#out + 1] = t end
    end
  end
  return out
end

local function hoverTooltip(frame)
  local tip = _G.GameTooltip
  local onEnter = type(frame.GetScript) == "function" and frame:GetScript("OnEnter")
  if not (tip and onEnter) then return nil end
  tip:Hide()
  if not pcall(onEnter, frame) then return nil end
  local lines = {}
  local isItem = type(tip.GetItem) == "function" and tip:GetItem() ~= nil
  if tip:IsShown() and not isItem then
    for i = 1, tip:NumLines() do
      local left = fontText(_G["GameTooltipTextLeft" .. i])
      local right = fontText(_G["GameTooltipTextRight" .. i])
      if type(left) == "string" and left ~= "" then
        lines[#lines + 1] = (type(right) == "string" and right ~= "") and (left .. "  " .. right) or left
      end
    end
  end
  local onLeave = frame:GetScript("OnLeave")
  if onLeave then pcall(onLeave, frame) end
  tip:Hide()
  return #lines > 0 and lines or nil
end

local function collectSheet(frame, out, seen, depth, diag)
  if depth > 14 or #out >= 150 or type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then return end
  diag.scanned = diag.scanned + 1
  local visible = type(frame.IsVisible) ~= "function" or frame:IsVisible()
  if visible then diag.visible = diag.visible + 1 end
  local static = type(frame.tooltip) == "string" or type(frame.tooltip2) == "string"
  if static then diag.stored = diag.stored + 1 end
  -- Stored text is readable even with the window closed; hovering needs it on screen.
  local texts = regionTexts(frame)
  if visible and #texts > 0 and #diag.map < 60 then
    -- Where the visible text lives, so a failed capture still shows the window's structure.
    local name = type(frame.GetName) == "function" and frame:GetName() or nil
    diag.map[#diag.map + 1] = ("%d %s: %s"):format(depth, tostring(name or "?"), table.concat(texts, " | "))
  end
  -- Only frames that show text are stat lines; this skips item slots, tabs and buttons.
  local hover = visible and #texts > 0 and hoverTooltip(frame) or nil
  if hover then diag.hovered = diag.hovered + 1 end
  do
    local key = hover and hover[1] or (static and tostring(frame.tooltip))
    local label = fontText(frame.Label) or fontText(frame.Name) or texts[1]
    -- No label means a button or empty item slot, not a stat line.
    if key and label and label ~= "" and not seen[key] then
      seen[key] = true
      out[#out + 1] = {
        label = label,
        value = fontText(frame.Value) or texts[2],
        tooltip = static and sanitize(frame.tooltip) or nil,
        tooltip2 = static and sanitize(frame.tooltip2) or nil,
        hover = hover,
      }
    end
  end
  for _, child in ipairs({ frame:GetChildren() }) do collectSheet(child, out, seen, depth + 1, diag) end
end

local function recordSheet(quiet, how)
  -- The whole character window: on Forever the visible stats are not in CharacterStatsPane.
  local root = _G.CharacterFrame or _G.PaperDollFrame
  if not root then return say("no character sheet frame found") end
  local lines, diag = {}, { scanned = 0, visible = 0, stored = 0, hovered = 0, map = {} }
  collectSheet(root, lines, {}, 0, diag)
  local paperDoll = _G.PaperDollFrame
  diag.how = how or "already open"
  diag.root = (type(root.GetName) == "function" and root:GetName()) or "?"
  diag.windowVisible = paperDoll and paperDoll:IsVisible() or false
  diag.toggleCharacter = type(_G.ToggleCharacter) == "function"
  local s = snapshot()
  s.sections.sheetDebug = diag  -- why a capture came out the way it did
  local old = s.sections.sheet
  if type(old) == "table" and #old > #lines then
    -- Never let a worse read (window closed, fewer lines) replace a better one.
    if not quiet then say("character sheet: this read found %d lines, kept the %d recorded earlier", #lines, #old) end
    return
  end
  s.level = sanitize(UnitLevel("player"))
  s.sections.sheet = lines
  if #lines <= 1 then
    say("character sheet: %d stat lines (window %s, %d frames, %d visible, %d hovered)",
      #lines, diag.windowVisible and "open" or "closed", diag.scanned, diag.visible, diag.hovered)
    say("  open it with C, expand every category, then /gwp sheet")
  elseif not quiet then
    say("character sheet: %d stat lines recorded", #lines)
  end
end

-- Records the sheet, opening the character window first if it is closed and
-- closing it again afterwards, so /gwp all doesn't depend on it being open.
-- The window may only become visible a frame later, so always wait before reading.
function P.sheet(quiet)
  if InCombatLockdown and InCombatLockdown() then return say("leave combat first") end
  local frame = _G.PaperDollFrame
  if frame and not frame:IsVisible() and type(_G.ToggleCharacter) == "function" then
    P.sheetOpening = true
    local toggled = pcall(_G.ToggleCharacter, "PaperDollFrame")
    C_Timer.After(0.5, function()
      P.sheetOpening = false
      recordSheet(quiet, toggled and "opened by probe" or "ToggleCharacter failed")
      if toggled and frame:IsVisible() then pcall(_G.ToggleCharacter, "PaperDollFrame") end
    end)
    return
  end
  recordSheet(quiet)
end

local function hookSheet()
  local frame = _G.PaperDollFrame or _G.CharacterFrame
  if not frame or P.sheetHooked then return end
  P.sheetHooked = true
  -- Opening the window yourself records it too (unless P.sheet opened it).
  frame:HookScript("OnShow", function()
    if not P.sheetOpening then C_Timer.After(0.5, function() recordSheet(true, "opened by you") end) end
  end)
end

-- Event-driven scans (open the window, the probe records it) -----------------------
local function scanTradeSkill()
  local out = { at = now(), recipes = {} }
  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
    out.profession = capture("C_TradeSkillUI.GetBaseProfessionInfo")
    -- Whose window is this? Yours, another player's link, a guild list, an NPC...
    out.owner = {
      linked = capture("C_TradeSkillUI.IsTradeSkillLinked"),
      guild = capture("C_TradeSkillUI.IsTradeSkillGuild"),
      npc = capture("C_TradeSkillUI.IsNPCCrafting"),
      ready = capture("C_TradeSkillUI.IsTradeSkillReady"),
      mine = capture("GetProfessions"),
    }
    local mine = out.owner.mine.values or {}
    out.owner.mineInfo = {}
    for i = 1, 6 do
      if type(mine[i]) == "number" then out.owner.mineInfo[#out.owner.mineInfo + 1] = capture("GetProfessionInfo", mine[i]) end
    end
    local ids = capture("C_TradeSkillUI.GetAllRecipeIDs")
    for _, id in ipairs((ids.values and ids.values[1]) or {}) do
      local info = capture("C_TradeSkillUI.GetRecipeInfo", id)
      local v = info.values and info.values[1]
      -- What it makes: an item (gear, rods) or an effect (enchants, described in text).
      local schematic = capture("C_TradeSkillUI.GetRecipeSchematic", id, false)
      local sv = schematic.values and schematic.values[1]
      local desc = capture("C_Spell.GetSpellDescription", id)
      out.recipes[#out.recipes + 1] = {
        recipeID = id, name = type(v) == "table" and v.name or nil,
        learned = type(v) == "table" and v.learned == true, -- false = not learned yet
        outputItemID = type(sv) == "table" and sv.outputItemID or nil,
        desc = desc.values and desc.values[1],
      }
    end
    out.api = "C_TradeSkillUI"
  elseif GetNumTradeSkills then
    for i = 1, GetNumTradeSkills() do out.recipes[i] = capture("GetTradeSkillInfo", i) end
    out.api = "classic"
  end
  -- scans is keyed by string, so "#" is always 0: key by profession name, or
  -- count existing tradeskill scans so a second profession can't overwrite the first.
  local info = out.profession and out.profession.values and out.profession.values[1]
  local name = type(info) == "table" and info.professionName
  if type(name) ~= "string" and GetTradeSkillLine then name = sanitize(GetTradeSkillLine()) end
  if type(name) ~= "string" or name:find("^<") then
    local n = 0
    for k in pairs(db().scans) do if k:find("^tradeskill:") then n = n + 1 end end
    name = tostring(n + 1)
  end
  db().scans["tradeskill:" .. name] = out
  local linked = out.owner and out.owner.linked.values or {}
  say("recorded %d recipes (%s)%s", #out.recipes, tostring(out.api),
    linked[1] == true and (" from " .. tostring(linked[2]) .. "'s linked profession") or "")
end

-- Trainer window: every service, learned ones included. The window's filter
-- (available / unavailable / already known) hides some, so the probe turns all
-- three on, reads the list a moment later, then puts your filter back. Changing
-- the filter yourself reads the list again.
local TRAINER_FILTERS = { "available", "unavailable", "used" }
local trainerBusy = false

local function readTrainer(out)
  for i = 1, (GetNumTrainerServices and GetNumTrainerServices() or 0) do
    out.services[i] = capture("GetTrainerServiceInfo", i)
    out.services[i].cost = capture("GetTrainerServiceCost", i).values -- copper (+ talent/profession points)
    out.services[i].level = capture("GetTrainerServiceLevelReq", i).values
  end
  local counts = {}
  for _, svc in ipairs(out.services) do
    local status = svc.values and svc.values[2]
    if status then counts[status] = (counts[status] or 0) + 1 end
  end
  out.counts = counts
  db().scans["trainer:" .. tostring(sanitize(UnitName("npc")))] = out
  local parts = {}
  for status, n in pairs(counts) do parts[#parts + 1] = n .. " " .. status end
  table.sort(parts)
  say("recorded %d trainer services (%s)", #out.services, table.concat(parts, ", "))
end

local function scanTrainer()
  if trainerBusy then return end
  local out = { at = now(), services = {}, npc = sanitize(UnitGUID and UnitGUID("npc")) }
  out.map = capture("C_Map.GetBestMapForUnit", "player")
  local mapID = out.map.values and out.map.values[1]
  if type(mapID) == "number" and C_Map and C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if ok and pos and pos.GetXY then out.x, out.y = pos:GetXY() end
    out.x, out.y = sanitize(out.x), sanitize(out.y)
  end
  out.zone = sanitize(GetRealZoneText and GetRealZoneText())
  if not (GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter) then
    out.filters = "none"
    return readTrainer(out)
  end
  local saved, changed = {}, false
  for _, f in ipairs(TRAINER_FILTERS) do
    local ok, on = pcall(GetTrainerServiceTypeFilter, f)
    saved[f] = ok and (on == true or on == 1) or false
    if not saved[f] then
      changed = true
      pcall(SetTrainerServiceTypeFilter, f, 1)
    end
  end
  out.filters = saved
  trainerBusy = true
  C_Timer.After(changed and 0.3 or 0, function()
    readTrainer(out)
    for _, f in ipairs(TRAINER_FILTERS) do
      if not saved[f] then pcall(SetTrainerServiceTypeFilter, f, 0) end
    end
    C_Timer.After(0.5, function() trainerBusy = false end) -- ignore our own filter updates
  end)
end

-- Loot log: what drops, and from what. The Encounter Journal won't load on
-- Forever (LoadAddOn says WRONG_GAME_TYPE), so dungeon loot tables have to be
-- built from real drops. Each corpse or chest counts once per session.
local lootSeen = {}

-- "Creature-0-4618-0-12-1732-0000123456" -> "Creature", "1732"
local function sourceID(guid)
  if type(guid) ~= "string" then return nil end
  return guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
end

local function sourceName(guid)
  for _, unit in ipairs({ "target", "mouseover" }) do
    if UnitGUID and sanitize(UnitGUID(unit)) == guid then return sanitize(UnitName(unit)) end
  end
end

local function recordLoot()
  if not (GetNumLootItems and GetLootSlotLink) then return end
  local log = db().scans.loot or { since = now(), items = {} }
  db().scans.loot = log
  local inst = capture("GetInstanceInfo")
  local iv = inst.values or {}
  local inInstance = iv[2] ~= nil and iv[2] ~= "none"
  local where = (inInstance and iv[1]) or sanitize(GetRealZoneText and GetRealZoneText()) or "?"
  local added = 0
  for slot = 1, GetNumLootItems() or 0 do
    local link = sanitize(GetLootSlotLink(slot))
    local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if itemID then
      local src = GetLootSourceInfo and pack(GetLootSourceInfo(slot)) or { n = 0 }
      for k = 1, math.max(src.n, 1), 2 do
        local guid = sanitize(src[k]) or "unknown"
        if not lootSeen[guid .. ":" .. itemID] then
          lootSeen[guid .. ":" .. itemID] = true
          local kind, id = sourceID(guid)
          local key = kind and (kind .. ":" .. id) or guid
          local quality = tonumber(link:match("|cnIQ(%d)")) -- Forever links carry the quality
          local rec = log.items[tostring(itemID)] or { name = link:match("%[(.-)%]"), quality = quality, from = {} }
          log.items[tostring(itemID)] = rec
          local e = rec.from[key] or { count = 0, where = where, instance = inInstance or nil, name = sourceName(guid) }
          e.count = e.count + 1
          rec.from[key] = e
          added = added + 1
        end
      end
    end
  end
  if added > 0 then say("loot: recorded %d drop(s) in %s", added, tostring(where)) end
end

local function onInspectReady()
  if not UnitExists("target") then return end
  local gear = dumpInventory("target")
  db().scans["inspect:" .. tostring(sanitize(UnitName("target")))] = {
    at = now(), class = select(2, UnitClass("target")), gear = gear,
    spec = capture("GetInspectSpecialization", "target"),
  }
  say("recorded inspect of %s", tostring(sanitize(UnitName("target"))))
  P.inspecting = false
end

-- SavedVariables persistence test ------------------------------------------------
local persistReport
local function persistenceCheck()
  local d = db()
  local prior = d.persistTest
  persistReport = prior
    and ("SavedVariables OK: found data written %s"):format(tostring(prior.written))
    or "SavedVariables: nothing from a previous session (first run, or the beta dropped it)"
  d.persistTest = { written = now(), token = math.random(1, 1e6) }
end

-- JSON export -----------------------------------------------------------------------
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function jsonString(s)
  s = s:gsub('[%c"\\]', function(c) return ESC[c] or ("\\u%04x"):format(c:byte()) end)
  return '"' .. s:gsub("|", "\\u007c") .. '"' -- "|" breaks WoW edit boxes
end

local function isArray(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
    n = n + 1
  end
  for i = 1, n do if t[i] == nil then return false end end
  return true, n
end

local function toJSON(v, buf)
  local t = type(v)
  if t == "table" then
    local arr, n = isArray(v)
    if arr then
      buf[#buf + 1] = "["
      for i = 1, n do
        if i > 1 then buf[#buf + 1] = "," end
        toJSON(v[i], buf)
      end
      buf[#buf + 1] = "]"
    else
      buf[#buf + 1] = "{"
      local first = true
      for k, val in pairs(v) do
        if not first then buf[#buf + 1] = "," end
        first = false
        buf[#buf + 1] = jsonString(tostring(k))
        buf[#buf + 1] = ":"
        toJSON(val, buf)
      end
      buf[#buf + 1] = "}"
    end
  elseif t == "string" then
    buf[#buf + 1] = jsonString(v)
  elseif t == "number" then
    buf[#buf + 1] = (v ~= v or v == math.huge or v == -math.huge) and "null" or tostring(v)
  elseif t == "boolean" then
    buf[#buf + 1] = tostring(v)
  else
    buf[#buf + 1] = "null"
  end
end

-- /gwp export: everything but the auction scan (it's big); /gwp export ah: only that.
function P.export(arg)
  local d, out = db(), {}
  if arg == "ah" then
    if not d.scans.auction then return say("no auction scan yet: /gwp ah at the auction house") end
    out = { scans = { auction = d.scans.auction } }
  else
    for k, v in pairs(d) do out[k] = v end
    out.scans = {}
    for k, v in pairs(d.scans) do if k ~= "auction" then out.scans[k] = v end end
  end
  local buf = {}
  toJSON(out, buf)
  local text = table.concat(buf)
  if not P.exportFrame then
    local f = CreateFrame("Frame", "GearwrightProbeExport", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(640, 440)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "GearwrightProbeExport")
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("GearwrightProbe export  -  Ctrl+A, Ctrl+C, paste into a .json file")
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -30)
    sf:SetPoint("BOTTOMRIGHT", -32, 12)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(580)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    sf:SetScrollChild(eb)
    f.edit = eb
    P.exportFrame = f
  end
  P.exportFrame.edit:SetText(text)
  P.exportFrame:Show()
  P.exportFrame.edit:SetFocus()
  P.exportFrame.edit:HighlightText()
  say("export: %d characters", #text)
end

-- Auction house ------------------------------------------------------------------
-- /gwp ah, with the auction house open: one full scan of every listing
-- (C_AuctionHouse.ReplicateItems; the server allows one every 15 minutes).
-- Gear is recorded in full (link, level, slot, stats, tooltip text), so we get
-- the stats of hundreds of items nobody has to equip. Everything else only
-- keeps its lowest unit buyout, for crafting costs later. Sellers' names are
-- never recorded.
local AH_BATCH, AH_RETRIES, AH_COOLDOWN = 400, 6, 15 * 60

local function isGear(itemID)
  if not (C_Item and C_Item.GetItemInfoInstant) then return false end
  local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
  if (classID == 2 or classID == 4) and type(equipLoc) == "string" and equipLoc ~= ""
      and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and equipLoc ~= "INVTYPE_BAG" then
    return true, equipLoc, classID, subclassID
  end
  return false
end

-- Full record of one gear listing, or nil when the client hasn't the data yet.
local function readGear(index, itemID)
  local link = sanitize(C_AuctionHouse.GetReplicateItemLink(index))
  if type(link) ~= "string" then return nil end
  local info = pack(C_Item.GetItemInfo(link))
  if info[1] == nil then return nil end
  local _, equipLoc, classID, subclassID = isGear(itemID)
  local tip = capture("C_TooltipInfo.GetHyperlink", link)
  local stats = itemStats(link)
  return {
    id = itemID, name = sanitize(info[1]), link = link, quality = sanitize(info[3]),
    ilvl = sanitize(info[4]), reqLevel = sanitize(info[5]), equip = equipLoc,
    class = classID, sub = subclassID, stats = stats.values and stats.values[1],
    tooltip = tooltipLines(tip.values and tip.values[1]),
  }
end

local ah = { open = false }

local function ahFinish(scan, waiting)
  scan.pending = nil
  local gear, prices = 0, 0
  for _ in pairs(scan.gear) do gear = gear + 1 end
  for _ in pairs(scan.prices) do prices = prices + 1 end
  scan.missing = waiting
  ah.scanning = false
  say("auction house: %d listings, %d gear items recorded, %d other items priced%s",
    scan.listings, gear, prices, waiting > 0 and (", %d gear items had no data"):format(waiting) or "")
  say("/reload, then send the SavedVariables file, or /gwp export ah")
end

-- Gear listings whose item data wasn't loaded: ask the server, try again.
local function ahRetry(scan, todo, try)
  if not ah.open then return ahFinish(scan, #todo) end
  local left = {}
  for _, t in ipairs(todo) do
    local rec = not t.done and readGear(t.index, t.id)
    if rec then
      -- The listing's name is empty until its data loads, so key by the real
      -- name now and merge listings that were split by that.
      t.done = true
      local key = t.id .. ":" .. tostring(rec.name)
      local prev = scan.gear[key]
      if prev then
        prev.listings = prev.listings + t.listings
        if t.buyout and (not prev.minBuyout or t.buyout < prev.minBuyout) then prev.minBuyout = t.buyout end
      else
        rec.minBuyout, rec.listings = t.buyout, t.listings
        scan.gear[key] = rec
      end
    elseif not t.done then
      left[#left + 1] = t
      if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, t.id) end
    end
  end
  if #left > 0 and try < AH_RETRIES then
    say("auction house: waiting for %d items...", #left)
    return C_Timer.After(1.5, function() ahRetry(scan, left, try + 1) end)
  end
  ahFinish(scan, #left)
end

local function ahProcess()
  local n = C_AuctionHouse.GetNumReplicateItems() or 0
  local scan = { at = now(), listings = n, gear = {}, prices = {} }
  db().scans.auction = scan
  local todo, byKey = {}, {}
  say("auction house: %d listings, reading...", n)
  local function batch(start)
    if not ah.open then return ahFinish(scan, #todo) end
    for i = start, math.min(start + AH_BATCH, n) - 1 do
      local info = pack(C_AuctionHouse.GetReplicateItemInfo(i))
      local count, buyout, itemID = info[3], info[10], info[17]
      if type(itemID) == "number" then
        local unit = (type(buyout) == "number" and buyout > 0 and type(count) == "number" and count > 0)
          and math.floor(buyout / count) or nil
        local key = tostring(itemID)
        if isGear(itemID) then
          -- Random-suffix items share an ID: tell them apart by name (empty
          -- until the item's data loads; ahRetry re-keys by the real name).
          key = key .. ":" .. tostring(sanitize(info[1]))
          local t = byKey[key]
          if not t then
            t = { key = key, index = i, id = itemID, listings = 0 }
            byKey[key] = t
            todo[#todo + 1] = t
          end
          t.listings = t.listings + 1
          if unit and (not t.buyout or unit < t.buyout) then t.buyout = unit end
        elseif unit and (not scan.prices[key] or unit < scan.prices[key]) then
          scan.prices[key] = unit
        end
      end
    end
    if start + AH_BATCH < n then
      return C_Timer.After(0.05, function() batch(start + AH_BATCH) end)
    end
    ahRetry(scan, todo, 1)
  end
  batch(0)
end

function P.ah()
  if not (C_AuctionHouse and C_AuctionHouse.ReplicateItems) then
    return say("no C_AuctionHouse.ReplicateItems on this client")
  end
  if not ah.open then return say("open the auction house first") end
  if ah.scanning then return say("auction house: already scanning") end
  local last = db().ahLastScan
  if last and time() - last < AH_COOLDOWN then
    return say("auction house: the server allows one full scan every 15 minutes; try again in %d min",
      math.ceil((AH_COOLDOWN - (time() - last)) / 60))
  end
  db().ahLastScan = time()
  ah.scanning = true
  ah.waiting = true
  say("auction house: full scan requested; keep the window open until it says done")
  C_AuctionHouse.ReplicateItems()
end

-- Wiring ----------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRAINER_SHOW")
pcall(events.RegisterEvent, events, "TRAINER_UPDATE")
events:RegisterEvent("INSPECT_READY")
events:RegisterEvent("LOOT_OPENED")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "REPLICATE_ITEM_LIST_UPDATE" }) do
  pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    persistenceCheck()
  elseif event == "PLAYER_LOGIN" then
    hookSheet()
    say("%s  -  type /gwp all", persistReport or "")
  elseif event == "TRADE_SKILL_SHOW" then
    C_Timer.After(0.5, scanTradeSkill) -- let the list populate
  elseif event == "TRAINER_SHOW" then
    C_Timer.After(0.5, scanTrainer)
  elseif event == "TRAINER_UPDATE" and not trainerBusy and not P.trainerQueued then
    P.trainerQueued = true -- you changed the filter: read it again, once
    C_Timer.After(0.5, function() P.trainerQueued = false; scanTrainer() end)
  elseif event == "LOOT_OPENED" then
    recordLoot()
  elseif event == "AUCTION_HOUSE_SHOW" then
    ah.open = true
  elseif event == "AUCTION_HOUSE_CLOSED" then
    ah.open = false
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" and ah.waiting then
    ah.waiting = false
    ahProcess()
  elseif event == "INSPECT_READY" and P.inspecting then
    onInspectReady()
  end
end)

-- Items by ID -------------------------------------------------------------------
-- The client can describe any item, owned or not, once the server has sent it.
-- Default set: Forever items that Wowhead lists with ratings, to see how the
-- client itself reports them, plus a few to compare against known data.
local DEFAULT_ITEMS = {
  13404,  -- Mask of the Unforgiven: 20 hit + 14 crit rating ("2.0%" / "1.0%"); didn't load on the beta
  21278,  -- Stormshroud Gloves: 10 hit + 14 crit rating
  16711,  -- Shadowcraft Boots: 3 hit rating ("0.3%")
  272395, -- Assassin's Waistguard: 20 hit rating, new for Forever
  276105, -- Scoutmaster's Eyepatch: 7 hit rating, new for Forever
  7348,   -- Fletcher's Gloves: 14 crit rating, level 20
  240080, -- Waywatcher Headdress: haste + expertise rating
  279899, -- Catacomb Cloak: Wowhead and the beta disagree on its stats
  252504, -- Brawler's Leather Hood: new for Forever, level 20
  5540,   -- Pearl-handled Dagger: equipped, as a control
}

local function readItem(id)
  local info = capture("C_Item.GetItemInfo", id)
  if info.status == "missing" then info = capture("GetItemInfo", id) end
  local v = info.values or {}
  if v[1] == nil or v[1] == "<nil>" then return nil end -- not sent by the server yet
  local link = type(v[2]) == "string" and v[2] or ("item:" .. id)
  local tip = capture("C_TooltipInfo.GetItemByID", id)
  if tip.status ~= "ok" then tip = capture("C_TooltipInfo.GetHyperlink", link) end
  return {
    link = link, info = info, instant = capture("C_Item.GetItemInfoInstant", id),
    stats = itemStats(link), tooltip = tooltipLines(tip.values and tip.values[1]),
  }
end

function P.items(arg)
  local ids = {}
  for id in (arg or ""):gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
  if #ids == 0 then ids = DEFAULT_ITEMS end
  for _, id in ipairs(ids) do
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
  local d = db()
  d.scans.items = d.scans.items or {}
  local out, read = d.scans.items, 0
  local function pass(list, try)
    local missing = {}
    for _, id in ipairs(list) do
      local r = readItem(id)
      if r then out[tostring(id)] = r; read = read + 1 else missing[#missing + 1] = id end
    end
    if #missing > 0 and try < 4 and C_Timer then
      return C_Timer.After(1, function() pass(missing, try + 1) end)
    end
    local tokens = {}
    for _, id in ipairs(ids) do
      local r = out[tostring(id)]
      local st = r and r.stats.values and r.stats.values[1]
      if type(st) == "table" then for token in pairs(st) do tokens[token] = true end end
    end
    local names = {}
    for token in pairs(tokens) do names[#names + 1] = token end
    table.sort(names)
    say("items: read %d of %d%s", read, #ids, #missing > 0 and (" (no data for " .. table.concat(missing, ", ") .. ")") or "")
    if #names > 0 then say("item stat tokens: %s", table.concat(names, ", ")) end
  end
  pass(ids, 1)
end

-- Encounter Journal --------------------------------------------------------------
-- Dungeon and raid loot tables, if this client fills them. Lists every instance
-- in the current tier with its bosses, then reads loot a moment later (the
-- client loads it on request).
-- Journal instance IDs of Classic dungeons and raids in the modern Encounter
-- Journal (Deadmines 63, Wailing Caverns 240, Ragefire 226, Shadowfang 64,
-- Stockade 238, Blackfathom 227, Gnomeregan 231, Molten Core 741, Onyxia 760...).
-- Asked for directly when the tier listing comes back empty.
local KNOWN_INSTANCES = { 63, 240, 226, 64, 238, 227, 231, 233, 311, 316, 234, 241, 230, 229, 236, 741, 742, 743, 744, 760 }

local function ejInstances(diag)
  local list, seen = {}, {}
  local tiers = capture("EJ_GetNumTiers")
  local numTiers = tiers.values and tonumber(tiers.values[1]) or 0
  diag.tiers = numTiers
  diag.currentTier = capture("EJ_GetCurrentTier")
  for tier = 1, math.max(numTiers, 1) do
    if EJ_SelectTier and numTiers > 0 then pcall(EJ_SelectTier, tier) end
    for _, raid in ipairs({ false, true }) do
      for i = 1, 60 do
        local r = capture("EJ_GetInstanceByIndex", i, raid)
        local id = r.values and r.values[1]
        if type(id) ~= "number" then break end
        if not seen[id] then
          seen[id] = true
          list[#list + 1] = { id = id, name = r.values[2], raid = raid, tier = tier, bosses = {} }
        end
      end
    end
  end
  if #list == 0 then
    diag.known = {}
    for _, id in ipairs(KNOWN_INSTANCES) do
      local r = capture("EJ_GetInstanceInfo", id)
      local name = r.values and r.values[1]
      diag.known[#diag.known + 1] = { id = id, status = r.status, name = name }
      if type(name) == "string" and name ~= "<nil>" then
        list[#list + 1] = { id = id, name = name, raid = r.values[9] == true, bosses = {}, byID = true }
      end
    end
  end
  return list
end

local function ejLoot(inst)
  if EJ_SelectInstance then pcall(EJ_SelectInstance, inst.id) end
  local n = capture("EJ_GetNumLoot")
  inst.lootCount = n.values and n.values[1]
  inst.loot = {}
  local count = type(inst.lootCount) == "number" and math.min(inst.lootCount, 8) or 0
  for k = 1, count do inst.loot[k] = capture("C_EncounterJournal.GetLootInfoByIndex", k) end
end

function P.ej()
  if not EJ_GetInstanceByIndex then return say("no Encounter Journal API on this client") end
  local out = { at = now(), filter = capture("EJ_GetLootFilter"), diag = {} }
  -- The journal's data may only be filled once its UI module is loaded.
  local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
  if load then
    local ok, loaded, reason = pcall(load, "Blizzard_EncounterJournal")
    out.diag.loadUI = { ok = ok, loaded = sanitize(loaded), reason = sanitize(reason) }
  end
  out.instances = ejInstances(out.diag)
  for _, inst in ipairs(out.instances) do
    if EJ_SelectInstance then pcall(EJ_SelectInstance, inst.id) end
    for e = 1, 30 do
      local r = capture("EJ_GetEncounterInfoByIndex", e, inst.id)
      local name = r.values and r.values[1]
      if type(name) ~= "string" or name == "<nil>" then break end
      inst.bosses[#inst.bosses + 1] = { name = name, id = r.values[3] }
    end
  end
  db().scans.ej = out
  local found = 0
  for _, k in ipairs(out.diag.known or {}) do if type(k.name) == "string" and k.name ~= "<nil>" then found = found + 1 end end
  say("encounter journal: %d tiers, %d instances%s; UI module %s; reading loot...", out.diag.tiers or 0,
    #out.instances, out.diag.known and (" (by ID: " .. found .. " of " .. #KNOWN_INSTANCES .. ")") or "",
    out.diag.loadUI and tostring(out.diag.loadUI.loaded) or "not loadable")
  local function readAll()
    local withLoot = 0
    for _, inst in ipairs(out.instances) do
      ejLoot(inst)
      if (inst.lootCount or 0) > 0 then withLoot = withLoot + 1 end
    end
    say("encounter journal: loot listed for %d of %d instances", withLoot, #out.instances)
  end
  if C_Timer then C_Timer.After(2, readAll) else readAll() end
end

local COMMANDS = {
  env = P.env, api = P.api, talents = P.talents, gear = P.gear, stats = P.stats, export = P.export,
  items = P.items, ej = P.ej, ah = P.ah,
  sheet = function() P.sheet() end,
  all = function()
    P.env(); P.api(); P.talents(); P.gear(); P.stats()
    -- Never open the character sheet from here: read it only if it's already
    -- open. It's recorded automatically whenever you open it yourself, and
    -- /gwp sheet still opens it on purpose.
    local frame = _G.PaperDollFrame
    if frame and frame:IsVisible() then
      P.sheet(true)
    else
      say("character sheet not read (open it any time and it's recorded, or /gwp sheet)")
    end
    say("done. /reload to flush SavedVariables, or /gwp export to copy it out.")
  end,
  inspect = function()
    if not UnitExists("target") then return say("target someone first") end
    P.inspecting = true
    NotifyInspect("target")
  end,
  persist = function() say(persistReport or "no report") end,
  clear = function() GearwrightProbeDB = nil; current = nil; say("cleared") end,
}

SLASH_GEARWRIGHTPROBE1 = "/gwp"
SlashCmdList.GEARWRIGHTPROBE = function(msg)
  local cmd, rest = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  local fn = COMMANDS[cmd]
  if fn then
    local ok, err = pcall(fn, rest)
    if not ok then say("|cffff5050error:|r %s", tostring(err)) end
  else
    say("usage: /gwp all | env | api | talents | gear | stats | sheet | items [ids] | ej | ah")
    say("       /gwp inspect | persist | export [ah] | clear")
    say("passive: open your character sheet, a profession window or class trainer and it is recorded automatically;")
    say("loot you open is logged with what dropped it")
  end
end
