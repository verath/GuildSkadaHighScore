local addonName, addonTable = ...

-- Global functions for faster access
local tinsert = tinsert;
local tContains = tContains;
local sort = sort;
local random = random;
local format = format;

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
					encounters = {
						["*"] = { -- encounterId
							difficulties = {
								-- playerParses is a list of objects: 
								--[[
									{
										playerId 	 = "",
										role 		 = "",
										specName 	 = "",
										itemLevel 	 = 0,
										damage 		 = 0,
										healing 	 = 0,
										groupParseId = ""
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
	},
	["zones"] = {
		["*"] = { -- zoneId
			zoneName = nil
		}
	},
	["encounters"] = {
		["*"] = { -- encounterId
			encounterName = nil
		}
	},
	["players"] = {
		["*"] = { -- playerId
			name 	= nil,
			class 	= nil
		}
	},
	["groupParses"] = {
		--[[
		["*"] = { -- groupParseId
			startTime 	= 0,
			duration 	= 0,
		}
		--]]
	}
}

addon.dbVersion = addon.dbVersion + 3

-- Constants
local TRACKED_ZONE_IDS = {
	994 -- Highmaul
}


local function generateRandomKey()
	local r1 = random(0, 1000);
	local r2 = random(0, 1000);
	local r3 = random(0, 1000);
	-- 1000^3 = 1´000´000´000, should be enough for now...
	return format("%x-%x-%x", r1, r2, r3);
end

local function addGroupParse(db, startTime, duration)
	-- Find a new unique key for the raid parse
	local key = generateRandomKey();
	while db.groupParses[key] do
		key = generateRandomKey();
	end

	db.groupParses[key] = {
		startTime 	= startTime,
		duration 	= duration
	};

	return key
end

local function addZone(db, zoneId, zoneName)
	db.zones[zoneId].zoneName = zoneName;
end

local function addEncounter(db, encounterId, encounterName)
	db.encounters[encounterId].encounterName = encounterName;
end

local function addPlayer(db, playerId, playerName, playerClass)
	db.players[playerId].name = playerName;
	db.players[playerId].class = playerClass;
end

local function getParsesTable(db, guildName, zoneId, encounterId, difficultyName)
	local encounterTable = db.guilds[guildName].zones[zoneId].encounters[encounterId];
	
	if not encounterTable.difficulties[difficultyName] then
		return nil
	else
		return encounterTable.difficulties[difficultyName].playerParses
	end
end

local function addEncounterParseForPlayer(parsesTable, player, groupParseId)
	local parse = {
		playerId 	 = player.id,
		role 		 = player.role,
		specName 	 = player.specName,
		itemLevel 	 = player.itemLevel,
		damage 		 = player.damage,
		healing 	 = player.healing,
		groupParseId = groupParseId
	}
	tinsert(parsesTable, parse);
end

-- Function for convering a database representation of 
-- a parse to a parse that can be returned to users.
-- Copies all values and adds calculated once (like dps)
local function getReturnableParse(db, parse)
	local parseCopy = {};
	for key, val in pairs(parse) do
		parseCopy[key] = val;
	end

	-- Get duration, statTime from the group parse
	local groupParse = db.groupParses[parse["groupParseId"]]
	parseCopy["duration"] = groupParse.duration;
	parseCopy["startTime"] = groupParse.startTime;
	parseCopy["groupParseId"] = nil

	-- Get player name and class
	parseCopy["name"] = db.players[parse["playerId"]].name;
	parseCopy["class"] = db.players[parse["playerId"]].class;

	-- Calculate dps/hps
	parseCopy["dps"] = 0;
	parseCopy["hps"] = 0;
	if parseCopy["duration"] > 0 then
		parseCopy["dps"] = parseCopy["damage"] / parseCopy["duration"];
		parseCopy["hps"] = parseCopy["healing"] / parseCopy["duration"];
	end

	return parseCopy;
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

	-- Add zone and encounter info
	addZone(self.db, zoneId, zoneName);
	addEncounter(self.db, encounterId, encounterName);

	-- Add a group parse entry, holding data shared between all players
	local groupParseId = addGroupParse(self.db, startTime, duration);

	local parsesTable = getParsesTable(self.db, guildName, zoneId, encounterId, difficultyName);
	if not parsesTable then
		self:Debug("AddEncounterParsesForPlayers: Could not get parsesTable")
		return
	end

	for _, player in ipairs(players) do
		self:Debug(format("addEncounterParseForPlayer: %s", player.name));

		addPlayer(self.db, player.id, player.name, player.class);
		addEncounterParseForPlayer(parsesTable, player, groupParseId)
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

	local parsesTable = getParsesTable(self.db, guildName, zoneId, encounterId, difficultyName);
	parsesTable = parsesTable or {};

	-- Get a *copy* of all parses for the specified role
	local parses = {};
	for _, parse in ipairs(parsesTable) do
		if parse.role == role then
			local parseCopy = getReturnableParse(self.db, parse);
			tinsert(parses, parseCopy);
		end
	end

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
	for encounterId, _ in pairs(encountersTable) do
		local encounterName = self.db.encounters[encounterId].encounterName;
		tinsert(encounters, {encounterId, encounterName});
	end
	return encounters;
end

-- Returns a list of zones that the guild has encounters for. 
-- The returned value is a list of {zoneId, zoneName}.
function highscore:GetZones(guildName)
	local zones = {};
	for zoneId, _ in pairs(self.db.guilds[guildName].zones) do
		local zoneName = self.db.zones[zoneId].zoneName;
		tinsert(zones, {zoneId, zoneName});
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
