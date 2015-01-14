local addonName, addonTable = ...

-- Global functions for faster access
local tinsert = tinsert;
local tContains = tContains;
local sort = sort;

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
								-- playerParses is a list of objects: 
								--[[
									{
										playerId 	= "",
										playerName 	= "",
										role 		= "",
										specName 	= "",
										itemLevel 	= 0,
										damage 		= 0,
										healing 	= 0,
										dps			= 0,
										hps			= 0,
										duration 	= 0,
										startTime 	= 0
									}
								--]]
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

addon.dbVersion = addon.dbVersion + 2

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

local function addEncounterParseForPlayer(encounterTable, startTime, duration, player)
	local dps = duration > 0 and (player.damage/duration) or 0;
	local hps = duration > 0 and (player.healing/duration) or 0;

	local parse = {
		playerId 	= player.id,
		playerName 	= player.name,
		role 		= player.role,
		specName 	= player.specName,
		itemLevel 	= player.itemLevel,
		damage 		= player.damage,
		healing 	= player.healing,
		dps 		= dps,
		hps 		= hps,
		duration 	= duration,
		startTime 	= startTime
	}
	tinsert(encounterTable.playerParses, parse);
end


function highscore:AddEncounterParsesForPlayers(guildName, encounter, players)
	local zoneId = encounter.zoneId;
	local zoneName = encounter.zoneName;
	local encounterId = encounter.id;
	local encounterName = encounter.name;
	local difficultyName = encounter.difficultyName;
	local startTime = encounter.startTime;
	local duration = encounter.duration;

	assert(guildName)
	assert(zoneId and zoneId > 1)
	assert(zoneName)
	assert(encounterId)
	assert(encounterName)
	assert(difficultyName)
	assert(startTime)
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
		addEncounterParseForPlayer(encounterTable, startTime, duration, player)
	end
end

function highscore:GetParses(guildName, zoneId, encounterId, difficultyName, role, sortBy)
	if (role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER") then
		return {};
	end

	if not sortBy then
		if role == "TANK" or role == "DAMAGER" then
			sortBy = "dps"
		elseif role == "HEALER" then
			sortBy = "hps"
		end
	end

	local encountersTable = self.db.guilds[guildName].zones[zoneId].encounters;
	local parsesTable = encountersTable[encounterId].difficulties[difficultyName];

	-- Get all parses for the specified role
	local parses = {};
	for _, parse in ipairs(parsesTable.playerParses) do
		if parse.role == role then
			tinsert(parses, parse);
		end
	end

	-- Sort these parses by the sortBy field
	sort(parses, function(a, b) 
		return a[sortBy] > b[sortBy];
	end)
	return parses;
end

-- Returns a list of encounters in the zone for the guild that 
-- the guild has parses for. The returned value is a list of
-- {encounterId, encounterName}.
function highscore:GetEncounters(guildName, zoneId)
	local encounters = {};
	local encountersTable = self.db.guilds[guildName].zones[zoneId].encounters;
	for encounterId, encounter in pairs(encountersTable) do
		tinsert(encounters, {encounterId, encounter.encounterName});
	end
	return encounters;
end

-- Returns a list of zones that the guild has encounters for. 
-- The returned value is a list of {zoneId, zoneName}.
function highscore:GetZones(guildName)
	local zones = {};
	for zoneId, zone in pairs(self.db.guilds[guildName].zones) do
		tinsert(zones, {zoneId, zone.zoneName});
	end
	return zones;
end

function highscore:GetGuildNames()
	local guildNames = {};
	for guildName, _ in pairs(self.db.guilds) do
		tinsert(guildNames, guildName);
	end
	return guildNames;
end


function highscore:OnEnable()
	self.db = addon.db.realm.modules["highscore"];
end

function highscore:OnDisable()
	self.db = nil;
end
