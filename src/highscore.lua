-- 
-- highscore.lua
-- 
-- Contains the highscore module. Essentially the database
-- store for the addon, using Ace3 DB.
-- 
-- This module also has various getters for the GUI to grab
-- data out of the database.
--

local addonName, addonTable = ...

-- Cached globals
local tinsert = tinsert;
local tContains = tContains;
local tremove = tremove;
local sort = sort;
local random = random;
local format = format;
local ipairs = ipairs;
local pairs = pairs;
local assert = assert;
local type = type;


-- Set up module
local addon = addonTable[1];
local highscore = addon:NewModule("highscore", "AceEvent-3.0", "AceTimer-3.0")
addon.highscore = highscore;

-- db defaults
addon.dbDefaults.realm.modules["highscore"] = {
	["guilds"] = {
		["*"] = { -- guildName
			["zones"] = {
				["*"] = { -- zoneId
					["difficulties"] = {
						["*"] = { -- difficultyId
							["encounters"] = {
								["*"] = { -- encounterId
									--[[
										playerParses is a list of objects: 
										{
											playerId 	 = "",
											role 		 = "",
											specName 	 = "",
											itemLevel 	 = 0,
											(damage)	 = 0,
											(healing) 	 = 0,
											groupParseId = ""
										}
										NOTE:
										damage is included for role TANK or DAMAGER.
										healing is included for role HEALER.
									--]]
									playerParses = {}
								}
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
	["difficulties"] = {
		["*"] = { -- difficultyId
			difficultyName = nil
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
		-- These can not have a default value as we are generating
		-- keys. We have to be able to test for existence.
		--[[
		["*"] = { -- groupParseId
			startTime    = 0,
			duration     = 0,
			guildName    = "",
			zoneId       = 0,
			difficultyId = 0,
			encounterId  = 0,
		}
		--]]
	}
}


-- Function that returns a list of keys in `parses` for the top
-- `numParses` for each player and role combination in `parses`.
local function getBestParsesForPlayers(parses, groupParses, numParses)
	local bestParses = {
		["DAMAGER"] = {},
		["TANK"] 	= {},
		["HEALER"] 	= {}
	}

	for key, parse in ipairs(parses) do
		local playerId = parse.playerId;
		local role = parse.role;
		local duration = groupParses[parse["groupParseId"]].duration;
		local amount = parse.damage and (parse.damage / duration) or (parse.healing / duration);

		if not bestParses[role][playerId] then
			bestParses[role][playerId] = {};
		end

		if #bestParses[role][playerId] < numParses then
			tinsert(bestParses[role][playerId], {key = key, amount = amount});
		elseif numParses > 0 then
			-- Sort so that the lowest amount is first element
			sort(bestParses[role][playerId], function(a, b)
				return a.amount < b.amount;
			end);
			-- Replace first element if current is higher
			if bestParses[role][playerId][1].amount < amount then
				bestParses[role][playerId][1] = {key = key, amount = amount};
			end
		end
	end

	local bestParsesKeys = {};
	for _, roleData in pairs(bestParses) do
		for _, playerData in pairs(roleData) do
			for _, parse in pairs(playerData) do
				tinsert(bestParsesKeys, parse.key);
			end
		end
	end

	return bestParsesKeys;
end

-- Function for convering a database representation of 
-- a parse to a parse that can be returned to users.
-- Copies all values and adds calculated once (like dps)
local function getReturnableParse(db, parse)
	local parseCopy = {};
	for key, val in pairs(parse) do
		parseCopy[key] = val;
	end

	-- Get duration, startTime from the group parse
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
		if parseCopy["role"] == "DAMAGER" or parseCopy["role"] == "TANK" then
			parseCopy["dps"] = parseCopy["damage"] / parseCopy["duration"];
		elseif parseCopy["role"] == "HEALER" then
			parseCopy["hps"] = parseCopy["healing"] / parseCopy["duration"];
		end
	end

	return parseCopy;
end

local function generateRandomKey()
	local r1 = random(0, 1000);
	local r2 = random(0, 1000);
	local r3 = random(0, 1000);
	-- 1000^3 = 1´000´000´000, should be enough for now...
	return format("%x-%x-%x", r1, r2, r3);
end

local function addGroupParse(db, startTime, duration, guildName, zoneId, difficultyId, encounterId)
	-- Find a new unique key for the raid parse
	local key = generateRandomKey();
	while db.groupParses[key] do
		key = generateRandomKey();
	end

	db.groupParses[key] = {
		startTime = startTime,
		duration = duration,
		guildName = guildName,
		zoneId = zoneId,
		difficultyId = difficultyId,
		encounterId = encounterId
	};

	return key
end

local function addZone(db, zoneId, zoneName)
	db.zones[zoneId].zoneName = zoneName;
end

local function addDifficulty(db, difficultyId, difficultyName)
	db.difficulties[difficultyId].difficultyName = difficultyName;
end

local function addEncounter(db, encounterId, encounterName)
	db.encounters[encounterId].encounterName = encounterName;
end

local function addPlayer(db, playerId, playerName, playerClass)
	db.players[playerId].name = playerName;
	db.players[playerId].class = playerClass;
end

local function getParsesTable(db, guildName, zoneId, difficultyId, encounterId)
	return db
		.guilds[guildName]
		.zones[zoneId]
		.difficulties[difficultyId]
		.encounters[encounterId]
		.playerParses;
end

local function addEncounterParseForPlayer(parsesTable, player, groupParseId)
	local parse = {
		playerId 	 = player.id,
		role 		 = player.role,
		specName 	 = player.specName,
		itemLevel 	 = player.itemLevel,
		groupParseId = groupParseId
	}

	-- Only store damage for dps/tanks and only healing for healers
	if player.role == "DAMAGER" or player.role == "TANK" then
		parse.damage = player.damage;
	elseif player.role == "HEALER" then
		parse.healing = player.healing;
	else
		return;
	end

	tinsert(parsesTable, parse);
end

function highscore:AddEncounterParsesForPlayers(encounter, players)
	local db = self:GetDB()

	-- Theses checks _should_ never fail. Something might fail though,
	-- so these are here as a final safe-guard against bad data being
	-- inserted into the db (which could be very hard to fix later on).
	encounter = assert(encounter);
	players = assert(players);
	local guildName = assert(encounter.guildName);
	local zoneId = assert(encounter.zoneId);
	local zoneName = assert(encounter.zoneName);
	local encounterId = assert(encounter.id);
	local encounterName = assert(encounter.name);
	local difficultyId = assert(encounter.difficultyId);
	local difficultyName = assert(encounter.difficultyName);
	local startTime = assert(encounter.startTime);
	local duration = assert(encounter.duration);

	-- Add zone, difficulty and encounter info
	addZone(db, zoneId, zoneName);
	addDifficulty(db, difficultyId, difficultyName);
	addEncounter(db, encounterId, encounterName);

	-- Add a group parse entry, holding data shared between all players
	local groupParseId = addGroupParse(db, startTime, duration, guildName,
		zoneId, difficultyId, encounterId);

	local parsesTable = getParsesTable(db, guildName, zoneId, difficultyId, encounterId);

	for _, player in ipairs(players) do
		self:Debug(format("addEncounterParseForPlayer: %s", player.name));

		addPlayer(db, player.id, player.name, player.class);
		addEncounterParseForPlayer(parsesTable, player, groupParseId)
	end

end

-- Returns (array of parses, numParses)
function highscore:GetParses(guildName, zoneId, difficultyId, encounterId, role, sortBy)
	local db = self:GetDB();

	if (role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER") then
		return {}, 0;
	end

	if not sortBy then
		if role == "TANK" or role == "DAMAGER" then
			sortBy = "dps"
		elseif role == "HEALER" then
			sortBy = "hps"
		end
	end

	local parsesTable = getParsesTable(db, guildName, zoneId, difficultyId, encounterId);

	-- Get a *copy* of all parses for the specified role
	local parses = {};
	local numParses = 0;
	for _, parse in ipairs(parsesTable) do
		if parse.role == role then
			local parseCopy = getReturnableParse(db, parse);
			tinsert(parses, parseCopy);
			numParses = numParses + 1;
		end
	end

	sort(parses, function(a, b)
		return a[sortBy] > b[sortBy];
	end)
	return parses, numParses;
end

-- Returns (array of {encounterId => encounterName}, numEncounters)
function highscore:GetEncounters(guildName, zoneId, difficultyId)
	if not guildName or not zoneId or not difficultyId then
		return {}, 0;
	end

	local db = self:GetDB();
	local encounters = {};
	local numEncounters = 0;
	local difficultiesTable = db.guilds[guildName].zones[zoneId].difficulties;

	for encounterId, _ in pairs(difficultiesTable[difficultyId].encounters) do
		local encounterName = db.encounters[encounterId].encounterName;
		encounters[encounterId] = encounterName;
		numEncounters = numEncounters + 1;
	end
	return encounters, numEncounters;
end

-- Returns (array of {difficultyId => difficultyName}, numDifficulties)
function highscore:GetDifficulties(guildName, zoneId)
	if not guildName or not zoneId then
		return {}, 0;
	end

	local db = self:GetDB();
	local difficulties = {};
	local numDifficulties = 0;
	local difficultiesTable = db.guilds[guildName].zones[zoneId].difficulties;

	for difficultyId, _ in pairs(difficultiesTable) do
		local difficultyName = db.difficulties[difficultyId].difficultyName;
		difficulties[difficultyId] = difficultyName;
		numDifficulties = numDifficulties + 1;
	end
	return difficulties, numDifficulties;
end

-- Returns (array of {zoneId => zoneName}, numZones)
function highscore:GetZones(guildName)
	if not guildName then
		return {}, 0;
	end

	local db = self:GetDB();
	local zones = {};
	local numZones = 0;
	for zoneId, _ in pairs(db.guilds[guildName].zones) do
		local zoneName = db.zones[zoneId].zoneName;
		zones[zoneId] = zoneName;
		numZones = numZones + 1;
	end
	return zones, numZones;
end

-- Returns (array of {guildId => guildName}, numGuilds)
function highscore:GetGuilds()
	local db = self:GetDB();
	local guildNames = {};
	local numGuilds = 0;
	for guildName, _ in pairs(db.guilds) do
		-- Actually guildId == guildName
		guildNames[guildName] = guildName;
		numGuilds = numGuilds + 1;
	end
	return guildNames, numGuilds;
end

-- Returns the name stored for the encounter id, or nil
-- if no encounters with that id.
function highscore:GetEncounterNameById(encounterId)
	local db = self:GetDB();
	return db.encounters[encounterId].encounterName;
end

-- Returns the name stored for the difficulty id, or nil
-- if no difficulty with that id.
function highscore:GetDifficultyNameById(difficultyId)
	local db = self:GetDB();
	return db.difficulties[difficultyId].difficultyName;
end

-- Returns the name stored for the zone id, or nil
-- if no zone with that id.
function highscore:GetZoneNameById(zoneId)
	local db = self:GetDB();
	return db.zones[zoneId].zoneName;
end

-- Returns the name stored for the guild id, or nil
-- if no guild with that id.
function highscore:GetGuildNameById(guildId)
	-- As our implementation uses the guild name as
	-- id, we will simply return the value passed in.
	-- Checking for actual existance is not easy due
	-- to aceDB defaults and is therefore not done.

	return guildId;
end

-- Removes parses that is older than "olderThanDate". If minParsesPerPlayer
-- is > 0, that many parses will be kept for the player/encounter combination.
function highscore:PurgeParses(olderThanDate, minParsesPerPlayer)
	local db = self:GetDB();
	local oldGroupParseIds = {};

	for id, groupParse in pairs(db.groupParses) do
		if groupParse.startTime < olderThanDate then
			tinsert(oldGroupParseIds, id);
		end
	end

	for _, id in ipairs(oldGroupParseIds) do
		local groupParse = db.groupParses[id];
		local guildName = groupParse.guildName;
		local zoneId = groupParse.zoneId;
		local difficultyId = groupParse.difficultyId;
		local encounterId = groupParse.encounterId;

		local parses = getParsesTable(db, guildName, zoneId, difficultyId, encounterId);

		local allRemoved = true;
		if minParsesPerPlayer == 0 then
			for i = #parses, 1, -1 do
				local parse = parses[i]
				if parse.groupParseId == id then
					tremove(parses, i);
				end
			end
		else
			local bestParsesKeys = getBestParsesForPlayers(parses, db.groupParses, minParsesPerPlayer);
			for i = #parses, 1, -1 do
				local parse = parses[i]
				if parse.groupParseId == id then
					if tContains(bestParsesKeys, i) then
						allRemoved = false;
					else
						tremove(parses, i);
					end
				end
			end
		end

		if allRemoved then
			db.groupParses[id] = nil;
		end
	end
end

function highscore:GetDB()
	return addon.db.realm.modules["highscore"];
end
