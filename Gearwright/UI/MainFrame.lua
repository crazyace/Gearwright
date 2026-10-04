-- Gearwright: main window. A tab list on the left, item rows on the right.
-- Each tab builds plain row tables (UI.BuildRows); the frame only draws them,
-- so the content can be tested without a game client.
local _, ns = ...

local UI = {}
ns.UI = UI

local Theme = ns.Theme
local WIDTH, HEIGHT, NAV_WIDTH, ROW_HEIGHT = 720, 500, 150, 46
local EMPTY_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local REASONS = {
  ["no-build-data"] = "No recommended build for this spec yet.",
  ["no-enchant-data"] = "No enchant data loaded.",
  ["nothing-to-enchant"] = "Nothing equipped that takes an enchant.",
  ["no-talent-points"] = "Spend some talent points so Gearwright can detect your spec.",
  ["no-talent-config"] = "Talents aren't loaded yet; try again in a moment.",
  ["no-trait-tab-map"] = "No talent tree layout for this class yet.",
  ["traits-error"] = "Couldn't read talents (turn on /gearwright debug for details).",
  ["no-talent-api"] = "This client exposes no talent API Gearwright knows.",
  ["no-dungeon-data"] = "No dungeon loot known yet. Gearwright learns it from drops the probe records "
    .. "(see docs/BETA-CHECKLIST.md); installing Forever Dungeon Journal adds its loot tables too.",
}
local function why(reason) return REASONS[reason] or ("Unavailable (" .. tostring(reason) .. ")") end
UI.why = why

local function num(v) return ("%.1f"):format(v) end
local function plus(v) return (v >= 0 and "+" or "") .. num(v) end
local function slotName(slot) return ns.Advisor.SLOT_NAMES[slot] or "?" end

-- Tabs ---------------------------------------------------------------------------
-- A tab's build() returns rows, message. A row:
--   { icon, title, sub, value, valueColor, link, train,
--     hint = "line" or { "line", ... }   -- hover text (after the item tooltip)
--     onClick = function(button) end     -- left or right click (shift-click links)
--     header = true }                    -- a section heading: just `title`

local TABS = {}

TABS.gear = {
  label = "Gear", icon = "Interface\\Icons\\INV_Chest_Leather_09",
  build = function()
    local gear = ns.Advisor.GearReport()
    local rows = {}
    for _, g in ipairs(gear or {}) do
      rows[#rows + 1] = {
        icon = g.link and ns.API.GetItemIcon(g.link) or EMPTY_ICON,
        title = g.link or (Theme.Hex("muted") .. "empty|r"),
        sub = g.name, link = g.link,
        value = g.score and num(g.score), valueColor = "text",
      }
    end
    return rows
  end,
}

TABS.upgrades = {
  label = "Dungeons", icon = "Interface\\Icons\\INV_Misc_Book_09",
  build = function()
    local list, reason, pending = ns.Advisor.DungeonReport()
    if not list then return {}, why(reason) end
    local rows = {}
    for _, r in ipairs(list) do
      local s = r.sources[1]
      local sub = slotName(r.slot) .. "  -  " .. ns.Sources.Describe(s)
      if #r.sources > 1 then sub = sub .. (" (+%d more)"):format(#r.sources - 1) end
      if r.reqLevel then sub = sub .. Theme.Hex("warn") .. (" - level %d|r"):format(r.reqLevel) end
      if r.train then sub = sub .. Theme.Hex("warn") .. (" - train %s|r"):format(r.train) end
      if r.lowSkill then sub = sub .. Theme.Hex("warn") .. (" - %s, level it|r"):format(r.lowSkill) end
      rows[#rows + 1] = {
        icon = ns.API.GetItemIcon("item:" .. r.itemID) or EMPTY_ICON,
        title = r.link or r.name, sub = sub, link = r.link, train = r.train,
        value = plus(r.delta), valueColor = "good",
      }
    end
    local message
    if pending and pending > 0 then
      message = ("Reading %d more items from the server..."):format(pending)
    elseif #rows == 0 then
      message = "No dungeon upgrades for you up to " .. ns.Advisor.Lookahead() .. " levels ahead."
    end
    return rows, message
  end,
}

