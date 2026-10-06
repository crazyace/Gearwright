-- Gearwright: upgrade/downgrade line on item tooltips.
local _, ns = ...

local UP, DOWN, SAME = "|cff40ff40", "|cffff5050", "|cffaaaaaa"

local Tooltip = {}
ns.Tooltip = Tooltip

local function colored(delta)
  local color = (delta > 0.05 and UP) or (delta < -0.05 and DOWN) or SAME
  return ("%s%s%.1f|r"):format(color, delta > 0 and "+" or "", delta)
end

-- The lines Gearwright adds for an item, from Advisor.CompareSlots:
--   Gearwright +123.6 in Main Hand over Pearl-handled Dagger (Assassination)
--   Off Hand: +54.2 over Pearl-handled Dagger
--   Not counted: Intellect, chance on hit effect
-- The first line is the slot where it helps most; others follow.
function Tooltip.Lines(link, list)
  local ctx = ns.Advisor.Context()
  local spec = ctx and ctx.class.specs[ctx.spec]
  local function over(c)
    local name = c.equipped and c.equipped:match("%[(.-)%]")
    return name and (" over " .. name) or (c.equipped and " over equipped" or " (empty slot)")
  end
  local best = list[1]
  local reqLevel = ns.API.GetItemDetails(link)
  local level = ns.API.clean(UnitLevel("player"))
  local later = (reqLevel and level and reqLevel > level) and (" |cffff9900at level %d|r"):format(reqLevel) or ""
  local out = {
    ("|cff4fc3f7Gearwright|r %s in %s%s |cffaaaaaa(%s)|r%s"):format(colored(best.delta),
      ns.Advisor.SLOT_NAMES[best.slot] or "?", over(best), spec and spec.label or "?", later),
  }
  for i = 2, #list do
    local c = list[i]
    out[#out + 1] = ("|cffaaaaaa%s:|r %s|cffaaaaaa%s|r"):format(ns.Advisor.SLOT_NAMES[c.slot] or "?", colored(c.delta), over(c))
  end
  if ctx then
    local skip = ns.Stats.Unscored(ns.API.GetItemStats(link), ns.API.GetItemTooltipLines(link), ctx.weights)
    if #skip > 0 then out[#out + 1] = "|cffaaaaaaNot counted: " .. table.concat(skip, ", ") .. "|r" end
  end
  return out
end

if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
  if not (ns.db and ns.db.showTooltip) then return end
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  if not tooltip.GetItem then return end

  local _, link = tooltip:GetItem()
  link = ns.API.clean(link)
  if not link then return end

  local list, slot = ns.Advisor.CompareSlots(link)
  if slot == "wrong-weapon-type" then
    local ctx = ns.Advisor.Context()
    local spec = ctx and ctx.class.specs[ctx.spec]
    tooltip:AddLine(("|cff4fc3f7Gearwright|r |cffaaaaaa%s wants a dagger here|r"):format(spec and spec.label or "Your spec"))
    return
  end
  if slot == "no-dual-wield" then
    local ctx = ns.Advisor.Context()
    local dw = ctx and ctx.class.dualWield
    tooltip:AddLine(("|cff4fc3f7Gearwright|r |cffaaaaaaoff hand: you learn Dual Wield at level %d|r"):format(dw and dw.level or 10))
    return
  end
  if not list then return end
  for _, text in ipairs(Tooltip.Lines(link, list)) do tooltip:AddLine(text) end
end)
