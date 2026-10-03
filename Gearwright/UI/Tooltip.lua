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

  local delta, slot = ns.Advisor.CompareToEquipped(link)
  if type(delta) ~= "number" then return end

  local color = (delta > 0.05 and UP) or (delta < -0.05 and DOWN) or SAME
  local sign = delta > 0 and "+" or ""
  local spec = ns.Spec.Detect()
  tooltip:AddLine(("|cff4fc3f7Gearwright|r %s%s%.1f|r vs %s (%s)"):format(
    color, sign, delta, ns.Advisor.SLOT_NAMES[slot] or "equipped", spec or "?"))
end)
