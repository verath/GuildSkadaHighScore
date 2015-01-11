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
	["zones"] = {
	--[[
		["*"] = { -- zoneId
			zoneName = "Unknown",
			encounters = {
				["*"] = { -- encounterId
					encounterName = "Unknown",
					difficulties = {
						["**"] = {
							playerParses = {} -- List of objects "{playerInfo, role, dps, hps}"
						},
						["Normal"] = {},
						["Heroic"] = {},
						["Mythic"] = {}
					}
				}
			}
		}
	--]]
	}
}


local trackedZoneIds = {994}

function highscore:GetOrCreateEncounterTable(zoneId, zoneName, encounterId, encounterName, difficultyName)
	if not self.db.zones[zoneId] then
		self.db.zones[zoneId] = {zoneName = zoneName, encounters = {}}
	end
	
	local zone = self.db.zones[zoneId]
	if not zone.encounters[encounterId] then
		zone.encounters[encounterId] = {
			encounterName = encounterName, 
			difficulties = {
				Normal = {playerParses = {}},
				Heroic = {playerParses = {}},
				Mythic = {playerParses = {}}
		}};
	end

	local encounter = zone.encounters[encounterId]
	if not encounter.difficulties[difficultyName] then
		return nil
	else
		return encounter.difficulties[difficultyName]
	end
end

function highscore:AddEncounterParseForPlayer(zoneId, zoneName, encounterId, encounterName, difficultyName, player)
	local encounterTable = self:GetOrCreateEncounterTable(zoneId, 
		zoneName, encounterId, encounterName, difficultyName);

	if encounterTable then
		local parse = {
			playerId = player.id,
			playerName = player.name,
			role = player.role,
			specName = player.specName,
			itemLevel = player.itemLevel,
			damage = player.damage,
			healing = player.healing,
			duration = encounter.duration
		}
		tinsert(encounterTable.playerParses, parse);
	end
end

function highscore:AddEncounterParsesForPlayers(encounter, players)
	local zoneId = encounter.zoneId;
	local zoneName = encounter.zoneName;
	local encounterId = encounter.id;
	local encounterName = encounter.name;
	local difficultyName = encounter.difficultyName;

	assert(zoneId and zoneId > 1)
	assert(zoneName)
	assert(encounterId)
	assert(encounterName)
	assert(difficultyName)
	assert(players)

	if not tContains(trackedZoneIds, zoneId) then
		self:Debug("Current zone not not in tracked zones");
		return
	end

	for _, player in ipairs(players) do
		self:AddEncounterParseForPlayer(zoneId, zoneName, 
			encounterId, encounterName, difficultyName, player)
	end
end

function highscore:OnEnable()
	self.db = addon.db.realm.modules["highscore"];
end

function highscore:OnDisable()
	self.db = nil;
end
