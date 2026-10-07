-- Gearwright: marks the quest reward to take in the quest window itself.
-- Each upgrade shows its score in the entry's empty bottom-right corner, the
-- best with an up arrow; with no upgrade, the reward that sells for the most
-- gets a coin. Nothing goes on the icon: a ring or tint there reads as the
-- item's quality, and text covers the picture.
-- Notices.QuestRewards works out the pick and calls Show.
local _, ns = ...

local QuestHighlight = {}
ns.QuestHighlight = QuestHighlight

local ARROW = "Interface\\Buttons\\Arrow-Up-Up"
local ARROW_ATLAS = "bags-greenarrow"
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

-- The mark for `button` (made once), shared with UI/VendorHighlight.lua:
-- "+1.8", with an up arrow on the pick. group: who shows it ("quest",
-- "vendor"), so each hides only its own. Placed clear of the icon:
--   under = a font string (the reward's name): just below it, left-aligned, so
--     it can't be read as belonging to the reward beside it;
--   else: the bottom-right corner of `row` (the vendor entry, beside its price).
function QuestHighlight.Mark(button, group, row, under)
  local m = marks[button]
  if m then m.group = group; return m end
  row = row or button
  m = CreateFrame("Frame", nil, row)
  m:SetSize(70, 16)
  m.left = under ~= nil
  if m.left then
    m:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -1)
  else
    m:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 4)
  end
  m:SetFrameLevel((row.GetFrameLevel and tonumber(row:GetFrameLevel()) or 0) + 5)
  m.score = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  m.score:SetJustifyH(m.left and "LEFT" or "RIGHT")
  -- The bags' own "upgrade" arrow where the client has it.
  m.arrow = m:CreateTexture(nil, "OVERLAY")
  local ct = rawget(_G, "C_Texture")
  local atlas = m.arrow.SetAtlas and ct and ct.GetAtlasInfo and ct.GetAtlasInfo(ARROW_ATLAS)
  if atlas then m.arrow:SetAtlas(ARROW_ATLAS) else m.arrow:SetTexture(ARROW) end
  m.arrow:SetSize(14, 14)
  m.coin = m:CreateTexture(nil, "OVERLAY")
  m.coin:SetTexture(COIN)
  m.coin:SetSize(12, 12)
  if m.left then
    m.arrow:SetPoint("LEFT")
    m.coin:SetPoint("LEFT")
  else
    m.score:SetPoint("RIGHT")
    m.arrow:SetPoint("RIGHT", m.score, "LEFT", -2, 0)
    m.coin:SetPoint("RIGHT")
  end
  m.group = group
  marks[button] = m
  return m
end

-- Sets what a mark shows: the arrow (the pick), a coin (sells for the most),
-- a score. muted: an upgrade you can't use yet (grey score, no arrow).
function QuestHighlight.Set(m, pick, sells, label, muted)
  m.pick, m.sells, m.label, m.muted = pick and not muted, sells, label or "", muted
  m.arrow:SetShown(m.pick)
  m.coin:SetShown(sells)
  m.score:SetText(m.label)
  if m.left then
    m.score:ClearAllPoints()
    m.score:SetPoint("LEFT", (m.pick or sells) and 16 or 0, 0)
  end
  if muted then m.score:SetTextColor(0.6, 0.6, 0.6) else m.score:SetTextColor(0.25, 1, 0.25) end
  m:Show()
end

function QuestHighlight.Hide(group)
  group = type(group) == "string" and group or "quest"
  for _, m in pairs(marks) do
    if m.group == group then m:Hide() end
  end
end

-- The reward's name text: Mainline's button.Name, or <ButtonName>Name.
function QuestHighlight.NameOf(button)
  if type(button.Name) == "table" then return button.Name end
  local name = button.GetName and button:GetName()
  return type(name) == "string" and rawget(_G, name .. "Name") or nil
end

function QuestHighlight.Enabled() return ns.db and ns.db.questHighlight end

-- rows: Notices.Evaluate's rows, by choice. best: the choice to take, or nil.
-- richest: with no upgrade, the choice that sells for the most.
-- Returns how many buttons were marked.
function QuestHighlight.Show(rows, best, richest, minDelta)
  QuestHighlight.Hide()
  if not QuestHighlight.Enabled() then return 0 end
  local shown = 0
  for i, row in ipairs(rows) do
    local upgrade = row.delta and row.delta > minDelta
    if upgrade or i == richest then
      local button = QuestHighlight.Button(i)
      if button then
        QuestHighlight.Set(QuestHighlight.Mark(button, "quest", button, QuestHighlight.NameOf(button)), i == best, i == richest,
          upgrade and ns.Advisor.FormatScore(row.delta, true), row.usable == false)
        shown = shown + 1
      end
    end
  end
  return shown
end

ns:On("QUEST_FINISHED", function() QuestHighlight.Hide("quest") end)
