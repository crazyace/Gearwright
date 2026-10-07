-- Gearwright: marks the quest reward to take in the quest window itself.
-- The best upgrade gets a green glow and its score; other upgrades get their
-- score; with no upgrade, the reward that sells for the most gets a coin.
-- Notices.QuestRewards works out the pick and calls Show.
local _, ns = ...

local QuestHighlight = {}
ns.QuestHighlight = QuestHighlight

local GLOW = "Interface\\Buttons\\UI-ActionButton-Border"
local COIN = "Interface\\MoneyFrame\\UI-GoldIcon"
local marks = {} -- one overlay per reward button, reused
QuestHighlight.marks = marks

-- The reward button for choice `i`. Mainline's quest window keeps its buttons
-- in QuestInfoFrame.rewardsFrame.RewardButtons (choices tagged type =
-- "choice"); older windows name them QuestInfoRewardsFrameQuestInfoItem<i>.
function QuestHighlight.Button(i)
  local qif = rawget(_G, "QuestInfoFrame")
  local rf = qif and qif.rewardsFrame
  for _, b in ipairs(rf and rf.RewardButtons or {}) do
    if b.type == "choice" and b.GetID and b:GetID() == i then return b end
  end
  return rawget(_G, "QuestInfoRewardsFrameQuestInfoItem" .. i) or rawget(_G, "QuestRewardItem" .. i)
end

local function mark(button)
  local m = marks[button]
  if m then return m end
  m = CreateFrame("Frame", nil, button)
  local icon = button.Icon or rawget(_G, (button.GetName and button:GetName() or "") .. "IconTexture") or button
  m:SetAllPoints(icon)
  m:SetFrameLevel((button.GetFrameLevel and tonumber(button:GetFrameLevel()) or 0) + 5)
  m.glow = m:CreateTexture(nil, "OVERLAY")
  m.glow:SetTexture(GLOW)
  m.glow:SetBlendMode("ADD")
  m.glow:SetVertexColor(0.25, 1, 0.25)
  m.glow:SetPoint("CENTER")
  m.glow:SetSize(70, 70)
  m.coin = m:CreateTexture(nil, "OVERLAY")
  m.coin:SetTexture(COIN)
  m.coin:SetSize(14, 14)
  m.coin:SetPoint("TOPRIGHT", 3, 3)
  m.score = m:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  m.score:SetPoint("BOTTOM", 0, 1)
  m.score:SetTextColor(0.25, 1, 0.25)
  marks[button] = m
  return m
end

function QuestHighlight.Hide()
  for _, m in pairs(marks) do m:Hide() end
end

-- rows: Notices.Evaluate's rows, by choice. best: the choice to take, or nil.
-- richest: with no upgrade, the choice that sells for the most.
-- Returns how many buttons were marked.
function QuestHighlight.Show(rows, best, richest, minDelta)
  QuestHighlight.Hide()
  if not (ns.db and ns.db.questHighlight) then return 0 end
  local shown = 0
  for i, row in ipairs(rows) do
    local upgrade = row.delta and row.delta > minDelta
    if upgrade or i == richest then
      local button = QuestHighlight.Button(i)
      if button then
        local m = mark(button)
        m.pick, m.sells = i == best, i == richest
        m.label = upgrade and ("+%.1f"):format(row.delta) or ""
        m.glow:SetShown(m.pick)
        m.coin:SetShown(m.sells)
        m.score:SetText(m.label)
        m:Show()
        shown = shown + 1
      end
    end
  end
  return shown
end

ns:On("QUEST_FINISHED", QuestHighlight.Hide)
