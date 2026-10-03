std = "lua51"
self = false
max_line_length = 140
exclude_files = { "tests/", "tools/" }
globals = {
  "GearwrightDB", "GearwrightProbeDB", "SlashCmdList",
  "SLASH_GEARWRIGHT1", "SLASH_GEARWRIGHT2", "SLASH_GEARWRIGHTPROBE1",
}
read_globals = {
  "C_AddOns", "C_Item", "C_TooltipInfo", "C_ClassTalents", "C_Traits", "C_Spell",
  "C_TradeSkillUI", "C_Timer", "GetSpellInfo", "TooltipDataProcessor", "Enum",
  "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "ItemRefTooltip", "ChatFontNormal",
  "GetAddOnMetadata", "GetItemStats", "GetItemInfoInstant", "GetInventoryItemLink",
  "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo",
  "GetNumTradeSkills", "GetTradeSkillLine", "GetNumTrainerServices", "NotifyInspect", "GetLocale", "WOW_PROJECT_ID",
  "UnitClass", "UnitFullName", "UnitLevel", "UnitName", "UnitExists",
  "UnitDamage", "UnitAttackSpeed", "GetItemInfo", "GetCoinTextureString",
  "GetNumQuestChoices", "GetQuestItemLink", "GetNumLootItems", "GetLootSlotLink", "GetLootRollItemLink",
  "EJ_GetInstanceByIndex", "EJ_SelectInstance", "EJ_SelectTier", "LoadAddOn",
  "issecretvalue", "InCombatLockdown", "geterrorhandler", "tinsert", "date",
}
