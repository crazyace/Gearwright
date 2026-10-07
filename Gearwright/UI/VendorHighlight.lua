-- Gearwright: marks upgrades for sale in a vendor's window, with their score;
-- the best on the page glows. Re-done on every page and when items arrive
-- from the server. (The auction house has no marks: its result list redraws
-- rows as you scroll, so the tooltip line there says what's an upgrade.)
local _, ns = ...

local VendorHighlight = {}
ns.VendorHighlight = VendorHighlight

local UPGRADE = 0.5 -- same threshold as quest rewards and loot
local waiting = false

local function perPage() return rawget(_G, "MERCHANT_ITEMS_PER_PAGE") or 10 end

-- The page's buttons: MerchantItem<i>ItemButton for i = 1..10, showing item
-- (page - 1) * 10 + i. Nothing on the Buyback tab.
function VendorHighlight.Items()
  local mf = rawget(_G, "MerchantFrame")
  if not (mf and mf:IsShown() and GetMerchantItemLink) or (mf.selectedTab or 1) ~= 1 then return {} end
  local out, first = {}, ((mf.page or 1) - 1) * perPage()
  for i = 1, perPage() do
    local button = rawget(_G, "MerchantItem" .. i .. "ItemButton")
    local index = first + i
    if button and index <= (GetMerchantNumItems and GetMerchantNumItems() or 0) then
      out[#out + 1] = { button = button, index = index, link = ns.API.clean(GetMerchantItemLink(index)) }
    end
  end
  return out
end

-- Returns how many items were marked.
function VendorHighlight.Refresh()
  ns.QuestHighlight.Hide("vendor")
  waiting = false
  if not ns.QuestHighlight.Enabled() then return 0 end
  local best, marked = nil, {}
  for _, it in ipairs(VendorHighlight.Items()) do
    if it.link then
      local delta, why = ns.Advisor.CompareToEquipped(it.link)
      if type(delta) == "number" and delta > UPGRADE then
        marked[#marked + 1] = { it = it, delta = delta }
        if not best or delta > best.delta then best = marked[#marked] end
      elseif why == "stats-unreadable" then
        waiting = true
      end
    else
      waiting = true -- not cached yet
    end
  end
  for _, m in ipairs(marked) do
    ns.QuestHighlight.Set(ns.QuestHighlight.Mark(m.it.button, "vendor"), m == best, false, ("+%.1f"):format(m.delta))
  end
  return #marked
end

local queued = false
local function later()
  if queued then return end
  if not C_Timer then return VendorHighlight.Refresh() end
  queued = true
  C_Timer.After(0, function() queued = false; VendorHighlight.Refresh() end)
end

ns:On("MERCHANT_SHOW", later)
ns:On("MERCHANT_UPDATE", later)
ns:On("PLAYER_EQUIPMENT_CHANGED", later)
ns:On("MERCHANT_CLOSED", function() ns.QuestHighlight.Hide("vendor") end)
ns:On("GET_ITEM_INFO_RECEIVED", function() if waiting then later() end end)
-- Paging and switching tabs redraw the window without an event.
for _, fn in ipairs({ "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo" }) do
  if hooksecurefunc and type(rawget(_G, fn)) == "function" then hooksecurefunc(fn, later) end
end
