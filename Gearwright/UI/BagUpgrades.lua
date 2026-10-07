-- Gearwright: an upgrade arrow on gear in your bags that beats what you wear
-- and that you can wear now. Works with Blizzard's bags and with Baganator
-- (through its upgrade-plugin API); other bag addons need their own hook.
local _, ns = ...

local Bags = {}
ns.BagUpgrades = Bags

local UPGRADE = 0.5 -- same threshold as quest rewards, vendors and loot
local ARROW_ATLAS, ARROW = "bags-greenarrow", "Interface\\Buttons\\Arrow-Up-Up"

-- link -> true / false, until gear, level, talents or the spec change.
local verdicts = {}
local waiting = false

-- true: an upgrade you can wear now; false: not; nil: not readable yet.
function Bags.IsUpgrade(link)
  if not link then return nil end
  local v = verdicts[link]
  if v ~= nil then return v end
  local delta, why, _, _, reqLevel = ns.Advisor.CompareToEquipped(link)
  if delta == nil and (why == "stats-unreadable" or why == "equipped-unreadable") then
    waiting = true
    return nil
  end
  v = type(delta) == "number" and delta > UPGRADE and not reqLevel
  verdicts[link] = v
  return v
end

-- Blizzard's bags ----------------------------------------------------------------

local arrows = {} -- item button -> our arrow texture

local function arrowFor(button)
  local a = arrows[button]
  if a then return a end
  a = button:CreateTexture(nil, "OVERLAY", nil, 2)
  local ct = rawget(_G, "C_Texture")
  if a.SetAtlas and ct and ct.GetAtlasInfo and ct.GetAtlasInfo(ARROW_ATLAS) then a:SetAtlas(ARROW_ATLAS) else a:SetTexture(ARROW) end
  a:SetSize(16, 16)
  a:SetPoint("TOPLEFT", -2, 2)
  arrows[button] = a
  return a
end

-- Every item button in an open Blizzard bag, with its bag and slot.
-- Mainline: ContainerFrameCombinedBags and ContainerFrame<n> list theirs
-- with EnumerateValidItems; older clients name them ContainerFrame<n>Item<m>.
function Bags.Buttons()
  local out = {}
  local function add(b)
    if b and b.GetID and b:IsShown() then
      local bag = (b.GetBagID and b:GetBagID()) or (b.GetParent and b:GetParent() and b:GetParent():GetID())
      out[#out + 1] = { button = b, bag = bag, slot = b:GetID() }
    end
  end
  local frames = { rawget(_G, "ContainerFrameCombinedBags") }
  for i = 1, 13 do frames[#frames + 1] = rawget(_G, "ContainerFrame" .. i) end
  for _, f in pairs(frames) do
    if f and f:IsShown() then
      if f.EnumerateValidItems then
        for _, b in f:EnumerateValidItems() do add(b) end
      else
        local name = f.GetName and f:GetName()
        if type(name) == "string" then
          for j = 1, 36 do add(rawget(_G, name .. "Item" .. j)) end
        end
      end
    end
  end
  return out
end

function Bags.Refresh()
  waiting = false
  local on = ns.QuestHighlight.Enabled()
  local shown = 0
  for _, it in ipairs(Bags.Buttons()) do
    local up = on and Bags.IsUpgrade(ns.API.GetContainerItemLink(it.bag, it.slot))
    if up then
      arrowFor(it.button):Show()
      shown = shown + 1
    elseif arrows[it.button] then
      arrows[it.button]:Hide()
    end
  end
  if not on then for _, a in pairs(arrows) do a:Hide() end end
  return shown
end

-- Baganator --------------------------------------------------------------------

local function baganatorAPI()
  local b = rawget(_G, "Baganator")
  return b and b.API
end

local function baganatorRefresh()
  local api = baganatorAPI()
  if api and api.RequestItemButtonsRefresh then pcall(api.RequestItemButtonsRefresh) end
end

local function hookBaganator()
  local api = baganatorAPI()
  if not (api and api.RegisterUpgradePlugin) or Bags.baganator then return end
  Bags.baganator = true
  api.RegisterUpgradePlugin("Gearwright", "gearwright", function(link)
    if not ns.QuestHighlight.Enabled() then return false end
    return Bags.IsUpgrade(link)
  end)
end

-- Wiring --------------------------------------------------------------------------

local queued = false
function Bags.Changed(forget)
  if forget then verdicts = {} end
  if queued then return end
  queued = true
  local function run() queued = false; Bags.Refresh(); baganatorRefresh() end
  if C_Timer then C_Timer.After(0, run) else run() end
end

for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
                         unpack(ns.API.TALENT_EVENTS) }) do
  ns:On(event, function() Bags.Changed(true) end)
end
ns:On("BAG_UPDATE_DELAYED", function() Bags.Changed() end)
ns:On("GET_ITEM_INFO_RECEIVED", function() if waiting then Bags.Changed() end end)
ns:On("PLAYER_LOGIN", function()
  hookBaganator()
  for _, fn in ipairs({ "OpenAllBags", "ToggleAllBags", "OpenBag", "ToggleBag", "ToggleBackpack", "OpenBackpack" }) do
    if hooksecurefunc and type(rawget(_G, fn)) == "function" then hooksecurefunc(fn, function() Bags.Changed() end) end
  end
end)
ns:On("ADDON_LOADED", function(name) if name == "Baganator" then hookBaganator() end end)
