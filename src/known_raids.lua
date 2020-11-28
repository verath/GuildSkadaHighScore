local _, addonTable = ...
-- Set up module
local addon = addonTable[1];
local knownRaids = addon:NewModule("knownRaids");
addon.knownRaids = knownRaids;

-- https://wow.gamepedia.com/InstanceID
local KNOWN_RAIDS_TABLE = {
	-- Classic
	[469] = {expansionLevel = LE_EXPANSION_CLASSIC}, -- Blackwing Lair
	[409] = {expansionLevel = LE_EXPANSION_CLASSIC}, -- Molten Core
	[509] = {expansionLevel = LE_EXPANSION_CLASSIC}, -- Ruins of Ahn'Qiraj
	[531] = {expansionLevel = LE_EXPANSION_CLASSIC}, -- Temple of Ahn'Qiraj

	-- BC
	[564] = {expansionLevel = LE_EXPANSION_BURNING_CRUSADE}, -- Black Temple
	[565] = {expansionLevel = LE_EXPANSION_BURNING_CRUSADE}, -- Gruul's Lair
	[534] = {expansionLevel = LE_EXPANSION_BURNING_CRUSADE}, -- Hyjal Summit
	[532] = {expansionLevel = LE_EXPANSION_BURNING_CRUSADE}, -- Karazhan
	[544] = {expansionLevel = LE_EXPANSION_BURNING_CRUSADE}, -- Magtheridon's Lair
	[548] = {expansionLevel = LE_EXPANSION_BURNING_CRUSADE}, -- Serpentshrine Cavern
	[580] = {expansionLevel = LE_EXPANSION_BURNING_CRUSADE}, -- Sunwell Plateau
	[550] = {expansionLevel = LE_EXPANSION_BURNING_CRUSADE}, -- Tempest Keep

	-- Wrath
	[631] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- Icecrown Citadel
	[533] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- Naxxramas
	[249] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- Onyxia's Lair
	[616] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- The Eye of Eternity
	[615] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- The Obsidian Sanctum
	[724] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- The Ruby Sanctum
	[649] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- Trial of the Crusader
	[603] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- Ulduar
	[624] = {expansionLevel = LE_EXPANSION_WRATH_OF_THE_LICH_KING}, -- Vault of Archavon

	-- Cataclysm
	[757] = {expansionLevel = LE_EXPANSION_CATACLYSM}, -- Baradin Hold
	[669] = {expansionLevel = LE_EXPANSION_CATACLYSM}, -- Blackwing Descent
	[967] = {expansionLevel = LE_EXPANSION_CATACLYSM}, -- Dragon Soul
	[720] = {expansionLevel = LE_EXPANSION_CATACLYSM}, -- Firelands
	[671] = {expansionLevel = LE_EXPANSION_CATACLYSM}, -- The Bastion of Twilight
	[754] = {expansionLevel = LE_EXPANSION_CATACLYSM}, -- Throne of the Four Winds

	-- Pandaria
	[1009] = {expansionLevel = LE_EXPANSION_MISTS_OF_PANDARIA}, -- Heart of Fear
	[1008] = {expansionLevel = LE_EXPANSION_MISTS_OF_PANDARIA}, -- Mogu'shan Vaults
	[1136] = {expansionLevel = LE_EXPANSION_MISTS_OF_PANDARIA}, -- Siege of Orgrimmar
	[996] = {expansionLevel = LE_EXPANSION_MISTS_OF_PANDARIA}, -- Terrace of Endless Spring
	[1098] = {expansionLevel = LE_EXPANSION_MISTS_OF_PANDARIA}, -- Throne of Thunder

	-- WoD
	[1228] = {expansionLevel = LE_EXPANSION_WARLORDS_OF_DRAENOR}, -- Highmaul
	[1205] = {expansionLevel = LE_EXPANSION_WARLORDS_OF_DRAENOR}, -- Blackrock Foundry
	[1448] = {expansionLevel = LE_EXPANSION_WARLORDS_OF_DRAENOR}, -- Hellfire Citadel
	
	-- Legion
	[1520] = {expansionLevel = LE_EXPANSION_LEGION}, -- The Emerald Nightmare
	[1648] = {expansionLevel = LE_EXPANSION_LEGION}, -- Trial of Valor
	[1530] = {expansionLevel = LE_EXPANSION_LEGION}, -- The Nighthold
	[1676] = {expansionLevel = LE_EXPANSION_LEGION}, -- Tomb of Sargeras
	[1712] = {expansionLevel = LE_EXPANSION_LEGION}, -- Antorus, the Burning Throne
	
	-- BFA
	[1861] = {expansionLevel = LE_EXPANSION_BATTLE_FOR_AZEROTH}, -- Uldir
	[2070] = {expansionLevel = LE_EXPANSION_BATTLE_FOR_AZEROTH}, -- Battle of Dazar'alor
	[2096] = {expansionLevel = LE_EXPANSION_BATTLE_FOR_AZEROTH}, -- Crucible of Storms
	[2164] = {expansionLevel = LE_EXPANSION_BATTLE_FOR_AZEROTH}, -- The Eternal Palace
	[2217] = {expansionLevel = LE_EXPANSION_BATTLE_FOR_AZEROTH}, -- Ny’alotha
};

function knownRaids.IsRaidForOldExpansion(_, expansionLevel, instanceId)
	local knownRaid = KNOWN_RAIDS_TABLE[instanceId];
	if knownRaid == nil then
		 -- If we don't know about instanceId, we assume it isn't an old raid.
		return false;
	end
	return knownRaid.expansionLevel < expansionLevel;
end

