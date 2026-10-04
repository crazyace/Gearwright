-- Gearwright: a per-character wishlist of upgrades to chase, and the next goal.
-- Items are added from any upgrade row in the window (right-click). The next
-- goal is the wishlist item you can wear soonest (biggest gain first among
-- equals); with an empty wishlist, the biggest known upgrade.
local _, ns = ...

local Wishlist = {}
ns.Wishlist = Wishlist

local function list()
  if not ns.db then return {} end
  ns.db.wishlist = ns.db.wishlist or {}
  local key = ns.Professions.CharKey()
  ns.db.wishlist[key] = ns.db.wishlist[key] or {}
  return ns.db.wishlist[key]
end

function Wishlist.Items() return list() end

function Wishlist.Has(itemID)
  for _, e in ipairs(list()) do if e.itemID == itemID then return true end end
  return false
end

-- entry: { itemID, link, name, from }
function Wishlist.Add(entry)
  if not entry.itemID or Wishlist.Has(entry.itemID) then return end
  local l = list()
  l[#l + 1] = { itemID = entry.itemID, link = entry.link, name = entry.name, from = entry.from }
end

function Wishlist.Remove(itemID)
  local l = list()
  for i = #l, 1, -1 do if l[i].itemID == itemID then table.remove(l, i) end end
end

function Wishlist.Toggle(entry)
  if Wishlist.Has(entry.itemID) then Wishlist.Remove(entry.itemID) else Wishlist.Add(entry) end
end

-- An entry as it stands now: delta (vs what you wear), slot, reqLevel (when
-- above your level), equipped (already wearing it), link.
function Wishlist.Status(e, ctx)
  local item = e.link or ("item:" .. e.itemID)
  local link = ns.API.GetItemLink("item:" .. e.itemID) or e.link
  if link and not e.link then e.link = link end
  local delta, slot = ns.Advisor.CompareToEquipped(item, ctx)
  local reqLevel = ns.API.GetItemDetails(item)
  local level = ns.API.clean(UnitLevel("player")) or 1
  local equipped = false
  for s = 1, 19 do
    local eq = ns.API.GetEquippedLink(s)
    if eq and tonumber(eq:match("item:(%d+)")) == e.itemID then equipped = true end
  end
  return {
    entry = e, link = link or item, delta = type(delta) == "number" and delta or nil, slot = type(delta) == "number" and slot or nil,
    reqLevel = reqLevel, levelsAway = reqLevel and reqLevel > level and (reqLevel - level) or 0,
    equipped = equipped, why = type(delta) ~= "number" and slot or nil,
  }
end

-- Everything on the wishlist, soonest first: wearable now, then by levels away;
-- equal ones by biggest gain.
function Wishlist.Report()
  local ctx = ns.Advisor.Context()
  local out = {}
  for _, e in ipairs(list()) do out[#out + 1] = Wishlist.Status(e, ctx) end
  table.sort(out, function(a, b)
    if a.equipped ~= b.equipped then return not a.equipped end
    if a.levelsAway ~= b.levelsAway then return a.levelsAway < b.levelsAway end
    return (a.delta or -1e9) > (b.delta or -1e9)
  end)
  return out
end

-- The next goal: { link, name, delta, levelsAway, from, wished } or nil.
function Wishlist.NextGoal()
  for _, s in ipairs(Wishlist.Report()) do
    if not s.equipped and s.delta and s.delta > 0 then
      return { link = s.link, name = s.entry.name, delta = s.delta, levelsAway = s.levelsAway,
        from = s.entry.from, wished = true }
    end
  end
  local gear = ns.Advisor.GearOverview()
  local best
  for _, g in ipairs(gear or {}) do
    if g.best and (not best or g.best.delta > best.delta) then best = g.best end
  end
  if not best then return nil end
  local level = ns.API.clean(UnitLevel("player")) or 1
  return { link = best.link, name = best.name, delta = best.delta, from = best.from,
    levelsAway = best.reqLevel and best.reqLevel > level and (best.reqLevel - level) or 0 }
end

-- "available now" / "in 2 levels"
function Wishlist.When(levelsAway)
  if not levelsAway or levelsAway <= 0 then return "available now" end
  return ("in %d level%s"):format(levelsAway, levelsAway == 1 and "" or "s")
end
