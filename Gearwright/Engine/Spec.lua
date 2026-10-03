-- Gearwright: work out which spec the player is playing.
local _, ns = ...

local Spec = {}
ns.Spec = Spec

function Spec.ClassData()
  local _, classToken = UnitClass("player")
  return ns.Data[classToken], classToken
end

-- Returns specKey, how ("override" | "talents"), or nil, reason.
function Spec.Detect()
  local classData, classToken = Spec.ClassData()
  if not classData then return nil, "class-not-supported:" .. tostring(classToken) end

  local override = ns.db and ns.db.specOverride
  if override and classData.specs[override] then return override, "override" end

  local talents, reason = ns.API.ReadTalents(classData.traitTabGroups)
  if not talents then return nil, reason end

  -- Spec = tab with the most points spent.
  local bestTab, bestPoints = nil, 0
  for tab, info in ipairs(talents.tabs) do
    if info.points > bestPoints then bestTab, bestPoints = tab, info.points end
  end
  if not bestTab then return nil, "no-talent-points" end

  local spec = classData.tabToSpec[bestTab]
  if not spec then return nil, "unknown-tab:" .. bestTab end
  return spec, "talents"
end
