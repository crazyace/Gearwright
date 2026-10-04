-- Gearwright: an entry in the game's AddOns settings. Gearwright's settings
-- live in its own window (Settings tab); this page points there.
local _, ns = ...

local function build()
  local panel = CreateFrame("Frame")
  panel.name = "Gearwright"
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Gearwright")
  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  text:SetPoint("RIGHT", -16, 0)
  text:SetJustifyH("LEFT")
  text:SetText("Gear, training, enchant and crafting advice. Its settings are in its own window "
    .. "(/gearwright, Settings tab).")
  local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  button:SetSize(200, 24)
  button:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
  button:SetText("Open Gearwright settings")
  button:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then pcall(HideUIPanel, SettingsPanel) end
    local f = ns.UI.Create()
    ns.UI.Select("settings")
    f:Show()
  end)
  return panel
end

ns:On("PLAYER_LOGIN", function()
  local ok, panel = pcall(build)
  if not ok then return end
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    pcall(function()
      local category = Settings.RegisterCanvasLayoutCategory(panel, "Gearwright")
      Settings.RegisterAddOnCategory(category)
    end)
  elseif InterfaceOptions_AddCategory then
    pcall(InterfaceOptions_AddCategory, panel)
  end
end)
