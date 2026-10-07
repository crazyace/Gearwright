-- Gearwright: bootstrap, event bus, saved settings.
local ADDON, ns = ...

ns.name = ADDON
ns.Data = ns.Data or {}

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMeta and getMeta(ADDON, "Version")) or "dev"

-- Event bus -----------------------------------------------------------------
-- Modules subscribe with ns:On("EVENT", fn). One frame, many listeners.
-- Unknown event names are skipped: newer clients error on them, and we don't
-- yet know every event the Forever client fires.
local frame = CreateFrame("Frame")
local handlers = {}

function ns:On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    if not pcall(frame.RegisterEvent, frame, event) then return end
  end
  table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok then geterrorhandler()(err) end
  end
end)

-- Saved settings -------------------------------------------------------------
-- Bump `schema` when the shape changes and add a migration in Util.
local DEFAULTS = {
  schema = 1,
  showTooltip = true,
  notices = true, -- chat lines for quest rewards, loot and rolls
  questHighlight = true, -- mark upgrades in quest rewards and vendor windows
  specOverride = false, -- false = auto-detect from talents
  minimap = true, -- minimap button (UI/MinimapButton.lua)
  debug = false,
}

ns:On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  GearwrightDB = ns.util.applyDefaults(GearwrightDB or {}, DEFAULTS)
  ns.db = GearwrightDB
end)
