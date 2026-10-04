std = "lua51"
self = false
max_line_length = 140
exclude_files = { "tests/", "tools/" }
globals = {
  "GearwrightDB", "GearwrightProbeDB", "BattlewrightDB", "SlashCmdList",
  "SLASH_BATTLEWRIGHT1", "SLASH_BATTLEWRIGHT2",
  "SLASH_GEARWRIGHT1", "SLASH_GEARWRIGHT2", "SLASH_GEARWRIGHTPROBE1",
}
read_globals = {
  "C_AddOns", "C_Item", "C_TooltipInfo", "C_ClassTalents", "C_Traits", "C_Spell",
  "C_TradeSkillUI", "C_Timer", "GetSpellInfo", "TooltipDataProcessor", "Enum",
  "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "ItemRefTooltip", "ChatFontNormal",
  "GetAddOnMetadata", "GetItemStats", "GetItemInfoInstant", "GetInventoryItemLink",
  "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo",
  "GetNumTradeSkills", "GetTradeSkillLine", "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceTypeFilter", "SetTrainerServiceTypeFilter", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "NotifyInspect", "GetLocale", "WOW_PROJECT_ID",
  "UnitClass", "UnitFullName", "UnitLevel", "UnitName", "UnitExists",
  "UnitDamage", "UnitAttackSpeed", "GetItemInfo", "GetCoinTextureString",
  "GetNumQuestChoices", "GetQuestItemLink", "GetNumLootItems", "GetLootSlotLink", "GetLootRollItemLink", "GetLootSourceInfo", "UnitGUID", "GetRealZoneText", "UnitFactionGroup", "IsModifiedClick", "ChatEdit_InsertLink", "IsPlayerSpell", "IsSpellKnown", "C_SpellBook", "GetNumSkillLines", "GetSkillLineInfo", "GetProfessions", "GetProfessionInfo", "GetRealmName",
  "EJ_GetInstanceByIndex", "EJ_SelectInstance", "EJ_SelectTier", "LoadAddOn",
  "issecretvalue", "InCombatLockdown", "geterrorhandler", "tinsert", "date", "time", "GetTime", "UnitPower", "UnitPowerMax", "GetComboPoints", "UnitHealth", "UnitHealthMax", "UnitCanAttack", "IsStealthed", "C_UnitAuras", "UnitAffectingCombat", "GetPowerRegen", "RETRIEVING_ITEM_INFO", "C_AuctionHouse", "C_Map", "OpenWorldMap", "ToggleWorldMap", "hooksecurefunc", "Settings", "SettingsPanel", "Minimap", "GetCursorPosition", "HideUIPanel", "InterfaceOptions_AddCategory",
}
