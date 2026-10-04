-- Gearwright: pins on the world map (e.g. the weapon master who trains a skill).
-- Forever's user-waypoint API isn't reliable, so pins are our own buttons on
-- the map canvas, placed when the map shows their zone. Right-click removes one.
-- Pins are saved, so they survive a reload until removed.
local _, ns = ...

local Pins = {}
ns.MapPins = Pins

local ICON = "Interface\\Icons\\INV_Sword_27"
local buttons = {}

local function list()
  if not ns.db then return {} end
  ns.db.pins = ns.db.pins or {}
  return ns.db.pins
end

local function canvas()
  local map = rawget(_G, "WorldMapFrame")
  if not map then return nil end
  if map.GetCanvas then
    local ok, c = pcall(map.GetCanvas, map)
    if ok and c then return c, map end
  end
  return map.ScrollContainer and (map.ScrollContainer.Child or map.ScrollContainer), map
end

local function button(parent, i)
  local b = buttons[i]
  if b then return b end
  b = CreateFrame("Button", nil, parent)
  b:SetSize(36, 36) -- canvas units: about icon size at the default zoom
  b:SetFrameLevel(10000) -- above the map's own pins
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexture(ICON)
  b:RegisterForClicks("RightButtonUp")
  b:SetScript("OnEnter", function(self)
    local p = self.pin
    if not (p and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(p.title or "Gearwright")
    if p.text then GameTooltip:AddLine(p.text, 1, 1, 1, true) end
    if p.note then GameTooltip:AddLine(p.note, 1, 0.6, 0, true) end
    GameTooltip:AddLine("Right-click to remove", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:SetScript("OnClick", function(self) Pins.Remove(self.pin) end)
  buttons[i] = b
  return b
end

-- Place the pins that belong to the map being shown.
function Pins.Refresh()
  for _, b in pairs(buttons) do b:Hide() end
  local c, map = canvas()
  if not (c and map and map:IsShown() and map.GetMapID) then return end
  local mapID = map:GetMapID()
  local w, h = c:GetWidth(), c:GetHeight()
  local n = 0
  for _, p in ipairs(list()) do
    if p.mapID == mapID then
      n = n + 1
      local b = button(c, n)
      b.pin = p
      b:ClearAllPoints()
      b:SetPoint("CENTER", c, "TOPLEFT", p.x * w, -p.y * h)
      b:Show()
    end
  end
end

local function same(a, b) return a.mapID == b.mapID and a.title == b.title end

function Pins.Add(pin)
  local l = list()
  for i, p in ipairs(l) do
    if same(p, pin) then l[i] = pin; return Pins.Refresh() end
  end
  l[#l + 1] = pin
  Pins.Refresh()
end

function Pins.Remove(pin)
  local l = list()
  for i = #l, 1, -1 do if same(l[i], pin) then table.remove(l, i) end end
  Pins.Refresh()
end

function Pins.Clear()
  if ns.db then ns.db.pins = {} end
  Pins.Refresh()
end

-- Open the world map on `mapID`.
function Pins.Open(mapID)
  local _, map = canvas()
  if not map then return end
  if not map:IsShown() then
    if OpenWorldMap then pcall(OpenWorldMap, mapID) elseif ToggleWorldMap then pcall(ToggleWorldMap) end
  end
  if map.SetMapID then pcall(map.SetMapID, map, mapID) end
  Pins.Refresh()
end

-- Follow the map: redraw when it opens or changes zone.
ns:On("PLAYER_LOGIN", function()
  local _, map = canvas()
  if not map then return end
  map:HookScript("OnShow", Pins.Refresh)
  if map.OnMapChanged and hooksecurefunc then hooksecurefunc(map, "OnMapChanged", Pins.Refresh) end
  local last
  local watch = CreateFrame("Frame", nil, map)
  watch:SetScript("OnUpdate", function()
    local id = map.GetMapID and map:GetMapID()
    if id ~= last then last = id; Pins.Refresh() end
  end)
end)
