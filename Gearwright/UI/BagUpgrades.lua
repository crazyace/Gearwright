-- Gearwright: an upgrade arrow on gear in your bags that beats what you wear
-- and that you can wear now. Works with Blizzard's bags and finds the item
-- buttons of bag addons (Baganator, Bagnon, AdiBags and the like) on its own.
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

-- addon: a bag addon's button. Those often show the item level top left and
-- lay their own frames over the icon, so the arrow sits bottom right (where
-- they put Pawn's) on a frame of its own above them.
local function arrowFor(button, addon)
  local a = arrows[button]
  if a then return a end
  local host = button
  if addon and CreateFrame then
    host = CreateFrame("Frame", nil, button)
    host:SetAllPoints(button)
    local lvl = tonumber(button.GetFrameLevel and button:GetFrameLevel())
    if lvl and host.SetFrameLevel then host:SetFrameLevel(lvl + 10) end
  end
  a = host:CreateTexture(nil, "OVERLAY", nil, 2)
  local ct = rawget(_G, "C_Texture")
  if a.SetAtlas and ct and ct.GetAtlasInfo and ct.GetAtlasInfo(ARROW_ATLAS) then a:SetAtlas(ARROW_ATLAS) else a:SetTexture(ARROW) end
  a:SetSize(16, 16)
  if addon then a:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1) else a:SetPoint("TOPLEFT", -2, 2) end
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

-- Bag addons ----------------------------------------------------------------------
-- They draw their own item buttons, each knowing its bag and slot (or its link)
-- under one of a few names. Gearwright looks for those under UIParent's shown
-- frames, remembers which top-level frames held some, and walks only those
-- until bags are opened again.

local roots = {}         -- top-level frame -> true, once it held bag buttons
local blizzard = {}      -- Blizzard's own buttons, already handled above
local MAX_DEPTH = 8

local function num(v) return type(v) == "number" and v or nil end
local function call(obj, key)
  local fn = obj[key]
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, obj)
  return ok and v or nil
end

-- The item an addon's button shows: its link, or its bag and slot.
local function itemOf(b, itemButton)
  local bgr = type(b.BGR) == "table" and b.BGR -- Baganator
  local link = (bgr and bgr.itemLink) or b.itemLink or b.link
  if type(link) == "string" and link:find("item:", 1, true) then return { button = b, link = link, addon = true } end
  local bag = num(call(b, "GetBagID")) or num(call(b, "GetBag")) or num(b.bagID) or num(b.bagId) or num(b.bag)
  -- Buttons made from ContainerFrameItemButtonTemplate (EllesmereUI's) take
  -- their bag from the parent's ID, like Blizzard's own.
  if not bag and itemButton then
    local p = call(b, "GetParent")
    bag = p and num(call(p, "GetID"))
  end
  if not bag then return nil end
  local slot = num(b.slotID) or num(b.slotId) or num(b.slot) or num(call(b, "GetID"))
  if not slot or slot < 1 then return nil end
  return { button = b, bag = bag, slot = slot, addon = true }
end

local function shown(f) return type(f.IsShown) == "function" and f:IsShown() end

local function walk(f, depth, out)
  if depth > MAX_DEPTH or type(f.GetChildren) ~= "function" then return end
  for _, c in ipairs({ f:GetChildren() }) do
    if type(c) == "table" and shown(c) and not blizzard[c] then
      -- Blizzard's bag template makes an "ItemButton"; older addons a plain Button.
      local kind = type(c.GetObjectType) == "function" and c:GetObjectType()
      local it = (kind == "Button" or kind == "ItemButton") and itemOf(c, kind == "ItemButton")
      if it then out[#out + 1] = it else walk(c, depth + 1, out) end
    end
  end
end

-- Every shown item button from a bag addon. full = also look for new roots.
function Bags.AddonButtons(full)
  local out = {}
  local parent = rawget(_G, "UIParent")
  if not (parent and type(parent.GetChildren) == "function") then return out end
  local tops = {}
  if full or not next(roots) then
    for _, c in ipairs({ parent:GetChildren() }) do tops[#tops + 1] = c end
  else
    for r in pairs(roots) do tops[#tops + 1] = r end
  end
  for _, top in ipairs(tops) do
    if type(top) == "table" and shown(top) and not blizzard[top] then
      local before = #out
      walk(top, 1, out)
      if #out > before and not roots[top] then
        roots[top] = true
        -- The addon's own bag key doesn't go through OpenAllBags; its frame showing does.
        if type(top.HookScript) == "function" then top:HookScript("OnShow", function() Bags.Changed() end) end
      end
    end
  end
  return out
end

local function linkOf(it)
  return it.link or ns.API.GetContainerItemLink(it.bag, it.slot)
end

function Bags.Refresh(full)
  waiting = false
  local on = ns.QuestHighlight.Enabled()
  local shown_ = 0
  local list = Bags.Buttons()
  blizzard = {}
  for _, it in ipairs(list) do blizzard[it.button] = true end
  if on then
    local frames = { rawget(_G, "ContainerFrameCombinedBags") }
    for i = 1, 13 do frames[#frames + 1] = rawget(_G, "ContainerFrame" .. i) end
    for _, f in pairs(frames) do blizzard[f] = true end
    for _, it in ipairs(Bags.AddonButtons(full)) do list[#list + 1] = it end
  end
  local seen = {}
  for _, it in ipairs(list) do
    seen[it.button] = true
    local up = on and Bags.IsUpgrade(linkOf(it))
    if up then
      arrowFor(it.button, it.addon):Show()
      shown_ = shown_ + 1
    elseif arrows[it.button] then
      arrows[it.button]:Hide()
    end
  end
  -- Buttons an addon hid or reused for something else lose their arrow.
  for b, a in pairs(arrows) do if not seen[b] then a:Hide() end end
  return shown_
end

-- Wiring --------------------------------------------------------------------------

local queued, queuedFull = false, false
-- full: bags were just opened, so look for a bag addon's frames again.
function Bags.Changed(forget, full)
  if forget then verdicts = {} end
  queuedFull = queuedFull or full or false
  if queued then return end
  queued = true
  local function run()
    queued = false
    local f = queuedFull
    queuedFull = false
    Bags.Refresh(f)
  end
  if C_Timer then
    C_Timer.After(0, run)
    -- Bag addons fill their buttons a moment after the bag event; look again then.
    C_Timer.After(0.3, function() if not queued then Bags.Refresh(false) end end)
  else
    run()
  end
end

for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
                         unpack(ns.API.TALENT_EVENTS) }) do
  ns:On(event, function() Bags.Changed(true) end)
end
ns:On("BAG_UPDATE_DELAYED", function() Bags.Changed() end)
ns:On("GET_ITEM_INFO_RECEIVED", function() if waiting then Bags.Changed() end end)
ns:On("PLAYER_LOGIN", function()
  for _, fn in ipairs({ "OpenAllBags", "ToggleAllBags", "OpenBag", "ToggleBag", "ToggleBackpack", "OpenBackpack" }) do
    if hooksecurefunc and type(rawget(_G, fn)) == "function" then hooksecurefunc(fn, function() Bags.Changed(false, true) end) end
  end
end)