local CRAFT_COLOR = { craft = "good", alt = "good", learn = "warn", altlearn = "warn", yours = "warn", order = "muted" }

TABS.crafting = {
  label = "Crafting", icon = "Interface\\Icons\\Trade_BlackSmithing",
  build = function()
    local list, reason, pending = ns.Advisor.CraftReport()
    if not list then return {}, why(reason) end
    local rows = {}
    for _, r in ipairs(list) do
      local sub = slotName(r.slot) .. "  -  " .. Theme.Hex(CRAFT_COLOR[r.status]) .. ns.Advisor.CraftStatusText(r) .. "|r"
      if r.reqLevel then sub = sub .. Theme.Hex("warn") .. (" - level %d|r"):format(r.reqLevel) end
      if r.train then sub = sub .. Theme.Hex("warn") .. (" - train %s|r"):format(r.train) end
      if r.lowSkill then sub = sub .. Theme.Hex("warn") .. (" - %s, level it|r"):format(r.lowSkill) end
      rows[#rows + 1] = {
        icon = ns.API.GetItemIcon("item:" .. r.itemID) or EMPTY_ICON,
        title = r.link or r.name, sub = sub, link = r.link, train = r.train,
        value = plus(r.delta), valueColor = "good",
      }
    end
    local message
    if pending and pending > 0 then
      message = ("Reading %d more items from the server..."):format(pending)
    elseif #rows == 0 then
      message = "No crafted upgrades for you up to " .. ns.Advisor.Lookahead() .. " levels ahead."
    end
    return rows, message
  end,
}

TABS.enchants = {
  label = "Enchants", icon = "Interface\\Icons\\Trade_Engraving",
  build = function()
    local list, reason = ns.Advisor.EnchantReport()
    if not list then return {}, why(reason) end
    local rows = {}
    for _, r in ipairs(list) do
      local title, sub, value, color
      if r.ok then
        title, sub, value, color = r.name .. ": " .. r.current, "Best available", "OK", "good"
      elseif not r.current then
        title, sub, value, color = r.name .. ": " .. Theme.Hex("bad") .. "none|r",
          "Best: " .. r.best.name, plus(r.best.score), "good"
      elseif not r.gain then
        title, sub, value, color = r.name .. ": " .. r.current .. " (not scored)",
          "Best stat enchant: " .. r.best.name, plus(r.best.score), "muted"
      else
        title, sub, value, color = r.name .. ": " .. r.current, "Better: " .. r.best.name, plus(r.gain), "good"
      end
      rows[#rows + 1] = { icon = ns.API.GetItemIcon(r.link) or EMPTY_ICON, title = title, sub = sub,
        link = r.link, value = value, valueColor = color }
    end
    return rows
  end,
}

TABS.talents = {
  label = "Talents", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate",
  build = function()
    local list, reason = ns.Advisor.TalentReport()
    if not list then return {}, why(reason) end
    if #list == 0 then return {}, "Matches the recommended build." end
    local rows = {}
    for _, r in ipairs(list) do
      rows[#rows + 1] = { icon = EMPTY_ICON, title = r.name, sub = "Recommended rank " .. r.want,
        value = r.have .. " / " .. r.want, valueColor = r.have < r.want and "warn" or "bad" }
    end
    return rows
  end,
}

local SKILL_ICONS = {
  [15] = "Interface\\Icons\\INV_Weapon_ShortBlade_01", [7] = "Interface\\Icons\\INV_Sword_04",
  [4] = "Interface\\Icons\\INV_Mace_01", [0] = "Interface\\Icons\\INV_Axe_01",
  [13] = "Interface\\Icons\\INV_Gauntlets_04", [2] = "Interface\\Icons\\INV_Weapon_Bow_01",
  [3] = "Interface\\Icons\\INV_Weapon_Rifle_01", [18] = "Interface\\Icons\\INV_Weapon_Crossbow_01",
  [16] = "Interface\\Icons\\INV_ThrowingKnife_02",
}
local SPELL_ICON = "Interface\\Icons\\INV_Misc_Book_11"

local function money(copper)
  if GetCoinTextureString then return GetCoinTextureString(copper) end
  return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function spellIcon(name)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, name)
    if ok and tex then return tex end
  end
  return SPELL_ICON
