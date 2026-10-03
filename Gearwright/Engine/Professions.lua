-- Gearwright: the recipes of every profession this character has.
-- Forever allows two primary professions, but the game only lists the recipes
-- of the one whose window is open. Each time a profession window opens, its
-- recipes are saved per character, so crafting advice covers both.
local _, ns = ...

local Professions = {}
ns.Professions = Professions

local function charKey()
  local name, realm = UnitFullName("player")
  return tostring(ns.API.clean(name)) .. "-" .. tostring(ns.API.clean(realm) or "")
end

local function store()
  if not ns.db then return nil end
  ns.db.recipes = ns.db.recipes or {}
  local key = charKey()
  ns.db.recipes[key] = ns.db.recipes[key] or {}
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

for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE" }) do
  ns:On(event, function() Professions.Remember() end)
end
