-- Gearwright: the recipes of every profession this character has.
-- Forever allows two primary professions, but the game only lists the recipes
-- of the one whose window is open. Each time a profession window opens, its
-- recipes are saved per character, so crafting advice covers both.
-- The saved settings are account-wide, so your other characters' recipes are
-- there too: Professions.Alts lists the ones you could mail a crafted item from.
local _, ns = ...

local Professions = {}
ns.Professions = Professions

local function whoAmI()
  local name, realm = UnitFullName("player")
  name = ns.API.clean(name)
  realm = ns.API.clean(realm) or (GetRealmName and ns.API.clean(GetRealmName())) or ""
  return tostring(name), realm
end

local function charKey()
  local name, realm = whoAmI()
  return name .. "-" .. realm
end
Professions.CharKey = charKey

local function store()
  if not ns.db then return nil end
  ns.db.recipes = ns.db.recipes or {}
  ns.db.characters = ns.db.characters or {}
  local name, realm = whoAmI()
  local key = name .. "-" .. realm
  ns.db.characters[key] = { name = name, realm = realm, faction = ns.API.PlayerFaction() }
  ns.db.recipes[key] = ns.db.recipes[key] or ns.db.recipes[name .. "-"] or {} -- older saves had no realm
  ns.db.recipes[name .. "-"] = nil
  return ns.db.recipes[key]
end

-- Read the open profession window and save the recipes that make an item.
-- Returns the profession name, or nil, reason.
function Professions.Remember()
  local recipes, profession = ns.API.ReadRecipes()
  if not recipes then return nil, profession end
  if not profession then return nil, "no-profession-name" end
  local keep = {}
  for _, r in ipairs(recipes) do
    if r.itemID then keep[#keep + 1] = r end
  end
  local saved = store()
  if saved then saved[profession] = { at = date and date("%Y-%m-%d %H:%M") or nil, recipes = keep } end
  return profession
end

-- { [professionName] = { recipes } } for this character, the open window
-- included. Empty when no profession window has been opened yet.
function Professions.Known()
  Professions.Remember()
  local out = {}
  for name, p in pairs(store() or {}) do out[name] = p.recipes end
  return out
end

-- Your other characters on this realm and faction (the ones you can mail an
-- item from) that have opened a profession window with Gearwright loaded:
--   { { name, key, professions = { [name] = { recipes } } }, ... } sorted by name
function Professions.Alts()
  local out = {}
  if not ns.db or not ns.db.recipes then return out end
  local me = charKey()
  local _, realm = whoAmI()
  local faction = ns.API.PlayerFaction()
  for key, profs in pairs(ns.db.recipes) do
    local info = ns.db.characters and ns.db.characters[key]
    if key ~= me and info and info.realm == realm and (not faction or info.faction == faction) then
      local list = {}
      for prof, p in pairs(profs) do list[prof] = p.recipes end
      out[#out + 1] = { name = info.name, key = key, professions = list }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE" }) do
  ns:On(event, function() Professions.Remember() end)
end
