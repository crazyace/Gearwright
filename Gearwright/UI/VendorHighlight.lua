-- Gearwright: marks upgrades for sale in a vendor's window, with their score;
-- the best you can use gets the arrow. One you can't use yet (the
-- window tints it red: level, or a weapon skill you haven't trained) shows
-- its score in grey. Re-done on every page and when items arrive
-- from the server. (The auction house has no marks: its result list redraws
-- rows as you scroll, so the tooltip line there says what's an upgrade.)
local _, ns = ...

local VendorHighlight = {}
ns.VendorHighlight = VendorHighlight

local UPGRADE = 0.5 -- same threshold as quest rewards and loot
local waiting = false

local function perPage() return rawget(_G, "MERCHANT_ITEMS_PER_PAGE") or 10 end

-- Whether the vendor window says you can use item `index` (it tints it red
-- if not). Mainline: C_MerchantFrame.GetItemInfo(index).isUsable; Classic:
-- GetMerchantItemInfo's 7th return. True when neither answers.
function VendorHighlight.Usable(index)
  local cm = rawget(_G, "C_MerchantFrame")
  if cm and cm.GetItemInfo then
    local ok, info = pcall(cm.GetItemInfo, index)
    if ok and type(info) == "table" and info.isUsable ~= nil then return info.isUsable and true or false end
  end
  local get = rawget(_G, "GetMerchantItemInfo")
  if get then
    local r = { pcall(get, index) }
    if r[1] and r[8] ~= nil then return r[8] and true or false end
  end
  return true
end

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
      out[#out + 1] = { button = button, row = rawget(_G, "MerchantItem" .. i), index = index,
        link = ns.API.clean(GetMerchantItemLink(index)) }
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
        local m = { it = it, delta = delta, usable = VendorHighlight.Usable(it.index) }
        marked[#marked + 1] = m
        if m.usable and (not best or delta > best.delta) then best = m end
      elseif why == "stats-unreadable" then
        waiting = true
      end
    else
      waiting = true -- not cached yet
    end
  end
  for _, m in ipairs(marked) do
    ns.QuestHighlight.Set(ns.QuestHighlight.Mark(m.it.button, "vendor", m.it.row), m == best, false, ns.Advisor.FormatScore(m.delta, true),
      not m.usable)
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
