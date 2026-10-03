-- Gearwright: window colours and frame helpers. Dark iron with bronze trim.
-- Colours are {r, g, b, a}; change them here, nowhere else.
local _, ns = ...

local Theme = {
  frame       = { 0.055, 0.050, 0.045, 0.97 },
  header      = { 0.125, 0.095, 0.060, 0.96 },
  panel       = { 0.085, 0.075, 0.065, 0.94 },
  nav         = { 0.110, 0.090, 0.070, 0.94 },
  navSelected = { 0.300, 0.205, 0.085, 0.97 },
  row         = { 0.115, 0.098, 0.080, 0.93 },
  rowHover    = { 0.250, 0.180, 0.095, 0.97 },
  border      = { 0.560, 0.410, 0.190, 1 },
  borderSoft  = { 0.330, 0.250, 0.140, 1 },
  title       = { 1.000, 0.820, 0.400 },
  text        = { 0.920, 0.870, 0.780 },
  muted       = { 0.650, 0.600, 0.520 },
  good        = { 0.400, 0.950, 0.400 },
  bad         = { 1.000, 0.380, 0.320 },
  warn        = { 1.000, 0.600, 0.000 },
}
ns.Theme = Theme

local FLAT = "Interface\\Buttons\\WHITE8X8"
local EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Flat fill with a thin tooltip-style border.
function Theme.Paint(frame, fill, border, edgeSize)
  if not frame.SetBackdrop then return end
  local e = edgeSize or 12
  frame:SetBackdrop({
    bgFile = FLAT, edgeFile = EDGE, tile = true, tileSize = 16, edgeSize = e,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(unpack(Theme[fill] or fill))
  frame:SetBackdropBorderColor(unpack(Theme[border or "borderSoft"] or border))
end

-- "|cffRRGGBB" for a theme colour.
function Theme.Hex(name)
  local c = Theme[name]
  return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

function Theme.Color(fontString, name)
  fontString:SetTextColor(unpack(Theme[name]))
end
