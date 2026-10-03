-- Gearwright: Rogue spec definitions.
local _, ns = ...
ns.Data.ROGUE = ns.Data.ROGUE or {}
local R = ns.Data.ROGUE

-- Talent-frame tab index -> spec key. VERIFY with GearwrightProbe (/gwp talents).
R.tabToSpec = { [1] = "assassination", [2] = "combat", [3] = "subtlety" }

R.specs = {
  assassination = {
    label = "Assassination",
    summary = "Poison-focused; built around Mutilate and Venom.",
    weapons = { mainHand = "dagger", offHand = "dagger" }, -- Mutilate wants daggers
  },
  combat = {
    label = "Combat",
    summary = "Dual-wield melee; Restless Blades cooldown loop.",
    weapons = { mainHand = "any", offHand = "any" }, -- Hack and Slash covers all types
  },
  subtlety = {
    label = "Subtlety",
    summary = "Stealth openers; Hemorrhage feeds your Rupture.",
    weapons = { mainHand = "dagger", offHand = "any" },
  },
}
