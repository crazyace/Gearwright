-- Gearwright: main window. Deliberately plain text for v0.x; real UI in Phase 2.
local _, ns = ...

local UI = {}
ns.UI = UI

local REASONS = {
  ["no-build-data"] = "No recommended build for this spec yet.",
  ["no-enchant-data"] = "No enchant recommendations for this spec yet.",
  ["no-talent-points"] = "Spend some talent points so Gearwright can detect your spec.",
  ["traits-api-not-implemented"] = "Talent API not supported yet (run GearwrightProbe).",
  ["no-talent-api"] = "This client exposes no talent API Gearwright knows.",
}
local function why(reason) return REASONS[reason] or ("Unavailable (" .. tostring(reason) .. ")") end

local function buildText()
  local out = {}
  local function add(s, ...) out[#out + 1] = select("#", ...) > 0 and s:format(...) or s end

  local ctx, reason = ns.Advisor.Context()
  if not ctx then return why(reason) end

  local spec = ctx.class.specs[ctx.spec]
  add("|cffffd100Spec:|r %s  |cff999999(%s)|r", spec.label, ctx.specHow)
  if ctx.class.weights._status == "provisional" then
    add("|cffff9900Stat weights are provisional placeholders.|r")
  end

  add(" ")
  add("|cffffd100Gear|r")
  local gear = ns.Advisor.GearReport()
  for _, row in ipairs(gear or {}) do
    add("  %-10s %s  %s", row.name, row.link or "|cff666666empty|r",
      row.score and ("|cff4fc3f7" .. ns.util.round(row.score, 1) .. "|r") or "")
  end

  add(" ")
  add("|cffffd100Talents|r")
  local talents, tReason = ns.Advisor.TalentReport()
  if not talents then add("  " .. why(tReason))
  elseif #talents == 0 then add("  Matches the recommended build.")
  else
    for _, r in ipairs(talents) do add("  %s: %d / %d", r.name, r.have, r.want) end
  end

  add(" ")
  add("|cffffd100Enchants|r")
  local enchants, eReason = ns.Advisor.EnchantReport()
  if not enchants then add("  " .. why(eReason))
  else
    for _, r in ipairs(enchants) do
      add("  %-10s %s", r.name, r.ok and "|cff40ff40OK|r" or ("|cffff5050missing:|r " .. r.wantName))
    end
  end

  return table.concat(out, "\n")
end

function UI.Create()
  if UI.frame then return UI.frame end
  local f = CreateFrame("Frame", "GearwrightFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(460, 520)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()
  tinsert(UISpecialFrames, "GearwrightFrame") -- close on Escape

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", 0, -5)
  f.title:SetText("Gearwright " .. ns.version)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -32)
  scroll:SetPoint("BOTTOMRIGHT", -32, 12)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(400, 1)
  scroll:SetScrollChild(content)

  f.text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("TOPLEFT")
  f.text:SetWidth(400)
  f.text:SetJustifyH("LEFT")
  f.content = content

  f:SetScript("OnShow", UI.Refresh)
  UI.frame = f
  return f
end

function UI.Refresh()
  local f = UI.frame
  if not f then return end
  f.text:SetText(buildText())
  f.content:SetHeight(f.text:GetStringHeight() + 8)
end

function UI.Toggle()
  local f = UI.Create()
  f:SetShown(not f:IsShown())
end

ns:On("PLAYER_EQUIPMENT_CHANGED", function()
  if UI.frame and UI.frame:IsShown() then UI.Refresh() end
end)
