-- Gearwright: slash commands. Loaded last so every module exists.
local _, ns = ...

local function help()
  ns.util.print("commands:")
  print("  /gearwright            toggle the window")
  local classData = ns.Spec.ClassData()
  local specs = {}
  for _, key in ipairs(classData and classData.tabToSpec or {}) do specs[#specs + 1] = key end
  specs[#specs + 1] = "auto"
  print("  /gearwright spec <" .. table.concat(specs, "|") .. ">")
  print("  /gearwright tooltip    toggle the tooltip line")
  print("  /gearwright notices    toggle quest reward / loot upgrade messages")
  print("  /gearwright craft      upgrades you can craft (open each profession once first)")
  print("  /gearwright spells     class spells to train now and coming up")
  print("  /gearwright train      weapon skills you can still train, pinned on the map")
  print("  /gearwright pins clear remove Gearwright's map pins")
  print("  /gearwright debug      toggle debug output")
end

SLASH_GEARWRIGHT1 = "/gearwright"
SLASH_GEARWRIGHT2 = "/gwr"
SlashCmdList.GEARWRIGHT = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")

  if cmd == "" then
    ns.UI.Toggle()
  elseif cmd == "spec" then
    local classData = ns.Spec.ClassData()
    if arg == "auto" or arg == "" then
      ns.db.specOverride = false
      ns.util.print("spec: auto-detect")
    elseif classData and classData.specs[arg] then
      ns.db.specOverride = arg
      ns.util.print("spec: %s", classData.specs[arg].label)
    else
      ns.util.print("unknown spec '%s'", arg)
    end
    if ns.UI.frame and ns.UI.frame:IsShown() then ns.UI.Refresh() end
  elseif cmd == "tooltip" then
    ns.db.showTooltip = not ns.db.showTooltip
    ns.util.print("tooltip line %s", ns.db.showTooltip and "on" or "off")
  elseif cmd == "notices" then
    ns.db.notices = not ns.db.notices
    ns.util.print("upgrade messages %s", ns.db.notices and "on" or "off")
  elseif cmd == "craft" then
    ns.Notices.Craft()
  elseif cmd == "spells" then
    ns.Notices.Spells()
  elseif cmd == "train" then
    ns.Notices.Train()
  elseif cmd == "pins" and arg == "clear" then
    ns.MapPins.Clear()
    ns.util.print("map pins cleared")
  elseif cmd == "debug" then
    ns.db.debug = not ns.db.debug
    ns.util.print("debug %s", ns.db.debug and "on" or "off")
  else
    help()
  end
end

ns:On("PLAYER_LOGIN", function()
  ns.util.debug("loaded %s", ns.version)
end)
