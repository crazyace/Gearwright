-- Gearwright: upgrade/downgrade line on item tooltips.
local _, ns = ...

if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end

local UP, DOWN, SAME = "|cff40ff40", "|cffff5050", "|cffaaaaaa"

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
  if not (ns.db and ns.db.showTooltip) then return end
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  if not tooltip.GetItem then return end

  local _, link = tooltip:GetItem()
  link = ns.API.clean(link)
  if not link then return end

  local delta, slot, _, _, reqLevel = ns.Advisor.CompareToEquipped(link)
  if slot == "wrong-weapon-type" then
    local ctx = ns.Advisor.Context()
    local spec = ctx and ctx.class.specs[ctx.spec]
    tooltip:AddLine(("|cff4fc3f7Gearwright|r |cffaaaaaa%s wants a dagger here|r"):format(spec and spec.label or "Your spec"))
    return
  end
  if type(delta) ~= "number" then return end

  local color = (delta > 0.05 and UP) or (delta < -0.05 and DOWN) or SAME
  local sign = delta > 0 and "+" or ""
  local spec = ns.Spec.Detect()
  local later = reqLevel and (" |cffff9900at level %d|r"):format(reqLevel) or ""
  tooltip:AddLine(("|cff4fc3f7Gearwright|r %s%s%.1f|r vs %s (%s)%s"):format(
    color, sign, delta, ns.Advisor.SLOT_NAMES[slot] or "equipped", spec or "?", later))

  -- Where an upgrade comes from, when a dungeon data addon knows.
  local itemID = delta > 0.05 and ns.API.GetItemBasics(link)
  local sources = itemID and ns.Sources.For(itemID)
  if sources then
    local more = #sources > 1 and (" |cff999999+%d more|r"):format(#sources - 1) or ""
    tooltip:AddLine(("|cffaaaaaa%s|r%s"):format(ns.Sources.Describe(sources[1]), more))
  end
end)
