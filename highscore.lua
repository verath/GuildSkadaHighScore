local addonName, addonTable = ...

-- Global functions for faster access
local tinsert = tinsert;
local tContains = tContains;

-- Set up module
local addon = addonTable[1];
local highscore = addon:NewModule("highscore", "AceEvent-3.0", "AceTimer-3.0")
addon.highscore = highscore;

-- db defaults
addon.dbDefaults.realm.modules["highscore"] = {
	["guilds"] = {
		["*"] = { -- Guild Name
			["zones"] = {
				["*"] = { -- zoneId
					zoneName = nil, -- Note: Must be set.
					encounters = {
						["*"] = { -- encounterId
							encounterName = nil, -- Note: Must be set.
							difficulties = {
								["LFR"] 	= {playerParses = {}},
								["Normal"] 	= {playerParses = {}},
								["Heroic"] 	= {playerParses = {}},
								["Mythic"] 	= {playerParses = {}}
							}
						}
					}
				}
			}
		}
	}
}

addon.dbVersion = addon.dbVersion + 1

-- Constants
local TRACKED_ZONE_IDS = {
	994 -- Highmaul
}


local function getOrCreateEncounterTable(db, guildName, zoneId, zoneName, encounterId, encounterName, difficultyName)
	local guildTable = db.guilds[guildName];
	local zoneTable = guildTable.zones[zoneId];
	local encounterTable = zoneTable.encounters[encounterId];

	if not zoneTable.zoneName then
		zoneTable.zoneName = zoneName;
	end

	if not encounterTable.encounterName then
		encounterTable.encounterName = encounterName;
	end
	
	if not encounterTable.difficulties[difficultyName] then
		return nil
	else
		return encounterTable.difficulties[difficultyName]
	end
end

local function addEncounterParseForPlayer(encounterTable, duration, player)
	local parse = {
		playerId = player.id,
		playerName = player.name,
		role = player.role,
		specName = player.specName,
		itemLevel = player.itemLevel,
		damage = player.damage,
		healing = player.healing,
		duration = duration
	}
	tinsert(encounterTable.playerParses, parse);
end


function highscore:AddEncounterParsesForPlayers(guildName, encounter, players)
	local zoneId = encounter.zoneId;
	local zoneName = encounter.zoneName;
	local encounterId = encounter.id;
	local encounterName = encounter.name;
	local difficultyName = encounter.difficultyName;
	local duration = encounter.duration;

	assert(guildName)
	assert(zoneId and zoneId > 1)
	assert(zoneName)
	assert(encounterId)
	assert(encounterName)
	assert(difficultyName)
	assert(duration)
	assert(players)

	if not tContains(TRACKED_ZONE_IDS, zoneId) then
		self:Debug("AddEncounterParsesForPlayers: Current zone not not in tracked zones");
		return
	end

	local encounterTable = getOrCreateEncounterTable(self.db, guildName, zoneId, zoneName, encounterId, encounterName, difficultyName);

	if not encounterTable then
		self:Debug("AddEncounterParsesForPlayers: Could not get encounterTable")
		return
	end

	for _, player in ipairs(players) do
		self:Debug(format("addEncounterParseForPlayer: %s", player.name));
		addEncounterParseForPlayer(encounterTable, duration, player)
	end
end


function highscore:OnEnable()
	self.db = addon.db.realm.modules["highscore"];
end

function highscore:OnDisable()
	self.db = nil;
end
