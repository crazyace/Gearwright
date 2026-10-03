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
  "GetInventoryItemLink", "C_PaperDollInfo.GetInspectItemLevel",
  -- character stats
  "UnitStat", "UnitAttackPower", "UnitAttackSpeed", "GetCritChance", "GetHitModifier",
  "GetSpellHitModifier", "GetExpertise", "GetHaste", "GetMeleeHaste", "GetCombatRating",
  "GetCombatRatingBonus", "GetDodgeChance", "GetParryChance", "GetArmorPenetration",
  -- professions / trainers
  "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetBaseProfessionInfo",
  "GetNumTradeSkills", "GetTradeSkillInfo", "GetNumTrainerServices", "GetTrainerServiceInfo",
  -- inspect
  "NotifyInspect", "CanInspect",
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
  if type(region) == "table" and type(region.GetText) == "function" then return sanitize(region:GetText()) end
end

-- Text of a frame's own font strings, e.g. "Agility:" and "66".
local function regionTexts(frame)
  local out = {}
  if type(frame.GetRegions) ~= "function" then return out end
  for _, r in ipairs({ frame:GetRegions() }) do
    if type(r.GetObjectType) == "function" and r:GetObjectType() == "FontString" then
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
  if tip:IsShown() then
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

local function collectSheet(frame, out, seen, depth)
  if depth > 10 or #out >= 150 or type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then return end
  local visible = type(frame.IsVisible) ~= "function" or frame:IsVisible()
  if visible then
    local static = type(frame.tooltip) == "string" or type(frame.tooltip2) == "string"
    local hover = hoverTooltip(frame)
    local key = hover and hover[1] or (static and tostring(frame.tooltip))
    if key and not seen[key] then
      seen[key] = true
      local texts = regionTexts(frame)
      out[#out + 1] = {
        label = fontText(frame.Label) or fontText(frame.Name) or texts[1],
        value = fontText(frame.Value) or texts[2],
        tooltip = static and sanitize(frame.tooltip) or nil,
        tooltip2 = static and sanitize(frame.tooltip2) or nil,
        hover = hover,
      }
    end
  end
  for _, child in ipairs({ frame:GetChildren() }) do collectSheet(child, out, seen, depth + 1) end
end

local function recordSheet(quiet)
  local root = _G.CharacterStatsPane or _G.PaperDollFrame or _G.CharacterFrame
  if not root then return say("no character sheet frame found") end
  local lines = {}
  collectSheet(root, lines, {}, 0)
  local s = snapshot()
  local old = s.sections.sheet
  if #lines == 0 and type(old) == "table" and #old > 0 then
    -- Never let an empty read (window closed) replace a real capture.
    if not quiet then say("character sheet: nothing visible, kept the %d lines recorded earlier", #old) end
    return
  end
  s.level = sanitize(UnitLevel("player"))
  s.sections.sheet = lines
  if #lines == 0 then
    say("character sheet: 0 stat lines; open it with C, expand every category, then /gwp sheet")
  elseif not quiet then
    say("character sheet: %d stat lines recorded", #lines)
  end
end

-- Records the sheet, opening the character window first if it is closed and
-- closing it again afterwards, so /gwp all doesn't depend on it being open.
function P.sheet(quiet)
  if InCombatLockdown and InCombatLockdown() then return say("leave combat first") end
  local frame = _G.PaperDollFrame
  if frame and not frame:IsVisible() and type(_G.ToggleCharacter) == "function" then
    P.sheetOpening = true
    local opened = pcall(_G.ToggleCharacter, "PaperDollFrame") and frame:IsVisible()
    if opened then
      -- Stat lines fill in after the window shows.
      C_Timer.After(0.5, function()
        P.sheetOpening = false
        recordSheet(quiet)
        if frame:IsVisible() then pcall(_G.ToggleCharacter, "PaperDollFrame") end
      end)
      return
    end
    P.sheetOpening = false
  end
  recordSheet(quiet)
end

local function hookSheet()
  local frame = _G.PaperDollFrame or _G.CharacterFrame
  if not frame or P.sheetHooked then return end
  P.sheetHooked = true
  -- Opening the window yourself records it too (unless P.sheet opened it).
  frame:HookScript("OnShow", function()
    if not P.sheetOpening then C_Timer.After(0.5, function() recordSheet(true) end) end
  end)
end

-- Event-driven scans (open the window, the probe records it) -----------------------
local function scanTradeSkill()
  local out = { at = now(), recipes = {} }
  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
    out.profession = capture("C_TradeSkillUI.GetBaseProfessionInfo")
    local ids = capture("C_TradeSkillUI.GetAllRecipeIDs")
    for _, id in ipairs((ids.values and ids.values[1]) or {}) do
      local info = capture("C_TradeSkillUI.GetRecipeInfo", id)
      local v = info.values and info.values[1]
      out.recipes[#out.recipes + 1] = { recipeID = id, name = type(v) == "table" and v.name or nil }
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
  say("recorded %d recipes (%s)", #out.recipes, tostring(out.api))
end

local function scanTrainer()
  local out = { at = now(), services = {} }
  for i = 1, (GetNumTrainerServices and GetNumTrainerServices() or 0) do
    out.services[i] = capture("GetTrainerServiceInfo", i)
  end
  db().scans["trainer:" .. tostring(sanitize(UnitName("npc")))] = out
  say("recorded %d trainer services", #out.services)
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

function P.export()
  local buf = {}
  toJSON(db(), buf)
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

-- Wiring ----------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRAINER_SHOW")
events:RegisterEvent("INSPECT_READY")
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
  elseif event == "INSPECT_READY" and P.inspecting then
    onInspectReady()
  end
end)

local COMMANDS = {
  env = P.env, api = P.api, talents = P.talents, gear = P.gear, stats = P.stats, export = P.export,
  sheet = function() P.sheet() end,
  all = function()
    P.env(); P.api(); P.talents(); P.gear(); P.stats(); P.sheet()
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
  local cmd = (msg or ""):lower():match("^(%S*)")
  local fn = COMMANDS[cmd]
  if fn then
    local ok, err = pcall(fn)
    if not ok then say("|cffff5050error:|r %s", tostring(err)) end
  else
    say("usage: /gwp all | env | api | talents | gear | stats | sheet | inspect | persist | export | clear")
    say("passive: open your character sheet, a profession window or class trainer and it is recorded automatically")
  end
end
