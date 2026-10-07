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
  ["no-enchant-data"] = "No enchant data loaded.",
  ["nothing-to-enchant"] = "Nothing equipped that takes an enchant.",
  ["no-consumable-data"] = "No consumable data loaded.",
  ["no-talent-points"] = "Spend some talent points so Gearwright can detect your spec.",
  ["no-talent-config"] = "Talents aren't loaded yet; try again in a moment.",
  ["no-trait-tab-map"] = "No talent tree layout for this class yet.",
  ["traits-error"] = "Couldn't read talents (turn on /gearwright debug for details).",
  ["no-talent-api"] = "This client exposes no talent API Gearwright knows.",
}
local function why(reason) return REASONS[reason] or ("Unavailable (" .. tostring(reason) .. ")") end
UI.why = why

local function num(v) return ns.Advisor.FormatScore(v) end
local function plus(v) return ns.Advisor.FormatScore(v, true) end
local function slotName(slot) return ns.Advisor.SLOT_NAMES[slot] or "?" end

-- Wishlist: right-click any upgrade row to add it (or take it off again);
-- wished items get a check mark.
local WISHED = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t "
local function wishable(row, entry)
  local has = ns.Wishlist.Has(entry.itemID)
  if has then row.title = WISHED .. (row.title or "") end
  local hint = row.hint
  if type(hint) == "string" then hint = { hint } end
  hint = hint or {}
  hint[#hint + 1] = has and "Right-click: remove from your wishlist" or "Right-click: add to your wishlist"
  row.hint = hint
  row.onClick = function(button)
    if button == "RightButton" then ns.Wishlist.Toggle(entry) end
  end
  return row
end

-- Tabs ---------------------------------------------------------------------------
-- A tab's build() returns rows, message. A row:
--   { icon, title, sub, value, valueColor, link,
--     note = "level 20"                  -- small text under the value
--     hint = "line" or { "line", ... }   -- hover text (after the item tooltip)
--     onClick = function(button) end     -- left or right click (shift-click links)
--     header = true }                    -- a section heading: just `title`

local TABS = {}

TABS.gear = {
  label = "Gear", icon = "Interface\\Icons\\INV_Chest_Leather_09",
  build = function()
    local gear, pending = ns.Advisor.GearOverview()
    local rows = {}
    for _, g in ipairs(gear or {}) do
      local b = g.best
      local current = g.link or (Theme.Hex("muted") .. "empty|r")
      local r = { icon = g.link and ns.API.GetItemIcon(g.link) or EMPTY_ICON, title = current, link = g.link }
      if b then
        local sub = "Upgrade: " .. (b.link or b.name or "?") .. Theme.Hex("muted") .. "  " .. b.from .. "|r"
        r.sub, r.value, r.valueColor = sub, plus(b.delta), "good"
        r.note = b.reqLevel and ("level " .. b.reqLevel)
        r.link = b.link -- hover and shift-click show the upgrade
        r.hint = { g.name .. ": you wear " .. (g.link or "nothing") .. (g.score and (" (" .. num(g.score) .. ")") or "") }
        if b.itemID then wishable(r, { itemID = b.itemID, link = b.link, name = b.name, from = b.from }) end
      else
        r.sub = g.name .. Theme.Hex("muted") .. "  no known upgrade|r"
        r.value, r.valueColor = g.score and num(g.score), "text"
      end
      rows[#rows + 1] = r
    end
    local message = pending and pending > 0 and ("Reading %d more items from the server..."):format(pending) or nil
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
      rows[#rows + 1] = wishable({
        icon = ns.API.GetItemIcon("item:" .. r.itemID) or EMPTY_ICON,
        title = r.link or r.name, sub = sub, link = r.link,
        value = plus(r.delta), valueColor = "good", note = r.reqLevel and ("level " .. r.reqLevel),
      }, { itemID = r.itemID, link = r.link, name = r.name, from = ns.Advisor.CraftStatusText(r) })
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

-- "+4 Weapon Damage, +2% Crit"
local PERCENT = { crit = true, hit = true, haste = true, spellCrit = true, spellHit = true }
local function effectText(stats)
  local keys = {}
  for k in pairs(stats or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = ("+%s%s %s"):format(stats[k], PERCENT[k] and "%" or "", ns.Stats.LABELS[k] or k)
  end
  return table.concat(parts, ", ")
end

local function itemLink(id)
  local link = ns.API.GetItemLink(id)
  if not link then ns.API.RequestItem(id) end
  return link or ("item:" .. id)
end

local function consumableRow(title, c, nxt, sub)
  local item = (c or nxt).item
  local row = { icon = ns.API.GetItemIcon(item.id) or EMPTY_ICON, link = itemLink(item.id) }
  if c then
    row.title, row.value, row.valueColor = title .. item.name, plus(c.score), "good"
  else
    row.title, row.value, row.valueColor = title .. Theme.Hex("muted") .. item.name .. "|r", "level " .. item.level, "muted"
  end
  if c and nxt then sub = sub .. Theme.Hex("muted") .. ("  -  level %d: %s|r"):format(nxt.item.level, nxt.item.name) end
  row.sub = sub
  return row
end

local function weaponBuffSub(c, r)
  local item = c.item
  local sub
  if c.poison then
    sub = ("~%.1f damage per second  -  you make it (Poisons)"):format(c.dps)
  else
    sub = effectText(item.stats) .. "  -  " .. item.source
  end
  if r.active then
    sub = Theme.Hex("good") .. ("applied, %d min left|r  -  "):format(r.active) .. sub
  elseif r.active == false then
    sub = Theme.Hex("warn") .. "nothing applied|r  -  " .. sub
  end
  return sub
end

TABS.consumables = {
  label = "Consumables", icon = "Interface\\Icons\\INV_Potion_93",
  build = function()
    local report, reason = ns.Advisor.ConsumableReport()
    if not report then return {}, why(reason) end
    local rows = {}
    if #report.weapon > 0 then
      rows[#rows + 1] = { header = true, title = "Weapon buffs" }
      for _, r in ipairs(report.weapon) do
        local c = r.best or r.next
        rows[#rows + 1] = consumableRow(slotName(r.slot) .. ": ", r.best, r.next, weaponBuffSub(c, r))
      end
    end
    if #report.elixirs > 0 then
      rows[#rows + 1] = { header = true, title = "Elixirs" }
      for _, r in ipairs(report.elixirs) do
        local item = (r.best or r.next).item
        rows[#rows + 1] = consumableRow("", r.best, r.next, effectText(item.stats) .. "  -  " .. (item.source or "Alchemy"))
      end
    end
    if #report.potions > 0 then
      rows[#rows + 1] = { header = true, title = "Potions" }
      for _, r in ipairs(report.potions) do
        local item = (r.best or r.next).item
        local row = consumableRow("", r.best, r.next,
          ("Restores ~%d %s  -  %s"):format(item.amount, item.restores, item.source or "Alchemy"))
        if r.best then row.value, row.valueColor = "use", "good" end
        rows[#rows + 1] = row
      end
    end
    local message = "Effects are Classic's until checked on Forever."
    if #rows == 0 then message = "Nothing worth using at your level yet." end
    return rows, message
  end,
}

TABS.wishlist = {
  label = "Wishlist", icon = "Interface\\Icons\\INV_Misc_Note_02",
  build = function()
    local rows = {}
    local goal = ns.Wishlist.NextGoal()
    rows[#rows + 1] = { header = true, title = "Next goal" }
    if goal then
      rows[#rows + 1] = { icon = goal.link and ns.API.GetItemIcon(goal.link) or EMPTY_ICON,
        title = goal.link or goal.name, link = goal.link,
        sub = ns.Wishlist.When(goal.levelsAway) .. Theme.Hex("muted") .. "  " .. (goal.from or "") .. "|r"
          .. (goal.wished and "" or (Theme.Hex("muted") .. "  (best known upgrade)|r")),
        value = plus(goal.delta), valueColor = "good" }
    else
      rows[#rows + 1] = { icon = EMPTY_ICON, title = "No upgrade known yet", sub = "Gearwright looks in crafted items" }
    end
    local report = ns.Wishlist.Report()
    rows[#rows + 1] = { header = true, title = "Wishlist" }
    if #report == 0 then
      rows[#rows + 1] = { icon = EMPTY_ICON, title = "Empty",
        sub = "Right-click an upgrade in Gear or Crafting to add it here" }
    end
    for _, w in ipairs(report) do
      local e = w.entry
      local status, value, color
      if w.equipped then
        status, value, color = "wearing it", "done", "good"
      elseif not w.delta then
        status, value, color = "can't score it right now", "?", "muted"
      elseif w.delta <= 0.05 then
        status, value, color = "no longer an upgrade", plus(w.delta), "muted"
      else
        status, value, color = ns.Wishlist.When(w.levelsAway), plus(w.delta), "good"
      end
      local sub = status .. (w.slot and ("  -  " .. slotName(w.slot)) or "") .. Theme.Hex("muted") .. "  " .. (e.from or "") .. "|r"
      local id = e.itemID
      rows[#rows + 1] = { icon = ns.API.GetItemIcon("item:" .. id) or EMPTY_ICON, title = w.link or e.name,
        link = w.link, sub = sub, value = value, valueColor = color, hint = "Right-click: remove from your wishlist",
        onClick = function(button) if button == "RightButton" then ns.Wishlist.Remove(id) end end }
    end
    return rows
  end,
}

-- Settings: every row is a control. Left-click toggles or picks; on the
-- look-ahead row, left-click adds a level and right-click takes one away.
local function onOff(v) return v and "On" or "Off", v and "good" or "muted" end

local function toggleRow(title, sub, key, after)
  local value, color = onOff(ns.db[key])
  return { icon = "Interface\\Icons\\INV_Misc_Note_01", title = title, sub = sub, value = value,
    valueColor = color, hint = "Click to turn " .. (ns.db[key] and "off" or "on"),
    onClick = function() ns.db[key] = not ns.db[key]; if after then after() end end }
end

TABS.settings = {
  label = "Settings", icon = "Interface\\Icons\\Trade_Engineering",
  quick = true, -- cheap to build, and a click should show its result at once
  build = function()
    if not ns.db then return {}, "Settings aren't loaded yet." end
    local rows = {}
    rows[#rows + 1] = { header = true, title = "Display" }
    rows[#rows + 1] = toggleRow("Tooltip line", "Gearwright's score on item tooltips", "showTooltip")
    rows[#rows + 1] = toggleRow("Chat messages", "Quest rewards, loot and rolls", "notices")
    rows[#rows + 1] = toggleRow("Upgrade marks", "Highlight upgrades in quest rewards and vendors' windows", "questHighlight",
      function() ns.QuestHighlight.Hide("quest"); ns.VendorHighlight.Refresh() end)
    if ns.MinimapButton then
      rows[#rows + 1] = toggleRow("Minimap button", "Your next goal; click it to open this window", "minimap",
        ns.MinimapButton.Update)
    end

    -- Weights follow your talents on their own; the one setting left is
    -- scoring for another spec than the one your talents say.
    rows[#rows + 1] = { header = true, title = "Stat weights" }
    local classData = ns.Spec.ClassData()
    local order = { false }
    for _, key in ipairs(classData and classData.tabToSpec or {}) do order[#order + 1] = key end
    local current = ns.db.specOverride or false
    local spec = current and classData and classData.specs[current]
    local leveling = classData and classData.specs[classData.levelingSpec or ""]
    local auto = "From your talents" .. (leveling and (" (" .. leveling.label .. " before level 10)") or "")
    rows[#rows + 1] = { icon = (spec and spec.icon) or "Interface\\Icons\\Ability_Stealth", title = "Score gear for",
      sub = spec and "Ignoring your talents' spec; click through to Automatic to go back" or auto,
      value = spec and spec.label or "Automatic", valueColor = spec and "warn" or "good",
      hint = { "Left-click: next spec", "Right-click: back to Automatic" },
      onClick = function(button)
        if button == "RightButton" then ns.db.specOverride = false; return end
        local i = 1
        for n, key in ipairs(order) do if key == current then i = n end end
        ns.db.specOverride = order[i % #order + 1]
      end }

    rows[#rows + 1] = { header = true, title = "Upgrade lists" }
    local n = ns.Advisor.Lookahead()
    rows[#rows + 1] = { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", title = "Look ahead",
      sub = "Crafting also lists items up to this many levels above you",
      value = n .. (n == 1 and " level" or " levels"), valueColor = "title",
      hint = { "Left-click: one more level", "Right-click: one less" },
      onClick = function(button)
        local d = button == "RightButton" and -1 or 1
        ns.db.lookahead = math.max(0, math.min(15, n + d))
      end }

    rows[#rows + 1] = { header = true, title = "Troubleshooting" }
    rows[#rows + 1] = toggleRow("Debug messages", "Extra chat output when something can't be read", "debug")

    return rows
  end,
}

UI.TAB_ORDER = { "gear", "wishlist", "crafting", "enchants", "consumables", "settings" }
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
  local unit = ctx.class.weights.model == "caster" and "points of your main spell power"
    or "damage per second, like the game's own comparison"
  local line = "Scores are in " .. unit .. "."
  local counted = {}
  for _, t in ipairs(ctx.weights.talents or {}) do
    counted[#counted + 1] = ("%s %d/%d"):format(t.name, t.rank, t.max)
  end
  if #counted > 0 then line = line .. " Weights include " .. table.concat(counted, ", ") .. "." end
  return text .. "\n" .. Theme.Hex("muted") .. line .. "|r"
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

  row.note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.note:SetPoint("TOPRIGHT", row.value, "BOTTOMRIGHT", 0, -1)
  row.note:SetJustifyH("RIGHT")
  Theme.Color(row.note, "warn")

  row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
  row.title:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
  row.title:SetJustifyH("LEFT")

  row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
  row.sub:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
  row.sub:SetJustifyH("LEFT")
  Theme.Color(row.sub, "muted")
  -- One line each: long text is cut short ("...") instead of running into the
  -- next row; the full text is on the hover tooltip.
  if row.title.SetWordWrap then row.title:SetWordWrap(false) end
  if row.sub.SetWordWrap then row.sub:SetWordWrap(false) end

  if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  row:SetScript("OnEnter", function(self)
    if self.isHeader then return end
    self:SetBackdropColor(unpack(Theme.rowHover))
    if not GameTooltip or not (self.link or self.hint or self.fullSub) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.link then GameTooltip:SetHyperlink(self.link) end
    local hint = self.hint
    if type(hint) == "string" then hint = { hint } end
    if self.fullSub and self.link then GameTooltip:AddLine(self.fullSub, 0.8, 0.8, 0.8, true) end
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
      ns.MinimapButton.Refresh() -- the wishlist or spec may have changed the next goal
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
    row.note:SetText(r.header and "" or (r.note or ""))
    -- With a note, lift the score so the two sit together, centred.
    row.value:ClearAllPoints()
    row.value:SetPoint("RIGHT", -12, r.note and 6 or 0)
    Theme.Color(row.value, r.valueColor or "text")
    row.link = r.link
    row.hint = r.hint
    row.fullSub = r.sub
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
  local tab = UI.tab
  if TABS[tab].quick then return UI.Show(tab, UI.BuildRows(tab)) end
  -- The other tabs score items (Gear and Crafting every crafted recipe), which
  -- took long enough to hitch the game on every tab switch. They're built in
  -- the background a slice per frame; meanwhile the tab shows what it showed
  -- last time.
  local last = UI.cache[tab]
  if last then
    UI.Show(tab, last.rows, last.message)
  else
    drawRows(f, {}, "Working it out...")
  end
  UI.Rebuild(tab)
end

-- What each tab showed last: { rows, message }.
UI.cache = {}

function UI.Show(tab, rows, message)
  UI.cache[tab] = { rows = rows, message = message }
  if tab ~= UI.tab or not (UI.frame and UI.frame:IsShown()) then return end
  UI.shown = { rows = rows, message = message } -- what's on screen; read by tests
  -- Still waiting for items from the server: redraw when they arrive.
  UI.waiting = type(message) == "string" and message:find("^Reading") ~= nil
  drawRows(UI.frame, rows, message)
end

-- One build per tab at a time; a refresh asked for meanwhile runs after it.
local building, again = {}, {}
function UI.Rebuild(tab)
  if building[tab] then again[tab] = true; return end
  building[tab] = true
  ns.util.Background(function() return UI.BuildRows(tab) end, function(ok, rows, message)
    building[tab] = false
    if ok then
      UI.Show(tab, rows, message)
    else
      ns.util.debug("%s tab: %s", tab, tostring(rows))
    end
    if again[tab] then again[tab] = false; UI.Rebuild(tab) end
  end)
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

-- Crafted items arrive from the server a few at a time; redraw once they settle.
local refreshQueued
ns:On("GET_ITEM_INFO_RECEIVED", function()
  if refreshQueued or not UI.waiting or not (UI.frame and UI.frame:IsShown()) then return end
  refreshQueued = true
  C_Timer.After(1, function() refreshQueued = false; refreshIfShown() end)
end)
