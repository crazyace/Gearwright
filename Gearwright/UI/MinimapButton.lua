-- Gearwright: the minimap button (and a LibDataBroker feed for info bars such
-- as Titan Panel or ElvUI, when one is installed). Its tooltip shows your next
-- goal; left-click opens the window, right-click the wishlist, drag to move it.
local _, ns = ...

local Button = {}
ns.MinimapButton = Button

local ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local RADIUS = 80

-- The next goal, worked out in the background (util.Background) after anything
-- that can change it. Working it out scores every crafted item, which froze the
-- game for a moment when it ran on every mouse-over; hovering only reads this.
local goal, known = nil, false

local function goalLines()
  if not known then
    Button.Refresh()
    return { "|cff999999Working it out...|r" }
  end
  if not goal then return { "No upgrade known yet" } end
  return {
    ("%s |cff40ff40%s|r"):format(goal.link or goal.name or "?", ns.Advisor.FormatScore(goal.delta, true)),
    ns.Wishlist.When(goal.levelsAway) .. (goal.from and (" - " .. goal.from) or ""),
    goal.wished and nil or "|cff999999(best known upgrade; right-click upgrades to wishlist them)|r",
  }
end

-- Short text for info bars: "Gloves of the Fang (in 2 levels)".
function Button.ShortText()
  if not goal then return "Gearwright" end
  local name = goal.name or (goal.link and goal.link:match("%[(.-)%]")) or "next goal"
  return name .. (goal.levelsAway > 0 and (" (in %d)"):format(goal.levelsAway) or "")
end

local function fillTooltip(tip)
  tip:AddLine("Gearwright")
  tip:AddLine("Next goal:", 1, 0.82, 0.4)
  for _, line in ipairs(goalLines()) do tip:AddLine(line, 1, 1, 1, true) end
  tip:AddLine("Left-click: open  -  Right-click: wishlist", 0.6, 0.6, 0.6)
end

local function open(tab)
  local f = ns.UI.Create()
  if tab then ns.UI.Select(tab) end
  if not f:IsShown() or tab then f:Show() else f:Hide() end
end

local function place(b)
  local a = math.rad(ns.db.minimapAngle or 220)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

function Button.Create()
  if Button.frame or not Minimap then return Button.frame end
  local b = CreateFrame("Button", "GearwrightMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b.icon = b:CreateTexture(nil, "BACKGROUND")
  b.icon:SetSize(20, 20)
  b.icon:SetPoint("CENTER", 0, 1)
  b.icon:SetTexture(ICON)
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetSize(53, 53)
  b.border:SetPoint("TOPLEFT")
  b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  if b.SetHighlightTexture then b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight") end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnClick", function(_, button) open(button == "RightButton" and "wishlist" or nil) end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    fillTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- Drag around the minimap's edge; the angle is saved.
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      place(self)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  Button.frame = b
  place(b)
  return b
end

-- Show or hide per the setting.
function Button.Update()
  if not ns.db then return end
  if ns.db.minimap then
    local b = Button.Create()
    if b then b:Show() end
  elseif Button.frame then
    Button.frame:Hide()
  end
end

-- LibDataBroker feed, for info bars.
local feed
local function makeFeed()
  local stub = rawget(_G, "LibStub")
  local ldb = stub and stub("LibDataBroker-1.1", true)
  if not ldb then return end
  feed = ldb:NewDataObject("Gearwright", {
    type = "data source", text = "Gearwright", icon = ICON,
    OnClick = function(_, button) open(button == "RightButton" and "wishlist" or nil) end,
    OnTooltipShow = fillTooltip,
  })
end

-- Work the goal out again, a second after the last change (several events
-- often come together); one run at a time, with another after it if asked.
local queued, running, again, waiting = false, false, false, false
local function run()
  if running then again = true; return end
  running = true
  ns.util.Background(ns.Wishlist.NextGoal, function(ok, g, pending)
    running = false
    if ok then
      goal, known = g, true
      waiting = type(pending) == "number" and pending > 0 -- items still on their way from the server
      if feed then feed.text = Button.ShortText() end
    else
      ns.util.debug("next goal: %s", tostring(g))
    end
    if again then again = false; Button.Refresh() end
  end)
end

function Button.Refresh()
  if queued then return end
  if not C_Timer then return run() end
  queued = true
  C_Timer.After(1, function() queued = false; run() end)
end

ns:On("PLAYER_LOGIN", function()
  Button.Update()
  pcall(makeFeed)
  if C_Timer then C_Timer.After(5, Button.Refresh) end
end)
for _, event in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", unpack(ns.API.TALENT_EVENTS) }) do
  ns:On(event, Button.Refresh)
end
ns:On("GET_ITEM_INFO_RECEIVED", function() if waiting then Button.Refresh() end end)
