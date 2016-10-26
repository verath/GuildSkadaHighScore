-- 
-- migrate.lua
-- 
-- Contains database migration
--

local addonName, addonTable = ...

-- Cached globals
local tinsert = tinsert;
local pairs = pairs;
local format = format;


-- Set up module
local addon = addonTable[1];
local migrate = addon:NewModule("migrate");
addon.migrate = migrate;


local function migrate7to8(db)
	-- dbVersion is now saved per realm, as every other
	-- options is stored per realm.
	local version = db.global.dbVersion;
	db.realm.dbVersion = version;
	return 8;
end

local function migrate8to9(db)
	-- Each highscore groupParse should have the
	-- guildName, zoneId, difficultyId and encounterId
	-- it is associated with, so that it is possible to
	-- find parses that is connected to a groupParse without
	-- having to look trough all parses.

	local highscoreDb = db.realm.modules["highscore"];

	for guildName, guildData in pairs(highscoreDb.guilds) do
		for zoneId, zoneData in pairs(guildData.zones) do
			for diffId, diffData in pairs(zoneData.difficulties) do
				for encId, encData in pairs(diffData.encounters) do
					for _, parse in pairs(encData.playerParses) do
						local groupParseId = parse.groupParseId;
						local groupParse = highscoreDb.groupParses[groupParseId];
						groupParse.guildName = guildName;
						groupParse.zoneId = zoneId;
						groupParse.difficultyId = diffId;
						groupParse.encounterId = encId;
					end
				end
			end
		end
	end

	return 9;
end


local function migrate9to10(db)
	-- Removed data not used by roles.
	-- * No longer storing damage done by healers.
	-- * No longer storing healing done by dps/tanks.
	-- * Parses must have a valid role (dps, heal, tank).
	--
	-- These changes were all made to remove data that is
	-- not used.

	local highscoreDb = db.realm.modules["highscore"];

	for _, guildData in pairs(highscoreDb.guilds) do
		for _, zoneData in pairs(guildData.zones) do
			for _, diffData in pairs(zoneData.difficulties) do
				for _, encData in pairs(diffData.encounters) do
					for id, parse in pairs(encData.playerParses) do
						if parse.role == "DAMAGER" or parse.role == "TANK" then
							parse.healing = nil;
						elseif parse.role == "HEALER" then
							parse.damage = nil;
						else
							encData.playerParses[id] = nil;
						end
					end
				end
			end
		end
	end

	return 10;
end

local function migrate10to11(db)
	local highscoreDb = db.realm.modules["highscore"];

	-- Switched to using GetInstanceInfo for zone ids

	local translateIds = {
		[994] = 1228, -- Highmaul
		[988] = 1205, -- Blackrock Foundry
		[1026] = 1448, -- Hellfire Citadel
	}

	for zoneId, zoneData in pairs(highscoreDb.zones) do
		local newId = translateIds[zoneId];
		if newId then
			highscoreDb.zones[newId] = zoneData
			highscoreDb.zones[zoneId] = nil
		end
	end

	for _, guildData in pairs(highscoreDb.guilds) do
		for zoneId, zoneData in pairs(guildData.zones) do
			local newId = translateIds[zoneId];
			if newId then
				guildData.zones[newId] = zoneData
				guildData.zones[zoneId] = nil
			end
		end
	end

	for _, groupData in pairs(highscoreDb.groupParses) do
		if translateIds[groupData.zoneId] then
			groupData.zoneId = translateIds[groupData.zoneId]
		end
	end


	return 11
end

local migrateTable = {
	[7] = migrate7to8,
	[8] = migrate8to9,
	[9] = migrate9to10,
	[10] = migrate10to11
}

local function resetDb()
	addon:Debug("Resetting db");
	addon.db:ResetDB();
end

function migrate:DoMigration()
	local db = addon.db;
	local targetVersion = addon.dbVersion;

	local currentVersion = 1;
	if db.global.dbVersion then
		-- dbVersion used to be stored in global
		currentVersion = db.global.dbVersion;
	end

	if db.realm.dbVersion and db.realm.dbVersion > currentVersion then
		currentVersion = db.realm.dbVersion
	end

	if currentVersion == targetVersion then
		return;
	end

	self:Debug(format("Attempting to migrate from dbVersion: %d to %d.", 
		currentVersion, targetVersion));

	-- If we can't find a version, we assume the db is newly created.
	-- This should mean that the db is in a good state, and all we need
	-- to do is to update the dbVersion.
	if currentVersion == 1 then
		self:Debug("No version of current db found, assuming new db.")
		db.realm.dbVersion = targetVersion;
		return;
	end

	if currentVersion > targetVersion then
		self:Debug(format("Could not migrate from dbVersion: %d!", currentVersion));
		resetDb();
	end

	while currentVersion < targetVersion do
		local migrateFunction = migrateTable[currentVersion];
		if migrateFunction then
			currentVersion = migrateFunction(db);
		else
			self:Debug(format("Could not migrate from dbVersion: %d!", currentVersion));
			resetDb();
			break;
		end
	end

	db.realm.dbVersion = targetVersion;
	self:Debug(format("Migration to dbVersion: %d completed.", 
		targetVersion));
end