end

local function spellRow(s, value, color)
  local cost = s.cost and (" - " .. money(s.cost)) or ""
  return { icon = spellIcon(s.name), title = ns.ClassTrainer.Label(s), sub = "Level " .. s.level .. cost,
    value = value, valueColor = color }
end

TABS.training = {
  label = "Training", icon = "Interface\\Icons\\INV_Misc_Book_11",
  build = function()
    local rows = {}
    local level = ns.API.clean(UnitLevel("player")) or 1
    local trainers = {}
    for i, t in ipairs(ns.ClassTrainer.Trainers()) do
      if i > 2 then break end
      trainers[#trainers + 1] = t.name .. (t.city and (", " .. t.city) or "")
    end
    local where = #trainers > 0 and table.concat(trainers, " or ") or "your class trainer"

    -- Class spells: what to train now, then the next levels.
    local now, visited = ns.ClassTrainer.ToTrain(level)
    local cost = ns.ClassTrainer.Cost(now)
    rows[#rows + 1] = { header = true, title = "Train now" .. (cost and #now > 0 and (" - " .. money(cost)) or "") }
    if not visited then
      rows[#rows + 1] = { icon = SPELL_ICON, title = "Visit your class trainer once",
        sub = "Then Gearwright knows which spells you've learned. " .. where, valueColor = "muted" }
    elseif #now == 0 then
      rows[#rows + 1] = { icon = SPELL_ICON, title = "Nothing to train", sub = "Everything up to level " .. level .. " is learned" }
    else
      for _, sp in ipairs(now) do
        local r = spellRow(sp, "train", "good")
        r.hint = "Train at " .. where
        rows[#rows + 1] = r
      end
    end
    local shown = 0
    for l = level + 1, level + 10 do
      local new = ns.ClassTrainer.NewAt(l)
      if #new > 0 then
        if shown == 0 then rows[#rows + 1] = { header = true, title = "Coming up" } end
        for _, sp in ipairs(new) do rows[#rows + 1] = spellRow(sp, "level " .. l, "muted") end
        shown = shown + 1
        if shown == 2 then break end
      end
    end

    -- Weapon skills: trained or not, how far levelled, who teaches the rest.
    local skills = ns.Advisor.WeaponSkillReport()
    if skills then
      rows[#rows + 1] = { header = true, title = "Weapon skills" }
      for _, w in ipairs(skills) do
        local r = { icon = SKILL_ICONS[w.sub] or SPELL_ICON, title = w.name }
        if w.known == false then
          r.sub = "Not trained" .. (w.where and (" - " .. w.where) or "")
          r.value, r.valueColor = "train", "warn"
          r.hint = "Click: show the weapon master on the map"
          local name = w.name
          r.onClick = function() ns.Trainers.Show(name) end
        elseif w.current then
          local low = w.current + ns.WeaponSkills.WARN_BELOW < w.max
          r.sub = low and "Fight with this weapon type to level it" or "Trained"
          if w.old then r.sub = r.sub .. " (level seen at an earlier character level)" end
          r.value, r.valueColor = w.current .. "/" .. w.max, low and "warn" or "good"
        else
          r.sub = "Trained - hover Main Hand on your character sheet with one equipped to read its level"
          r.value, r.valueColor = "?", "muted"
        end
        rows[#rows + 1] = r
      end
    end
    return rows
  end,
}

-- Settings: every row is a control. Left-click toggles or picks; on the
-- look-ahead row, left-click adds a level and right-click takes one away.
local function onOff(v) return v and "On" or "Off", v and "good" or "muted" end

local function toggleRow(title, sub, key)
  local value, color = onOff(ns.db[key])
  return { icon = "Interface\\Icons\\INV_Misc_Note_01", title = title, sub = sub, value = value,
    valueColor = color, hint = "Click to turn " .. (ns.db[key] and "off" or "on"),
    onClick = function() ns.db[key] = not ns.db[key] end }
end

TABS.settings = {
  label = "Settings", icon = "Interface\\Icons\\Trade_Engineering",
  build = function()
    if not ns.db then return {}, "Settings aren't loaded yet." end
    local rows = {}
    rows[#rows + 1] = { header = true, title = "Display" }
    rows[#rows + 1] = toggleRow("Tooltip line", "Gearwright's score on item tooltips", "showTooltip")
    rows[#rows + 1] = toggleRow("Chat messages", "Quest rewards, loot, rolls, training reminders", "notices")
    if ns.MinimapButton then
      rows[#rows + 1] = toggleRow("Minimap button", "Your next goal; click it to open this window", "minimap")
    end

    rows[#rows + 1] = { header = true, title = "Spec" }
    local classData = ns.Spec.ClassData()
    local choices = { { key = false, label = "Automatic", sub = "From your talents (Combat before level 10)" } }
    for _, key in ipairs({ "assassination", "combat", "subtlety" }) do
      local spec = classData and classData.specs[key]
      if spec then choices[#choices + 1] = { key = key, label = spec.label, sub = spec.summary } end
    end
    for _, c in ipairs(choices) do
      local on = (ns.db.specOverride or false) == c.key
      rows[#rows + 1] = { icon = "Interface\\Icons\\Ability_Stealth", title = c.label, sub = c.sub,
        value = on and "selected" or "", valueColor = "good", hint = on and nil or "Click to score gear for this",
        onClick = function() ns.db.specOverride = c.key end }
    end

    rows[#rows + 1] = { header = true, title = "Upgrade lists" }
    local n = ns.Advisor.Lookahead()
    rows[#rows + 1] = { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", title = "Look ahead",
      sub = "Dungeons and Crafting also list items up to this many levels above you",
      value = n .. (n == 1 and " level" or " levels"), valueColor = "title",
      hint = { "Left-click: one more level", "Right-click: one less" },
      onClick = function(button)
        local d = button == "RightButton" and -1 or 1
        ns.db.lookahead = math.max(0, math.min(15, n + d))
      end }

    rows[#rows + 1] = { header = true, title = "Map" }
    local pins = ns.db.pins and #ns.db.pins or 0
    rows[#rows + 1] = { icon = "Interface\\Icons\\INV_Misc_Map_01", title = "Clear map pins",
      sub = "Weapon masters Gearwright pinned on the world map", value = pins .. " pinned",
      valueColor = pins > 0 and "title" or "muted", hint = pins > 0 and "Click to remove them all" or nil,
      onClick = pins > 0 and function() ns.MapPins.Clear() end or nil }

    rows[#rows + 1] = { header = true, title = "Troubleshooting" }
    rows[#rows + 1] = toggleRow("Debug messages", "Extra chat output when something can't be read", "debug")
    return rows
  end,
}

UI.TAB_ORDER = { "gear", "upgrades", "crafting", "enchants", "talents", "training", "settings" }
UI.TABS = TABS

function UI.BuildRows(tab)
  return TABS[tab].build()
end

-- "Spec: Combat (talents)", plus warnings. Returns text or nil, reason.
local HOW = {
  leveling = "leveling: no talent points spent; the first comes at level 10",
}

function UI.HeaderText()
  local ctx, reason = ns.Advisor.Context()
  if not ctx then return nil, reason end
  local spec = ctx.class.specs[ctx.spec]
  local how = HOW[ctx.specHow] or ctx.specHow
  local text = Theme.Hex("title") .. "Spec:|r " .. spec.label .. " " .. Theme.Hex("muted") .. "(" .. how .. ")|r"
  if ctx.class.weights._status == "provisional" then
    text = text .. "   " .. Theme.Hex("warn") .. "Stat weights are provisional placeholders.|r"
  end
  return text .. "\n" .. Theme.Hex("muted") .. "Scores are in attack-power equivalents.|r"
end

-- Frame ----------------------------------------------------------------------------

local function makeRow(parent)
  local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
  row:SetHeight(ROW_HEIGHT - 4)
  Theme.Paint(row, "row", "borderSoft", 10)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(32, 32)
  row.icon:SetPoint("LEFT", 8, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  row.value:SetPoint("RIGHT", -12, 0)
  row.value:SetJustifyH("RIGHT")

  row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
  row.title:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
  row.title:SetJustifyH("LEFT")

  row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
  row.sub:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
  row.sub:SetJustifyH("LEFT")
  Theme.Color(row.sub, "muted")

  if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  row:SetScript("OnEnter", function(self)
    if self.isHeader then return end
    self:SetBackdropColor(unpack(Theme.rowHover))
    if not GameTooltip or not (self.link or self.hint or self.train) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.link then GameTooltip:SetHyperlink(self.link) end
    if self.train then GameTooltip:AddLine("Click: show where to train " .. self.train, 1, 0.6, 0) end
    local hint = self.hint
    if type(hint) == "string" then hint = { hint } end
    for i, line in ipairs(hint or {}) do
      if i == 1 and not self.link then GameTooltip:SetText(line, 1, 0.82, 0.4) else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function(self)
    if self.isHeader then return end
    self:SetBackdropColor(unpack(Theme.row))
    if GameTooltip then GameTooltip:Hide() end
  end)
  row:SetScript("OnClick", function(self, button)
    if self.isHeader then return end
    if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
      ChatEdit_InsertLink(self.link)
    elseif self.onClick then
      self.onClick(button)
      UI.Refresh()
    elseif self.train then
      ns.Trainers.Show(self.train) -- where to train the weapon skill this item needs
    end
  end)
  return row
end

local function makeTab(f, key, index)
  local def = TABS[key]
  local b = CreateFrame("Button", nil, f, "BackdropTemplate")
  b:SetSize(NAV_WIDTH - 16, 36)
  b:SetPoint("TOPLEFT", f.nav, "TOPLEFT", 8, -8 - (index - 1) * 40)
  Theme.Paint(b, "nav", "borderSoft", 10)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(24, 24)
  b.icon:SetPoint("LEFT", 6, 0)
  b.icon:SetTexture(def.icon)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
  b.label:SetText(def.label)
  b:SetScript("OnClick", function() UI.Select(key) end)
  return b
end

function UI.Create()
  if UI.frame then return UI.frame end
  local f = CreateFrame("Frame", "GearwrightFrame", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, HEIGHT)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  Theme.Paint(f, "frame", "border", 16)
  f:Hide()
  tinsert(UISpecialFrames, "GearwrightFrame") -- close on Escape

  -- Header: icon, title, spec line.
  f.header = CreateFrame("Frame", nil, f, "BackdropTemplate")
  f.header:SetPoint("TOPLEFT", 6, -6)
  f.header:SetPoint("TOPRIGHT", -6, -6)
  f.header:SetHeight(54)
  Theme.Paint(f.header, "header", "borderSoft", 12)

  f.logo = f.header:CreateTexture(nil, "ARTWORK")
  f.logo:SetSize(36, 36)
  f.logo:SetPoint("LEFT", 10, 0)
  f.logo:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  f.logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.title = f.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 10, 0)
  f.title:SetText("Gearwright " .. Theme.Hex("muted") .. ns.version .. "|r")
  Theme.Color(f.title, "title")

  f.spec = f.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.spec:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.spec:SetJustifyH("LEFT")

  f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.close:SetPoint("TOPRIGHT", -4, -4)

  -- Left: tabs.
  f.nav = CreateFrame("Frame", nil, f, "BackdropTemplate")
  f.nav:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -4)
  f.nav:SetPoint("BOTTOMLEFT", 6, 6)
  f.nav:SetWidth(NAV_WIDTH)
  Theme.Paint(f.nav, "panel", "borderSoft", 12)
  f.tabs = {}
  for i, key in ipairs(UI.TAB_ORDER) do f.tabs[key] = makeTab(f, key, i) end

  -- Right: list of rows.
  f.body = CreateFrame("Frame", nil, f, "BackdropTemplate")
  f.body:SetPoint("TOPLEFT", f.nav, "TOPRIGHT", 4, 0)
  f.body:SetPoint("BOTTOMRIGHT", -6, 6)
  Theme.Paint(f.body, "panel", "borderSoft", 12)

  f.message = f.body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.message:SetPoint("TOPLEFT", 14, -14)
  f.message:SetPoint("RIGHT", -14, 0)
  f.message:SetJustifyH("LEFT")
  Theme.Color(f.message, "muted")

  f.scroll = CreateFrame("ScrollFrame", nil, f.body, "UIPanelScrollFrameTemplate")
  f.scroll:SetPoint("TOPLEFT", 8, -8)
  f.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  f.list = CreateFrame("Frame", nil, f.scroll)
  f.list:SetSize(WIDTH - NAV_WIDTH - 56, 1)
  f.scroll:SetScrollChild(f.list)
  f.rows = {}

  f:SetScript("OnShow", UI.Refresh)
  UI.frame = f
  return f
end

local HEADER_HEIGHT = 26

local function drawRows(f, rows, message)
  local y = 0
  for i, r in ipairs(rows) do
    local row = f.rows[i] or makeRow(f.list)
    f.rows[i] = row
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", f.list, "RIGHT", 0, 0)
    row.isHeader = r.header
    if r.header then
      row:SetHeight(HEADER_HEIGHT - 4)
      row:SetBackdropColor(unpack(Theme.nav))
      row.icon:Hide()
      row.title:ClearAllPoints()
      row.title:SetPoint("LEFT", 10, 0)
      row.title:SetPoint("RIGHT", -10, 0)
      row.title:SetFontObject("GameFontNormalLarge")
      Theme.Color(row.title, "title")
      y = y + HEADER_HEIGHT
    else
      row:SetHeight(ROW_HEIGHT - 4)
      row:SetBackdropColor(unpack(Theme.row))
      row.icon:Show()
      row.icon:SetTexture(r.icon or EMPTY_ICON)
      row.title:ClearAllPoints()
      row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
      row.title:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
      row.title:SetFontObject("GameFontNormal")
      Theme.Color(row.title, "title")
      y = y + ROW_HEIGHT
    end
    row.title:SetText(r.title or "")
    row.sub:SetText(r.header and "" or (r.sub or ""))
    row.value:SetText(r.header and "" or (r.value or ""))
    Theme.Color(row.value, r.valueColor or "text")
    row.link = r.link
    row.train = r.train
    row.hint = r.hint
    row.onClick = r.onClick
    row:Show()
  end
  for i = #rows + 1, #f.rows do f.rows[i]:Hide() end
  f.list:SetHeight(math.max(y, 1))
  f.message:SetText(message or "")
  f.message:SetShown(message ~= nil)
  f.scroll:ClearAllPoints()
  f.scroll:SetPoint("TOPLEFT", 8, message and -40 or -8)
  f.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
end

function UI.Select(tab)
  UI.tab = tab
  if UI.frame and UI.frame:IsShown() then UI.Refresh() end
end

function UI.Refresh()
  local f = UI.frame
  if not f then return end
  UI.tab = UI.tab or "gear"
  for key, b in pairs(f.tabs) do
    b:SetBackdropColor(unpack(key == UI.tab and Theme.navSelected or Theme.nav))
    Theme.Color(b.label, key == UI.tab and "title" or "text")
  end

  local header, reason = UI.HeaderText()
  f.spec:SetText(header or why(reason))
  if not header then
    drawRows(f, {}, why(reason))
    return
  end
  local rows, message = UI.BuildRows(UI.tab)
  UI.shown = { rows = rows, message = message } -- what's on screen; read by tests
  drawRows(f, rows, message)
end

function UI.Toggle()
  local f = UI.Create()
  f:SetShown(not f:IsShown())
end

local function refreshIfShown()
  if UI.frame and UI.frame:IsShown() then UI.Refresh() end
end
ns:On("PLAYER_EQUIPMENT_CHANGED", refreshIfShown)
-- API.lua subscribed to these first, so its talent cache is already cleared.
for _, event in ipairs(ns.API.TALENT_EVENTS) do ns:On(event, refreshIfShown) end

-- Dungeon items arrive from the server a few at a time; redraw once they settle.
local refreshQueued
ns:On("GET_ITEM_INFO_RECEIVED", function()
  if refreshQueued or (UI.tab ~= "upgrades" and UI.tab ~= "crafting") or not (UI.frame and UI.frame:IsShown()) then return end
  refreshQueued = true
  C_Timer.After(0.5, function() refreshQueued = false; refreshIfShown() end)
end)
